import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Janela para digitar a cidade da previsão do tempo.
// Os popups da barra (PopupWindow) não recebem o teclado do Wayland, então o campo
// vive numa PanelWindow com foco exclusivo, como o lançador.
//   Enter salva · Esc cancela · vazio = detectar pela conexão
LazyLoader {
    active: Popups.cityPromptOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-city"
        panelWidth: 460
        panelHeight: frame.implicitHeight
        onDismissed: close()

        function close() { Popups.cityPromptOpen = false }
        function save(city) {
            Settings.data.weatherCity = city.trim()
            close()
        }

        Component.onCompleted: field.focusInput()


        GradientFrame {
            id: frame
            width: win.panelWidth
            implicitHeight: column.implicitHeight + 40
            color: Theme.bg
            radius: Theme.radius
            focus: true
            Keys.onEscapePressed: win.close()

            ColumnLayout {
                id: column
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 12

                PopupTitle {
                    icon: Icons.location
                    text: "Cidade da previsão do tempo"
                }

                Field {
                    id: field
                    icon: Icons.location
                    placeholder: "Ex.: Belo Horizonte, Minas Gerais"
                    text: Settings.data.weatherCity
                    onAccepted: win.save(text)
                }

                Text {
                    Layout.fillWidth: true
                    text: "Use \"Cidade, Estado\" para desempatar nomes repetidos. Vazio detecta pela sua conexão."
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PlainButton {
                        text: "Automática"
                        onClicked: win.save("")
                    }

                    Item { Layout.fillWidth: true }

                    PlainButton {
                        text: "Cancelar (Esc)"
                        onClicked: win.close()
                    }

                    PlainButton {
                        highlighted: true
                        text: "Salvar (Enter)"
                        onClicked: win.save(field.text)
                    }
                }
            }
        }
    }
}
