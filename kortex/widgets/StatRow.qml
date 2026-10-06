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
    property int textSize: Theme.textSmall

    Layout.fillWidth: true
    visible: value !== ""
    spacing: 8

    // O rótulo nunca é cortado; se faltar espaço, quem encolhe é o valor
    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: implicitWidth
        text: root.label
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: root.textSize
        elide: Text.ElideRight
    }

    Text {
        Layout.minimumWidth: 0
        Layout.preferredWidth: implicitWidth
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        text: root.value
        color: root.warn ? Theme.red : Theme.fg
        font.family: Theme.font
        font.pixelSize: root.textSize
    }
}
