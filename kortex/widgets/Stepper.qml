import QtQuick
import QtQuick.Layouts
import qs.services

// Número com botões − e +
Row {
    id: root

    property int value: 0
    property int from: 0
    property int to: 10
    property string suffix: ""
    signal moved(int value)

    spacing: 8

    PlainButton {
        implicitWidth: 34
        icon: Icons.minus
        enabled: root.value > root.from
        onClicked: root.moved(Math.max(root.from, root.value - 1))
    }

    Text {
        width: 64
        height: 32
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.value + root.suffix
        color: Theme.fgBright
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 1
        font.bold: true
    }

    PlainButton {
        implicitWidth: 34
        icon: Icons.plus
        enabled: root.value < root.to
        onClicked: root.moved(Math.min(root.to, root.value + 1))
    }
}
