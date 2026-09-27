pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Avisos rápidos (OSD) no centro/baixo da tela: volume, brilho, Caps Lock e Num Lock.
//  • volume: mudanças no dispositivo de saída padrão (teclas, atalhos, roda na barra). Fica quieto com o
//    painel de Som aberto, ao iniciar e ao trocar de dispositivo.
//  • brilho: o kernel avisa cada mudança da luz de fundo (udevadm monitor); então relê o valor. Fica
//    quieto com o painel da Tela aberto.
//  • Caps Lock e Num Lock: atalhos do Hyprland que não consomem a tecla (HyprSync) chamam
//    "qs -c kortex ipc call osd locks"; o estado vem do teclado principal no hyprctl devices.
Singleton {
    id: root

    property string kind: ""        // "volume" | "brightness" | "caps" | "num"
    property bool active: false     // à vista
    property bool capsLock: false
    property bool numLock: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real brightness: Brightness.value

    property bool _ready: false         // ignora os valores que chegam ao iniciar
    property bool _sinkSettling: true   // ignora o volume do dispositivo recém-escolhido
    property bool _brightnessPending: false
    property int _lockTries: 0

    function show(k) {
        if (!_ready) return
        kind = k
        active = true
        hide.restart()
    }

    function checkLocks() {
        _lockTries = 0
        locksDelay.restart()
    }

    onVolumeChanged: if (!_sinkSettling && Popups.current !== "audio") show("volume")
    onMutedChanged: if (!_sinkSettling && Popups.current !== "audio") show("volume")
    onSinkChanged: {
        _sinkSettling = true
        sinkSettle.restart()
    }

    PwObjectTracker { objects: [root.sink] }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.active = false
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: root._ready = true
    }

    Timer {
        id: sinkSettle
        interval: 600
        running: true
        onTriggered: root._sinkSettling = false
    }

    // Brilho: cada mudança da luz de fundo vira uma linha "change … (backlight)"
    Process {
        id: backlightWatch
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf(" change ") < 0 || Popups.current === "display") return
                root._brightnessPending = true
                Brightness.refresh()
            }
        }
    }

    Connections {
        target: Brightness
        function onRefreshed() {
            if (!root._brightnessPending) return
            root._brightnessPending = false
            if (Brightness.available) root.show("brightness")
        }
    }

    // Caps Lock e Num Lock: o estado muda logo depois da tecla, então lê com um pequeno atraso
    Timer {
        id: locksDelay
        interval: 80
        onTriggered: if (!locksGetter.running) locksGetter.running = true
    }

    Process {
        id: locksGetter
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            id: locksOut
            onStreamFinished: {
                let kb = null
                try {
                    const list = JSON.parse(locksOut.text).keyboards || []
                    kb = list.find(k => k.main) || list[list.length - 1] || null
                } catch (e) {}
                if (!kb) return
                const caps = !!kb.capsLock, num = !!kb.numLock
                const capsChanged = caps !== root.capsLock, numChanged = num !== root.numLock
                root.capsLock = caps
                root.numLock = num
                if (capsChanged) root.show("caps")
                else if (numChanged) root.show("num")
                else if (root._lockTries++ < 2) locksDelay.restart()   // ainda não mudou: tenta de novo
            }
        }
    }

    // Estado inicial das travas, sem aviso
    Component.onCompleted: locksGetter.running = true
}
