pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Bateria e modo de energia. A bateria vem do `uevent` de cada fonte em /sys/class/power_supply
// (um único processo lê tudo), relido a cada 10 s e, com o painel Energia aberto, a cada 2 s.
// Os modos (Economia, Equilibrado, Desempenho) são os do power-profiles-daemon, pelo D-Bus.
Singleton {
    id: root

    // [{ name, status, percent, energyNow, energyFull, energyDesign, power, voltage, cycles, temp,
    //    technology, manufacturer, model, made }]: energias em Wh, potência em W, tensão em V,
    //    temperatura em °C; -1 (ou "") = a bateria não informa
    property var batteries: []
    property bool onAc: false
    property bool profilesAvailable: false

    readonly property var battery: batteries[0] ?? null
    readonly property bool popupOpen: Popups.current === "energy"

    // Modos na ordem da tela. "Desempenho" só aparece se a máquina tiver esse modo.
    // PowerProfiles só é tocado com o serviço presente: o Quickshell tenta conectar no primeiro acesso
    // e, se falhar, desiste até reiniciar (assim, instalar o serviço com o shell aberto funciona).
    readonly property var profiles: !profilesAvailable ? [] : [
        { id: PowerProfile.PowerSaver, icon: Icons.eco, text: "Economia" },
        { id: PowerProfile.Balanced, icon: Icons.balanced, text: "Equilibrado" },
        { id: PowerProfile.Performance, icon: Icons.performance, text: "Desempenho" }
    ].filter(p => p.id !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
    readonly property int profile: profilesAvailable ? PowerProfiles.profile : -1

    // Motivo de o modo Desempenho estar limitado ("" = nenhum)
    readonly property string degradation: {
        if (!profilesAvailable) return ""
        switch (PowerProfiles.degradationReason) {
        case PerformanceDegradationReason.HighTemperature: return "temperatura alta"
        case PerformanceDegradationReason.LapDetected: return "notebook no colo"
        default: return ""
        }
    }

    function setProfile(p) {
        if (profilesAvailable) PowerProfiles.profile = p
    }

    // ── Formatação ──────────────────────────────────────────────────────
    function statusText(b) {
        switch (b.status) {
        case "Charging": return "Carregando"
        case "Discharging": return "Na bateria"
        case "Full": return "Carga completa"
        case "Not charging": return onAc ? "Na tomada, sem carregar" : "Sem carregar"
        default: return "Estado desconhecido"
        }
    }

    // Horas até esvaziar (na bateria) ou até encher (carregando); -1 = sem estimativa
    function hoursLeft(b) {
        if (b.power < 0.5 || b.energyNow < 0 || b.energyFull <= 0) return -1
        if (b.status === "Discharging") return b.energyNow / b.power
        if (b.status === "Charging") return Math.max(0, b.energyFull - b.energyNow) / b.power
        return -1
    }

    function duration(h) {
        const min = Math.round(h * 60)
        const hh = Math.floor(min / 60), mm = min % 60
        return hh > 0 ? hh + " h " + String(mm).padStart(2, "0") + " min" : mm + " min"
    }

    function technologyText(t) {
        const names = { "Li-ion": "Íon de lítio", "Li-poly": "Polímero de lítio", "LiFe": "Fosfato de ferro-lítio",
                        "NiMH": "Níquel-hidreto metálico", "NiCd": "Níquel-cádmio" }
        return names[t] ?? (t === "Unknown" ? "" : t)
    }

    // Ícone da bateria conforme a carga (com raio quando carrega; alerta quando está quase vazia)
    function batteryIcon(b) {
        if (!b) return Icons.bolt
        const p = b.percent
        if (b.status === "Charging") {
            const steps = [[25, "20"], [40, "30"], [55, "50"], [70, "60"], [85, "80"]]
            const s = steps.find(x => p < x[0])
            return "battery_charging_" + (s ? s[1] : "90")
        }
        if (p <= 10 && b.status === "Discharging") return Icons.batteryAlert
        if (p >= 95) return "battery_full"
        return "battery_" + Math.max(0, Math.min(6, Math.floor(p / 15))) + "_bar"
    }

    // Carga baixa (15% ou menos) fora da tomada
    function isLow(b) { return b !== null && b.percent <= 15 && !onAc }

    // ── Leitura ─────────────────────────────────────────────────────────
    function parse(text) {
        const list = []
        let ac = false
        for (const block of text.split("\n\n")) {
            const f = {}
            for (const line of block.split("\n")) {
                const i = line.indexOf("=")
                if (i > 0) f[line.slice(0, i).replace("POWER_SUPPLY_", "")] = line.slice(i + 1)
            }
            const num = k => (f[k] === undefined || f[k] === "" || isNaN(Number(f[k]))) ? -1 : Number(f[k])
            if ((f.TYPE === "Mains" || f.TYPE === "USB") && f.ONLINE === "1") ac = true
            if (f.TYPE !== "Battery" || f.SCOPE === "Device" || f.PRESENT === "0") continue

            // Energia em Wh: direto (µWh) ou pela carga (µAh) × tensão de projeto (µV)
            const vDesign = num("VOLTAGE_MIN_DESIGN")
            const wh = (e, c) => num(e) >= 0 ? num(e) / 1e6 : (num(c) >= 0 && vDesign > 0 ? num(c) * vDesign / 1e12 : -1)
            const energyNow = wh("ENERGY_NOW", "CHARGE_NOW")
            const energyFull = wh("ENERGY_FULL", "CHARGE_FULL")
            const vNow = num("VOLTAGE_NOW")
            const power = num("POWER_NOW") >= 0 ? num("POWER_NOW") / 1e6
                        : (num("CURRENT_NOW") >= 0 && vNow > 0 ? num("CURRENT_NOW") * vNow / 1e12 : -1)
            let percent = num("CAPACITY")
            if (percent < 0 && energyNow >= 0 && energyFull > 0) percent = Math.round(energyNow / energyFull * 100)
            const y = num("MANUFACTURE_YEAR"), m = num("MANUFACTURE_MONTH"), d = num("MANUFACTURE_DAY")

            list.push({
                name: f.NAME || "",
                status: f.STATUS || "Unknown",
                percent: Math.max(0, Math.min(100, percent)),
                energyNow: energyNow,
                energyFull: energyFull,
                energyDesign: wh("ENERGY_FULL_DESIGN", "CHARGE_FULL_DESIGN"),
                power: power,
                voltage: vNow > 0 ? vNow / 1e6 : -1,
                cycles: num("CYCLE_COUNT"),
                temp: num("TEMP") >= 0 ? num("TEMP") / 10 : -1,
                technology: technologyText(f.TECHNOLOGY || ""),
                manufacturer: (f.MANUFACTURER || "").trim(),
                model: (f.MODEL_NAME || "").trim(),
                made: y > 1990 ? (d > 0 ? String(d).padStart(2, "0") + "/" : "") + (m > 0 ? String(m).padStart(2, "0") + "/" : "") + y : ""
            })
        }
        onAc = ac
        batteries = list
    }

    function refresh() {
        if (!reader.running) reader.running = true
        if (!profilesCheck.running) profilesCheck.running = true
    }

    Process {
        id: reader
        command: ["sh", "-c", "for f in /sys/class/power_supply/*/uevent; do cat \"$f\" 2>/dev/null; echo; done"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    // O power-profiles-daemon (ou o tuned-ppd, que imita a mesma interface) está no D-Bus do sistema?
    Process {
        id: profilesCheck
        command: ["sh", "-c", "busctl --system --no-legend list 2>/dev/null | grep -qE '^(org\\.freedesktop\\.UPower\\.PowerProfiles|net\\.hadess\\.PowerProfiles) '"]
        onExited: code => root.profilesAvailable = code === 0
    }

    onPopupOpenChanged: if (popupOpen) refresh()

    Timer {
        interval: root.popupOpen ? 2000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!reader.running) reader.running = true
            // o serviço pode ser instalado com o shell aberto: confere de novo só com o painel aberto
            if (root.popupOpen && !profilesCheck.running) profilesCheck.running = true
        }
    }

    Component.onCompleted: profilesCheck.running = true
}
