import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// Janela modal para lançador, temas, cidade do clima e rede: tela cheia e transparente,
// com o painel visível centralizado (panelWidth × panelHeight) e teclado exclusivo.
//
// Ocupar a tela toda é o que faz o "clicar fora fecha" funcionar: enquanto uma janela com
// teclado exclusivo está aberta o Hyprland só entrega cliques a ela (nem uma camada por trás
// nem o HyprlandFocusGrab funcionam). O fundo emite dismissed() no clique fora; cliques dentro
// do painel não chegam ao fundo.
PanelWindow {
    id: root

    property string layerNamespace: "kortex-overlay"
    property int panelWidth: 400
    property int panelHeight: 300
    default property alias content: panel.data
    signal dismissed()

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: root.layerNamespace

    // fundo: clique fora do painel
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.dismissed()
    }

    Item {
        id: panel
        // Centralizado, mas com a origem em pixels físicos inteiros: com escala fracionária o
        // centro exato pode cair no meio de um pixel e a borda do painel sai borrada.
        x: Math.round((root.width - width) / 2 * root.devicePixelRatio) / root.devicePixelRatio
        y: Math.round((root.height - height) / 2 * root.devicePixelRatio) / root.devicePixelRatio
        width: root.panelWidth
        height: root.panelHeight

        // engole os cliques em áreas vazias do painel (o conteúdo, declarado depois, fica por cima)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => mouse.accepted = true
        }
    }
}
