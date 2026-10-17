pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Agente de pareamento Bluetooth. O Quickshell inicia o pareamento, mas não responde aos pedidos
// de confirmação do bluetoothd; sem um agente, mouses e fones são recusados ("No agent available")
// e ficam tentando de novo sem parar. O scripts/bt-agent.py registra o agente no BlueZ e repassa os
// pedidos para cá:
//  • "just works" (mouse, fone) ou serviço de um dispositivo que você mandou parear pelo painel
//    nos últimos 2 minutos: aceito sozinho;
//  • comparação de código, ou qualquer pedido que você não iniciou: o painel abre e pergunta;
//  • código para digitar no dispositivo (teclados): o painel abre e mostra o código.
// Como todo singleton, só nasce no primeiro acesso, que é o do item Bluetooth da barra: sem esse
// item não há onde perguntar, e o Kortex não se registra como agente.
Singleton {
    id: root

    property bool ready: false
    property string error: ""       // "missing" = faltam python-dbus/python-gobject; outro texto = erro do bluetoothd
    property var request: null      // { id, kind: authorize|confirm|service, address, passkey }
    property var display: null      // { address, code }
    property var failed: ({})       // endereço → true: o pareamento pedido pelo painel não deu certo
    property var _expected: ({})    // endereço → instante (ms) em que o painel pediu o pareamento

    // Um pedido que precisa de você: o indicador da tela em foco abre o painel
    signal attention()

    function deviceName(address) {
        const d = Bluetooth.devices.values.find(d => d.address === address)
        return d ? (d.name || address) : address
    }

    function pair(device) {
        const expected = Object.assign({}, _expected)
        expected[device.address] = Date.now()
        _expected = expected
        _setFailed(device.address, false)
        device.trusted = true
        device.pair()
    }

    function answer(yes) {
        if (!request) return
        proc.write(request.id + (yes ? " yes\n" : " no\n"))
        request = null
    }

    function _isExpected(address) {
        const t = _expected[address]
        return t !== undefined && Date.now() - t < 120000
    }

    function _setFailed(address, value) {
        if (!!failed[address] === value) return
        const f = Object.assign({}, failed)
        if (value) f[address] = true
        else delete f[address]
        failed = f
    }

    function _handle(line) {
        let msg
        try { msg = JSON.parse(line) } catch (e) { return }
        switch (msg.event) {
        case "ready":
            ready = true
            error = ""
            break
        case "error":
            error = msg.message.startsWith("missing:") ? "missing" : msg.message
            break
        case "request":
            if (msg.kind !== "confirm" && _isExpected(msg.device)) {
                proc.write(msg.id + " yes\n")
                return
            }
            // Só um pedido aparece por vez: o anterior, ainda sem resposta, é recusado em vez de
            // ficar preso no bluetoothd até o tempo dele acabar
            if (request) proc.write(request.id + " no\n")
            request = { id: msg.id, kind: msg.kind, address: msg.device, passkey: msg.passkey || "" }
            attention()
            break
        case "display":
            display = { address: msg.device, code: msg.code }
            attention()
            break
        case "cancel":
            request = null
            display = null
            break
        }
    }

    Process {
        id: proc
        running: true
        command: ["python3", Settings.scripts + "/bt-agent.py"]
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root._handle(line) }
        onExited: code => {
            root.ready = false
            root.request = null
            root.display = null
            // 3 = faltam os módulos do Python: tentar de novo não adianta
            if (code !== 3) restart.start()
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: proc.running = true
    }

    // Quando um pareamento pedido pelo painel termina, confere o resultado. Espera um pouco: o
    // "Paired" do dispositivo pode chegar depois do fim do pedido. Na falha, desfaz o "confiável"
    // que o painel marcou, para o dispositivo não ficar se reconectando e sendo recusado.
    property var _ended: []

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property BluetoothDevice modelData
            target: modelData
            function onPairingChanged() {
                if (modelData.pairing || root._expected[modelData.address] === undefined) return
                root._ended = root._ended.concat([modelData])
                settle.restart()
            }
            function onPairedChanged() {
                if (!modelData.paired) return
                root._setFailed(modelData.address, false)
                if (root.display && root.display.address === modelData.address) root.display = null
            }
        }
    }

    Timer {
        id: settle
        interval: 1000
        onTriggered: {
            const expected = Object.assign({}, root._expected)
            for (const d of root._ended) {
                if (!d || d.pairing) continue
                delete expected[d.address]
                if (!d.paired) {
                    root._setFailed(d.address, true)
                    d.trusted = false
                    if (root.display && root.display.address === d.address) root.display = null
                }
            }
            root._ended = []
            root._expected = expected
        }
    }
}
