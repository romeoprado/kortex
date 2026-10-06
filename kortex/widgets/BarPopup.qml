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

    // O Hyprland só esmaece popups, então o movimento é do Qt: ao abrir, o painel cresce a partir
    // da barra, descendo (ou subindo) e surgindo; ao fechar, recolhe mais depressa em direção à
    // barra e some. Escala, deslocamento, curvas e durações vêm de Motion (Configurações › Animações).
    onWantedChanged: {
        if (wanted) {
            outro.stop()
            _leaving = false
            if (!Motion.enabled) {
                frame.opacity = 1; frame.scale = 1; frame.y = 0
                return
            }
            frame.opacity = 0
            intro.restart()
        } else if (visible && Motion.enabled) {
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
                target: frame; property: "y"; from: root.below ? -Motion.popupShift : Motion.popupShift; to: 0
                duration: Motion.ms(320); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut
            }
            NumberAnimation {
                target: frame; property: "scale"; from: Motion.popupScale; to: 1
                duration: Motion.ms(320); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut
            }
            NumberAnimation { target: frame; property: "opacity"; from: 0; to: 1; duration: Motion.ms(160); easing.type: Easing.OutQuad }
        }

        ParallelAnimation {
            id: outro
            onFinished: root._leaving = false
            NumberAnimation {
                target: frame; property: "y"; to: root.below ? -Motion.popupShift * 0.6 : Motion.popupShift * 0.6
                duration: Motion.ms(150); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveIn
            }
            NumberAnimation {
                target: frame; property: "scale"; to: 1 - (1 - Motion.popupScale) / 2
                duration: Motion.ms(150); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveIn
            }
            NumberAnimation { target: frame; property: "opacity"; to: 0; duration: Motion.ms(150); easing.type: Easing.InQuad }
        }
    }
}
