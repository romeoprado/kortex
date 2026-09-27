import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Editor de conexões de rede (substitui o nm-connection-editor).
// Lista os perfis de Wi-Fi e cabo; à direita edita o selecionado: conectar automaticamente,
// senha do Wi-Fi, IPv4 (DHCP ou manual: endereço, máscara, gateway), DNS e IPv6.
// Vive numa PanelWindow com foco exclusivo porque popups da barra não recebem o teclado.
//   Esc fecha · Tab troca de campo · Enter aplica
LazyLoader {
    active: Popups.networkSettingsOpen

    OverlayPanel {
        id: win

        // Seleção e formulário. ipv4Method/ipv6Method vazios = método que não editamos aqui.
        property string sel: ""
        property string ipv4Method: "auto"
        property string ipv6Method: "auto"
        property bool autoconnect: true
        property bool showPassword: false
        property bool confirmForget: false
        property string formError: ""
        property var extraAddresses: []   // endereços além do primeiro: preservados ao salvar

        readonly property var conn: Network.connections.find(c => c.name === sel) ?? null
        readonly property var d: Network.details
        readonly property bool wifi: d !== null && d.type === "wifi"
        readonly property bool saving: Network.saveState === "saving"

        layerNamespace: "kortex-network-settings"
        panelWidth: Math.min(820, (win.screen?.width ?? 1280) - 80)
        panelHeight: Math.min(720, (win.screen?.height ?? 800) - 100)
        onDismissed: close()

        component Label: Text {
            Layout.fillWidth: true
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        component Caption: Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }

        component Section: Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            color: Theme.fgBright
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
        }

        function close() { Popups.networkSettingsOpen = false }

        // ── validação ──────────────────────────────────────────────────
        function isIPv4(s) {
            const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(s)
            return !!m && m.slice(1).every(x => Number(x) <= 255)
        }

        // "24" ou "255.255.255.0" → 24; inválido → -1
        function prefixOf(s) {
            if (/^\d{1,2}$/.test(s)) {
                const n = Number(s)
                return n >= 1 && n <= 32 ? n : -1
            }
            if (!isIPv4(s)) return -1
            const bits = s.split(".").map(o => Number(o).toString(2).padStart(8, "0")).join("")
            if (!/^1+0*$/.test(bits)) return -1
            const zero = bits.indexOf("0")
            return zero < 0 ? 32 : zero
        }

        // → { settings } ou { error }
        function collect() {
            const s = { autoconnect: autoconnect, ipv4Method: ipv4Method, ipv6Method: ipv6Method,
                        addresses: [], gateway: "", dns: [], password: "" }
            if (ipv4Method === "manual") {
                const ip = addr.text.trim()
                if (!isIPv4(ip)) return { error: "Endereço IP inválido." }
                const p = prefixOf(mask.text.trim())
                if (p < 0) return { error: "Máscara ou prefixo inválido (ex.: 24 ou 255.255.255.0)." }
                const g = gw.text.trim()
                if (g !== "" && !isIPv4(g)) return { error: "Gateway inválido." }
                s.addresses = [ip + "/" + p].concat(extraAddresses)
                s.gateway = g
            }
            if (ipv4Method !== "") {
                const list = dns.text.split(/[\s,;]+/).filter(x => x)
                if (!list.every(isIPv4)) return { error: "DNS inválido. Use endereços IPv4 separados por vírgula." }
                s.dns = list
            }
            if (wifi && d.keyMgmt !== "" && pass.text !== "") {
                const p = pass.text
                if ((d.keyMgmt === "wpa-psk" || d.keyMgmt === "sae") && (p.length < 8 || p.length > 63))
                    return { error: "A senha WPA precisa ter de 8 a 63 caracteres." }
                s.password = p
            }
            return { settings: s }
        }

        // ── ações ──────────────────────────────────────────────────────
        function select(name) {
            sel = name
            confirmForget = false
            formError = ""
            Network.loadDetails(name)
        }

        function selectDefault() {
            const list = Network.connections
            if (list.length === 0) return
            const c = list.find(x => x.name === Popups.networkSettingsTarget)
                ?? list.find(x => x.active) ?? list[0]
            select(c.name)
        }

        // Copia o perfil carregado para os campos
        function fill() {
            formError = ""
            const p = Network.details
            if (!p || p.name !== sel) return
            ipv4Method = p.ipv4Method === "auto" || p.ipv4Method === "manual" ? p.ipv4Method : ""
            ipv6Method = p.ipv6Method === "auto" ? "auto"
                       : (p.ipv6Method === "disabled" || p.ipv6Method === "ignore") ? "disabled" : ""
            autoconnect = p.autoconnect
            const first = (p.addresses[0] || "").split("/")
            addr.text = first[0] || ""
            mask.text = first[1] || ""
            extraAddresses = p.addresses.slice(1)
            gw.text = p.gateway
            dns.text = p.dns.join(", ")
            pass.text = ""
        }

        function apply() {
            if (!conn || !d || saving) return
            const r = collect()
            if (r.error) {
                formError = r.error
                return
            }
            formError = ""
            Network.saveConnection(sel, r.settings, conn.active)
        }

        // Rola até o campo que ganhou foco (Tab)
        function reveal(item) {
            const y = item.mapToItem(form, 0, 0).y
            if (y < scroller.contentY) scroller.contentY = Math.max(0, y - 8)
            else if (y + item.height > scroller.contentY + scroller.height)
                scroller.contentY = y + item.height - scroller.height + 8
        }

        Component.onCompleted: {
            Network.refresh()
            selectDefault()
        }

        Connections {
            target: Network
            function onConnectionsChanged() {
                if (!Network.connections.some(c => c.name === win.sel)) win.selectDefault()
            }
            function onDetailsChanged() { win.fill() }
        }

        Timer {
            id: forgetTimer
            interval: 3000
            onTriggered: win.confirmForget = false
        }


        GradientFrame {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            focus: true
            Keys.onEscapePressed: win.close()

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                // ── lista de conexões ─────────────────────────────────
                ColumnLayout {
                    // largura fixa: um layout aninhado não respeita só o preferredWidth
                    Layout.preferredWidth: 220
                    Layout.minimumWidth: 220
                    Layout.maximumWidth: 220
                    Layout.fillHeight: true
                    spacing: 10

                    PopupTitle {
                        icon: Icons.globe
                        text: "Conexões"
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: Network.connections

                        delegate: MouseArea {
                            id: row
                            required property var modelData
                            width: ListView.view.width
                            height: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.select(modelData.name)

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: row.modelData.name === win.sel ? Theme.selection
                                     : row.containsMouse ? Theme.bgAlt : "transparent"
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Icon {
                                    text: row.modelData.type === "wifi" ? Icons.wifi : Icons.ethernet
                                    color: row.modelData.active ? Theme.accent : Theme.fgDim
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    color: row.modelData.name === win.sel ? Theme.fgBright : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: row.modelData.active
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: row.modelData.active
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Theme.green
                                }
                            }
                        }
                    }

                    Text {
                        visible: Network.connections.length === 0
                        Layout.fillWidth: true
                        text: "Nenhuma conexão salva."
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    PlainButton {
                        Layout.fillWidth: true
                        text: "Fechar (Esc)"
                        onClicked: win.close()
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: Theme.muted
                }

                // ── formulário ────────────────────────────────────────
                Flickable {
                    id: scroller
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: form.implicitHeight + 8
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        visible: win.conn === null
                        text: "Selecione uma conexão."
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    ColumnLayout {
                        id: form
                        visible: win.conn !== null
                        width: scroller.width - 12
                        spacing: 10

                        // cabeçalho
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: win.conn ? win.conn.name : ""
                                    color: Theme.fgBright
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 4
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: !win.conn ? ""
                                        : (win.conn.type === "wifi" ? "Wi-Fi" : "Cabo")
                                          + (win.conn.active ? " · conectado" + (win.conn.device ? " em " + win.conn.device : "") : " · desconectado")
                                    color: win.conn && win.conn.active ? Theme.green : Theme.fgDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                }
                            }

                            PlainButton {
                                enabled: Network.connecting === ""
                                text: Network.connecting === win.sel ? "Conectando…"
                                    : win.conn && win.conn.active ? "Desconectar" : "Conectar"
                                onClicked: {
                                    if (win.conn.active) Network.disconnect(win.sel)
                                    else Network.activate(win.sel)
                                }
                            }

                            PlainButton {
                                visible: win.conn !== null && win.conn.type === "wifi"
                                danger: true
                                text: win.confirmForget ? "Confirmar?" : "Esquecer"
                                onClicked: {
                                    if (!win.confirmForget) {
                                        win.confirmForget = true
                                        forgetTimer.restart()
                                    } else {
                                        Network.forget(win.sel)
                                        win.confirmForget = false
                                        win.sel = ""
                                    }
                                }
                            }
                        }

                        Label {
                            visible: Network.error !== ""
                            text: Network.error
                            color: Theme.red
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                        }

                        Label {
                            visible: Network.detailsError !== ""
                            text: Network.detailsError
                            color: Theme.red
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                        }

                        // em uso agora (útil no modo automático: mostra o que o DHCP entregou)
                        Rectangle {
                            visible: Network.live !== null && win.conn !== null && win.conn.active
                            Layout.fillWidth: true
                            implicitHeight: liveCol.implicitHeight + 20
                            radius: Theme.radiusSmall
                            color: Theme.bgAlt

                            ColumnLayout {
                                id: liveCol
                                x: 10
                                y: 10
                                width: parent.width - 20
                                spacing: 3
                                Text {
                                    text: "Em uso agora"
                                    color: Theme.fgDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                }
                                Label { text: "IP:       " + (Network.live ? Network.live.ip || "—" : "") }
                                Label { text: "Gateway:  " + (Network.live ? Network.live.gateway || "—" : "") }
                                Label { text: "DNS:      " + (Network.live ? Network.live.dns || "—" : "") }
                            }
                        }

                        // geral
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Conectar automaticamente" }
                            Toggle {
                                checked: win.autoconnect
                                onToggled: value => win.autoconnect = value
                            }
                        }

                        // senha do Wi-Fi
                        Section { visible: win.wifi && win.d.keyMgmt !== ""; text: "Senha do Wi-Fi" }
                        RowLayout {
                            visible: win.wifi && win.d.keyMgmt !== ""
                            Layout.fillWidth: true
                            spacing: 8
                            Field {
                                id: pass
                                icon: Icons.lock
                                echoMode: win.showPassword ? TextInput.Normal : TextInput.Password
                                placeholder: "Deixe vazio para manter a atual"
                                tabTo: addr
                                onFocused: win.reveal(pass)
                                onAccepted: win.apply()
                            }
                            PlainButton {
                                text: win.showPassword ? "Ocultar" : "Mostrar"
                                onClicked: win.showPassword = !win.showPassword
                            }
                        }

                        // IPv4
                        Section { text: "IPv4" }
                        Chips {
                            model: [
                                { label: "Automático (DHCP)", value: "auto" },
                                { label: "Manual", value: "manual" }
                            ]
                            current: win.ipv4Method
                            onPicked: value => win.ipv4Method = value
                        }

                        Label {
                            visible: win.ipv4Method === "" && win.d !== null
                            text: "O método IPv4 “" + (win.d ? win.d.ipv4Method : "") + "” não é editável aqui."
                            color: Theme.fgDim
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                        }

                        ColumnLayout {
                            visible: win.ipv4Method === "manual"
                            Layout.fillWidth: true
                            spacing: 4
                            Caption { text: "Endereço IP" }
                            Field {
                                id: addr
                                placeholder: "ex.: 192.168.1.50"
                                tabTo: mask
                                onFocused: win.reveal(addr)
                                onAccepted: win.apply()
                            }
                            Caption { Layout.topMargin: 8; text: "Máscara ou prefixo" }
                            Field {
                                id: mask
                                placeholder: "ex.: 24 ou 255.255.255.0"
                                tabTo: gw
                                onFocused: win.reveal(mask)
                                onAccepted: win.apply()
                            }
                            Caption { Layout.topMargin: 8; text: "Gateway" }
                            Field {
                                id: gw
                                placeholder: "ex.: 192.168.1.1"
                                tabTo: dns
                                onFocused: win.reveal(gw)
                                onAccepted: win.apply()
                            }
                        }

                        Caption {
                            visible: win.ipv4Method !== ""
                            text: win.ipv4Method === "auto" ? "Servidores DNS (vazio = os do DHCP)" : "Servidores DNS"
                        }
                        Field {
                            id: dns
                            visible: win.ipv4Method !== ""
                            placeholder: "ex.: 1.1.1.1, 8.8.8.8"
                            onFocused: win.reveal(dns)
                            onAccepted: win.apply()
                        }

                        // IPv6
                        Section { text: "IPv6" }
                        Chips {
                            model: [
                                { label: "Automático", value: "auto" },
                                { label: "Desativado", value: "disabled" }
                            ]
                            current: win.ipv6Method
                            onPicked: value => win.ipv6Method = value
                        }

                        // resultado
                        Label {
                            visible: win.formError !== "" || Network.saveMessage !== ""
                            text: win.formError !== "" ? win.formError : Network.saveMessage
                            color: (win.formError !== "" || Network.saveState === "error") ? Theme.red : Theme.green
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 8

                            Label {
                                text: win.conn && win.conn.active ? "Aplicar reconecta esta rede; ela pode cair por instantes." : ""
                                color: Theme.fgDim
                                font.pixelSize: Theme.fontSize - 1
                                wrapMode: Text.Wrap
                            }

                            PlainButton {
                                text: "Reverter"
                                enabled: !win.saving
                                onClicked: {
                                    Network.saveMessage = ""
                                    win.fill()
                                }
                            }

                            PlainButton {
                                highlighted: true
                                enabled: !win.saving && win.d !== null
                                text: win.saving ? "Aplicando…" : "Aplicar"
                                onClicked: win.apply()
                            }
                        }
                    }
                }
            }
        }
    }
}
