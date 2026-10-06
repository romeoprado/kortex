import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.widgets

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
                        if (d.paired) d.forget()
                        return
                    }
                    if (d.connected) d.disconnect()
                    else if (!d.paired) { d.trusted = true; d.pair() }
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
                                : row.modelData.paired ? "Pareado" : "Clique para parear"
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
