import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Fecha os popups da barra ao clicar fora deles. (As janelas modais — lançador, temas, cidade e
// rede — tratam o clique fora sozinhas: ver OverlayPanel.)
//
// HyprlandFocusGrab não serve para isso aqui: nunca ativa para um PopupWindow e, em janelas
// com teclado exclusivo, fica ativo mas nunca avisa do clique fora. Esta camada transparente
// cobre a tela inteira enquanto algo está aberto, com um recorte do tamanho exato da barra
// (na flutuante, as faixas ao lado e a folga até a borda também fecham). Popups e janelas
// ficam acima dela e a barra recebe os cliques pelo recorte.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: layer

        required property ShellScreen modelData

        // espaço da barra neste monitor (coordenadas da camada, que ocupa a tela toda)
        readonly property real barWidth: Theme.barFloating ? (Popups.barWidths[modelData.name] ?? 0) : width
        readonly property real barY: Theme.barBottom ? height - Theme.barReserved : Theme.barReserved - Theme.barHeight

        screen: modelData
        visible: Popups.current !== ""
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "kortex-clickaway"

        mask: Region {
            item: area

            Region {
                intersection: Intersection.Subtract
                x: Math.round((layer.width - layer.barWidth) / 2)   // como o Hyprland centraliza
                y: layer.barY
                width: Math.ceil(layer.barWidth)
                height: Theme.barHeight
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Popups.dismiss()
        }
    }
}
