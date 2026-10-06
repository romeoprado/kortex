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

    // ao fechar, continua visível até a saída terminar
    property bool _leaving: false
    visible: wanted || _leaving
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

    // O Hyprland só esmaece popups, então o movimento é do Qt: ao abrir, o painel cresce de 92% a
    // partir da barra, descendo (ou subindo) 10 px e surgindo; ao fechar, recolhe mais depressa
    // em direção à barra e some. Mesmas curvas do Hyprland (kortexOut/kortexIn, ver HyprSync).
    onWantedChanged: {
        if (wanted) {
            outro.stop()
            _leaving = false
            frame.opacity = 0
            intro.restart()
        } else if (visible) {
            intro.stop()
            _leaving = true
            outro.restart()
        }
    }

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

        transformOrigin: root.below ? Item.Top : Item.Bottom

        ParallelAnimation {
            id: intro
            NumberAnimation {
                target: frame; property: "y"; from: root.below ? -10 : 10; to: 0
                duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }
            NumberAnimation {
                target: frame; property: "scale"; from: 0.92; to: 1
                duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }
            NumberAnimation { target: frame; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            id: outro
            onFinished: root._leaving = false
            NumberAnimation {
                target: frame; property: "y"; to: root.below ? -6 : 6
                duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
            }
            NumberAnimation {
                target: frame; property: "scale"; to: 0.96
                duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
            }
            NumberAnimation { target: frame; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InQuad }
        }
    }
}
