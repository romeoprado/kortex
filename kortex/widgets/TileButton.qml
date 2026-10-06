import QtQuick
import QtQuick.Layouts
import qs.services

// Bloco de ação: ícone grande sobre o texto.
// Com danger: true o destaque ao passar o mouse é vermelho. Com asking: true o bloco vira
// um pedido de confirmação (fundo vermelho, "Confirmar") e uma barra esvazia em countdown ms.
// Com selected: true o bloco fica marcado (fundo no acento), como a opção em uso nos chips.
// Sem texto, vira um botão baixo só com o ícone (44 × 36), inclusive pedindo confirmação.
MouseArea {
    id: root

    property string icon: ""
    property string text: ""
    property bool danger: false
    property bool asking: false
    property bool selected: false
    property int countdown: 3000
    readonly property color hue: danger ? Theme.red : Theme.accent
    // Fundo do hover: um toque da cor do destaque sobre o bloco (não usa Theme.selection, que em
    // alguns temas é igual ao acento e apagaria o texto)
    readonly property color hoverFill: Qt.tint(Theme.bgAlt, Qt.alpha(hue, 0.18))
    readonly property color tone: asking ? Theme.redText : selected ? Theme.accentText : containsMouse ? hue : Theme.fg
    readonly property bool iconOnly: text === ""

    implicitWidth: iconOnly ? 44 : 0
    implicitHeight: iconOnly ? 36 : 78
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    scale: pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    onAskingChanged: if (asking) drain.restart(); else drain.stop()
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

    FocusRing { baseRadius: Theme.radius }

    GradientBorder {
        anchors.fill: parent
        radius: Theme.radius
        borderWidth: 1
        fill: root.asking ? Theme.red : root.selected ? Theme.accent : root.containsMouse ? root.hoverFill : Theme.bgAlt
        color: root.asking ? Theme.red : root.selected ? Theme.accent : root.containsMouse ? root.hue : "transparent"
        Behavior on fill { ColorAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.iconOnly ? 0 : -3
        spacing: 5

        Icon {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            color: root.tone
            size: root.iconOnly ? Theme.iconSize + 3 : Theme.iconSize + 8
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            visible: !root.iconOnly
            Layout.alignment: Qt.AlignHCenter
            text: root.asking ? "Confirmar" : root.text
            color: root.tone
            font.family: Theme.font
            font.pixelSize: Theme.textBody
            font.bold: root.asking || root.selected
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // Tempo que resta para confirmar
    Rectangle {
        id: bar
        visible: root.asking
        anchors {
            left: parent.left; bottom: parent.bottom
            leftMargin: root.iconOnly ? 6 : 12; bottomMargin: root.iconOnly ? 3 : 8
        }
        height: 3
        radius: 1.5
        color: Theme.redText
        opacity: 0.55
        width: 0

        NumberAnimation on width {
            id: drain
            running: false
            from: root.width - (root.iconOnly ? 12 : 24)
            to: 0
            duration: root.countdown
        }
    }
}
