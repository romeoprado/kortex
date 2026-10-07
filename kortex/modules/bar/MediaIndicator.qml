import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.widgets

// Mídia tocando: ▶ Artista – Título (até 35 letras). Só aparece com algum player aberto.
// Clique: painel com capa e controles; clique do meio ou direito: tocar/pausar.
BarButton {
    id: root
    required property string screenName

    readonly property int maxChars: 35

    present: Media.present
    icon: Media.playing ? Icons.play : Icons.pause
    iconFilled: true
    label: Media.line.length > maxChars ? Media.line.slice(0, maxChars - 1).replace(/\s+$/, "") + "…" : Media.line
    color: Media.playing ? Theme.fg : Theme.fgDim
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) Popups.toggle("media", screenName)
        else Media.toggle()
    }
    // uma faixa por vez: um deslizar longo no touchpad não pula várias
    property real lastSkip: 0
    onWheel: wheel => {
        const n = wheelSteps(wheel)
        if (n === 0 || Date.now() - lastSkip < 400) return
        lastSkip = Date.now()
        if (n > 0) Media.previous()
        else Media.next()
    }

    BarPopup {
        id: popup
        target: root
        popupId: "media"
        screenName: root.screenName
        panelWidth: 380

        PopupTitle {
            text: "Mídia"
            icon: Icons.music
            subtitle: Media.identity
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // capa (ou a nota musical, quando o player não manda imagem)
            ClippingRectangle {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 84
                radius: Theme.radiusSmall
                color: Theme.bgAlt

                Icon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: Icons.music
                    size: 36
                    color: Theme.fgDim
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 168
                    sourceSize.height: 168
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: Media.title || Media.identity
                    color: Theme.fgBright
                    font.family: Theme.font
                    font.pixelSize: Theme.textLarge
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Media.artist
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Media.album
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    elide: Text.ElideRight
                }
            }
        }

        // andamento: barra e tempos (só quando o player informa a duração)
        ColumnLayout {
            Layout.fillWidth: true
            visible: (Media.player?.lengthSupported ?? false) && (Media.player?.length ?? 0) > 0
            spacing: 4

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.bgAlt

                Rectangle {
                    width: Media.player && Media.player.length > 0
                        ? track.width * Math.max(0, Math.min(1, Media.player.position / Media.player.length)) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }

                // clique na barra pula para aquele ponto, se o player deixar
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: Media.player?.canSeek ?? false
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => {
                        const p = Media.player
                        p.position = Math.max(0, Math.min(1, (mouse.x - 6) / track.width)) * p.length
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Media.clock(Media.player?.position ?? 0)
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    font.features: { "tnum": 1 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Media.clock(Media.player?.length ?? 0)
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    font.features: { "tnum": 1 }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            PlainButton {
                icon: Icons.skipPrevious
                enabled: Media.player?.canGoPrevious ?? false
                onClicked: Media.previous()
            }
            PlainButton {
                implicitWidth: 56
                icon: Media.playing ? Icons.pause : Icons.play
                highlighted: true
                enabled: Media.player?.canTogglePlaying ?? false
                onClicked: Media.toggle()
            }
            PlainButton {
                icon: Icons.skipNext
                enabled: Media.player?.canGoNext ?? false
                onClicked: Media.next()
            }
        }
    }
}
