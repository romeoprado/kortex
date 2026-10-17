pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Gerenciador de Processos (modules/processes): os processos do usuário agrupados por aplicativo.
// Só lê enquanto a janela está aberta, a cada 2 s (scripts/processes.sh, ~15 ms).
//
// Agrupamento: cada processo sobe pela árvore até um "dono". Começa um grupo o processo que tem
// janela no Hyprland ou cujo pai é da sessão (Hyprland, systemd do usuário, init, ou de outro
// usuário). Assim o Firefox leva os seus 20 processos e o terminal leva o shell e o que roda nele;
// um programa com janela aberto de dentro do terminal vira um grupo próprio.
//
// CPU em fração da máquina inteira (0…1, como o uso na barra); memória em kB, só a parte própria
// de cada processo (ver o script).
Singleton {
    id: root

    readonly property bool active: Popups.processesOpen

    // [{ key, pid, name, icon, title, isApp, essential, cpu, mem, procs: [{ pid, name, cpu, mem, cmd }] }]
    property var groups: []
    property bool loaded: false

    // pid → Date.now() do pedido de encerramento (para mostrar "não respondeu" e oferecer forçar)
    property var ending: ({})
    readonly property int patience: 3000   // ms até oferecer o encerramento forçado

    property var _ticks: ({})
    property real _total: 0
    property bool _primed: false   // já há uma leitura anterior para medir a CPU

    // Pais que não pertencem a nenhum aplicativo: os filhos deles começam grupos
    readonly property var _sessionRoots: ["systemd", "Hyprland", "start-hyprland", "uwsm", "init"]
    // Processos que a sessão precisa: aparecem, mas sem botão de encerrar
    readonly property var _essential: ["systemd", "(sd-pam)", "Hyprland", "start-hyprland", "uwsm",
        "dbus-broker", "dbus-broker-lau", "dbus-daemon", "Xwayland", "qs", "quickshell"]
    // Interpretadores: o nome útil é o do script que rodam
    readonly property var _interpreters: /^(python[\d.]*|node|bash|sh|zsh|fish|perl|ruby|lua[\d.]*|java|gjs)$/
    // Nomes amigáveis dos serviços de fundo mais comuns
    readonly property var _friendly: ({
        "qs": "Kortex", "quickshell": "Kortex",
        "Hyprland": "Hyprland", "start-hyprland": "Início do Hyprland",
        "systemd": "Serviços do usuário (systemd)", "(sd-pam)": "Sessão de login (PAM)",
        "Xwayland": "Xwayland (apps X11)",
        "pipewire": "Som e vídeo (PipeWire)", "pipewire-pulse": "Som (PipeWire Pulse)",
        "wireplumber": "Som (WirePlumber)",
        "gnome-keyring-daemon": "Chaveiro de senhas",
        "dbus-broker-launch": "Barramento D-Bus", "dbus-daemon": "Barramento D-Bus",
        "hypridle": "Inatividade da tela (hypridle)",
        "hyprpolkitagent": "Pedidos de senha (polkit)",
        "xdg-desktop-portal": "Portal do desktop", "xdg-desktop-portal-gtk": "Portal do desktop (GTK)",
        "xdg-desktop-portal-hyprland": "Portal do desktop (Hyprland)",
        "xdg-document-portal": "Portal de documentos", "xdg-permission-store": "Permissões do portal",
        "at-spi-bus-launcher": "Acessibilidade", "at-spi2-registryd": "Acessibilidade",
        "speech-dispatcher": "Leitura de tela (fala)",
        "dconf-service": "Configurações (dconf)",
        "gvfsd": "Arquivos remotos (GVfs)", "gvfsd-fuse": "Arquivos remotos (GVfs)",
        "gvfsd-metadata": "Arquivos remotos (GVfs)", "gvfs-udisks2-volume-monitor": "Discos removíveis (GVfs)",
        "wl-copy": "Área de transferência (wl-copy)"
    })
    // Processos internos do Firefox (o nome que ele dá a cada um, cortado em 15 letras pelo kernel)
    readonly property var _firefoxParts: ({
        "Isolated Web Co": "Abas (conteúdo web)", "Web Content": "Conteúdo web",
        "WebExtensions": "Extensões", "Privileged Cont": "Páginas internas",
        "Isolated Servic": "Service workers", "Socket Process": "Rede",
        "RDD Process": "Decodificação de mídia", "Utility Process": "Utilitário",
        "GPU Process": "GPU", "forkserver": "Iniciador de processos"
    })

    onActiveChanged: {
        if (active) {
            _primed = false
            refresh()
        } else {
            groups = []
            loaded = false
            ending = {}
            _ticks = {}
        }
    }

    function refresh() { if (!proc.running) proc.running = true }

    // ── Ações ───────────────────────────────────────────────────────────
    // Pede para encerrar (SIGTERM: o programa salva o que precisa e sai). Num grupo, basta o dono:
    // os filhos saem junto.
    function end(pid) {
        Quickshell.execDetached(["kill", "-TERM", String(pid)])
        _markEnding([pid])
    }

    // Encerramento forçado (SIGKILL): para quem não respondeu. Leva todos os processos dados.
    function forceEnd(pids) {
        Quickshell.execDetached(["kill", "-KILL"].concat(pids.map(String)))
        _markEnding(pids)
    }

    function _markEnding(pids) {
        const e = Object.assign({}, ending)
        for (const p of pids) e[p] = Date.now()
        ending = e
        Qt.callLater(refresh)
    }

    // Pediu para encerrar há mais de `patience` e o processo continua aí
    function stuck(pid, now) {
        const t = ending[pid]
        return t !== undefined && now - t > patience
    }

    // ── Formatação ──────────────────────────────────────────────────────
    function cpuText(v) {
        const p = v * 100
        if (p < 0.05) return "0%"
        if (p < 10) return Theme.decimal(p, 1) + "%"
        return Math.round(p) + "%"
    }

    function memText(kb) {
        if (kb >= 1048576) return Theme.decimal(kb / 1048576, 1) + " GB"
        if (kb >= 1024) return Math.round(kb / 1024) + " MB"
        return Math.max(0, Math.round(kb)) + " kB"
    }

    // ── Leitura ─────────────────────────────────────────────────────────
    function _base(path) { return String(path).split("/").pop() }

    // Nome de um processo: o executável completo (o comm do kernel corta em 15 letras) ou,
    // para interpretadores, o script
    function _procName(comm, cmd) {
        const args = cmd.split(" ").filter(a => a !== "")
        const exe = args.length > 0 ? _base(args[0]) : ""
        const short = exe.startsWith(comm) ? exe : comm
        if (_firefoxParts[comm] && exe !== comm) return _firefoxParts[comm]
        if (_interpreters.test(short)) {
            // "sh -c 'comando …'": o nome é o do comando; senão, o do script
            const c = args.indexOf("-c")
            const script = c > 0 ? args[c + 1] : args.slice(1).find(a => !a.startsWith("-"))
            if (script) return _base(script)
        }
        return short
    }

    // Título da janela sem o nome do aplicativo no fim ("Página — Mozilla Firefox" → "Página");
    // vazio se não sobrar nada além do próprio nome
    function _windowTitle(title, appName) {
        const t = String(title || "").trim()
        const name = String(appName || "").toLowerCase()
        if (name === "" || t.toLowerCase() === name) return name === "" ? t : ""
        const m = t.match(/^(.*\S)\s+[—–-]\s+([^—–-]+)$/)
        return m && m[2].toLowerCase().includes(name) ? m[1] : t
    }

    function parse(text) {
        const parts = text.split("\n--clients--\n")
        const lines = parts[0].split("\n")
        const head = lines[0].match(/^cpu (\d+)/)
        if (!head) return
        const total = Number(head[1])
        const dt = total - _total

        let clients = []
        try { clients = JSON.parse(parts[1] || "[]") } catch (e) { clients = [] }
        const windowOf = {}   // pid → janela (a primeira)
        for (const c of clients) if (c.pid > 0 && !windowOf[c.pid]) windowOf[c.pid] = c

        // Processos
        const byPid = {}
        const ticks = {}
        for (let i = 1; i < lines.length; i++) {
            const f = lines[i].split("\t")
            if (f.length < 6) continue
            const pid = Number(f[0]), t = Number(f[2])
            ticks[pid] = t
            const prev = _ticks[pid]
            byPid[pid] = {
                pid: pid,
                ppid: Number(f[1]),
                comm: f[4],
                cmd: f[5],
                name: _procName(f[4], f[5]),
                cpu: _primed && prev !== undefined && dt > 0 ? Math.max(0, (t - prev) / dt) : 0,
                mem: Number(f[3])
            }
        }
        _ticks = ticks
        _total = total

        // A leitura em si (o script e o hyprctl, filhos do Kortex) não entra na lista
        const self = Object.values(byPid).find(p => p.cmd.includes("/scripts/processes.sh"))
        if (self) {
            for (const p of Object.values(byPid)) if (p.ppid === self.pid) delete byPid[p.pid]
            delete byPid[self.pid]
        }

        // Dono de cada processo
        const isRoot = p => windowOf[p.pid] !== undefined || !byPid[p.ppid]
                           || _sessionRoots.includes(byPid[p.ppid].comm)
        const ownerCache = {}
        const ownerOf = p => {
            const chain = []
            let cur = p
            while (!isRoot(cur) && ownerCache[cur.pid] === undefined && chain.length < 64) {
                chain.push(cur.pid)
                cur = byPid[cur.ppid]
            }
            const owner = ownerCache[cur.pid] ?? cur.pid
            ownerCache[cur.pid] = owner
            for (const pid of chain) ownerCache[pid] = owner
            return owner
        }

        const map = {}
        for (const p of Object.values(byPid)) {
            const o = ownerOf(p)
            if (!map[o]) map[o] = []
            map[o].push(p)
        }

        const list = []
        for (const o in map) {
            const owner = byPid[o]
            const procs = map[o].sort((a, b) => (a.pid === owner.pid ? -1 : b.pid === owner.pid ? 1 : b.mem - a.mem))
            const win = windowOf[owner.pid]
            const entry = win ? DesktopEntries.heuristicLookup(win.class || win.initialClass || "") : null
            const essential = _essential.includes(owner.comm)
            const appName = win ? (entry?.name || win.class || win.title || owner.name) : ""
            list.push({
                key: String(owner.pid),
                pid: owner.pid,
                name: win ? appName : (_friendly[owner.name] || _friendly[owner.comm] || owner.name),
                icon: win ? (entry?.icon || win.class || "") : "",
                title: win ? _windowTitle(win.title, appName) : "",
                isApp: win !== undefined,
                essential: essential,
                cpu: procs.reduce((s, p) => s + p.cpu, 0),
                mem: procs.reduce((s, p) => s + p.mem, 0),
                procs: procs.map(p => ({ pid: p.pid, name: p.name, cpu: p.cpu, mem: p.mem, cmd: p.cmd }))
            })
        }

        // Pedidos de encerramento de processos que já saíram não interessam mais
        const e = {}
        for (const pid in ending) if (byPid[pid]) e[pid] = ending[pid]
        ending = e

        groups = list
        loaded = true

        // A primeira leitura só serve de referência para a CPU: a segunda vem logo
        if (!_primed) {
            _primed = true
            primer.restart()
        }
    }

    Process {
        id: proc
        command: ["bash", Settings.scripts + "/processes.sh"]
        stdout: StdioCollector {
            id: out
            onStreamFinished: root.parse(out.text)
        }
    }

    Timer {
        id: primer
        interval: 600
        onTriggered: root.refresh()
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
