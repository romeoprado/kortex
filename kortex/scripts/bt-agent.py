#!/usr/bin/env python3
# Agente de pareamento Bluetooth do Kortex (org.bluez.Agent1, capacidade DisplayYesNo).
# Sem um agente registrado, o bluetoothd recusa os pedidos de confirmação de pareamento
# ("No agent available") e o adaptador nem aceita parear. O Quickshell só inicia o pareamento,
# não responde a esses pedidos; quem responde é este script, a mando do Kortex.
#
# Conversa com o Kortex por linhas JSON:
#   stdout  {"event": "ready"}                       agente registrado (e de novo se o bluetoothd reiniciar)
#           {"event": "request", "id": 3, "kind": "authorize" | "confirm" | "service",
#            "device": "AA:BB:…", "passkey": "123456", "uuid": "…"}
#           {"event": "display", "device": "AA:BB:…", "code": "123456"}   digitar o código no dispositivo
#           {"event": "cancel"}                      o bluetoothd desistiu do pedido em aberto
#           {"event": "error", "message": "…"}
#   stdin   "3 yes" ou "3 no"                        resposta ao pedido 3
# Termina quando o stdin fecha (o Kortex saiu). Precisa de python-dbus e python-gobject.
#
#   python3 bt-agent.py
# Saída: 0 = stdin fechou; 3 = faltam python-dbus ou python-gobject (o Kortex não tenta de novo);
# outro código = erro inesperado, como o D-Bus do sistema fora do ar (o Kortex tenta de novo em 5 s).

import json
import os
import secrets
import sys

try:
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib
except ImportError as e:
    print(json.dumps({"event": "error", "message": "missing:" + str(e)}), flush=True)
    sys.exit(3)

AGENT_PATH = "/org/kortex/btagent"
CAPABILITY = "DisplayYesNo"


def emit(**fields):
    print(json.dumps(fields), flush=True)


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


def address(bus, path):
    try:
        props = dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
        return str(props.Get("org.bluez.Device1", "Address"))
    except dbus.DBusException:
        return ""


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus
        self.next_id = 1
        self.pending = {}   # id -> (ok, err)

    def _ask(self, kind, device, ok, err, **extra):
        rid = self.next_id
        self.next_id += 1
        self.pending[rid] = (ok, err)
        emit(event="request", id=rid, kind=kind, device=address(self.bus, device), **extra)

    def answer(self, rid, yes):
        reply = self.pending.pop(rid, None)
        if reply is None:
            return
        ok, err = reply
        if yes:
            ok()
        else:
            err(Rejected("Recusado"))

    def drop_pending(self):
        for _, err in self.pending.values():
            err(Rejected("Cancelado"))
        self.pending.clear()

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        self.drop_pending()

    # Pareamento "just works" pedido pelo dispositivo (mouses, fones…)
    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="",
                         async_callbacks=("ok", "err"))
    def RequestAuthorization(self, device, ok, err):
        self._ask("authorize", device, ok, err)

    # Comparação numérica: o mesmo código aparece aqui e no outro aparelho
    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="",
                         async_callbacks=("ok", "err"))
    def RequestConfirmation(self, device, passkey, ok, err):
        self._ask("confirm", device, ok, err, passkey="%06d" % passkey)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="",
                         async_callbacks=("ok", "err"))
    def AuthorizeService(self, device, uuid, ok, err):
        self._ask("service", device, ok, err, uuid=str(uuid))

    # Teclados antigos (sem SSP): o código é gerado aqui e digitado no teclado
    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        code = "%06d" % secrets.randbelow(1000000)
        emit(event="display", device=address(self.bus, device), code=code)
        return code

    # Com DisplayYesNo o bluetoothd não pede para digitar um código aqui
    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        raise Rejected("Sem teclado no agente")

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        emit(event="display", device=address(self.bus, device), code="%06d" % passkey)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        emit(event="display", device=address(self.bus, device), code=str(pincode))

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        self.drop_pending()
        emit(event="cancel")


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus)
    loop = GLib.MainLoop()

    def register():
        try:
            manager = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
            manager.RegisterAgent(AGENT_PATH, CAPABILITY)
            manager.RequestDefaultAgent(AGENT_PATH)
            emit(event="ready")
        except dbus.DBusException as e:
            emit(event="error", message=e.get_dbus_message() or str(e))

    # Registra agora e de novo sempre que o bluetoothd (re)aparecer no barramento
    def on_owner(owner):
        if owner:
            register()
        else:
            agent.drop_pending()
    bus.watch_name_owner("org.bluez", on_owner)

    # Lê direto do descritor: com o readline do Python, linhas já guardadas no buffer não
    # acordariam a vigia de novo
    buffered = b""

    def on_stdin(fd, condition):
        nonlocal buffered
        data = os.read(fd, 4096) if condition & GLib.IO_IN else b""
        if not data:
            loop.quit()
            return False
        buffered += data
        *lines, buffered = buffered.split(b"\n")
        for line in lines:
            parts = line.decode(errors="replace").split()
            if len(parts) == 2 and parts[0].isdigit():
                agent.answer(int(parts[0]), parts[1] == "yes")
        return True
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)

    loop.run()
    agent.drop_pending()
    try:
        manager = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
        manager.UnregisterAgent(AGENT_PATH)
    except dbus.DBusException:
        pass


if __name__ == "__main__":
    main()
