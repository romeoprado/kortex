import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Senha de uma rede Wi-Fi nova.
// Popups da barra não recebem o teclado do Wayland, então o campo vive numa PanelWindow
// com foco exclusivo. A janela fica aberta enquanto conecta e só fecha se der certo;
// se falhar, mostra o motivo e deixa tentar de novo.
//   Enter conecta · Esc cancela
LazyLoader {
    active: Popups.networkPromptSsid !== ""

    OverlayPanel {
        id: win

        readonly property string ssid: Popups.networkPromptSsid
        property bool busy: false
        property bool showPassword: false

        layerNamespace: "kortex-network-prompt"
        panelWidth: 460
        panelHeight: frame.implicitHeight
        onDismissed: close()

        function close() { Popups.networkPromptSsid = "" }

        function submit() {
            if (busy || field.text === "") return
            busy = true
            Network.connect(ssid, field.text)
        }

        Component.onCompleted: {
            Network.error = ""
            field.focusInput()
        }

        Connections {
            target: Network
            function onConnectingChanged() {
                if (!win.busy || Network.connecting !== "") return
                if (Network.lastConnectOk) {
                    win.close()
                } else {
                    win.busy = false
                    field.focusInput()
                    field.input.selectAll()
                }
            }
        }


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
                    icon: Icons.wifi
                    text: "Conectar a “" + win.ssid + "”"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Field {
                        id: field
                        enabled: !win.busy
                        icon: Icons.lock
                        echoMode: win.showPassword ? TextInput.Normal : TextInput.Password
                        placeholder: "Senha da rede"
                        onAccepted: win.submit()
                    }

                    PlainButton {
                        text: win.showPassword ? "Ocultar" : "Mostrar"
                        onClicked: {
                            win.showPassword = !win.showPassword
                            field.focusInput()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: win.busy || Network.error !== ""
                    text: win.busy ? "Conectando…" : Network.error
                    color: win.busy ? Theme.fgDim : Theme.red
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    PlainButton {
                        text: "Cancelar (Esc)"
                        onClicked: win.close()
                    }

                    PlainButton {
                        highlighted: true
                        enabled: !win.busy && field.text !== ""
                        text: "Conectar (Enter)"
                        onClicked: win.submit()
                    }
                }
            }
        }
    }
}
