import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services

// Áreas de trabalho numeradas (1…N, N em Configurações)
RowLayout {
    id: root

    required property ShellScreen shellScreen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(shellScreen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? -1
    readonly property int count: Math.max(1, Math.min(10, Settings.data.workspaceCount))

    Layout.fillHeight: true
    spacing: 0

    Repeater {
        model: root.count

        MouseArea {
            id: ws
            required property int index
            readonly property int wsId: index + 1
            readonly property bool isActive: root.activeId === wsId
            // com janela aberta (a área atual, mesmo vazia, também consta na lista do Hyprland)
            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId && w.toplevels.values.length > 0)

            Layout.fillHeight: true
            implicitWidth: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
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
                color: ws.isActive ? Theme.accent
                     : ws.containsMouse ? Theme.fgBright
                     : ws.occupied ? Theme.fg : Theme.fgDim
            }

            // Área com janela aberta: linha embaixo do número (na barra flutuante, um pouco mais
            // para dentro, para não encostar no contorno)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.barFloating ? 5 : 3
                anchors.horizontalCenter: parent.horizontalCenter
                height: 2
                radius: 1
                width: ws.occupied ? 14 : 0
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }

            // Área atual: a mesma linha, em cima do número
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: Theme.barFloating ? 5 : 3
                anchors.horizontalCenter: parent.horizontalCenter
                height: 2
                radius: 1
                width: ws.isActive ? 14 : 0
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            const cur = root.activeId > 0 && root.activeId <= root.count ? root.activeId : 1
            const next = event.angleDelta.y > 0 ? ((cur + root.count - 2) % root.count) + 1 : (cur % root.count) + 1
            Hyprland.dispatch("workspace " + next)
        }
    }
}
