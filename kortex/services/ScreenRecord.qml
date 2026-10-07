pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Gravação de tela (áudio e vídeo), no molde da captura: o menu (modules/screenshot/RecordMenu.qml)
// escolhe Tela Inteira, Janela ou Área e o áudio (sistema e microfone); a gravação vai para um MKV
// temporário (scripts/screenrecord.sh, com o gpu-screen-recorder) e, ao parar, a janela de salvar
// (RecordSave.qml) escolhe nome, formato e pasta. Enquanto grava, a barra mostra o tempo; clicar
// nele ou repetir o atalho para. Nada é gravado fora da pasta temporária antes do Salvar.
//   qs -c kortex ipc call record toggle   (SHIFT+Print)
Singleton {
    id: root

    readonly property string script: Settings.scripts + "/screenrecord.sh"
    readonly property string tmpDir: Screenshot.tmpDir

    property string monitor: ""       // monitor em que o menu abriu: o de "Tela Inteira"
    property bool busy: false         // escolhendo janela/área (menu fechado, slurp na tela)
    property bool recording: false
    property bool stopping: false     // SIGINT enviado, o gravador finalizando o arquivo
    property real startedAt: 0
    property int elapsed: 0           // segundos gravados
    property string pending: ""       // gravação à espera de ser salva (abre a janela de salvar)
    property string preview: ""       // um quadro do vídeo (PNG), para a janela de salvar
    property int pixelWidth: 0
    property int pixelHeight: 0
    property real duration: 0         // segundos
    property string defaultName: ""
    property bool saving: false
    property string error: ""         // falha ao salvar, mostrada na janela
    property string conflict: ""      // destino que já existe: o próximo Salvar substitui
    property var folders: []          // atalhos de pasta: [{ label, value }]
    // Gravações: Screencasts na pasta de vídeos do xdg-user-dirs (o 1º atalho de `dirs`)
    readonly property string defaultDir: folders.length > 0 ? folders[0].value : Settings.home + "/Videos/Screencasts"
    readonly property string startDir: Settings.data.recordDir || defaultDir

    property string _mode: ""
    property string _file: ""
    property string _dest: ""
    property string _format: ""

    function toggle() {
        if (recording) { stop(); return }
        if (Popups.recordOpen) { Popups.recordOpen = false; return }
        if (busy || pending !== "") return
        monitor = Hyprland.focusedMonitor?.name ?? ""
        Popups.openRecord()
    }

    // Fecha o menu e espera ele sumir da tela (animação de saída do Hyprland) antes de começar
    function start(mode) {
        if (busy || recording) return
        Popups.recordOpen = false
        busy = true
        _mode = mode
        _file = tmpDir + "/gravacao-" + Date.now() + ".mkv"
        delay.restart()
    }

    function stop() {
        if (!recording || stopping) return
        stopping = true
        recorder.signal(2)   // SIGINT: o gpu-screen-recorder finaliza o arquivo e sai
    }

    // 0:07 · 12:34 · 1:02:03
    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, r = s % 60
        const pad = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + pad(m) + ":" + pad(r) : m + ":" + pad(r)
    }

    function displayPath(p) { return Screenshot.displayPath(p) }

    function save(name, dir, format, replace) {
        let n = name.trim().replace(/\.(mp4|mkv)$/i, "")
        if (n === "") { error = "Digite um nome."; return }
        if (n.includes("/")) { error = "O nome não pode ter \"/\"."; return }
        error = ""
        _format = format === "mkv" ? "mkv" : "mp4"
        _dest = dir.replace(/\/+$/, "") + "/" + n + "." + _format
        saving = true
        saver.command = ["bash", script, "save", pending, _dest, _format].concat(replace && conflict === _dest ? ["force"] : [])
        saver.running = true
    }

    function discard() {
        if (pending !== "") Quickshell.execDetached(["rm", "-f", pending, preview])
        pending = ""
        preview = ""
        error = ""
        conflict = ""
    }

    function _fail(message) {
        Notifs.flash("record", Icons.record, "Gravação não feita", message)
    }

    // Gravações temporárias que sobraram (o shell reiniciou gravando ou com a janela de salvar aberta)
    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/gravacao-*", "sh", tmpDir])
        lister.running = true
    }

    Timer {
        id: delay
        interval: 400
        onTriggered: {
            targeter.command = ["bash", root.script, "target", root._mode, root.monitor,
                                Theme.accent.toString(), Theme.bg.toString()]
            targeter.running = true
        }
    }

    Process {
        id: targeter
        stdout: StdioCollector { id: targetOut }
        stderr: StdioCollector { id: targetErr }
        onExited: code => {
            root.busy = false
            if (code !== 0) {
                if (code !== 1)   // 1 = cancelado com Esc no slurp: sem aviso
                    root._fail(targetErr.text.trim().split("\n").pop() || "Erro ao escolher o que gravar.")
                return
            }
            recorder.command = ["bash", root.script, "record", targetOut.text.trim(), root._file,
                                Settings.data.recordSystemAudio ? "1" : "0", Settings.data.recordMicrophone ? "1" : "0"]
            root.startedAt = Date.now()
            root.elapsed = 0
            root.recording = true
            recorder.running = true
        }
    }

    Process {
        id: recorder
        stderr: StdioCollector { id: recordErr }
        onExited: code => {
            root.recording = false
            root.stopping = false
            // o motivo vem na linha "gsr error: …" (as seguintes podem ser listas, como a dos monitores)
            const err = recordErr.text.split("\n").filter(l => /^gsr error:/.test(l)).pop()
            const own = recordErr.text.trim().split("\n").pop() || ""   // erro do próprio script
            infoProc.message = err ? err.replace(/^gsr error:\s*/, "") : code === 2 ? own : ""
            infoProc.command = ["bash", root.script, "info", root._file, root._file.replace(/\.mkv$/, ".png")]
            infoProc.running = true
        }
    }

    Process {
        id: infoProc
        property string message: ""   // última linha de erro do gravador, se o arquivo não servir
        stdout: StdioCollector { id: infoOut }
        onExited: code => {
            const f = infoOut.text.trim().split(/\s+/)
            if (code !== 0 || f.length < 3) {
                Quickshell.execDetached(["rm", "-f", root._file, root._file.replace(/\.mkv$/, ".png")])
                root._fail(infoProc.message || "O gravador não gerou o vídeo.")
                return
            }
            root.pixelWidth = parseInt(f[0]) || 0
            root.pixelHeight = parseInt(f[1]) || 0
            root.duration = parseFloat(f[2]) || 0
            root.defaultName = "Gravação " + Qt.formatDateTime(new Date(root.startedAt), "yyyy-MM-dd HH-mm-ss")
            root.error = ""
            root.conflict = ""
            lister.running = true
            root.preview = root._file.replace(/\.mkv$/, ".png")
            root.pending = root._file
        }
    }

    Timer {
        interval: 500
        running: root.recording
        repeat: true
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }

    Process {
        id: saver
        stderr: StdioCollector { id: saveErr }
        onExited: code => {
            root.saving = false
            if (code === 0) {
                Settings.data.recordDir = root._dest.slice(0, root._dest.lastIndexOf("/"))
                Settings.data.recordFormat = root._format
                Notifs.flash("record", Icons.record, "Gravação salva", root.displayPath(root._dest))
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
