pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aplicativos padrão: terminal, explorador de arquivos e navegador.
// Os candidatos vêm dos .desktop instalados (categorias TerminalEmulator, FileManager e WebBrowser).
// A escolha vai para o Settings (uso do shell), para o apps.sh (atalhos do Hyprland, via open-app.sh)
// e, no caso de arquivos e navegador, para o padrão do sistema (xdg-mime), que é o que outros
// programas consultam.
Singleton {
    id: root

    readonly property var terminals: entries("TerminalEmulator")
    readonly property var fileManagers: entries("FileManager")
    readonly property var browsers: entries("WebBrowser")

    // Padrão registrado no sistema (xdg-mime), sem o sufixo .desktop
    property string systemFileManager: ""
    property string systemBrowser: ""

    function entries(category) {
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay && (a.categories || []).includes(category) && (a.command || []).length > 0)
            .map(a => ({ id: a.id, name: a.name, icon: a.icon, command: Array.from(a.command) }))
            .sort((x, y) => x.name.localeCompare(y.name))
    }

    // Nome do programa, sem o caminho: é o que o Settings guarda para o terminal
    function commandName(entry) { return entry ? String(entry.command[0]).split("/").pop() : "" }

    // Escolha atual de cada tipo: a do Kortex e, na falta dela, o padrão do sistema
    function currentTerminal() { return Settings.data.terminal }
    function currentFileManager() { return Settings.data.fileManager || systemFileManager }
    function currentBrowser() { return Settings.data.browser || systemBrowser }

    // entry nulo = voltar ao automático
    function setTerminal(entry) {
        Settings.data.terminal = commandName(entry)
        _apply("terminal", entry)
    }
    function setFileManager(entry) {
        Settings.data.fileManager = entry ? entry.id : ""
        _apply("files", entry)
    }
    function setBrowser(entry) {
        Settings.data.browser = entry ? entry.id : ""
        _apply("browser", entry)
    }

    function _apply(kind, entry) {
        const cmd = ["bash", Settings.scripts + "/apps-apply.sh", kind, entry ? entry.id : "-"]
        Quickshell.execDetached(entry ? cmd.concat(entry.command) : cmd)
        reread.restart()
    }

    function refresh() {
        if (!query.running) query.running = true
    }

    Component.onCompleted: refresh()

    // xdg-mime grava de forma assíncrona: relê um instante depois
    Timer {
        id: reread
        interval: 600
        onTriggered: root.refresh()
    }

    Process {
        id: query
        command: ["sh", "-c", "xdg-mime query default inode/directory; xdg-mime query default x-scheme-handler/https"]
        stdout: StdioCollector {
            id: queryOut
            onStreamFinished: {
                const lines = queryOut.text.split("\n")
                const clean = s => (s || "").trim().replace(/\.desktop$/, "")
                root.systemFileManager = clean(lines[0])
                root.systemBrowser = clean(lines[1])
            }
        }
    }
}
