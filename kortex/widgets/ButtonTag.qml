import QtQuick
import qs.services

// Etiqueta (pílula) sob uma linha de botões só com ícone (TileButton de 44 px, 8 px entre eles):
// centralizada no botão `index`, sem passar das bordas, desliza de um botão para outro e esmaece
// quando `index` é -1. O último conteúdo fica guardado, para ela sumir inteira (sem encolher).
Item {
    id: root

    property int index: -1
    property string text: ""
    property color fill: Theme.bgAlt
    property color textColor: Theme.fg
    property bool bold: false
    readonly property int padding: 20   // folga somada ao texto (para quem calcula a largura do painel)

    property int _index: 0
    property string _text: ""
    property color _fill: Theme.bgAlt
    property color _textColor: Theme.fg
    property bool _bold: false
    function _sync() {
        if (index < 0) return
        _index = index; _text = text; _fill = fill; _textColor = textColor; _bold = bold
    }
    onIndexChanged: _sync()
    onTextChanged: _sync()
    onFillChanged: _sync()
    onTextColorChanged: _sync()
    onBoldChanged: _sync()
    Component.onCompleted: _sync()

    implicitHeight: tag.height + 4   // reservado: o painel não pula quando a etiqueta aparece

    Rectangle {
        id: tag
        readonly property real center: root._index * 52 + 22
        y: 4
        height: label.implicitHeight + 6
        width: label.implicitWidth + root.padding
        radius: height / 2
        x: Math.max(0, Math.min(root.width - width, center - width / 2))
        color: root._fill
        opacity: root.index >= 0 ? 1 : 0
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: root._text
            color: root._textColor
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            font.bold: root._bold
        }
    }
}
