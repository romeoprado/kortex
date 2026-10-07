pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Atualizações pendentes dos repositórios oficiais, pelo `checkupdates` (pacote pacman-contrib), que
// consulta uma cópia do banco do pacman sem precisar de senha. Confere ao iniciar e a cada 10 minutos.
// Sem o checkupdates, o item não aparece.
Singleton {
    id: root

    property bool available: false
    property bool checking: false
    property var packages: []          // [{ name, from, to }]
    property double lastCheck: 0       // ms
    readonly property int count: packages.length

    function check() {
        if (!available || proc.running) return
        checking = true
        proc.running = true
    }

    // Abre o terminal com a atualização completa; o terminal espera Enter para fechar
    function upgrade() {
        Settings.runInTerminal(["bash", "-c", "sudo pacman -Syu; echo; read -rp 'Pressione Enter para fechar.'"])
        recheck.left = 15
        recheck.restart()
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v checkupdates"]
        onExited: code => {
            root.available = code === 0
            if (root.available) root.check()
        }
    }

    Process {
        id: proc
        command: ["checkupdates"]
        // Só a lista que chegou substitui a anterior: num erro a saída vem vazia e a última lista fica
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    // "nome versão-velha -> versão-nova"
                    const m = line.trim().match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                    if (m) out.push({ name: m[1], from: m[2], to: m[3] })
                }
                if (out.length > 0) root.packages = out
            }
        }
        // 0 = há atualizações, 2 = nenhuma, 1 = erro (sem rede, etc.: mantém a última lista)
        onExited: code => {
            root.checking = false
            if (code === 2) root.packages = []
            if (code !== 1) root.lastCheck = Date.now()
        }
    }

    Timer {
        running: root.available
        interval: 10 * 60 * 1000
        repeat: true
        onTriggered: root.check()
    }

    // depois de abrir a atualização no terminal, confere de novo de tempos em tempos (uma vez por
    // minuto, por 15 minutos) para o número baixar quando ela terminar
    Timer {
        id: recheck
        property int left: 15
        interval: 60 * 1000
        repeat: true
        onTriggered: {
            root.check()
            if (--left <= 0) stop()
        }
    }
}
