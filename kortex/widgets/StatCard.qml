import QtQuick
import QtQuick.Layouts
import qs.services

// Bloco de informações de um componente: ícone e nome, valor principal, barra e linhas de detalhe.
// O conteúdo declarado dentro dele (StatRow, StatSection…) vira o corpo do bloco.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string valueText: ""
    property real value: -1        // 0…1; negativo esconde a barra
    property bool alert: true
    property bool lowAlert: false
    property int subtitleSize: Theme.textSmall
    default property alias content: body.data

    Layout.fillWidth: true
    Layout.fillHeight: true        // numa grade, blocos da mesma linha ficam com a mesma altura
    implicitHeight: column.implicitHeight + 24
    radius: Theme.radius
    color: Theme.bgAlt

    ColumnLayout {
        id: column
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                text: root.icon
                color: Theme.accent
                size: Theme.iconSize + 3
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.fgBright
                font.family: Theme.titleFont
                font.pixelSize: Theme.textLarge
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: root.valueText
                color: Theme.fgBright
                font.family: Theme.font
                font.pixelSize: Theme.textTitle
                font.bold: true
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: -4
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: root.subtitleSize
            elide: Text.ElideRight
        }

        StatBar {
            Layout.fillWidth: true
            visible: root.value >= 0
            value: root.value
            alert: root.alert
            lowAlert: root.lowAlert
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 4
        }
    }
}
