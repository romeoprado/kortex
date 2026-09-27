import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Configurações gerais do Kortex: aparência, barra, aplicativos padrão, sessão e outras opções.
// Abre pelo lançador (botão de engrenagem ou digitando "config") ou por
//   qs -c kortex ipc call settings toggle
// Vive numa janela com foco exclusivo, como as outras (popups da barra não recebem o teclado).
//   Esc fecha
LazyLoader {
    active: Popups.settingsOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-settings"
        panelWidth: Math.min(940, (win.screen?.width ?? 1280) - 80)
        panelHeight: Math.min(680, (win.screen?.height ?? 800) - 100)
        onDismissed: close()

        readonly property var pages: [
            { id: "appearance", icon: Icons.brush, text: "Aparência" },
            { id: "bar", icon: Icons.bars, text: "Barra" },
            { id: "apps", icon: Icons.apps, text: "Aplicativos" },
            { id: "power", icon: Icons.session, text: "Sessão" },
            { id: "general", icon: Icons.sliders, text: "Geral" },
            { id: "about", icon: Icons.info, text: "Sobre" }
        ]
        readonly property int pageIndex: Math.max(0, pages.findIndex(p => p.id === Popups.settingsPage))

        function close() { Popups.settingsOpen = false }

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

                PopupTitle {
                    icon: Icons.sliders
                    text: "Configurações do Kortex"

                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: win.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 18

                    ColumnLayout {
                        Layout.preferredWidth: 180
                        Layout.maximumWidth: 180
                        Layout.fillHeight: true
                        spacing: 6

                        Repeater {
                            model: win.pages.filter(p => p.id !== "about")

                            PlainButton {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 38
                                alignLeft: true
                                icon: modelData.icon
                                text: modelData.text
                                highlighted: Popups.settingsPage === modelData.id
                                onClicked: Popups.settingsPage = modelData.id
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // "Sobre" fica separado, no pé da lista
                        PlainButton {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            alignLeft: true
                            icon: Icons.info
                            text: "Sobre"
                            highlighted: Popups.settingsPage === "about"
                            onClicked: Popups.settingsPage = "about"
                        }
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        implicitWidth: 1
                        color: Theme.muted
                        opacity: 0.5
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: win.pageIndex

                        AppearancePage {}
                        BarPage {}
                        AppsPage {}
                        PowerPage {}
                        GeneralPage {}
                        AboutPage {}
                    }
                }
            }
        }
    }
}
