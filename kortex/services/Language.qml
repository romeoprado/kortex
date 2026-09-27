pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Idioma do sistema (LANG em /etc/locale.conf).
//
// Um idioma já gerado é definido com `localectl set-locale`. Um que ainda não foi gerado é
// habilitado em /etc/locale.gen, gerado com `locale-gen` e definido, tudo num só comando via
// `pkexec` (a senha vem do agente do polkit). Só vale a partir do próximo login: as
// variáveis de ambiente da sessão atual não mudam.
Singleton {
    id: root

    property string current: Quickshell.env("LANG") || "C"   // LANG gravado em /etc/locale.conf
    property var installed: []                                // gerados: ["C.UTF-8", "pt_BR.UTF-8"]
    property var available: []                                // de /etc/locale.gen (só UTF-8)

    property bool busy: false
    property bool failed: false
    property string message: ""

    // [{ code, name, installed, current, search }]: o em uso, os instalados e o resto, cada grupo em ordem alfabética
    readonly property var entries: _build(available, installed, current)
    readonly property string currentName: nameOf(current)

    // Habilita o idioma em locale.gen (o código já foi validado), gera e define como padrão
    readonly property string _generateScript:
        "sed -i \"s/^#[[:space:]]*\\($1 UTF-8\\)/\\1/\" /etc/locale.gen && locale-gen && localectl set-locale \"LANG=$1\""

    // ── API pública ─────────────────────────────────────────────────────
    function refresh() {
        if (!lister.running) lister.running = true
    }

    // "pt_BR.UTF-8" → "Português (Brasil)"
    function nameOf(code) {
        const c = _norm(code)
        if (c === "C" || c === "C.UTF-8" || c === "POSIX") return "Padrão do sistema (" + c + ")"
        const modifier = /@(.+)$/.exec(c)
        const loc = Qt.locale(c.replace(/\.UTF-8/, ""))
        if (!loc.nativeLanguageName) return c
        const lang = loc.nativeLanguageName
        const territory = loc.nativeTerritoryName
        return lang.charAt(0).toUpperCase() + lang.slice(1)
            + (territory ? " (" + territory + ")" : "")
            + (modifier ? " · " + modifier[1] : "")
    }

    function setLanguage(code) {
        // O código vira argumento de um comando de root: só aceita o formato exato do locale.gen
        if (busy || !/^[a-z]{2,3}_[A-Z]{2}\.UTF-8(@[A-Za-z0-9]+)?$/.test(code)) return
        const entry = entries.find(e => e.code === code)
        busy = true
        failed = false
        message = ""
        setter.command = entry && entry.installed
            ? ["localectl", "set-locale", "LANG=" + code]
            : ["pkexec", "sh", "-c", _generateScript, "sh", code]
        setter.running = true
    }

    // ── Internos ────────────────────────────────────────────────────────
    function _norm(code) {
        return code.replace(/\.utf-?8/i, ".UTF-8")
    }

    function _build(avail, inst, cur) {
        const isLang = c => /^[a-z]{2,3}_[A-Z]{2}/.test(c)
        const have = {}
        for (const c of inst) have[_norm(c)] = true
        const codes = {}
        for (const c of avail.concat(inst, [cur])) if (isLang(c)) codes[_norm(c)] = true
        const now = _norm(cur)
        return Object.keys(codes).map(code => {
            const name = nameOf(code)
            return { code: code, name: name, installed: have[code] === true, current: code === now,
                     search: (name + " " + code).toLowerCase() }
        }).sort((a, b) => (b.current - a.current) || (b.installed - a.installed) || a.name.localeCompare(b.name))
    }

    // "#pt_BR.UTF-8 UTF-8" e "pt_BR.UTF-8 UTF-8" → "pt_BR.UTF-8"
    function _parseGen(text) {
        const out = []
        for (const line of text.split("\n")) {
            const m = /^#?([A-Za-z_@.0-9-]+)\s+UTF-8\s*$/.exec(line)
            if (m) out.push(m[1])
        }
        available = out
    }

    function _parseConf(text) {
        const m = /^LANG=["']?([^"'\s]+)["']?\s*$/m.exec(text)
        if (m) current = m[1]
    }

    Component.onCompleted: refresh()

    Process {
        id: lister
        command: ["localectl", "list-locales"]
        stdout: StdioCollector {
            id: listerOut
            onStreamFinished: root.installed = listerOut.text.split("\n").map(s => s.trim()).filter(s => s)
        }
    }

    Process {
        id: setter
        stderr: StdioCollector { id: setterErr }
        onExited: (code, status) => {
            root.busy = false
            root.failed = code !== 0
            if (code === 0) root.message = "Idioma definido. Vale a partir do próximo login."
            else if (code === 126 || code === 127) root.message = "Autorização cancelada ou negada."
            else root.message = setterErr.text.trim() || "Não foi possível definir o idioma (código " + code + ")."
            root.refresh()
        }
    }

    FileView {
        path: "/etc/locale.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._parseConf(text())
    }

    FileView {
        path: "/etc/locale.gen"
        printErrors: false
        onLoaded: root._parseGen(text())
    }
}
