pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Uso de CPU e memória lido de /proc a cada 2 s. GPU e armazenamento só são consultados
// quando a barra os mostra ou o painel Recursos está aberto (a GPU custa um processo por consulta;
// o armazenamento muda devagar e é lido a cada 10 s na barra). As temperaturas de CPU e memória
// só são lidas com o painel aberto.
Singleton {
    id: root

    property real cpu: 0
    property real mem: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property string load: ""
    property real cpuTemp: -1        // °C; -1 = sem sensor
    property real ramTemp: -1
    property int threads: 0
    property var _last: null

    // GPUs: [{ addr, kind, name, state, util, vramUsed, vramTotal, temp, power, freq, freqMax }]
    //   util em 0…1 (-1 = a placa não informa uso, como a Intel); memória de vídeo em GB;
    //   temp em °C, power em W, freq em MHz; -1 = desconhecido
    property var gpus: []
    // Armazenamento: [{ source, fs, mount, total, used, avail, frac, temp }], um por disco;
    // tamanhos em GB, temp em °C (-1 = o disco não expõe sensor)
    property var disks: []

    readonly property bool popupOpen: Popups.current === "stats"
    readonly property bool gpuWanted: Settings.data.statsGpu || Settings.data.statsVram || popupOpen
    readonly property bool diskWanted: Settings.data.statsDisk || popupOpen

    // A GPU que vai para a barra: a primeira que informa uso
    readonly property var gpu: gpus.find(g => g.util >= 0) ?? null
    // No painel: a principal vai no cabeçalho do bloco, as demais em subseções
    readonly property var mainGpu: gpu ?? gpus[0] ?? null
    readonly property var otherGpus: gpus.filter(g => g !== mainGpu)
    readonly property var vramGpu: gpus.find(g => g.vramTotal > 0) ?? null
    readonly property var disk: disks.find(d => d.mount === Settings.data.statsDiskMount)
                                ?? disks.find(d => d.mount === "/") ?? disks[0] ?? null

    readonly property var otherDisks: disks.filter(d => d !== disk)

    property int _tick: 0
    property var _vramTotals: ({})   // a NVIDIA em repouso não informa; lembra o último valor

    // ── Formatação ──────────────────────────────────────────────────────
    function pct(v) { return Math.round(v * 100) + "%" }

    // Por extenso: 5.1 GB · 232 GB · 1.8 TB
    function sizeLong(gb) {
        if (gb >= 1024) return (gb / 1024).toFixed(1) + " TB"
        return (gb >= 100 ? Math.round(gb) : gb.toFixed(1)) + " GB"
    }

    // "5.1 / 31.2 GB" (ou TB), na unidade do total
    function sizePair(used, total) {
        const tb = total >= 1024
        const d = tb ? 1024 : 1
        return (used / d).toFixed(1) + " / " + (total / d).toFixed(1) + (tb ? " TB" : " GB")
    }

    // Resumo de uma GPU para o cabeçalho: uso quando a placa informa, senão a frequência
    function gpuSummary(g) {
        if (g.util >= 0) return { text: pct(g.util), frac: g.util, alert: true }
        if (g.freq >= 0) return { text: g.freq + " MHz", frac: g.freqMax > 0 ? g.freq / g.freqMax : 0, alert: false }
        return { text: "—", frac: 0, alert: false }
    }

    // ── Leitura ─────────────────────────────────────────────────────────
    function refreshExtras(everything) {
        if (gpuWanted && !gpuProc.running) gpuProc.running = true
        if (diskWanted && (everything || popupOpen || disks.length === 0 || _tick % 5 === 0) && !diskProc.running) diskProc.running = true
        if (popupOpen && !sensorsProc.running) sensorsProc.running = true
    }

    function parse(text) {
        const lines = text.split("\n")
        const f = lines[0].trim().split(/\s+/).slice(1).map(Number)
        if (f.length >= 4) {
            const idle = f[3] + (f[4] || 0)
            const total = f.reduce((a, b) => a + b, 0)
            if (_last) {
                const dt = total - _last.total
                const di = idle - _last.idle
                if (dt > 0) cpu = Math.max(0, Math.min(1, 1 - di / dt))
            }
            _last = { total: total, idle: idle }
        }
        let total = 0, avail = 0
        for (const l of lines) {
            const m = l.match(/^(\w+):\s+(\d+)/)
            if (!m) continue
            if (m[1] === "MemTotal") total = Number(m[2])
            if (m[1] === "MemAvailable") avail = Number(m[2])
        }
        if (total > 0) {
            mem = (total - avail) / total
            memUsedGb = (total - avail) / 1048576
            memTotalGb = total / 1048576
        }
        const last = lines.filter(l => l.length > 0).pop() || ""
        const la = last.split(" ")
        if (la.length >= 3 && !isNaN(Number(la[0]))) load = la.slice(0, 3).join("  ")
    }

    function parseGpus(text) {
        const num = s => (s === undefined || s === "" || isNaN(Number(s))) ? -1 : Number(s)
        const totals = Object.assign({}, _vramTotals)
        gpus = text.split("\n").filter(l => l.length > 0).map(l => {
            const f = l.split("\t")
            const addr = f[0], state = f[10]
            const util = num(f[3])
            const vt = num(f[5])
            if (vt > 0) totals[addr] = vt / 1024
            return {
                addr: addr,
                kind: f[1],
                name: f[2],
                state: state,
                // em repouso a placa está ociosa: 0% em vez de "sem dado"
                util: util >= 0 ? util / 100 : state === "suspended" ? 0 : -1,
                vramUsed: Math.max(0, num(f[4])) / 1024,
                vramTotal: totals[addr] ?? 0,
                temp: num(f[6]),
                power: num(f[7]),
                freq: num(f[8]),
                freqMax: num(f[9])
            }
        })
        _vramTotals = totals
    }

    function parseSensors(text) {
        for (const l of text.split("\n")) {
            const m = l.match(/^(cpu|ram|threads)=(\d*)$/)
            if (!m) continue
            const v = m[2] === "" ? -1 : Number(m[2])
            if (m[1] === "cpu") cpuTemp = v
            else if (m[1] === "ram") ramTemp = v
            else threads = Math.max(0, v)
        }
    }

    // Só discos de verdade, um por dispositivo (subvolumes btrfs repetem o mesmo em vários
    // pontos: fica o de caminho mais curto). Partições de boot ficam de fora.
    // Entrada: as linhas de disk-stats.sh (campos separados por TAB).
    function parseDisks(text) {
        const bySource = {}
        for (const l of text.split("\n")) {
            const f = l.split("\t")
            if (f.length < 7) continue
            const source = f[0], mount = f[6]
            if (!source.startsWith("/dev/") || source.startsWith("/dev/loop") || /^\/(boot|efi)(\/|$)/.test(mount)) continue
            if (bySource[source] && bySource[source].mount.length <= mount.length) continue
            const used = Number(f[3]), avail = Number(f[4])
            bySource[source] = {
                source: source,
                fs: f[1],
                mount: mount,
                total: Number(f[2]) / 1073741824,
                used: used / 1073741824,
                avail: avail / 1073741824,
                frac: used + avail > 0 ? used / (used + avail) : 0,   // mesma conta do `df`
                temp: f[5] === "" ? -1 : Number(f[5])
            }
        }
        disks = Object.values(bySource).sort((a, b) => a.mount.length - b.mount.length || a.mount.localeCompare(b.mount))
    }

    Process {
        id: proc
        command: ["sh", "-c", "head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; cat /proc/loadavg"]
        stdout: StdioCollector {
            id: out
            onStreamFinished: root.parse(out.text)
        }
    }

    Process {
        id: gpuProc
        command: ["bash", Settings.scripts + "/gpu-stats.sh"]
        stdout: StdioCollector {
            id: gpuOut
            onStreamFinished: root.parseGpus(gpuOut.text)
        }
    }

    Process {
        id: diskProc
        command: ["bash", Settings.scripts + "/disk-stats.sh"]
        stdout: StdioCollector {
            id: diskOut
            onStreamFinished: root.parseDisks(diskOut.text)
        }
    }

    Process {
        id: sensorsProc
        command: ["bash", Settings.scripts + "/sensors.sh"]
        stdout: StdioCollector {
            id: sensorsOut
            onStreamFinished: root.parseSensors(sensorsOut.text)
        }
    }

    // Abriu o painel ou ligou um item na barra: não espera o próximo ciclo
    Connections {
        target: Popups
        function onCurrentChanged() { if (root.popupOpen) root.refreshExtras(true) }
    }

    Connections {
        target: Settings.data
        function onStatsGpuChanged() { root.refreshExtras(true) }
        function onStatsVramChanged() { root.refreshExtras(true) }
        function onStatsDiskChanged() { root.refreshExtras(true) }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!proc.running) proc.running = true
            root._tick++
            root.refreshExtras(false)
        }
    }
}
