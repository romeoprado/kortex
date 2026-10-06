import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Seletor rápido de papel de parede (SUPER+SHIFT+W): se a área de trabalho atual tem janelas, leva a
// uma área vazia do mesmo monitor e, ao fechar, volta à anterior. A prévia é o próprio papel de parede
// do shell (Theme.previewWallpaper), visto por trás de um carrossel embaixo. Setas, roda do mouse,
// arrastar ou clicar numa imagem mudam a prévia na hora; Enter (ou clique na imagem do centro) aplica;
// Esc ou clique fora do carrossel cancela e volta ao papel de parede anterior. Com o papel de parede
// do shell desligado (wallpaperEnabled: false), a prévia é desenhada aqui, cobrindo a tela.
LazyLoader {
    active: Popups.wallpaperCarouselOpen

    PanelWindow {
        id: win

        // Cópia fixa da lista: trocar o modelo faz o PathView perder a posição, então a lista relida
        // ao abrir só entra enquanto ninguém navegou
        property var list: []
        property bool moved: false
        readonly property string original: Settings.data.wallpaper
        readonly property string selected: list[view.currentIndex] ?? ""
        // Miniatura do centro, na proporção da tela
        readonly property int thumbW: Math.round(Math.min(300, width / 5.5))
        readonly property int thumbH: Math.round(thumbW * (screen ? screen.height / screen.width : 0.625))
        property bool ready: false   // só previa depois de posicionar o carrossel no papel de parede atual
        // Sem a camada de papel de parede do shell, a prévia é desenhada aqui mesmo
        readonly property bool overlay: !Settings.data.wallpaperEnabled
        // Área de trabalho de onde o usuário veio ("" = já estava numa vazia e fica nela)
        property string returnTo: ""

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Normal   // respeita a faixa da barra: ela continua à vista
        color: overlay ? Theme.bg : "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kortex-wallpaper-carousel"

        function close(applyIt) {
            if (applyIt && selected !== "" && selected !== original) Theme.setWallpaper(selected)
            Popups.wallpaperCarouselOpen = false
        }

        // Carrega a lista e põe o carrossel no papel de parede em uso
        function load() {
            ready = false
            list = Theme.wallpapers.slice()
            const i = Math.max(0, list.indexOf(original))
            view.positionViewAtIndex(i, PathView.Center)
            view.currentIndex = i
            ready = list.length > 0
        }

        function step(d) {
            moved = true
            if (d > 0) view.incrementCurrentIndex()
            else view.decrementCurrentIndex()
        }

        onSelectedChanged: if (ready && selected !== "") Theme.previewWallpaper = selected

        Connections {
            target: Theme
            function onWallpapersChanged() { if (!win.moved) win.load() }
        }

        Component.onCompleted: {
            const ws = Hyprland.focusedMonitor?.activeWorkspace
            if (!overlay && ws && ws.toplevels.values.length > 0) {
                returnTo = ws.id > 0 ? String(ws.id) : "name:" + ws.name
                Hyprland.dispatch("workspace emptym")
            }
            load()
            Theme.listWallpapers()
            view.forceActiveFocus()
        }
        Component.onDestruction: {
            Theme.previewWallpaper = ""
            if (returnTo !== "") Hyprland.dispatch("workspace " + returnTo)
        }

        // ── Prévia em tela cheia, só sem o papel de parede do shell ───────
        Loader {
            anchors.fill: parent
            active: win.overlay
            sourceComponent: stageComponent
        }

        Component {
            id: stageComponent

            Item {
                id: stage
                readonly property string path: win.ready ? win.selected : win.original

                onPathChanged: {
                    back.source = front.source
                    back.opacity = 1
                    front.source = Theme.url(path)
                }

                Image {
                    id: front
                    anchors.fill: parent
                    source: Theme.url(stage.path)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: stage.width * win.devicePixelRatio
                    sourceSize.height: stage.height * win.devicePixelRatio
                    onStatusChanged: if (status === Image.Ready) fade.restart()
                }

                Image {
                    id: back
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: stage.width * win.devicePixelRatio
                    sourceSize.height: stage.height * win.devicePixelRatio
                    opacity: 0
                }

                NumberAnimation {
                    id: fade
                    target: back
                    property: "opacity"
                    to: 0
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Clique fora do carrossel cancela; a roda do mouse anda pelo carrossel (acumulada: touchpad manda passos pequenos)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real wheelAcc: 0
            onClicked: win.close(false)
            onWheel: wheel => {
                wheelAcc += (wheel.angleDelta.x !== 0 ? -wheel.angleDelta.x : wheel.angleDelta.y)
                while (wheelAcc >= 120) { win.step(-1); wheelAcc -= 120 }
                while (wheelAcc <= -120) { win.step(1); wheelAcc += 120 }
            }
        }

        // Sombra embaixo, para o carrossel e os textos se destacarem de qualquer imagem
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: win.thumbH + 170
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.45; color: Qt.alpha(Theme.bg, 0.6) }
                GradientStop { position: 1; color: Qt.alpha(Theme.bg, 0.92) }
            }
        }

        PathView {
            id: view
            anchors { horizontalCenter: parent.horizontalCenter; bottom: caption.top; bottomMargin: 18 }
            width: Math.min(parent.width - 40, pathItemCount * win.thumbW * 0.82)
            height: win.thumbH + 12
            model: win.list
            pathItemCount: Math.min(win.list.length, 5)
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: 220
            snapMode: PathView.SnapToItem
            focus: true

            onMovementStarted: win.moved = true   // arrastando
            Keys.onLeftPressed: win.step(-1)
            Keys.onRightPressed: win.step(1)
            Keys.onReturnPressed: win.close(true)
            Keys.onEnterPressed: win.close(true)
            Keys.onEscapePressed: win.close(false)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Home) { win.moved = true; currentIndex = 0; event.accepted = true }
                else if (event.key === Qt.Key_End) { win.moved = true; currentIndex = count - 1; event.accepted = true }
            }

            // Miniaturas menores e esmaecidas nas pontas, a do centro inteira e por cima
            path: Path {
                startX: 0
                startY: view.height / 2
                PathAttribute { name: "itemScale"; value: 0.62 }
                PathAttribute { name: "itemOpacity"; value: 0.45 }
                PathAttribute { name: "itemZ"; value: 0 }
                PathLine { x: view.width / 2; y: view.height / 2 }
                PathAttribute { name: "itemScale"; value: 1 }
                PathAttribute { name: "itemOpacity"; value: 1 }
                PathAttribute { name: "itemZ"; value: 10 }
                PathLine { x: view.width; y: view.height / 2 }
                PathAttribute { name: "itemScale"; value: 0.62 }
                PathAttribute { name: "itemOpacity"; value: 0.45 }
                PathAttribute { name: "itemZ"; value: 0 }
            }

            delegate: Item {
                id: card
                required property string modelData
                required property int index
                readonly property bool isCurrent: PathView.isCurrentItem
                readonly property bool inUse: modelData === win.original

                width: win.thumbW
                height: win.thumbH
                scale: PathView.itemScale ?? 1
                opacity: PathView.itemOpacity ?? 1
                z: PathView.itemZ ?? 0

                GradientBorder {
                    id: frame
                    anchors.fill: parent
                    radius: Theme.radius
                    fill: Theme.bgAlt
                    borderWidth: card.isCurrent ? 3 : 1
                    color: card.isCurrent ? Theme.accent : hover.containsMouse ? Theme.fg : Theme.outline

                    Image {
                        anchors.fill: parent
                        anchors.margins: frame.b
                        source: Theme.url(card.modelData)
                        sourceSize.width: 480
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                // O papel de parede em uso
                Rectangle {
                    visible: card.inUse
                    anchors { top: parent.top; right: parent.right; margins: 10 }
                    width: inUseRow.implicitWidth + 14
                    height: 24
                    radius: Theme.radiusSmall
                    color: Qt.alpha(Theme.bg, 0.85)

                    Row {
                        id: inUseRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { anchors.verticalCenter: parent.verticalCenter; text: Icons.check; color: Theme.accent; size: Theme.fontSize + 2 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Em uso"
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.textSmall
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.isCurrent) win.close(true)
                        else {
                            win.moved = true
                            view.currentIndex = card.index
                        }
                    }
                }
            }
        }

        // Nome do arquivo, posição e teclas
        ColumnLayout {
            id: caption
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            width: Math.min(parent.width - 40, 900)
            spacing: 6

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: win.list.length === 0
                    ? "Nenhum papel de parede encontrado. Escolha uma pasta em Temas › Papéis de Parede."
                    : win.selected.split("/").pop() + "   ·   " + (view.currentIndex + 1) + " / " + win.list.length
                color: Theme.fgBright
                font.family: Theme.font
                font.pixelSize: Theme.textBody
                font.bold: win.list.length > 0
                elide: Text.ElideMiddle
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: win.list.length === 0 ? "Esc fecha"
                    : "Enter: aplicar   ·   Esc: cancelar"
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.textSmall
            }
        }
    }
}
