pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Resolução, taxa de atualização e escala dos monitores, via hyprctl.
//
// apply() aplica na hora e deixa a mudança "em teste": se não for confirmada em
// `confirmSeconds`, o modo anterior volta sozinho (evita ficar preso numa tela preta).
// Só o que foi confirmado é gravado em ~/.local/state/kortex/monitors.conf, que o
// hyprland.conf carrega (`source`) — assim a escolha sobrevive a um reload e ao relogin.
Singleton {
    id: root

    readonly property var scales: [1, 1.25, 1.6]
    readonly property int confirmSeconds: 15

    // [{ name, description, width, height, refresh, scale, x, y,
    //    resolutions: [{ key, w, h, rates: [maior → menor] }] }]
    property var monitors: []

    property bool pending: false
    property string pendingName: ""
    property int secondsLeft: 0
    property string error: ""

    property var _before: null
    property var _queue: []

    // ── API pública ─────────────────────────────────────────────────────
    function refresh() {
        if (!lister.running) lister.running = true
    }

    function byName(name) {
        return monitors.find(m => m.name === name) ?? null
    }

    function apply(name, w, h, rate, scale) {
        const cur = byName(name)
        if (!cur) return
        if (!pending) _before = cur
        error = ""
        pendingName = name
        pending = true
        secondsLeft = confirmSeconds
        countdown.restart()
        _send(rule({ name: name, width: w, height: h, refresh: rate, x: cur.x, y: cur.y, scale: scale }))
    }

    function confirm() {
        if (!pending) return
        countdown.stop()
        pending = false
        const m = byName(pendingName)
        if (!m) return
        const rules = Object.assign({}, Settings.data.monitorRules || {})
        rules[m.name] = rule(m).slice(m.name.length + 1)
        Settings.data.monitorRules = rules
        writeConf()
    }

    function revert() {
        if (!pending) return
        countdown.stop()
        pending = false
        if (_before) _send(rule(_before))
    }

    function dismissError() {
        error = ""
    }

    function describe(m) {
        return m.width + "×" + m.height + " @ " + fmtLabel(m.refresh) + " Hz · escala " + fmtLabel(m.scale)
    }

    function fmtNumber(n) {
        return String(Number(Number(n).toFixed(2)))
    }

    // Para mostrar na tela, com vírgula (o fmtNumber, com ponto, é o que vai para o Hyprland)
    function fmtLabel(n) {
        return fmtNumber(n).replace(".", ",")
    }

    // ── Internos ────────────────────────────────────────────────────────
    // Regra do Hyprland: "DP-1,2560x1440@165,0x0,1.6"
    function rule(m) {
        return m.name + "," + m.width + "x" + m.height + "@" + fmtNumber(m.refresh)
             + "," + m.x + "x" + m.y + "," + fmtNumber(m.scale)
    }

    function writeConf() {
        const rules = Settings.data.monitorRules || {}
        let text = "# Gerado pelo Kortex (widget de tela). Carregado pelo Hyprland.\n"
        for (const name of Object.keys(rules)) text += "monitor = " + name + ", " + rules[name] + "\n"
        conf.setText(text)
    }

    function _send(r) {
        _queue = _queue.concat([r])
        _pump()
    }

    function _pump() {
        if (setter.running || _queue.length === 0) return
        setter.command = ["hyprctl", "keyword", "monitor", _queue[0]]
        _queue = _queue.slice(1)
        setter.running = true
    }

    function _fail(msg) {
        countdown.stop()
        pending = false
        error = msg || "O Hyprland recusou a configuração."
    }

    function _resolutions(modes) {
        const out = []
        const index = {}
        for (const s of modes) {
            const m = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s)
            if (!m) continue
            const key = m[1] + "x" + m[2]
            if (!(key in index)) {
                index[key] = out.length
                out.push({ key: key, w: Number(m[1]), h: Number(m[2]), rates: [] })
            }
            const rate = Number(m[3])
            if (!out[index[key]].rates.includes(rate)) out[index[key]].rates.push(rate)
        }
        for (const r of out) r.rates.sort((a, b) => b - a)
        return out.sort((a, b) => (b.w * b.h - a.w * a.h) || (b.w - a.w))
    }

    function _parse(text) {
        let raw
        try { raw = JSON.parse(text) } catch (e) { return }
        monitors = raw.filter(m => !m.disabled).map(m => ({
            name: m.name,
            description: m.description || "",
            width: m.width,
            height: m.height,
            refresh: m.refreshRate,
            scale: m.scale,
            x: m.x,
            y: m.y,
            resolutions: _resolutions(m.availableModes || [])
        }))
    }

    Component.onCompleted: refresh()

    Process {
        id: lister
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            id: listerOut
            onStreamFinished: root._parse(listerOut.text)
        }
    }

    // hyprctl responde "ok" ou a mensagem de erro (em stdout)
    Process {
        id: setter
        stdout: StdioCollector {
            id: setterOut
            onStreamFinished: {
                const out = setterOut.text.trim()
                if (out !== "ok") root._fail(out)
            }
        }
        onExited: {
            root._pump()
            if (root._queue.length === 0) readback.restart()
        }
    }

    // Dá tempo ao Hyprland de terminar o modeset antes de reler o estado
    Timer {
        id: readback
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft -= 1
            if (root.secondsLeft <= 0) root.revert()
        }
    }

    FileView {
        id: conf
        path: Settings.stateDir + "/monitors.conf"
        printErrors: false
    }
}
