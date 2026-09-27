import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Aviso rápido (OSD) no centro/baixo da tela, no monitor em foco: ícone, barra e porcentagem para
// volume e brilho; ícone e texto para Caps Lock e Num Lock. Não recebe cliques nem teclado.
PanelWindow {
    id: win

    readonly property bool level: Osd.kind === "volume" || Osd.kind === "brightness"
    readonly property real value: Osd.kind === "volume" ? Osd.volume : Osd.brightness
    readonly property bool dim: Osd.kind === "volume" && Osd.muted

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors.bottom: true
    margins.bottom: 64
    exclusionMode: ExclusionMode.Normal   // com a barra embaixo, fica acima dela
    implicitWidth: Theme.snapUp(frame.implicitWidth, devicePixelRatio)
    implicitHeight: Theme.snapUp(frame.implicitHeight, devicePixelRatio)
    color: "transparent"
    visible: frame.opacity > 0
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "kortex-osd"

    GradientFrame {
        id: frame
        width: win.implicitWidth
        height: win.implicitHeight
        implicitWidth: win.level ? 280 : row.implicitWidth + 36
        implicitHeight: 44
        radius: height / 2
        opacity: Osd.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Osd.active ? 120 : 250; easing.type: Easing.OutQuad } }

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 12

            Icon {
                text: Osd.kind === "volume" ? (Osd.muted || Osd.volume <= 0 ? Icons.volMute : Osd.volume > 0.5 ? Icons.volHigh : Icons.volLow)
                    : Osd.kind === "brightness" ? Icons.sun
                    : Osd.kind === "caps" ? Icons.capsLock : Icons.numLock
                color: win.dim ? Theme.fgDim : Theme.accent
                size: Theme.iconSize + 2
            }

            // Volume e brilho: barra e porcentagem
            Rectangle {
                visible: win.level
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.bgAlt

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, win.value))
                    height: parent.height
                    radius: parent.radius
                    color: win.dim ? Theme.fgDim : Theme.accent
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }

            Text {
                visible: win.level
                Layout.preferredWidth: pctMetrics.width
                horizontalAlignment: Text.AlignRight
                text: Math.round(win.value * 100) + "%"
                color: win.dim ? Theme.fgDim : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                TextMetrics { id: pctMetrics; font.family: Theme.font; font.pixelSize: Theme.fontSize; text: "100%" }
            }

            // Caps Lock e Num Lock: nome e estado
            Text {
                visible: !win.level
                text: (Osd.kind === "caps" ? "Caps Lock " + (Osd.capsLock ? "ativado" : "desativado")
                                            : "Num Lock " + (Osd.numLock ? "ativado" : "desativado"))
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
