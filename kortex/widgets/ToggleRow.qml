import QtQuick
import QtQuick.Layouts
import qs.services

// Linha de opção: texto à esquerda, interruptor à direita
RowLayout {
    id: root
    property string text: ""
    property bool checked: false
    signal toggled(bool value)

    Layout.fillWidth: true

    Text {
        Layout.fillWidth: true
        text: root.text
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.textBody
        elide: Text.ElideRight
    }

    Toggle {
        checked: root.checked
        onToggled: value => root.toggled(value)
    }
}
