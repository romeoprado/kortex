import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName

    readonly property var net: Network.active
    icon: Network.wiredName !== "" && !net ? Icons.ethernet : Icons.wifi
    color: (net || Network.wiredName !== "") ? Theme.fg : Theme.fgDim
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) Popups.openNetworkSettings("")
        else Popups.toggle("network", screenName)
    }

    BarPopup {
        id: popup
        target: root
        popupId: "network"
        screenName: root.screenName
        panelWidth: 340
        onWantedChanged: {
            if (wanted) {
                Network.error = ""
                Network.rescan()
            }
        }

        PopupTitle {
            text: "Rede"
            icon: Network.wiredName !== "" && !root.net ? Icons.ethernet : Icons.wifi
            // Só o estado (o nome da rede já aparece na lista): conectado por Wi-Fi ou cabo, Wi-Fi desligado
            // sem nada conectado, ou desconectado
            subtitle: root.net || Network.wiredName !== "" ? "Conectado"
                : Network.hasWifi && !Network.wifiEnabled ? "Desligado"
                : "Desconectado"
            PlainButton {
                visible: Network.hasWifi && Network.wifiEnabled
                implicitHeight: 26
                icon: Icons.refresh
                text: Network.scanning ? "Buscando…" : "Buscar"
                onClicked: Network.rescan()
            }
            Toggle {
                visible: Network.hasWifi
                checked: Network.wifiEnabled
                onToggled: value => Network.setWifi(value)
            }
        }

        // Conexão em uso: cabeçalho (rede, interface e sinal) e um bloco por dado; o IPv6 só aparece
        // se houver um endereço global e ocupa a linha inteira
        GradientBorder {
            id: info
            readonly property var c: Network.current
            readonly property bool wifi: c !== null && c.type === "wifi"
            visible: c !== null
            Layout.fillWidth: true
            implicitHeight: infoCol.implicitHeight + 24
            radius: Theme.radiusSmall
            borderWidth: 1
            fill: Theme.bgAlt
            color: Qt.alpha(Theme.accent, 0.35)

            ColumnLayout {
                id: infoCol
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Ícone num círculo tingido do acento
                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 17
                        color: Qt.alpha(Theme.accent, 0.16)
                        Icon {
                            anchors.centerIn: parent
                            text: info.wifi ? Icons.wifi : Icons.ethernet
                            color: Theme.accent
                            size: Theme.iconSize + 2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: info.c ? info.c.name || info.c.device : ""
                            color: Theme.fgBright
                            font.family: Theme.font
                            font.pixelSize: Theme.textBody
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: info.c ? info.c.device + " · " + (info.wifi ? "Wi-Fi" : "Cabo") : ""
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.textSmall
                            elide: Text.ElideRight
                        }
                    }

                    // Sinal do Wi-Fi em uso
                    Rectangle {
                        visible: info.wifi && root.net !== null
                        implicitWidth: signalText.implicitWidth + 16
                        implicitHeight: signalText.implicitHeight + 6
                        radius: height / 2
                        color: Qt.alpha(Theme.accent, 0.16)
                        Text {
                            id: signalText
                            anchors.centerIn: parent
                            text: root.net ? root.net.signal + "%" : ""
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.textSmall
                            font.bold: true
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 6
                    rowSpacing: 6

                    Repeater {
                        model: {
                            const c = info.c
                            if (!c) return []
                            const rows = [
                                { icon: Icons.ipAddress, label: "IP", value: c.ip },
                                { icon: Icons.gateway, label: "Gateway", value: c.gateway },
                                { icon: Icons.dns, label: "DNS", value: c.dns },
                                { icon: Icons.mac, label: "MAC", value: c.mac }
                            ]
                            if (c.ipv6) rows.push({ icon: Icons.ipv6, label: "IPv6", value: c.ipv6, wide: true })
                            return rows
                        }

                        Rectangle {
                            id: tileBox
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1   // colunas iguais
                            Layout.columnSpan: tileBox.modelData.wide ? 2 : 1
                            implicitHeight: tile.implicitHeight + 14
                            radius: Theme.radiusSmall
                            color: Theme.bg

                            ColumnLayout {
                                id: tile
                                x: 9
                                y: 7
                                width: parent.width - 18
                                spacing: 2

                                RowLayout {
                                    spacing: 5
                                    Icon {
                                        text: tileBox.modelData.icon
                                        color: Theme.accent
                                        size: Theme.fontSize
                                    }
                                    Text {
                                        text: tileBox.modelData.label
                                        color: Theme.fgDim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSmall
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: tileBox.modelData.value || "—"
                                    color: Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textSmall
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            visible: Network.wiredName !== ""
            Layout.fillWidth: true
            implicitHeight: 30
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Popups.openNetworkSettings(Network.wiredName)

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: parent.containsMouse ? Theme.bgAlt : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 10
                Icon { text: Icons.ethernet; color: Theme.accent }
                Text {
                    Layout.fillWidth: true
                    text: "Cabo: " + Network.wiredName
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    elide: Text.ElideRight
                }
                Text {
                    text: "Configurar"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                }
            }
        }

        Text {
            Layout.fillWidth: true
            // Sem placa Wi-Fi não há aviso: o painel mostra só a conexão em uso
            visible: Network.hasWifi && (!Network.wifiEnabled || Network.networks.length === 0)
            text: !Network.wifiEnabled ? "Wi-Fi desligado." : "Nenhuma rede encontrada ainda."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textBody
            wrapMode: Text.Wrap
        }

        ListView {
            id: list
            visible: Network.wifiEnabled && Network.networks.length > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 300)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Network.wifiEnabled ? Network.networks : []

            delegate: MouseArea {
                id: row
                required property var modelData
                readonly property bool isConnecting: Network.connecting === modelData.ssid

                width: ListView.view.width
                height: 38
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    const n = modelData
                    if (mouse.button === Qt.RightButton) {
                        if (Network.isKnown(n.ssid)) Network.forget(n.ssid)
                        return
                    }
                    if (n.active) Network.disconnect(n.ssid)
                    else if (n.secure && !Network.isKnown(n.ssid)) Popups.openNetworkPrompt(n.ssid)
                    else Network.connect(n.ssid, "")
                }

                // Rede conectada: fundo no acento e tudo em Theme.accentText por cima, como os chips selecionados
                // (Theme.selection não serve: em alguns temas é igual ao acento e apagava o ícone e o texto)
                readonly property color onRow: modelData.active ? Theme.accentText : Theme.fg
                readonly property color onRowDim: modelData.active ? Theme.accentText : Theme.fgDim

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: row.modelData.active ? Theme.accent : (row.containsMouse ? Theme.bgAlt : "transparent")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Icon {
                        text: Icons.wifi
                        opacity: row.modelData.active ? 1 : 0.35 + 0.65 * row.modelData.signal / 100
                        color: row.onRow
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.ssid
                        color: row.onRow
                        font.family: Theme.font
                        font.pixelSize: Theme.textBody
                        font.bold: row.modelData.active
                        elide: Text.ElideRight
                    }
                    Text {
                        text: row.isConnecting ? "Conectando…"
                            : row.modelData.active ? (row.containsMouse ? "Desconectar" : "Conectado")
                            : row.modelData.signal + "%"
                        color: row.onRowDim
                        font.family: Theme.font
                        font.pixelSize: Theme.textSmall
                    }
                    // Cadeado fechado com senha, aberto sem senha (rede sem proteção)
                    Icon {
                        text: row.modelData.secure ? Icons.lock : Icons.lockOpen
                        color: row.onRowDim
                        size: Theme.fontSize
                    }
                }
            }
        }

        Text {
            visible: Network.error !== ""
            Layout.fillWidth: true
            text: Network.error
            color: Theme.red
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            wrapMode: Text.Wrap
        }

        PlainButton {
            Layout.fillWidth: true
            icon: Icons.cog
            text: "Configurações de Rede"
            onClicked: Popups.openNetworkSettings("")
        }
    }
}
