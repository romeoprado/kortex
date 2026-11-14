import QtQuick
import QtQuick.Layouts
import qs.services

// Página rolável das Configurações: o conteúdo declarado dentro dela vira uma coluna de linhas.
// Ao aparecer (troca de página), o conteúdo surge subindo alguns pixels; com as animações
// desligadas a troca é na hora (Motion.ms devolve 0). Pelo teclado, o controle que ganha o foco
// (Tab) rola para dentro da área visível.
Item {
    id: root

    default property alias content: column.data

    // Controle com o foco do teclado na janela. O clique do mouse não dá foco aos botões, então isto
    // só muda com o Tab ou ao clicar num campo de texto.
    readonly property Item focusItem: Window.activeFocusItem

    // Rola o mínimo para `item` caber na área visível, se ele for desta página
    function reveal(item) {
        if (!item || !visible) return
        let p = item
        while (p && p !== column) p = p.parent
        if (!p) return
        const margin = 12
        const top = item.mapToItem(column, 0, 0).y - margin
        const bottom = top + item.height + 2 * margin
        const last = Math.max(0, flick.contentHeight - flick.height)
        let to = flick.contentY
        if (top < to) to = Math.max(0, top)
        else if (bottom > to + flick.height) to = Math.min(last, bottom - flick.height)
        if (to === flick.contentY) return
        glide.to = to
        glide.restart()
    }

    onFocusItemChanged: reveal(focusItem)
    onVisibleChanged: if (visible) enter.restart()

    NumberAnimation { id: glide; target: flick; property: "contentY"; duration: Motion.ms(160); easing.type: Easing.OutCubic }

    ParallelAnimation {
        id: enter
        NumberAnimation { target: flick; property: "opacity"; from: 0; to: 1; duration: Motion.ms(180); easing.type: Easing.OutCubic }
        NumberAnimation {
            target: shift; property: "y"; from: Motion.pick(6, 10, 16); to: 0; duration: Motion.ms(260)
            easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: 12
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        transform: Translate { id: shift }

        ColumnLayout {
            id: column
            width: flick.width
            spacing: 14
        }
    }

    // indicador de rolagem
    Rectangle {
        visible: flick.contentHeight > flick.height + 1
        x: root.width - 5
        width: 4
        radius: 2
        color: Theme.muted
        opacity: 0.8
        y: flick.visibleArea.yPosition * root.height
        height: Math.max(28, flick.visibleArea.heightRatio * root.height)
    }
}
