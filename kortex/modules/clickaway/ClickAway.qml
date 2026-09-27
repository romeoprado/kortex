import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Fecha os popups da barra ao clicar fora deles. (As janelas modais — lançador, temas, cidade e
// rede — tratam o clique fora sozinhas: ver OverlayPanel.)
//
// HyprlandFocusGrab não serve para isso aqui: nunca ativa para um PopupWindow e, em janelas
// com teclado exclusivo, fica ativo mas nunca avisa do clique fora. Esta camada transparente
// cobre a tela logo abaixo da barra enquanto algo está aberto. Popups e janelas ficam acima
// dela (e a barra fora dela), então continuam recebendo os próprios cliques.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property ShellScreen modelData

        screen: modelData
        visible: Popups.current !== ""
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: Theme.barBottom ? 0 : Theme.barHeight
        margins.bottom: Theme.barBottom ? Theme.barHeight : 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "kortex-clickaway"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Popups.dismiss()
        }
    }
}
