import QtQuick
import QtQuick.Layouts
import qs.services

// Botão plano da barra: ícone + texto opcional, destaque na cor de acento ao passar o mouse
MouseArea {
    id: root

    property string icon: ""
    property string label: ""
    property color color: Theme.fg
    property bool active: false
    property real iconScale: 1.0
    property bool iconFilled: false   // ícone preenchido (ex.: sino com notificações)
    property bool tabular: false      // algarismos de largura fixa (o tempo da gravação não sacode a barra)
    // Distância VISÍVEL entre o desenho do ícone e o texto: o espaço real desconta a sobra do
    // glifo (a sobra vazia à direita do desenho, que muda de ícone para ícone), então sino, bateria,
    // teclado, clima e Recursos ficam iguais
    property real labelGap: 4
    readonly property real iconInkRight: Math.max(0, glyphInk.advanceWidth - glyphInk.tightBoundingRect.x - glyphInk.tightBoundingRect.width)

    TextMetrics {
        id: glyphInk
        font: glyph.font
        text: glyph.text
    }
    property string iconFamily: Icons.family   // o logo do Arch vem de outra fonte
    readonly property color shownColor: containsMouse || active ? Theme.accent : color

    Layout.fillHeight: true
    implicitWidth: row.implicitWidth + 16
    implicitHeight: Theme.barHeight
    hoverEnabled: true
    cursorShape: reordering ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    // Reordenar na barra: com `reorderId` (dado pela barra), segurar o botão esquerdo por 450 ms
    // começa a arrastar; as posições (em coordenadas da janela) vão para a barra, que mostra onde
    // o item vai cair, e soltar o grava. Depois de segurar, o clique não acontece. Sem `reorderId`
    // (lançador), o tempo é tão longo que nunca dispara.
    property string reorderId: ""
    property bool reordering: false
    signal reorderStarted(real x, real y)
    signal reorderMoved(real x, real y)
    signal reorderFinished(bool dropped)

    pressAndHoldInterval: reorderId !== "" ? 450 : 1000000
    onPressAndHold: mouse => {
        if (reorderId === "" || mouse.button !== Qt.LeftButton) return
        reordering = true
        const p = mapToItem(null, mouse.x, mouse.y)
        reorderStarted(p.x, p.y)
    }
    onPositionChanged: mouse => {
        if (!reordering) return
        const p = mapToItem(null, mouse.x, mouse.y)
        reorderMoved(p.x, p.y)
    }
    onReleased: if (reordering) { reordering = false; reorderFinished(true) }
    onCanceled: if (reordering) { reordering = false; reorderFinished(false) }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.max(0, root.labelGap - root.iconInkRight)

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.shownColor
            size: Math.round(Theme.iconSize * root.iconScale)
            filled: root.iconFilled
            font.family: root.iconFamily
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.shownColor
            font.family: Theme.font
            font.pixelSize: Theme.textBody
            font.features: root.tabular ? { "tnum": 1 } : {}
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
}
