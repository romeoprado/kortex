pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Previsão do tempo de 7 dias via Open-Meteo (sem chave de API).
//
// Cidade preenchida → geocodificação do Open-Meteo ("Cidade" ou "Cidade, Estado/País").
// Cidade vazia      → localização aproximada pelo IP (ipinfo.io).
// Depois de achar as coordenadas, uma segunda chamada traz o tempo atual e os 7 dias.
Singleton {
    id: root

    readonly property int forecastDays: 7

    property bool ready: false
    property bool loading: false
    property string error: ""
    property string location: ""
    property int temp: 0
    property int feels: 0
    property int humidity: 0
    property int wind: 0
    property string desc: ""
    property string icon: Icons.cloud
    property var days: []
    property var updated: null

    property bool _again: false   // mudança de cidade durante uma busca em andamento

    function refresh() {
        if (locator.running || forecaster.running) {
            _again = true
            return
        }
        loading = true
        const city = Settings.data.weatherCity.trim()
        const name = city.split(",")[0].trim()
        locator.command = ["curl", "-sf", "--max-time", "15",
            city ? "https://geocoding-api.open-meteo.com/v1/search?count=10&language=pt&format=json&name=" + encodeURIComponent(name)
                 : "https://ipinfo.io/json"]
        locator.running = true
    }

    // Códigos WMO do Open-Meteo
    function describe(c, night) {
        if (c === 0) return { icon: night ? Icons.moon : Icons.sun, text: night ? "Céu limpo" : "Ensolarado" }
        if (c === 1) return { icon: night ? Icons.moon : Icons.sun, text: "Predominantemente limpo" }
        if (c === 2) return { icon: Icons.cloud, text: "Parcialmente nublado" }
        if (c === 3) return { icon: Icons.cloud, text: "Encoberto" }
        if (c === 45 || c === 48) return { icon: Icons.fog, text: "Neblina" }
        if (c >= 51 && c <= 57) return { icon: Icons.drizzle, text: "Garoa" }
        if (c === 61) return { icon: Icons.rain, text: "Chuva fraca" }
        if (c === 63) return { icon: Icons.rain, text: "Chuva" }
        if (c === 65) return { icon: Icons.rain, text: "Chuva forte" }
        if (c === 66 || c === 67) return { icon: Icons.rain, text: "Chuva congelante" }
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return { icon: Icons.snow, text: "Neve" }
        if (c >= 80 && c <= 82) return { icon: Icons.rain, text: "Pancadas de chuva" }
        if (c === 95) return { icon: Icons.storm, text: "Trovoadas" }
        if (c === 96 || c === 99) return { icon: Icons.storm, text: "Trovoadas com granizo" }
        return { icon: Icons.cloud, text: "" }
    }

    function fail(msg) {
        error = msg
        loading = false
        finish()
    }

    function finish() {
        if (_again) {
            _again = false
            refresh()
        }
    }

    function plain(s) {
        return String(s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim()
    }

    // Resposta da localização → coordenadas e nome; segue para a previsão
    function located(text) {
        let lat, lon, label
        try {
            const j = JSON.parse(text)
            if (Array.isArray(j.results) || "generationtime_ms" in j) {
                // geocodificação: "Cidade, Estado" usa o que vem depois da vírgula para desempatar
                const hints = Settings.data.weatherCity.split(",").slice(1).map(plain).filter(h => h)
                const list = j.results || []
                const hit = list.find(r => hints.every(h =>
                    plain(r.admin1).includes(h) || plain(r.country).includes(h) || plain(r.country_code) === h)) ?? null
                if (!hit) {
                    const asked = Settings.data.weatherCity.trim()
                    fail(list.length === 0
                        ? "Cidade não encontrada: " + asked
                        : "Não achei \"" + asked + "\". Tente só o nome da cidade ou o estado/país em português.")
                    return
                }
                lat = hit.latitude
                lon = hit.longitude
                label = hit.name + (hit.admin1 ? ", " + hit.admin1 : "")
            } else {
                // ipinfo.io: "loc" = "lat,lon"
                const p = String(j.loc || "").split(",")
                lat = Number(p[0])
                lon = Number(p[1])
                label = (j.city || "") + (j.region ? ", " + j.region : "")
                if (!isFinite(lat) || !isFinite(lon) || p.length < 2) {
                    fail("Não foi possível descobrir sua localização. Informe a cidade.")
                    return
                }
            }
        } catch (e) {
            fail("Resposta inválida do serviço de localização")
            return
        }
        location = label
        forecaster.command = ["curl", "-sf", "--max-time", "15",
            "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=" + forecastDays]
        forecaster.running = true
    }

    function parse(text) {
        try {
            const j = JSON.parse(text)
            if (j.error) throw new Error(j.reason || "erro")
            const c = j.current
            temp = Math.round(c.temperature_2m)
            feels = Math.round(c.apparent_temperature)
            humidity = Math.round(c.relative_humidity_2m)
            wind = Math.round(c.wind_speed_10m)
            const now = describe(c.weather_code, c.is_day === 0)
            desc = now.text
            icon = now.icon
            const d = j.daily
            days = d.time.map((date, i) => {
                const info = describe(d.weather_code[i], false)
                return {
                    date: date,
                    max: Math.round(d.temperature_2m_max[i]),
                    min: Math.round(d.temperature_2m_min[i]),
                    icon: info.icon,
                    text: info.text,
                    rain: Number(d.precipitation_probability_max[i]) || 0
                }
            })
            ready = true
            error = ""
            updated = new Date()
        } catch (e) {
            error = "Resposta inválida do serviço de clima"
        }
    }

    Process {
        id: locator
        stdout: StdioCollector {
            id: locatorOut
            onStreamFinished: if (locatorOut.text.length > 0) root.located(locatorOut.text)
        }
        onExited: code => {
            if (code !== 0 || locatorOut.text.length === 0) root.fail("Sem resposta do serviço de localização")
        }
    }

    Process {
        id: forecaster
        stdout: StdioCollector {
            id: forecastOut
            onStreamFinished: if (forecastOut.text.length > 0) root.parse(forecastOut.text)
        }
        onExited: code => {
            if (code !== 0) root.error = "Sem resposta do Open-Meteo"
            root.loading = false
            root.finish()
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Settings.data
        function onWeatherCityChanged() { retry.restart() }
    }

    Timer {
        id: retry
        interval: 300
        onTriggered: root.refresh()
    }
}
