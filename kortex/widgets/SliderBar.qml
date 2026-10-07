import QtQuick
import QtQuick.Layouts
import qs.services

// Controle deslizante 0–1 com ícone clicável à esquerda e valor à direita.
// moved(): durante o arraste; committed(): ao soltar ou rolar a roda.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property bool dimmed: false
    property string valueText: Math.round(value * 100) + "%"
    property real step: 0.05
    signal moved(real value)
    signal committed(real value)
    signal iconClicked()

    Layout.fillWidth: true
    implicitHeight: 26

    function clamp(v) { return Math.max(0, Math.min(1, v)) }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Icon {
            Layout.preferredWidth: 18
            text: root.icon
            visible: root.icon !== ""
            color: iconArea.containsMouse ? Theme.accent : (root.dimmed ? Theme.fgDim : Theme.fg)

            MouseArea {
                id: iconArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.bgAlt

                Rectangle {
                    width: track.width * root.clamp(root.value)
                    height: parent.height
                    radius: parent.radius
                    color: root.dimmed ? Theme.muted : Theme.accent
                }
            }

            GradientBorder {
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: track.width * root.clamp(root.value) - width / 2
                fill: Theme.fgBright
                borderWidth: 2
                color: root.dimmed ? Theme.muted : Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function valueAt(x) { return root.clamp(x / width) }
                onPressed: mouse => root.moved(valueAt(mouse.x))
                onPositionChanged: mouse => { if (pressed) root.moved(valueAt(mouse.x)) }
                onReleased: mouse => root.committed(valueAt(mouse.x))
                // um passo por dente da roda (120); os movimentos pequenos do touchpad se somam até lá
                property real wheelAcc: 0
                onWheel: wheel => {
                    wheelAcc += wheel.angleDelta.y
                    const n = Math.trunc(wheelAcc / 120)
                    if (n === 0) return
                    wheelAcc -= n * 120
                    const v = root.clamp(root.value + n * root.step)
                    root.moved(v)
                    root.committed(v)
                }
            }
        }

        Text {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: root.valueText
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
        }
    }
}
