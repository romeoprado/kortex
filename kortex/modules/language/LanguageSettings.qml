import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Teclado (layouts e atalho) e idioma do sistema.
// Vive numa PanelWindow com foco exclusivo porque popups da barra não recebem o teclado.
//   Esc fecha
LazyLoader {
    active: Popups.languageOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-language"
        panelWidth: Math.min(900, (win.screen?.width ?? 1280) - 80)
        panelHeight: Math.min(540, (win.screen?.height ?? 800) - 100)
        onDismissed: close()

        function close() { Popups.languageOpen = false }

        Component.onCompleted: {
            Keyboard.refresh()
            Language.refresh()
        }

        GradientFrame {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            focus: true
            Keys.onEscapePressed: win.close()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PlainButton {
                        icon: Icons.keyboard
                        text: "Teclado"
                        highlighted: Popups.languageTab === "keyboard"
                        onClicked: Popups.languageTab = "keyboard"
                    }
                    PlainButton {
                        icon: Icons.globe
                        text: "Idioma"
                        highlighted: Popups.languageTab === "language"
                        onClicked: Popups.languageTab = "language"
                    }

                    Item { Layout.fillWidth: true }

                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: win.close()
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: Popups.languageTab === "language" ? 1 : 0

                    KeyboardPage { onCloseRequested: win.close() }
                    LanguagePage { onCloseRequested: win.close() }
                }
            }
        }
    }
}
