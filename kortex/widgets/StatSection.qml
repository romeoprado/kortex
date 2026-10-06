import QtQuick
import QtQuick.Layouts
import qs.services

// Subseção de um bloco (uma segunda GPU, outro disco): divisória, nome e valor, barra e linhas de detalhe.
// O conteúdo declarado dentro dela vira as linhas de detalhe.
ColumnLayout {
    id: root
    property string title: ""
    property string valueText: ""
    property real value: -1        // 0…1; negativo esconde a barra
    property bool alert: true
    default property alias content: body.data

    Layout.fillWidth: true
    spacing: 6

    Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; implicitHeight: 1; color: Theme.muted; opacity: 0.6 }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.textBody
            elide: Text.ElideRight
        }

        Text {
            text: root.valueText
            color: Theme.fgBright
            font.family: Theme.font
            font.pixelSize: Theme.textBody
            font.bold: true
        }
    }

    StatBar {
        Layout.fillWidth: true
        visible: root.value >= 0
        value: root.value
        alert: root.alert
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 4
    }
}
