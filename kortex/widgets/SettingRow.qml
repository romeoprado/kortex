import QtQuick
import QtQuick.Layouts
import qs.services

// Linha de configuração: título e descrição à esquerda, o controle (declarado dentro) à direita.
RowLayout {
    id: root

    property string title: ""
    property string description: ""
    property bool dimmed: false
    default property alias control: slot.data

    Layout.fillWidth: true
    Layout.minimumHeight: 38
    spacing: 16
    opacity: dimmed ? 0.5 : 1

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.description !== ""
            text: root.description
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
        }
    }

    RowLayout {
        id: slot
        Layout.alignment: Qt.AlignVCenter
        spacing: 8
    }
}
