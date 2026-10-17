import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Bluetooth. O ícone fica no acento com algum dispositivo conectado. O clique abre o painel para
// ligar, buscar e conectar. Nele, o clique conecta, desconecta ou pareia, e o direito esquece um
// dispositivo pareado. Um pedido de pareamento que precisa de resposta (services/BluetoothAgent.qml)
// abre o painel sozinho, na tela em foco, com o código e os botões Recusar e Aceitar.
BarButton {
    id: root
    required property string screenName

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: adapter
        ? adapter.devices.values.slice().sort((a, b) =>
              (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || ""))
        : []
    readonly property int connectedCount: devices.filter(d => d.connected).length

    icon: Icons.bluetooth
    color: !on ? Theme.fgDim : connectedCount > 0 ? Theme.accent : Theme.fg
    active: popup.visible
    onClicked: Popups.toggle("bluetooth", screenName)

    // Pedido de pareamento que precisa de resposta: abre o painel na tela em foco
    Connections {
        target: BluetoothAgent
        function onAttention() {
            const focused = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name
            if (root.screenName === focused) Popups.open("bluetooth", root.screenName)
        }
    }

    BarPopup {
        id: popup
        target: root
        popupId: "bluetooth"
        screenName: root.screenName
        panelWidth: 340
        onWantedChanged: if (!wanted && root.adapter && root.adapter.discovering) root.adapter.discovering = false

        PopupTitle {
            text: "Bluetooth"
            icon: Icons.bluetooth
            subtitle: !root.adapter ? "Sem adaptador"
                : !root.on ? "Desligado"
                : root.connectedCount > 0
                    ? root.connectedCount + (root.connectedCount === 1 ? " dispositivo conectado" : " dispositivos conectados")
                    : "Ligado"
            PlainButton {
                visible: root.on
                implicitHeight: 26
                icon: Icons.refresh
                text: root.adapter?.discovering ? "Buscando…" : "Buscar"
                onClicked: if (root.adapter) root.adapter.discovering = !root.adapter.discovering
            }
            Toggle {
                enabled: root.adapter !== null
                checked: root.on
                onToggled: value => { if (root.adapter) root.adapter.enabled = value }
            }
        }

        // Pedido do agente de pareamento (services/BluetoothAgent.qml)
        ColumnLayout {
            readonly property var req: BluetoothAgent.request
            readonly property var disp: BluetoothAgent.display
            readonly property string code: req ? req.passkey : disp ? disp.code : ""
            visible: root.on && (req !== null || disp !== null)
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                readonly property string name: BluetoothAgent.deviceName(parent.req ? parent.req.address : parent.disp?.address ?? "")
                text: !parent.req ? "Digite o código abaixo em " + name + " e tecle Enter."
                    : parent.req.kind === "confirm" ? "Confira se " + name + " mostra o mesmo código e aceite."
                    : parent.req.kind === "service" ? name + " quer usar um serviço deste computador."
                    : name + " quer parear com este computador."
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.textBody
                wrapMode: Text.Wrap
            }
            Text {
                visible: parent.code !== ""
                Layout.alignment: Qt.AlignHCenter
                text: parent.code
                color: Theme.fgBright
                font.family: Theme.font
                font.pixelSize: Theme.textBody * 2
                font.bold: true
                font.letterSpacing: 4
            }
            RowLayout {
                visible: parent.req !== null
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                PlainButton {
                    implicitHeight: 26
                    text: "Recusar"
                    onClicked: BluetoothAgent.answer(false)
                }
                PlainButton {
                    implicitHeight: 26
                    text: "Aceitar"
                    highlighted: true
                    onClicked: BluetoothAgent.answer(true)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.on && BluetoothAgent.error !== ""
            text: BluetoothAgent.error === "missing"
                ? "Para parear dispositivos, instale python-dbus e python-gobject."
                : "Agente de pareamento indisponível: " + BluetoothAgent.error
            color: Theme.yellow
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            visible: !root.adapter || !root.on || root.devices.length === 0
            text: !root.adapter ? "Nenhum adaptador encontrado."
                : !root.on ? "Bluetooth desligado."
                : "Nenhum dispositivo por perto."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textBody
            wrapMode: Text.Wrap
        }

        ListView {
            visible: root.on && root.devices.length > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 320)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.on ? root.devices : []

            delegate: MouseArea {
                id: row
                required property var modelData
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                                          || modelData.state === BluetoothDeviceState.Disconnecting
                                          || modelData.pairing

                width: ListView.view.width
                height: 44
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    const d = modelData
                    if (mouse.button === Qt.RightButton) {
                        if (d.paired || d.trusted) d.forget()
                        return
                    }
                    if (d.connected) d.disconnect()
                    else if (!d.paired) BluetoothAgent.pair(d)
                    else d.connect()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: row.containsMouse ? Theme.bgAlt : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Icon {
                        text: Icons.bluetooth
                        color: row.modelData.connected ? Theme.accent : Theme.fgDim
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name || row.modelData.address
                            color: row.modelData.connected ? Theme.fgBright : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.textBody
                            elide: Text.ElideRight
                        }
                        Text {
                            text: row.busy ? "Aguarde…"
                                : row.modelData.connected ? "Conectado"
                                : row.modelData.paired ? "Pareado"
                                : BluetoothAgent.failed[row.modelData.address] ? "Falha ao parear · clique para tentar de novo"
                                : "Clique para parear"
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.textSmall
                        }
                    }

                    Row {
                        visible: row.modelData.batteryAvailable
                        spacing: 3
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.battery
                            color: Theme.fgDim
                            size: Theme.fontSize + 1
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(row.modelData.battery * 100) + "%"
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.textSmall
                        }
                    }
                }
            }
        }

        Text {
            visible: root.on && root.devices.some(d => d.paired)
            text: "Botão direito sobre um pareado para esquecê-lo."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
        }
    }
}
