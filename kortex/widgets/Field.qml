import QtQuick
import QtQuick.Layouts
import qs.services

// Campo de texto de linha única com placeholder
Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property alias echoMode: input.echoMode
    property string placeholder: ""
    property string icon: ""
    property var tabTo: null       // outro Field: Tab move o foco para ele
    signal accepted()
    signal focused()               // ganhou o foco (útil para rolar até o campo)
    signal keyPressed(var event)   // teclas antes do TextInput (event.accepted = true para consumir)

    function focusInput() { input.forceActiveFocus() }

    Layout.fillWidth: true
    implicitHeight: 34
    implicitWidth: 200
    radius: Theme.radiusSmall
    color: "transparent"

    GradientBorder {
        anchors.fill: parent
        radius: root.radius
        borderWidth: 1
        color: input.activeFocus ? Theme.accent : Theme.outline
        fill: Theme.bgDark
    }

    Icon {
        id: glyph
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.fgDim
        size: Theme.iconSize - 1
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: glyph.visible ? 32 : 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fgBright
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.font
        font.pixelSize: Theme.textBody
        clip: true
        KeyNavigation.tab: root.tabTo ? root.tabTo.input : null
        onActiveFocusChanged: if (activeFocus) root.focused()
        onAccepted: root.accepted()
        Keys.onPressed: event => {
            event.accepted = false
            root.keyPressed(event)
        }
    }

    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === "" && !input.inputMethodComposing
        text: root.placeholder
        color: Theme.fgDim
        font: input.font
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.NoButton
    }
}
