import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

// Menu da captura de tela (a tecla Print): Tela Inteira (o monitor em que o menu abriu), Janela
// (clique numa janela) ou Área (arraste um retângulo). Depois da captura abre a janela de salvar.
//   1, 2, 3 escolhem · Esc fecha
LazyLoader {
    active: Popups.screenshotOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-screenshot"
        panelWidth: 420
        panelHeight: frame.implicitHeight
        onDismissed: close()

        readonly property var modes: [
            { id: "screen", icon: Icons.shotScreen, text: "Tela Inteira" },
            { id: "window", icon: Icons.shotWindow, text: "Janela" },
            { id: "area", icon: Icons.shotArea, text: "Área" }
        ]

        function close() { Popups.screenshotOpen = false }

        GradientFrame {
            id: frame
            width: win.panelWidth
            implicitHeight: column.implicitHeight + 40
            color: Theme.bg
            radius: Theme.radius
            focus: true
            Keys.onEscapePressed: win.close()
            Keys.onPressed: event => {
                const i = event.key - Qt.Key_1
                if (i >= 0 && i < win.modes.length) {
                    Screenshot.capture(win.modes[i].id)
                    event.accepted = true
                }
            }

            ColumnLayout {
                id: column
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 14

                PopupTitle {
                    icon: Icons.screenshot
                    text: "Captura de Tela"

                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: win.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: win.modes

                        TileButton {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: modelData.icon
                            text: modelData.text
                            onClicked: Screenshot.capture(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
