import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Barra superior (uma por monitor)
//  esquerda: lançador · áreas de trabalho · CPU/RAM
//  centro:   relógio/calendário · clima
//  direita:  teclado · bluetooth · wi-fi · som · tela · notificações · energia · sessão
//
// Dois estilos (Configurações › Barra › Estilo da barra):
//  Inteira (padrão): de ponta a ponta, colada à borda da tela.
//  Flutuante: solta da borda e das laterais (a Theme.gap px), centralizada, só da largura do
//    conteúdo e com o raio e a borda dos painéis (a borda pode ser desligada). Sem seções: o
//    lançador, as áreas de trabalho e todos os itens numa fileira só, com ordem própria
//    (Settings.barFloatingLayout); a fileira da esquerda recebe tudo e as outras ficam vazias.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property string screenName: modelData ? modelData.name : ""
    readonly property bool floating: Theme.barFloating
    // borda da barra flutuante: a dos painéis, ou nenhuma (Configurações › Barra › Borda da barra flutuante)
    readonly property int frameBorder: Settings.data.barBorder ? Theme.border : 0

    // folga entre os grupos e a ponta da barra, e entre os grupos e o relógio (estilo flutuante)
    readonly property int inset: floating ? Math.max(4, Math.round(Theme.radius / 2)) + frameBorder : 4
    readonly property real contentWidth: leftGroup.implicitWidth + 2 * inset

    screen: modelData
    // sem âncoras laterais, o Hyprland centraliza a camada
    anchors { top: !Theme.barBottom; bottom: Theme.barBottom; left: !floating; right: !floating }
    margins.top: floating && !Theme.barBottom ? Theme.gap : 0
    margins.bottom: floating && Theme.barBottom ? Theme.gap : 0
    implicitWidth: floating ? Theme.snapUp(Math.min(contentWidth, (modelData ? modelData.width : 1920) - 2 * Theme.gap), devicePixelRatio) : 0
    implicitHeight: Theme.barHeight
    color: floating ? "transparent" : Theme.bg
    WlrLayershell.namespace: "kortex-bar"
    WlrLayershell.layer: WlrLayer.Top

    Behavior on color { ColorAnimation { duration: 300 } }

    // a camada ClickAway recorta o espaço da barra flutuante com esta largura
    readonly property real floatingWidth: floating ? implicitWidth : 0
    onFloatingWidthChanged: Popups.setBarWidth(screenName, floatingWidth)
    Component.onCompleted: Popups.setBarWidth(screenName, floatingWidth)

    // fundo da barra flutuante: a mesma moldura dos painéis
    GradientFrame {
        anchors.fill: parent
        visible: bar.floating
        borderWidth: bar.frameBorder
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    // Manter Acordado: a barra está sempre à vista, então segura o pedido de "não ficar inativo"
    IdleInhibitor {
        window: bar
        enabled: KeepAwake.active
    }

    // Espaço vazio da barra: a camada ClickAway deixa a barra de fora, então fecha aqui também
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Popups.dismiss()
    }

    // ── Itens (ordem em Settings.barLayout, ou barFloatingLayout na flutuante; segure um item e
    //    arraste para mudá-lo de lugar) ──
    readonly property var layout: Settings.barLayout()
    readonly property var floatingOrder: Settings.barFloatingLayout()
    readonly property var components: ({
        stats: cStats, clock: cClock, weather: cWeather, keyboard: cKeyboard, bluetooth: cBluetooth,
        network: cNetwork, audio: cAudio, display: cDisplay, notifications: cNotifications,
        energy: cEnergy, power: cPower
    })
    Component { id: cStats; StatsIndicator { screenName: bar.screenName } }
    Component { id: cClock; ClockIndicator { screenName: bar.screenName } }
    Component { id: cWeather; WeatherIndicator { screenName: bar.screenName } }
    Component { id: cKeyboard; KeyboardIndicator { screenName: bar.screenName } }
    Component { id: cBluetooth; BluetoothIndicator { screenName: bar.screenName } }
    Component { id: cNetwork; NetworkIndicator { screenName: bar.screenName } }
    Component { id: cAudio; AudioIndicator { screenName: bar.screenName } }
    Component { id: cDisplay; DisplayIndicator { screenName: bar.screenName } }
    Component { id: cNotifications; NotificationIndicator { screenName: bar.screenName } }
    Component { id: cEnergy; EnergyIndicator { screenName: bar.screenName } }
    Component { id: cPower; PowerIndicator { screenName: bar.screenName } }

    // um item da barra; a visibilidade vem das Configurações (o relógio não se esconde)
    Component {
        id: slotDelegate
        Loader {
            id: slot
            required property string modelData
            readonly property string itemId: modelData
            Layout.fillHeight: true
            visible: itemId === "clock" || Settings.barItemVisible(itemId)
            sourceComponent: bar.components[itemId] ?? null
            // o item arrastado fica apagado no lugar de origem até ser solto
            opacity: bar.dragId === itemId ? 0.3 : 1
            onLoaded: {
                item.reorderId = itemId
                item.reorderStarted.connect((x, y) => bar.beginDrag(slot, x, y))
                item.reorderMoved.connect((x, y) => bar.moveDrag(x, y))
                item.reorderFinished.connect(dropped => bar.endDrag(dropped))
            }
            Component.onDestruction: if (bar.dragId === itemId) bar.endDrag(false)
        }
    }

    RowLayout {
        id: leftGroup
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: bar.inset }
        spacing: bar.floating ? 0 : 2

        LauncherButton {}
        // espaçadores ao redor das áreas de trabalho, com folga só do lado de fora do conjunto
        Rectangle { Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 6; width: 4; height: 4; color: Theme.muted }
        Workspaces { shellScreen: bar.modelData }
        Rectangle { id: fixedEnd; Layout.alignment: Qt.AlignVCenter; Layout.rightMargin: 6; width: 4; height: 4; color: Theme.muted }
        Repeater { id: leftItems; model: bar.floating ? bar.floatingOrder : bar.layout.left; delegate: slotDelegate }
    }

    RowLayout {
        id: centerGroup
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
        spacing: 0

        Repeater { id: centerItems; model: bar.floating ? [] : bar.layout.center; delegate: slotDelegate }
    }

    RowLayout {
        id: rightGroup
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: bar.inset }
        spacing: 0

        Repeater { id: rightItems; model: bar.floating ? [] : bar.layout.right; delegate: slotDelegate }
    }

    // ── Arrastar ──
    property string dragId: ""
    property Item dragSlot: null
    property real dragX: 0
    property real grabOffset: 0     // distância do cursor à ponta esquerda do item ao começar
    property bool dragOutside: false   // longe da barra: soltar ali cancela
    property var dropSlot: null        // { group, index, x }

    // Lugares possíveis para soltar: antes de cada item visível, depois do último e, num grupo
    // vazio, o lugar do próprio grupo. `index` conta na lista do grupo sem o item arrastado.
    function _slots() {
        const out = []
        const groups = floating ? [["flat", leftItems]]
                     : [["left", leftItems], ["center", centerItems], ["right", rightItems]]
        for (const [g, rep] of groups) {
            const ids = (g === "flat" ? floatingOrder : layout[g]).filter(id => id !== dragId)
            const shown = []
            for (let i = 0; i < rep.count; i++) {
                const it = rep.itemAt(i)
                if (!it || !it.visible || it.itemId === dragId) continue
                const p = it.mapToItem(null, 0, 0)
                shown.push({ index: ids.indexOf(it.itemId), x0: p.x, x1: p.x + it.width })
            }
            if (shown.length === 0) {
                const x = g === "left" || g === "flat" ? fixedEnd.mapToItem(null, fixedEnd.width + 8, 0).x
                        : g === "center" ? bar.width / 2
                        : bar.width - inset - 4
                out.push({ group: g, index: g === "left" || g === "flat" ? 0 : ids.length, x: x })
                continue
            }
            for (const it of shown) out.push({ group: g, index: it.index, x: it.x0 })
            const last = shown[shown.length - 1]
            out.push({ group: g, index: last.index + 1, x: last.x1 })
        }
        return out
    }

    function beginDrag(slot, x, y) {
        Popups.dismiss()
        dragSlot = slot
        dragId = slot.itemId
        grabOffset = x - slot.mapToItem(null, 0, 0).x
        moveDrag(x, y)
    }
    function moveDrag(x, y) {
        if (dragId === "") return
        dragX = x
        dragOutside = y < -40 || y > bar.height + 40
        let best = null
        for (const s of _slots())
            if (!best || Math.abs(s.x - x) < Math.abs(best.x - x)) best = s
        dropSlot = best
    }
    function endDrag(dropped) {
        if (dragId === "") return
        const id = dragId, target = dropSlot, outside = dragOutside
        dragId = ""
        dragSlot = null
        dropSlot = null
        if (!dropped || outside || !target) return
        if (target.group === "flat") Settings.moveFloatingItem(id, target.index)
        else Settings.moveBarItem(id, target.group, target.index)
    }

    // cópia do item seguindo o cursor
    ShaderEffectSource {
        z: 10
        visible: bar.dragId !== "" && bar.dragSlot !== null
        sourceItem: bar.dragSlot ? bar.dragSlot.item : null
        live: true
        width: bar.dragSlot ? bar.dragSlot.width : 0
        height: bar.height
        x: Math.max(0, Math.min(bar.width - width, bar.dragX - bar.grabOffset))
        opacity: bar.dragOutside ? 0.35 : 0.9
    }

    // marca de onde o item vai cair
    Rectangle {
        z: 9
        visible: bar.dragId !== "" && bar.dropSlot !== null && !bar.dragOutside
        x: bar.dropSlot ? Math.round(bar.dropSlot.x - width / 2) : 0
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: Math.round(bar.height * 0.6)
        radius: 1
        color: Theme.accent
    }
}
