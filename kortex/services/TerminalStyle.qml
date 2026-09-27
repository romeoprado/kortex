pragma Singleton

import QtQuick
import Quickshell

// Terminal translúcido e com desfoque (Configurações › Aparência › Terminal), igual em qualquer tema.
//  • opacidade: vai para o Kitty pelo scripts/terminal-apply.sh (background_opacity num arquivo que o
//    kitty-theme.conf inclui); os Kitty abertos recarregam sozinhos.
//  • desfoque: é do Hyprland, que desfoca o que aparece por trás de uma janela translúcida. O mesmo script
//    grava ~/.local/state/kortex/hyprland-terminal.conf (regra no_blur para a classe "kitty" quando desligado),
//    que o hyprland.conf carrega, e manda o Hyprland recarregar se ele mudou.
// Nada aqui grava no hyprland.conf.
Singleton {
    id: root

    readonly property int percent: Math.max(30, Math.min(100, Math.round(Settings.data.terminalOpacity)))
    readonly property bool blur: Settings.data.terminalBlur

    function apply() {
        Quickshell.execDetached(["bash", Settings.scripts + "/terminal-apply.sh", String(percent), blur ? "1" : "0"])
    }

    onPercentChanged: settle.restart()
    onBlurChanged: settle.restart()

    Timer {
        id: settle
        interval: 350
        onTriggered: root.apply()
    }

    Component.onCompleted: settle.restart()
}
