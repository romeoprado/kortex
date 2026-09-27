import QtQuick
import QtQuick.Layouts
import qs.services

// Título de uma seção das Configurações, com um filete embaixo
ColumnLayout {
    id: root

    property string text: ""

    Layout.fillWidth: true
    Layout.topMargin: 6
    spacing: 5

    Text {
        text: root.text
        color: Theme.accent
        font.family: Theme.titleFont
        font.pixelSize: Theme.fontSize + 2
        font.bold: true
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.muted
        opacity: 0.5
    }
}
