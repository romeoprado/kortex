import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Janela de teste da tela: mantém a nova configuração ou volta à anterior.
//   Enter mantém · Esc reverte · sem resposta, reverte sozinha.
// Também mostra o erro quando o Hyprland recusa a configuração.
LazyLoader {
    active: Monitors.pending || Monitors.error !== ""

    PanelWindow {
        id: win

        readonly property var mon: Monitors.byName(Monitors.pendingName)
        readonly property bool failed: Monitors.error !== ""

        function accept() { if (failed) Monitors.dismissError(); else Monitors.confirm() }
        function reject() { if (failed) Monitors.dismissError(); else Monitors.revert() }

        screen: Quickshell.screens.find(s => s.name === Monitors.pendingName) ?? Quickshell.screens[0]
        implicitWidth: Theme.snapUp(420, devicePixelRatio)
        implicitHeight: Theme.snapUp(frame.implicitHeight, devicePixelRatio)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kortex-display-confirm"

        Component.onCompleted: frame.forceActiveFocus()

        GradientFrame {
            id: frame
            width: win.implicitWidth
            height: win.implicitHeight
            implicitHeight: column.implicitHeight + 40
            color: Theme.bg
            radius: Theme.radius
            borderColor: win.failed ? Theme.red : Theme.borderColor
            focus: true

            Keys.onReturnPressed: win.accept()
            Keys.onEnterPressed: win.accept()
            Keys.onEscapePressed: win.reject()

            ColumnLayout {
                id: column
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 12

                PopupTitle {
                    icon: win.failed ? Icons.warning : Icons.display
                    tone: win.failed ? Theme.red : Theme.accent
                    titleColor: win.failed ? Theme.red : Theme.fgBright
                    text: win.failed ? "Não foi possível aplicar" : "Manter esta configuração?"
                }

                Text {
                    Layout.fillWidth: true
                    text: win.failed ? Monitors.error
                        : win.mon ? win.mon.name + " · " + Monitors.describe(win.mon) : Monitors.pendingName
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    wrapMode: Text.Wrap
                }

                ColumnLayout {
                    visible: !win.failed
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: "Voltando ao modo anterior em " + Monitors.secondsLeft + " s"
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.textSmall
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Theme.bgAlt

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                            width: parent.width * Math.max(0, Monitors.secondsLeft - 1) / (Monitors.confirmSeconds - 1)
                            Behavior on width { NumberAnimation { duration: 1000 } }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    PlainButton {
                        visible: !win.failed
                        text: "Reverter (Esc)"
                        onClicked: win.reject()
                    }

                    PlainButton {
                        highlighted: true
                        text: win.failed ? "Fechar" : "Manter (Enter)"
                        onClicked: win.accept()
                    }
                }
            }
        }
    }
}
