pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Preferências persistidas em ~/.local/state/kortex/settings.json
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/kortex"
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/kortex"
    readonly property string scripts: Quickshell.shellDir + "/scripts"

    property alias data: adapter

    FileView {
        path: root.stateDir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter()
        }

        JsonAdapter {
            id: adapter

            // Aparência
            property string theme: "morello"
            property string wallpaper: ""
            property var themeWallpapers: ({})
            property string wallpaperDir: "~/Pictures/Wallpapers"
            property bool wallpaperEnabled: true
            property string matugenMode: "dark"                   // cores geradas do papel de parede: "dark" | "light"
            property string matugenScheme: "scheme-tonal-spot"    // variante do Matugen (--type)
            property bool hyprBorders: true
            property string mainFont: ""       // fonte principal; vazio = JetBrainsMono Nerd Font
            property int fontSize: 12          // 10…16
            property int radius: 6             // raio dos cantos arredondados dos painéis, 0…20 px
            property real borderWidth: 2       // espessura da borda dos painéis, inteiro de 0 a 5 px
            property bool hyprSyncAppearance: false   // aplica raio e borda também às janelas do Hyprland
            property int terminalOpacity: 85          // opacidade do fundo do terminal, 30…100 %
            property bool terminalBlur: true          // desfoque do que aparece por trás do terminal

            // Animações (ver services/Motion.qml)
            property bool animations: true             // desligado = nada se anima (Hyprland e Kortex)
            property string animIntensity: "elegant"   // "subtle" | "elegant" | "intense"
            property string animSpeed: "normal"        // "slow" | "normal" | "fast"
            property string animWindows: "popin"       // abertura das janelas: "popin" | "slide" | "gnomed"
            property string animWorkspaces: "horizontal"   // troca de área de trabalho: "horizontal" | "vertical" | "fade"

            // Barra
            property string barPosition: "top"      // "top" | "bottom"
            property string barStyle: "full"        // "full" (de ponta a ponta, colada à borda) | "floating" (centralizada, solta e arredondada)
            property bool barBorder: true           // borda na barra flutuante (a espessura é a dos painéis)
            property string barSize: "normal"       // "compact" (24 px) | "normal" (30 px, o padrão) | "comfortable" (36 px)
            property int workspaceCount: 5          // 1…10
            property var barItems: ({})             // { stats: false, ... }: item ausente = visível
            property var powerActions: ({})         // { lock: false, ... }: botão ausente = visível
            property bool powerConfirm: true        // sair/reiniciar/desligar pedem um segundo clique
            property int toastSeconds: 6            // tempo dos avisos flutuantes
            property bool use24h: true
            property int clockFormat: 0       // formato do relógio da barra (clique do meio alterna): 0…4
            property string weatherCity: ""   // vazio = detecta pela rede
            property string screenshotDir: ""      // última pasta em que uma captura foi salva; vazio = ~/Pictures/Screenshots
            property string screenshotFormat: "png"   // último formato usado: "png" | "jpeg"

            // Widget Recursos: o que aparece na barra
            property bool statsCpu: true
            property bool statsMem: true
            property bool statsGpu: false
            property bool statsVram: false
            property bool statsDisk: false
            property string statsDiskMount: "/"     // armazenamento mostrado na barra

            // Sistema
            property bool dnd: false
            property bool nightLight: false
            property int nightLightTemp: 4500
            property string terminal: ""      // vazio = detecta automaticamente
            property string fileManager: ""   // id do .desktop, sem o sufixo; vazio = o padrão do sistema
            property string browser: ""       // idem
            property string titleFont: ""     // fonte dos títulos dos painéis; vazio = Iosevka Fixed SmBd Ex
            property string audioApp: "pavucontrol"
            property string lockCommand: "pidof hyprlock || hyprlock"
            property var monitorRules: ({})   // { "DP-1": "2560x1440@165,0x0,1.6" }, confirmadas no widget de tela
            property var keyboard: ({})       // { layouts: [{ layout, variant }], options }; vazio = o que o Hyprland já usa

            // Lançador
            property var appUsage: ({})
            property var favoriteApps: []          // ids (.desktop) dos aplicativos favoritos
            property bool launcherFavoritesOnly: true    // o lançador abre listando só os favoritos
        }
    }

    // Itens da barra e botões de sessão: ausentes no mapa = visíveis
    function barItemVisible(id) { return (adapter.barItems || {})[id] !== false }
    function powerActionEnabled(id) { return (adapter.powerActions || {})[id] !== false }

    // Grava uma chave dentro de um mapa (barItems, powerActions), sem mexer nas outras
    function setFlag(map, key, value) {
        const m = Object.assign({}, adapter[map] || {})
        m[key] = value
        adapter[map] = m
    }

    // Aplica várias chaves em sequência, com uma pausa entre elas. Gravar o arquivo e relê-lo não é
    // instantâneo: várias mudanças na mesma volta do laço faziam algumas voltar ao valor antigo.
    property var _queue: []

    function applyBatch(pairs) {
        _queue = _queue.concat(pairs)
        if (!batch.running) batch.start()
    }

    Timer {
        id: batch
        interval: 90
        repeat: true
        onTriggered: {
            const q = root._queue.slice()
            const p = q.shift()
            root._queue = q
            if (p) adapter[p[0]] = p[1]
            else stop()
        }
    }

    // Volta aos padrões o que a janela de Configurações controla (menos tema, papel de parede e aplicativos)
    function resetAppearance() {
        applyBatch([
            ["mainFont", ""], ["titleFont", ""], ["fontSize", 12], ["radius", 6], ["borderWidth", 2],
            ["hyprSyncAppearance", false], ["terminalOpacity", 85], ["terminalBlur", true], ["barPosition", "top"], ["barStyle", "full"], ["barBorder", true], ["barSize", "normal"],
            ["animations", true], ["animIntensity", "elegant"], ["animSpeed", "normal"], ["animWindows", "popin"],
            ["animWorkspaces", "horizontal"],
            ["workspaceCount", 5],
            ["barItems", ({})], ["powerActions", ({})], ["powerConfirm", true], ["toastSeconds", 6]
        ])
    }

    function runInTerminal(cmd) {
        Quickshell.execDetached(["bash", scripts + "/term.sh", adapter.terminal].concat(cmd))
    }

    function shell(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
    }
}
