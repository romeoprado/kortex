pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Layouts de teclado do Hyprland (input:kb_layout, kb_variant e kb_options), via hyprctl.
//
// A escolha do usuário fica em Settings.data.keyboard e é reaplicada quando o shell inicia e
// quando o Hyprland recarrega a configuração ("configreloaded"), então vale mesmo com outro
// kb_layout no hyprland.conf. Enquanto nada foi escolhido o shell só reflete o que o Hyprland
// já usa e não muda nada.
Singleton {
    id: root

    readonly property int maxLayouts: 4   // limite do XKB: 4 grupos
    readonly property string catalogPath: "/usr/share/X11/xkb/rules/evdev.lst"

    // Atalhos para alternar entre layouts (opções "grp:" do XKB). Super+Espaço fica de fora:
    // o Hyprland trata esse atalho antes do XKB (é o do lançador).
    readonly property var switchKeys: [
        { label: "Alt + Shift", value: "grp:alt_shift_toggle" },
        { label: "Ctrl + Shift", value: "grp:ctrl_shift_toggle" },
        { label: "Alt + Espaço", value: "grp:alt_space_toggle" },
        { label: "Caps Lock", value: "grp:caps_toggle" },
        { label: "Nenhum", value: "" }
    ]

    // Estado atual do Hyprland: [{ layout: "br", variant: "abnt2" }]
    property var layouts: [{ layout: "us", variant: "" }]
    property string options: ""
    property int activeIndex: 0
    property string error: ""

    // Gravação no sistema (console e tela de login), via localectl
    property bool systemBusy: false
    property bool systemFailed: false
    property string systemMessage: ""

    // [{ layout, variant, code, name, search, order }], em ordem alfabética
    property var catalog: []
    property var _names: ({})   // "br(abnt2)" → "Português (Brasil, ABNT2)" (traduzido, se houver tradução)
    property var _tr: ({})      // tradução oficial do xkeyboard-config: "Portuguese (Brazil)" → "Português (Brasil)"
    property string _catalogText: ""

    readonly property var active: layouts[activeIndex] ?? layouts[0]
    readonly property string shortName: labelOf(active)
    readonly property string switchKey: options.split(",").find(o => o.startsWith("grp:")) ?? ""

    property string _lastPush: ""
    property var _next: null

    // ── API pública ─────────────────────────────────────────────────────
    function refresh() {
        if (!lister.running) lister.running = true
    }

    // "br(abnt2)" ou "us"
    function keyOf(e) {
        return e.variant ? e.layout + "(" + e.variant + ")" : e.layout
    }

    function nameOf(e) {
        return _names[keyOf(e)] ?? keyOf(e)
    }

    // Rótulo curto: "US", "BR". Se mais de um layout tem o mesmo código, acrescenta o início da variante
    // ("US-intl"). Compara por conteúdo, não por identidade: as linhas de um Repeater recebem cópias.
    function labelOf(e) {
        const base = e.layout.toUpperCase()
        const shared = layouts.filter(o => o.layout === e.layout).length > 1
        return shared && e.variant ? base + "-" + e.variant.slice(0, 5) : base
    }

    function hasLayout(e) {
        return layouts.some(l => l.layout === e.layout && l.variant === e.variant)
    }

    function switchTo(index) {
        if (index < 0 || index >= layouts.length || switcher.running) return
        switcher.command = ["hyprctl", "switchxkblayout", "all", String(index)]
        switcher.running = true
    }

    function next() { switchTo((activeIndex + 1) % layouts.length) }
    function prev() { switchTo((activeIndex - 1 + layouts.length) % layouts.length) }

    function addLayout(e) {
        if (layouts.length >= maxLayouts || hasLayout(e)) return
        setLayouts(layouts.concat([{ layout: e.layout, variant: e.variant }]), options)
    }

    function removeLayout(index) {
        if (layouts.length <= 1) return
        setLayouts(layouts.filter((_, i) => i !== index), options)
    }

    function moveLayout(index, delta) {
        const to = index + delta
        if (to < 0 || to >= layouts.length) return
        const list = layouts.slice()
        list.splice(to, 0, list.splice(index, 1)[0])
        setLayouts(list, options)
    }

    // Troca o atalho de alternância e preserva as outras opções (ex.: caps:escape)
    function setSwitchKey(key) {
        const rest = options.split(",").filter(o => o && !o.startsWith("grp:"))
        setLayouts(layouts, (key ? [key] : []).concat(rest).join(","))
    }

    function setLayouts(list, opts) {
        const cfg = { layouts: list.map(l => ({ layout: l.layout, variant: l.variant || "" })), options: opts }
        error = ""
        Settings.data.keyboard = cfg
        _lastPush = _signature(cfg)
        _push(cfg)
    }

    // Grava os layouts atuais no sistema: valem no console (TTY) e na tela de login.
    // O localectl pede a senha de administrador pelo agente do polkit.
    function applySystem() {
        if (systemBusy) return
        systemBusy = true
        systemFailed = false
        systemMessage = ""
        sysProc.command = ["localectl", "set-x11-keymap",
            layouts.map(l => l.layout).join(","), "pc105",
            layouts.map(l => l.variant).join(","), options]
        sysProc.running = true
    }

    // ── Internos ────────────────────────────────────────────────────────
    function _signature(cfg) {
        return cfg.layouts.map(keyOf).join(",") + "|" + (cfg.options || "")
    }

    function _push(cfg) {
        _next = cfg
        _pump()
    }

    function _pump() {
        if (pusher.running || _next === null) return
        const cfg = _next
        _next = null
        // Cada keyword recompila o mapa de teclado na hora. Trocar o layout antes da variante deixaria,
        // por um instante, a variante antiga presa ao layout novo (ao inverter "br,us" com ",alt-intl"
        // sairia "br(alt-intl)") e o Hyprland mostraria "Invalid keyboard layout passed". Por isso as
        // variantes são zeradas primeiro: sem variante, qualquer lista de layouts é válida.
        pusher.command = ["sh", "-c",
            "hyprctl keyword input:kb_variant \"\"; hyprctl keyword input:kb_layout \"$1\"; hyprctl keyword input:kb_variant \"$2\"; hyprctl keyword input:kb_options \"$3\"",
            "sh", cfg.layouts.map(l => l.layout).join(","), cfg.layouts.map(l => l.variant).join(","), cfg.options || ""]
        pusher.running = true
    }

    // Em vez de comparar strings do Hyprland, compara os layouts já separados
    function _matches(cfg) {
        return layouts.length === cfg.layouts.length
            && layouts.every((l, i) => l.layout === cfg.layouts[i].layout && l.variant === (cfg.layouts[i].variant || ""))
            && options === (cfg.options || "")
    }

    function _parseDevices(text) {
        let raw
        try { raw = JSON.parse(text) } catch (e) { return }
        const boards = raw.keyboards || []
        const kb = boards.find(k => k.main) ?? boards[0]
        if (!kb) return

        const names = (kb.layout || "us").split(",")
        const variants = (kb.variant || "").split(",")
        layouts = names.map((n, i) => ({ layout: n.trim() || "us", variant: (variants[i] || "").trim() }))
        options = kb.options || ""
        activeIndex = Math.min(kb.active_layout_index || 0, layouts.length - 1)

        // Escolha salva que o Hyprland não está usando (shell recém-iniciado, reload): reaplica uma vez
        const want = Settings.data.keyboard
        if (want && want.layouts && want.layouts.length > 0 && !_matches(want) && _lastPush !== _signature(want)) {
            _lastPush = _signature(want)
            _push(want)
        }
    }

    // Lê o xkeyboard-config: seções "! layout" e "! variant" de evdev.lst
    //   "  br              Portuguese (Brazil)"
    //   "  abnt2           br: Portuguese (Brazil, ABNT2)"
    // Saída do msgunfmt (.po): pares msgid/msgstr, com continuação em linhas que são só uma string
    function _parseTranslations(text) {
        const tr = {}
        const unq = l => l.slice(l.indexOf('"') + 1, l.lastIndexOf('"')).replace(/\\"/g, '"').replace(/\\n/g, "")
        let id = null, str = null, cur = ""
        const flush = () => { if (id && str) tr[id] = str }
        for (const line of text.split("\n")) {
            if (line.startsWith("msgid ")) { flush(); id = unq(line); str = null; cur = "id" }
            else if (line.startsWith("msgstr ")) { str = unq(line); cur = "str" }
            else if (line.startsWith('"')) { if (cur === "id") id += unq(line); else if (cur === "str") str += unq(line) }
        }
        flush()
        _tr = tr
        if (_catalogText !== "") _parseCatalog(_catalogText)
    }

    function _parseCatalog(text) {
        _catalogText = text
        const out = []
        const names = {}
        let section = ""
        for (const line of text.split("\n")) {
            if (line.startsWith("!")) {
                section = line.slice(1).trim()
                continue
            }
            const m = /^\s+(\S+)\s+(.+)$/.exec(line)
            if (!m || (section !== "layout" && section !== "variant")) continue

            let layout = m[1], variant = "", name = m[2].trim()
            if (section === "variant") {
                const v = /^([^:\s]+):\s*(.+)$/.exec(name)
                if (!v) continue
                layout = v[1]
                variant = m[1]
                name = v[2]
            }
            if (layout === "custom") continue
            const code = variant ? layout + "(" + variant + ")" : layout
            const original = name
            name = _tr[original] || original
            names[code] = name
            out.push({ layout: layout, variant: variant, code: code, name: name,
                       search: (name + " " + original + " " + code).toLowerCase(), order: 0 })
        }
        out.sort((a, b) => a.name.localeCompare(b.name))
        out.forEach((e, i) => e.order = i)
        _names = names
        catalog = out
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                readback.restart()
            } else if (event.name === "configreloaded") {
                root._lastPush = ""
                readback.restart()
            }
        }
    }

    Timer {
        id: readback
        interval: 150
        onTriggered: root.refresh()
    }

    Process {
        id: lister
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            id: listerOut
            onStreamFinished: root._parseDevices(listerOut.text)
        }
    }

    Process {
        id: switcher
        onExited: readback.restart()
    }

    // hyprctl responde "ok" ou a mensagem de erro, uma linha por comando
    Process {
        id: pusher
        stdout: StdioCollector {
            id: pusherOut
            onStreamFinished: {
                const bad = pusherOut.text.split("\n").map(s => s.trim()).filter(s => s && s !== "ok")
                if (bad.length > 0) root.error = bad.join(" ")
            }
        }
        onExited: {
            readback.restart()
            root._pump()
        }
    }

    Process {
        id: sysProc
        stderr: StdioCollector { id: sysErr }
        onExited: (code, status) => {
            root.systemBusy = false
            root.systemFailed = code !== 0
            root.systemMessage = code === 0 ? "Gravado no sistema. Vale no console e na tela de login."
                : sysErr.text.trim() || "Não foi possível gravar (código " + code + ")."
        }
    }

    // Nomes dos layouts no idioma do sistema (pt_BR, depois pt), se a tradução estiver instalada
    Process {
        running: true
        command: ["sh", "-c", "for l in \"$1\" \"${1%%_*}\"; do f=/usr/share/locale/$l/LC_MESSAGES/xkeyboard-config.mo; "
                  + "[ -f \"$f\" ] && exec msgunfmt \"$f\"; done; exit 0", "sh", Qt.locale().name]
        stdout: StdioCollector {
            id: trOut
            onStreamFinished: if (trOut.text !== "") root._parseTranslations(trOut.text)
        }
    }

    FileView {
        path: root.catalogPath
        printErrors: false
        onLoaded: root._parseCatalog(text())
    }
}
