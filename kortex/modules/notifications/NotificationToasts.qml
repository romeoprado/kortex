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
    // Deslocamento, escala, curvas e durações vêm de Motion (Configurações › Animações).
    visible: Notifs.toasts.length > 0 || heldHeight > 0
    anchors { top: true; right: true }
    // distância da borda (e da barra) num número inteiro de pixels físicos (a 1.6, 10 em vez de 8):
    // o Hyprland não arredonda a posição das camadas, e o aviso cairia entre pixels, borrado
    margins { top: Theme.snapUp(Theme.gap, devicePixelRatio); right: Theme.snapUp(Theme.gap, devicePixelRatio) }
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
        interval: Motion.enabled ? Motion.ms(480) : 0
        onTriggered: win.heldHeight = Math.max(0, win.listHeight)
    }

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
            enabled: Motion.enabled
            NumberAnimation { property: "x"; from: Motion.toastShift; to: 0; duration: Motion.ms(450); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut }
            NumberAnimation { property: "scale"; from: Motion.toastScale; to: 1; duration: Motion.ms(450); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.ms(220); easing.type: Easing.OutQuad }
        }
        remove: Transition {
            enabled: Motion.enabled
            NumberAnimation { property: "x"; to: Motion.toastShift; duration: Motion.ms(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveIn }
            NumberAnimation { property: "scale"; to: Motion.toastScale; duration: Motion.ms(240); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveIn }
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.ms(180); easing.type: Easing.InQuad }
        }
        // quem é empurrado desliza; se estava entrando, termina de entrar
        addDisplaced: Transition {
            enabled: Motion.enabled
            NumberAnimation { property: "y"; duration: Motion.ms(360); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveStd }
            NumberAnimation { properties: "x"; to: 0; duration: Motion.ms(360); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut }
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: Motion.ms(200) }
        }
        // ao sair um aviso, os de baixo esperam ele esmaecer um pouco antes de subir
        removeDisplaced: Transition {
            enabled: Motion.enabled
            SequentialAnimation {
                PauseAnimation { duration: Motion.ms(90) }
                NumberAnimation { property: "y"; duration: Motion.ms(360); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveStd }
            }
            NumberAnimation { properties: "x"; to: 0; duration: Motion.ms(360); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut }
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: Motion.ms(200) }
        }
    }
}
