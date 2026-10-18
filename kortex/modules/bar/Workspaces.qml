import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services

// Áreas de trabalho numeradas (1…N, N em Configurações). Clique troca de área; a roda do mouse passa
// para a próxima ou a anterior.
//
// A área atual tem uma marca só, no acento, que desliza de uma área para a outra (a bolinha na barra
// flutuante, a linha de cima na inteira). Ela se estica como uma minhoca: a ponta da frente sai na
// hora e a de trás alcança depois; quanto alcança vem da intensidade em Motion. Ideia do indicador
// deslizante do dhrruvsharma/shell (GPLv3).
Item {
    id: root

    required property ShellScreen shellScreen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(shellScreen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? -1
    readonly property int count: Math.max(1, Math.min(10, Settings.data.workspaceCount))

    // Na flutuante, cada área é uma bolinha: a atual no acento, as com janela num fundo discreto.
    readonly property bool pill: Theme.barFloating
    readonly property int cell: pill ? 26 : 24
    readonly property real markWidth: pill ? cell - 4 : 14
    readonly property bool markShown: activeId >= 1 && activeId <= count
    // pontas da marca, animadas separadamente
    property real edgeL: 0
    property real edgeR: 0
    property int hoverId: -1   // área sob o mouse (os fundos ficam numa fileira separada dos cliques)

    function place(instant) {
        if (!markShown) return
        const l = (activeId - 1) * cell + (cell - markWidth) / 2
        const r = l + markWidth
        if (instant || !Motion.enabled || edgeR === edgeL) {
            animL.stop(); animR.stop()
            edgeL = l; edgeR = r
            return
        }
        const forward = l > edgeL
        const lead = Motion.ms(180)
        const tail = Motion.ms(Motion.pick(220, 340, 460))
        animL.to = l; animL.duration = forward ? tail : lead
        animR.to = r; animR.duration = forward ? lead : tail
        animL.restart(); animR.restart()
    }

    Layout.fillHeight: true
    implicitWidth: count * cell

    onActiveIdChanged: place(false)
    onPillChanged: place(true)
    onCountChanged: place(true)
    Component.onCompleted: place(true)

    NumberAnimation { id: animL; target: root; property: "edgeL"; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut }
    NumberAnimation { id: animR; target: root; property: "edgeR"; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut }

    // Fundos (por baixo da marca): na flutuante, as áreas com janela e a área sob o mouse; na inteira,
    // a linha embaixo do número das áreas com janela
    Row {
        height: parent.height

        Repeater {
            model: root.count

            Item {
                id: back
                required property int index
                readonly property int wsId: index + 1
                // com janela aberta (a área atual, mesmo vazia, também consta na lista do Hyprland)
                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)
                readonly property bool hovered: root.hoverId === wsId

                width: root.cell
                height: parent.height

                Rectangle {
                    visible: root.pill
                    anchors.centerIn: parent
                    width: parent.width - 4
                    height: Math.round(Theme.barHeight * 0.6)
                    radius: height / 2
                    color: back.hovered ? Qt.tint(Theme.bgAlt, Qt.alpha(Theme.accent, 0.35))
                         : back.occupied ? Theme.bgAlt : "transparent"
                    Behavior on color { ColorAnimation { duration: 230 } }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 2
                    radius: 1
                    visible: !root.pill
                    width: back.occupied ? 14 : 0
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // A marca da área atual
    Rectangle {
        visible: root.markShown
        x: root.edgeL
        width: root.edgeR - root.edgeL
        height: root.pill ? Math.round(Theme.barHeight * 0.6) : 2
        y: root.pill ? Math.round((root.height - height) / 2) : 3
        radius: height / 2
        color: Theme.accent
    }

    // Números e cliques (por cima da marca)
    Row {
        height: parent.height

        Repeater {
            model: root.count

            MouseArea {
                id: ws
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: root.activeId === wsId
                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)

                width: root.cell
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: {
                    if (containsMouse) root.hoverId = wsId
                    else if (root.hoverId === wsId) root.hoverId = -1
                }
                // clicar aqui também fecha o popup aberto, como no resto da barra (este MouseArea cobre o
                // fundo da barra, que é quem fecha)
                onPressed: Popups.dismiss()
                onClicked: Hyprland.dispatch("workspace " + wsId)

                Text {
                    anchors.centerIn: parent
                    text: ws.wsId
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    font.bold: ws.isActive
                    color: root.pill && ws.isActive ? Theme.accentText
                         : ws.isActive ? Theme.accent
                         : ws.containsMouse ? Theme.fgBright
                         : ws.occupied ? Theme.fg : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Motion.enabled ? Motion.ms(200) : 0 } }
                }
            }
        }
    }

    // Um passo por dente da roda (120); os movimentos pequenos do touchpad se somam até lá
    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y
            const n = Math.trunc(acc / 120)
            if (n === 0) return
            acc -= n * 120
            const cur = root.activeId > 0 && root.activeId <= root.count ? root.activeId : 1
            const next = ((cur - 1 - n) % root.count + root.count) % root.count + 1
            Hyprland.dispatch("workspace " + next)
        }
    }
}
