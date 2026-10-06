import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Avisos flutuantes no canto superior direito do monitor em foco
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    // Cada aviso entra deslizando da direita e sai deslizando de volta e esmaecendo (por tempo,
    // clique ou fechado pelo app); os outros abrem ou fecham o espaço suavemente. A camada não tem
    // animação do Hyprland (ver HyprSync) e só encolhe depois que a saída termina (heldHeight).
    visible: Notifs.toasts.length > 0 || heldHeight > 0
    anchors { top: true; right: true }
    margins { top: Theme.gap; right: Theme.gap }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: Theme.snapUp(380, devicePixelRatio)
    implicitHeight: Math.max(1, Theme.snapUp(heldHeight, devicePixelRatio))
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kortex-notifications"

    property real heldHeight: 0
    readonly property real listHeight: list.contentHeight
    onListHeightChanged: {
        if (listHeight >= heldHeight) {
            shrink.stop()
            heldHeight = listHeight
        } else {
            shrink.restart()
        }
    }
    Timer {
        id: shrink
        interval: 480
        onTriggered: win.heldHeight = Math.max(0, win.listHeight)
    }

    // curvas iguais às do Hyprland (kortexOut/kortexIn/kortexStd, ver HyprSync)
    readonly property var curveOut: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveIn: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var curveStd: [0.2, 0, 0, 1, 1, 1]

    ListView {
        id: list
        width: parent.width
        height: win.screen ? win.screen.height : 2000   // a janela recorta; assim todos os cartões existem
        interactive: false
        spacing: Math.round(Theme.gap * win.devicePixelRatio) / win.devicePixelRatio   // pixels físicos inteiros

        // compara pelo id: um aviso que continua na lista não é recriado (nem anima de novo)
        model: ScriptModel {
            values: Notifs.toasts
            objectProp: "id"
        }

        delegate: NotificationCard {
            required property var modelData
            notif: modelData
            toast: true
            width: list.width
            onExpired: Notifs.removeToast(modelData)
        }

        add: Transition {
            NumberAnimation { property: "x"; from: 56; to: 0; duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveOut }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveOut }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutQuad }
        }
        remove: Transition {
            NumberAnimation { property: "x"; to: 56; duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveIn }
            NumberAnimation { property: "scale"; to: 0.94; duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveIn }
            NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: Easing.InQuad }
        }
        // quem é empurrado desliza; se estava entrando, termina de entrar
        addDisplaced: Transition {
            NumberAnimation { property: "y"; duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveStd }
            NumberAnimation { properties: "x"; to: 0; duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveOut }
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: 200 }
        }
        // ao sair um aviso, os de baixo esperam ele esmaecer um pouco antes de subir
        removeDisplaced: Transition {
            SequentialAnimation {
                PauseAnimation { duration: 90 }
                NumberAnimation { property: "y"; duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveStd }
            }
            NumberAnimation { properties: "x"; to: 0; duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: win.curveOut }
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: 200 }
        }
    }
}
