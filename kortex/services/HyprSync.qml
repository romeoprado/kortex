pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Leva ao Hyprland as opções das Configurações que dependem dele, ao vivo, via hyprctl:
//  • atalhos SUPER+6…0 (e SUPER+SHIFT+…) para as áreas de trabalho além da quinta, quando a barra
//    mostra mais de cinco. Os atalhos 1–5 já vêm do hyprland.conf.
//  • espessura da borda e raio dos cantos das janelas, quando "aplicar às janelas" está ligado.
//  • atalhos do Caps Lock e do Num Lock que avisam o OSD (bindn: não consomem a tecla).
//  • as animações do Hyprland (Configurações › Animações, ver services/Motion.qml): janelas, áreas
//    de trabalho, camadas e popups, reaplicadas a cada mudança. As janelas do Kortex (lançador,
//    temas, Configurações, rede, cidade, idioma, confirmação de tela, OSD, captura de tela) crescem
//    do centro, a barra e o carrossel deslizam da borda, e os avisos e os painéis da barra se movem
//    pelo Qt. A seleção do slurp fica sem animação, para não sair na imagem.
// Um "hyprctl reload" apaga o que foi aplicado em tempo de execução, então tudo é reaplicado
// quando o Hyprland avisa que recarregou (configreloaded). Nada aqui grava no hyprland.conf.
Singleton {
    id: root

    readonly property int workspaces: Math.max(1, Math.min(10, Settings.data.workspaceCount))
    readonly property bool syncWindows: Settings.data.hyprSyncAppearance
    readonly property int windowBorder: Math.round(Theme.border)
    readonly property int windowRounding: Theme.radius

    // atalhos que este serviço criou (e por isso pode remover); um reload do Hyprland os apaga
    property var _bound: []
    property bool _wasSyncing: false
    property bool _osdBound: false   // atalhos do OSD já criados (um reload do Hyprland os apaga)
    property bool _animsSet: false   // regras de camada já aplicadas (se repetiriam a cada vez)

    // Regras das camadas do Kortex (as curvas e velocidades vêm de Motion, ver services/Motion.qml)
    readonly property var _layerRules: [
        // janelas do Kortex crescem do centro; a barra e o carrossel deslizam da borda em que estão
        "keyword layerrule animation popin 90%, match:namespace "
            + "^kortex-(launcher|themes|settings|network-settings|network-prompt|city|language|display-confirm|osd|screenshot|screenshot-save)$",
        "keyword layerrule animation slide, match:namespace ^kortex-(bar|wallpaper-carousel)$",
        // os avisos e a camada de clique fora se animam sozinhos (Qt) ou não precisam
        "keyword layerrule no_anim on, match:namespace ^kortex-(notifications|clickaway)$",
        // a marcação do slurp (captura de tela) some na hora: com a animação de saída, o grim a pegaria
        "keyword layerrule no_anim on, match:namespace ^selection$"
    ]

    function _key(n) { return n === 10 ? "0" : String(n) }

    function apply() {
        const cmds = []
        const bound = []
        for (let n = 6; n <= 10; n++) {
            if (n <= workspaces) {
                cmds.push("keyword bind SUPER, " + _key(n) + ", workspace, " + n)
                cmds.push("keyword bind SUPER SHIFT, " + _key(n) + ", movetoworkspace, " + n)
                bound.push(n)
            } else if (_bound.includes(n)) {
                cmds.push("keyword unbind SUPER, " + _key(n))
                cmds.push("keyword unbind SUPER SHIFT, " + _key(n))
            }
        }
        _bound = bound

        if (!_osdBound) {
            cmds.push("keyword bindn , Caps_Lock, exec, qs -c kortex ipc call osd locks")
            cmds.push("keyword bindn , Num_Lock, exec, qs -c kortex ipc call osd locks")
            _osdBound = true
        }
        if (!_animsSet) {
            cmds.push(..._layerRules)
            _animsSet = true
        }
        cmds.push(...Motion.hyprlandCommands)
        if (syncWindows) {
            cmds.push("keyword general:border_size " + windowBorder)
            cmds.push("keyword decoration:rounding " + windowRounding)
        }
        if (cmds.length > 0) Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])

        // desligou "aplicar às janelas": o reload devolve os valores do hyprland.conf
        if (!syncWindows && _wasSyncing) Quickshell.execDetached(["hyprctl", "reload"])
        _wasSyncing = syncWindows
    }

    onWorkspacesChanged: settle.restart()
    readonly property var _motion: Motion.hyprlandCommands
    on_MotionChanged: settle.restart()
    onSyncWindowsChanged: settle.restart()
    onWindowBorderChanged: if (syncWindows) settle.restart()
    onWindowRoundingChanged: if (syncWindows) settle.restart()

    Timer {
        id: settle
        interval: 350
        onTriggered: root.apply()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root._bound = []
                root._osdBound = false
                root._animsSet = false
                settle.restart()
            }
        }
    }

    Component.onCompleted: settle.restart()
}
