import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services

// Painel que desce da barra, centralizado no botão que o abriu.
// Fecha ao clicar fora (camada ClickAway), ao clicar no botão de novo ou ao abrir outro painel.
PopupWindow {
    id: root

    required property Item target
    required property string popupId
    required property string screenName
    property int panelWidth: 320
    property int padding: 14
    default property alias content: column.data
    readonly property bool wanted: Popups.current === popupId && Popups.screen === screenName

    visible: wanted
    color: "transparent"
    // tamanho da janela em múltiplos do passo da escala (ver Theme.snapStep); a moldura a preenche
    implicitWidth: Theme.snapUp(panelWidth, devicePixelRatio)
    implicitHeight: Theme.snapUp(frame.implicitHeight, devicePixelRatio)

    anchor.item: target
    // Barra no topo: o painel desce; barra no fundo: ele sobe
    readonly property bool below: !Theme.barBottom
    anchor.rect.x: 0
    anchor.rect.y: below ? 0 : -Theme.gap / 2
    anchor.rect.width: target.width
    anchor.rect.height: target.height + Theme.gap / 2
    anchor.edges: below ? Edges.Bottom : Edges.Top
    anchor.gravity: below ? Edges.Bottom : Edges.Top

    // Ao abrir, desce (ou sobe) 6 px até o lugar; o esmaecimento de abrir e fechar é do próprio
    // Hyprland (fadePopupsIn/Out, ver services/HyprSync.qml)
    onVisibleChanged: if (visible) intro.restart()

    GradientFrame {
        id: frame
        width: root.implicitWidth
        height: root.implicitHeight
        implicitHeight: column.implicitHeight + root.padding * 2
        color: Theme.bg
        radius: Theme.radius
        Keys.onEscapePressed: Popups.close(root.popupId)

        ColumnLayout {
            id: column
            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            spacing: 10
        }

        NumberAnimation {
            id: intro
            target: frame; property: "y"; from: root.below ? -6 : 6; to: 0; duration: 180; easing.type: Easing.OutCubic
        }
    }
}
