pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brilho (brightnessctl) e luz noturna (hyprsunset)
Singleton {
    id: root

    property bool available: false
    property real value: 0
    property bool nightLightMissing: false
    property bool _again: false   // pedido de leitura durante outra: relê ao terminar

    signal refreshed()   // terminou uma leitura (o valor pode ou não ter mudado)

    function refresh() {
        if (getter.running) _again = true
        else getter.running = true
    }

    function setValue(v) {
        v = Math.max(0.01, Math.min(1, v))
        value = v
        Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", Math.round(v * 100) + "%"])
    }

    function applyNightLight() {
        sunset.running = false
        Quickshell.execDetached(["pkill", "-x", "hyprsunset"])
        if (Settings.data.nightLight) sunsetStart.restart()
    }

    Process {
        id: getter
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            id: getterOut
            onStreamFinished: {
                const f = getterOut.text.trim().split("\n")[0].split(",")
                if (f.length >= 5 && Number(f[4]) > 0) {
                    root.available = true
                    root.value = Number(f[2]) / Number(f[4])
                }
            }
        }
        onExited: code => {
            if (code !== 0) root.available = false
            root.refreshed()
            if (root._again) {
                root._again = false
                getter.running = true
            }
        }
    }

    Process {
        id: sunset
        command: ["hyprsunset", "-t", String(Settings.data.nightLightTemp)]
        onExited: code => { if (code === 127) root.nightLightMissing = true }
    }

    Timer {
        id: sunsetStart
        interval: 400
        onTriggered: sunset.running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Settings.data
        function onNightLightChanged() { root.applyNightLight() }
        function onNightLightTempChanged() { if (Settings.data.nightLight) root.applyNightLight() }
    }
}
