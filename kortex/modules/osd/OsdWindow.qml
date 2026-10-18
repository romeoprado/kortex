import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Aviso rápido (OSD) no centro/baixo da tela, no monitor em foco: ícone, barra e porcentagem para
// volume e brilho; ícone e texto para Caps Lock e Num Lock. Não recebe cliques nem teclado.
//
// Surge como uma gota com o ícone (cresce com um quique), abre em pílula e a barra sobe do zero até
// o nível; a cada passo seguinte o ícone dá um pulo e a barra brilha. Ao sumir, fecha de volta em gota
// e encolhe. A janela tem o tamanho da pílula aberta, com folga para o quique: só o desenho se move.
// Quique, escala e durações vêm de Motion (Configurações › Animações). Ideia do OsdPill do
// dhrruvsharma/shell (GPLv3).
PanelWindow {
    id: win

    readonly property bool level: Osd.kind === "volume" || Osd.kind === "brightness"
    readonly property real value: Osd.kind === "volume" ? Osd.volume : Osd.brightness
    readonly property bool dim: Osd.kind === "volume" && Osd.muted

    // folga em volta da pílula: o quique passa um pouco do tamanho final
    readonly property int pad: 10
    readonly property int bead: 44
    readonly property real iconW: Theme.iconSize + 2
    // largura da pílula aberta: fixa com barra; com texto, a do texto
    readonly property real openWidth: level ? 280 : 18 + iconW + 12 + lockText.implicitWidth + 18
    property real shownWidth: openWidth
    Behavior on shownWidth { enabled: Motion.enabled; NumberAnimation { duration: Motion.ms(220); easing.type: Easing.OutCubic } }

    // 0 = sumido, 1 = a gota inteira; 0 = gota, 1 = pílula aberta; 0 = a barra começa do zero, 1 = no
    // nível; 1 a cada passo, caindo a 0
    property real pop: 0
    property real grow: 0
    property real sweep: 1
    property real kick: 0
    // o nível desenhado, suavizado
    property real eased: Math.max(0, Math.min(1, value))
    Behavior on eased { enabled: Motion.enabled; NumberAnimation { duration: Motion.ms(260); easing.type: Easing.OutCubic } }

    function appear() {
        outro.stop()
        if (!Motion.enabled) {
            pop = 1; grow = 1; sweep = 1
            return
        }
        const fresh = pop === 0
        if (fresh) sweep = 0
        intro.popTime = fresh ? Motion.ms(240) : Math.round(Motion.ms(160) * (1 - Math.min(1, pop)))
        intro.lag = fresh ? Motion.ms(80) : 0
        intro.restart()
    }

    function disappear() {
        intro.stop()
        if (!Motion.enabled) {
            pop = 0; grow = 0
            return
        }
        outro.restart()
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors.bottom: true
    margins.bottom: 64 - pad
    exclusionMode: ExclusionMode.Normal   // com a barra embaixo, fica acima dela
    implicitWidth: Theme.snapUp(Math.max(280, openWidth) + 2 * pad, devicePixelRatio)
    implicitHeight: Theme.snapUp(bead + 2 * pad, devicePixelRatio)
    color: "transparent"
    visible: pop > 0 || intro.running
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "kortex-osd"

    Connections {
        target: Osd
        function onActiveChanged() { if (Osd.active) win.appear(); else win.disappear() }
        // um passo com a pílula já aberta: o ícone pula e a barra brilha
        function onPulseChanged() { if (Osd.active && win.grow > 0.9 && Motion.enabled) flare.restart() }
    }

    SequentialAnimation {
        id: intro
        property int popTime: 240
        property int lag: 80

        ParallelAnimation {
            NumberAnimation {
                target: win; property: "pop"; to: 1; duration: intro.popTime
                easing.type: Easing.OutBack; easing.overshoot: Motion.pick(1, 1.8, 2.4)
            }
            SequentialAnimation {
                PauseAnimation { duration: intro.lag }
                NumberAnimation { target: win; property: "grow"; to: 1; duration: Motion.ms(460); easing.type: Easing.OutQuint }
            }
            SequentialAnimation {
                PauseAnimation { duration: intro.lag + Motion.ms(90) }
                NumberAnimation { target: win; property: "sweep"; to: 1; duration: Motion.ms(620); easing.type: Easing.OutCubic }
            }
        }
    }

    SequentialAnimation {
        id: outro
        NumberAnimation { target: win; property: "grow"; to: 0; duration: Motion.ms(250); easing.type: Easing.InCubic }
        NumberAnimation {
            target: win; property: "pop"; to: 0; duration: Motion.ms(180)
            easing.type: Easing.InBack; easing.overshoot: Motion.pick(1, 1.8, 2.4)
        }
    }

    NumberAnimation { id: flare; target: win; property: "kick"; from: 1; to: 0; duration: Motion.ms(560); easing.type: Easing.OutCubic }

    GradientFrame {
        id: frame
        // centralizada, com a origem em pixel físico inteiro (a borda não borra com a pílula parada)
        x: Math.round((win.width - width) / 2 * win.devicePixelRatio) / win.devicePixelRatio
        y: win.pad
        width: win.bead + (win.shownWidth - win.bead) * win.grow
        height: win.bead
        radius: height / 2
        clip: true
        scale: Motion.pick(0.8, 0.6, 0.45) + (1 - Motion.pick(0.8, 0.6, 0.45)) * win.pop
        opacity: Math.max(0, Math.min(1, win.pop * 1.8))

        // o ícone vai do centro da gota para a ponta esquerda da pílula
        Icon {
            id: icon
            x: (win.bead - width) / 2 + (18 - (win.bead - width) / 2) * win.grow
            anchors.verticalCenter: parent.verticalCenter
            scale: 1 + 0.3 * win.kick
            text: Osd.kind === "volume" ? (Osd.muted || Osd.volume <= 0 ? Icons.volMute : Osd.volume > 0.5 ? Icons.volHigh : Icons.volLow)
                : Osd.kind === "brightness" ? Icons.sun
                : Osd.kind === "caps" ? Icons.capsLock : Icons.numLock
            color: win.dim ? Theme.fgDim : Theme.accent
            size: win.iconW
        }

        // o resto aparece quando a pílula já está quase aberta (até lá, o recorte da moldura o esconde)
        Item {
            x: 18 + win.iconW + 12
            width: win.openWidth - x - 18
            height: parent.height
            opacity: Math.max(0, Math.min(1, (win.grow - 0.55) / 0.45))

            // Volume e brilho: barra e porcentagem
            Rectangle {
                id: track
                visible: win.level
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - pct.width - 12
                height: 6 + 2 * win.kick
                radius: height / 2
                color: Theme.bgAlt

                Rectangle {
                    width: parent.width * win.eased * win.sweep
                    height: parent.height
                    radius: parent.radius
                    color: Qt.tint(win.dim ? Theme.fgDim : Theme.accent, Qt.alpha(Theme.fgBright, 0.45 * win.kick))
                }
            }

            Text {
                id: pct
                visible: win.level
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: pctMetrics.width
                horizontalAlignment: Text.AlignRight
                text: Math.round(win.value * 100) + "%"
                color: win.dim ? Theme.fgDim : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.textBody
                TextMetrics { id: pctMetrics; font.family: Theme.font; font.pixelSize: Theme.textBody; text: "100%" }
            }

            // Caps Lock e Num Lock: nome e estado
            Text {
                id: lockText
                visible: !win.level
                anchors.verticalCenter: parent.verticalCenter
                text: (Osd.kind === "caps" ? "Caps Lock " + (Osd.capsLock ? "ativado" : "desativado")
                                            : "Num Lock " + (Osd.numLock ? "ativado" : "desativado"))
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.textBody
            }
        }
    }
}
