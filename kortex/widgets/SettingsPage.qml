import QtQuick
import QtQuick.Layouts
import qs.services

// Página rolável das Configurações: o conteúdo declarado dentro dela vira uma coluna de linhas.
// Ao aparecer (troca de página), o conteúdo surge subindo alguns pixels; com as animações
// desligadas a troca é na hora (Motion.ms devolve 0).
Item {
    id: root

    default property alias content: column.data

    onVisibleChanged: if (visible) enter.restart()

    ParallelAnimation {
        id: enter
        NumberAnimation { target: flick; property: "opacity"; from: 0; to: 1; duration: Motion.ms(180); easing.type: Easing.OutCubic }
        NumberAnimation {
            target: shift; property: "y"; from: Motion.pick(6, 10, 16); to: 0; duration: Motion.ms(260)
            easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: 12
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        transform: Translate { id: shift }

        ColumnLayout {
            id: column
            width: flick.width
            spacing: 14
        }
    }

    // indicador de rolagem
    Rectangle {
        visible: flick.contentHeight > flick.height + 1
        x: root.width - 5
        width: 4
        radius: 2
        color: Theme.muted
        opacity: 0.8
        y: flick.visibleArea.yPosition * root.height
        height: Math.max(28, flick.visibleArea.heightRatio * root.height)
    }
}
