import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Papel de parede desenhado pelo próprio shell, com transição suave.
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

        // clique duplo na área de trabalho abre o seletor rápido de papel de parede
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onDoubleClicked: if (!Popups.wallpaperCarouselOpen) Popups.toggleWallpaperCarousel()
        }
    }
}
