import QtQuick
import qs.services

MouseArea {
    id: root
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 34
    implicitHeight: 18
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)

    GradientBorder {
        anchors.fill: parent
        radius: height / 2
        borderWidth: 1
        fill: root.checked ? Theme.accent : Theme.bgAlt
        color: root.checked ? Theme.accent : Theme.muted
        Behavior on fill { ColorAnimation { duration: 120 } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.bg : Theme.fgDim
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
}
