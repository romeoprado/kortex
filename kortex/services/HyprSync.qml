pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Leva ao Hyprland as opções das Configurações que dependem dele, ao vivo, via hyprctl:
//  • atalhos SUPER+6…0 (e SUPER+SHIFT+…) para as áreas de trabalho além da quinta, quando a barra
//    mostra mais de cinco. Os atalhos 1–5 já vêm do hyprland.conf.
//  • espessura da borda e raio dos cantos das janelas, quando "aplicar às janelas" está ligado.
//  • atalhos do Caps Lock e do Num Lock que avisam o OSD (bindn: não consomem a tecla).
//  • animações de abrir e fechar os painéis, do próprio Hyprland: as janelas do Kortex (lançador,
//    temas, Configurações, rede, cidade, idioma, confirmação de tela, OSD) surgem crescendo do centro
//    (popin a 92%) e os painéis da barra (popups) esmaecem; as demais camadas e popups de qualquer
//    programa ficam com a mesma velocidade (sem isto herdariam a global, ~800 ms).
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
    property bool _animsSet: false   // animações já aplicadas (a regra de camada se repetiria a cada vez)

    readonly property var _animations: [
        "keyword bezier kortexOut,0.16,1,0.3,1",
        "keyword animation layersIn,1,2.5,kortexOut",
        "keyword animation layersOut,1,1.8,kortexOut",
        "keyword animation fadeLayersIn,1,2,kortexOut",
        "keyword animation fadeLayersOut,1,1.5,kortexOut",
        "keyword animation fadePopupsIn,1,2,kortexOut",
        "keyword animation fadePopupsOut,1,1.5,kortexOut",
        "keyword layerrule animation popin 92%, match:namespace "
            + "^kortex-(launcher|themes|settings|network-settings|network-prompt|city|language|display-confirm|osd)$"
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
            cmds.push(..._animations)
            _animsSet = true
        }
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
