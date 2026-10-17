import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Rede (Wi-Fi ou cabo). O clique abre o painel com a conexão em uso (endereços e dados da sessão)
// e as redes Wi-Fi. Nele, o clique conecta ou desconecta e o direito esquece uma rede salva. O
// clique direito no ícone abre o editor de conexões (modules/network/NetworkSettings.qml).
BarButton {
    id: root
    required property string screenName

    readonly property var net: Network.active
    property bool tsExpanded: false   // lista de dispositivos do Tailscale aberta
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
                Tailscale.error = ""
                root.tsExpanded = false
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

        // Conexão em uso: cabeçalho (rede, interface e sinal) e um bloco por dado: primeiro os dados
        // recebidos e enviados nesta sessão (ao vivo), depois os endereços; o IPv6 só aparece se
        // houver um endereço global e ocupa a linha inteira
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
                                { icon: Icons.received, label: "Recebidos", traffic: "rx" },
                                { icon: Icons.sent, label: "Enviados", traffic: "tx" },
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
                                    text: tileBox.modelData.traffic === "rx" ? Network.bytes(Network.sessionRx)
                                        : tileBox.modelData.traffic === "tx" ? Network.bytes(Network.sessionTx)
                                        : tileBox.modelData.value || "—"
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

        // ── Tailscale ──────────────────────────────────────────────────
        // Estado, interruptor (tailscale up/down) e os dispositivos da tailnet, este computador
        // primeiro e depois os online; clicar numa linha copia o IP. A lista começa recolhida a cada
        // abertura do painel (clique no cabeçalho para ver), para o painel não crescer demais
        Rectangle {
            visible: Tailscale.installed
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.muted
        }

        MouseArea {
            id: tsHead
            visible: Tailscale.installed
            Layout.fillWidth: true
            implicitHeight: tsHeadRow.implicitHeight + 12
            hoverEnabled: true
            readonly property bool expandable: Tailscale.running && tsList.count > 0
            cursorShape: expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (expandable) root.tsExpanded = !root.tsExpanded

            readonly property bool on: Tailscale.running || Tailscale.backendState === "Starting"
            readonly property int onlineCount: Tailscale.peers.filter(p => p.online).length

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: tsHead.expandable && tsHead.containsMouse ? Theme.bgAlt : "transparent"
            }

            RowLayout {
                id: tsHeadRow
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 10

                Icon {
                    text: Icons.tailscale
                    color: tsHead.on ? Theme.accent : Theme.fgDim
                    size: Theme.iconSize
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Tailscale"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.textBody
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: !Tailscale.daemonRunning ? (Tailscale.busy ? "Iniciando o serviço…" : "Serviço parado")
                            : Tailscale.busy ? (tsHead.on ? "Conectando…" : "Desconectando…")
                            : Tailscale.running ? "Conectado · " + tsHead.onlineCount + " de " + Tailscale.peers.length + " online"
                            : Tailscale.backendState === "NeedsLogin" ? "É preciso entrar na conta"
                            : Tailscale.backendState === "NeedsMachineAuth" ? "Aguardando aprovação no painel"
                            : Tailscale.backendState === "Starting" ? "Conectando…"
                            : "Desligado"
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.textSmall
                        elide: Text.ElideRight
                    }
                }
                PlainButton {
                    visible: Tailscale.backendState === "NeedsLogin" && !Tailscale.busy
                    implicitHeight: 26
                    text: "Entrar"
                    onClicked: Tailscale.authUrl ? Qt.openUrlExternally(Tailscale.authUrl) : Tailscale.setRunning(true)
                }
                Icon {
                    visible: tsHead.expandable
                    text: root.tsExpanded ? Icons.up : Icons.down
                    color: Theme.fgDim
                    size: Theme.iconSize
                }
                Toggle {
                    checked: tsHead.on
                    enabled: !Tailscale.busy
                    opacity: enabled ? 1 : 0.5
                    onToggled: value => Tailscale.setRunning(value)
                }
            }
        }

        ListView {
            id: tsList
            visible: root.tsExpanded && Tailscale.installed && Tailscale.running && count > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 240)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Tailscale.running
                ? (Tailscale.self ? [Object.assign({ isSelf: true, online: true }, Tailscale.self)] : []).concat(Tailscale.peers)
                : []

            property string copied: ""   // nome da linha cujo IP acabou de ser copiado
            Timer {
                id: copiedReset
                interval: 1400
                onTriggered: tsList.copied = ""
            }

            delegate: MouseArea {
                id: peer
                required property var modelData
                readonly property var p: modelData
                readonly property bool justCopied: tsList.copied === p.name

                width: ListView.view.width
                height: 40
                hoverEnabled: true
                cursorShape: p.ip ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!p.ip) return
                    Tailscale.copy(p.ip)
                    tsList.copied = p.name
                    copiedReset.restart()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: peer.p.isSelf ? Theme.selectionTint : (peer.containsMouse ? Theme.bgAlt : "transparent")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Icon {
                        text: Tailscale.deviceIcon(peer.p)
                        color: peer.p.online ? Theme.accent : Theme.fgDim
                        size: Theme.iconSize
                        // no desenho padrão do Qt, o contorno esquerdo do celular saía borrado a 1,25×
                        renderType: Text.NativeRendering
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: peer.p.name
                            color: peer.p.online ? Theme.fg : Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.textBody
                            font.bold: peer.p.isSelf === true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            // offline: só quando foi visto (com o sistema junto não cabe ao lado do IP)
                            text: peer.p.isSelf ? "Este computador"
                                : !peer.p.online ? (peer.p.lastSeen ? "Visto " + Tailscale.ago(peer.p.lastSeen) : "Offline")
                                : [Tailscale.osLabel(peer.p.os),
                                   peer.p.exitNode ? "saída para a internet"
                                       : peer.p.active ? (peer.p.direct ? "conexão direta" : "via relay")
                                       : ""].filter(x => x).join(" · ")
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.textSmall
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        text: peer.justCopied ? "Copiado" : peer.p.ip
                        color: peer.justCopied ? Theme.accent : (peer.p.online ? Theme.fg : Theme.fgDim)
                        font.family: Theme.font
                        font.pixelSize: Theme.textSmall
                    }
                    Icon {
                        // opacidade, e não visible: o espaço fica reservado e o IP não pula
                        opacity: peer.containsMouse && !peer.justCopied && peer.p.ip !== "" ? 1 : 0
                        text: Icons.copy
                        color: Theme.fgDim
                        size: Theme.fontSize
                    }
                }
            }
        }

        Text {
            visible: Tailscale.error !== ""
            Layout.fillWidth: true
            text: Tailscale.error
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
