import QtQuick
import QtQuick.Layouts
import qs.services

MouseArea {
    id: root

    property string text: ""
    property string icon: ""
    property bool highlighted: false
    property bool danger: false
    property bool alignLeft: false
    property bool enabledLook: enabled
    property real iconShift: 0   // desloca o conteúdo na horizontal; corrige glifos que ficam fora do centro
    readonly property color tone: highlighted ? Theme.bg
                                : (danger && containsMouse) ? Theme.red
                                : containsMouse ? Theme.fgBright : Theme.fg

    // Largura natural, sem cortes. O texto só é cortado (com "…") quando o botão recebe menos que isso,
    // por exemplo num layout que o estica ou o limita.
    implicitWidth: (glyph.visible ? glyph.width + (label.visible ? row.spacing : 0) : 0)
                 + (label.visible ? label.implicitWidth : 0) + 22
    implicitHeight: 32
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: enabledLook ? 1 : 0.5

    GradientBorder {
        anchors.fill: parent
        radius: Theme.radiusSmall
        borderWidth: 1
        fill: root.highlighted ? Theme.accent : (root.containsMouse ? Theme.bgAlt : "transparent")
        color: root.highlighted ? Theme.accent
             : (root.danger && root.containsMouse) ? Theme.red : Theme.muted
        Behavior on fill { ColorAnimation { duration: 100 } }
    }

    Row {
        id: row
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: root.alignLeft ? undefined : parent.horizontalCenter
        anchors.horizontalCenterOffset: root.iconShift
        anchors.left: root.alignLeft ? parent.left : undefined
        anchors.leftMargin: 12

        Icon {
            id: glyph
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: root.alignLeft ? 18 : implicitWidth
            text: root.icon
            color: root.tone
            size: Theme.iconSize - 1
        }

        Text {
            id: label
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(0, root.width - 22 - (glyph.visible ? glyph.width + row.spacing : 0)))
            elide: Text.ElideRight
            text: root.text
            color: root.tone
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
