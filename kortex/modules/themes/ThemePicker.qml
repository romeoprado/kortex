import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Seletor de temas e papéis de parede
LazyLoader {
    active: Popups.themePickerOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-themes"
        panelWidth: Math.min(1040, (win.screen?.width ?? 1280) - 80)
        // Alto o bastante para duas fileiras inteiras de temas, sem rolar (a mesma conta da grade da aba
        // Temas: colunas de ~240 px, cartão 16:9 + 44 px de rodapé), sem passar do limite da tela.
        // Soma: margens (18 + 18), abas (32), espaço (14), linha da pasta da aba Papéis de Parede (34),
        // espaço (12) e as duas fileiras.
        readonly property int themeRowHeight: {
            const w = panelWidth - 36
            const cw = Math.floor(w / Math.max(1, Math.floor(w / 240)))
            return Math.round(cw * 0.5625) + 44
        }
        panelHeight: Math.min(36 + 32 + 14 + 34 + 12 + 2 * themeRowHeight, (win.screen?.height ?? 800) - 120)
        onDismissed: close()

        function close() { Popups.themePickerOpen = false }

        Component.onCompleted: {
            Theme.status = ""
            Theme.refresh()
            Theme.listWallpapers()
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
                        icon: Icons.brush
                        text: "Temas"
                        highlighted: Popups.pickerTab === "themes"
                        onClicked: Popups.pickerTab = "themes"
                    }
                    PlainButton {
                        icon: Icons.image
                        text: "Papéis de Parede"
                        highlighted: Popups.pickerTab === "wallpapers"
                        onClicked: Popups.pickerTab = "wallpapers"
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        text: Theme.status
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: win.close()
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: Popups.pickerTab === "wallpapers" ? 1 : 0

                    ThemesPage { onCloseRequested: win.close() }
                    WallpapersPage { onCloseRequested: win.close() }
                }
            }
        }
    }
}
