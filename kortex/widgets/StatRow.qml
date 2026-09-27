import QtQuick
import QtQuick.Layouts
import qs.services

// Linha de detalhe de um bloco: rótulo esmaecido à esquerda, valor à direita.
// Valor vazio esconde a linha (sensor que a máquina não tem).
RowLayout {
    id: root
    property string label: ""
    property string value: ""
    property bool warn: false
    property int textSize: Theme.fontSize - 1

    Layout.fillWidth: true
    visible: value !== ""
    spacing: 8

    Text {
        Layout.fillWidth: true
        text: root.label
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: root.textSize
        elide: Text.ElideRight
    }

    Text {
        text: root.value
        color: root.warn ? Theme.red : Theme.fg
        font.family: Theme.font
        font.pixelSize: root.textSize
    }
}
