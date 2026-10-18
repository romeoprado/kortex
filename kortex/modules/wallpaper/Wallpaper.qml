import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Papel de parede desenhado pelo próprio shell, com transição suave. Não recebe cliques nem teclado.
// A troca esmaece ou, com outro efeito escolhido em Configurações › Animações (wallpaperTransition),
// passa pelo shader shaders/wallpaper_transition.frag (círculo, íris, tinta, ladrilhos, varredura, falha).
// Desative em settings.json (wallpaperEnabled: false) se preferir hyprpaper/swww.
Variants {
    model: Settings.data.wallpaperEnabled ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property ShellScreen modelData
        readonly property string path: Theme.previewWallpaper !== "" ? Theme.previewWallpaper : Settings.data.wallpaper

        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.bg
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "kortex-wallpaper"

        // Troca com esmaecimento: cada imagem nova entra numa camada por cima e surge quando termina de
        // carregar; ao ficar opaca, as de baixo são descartadas. A anterior não é recarregada, então nunca
        // pisca o fundo, e trocas rápidas (carrossel) se sobrepõem sem saltos.
        readonly property int fadeMs: Theme.previewWallpaper !== "" ? 400 : 700

        // Troca com efeito (Configurações › Animações › Troca do papel de parede): em vez de esmaecer,
        // a imagem anterior e a nova viram texturas (ShaderEffectSource, que esconde as duas) e o shader
        // shaders/wallpaper_transition.frag desenha a passagem por cima. Só existe durante a troca; uma
        // troca nova no meio de outra termina a anterior na hora e parte dela. No carrossel, mais curta.
        readonly property var shaderModes: ({ circle: 0, iris: 1, ink: 2, tiles: 3, scan: 4, glitch: 5 })
        readonly property var shaderMs: ({ circle: 1100, iris: 1300, ink: 1500, tiles: 1300, scan: 1100, glitch: 950 })
        readonly property string effect: Motion.enabled && shaderModes[Settings.data.wallpaperTransition] !== undefined
            ? Settings.data.wallpaperTransition : ""
        property bool shading: false
        property real progress: 0

        onPathChanged: show(false)
        Component.onCompleted: show(true)

        function show(instant) {
            // Camadas ainda carregando nunca apareceram: saem, para não decodificar imagens puladas
            for (const c of stack.children.slice())
                if (!c.fading && c.status !== Image.Ready) c.destroy()
            if (path !== "") layer.createObject(stack, { source: Theme.url(path), instant: instant })
        }

        function dropBelow(top) {
            for (const c of stack.children.slice()) {
                if (c === top) break
                c.destroy()
            }
        }

        // a camada por baixo de `top` já à vista (a imagem de onde a troca parte)
        function shownBelow(top) {
            let below = null
            for (const c of stack.children) {
                if (c === top) break
                if (c.status === Image.Ready && c.opacity >= 1) below = c
            }
            return below
        }

        // true: a troca vai pelo shader; false: a camada esmaece como antes
        function shade(img) {
            if (effect === "") return false
            finishShade()
            const from = shownBelow(img)
            if (!from) return false
            img.opacity = 1   // escondida pelo ShaderEffectSource até o fim
            fromSrc.sourceItem = from
            toSrc.sourceItem = img
            fx.mode = shaderModes[effect]
            shading = true
            progress = 0
            shadeAnim.duration = Motion.ms(shaderMs[effect] * (Theme.previewWallpaper !== "" ? 0.6 : 1))
            shadeAnim.restart()
            return true
        }

        function finishShade() {
            if (!shading) return
            shading = false
            shadeAnim.stop()
            const top = toSrc.sourceItem
            fromSrc.sourceItem = null
            toSrc.sourceItem = null
            if (top) dropBelow(top)
        }

        Item {
            id: stack
            anchors.fill: parent
        }

        Component {
            id: layer

            Image {
                id: img
                property bool instant: false
                property bool fading: false

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // em pixels da tela: o tamanho do monitor é lógico (a 1.6×, 1600 × 1000 num painel de
                // 2560 × 1600), e a imagem decodificada nele sairia ampliada e borrada
                sourceSize.width: Math.round(win.modelData.width * win.devicePixelRatio)
                sourceSize.height: Math.round(win.modelData.height * win.devicePixelRatio)
                opacity: 0
                onStatusChanged: {
                    if (status === Image.Ready) {
                        fading = true
                        if (!instant && win.shade(img)) return
                        fadeIn.duration = instant ? 0 : win.fadeMs
                        fadeIn.start()
                    } else if (status === Image.Error) {
                        destroy()
                    }
                }

                NumberAnimation {
                    id: fadeIn
                    target: img
                    property: "opacity"
                    to: 1
                    easing.type: Easing.InOutQuad
                    onFinished: win.dropBelow(img)
                }
            }
        }

        ShaderEffectSource {
            id: fromSrc
            anchors.fill: parent
            visible: false
            hideSource: true
            textureSize: Qt.size(width * win.devicePixelRatio, height * win.devicePixelRatio)
        }

        ShaderEffectSource {
            id: toSrc
            anchors.fill: parent
            visible: false
            hideSource: true
            textureSize: Qt.size(width * win.devicePixelRatio, height * win.devicePixelRatio)
        }

        ShaderEffect {
            id: fx
            property variant fromTex: fromSrc
            property variant toTex: toSrc
            property real progress: win.progress
            property real mode: 0
            property real aspect: width / Math.max(1, height)
            property color edgeColor: Theme.accent
            anchors.fill: parent
            visible: win.shading
            fragmentShader: Qt.resolvedUrl("../../shaders/wallpaper_transition.frag.qsb")
        }

        NumberAnimation {
            id: shadeAnim
            target: win
            property: "progress"
            from: 0
            to: 1
            easing.type: Easing.InOutCubic
            onFinished: if (win.progress >= 1) win.finishShade()
        }

        // clique duplo na área de trabalho abre o seletor rápido de papel de parede
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onDoubleClicked: if (!Popups.wallpaperCarouselOpen) Popups.toggleWallpaperCarousel()
        }
    }
}
