pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Captura de tela: o menu (modules/screenshot/ScreenshotMenu.qml) escolhe Tela Inteira, Janela ou Área;
// a captura vai para um PNG temporário (scripts/screenshot.sh) e a janela de salvar
// (ScreenshotSave.qml) escolhe nome, formato e pasta. Nada é gravado fora da pasta temporária
// antes do Salvar; Descartar apaga a captura.
//   qs -c kortex ipc call screenshot toggle   (a tecla Print)
Singleton {
    id: root

    readonly property string script: Settings.scripts + "/screenshot.sh"
    readonly property string tmpDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kortex"

    property string monitor: ""       // monitor em que o menu abriu: o de "Tela Inteira"
    property bool busy: false         // capturando (menu fechado, slurp na tela)
    property string pending: ""       // captura à espera de ser salva (abre a janela de salvar)
    property int pixelWidth: 0
    property int pixelHeight: 0
    property string defaultName: ""
    property bool saving: false
    property string error: ""         // falha ao salvar, mostrada na janela
    property string conflict: ""      // destino que já existe: o próximo Salvar substitui
    property var folders: []          // atalhos de pasta: [{ label, value }]
    readonly property string defaultDir: Settings.home + "/Pictures/Screenshots"
    readonly property string startDir: Settings.data.screenshotDir || defaultDir

    property string _mode: ""
    property string _file: ""
    property string _dest: ""
    property string _format: ""

    function toggle() {
        if (Popups.screenshotOpen) { Popups.screenshotOpen = false; return }
        if (busy || pending !== "") return
        monitor = Hyprland.focusedMonitor?.name ?? ""
        Popups.openScreenshot()
    }

    // Fecha o menu e espera ele sumir da tela (animação de saída do Hyprland) antes de capturar
    function capture(mode) {
        if (busy) return
        Popups.screenshotOpen = false
        busy = true
        _mode = mode
        _file = tmpDir + "/captura-" + Date.now() + ".png"
        delay.restart()
    }

    function displayPath(p) {
        return p.startsWith(Settings.home + "/") ? "~" + p.slice(Settings.home.length) : p === Settings.home ? "~" : p
    }

    function save(name, dir, format, replace) {
        let n = name.trim().replace(/\.(png|jpe?g)$/i, "")
        if (n === "") { error = "Digite um nome."; return }
        if (n.includes("/")) { error = "O nome não pode ter \"/\"."; return }
        error = ""
        _format = format === "jpeg" ? "jpeg" : "png"
        _dest = dir.replace(/\/+$/, "") + "/" + n + (_format === "jpeg" ? ".jpg" : ".png")
        saving = true
        saver.command = ["bash", script, "save", pending, _dest, _format].concat(replace && conflict === _dest ? ["force"] : [])
        saver.running = true
    }

    function discard() {
        if (pending !== "") Quickshell.execDetached(["rm", "-f", pending])
        pending = ""
        error = ""
        conflict = ""
    }

    // Capturas temporárias que sobraram (o shell reiniciou com uma janela de salvar aberta)
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/captura-*.png", "sh", tmpDir])

    Timer {
        id: delay
        interval: 400
        onTriggered: {
            catcher.command = ["bash", root.script, "capture", root._mode, root.monitor, root._file,
                               Theme.accent.toString(), Theme.bg.toString()]
            catcher.running = true
        }
    }

    Process {
        id: catcher
        stdout: StdioCollector { id: catchOut }
        stderr: StdioCollector { id: catchErr }
        onExited: code => {
            root.busy = false
            if (code === 0) {
                const size = catchOut.text.trim().split(/\s+/)
                root.pixelWidth = parseInt(size[0]) || 0
                root.pixelHeight = parseInt(size[1]) || 0
                root.defaultName = "Captura " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")
                root.error = ""
                root.conflict = ""
                lister.running = true
                root.pending = root._file
                return
            }
            Quickshell.execDetached(["rm", "-f", root._file])
            if (code !== 1)   // 1 = cancelado com Esc no slurp: sem aviso
                Notifs.flash("screenshot", Icons.screenshot, "Captura não feita",
                             catchErr.text.trim().split("\n").pop() || "Erro ao capturar a tela.")
        }
    }

    Process {
        id: saver
        stderr: StdioCollector { id: saveErr }
        onExited: code => {
            root.saving = false
            if (code === 0) {
                Settings.data.screenshotDir = root._dest.slice(0, root._dest.lastIndexOf("/"))
                Settings.data.screenshotFormat = root._format
                Notifs.flash("screenshot", Icons.screenshot, "Captura salva", root.displayPath(root._dest))
                root.discard()
            } else if (code === 3) {
                root.conflict = root._dest
            } else {
                root.error = saveErr.text.trim().split("\n").pop() || "Não foi possível salvar."
            }
        }
    }

    Process {
        id: lister
        command: ["bash", root.script, "dirs"]
        stdout: StdioCollector {
            id: dirsOut
            onStreamFinished: root.folders = dirsOut.text.trim().split("\n").filter(l => l.includes("\t"))
                .map(l => ({ label: l.split("\t")[0], value: l.split("\t").slice(1).join("\t") }))
        }
    }
}
