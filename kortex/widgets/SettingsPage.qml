import QtQuick
import QtQuick.Layouts
import qs.services

// Página rolável das Configurações: o conteúdo declarado dentro dela vira uma coluna de linhas.
Item {
    id: root

    default property alias content: column.data

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: 12
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

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
