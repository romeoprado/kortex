pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale (VPN), lido de `tailscale status --json`: o estado, este computador e os outros
// dispositivos da tailnet com os endereços. Só é consultado com o painel de rede aberto (e uma vez
// ao iniciar, para saber se o Tailscale está instalado).
//
// Ligar e desligar usam `tailscale up` e `tailscale down`, que só mudam o "WantRunning" e mantêm o
// resto das preferências. Sem `tailscale set --operator=$USER`, o tailscaled só aceita isso do
// root: o comando é repetido com pkexec, que pede a senha. Se o tailscaled estiver parado, ligar
// também inicia o serviço (systemctl, que pede a senha pelo polkit).
Singleton {
    id: root

    property bool installed: false
    property bool daemonRunning: false
    property string backendState: ""     // "Running" | "Stopped" | "NeedsLogin" | "Starting" | "NoState" …
    readonly property bool running: backendState === "Running"
    property string tailnet: ""
    property string authUrl: ""
    property var self: null               // { name, ip, ipv6, dns }
    property var peers: []                // [{ name, dns, os, ip, ipv6, online, lastSeen, exitNode, direct, active }]
    property bool busy: false             // ligando ou desligando
    property string error: ""

    readonly property bool watch: Popups.current === "network"
    onWatchChanged: if (watch) refresh()

    readonly property var _cLocale: ({ LC_ALL: "C" })
    property bool _wantOn: false
    property bool _elevated: false

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    // "servidor.tailnet.ts.net." → "servidor" (o nome MagicDNS: o HostName do iOS é "localhost")
    function _shortName(node) {
        const dns = String(node.DNSName || "")
        return dns ? dns.split(".")[0] : (node.HostName || "")
    }

    function _ips(node) {
        const ips = node.TailscaleIPs || []
        return { v4: ips.find(a => a.indexOf(":") < 0) || "", v6: ips.find(a => a.indexOf(":") >= 0) || "" }
    }

    function _parse(text) {
        let d = null
        try { d = JSON.parse(text) } catch (e) { return }
        daemonRunning = true
        if (!busy) backendState = d.BackendState || ""   // ligando/desligando: mantém o estado pedido
        authUrl = d.AuthURL || ""
        tailnet = d.CurrentTailnet?.Name || ""

        const s = d.Self
        if (s && s.DNSName) {
            const ip = _ips(s)
            self = { name: _shortName(s), ip: ip.v4, ipv6: ip.v6, dns: String(s.DNSName).replace(/\.$/, "") }
        } else {
            self = null
        }

        const list = []
        for (const p of Object.values(d.Peer || {})) {
            const ip = _ips(p)
            const seen = Date.parse(p.LastSeen || "")
            list.push({
                name: _shortName(p),
                dns: String(p.DNSName || "").replace(/\.$/, ""),
                os: p.OS || "",
                ip: ip.v4,
                ipv6: ip.v6,
                online: p.Online === true,
                lastSeen: seen > 0 ? seen : 0,     // o ano 1 do Go vem negativo
                exitNode: p.ExitNode === true,
                direct: (p.CurAddr || "") !== "",
                active: p.Active === true
            })
        }
        peers = list.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name))
    }

    function _parseFailure(msg) {
        // tailscaled parado (ou sem permissão no socket): sem dados, só o estado
        daemonRunning = !/failed to connect|doesn't appear to be running|connection refused|no such file/i.test(msg)
        backendState = daemonRunning ? backendState : ""
        if (!daemonRunning) {
            self = null
            peers = []
        }
    }

    // "Linux", "iOS"… como o Tailscale escreve, com a inicial maiúscula nos que vêm em minúsculas
    function osLabel(os) {
        const names = { linux: "Linux", windows: "Windows", macOS: "macOS", iOS: "iOS", android: "Android", freebsd: "FreeBSD" }
        return names[os] || os
    }

    // Ícone do dispositivo. O Tailscale só informa o sistema (iPhone e iPad são "iOS"), então o
    // tablet é reconhecido pelo nome
    function deviceIcon(peer) {
        if (peer.os !== "iOS" && peer.os !== "android") return Icons.computer
        return /ipad|tablet/i.test(peer.name) ? Icons.tablet : Icons.phone
    }

    // "agora" · "há 5 min" · "há 3 h" · "há 12 dias"
    function ago(ms) {
        if (!ms) return ""
        const min = Math.max(0, Math.round((Date.now() - ms) / 60000))
        if (min < 1) return "agora"
        if (min < 60) return "há " + min + " min"
        const h = Math.round(min / 60)
        if (h < 24) return "há " + h + " h"
        const days = Math.round(h / 24)
        return "há " + days + (days === 1 ? " dia" : " dias")
    }

    function friendly(msg) {
        msg = String(msg || "").trim()
        if (/dismissed|Not authorized|Request dismissed|Error executing command as another user/i.test(msg)) return "Senha não informada: nada foi alterado."
        if (/access denied/i.test(msg)) return "Sem permissão para alterar o Tailscale."
        const lines = msg.split("\n").filter(l => l.trim() !== "")
        return lines[lines.length - 1] || "Não foi possível alterar o Tailscale."
    }

    // Liga (tailscale up) ou desliga (tailscale down) a conexão
    function setRunning(on) {
        if (busy) return
        error = ""
        busy = true
        _wantOn = on
        _elevated = false
        backendState = on ? "Starting" : "Stopped"   // o interruptor responde já; a leitura seguinte confirma
        if (on && !daemonRunning) {
            startDaemon.running = true
            return
        }
        _runToggle()
    }

    function _runToggle() {
        const cmd = ["tailscale", _wantOn ? "up" : "down"]
        toggler.command = _elevated ? ["pkexec"].concat(cmd) : cmd
        toggler.running = true
    }

    function copy(text) {
        if (text) Quickshell.execDetached(["wl-copy", "--", text])
    }

    // ── Processos ───────────────────────────────────────────────────────
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v tailscale"]
        onExited: code => {
            root.installed = code === 0
            if (root.installed && root.watch) root.refresh()
        }
    }

    Process {
        id: statusProc
        environment: root._cLocale
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector { id: statusOut }
        stderr: StdioCollector { id: statusErr }
        onExited: code => {
            if (code === 0) root._parse(statusOut.text)
            else root._parseFailure(statusErr.text)
        }
    }

    Process {
        id: startDaemon
        command: ["systemctl", "start", "tailscaled"]
        stderr: StdioCollector { id: startErr }
        onExited: code => {
            if (code !== 0) {
                root.error = root.friendly(startErr.text) || "Não foi possível iniciar o tailscaled."
                root.busy = false
                root.refresh()
                return
            }
            root.daemonRunning = true
            root._runToggle()
        }
    }

    // `tailscale up` sem login abre o endereço de autenticação no navegador e espera; a saída
    // chega aos poucos, então o endereço é procurado a cada linha
    Process {
        id: toggler
        environment: root._cLocale
        stdout: SplitParser { onRead: line => root._checkAuth(line) }
        stderr: SplitParser {
            onRead: line => {
                root._checkAuth(line)
                toggler.errText += line + "\n"
            }
        }
        property string errText: ""
        onRunningChanged: if (running) errText = ""
        onExited: code => {
            if (code !== 0 && !root._elevated && /access denied/i.test(errText)) {
                root._elevated = true
                root._runToggle()
                return
            }
            if (code !== 0) root.error = root.friendly(errText)
            root.busy = false
            root.refresh()
            later.restart()
        }
    }

    function _checkAuth(line) {
        const m = String(line).match(/https:\/\/login\.tailscale\.com\/\S+/)
        if (m && m[0] !== authUrl) {
            authUrl = m[0]
            Qt.openUrlExternally(authUrl)
        }
    }

    Timer {
        interval: 3000
        running: root.watch && root.installed
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: later
        interval: 1500
        onTriggered: root.refresh()
    }
}
