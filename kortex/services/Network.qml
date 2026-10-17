pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi e cabo via NetworkManager (nmcli).
//
// Além da lista de redes, lê e edita os perfis salvos (IP, gateway, DNS, senha…) sem app
// externo. Os comandos que gravam rodam com LC_MESSAGES=C para as mensagens de erro do
// nmcli serem previsíveis (a saída "terse" que lemos já não é traduzida).
Singleton {
    id: root

    property bool wifiEnabled: true
    property bool hasWifi: false
    property string wiredName: ""
    property var networks: []
    property var known: []
    property var connections: []       // [{ name, type: "wifi"|"ethernet", active, device, autoconnect, path }]
    property string connecting: ""
    property string error: ""
    property bool lastConnectOk: false // resultado da última tentativa de conexão
    property bool scanning: false
    readonly property var active: networks.find(n => n.active) ?? null

    // Conexão em uso (painel da barra): { name, device, type, ip, gateway, dns, ipv6, mac } ou null.
    // Só é lida com o painel de rede aberto, junto com cada atualização do estado.
    property var current: null
    readonly property bool watchCurrent: Popups.current === "network"
    onWatchCurrentChanged: if (watchCurrent) refreshCurrent()

    // Dados recebidos e enviados na sessão da conexão em uso (desde que ela foi ativada), em bytes;
    // -1 = ainda não lidos. Atualizados a cada segundo com o painel de rede aberto.
    property real sessionRx: -1
    property real sessionTx: -1
    readonly property bool watchTraffic: watchCurrent && current !== null
    onWatchTrafficChanged: if (!watchTraffic) { sessionRx = -1; sessionTx = -1 }

    // Os contadores da interface (/sys/class/net/<dev>/statistics) só zeram quando ela é desligada,
    // e o NetworkManager troca de rede ou religa o cabo sem desligá-la. Por isso cada ativação (o
    // caminho ActiveConnection/N do NM, novo a cada vez) guarda o valor dos contadores ao ser vista,
    // em network-sessions.json com o boot_id: reiniciar o shell não zera a sessão. Sem registro
    // deste boot (a conexão feita no boot, antes do login), a sessão conta desde que a interface subiu.
    property var _sessions: ({})       // caminho da ativação → { device, rx, tx }
    property string _bootId: ""

    // Perfil em edição
    property var details: null         // ver _parseDetails()
    property var live: null            // { ip, gateway, dns } em uso agora (quando conectado)
    property string detailsError: ""
    property string saveState: ""      // "" | "saving" | "ok" | "error"
    property string saveMessage: ""

    property string _connectSsid: ""
    property bool _wasKnown: false
    property string _detailsName: ""
    property string _detailsLoading: ""
    property string _reactivate: ""
    property int _modifyCode: 0
    property int _upCode: 0

    readonly property var _cLocale: ({ LC_MESSAGES: "C" })

    // ── Utilitários ─────────────────────────────────────────────────────
    // Divide uma linha do modo -t do nmcli respeitando "\:" escapado
    function fields(line) {
        const out = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (c === ":") { out.push(cur); cur = ""; continue }
            cur += c
        }
        out.push(cur)
        return out
    }

    // "chave:valor" por linha → { chave: valor } (campo ausente simplesmente não aparece)
    function keyed(text) {
        const out = {}
        for (const l of text.split("\n")) {
            const i = l.indexOf(":")
            if (i <= 0) continue
            out[l.slice(0, i)] = l.slice(i + 1).replace(/\\(.)/g, "$1")
        }
        return out
    }

    // Traduz as mensagens mais comuns do nmcli (em inglês, via LC_MESSAGES=C)
    function friendly(msg) {
        // o nmcli pode acrescentar linhas "Hint: use journalctl…" depois do erro: ignora-as
        const lines = String(msg || "").trim().split("\n").filter(l => l && !/^Hint:/i.test(l))
        msg = (lines.find(l => /^Error/i.test(l)) ?? lines[lines.length - 1] ?? "").replace(/^Error:\s*/, "")
        if (/Secrets were required|secrets/i.test(msg)) return "Senha incorreta ou não aceita pela rede."
        if (/No network with SSID|network could not be found|AP not found/i.test(msg)) return "Rede não encontrada. Ela pode estar fora de alcance."
        if (/time(d)? ?out/i.test(msg)) return "Tempo esgotado ao conectar."
        if (/base network connection was interrupted/i.test(msg)) return "A conexão foi interrompida."
        if (/psk: property is invalid/i.test(msg)) return "Senha inválida (WPA exige de 8 a 63 caracteres)."
        if (/requires at least an address/i.test(msg)) return "O modo manual precisa de um endereço IP."
        if (/not authorized|permission denied/i.test(msg)) return "Sem permissão para alterar esta conexão."
        return msg
    }

    // ── Estado geral ────────────────────────────────────────────────────
    function parse(text) {
        const parts = text.split("@@\n")
        wifiEnabled = (parts[0] || "").trim() === "enabled"

        let wired = "", hasW = false
        for (const l of (parts[1] || "").split("\n")) {
            if (!l) continue
            const f = fields(l)
            if (f[0] === "wifi") hasW = true
            if (f[0] === "ethernet" && f[1] === "connected") wired = f[2]
        }
        wiredName = wired
        hasWifi = hasW

        const conns = []
        for (const l of (parts[2] || "").split("\n")) {
            if (!l) continue
            const f = fields(l)
            const kind = f[1] === "802-11-wireless" ? "wifi" : f[1] === "802-3-ethernet" ? "ethernet" : ""
            if (!kind) continue
            conns.push({ name: f[0], type: kind, active: f[2] === "yes", device: f[3] || "", autoconnect: f[4] === "yes", path: f[5] || "" })
        }
        connections = conns.sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name))
        known = conns.filter(c => c.type === "wifi").map(c => c.name)

        const map = {}
        for (const l of (parts[3] || "").split("\n")) {
            if (!l) continue
            const f = fields(l)
            const ssid = f[3]
            if (!ssid) continue
            const n = { ssid: ssid, active: f[0] === "*", signal: parseInt(f[1]) || 0, secure: !!f[2] && f[2] !== "--" }
            const prev = map[ssid]
            if (!prev || n.active || (!prev.active && n.signal > prev.signal)) map[ssid] = n
        }
        networks = Object.values(map).sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
        if (watchCurrent) refreshCurrent()

        // ativação nova (ou que acabou): lê os contadores para registrar a sessão
        const paths = conns.filter(c => c.active && c.device && c.path).map(c => c.path)
        const tracked = Object.keys(_sessions)
        if (!_bootId || paths.length !== tracked.length || paths.some(p => !_sessions[p])) readCounters()
    }

    function refreshCurrent() {
        if (!currentProc.running) currentProc.running = true
    }

    // Blocos de "nmcli device show" separados por linha vazia; escolhe o cabo ou Wi-Fi conectado,
    // preferindo o que tem gateway (a rota padrão) e, entre dois assim, o cabo
    function _parseCurrent(text) {
        const devs = []
        for (const block of text.split("\n\n")) {
            const d = { name: "", device: "", type: "", state: 0, mac: "", ips: [], gateway: "", dns: [], ipv6: [] }
            for (const l of block.split("\n")) {
                const i = l.indexOf(":")
                if (i <= 0) continue
                const k = l.slice(0, i), v = l.slice(i + 1).replace(/\\(.)/g, "$1")
                if (k === "GENERAL.DEVICE") d.device = v
                else if (k === "GENERAL.CONNECTION") d.name = v
                else if (k === "GENERAL.TYPE") d.type = v
                else if (k === "GENERAL.STATE") d.state = parseInt(v) || 0
                else if (k === "GENERAL.HWADDR") d.mac = v
                else if (k.startsWith("IP4.ADDRESS")) d.ips.push(v)
                else if (k === "IP4.GATEWAY") d.gateway = v
                else if (k.startsWith("IP4.DNS")) d.dns.push(v)
                else if (k.startsWith("IP6.ADDRESS") && !/^fe80:/i.test(v)) d.ipv6.push(v)   // sem o link-local
            }
            if (d.state === 100 && (d.type === "wifi" || d.type === "ethernet")) devs.push(d)
        }
        devs.sort((a, b) => (!!b.gateway - !!a.gateway) || ((b.type === "ethernet") - (a.type === "ethernet")))
        const d = devs[0]
        // IP sem o prefixo de rede ("192.168.0.10/24" → "192.168.0.10"): cabe no bloco do painel
        current = d ? { name: d.name, device: d.device, type: d.type, ip: d.ips.map(a => a.split("/")[0]).join(", "), gateway: d.gateway,
                        dns: d.dns.join(", "), ipv6: d.ipv6.join(", "), mac: d.mac } : null
    }

    function refresh() {
        if (!status.running) status.running = true
    }

    // ── Dados da sessão ─────────────────────────────────────────────────
    function readCounters() {
        if (counters.running) return
        const devices = connections.filter(c => c.active && c.device && c.path).map(c => c.device)
        counters.command = ["sh", "-c",
            "cat /proc/sys/kernel/random/boot_id; for d; do s=/sys/class/net/$d/statistics; "
            + "echo \"$d $(cat $s/rx_bytes) $(cat $s/tx_bytes)\"; done", "sh"].concat(devices)
        counters.running = true
    }

    // 1ª linha: boot_id; depois "interface recebidos enviados"
    function _parseCounters(text) {
        const lines = text.trim().split("\n")
        const boot = (lines[0] || "").trim()
        if (!boot) return
        const now = {}
        for (const l of lines.slice(1)) {
            const f = l.split(" ")
            if (f.length === 3 && f[1] !== "" && f[2] !== "") now[f[0]] = { rx: Number(f[1]), tx: Number(f[2]) }
        }

        // 1ª leitura: retoma o registro deste boot, se houver
        let fresh = false
        if (_bootId !== boot) {
            let saved = null
            try { saved = JSON.parse(sessionsFile.text()) } catch (e) {}
            fresh = !saved || saved.boot !== boot
            _sessions = fresh ? {} : (saved.sessions || {})
            _bootId = boot
        }

        const sessions = {}
        let changed = fresh
        for (const c of connections) {
            const v = now[c.device]
            if (!c.active || !c.path || !v) continue
            const old = _sessions[c.path]
            if (old && old.device === c.device && v.rx >= old.rx && v.tx >= old.tx) {
                sessions[c.path] = old
                continue
            }
            // ativação nova: conta a partir de agora; na 1ª do boot, ou se os contadores zeraram
            // (a interface foi religada), desde que a interface subiu
            sessions[c.path] = fresh || old ? { device: c.device, rx: 0, tx: 0 } : { device: c.device, rx: v.rx, tx: v.tx }
            changed = true
        }
        if (Object.keys(sessions).length !== Object.keys(_sessions).length) changed = true
        _sessions = sessions
        if (changed) sessionsFile.setText(JSON.stringify({ boot: boot, sessions: sessions }))

        const cur = current ? Object.values(sessions).find(x => x.device === current.device) : null
        const v = cur ? now[cur.device] : null
        sessionRx = v ? v.rx - cur.rx : -1
        sessionTx = v ? v.tx - cur.tx : -1
    }

    // Bytes por extenso: 0 B · 850 KB · 12,4 MB · 1,8 GB
    function bytes(n) {
        if (n < 0) return "—"
        const units = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024
            i++
        }
        return (i === 0 || n >= 100 ? Math.round(n) : Theme.decimal(n, 1)) + " " + units[i]
    }

    function rescan() {
        scanning = true
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"])
        scanDone.restart()
    }

    function setWifi(on) {
        wifiEnabled = on
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
        later.restart()
    }

    function isKnown(ssid) {
        return known.indexOf(ssid) >= 0
    }

    // ── Conectar / desconectar ──────────────────────────────────────────
    function connect(ssid, password) {
        error = ""
        connecting = ssid
        _connectSsid = ssid
        _wasKnown = isKnown(ssid)
        if (!password && _wasKnown)
            conn.command = ["nmcli", "-w", "30", "connection", "up", "id", ssid]
        else
            conn.command = ["nmcli", "-w", "30", "device", "wifi", "connect", ssid].concat(password ? ["password", password] : [])
        conn.running = true
    }

    // Ativa um perfil salvo (Wi-Fi ou cabo)
    function activate(name) {
        error = ""
        connecting = name
        _connectSsid = ""
        conn.command = ["nmcli", "-w", "30", "connection", "up", "id", name]
        conn.running = true
    }

    function disconnect(name) {
        Quickshell.execDetached(["nmcli", "connection", "down", "id", name])
        later.restart()
    }

    function forget(name) {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", name])
        later.restart()
    }

    // ── Edição de perfis ────────────────────────────────────────────────
    function loadDetails(name) {
        const same = name === _detailsName    // recarregar o mesmo perfil (após salvar) mantém o resultado
        _detailsName = name
        details = null
        live = null
        detailsError = ""
        if (!same) {
            saveState = ""
            saveMessage = ""
        }
        if (!detailer.running) _startDetails()   // se já roda, o onExited relança com o nome mais recente
    }

    function _startDetails() {
        _detailsLoading = _detailsName
        detailer.command = ["nmcli", "-t", "-f",
            "connection.id,connection.type,connection.autoconnect,802-11-wireless.ssid,"
            + "802-11-wireless-security.key-mgmt,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,"
            + "ipv4.ignore-auto-dns,ipv6.method",
            "connection", "show", "id", _detailsName]
        detailer.running = true
    }

    function _parseDetails(text) {
        const m = keyed(text)
        if (m["connection.id"] !== _detailsName) return   // resposta de uma seleção antiga
        const list = s => (s || "").split(/[,\s]+/).filter(x => x)
        details = {
            name: m["connection.id"],
            type: m["connection.type"] === "802-11-wireless" ? "wifi" : "ethernet",
            autoconnect: m["connection.autoconnect"] === "yes",
            ssid: m["802-11-wireless.ssid"] || "",
            keyMgmt: m["802-11-wireless-security.key-mgmt"] || "",
            ipv4Method: m["ipv4.method"] || "auto",
            addresses: list(m["ipv4.addresses"]),
            gateway: m["ipv4.gateway"] || "",
            dns: list(m["ipv4.dns"]),
            ignoreAutoDns: m["ipv4.ignore-auto-dns"] === "yes",
            ipv6Method: m["ipv6.method"] || "auto"
        }
        const c = connections.find(x => x.name === details.name)
        if (c && c.active && c.device) {
            liveProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", c.device]
            liveProc.running = true
        }
    }

    function _parseLive(text) {
        const ips = [], dns = []
        let gateway = ""
        for (const l of text.split("\n")) {
            const i = l.indexOf(":")
            if (i <= 0) continue
            const k = l.slice(0, i), v = l.slice(i + 1).replace(/\\(.)/g, "$1")
            if (k.startsWith("IP4.ADDRESS")) ips.push(v)
            else if (k.startsWith("IP4.GATEWAY")) gateway = v
            else if (k.startsWith("IP4.DNS")) dns.push(v)
        }
        live = { ip: ips.join(", "), gateway: gateway, dns: dns.join(", ") }
    }

    // s: { autoconnect, ipv4Method, addresses[], gateway, dns[], ipv6Method, password }
    // ipv4Method/ipv6Method vazios = não mexer. reactivate = reconectar para aplicar.
    function saveConnection(name, s, reactivate) {
        if (modifier.running || upper.running) return
        saveState = "saving"
        saveMessage = ""
        const a = ["nmcli", "connection", "modify", "id", name,
                   "connection.autoconnect", s.autoconnect ? "yes" : "no"]
        if (s.ipv4Method) {
            const manual = s.ipv4Method === "manual"
            a.push("ipv4.method", s.ipv4Method,
                   "ipv4.addresses", manual ? s.addresses.join(",") : "",
                   "ipv4.gateway", manual ? s.gateway : "",
                   "ipv4.dns", s.dns.join(","),
                   "ipv4.ignore-auto-dns", (!manual && s.dns.length > 0) ? "yes" : "no")
        }
        if (s.ipv6Method) a.push("ipv6.method", s.ipv6Method)
        if (s.password) a.push("802-11-wireless-security.psk", s.password)
        _reactivate = reactivate ? name : ""
        modifier.command = a
        modifier.running = true
    }

    function _finishSave(ok, message) {
        saveState = ok ? "ok" : "error"
        saveMessage = message
        refresh()
        if (ok && _detailsName) loadDetails(_detailsName)   // mostra os valores como o NM os guardou
    }

    // ── Processos ───────────────────────────────────────────────────────
    Process {
        id: status
        command: ["sh", "-c",
            "nmcli -t -f WIFI general; echo '@@'; " +
            "nmcli -t -f TYPE,STATE,CONNECTION device; echo '@@'; " +
            "nmcli -t -f NAME,TYPE,ACTIVE,DEVICE,AUTOCONNECT,ACTIVE-PATH connection show; echo '@@'; " +
            "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no"]
        stdout: StdioCollector {
            id: statusOut
            onStreamFinished: root.parse(statusOut.text)
        }
    }

    Process {
        id: currentProc
        environment: root._cLocale
        command: ["nmcli", "-t", "-f",
            "GENERAL.DEVICE,GENERAL.CONNECTION,GENERAL.TYPE,GENERAL.STATE,GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS",
            "device", "show"]
        stdout: StdioCollector {
            id: currentOut
            onStreamFinished: root._parseCurrent(currentOut.text)
        }
    }

    Process {
        id: counters
        stdout: StdioCollector {
            id: countersOut
            onStreamFinished: root._parseCounters(countersOut.text)
        }
    }

    FileView {
        id: sessionsFile
        path: Settings.stateDir + "/network-sessions.json"
        blockLoading: true
        printErrors: false
    }

    Process {
        id: conn
        environment: root._cLocale
        stderr: StdioCollector {
            id: connErr
            onStreamFinished: {
                const msg = connErr.text.trim()
                if (msg) root.error = root.friendly(msg)
            }
        }
        onExited: code => {
            root.lastConnectOk = code === 0
            // Rede nova que falhou: apaga o perfil criado, senão o NM fica tentando com a senha errada
            if (code !== 0 && !root._wasKnown && root._connectSsid !== "")
                Quickshell.execDetached(["nmcli", "connection", "delete", "id", root._connectSsid])
            root.connecting = ""
            root.refresh()
        }
    }

    Process {
        id: detailer
        environment: root._cLocale
        stdout: StdioCollector {
            id: detailOut
            onStreamFinished: root._parseDetails(detailOut.text)
        }
        stderr: StdioCollector {
            id: detailErr
            onStreamFinished: {
                const msg = detailErr.text.trim()
                if (msg) root.detailsError = root.friendly(msg)
            }
        }
        onExited: {
            if (root._detailsLoading !== root._detailsName) root._startDetails()
        }
    }

    Process {
        id: liveProc
        stdout: StdioCollector {
            id: liveOut
            onStreamFinished: root._parseLive(liveOut.text)
        }
    }

    Process {
        id: modifier
        environment: root._cLocale
        stderr: StdioCollector { id: modifyErr }
        onExited: code => {
            root._modifyCode = code
            saveDone.restart()   // dá tempo ao stderr terminar de chegar
        }
    }

    Process {
        id: upper
        environment: root._cLocale
        command: ["nmcli", "-w", "30", "connection", "up", "id", root._reactivate]
        stderr: StdioCollector { id: upErr }
        onExited: code => {
            root._upCode = code
            upDone.restart()
        }
    }

    Timer {
        id: saveDone
        interval: 120
        onTriggered: {
            if (root._modifyCode !== 0) {
                root._finishSave(false, root.friendly(modifyErr.text))
            } else if (root._reactivate !== "") {
                upper.running = true
            } else {
                root._finishSave(true, "Configurações salvas.")
            }
        }
    }

    Timer {
        id: upDone
        interval: 120
        onTriggered: {
            if (root._upCode === 0) root._finishSave(true, "Configurações salvas e aplicadas.")
            else root._finishSave(false, "Salvo, mas não foi possível reconectar: " + root.friendly(upErr.text))
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // dados da sessão ao vivo com o painel de rede aberto
    Timer {
        interval: 1000
        running: root.watchTraffic
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readCounters()
    }

    Timer {
        id: later
        interval: 1200
        onTriggered: root.refresh()
    }

    Timer {
        id: scanDone
        interval: 4000
        onTriggered: {
            root.scanning = false
            root.refresh()
        }
    }
}
