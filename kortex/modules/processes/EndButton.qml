import QtQuick
import qs.services
import qs.widgets

// Botão compacto de encerrar das linhas do Gerenciador de Processos.
// Com asking: true vira o pedido de confirmação (fundo vermelho); com urgent: true fica vermelho
// o tempo todo (o "Forçar" de quem não respondeu).
MouseArea {
    id: root

    property string text: "Encerrar"
    property string icon: Icons.endTask
    property bool asking: false
    property bool urgent: false
    readonly property bool red: asking || urgent
    readonly property color tone: red ? Theme.redText : containsMouse ? Theme.red : Theme.fg

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    scale: pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    Accessible.role: Accessible.Button
    Accessible.name: root.text

    GradientBorder {
        anchors.fill: parent
        radius: Theme.radiusSmall
        borderWidth: 1
        fill: root.red ? Theme.red : root.containsMouse ? Qt.tint(Theme.bgAlt, Qt.alpha(Theme.red, 0.18)) : "transparent"
        color: root.red || root.containsMouse ? Theme.red : Theme.outline
        Behavior on fill { ColorAnimation { duration: 100 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.tone
            size: Theme.iconSize - 2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.tone
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            font.bold: root.red
        }
    }
}
