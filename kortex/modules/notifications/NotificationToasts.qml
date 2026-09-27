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
    visible: Notifs.toasts.length > 0
    anchors { top: true; right: true }
    margins { top: Theme.gap; right: Theme.gap }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: Theme.snapUp(380, devicePixelRatio)
    implicitHeight: Math.max(1, Theme.snapUp(column.implicitHeight, devicePixelRatio))
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kortex-notifications"

    Column {
        id: column
        width: parent.width
        spacing: Math.round(Theme.gap * win.devicePixelRatio) / win.devicePixelRatio   // pixels físicos inteiros

        Repeater {
            model: Notifs.toasts

            NotificationCard {
                required property var modelData
                notif: modelData
                toast: true
                width: column.width
                onExpired: Notifs.removeToast(modelData)
            }
        }
    }
}
