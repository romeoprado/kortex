import QtQuick
import Quickshell
import qs.services

// Botão de aplicativo: ícone do .desktop e nome; o escolhido fica em destaque. Tab chega a ele e
// Espaço ou Enter o aciona.
MouseArea {
    id: root

    property string text: ""
    property string icon: ""        // nome do ícone do tema de ícones; vazio = só o texto
    property bool highlighted: false

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 38
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // Teclado: Tab chega ao controle (contorno de foco) e Espaço ou Enter o aciona
    activeFocusOnTab: enabled && visible
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked(null)
            event.accepted = true
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: root.text

    FocusRing {}

    GradientBorder {
        anchors.fill: parent
        radius: Theme.radiusSmall
        borderWidth: 1
        fill: root.highlighted ? Theme.accent : (root.containsMouse ? Theme.bgAlt : "transparent")
        color: root.highlighted ? Theme.accent : Theme.outline
        Behavior on fill { ColorAnimation { duration: Motion.ms(100) } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Image {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            source: root.icon !== "" ? Quickshell.iconPath(root.icon, "application-x-executable") : ""
            sourceSize.width: 40
            sourceSize.height: 40
            asynchronous: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.highlighted ? Theme.accentText : (root.containsMouse ? Theme.fgBright : Theme.fg)
            font.family: Theme.font
            font.pixelSize: Theme.textBody
        }
    }
}
