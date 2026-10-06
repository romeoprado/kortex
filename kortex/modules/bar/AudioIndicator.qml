import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    function nodeName(n) { return n ? (n.description || n.nickname || n.name) : "" }
    function setVolume(v) {
        if (!sink?.audio) return
        sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    icon: muted || volume <= 0 ? Icons.audioOff : Icons.audio
    color: muted ? Theme.fgDim : Theme.fg
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton && sink?.audio) sink.audio.muted = !sink.audio.muted
        else if (mouse.button === Qt.RightButton) Settings.shell(Settings.data.audioApp)
        else Popups.toggle("audio", screenName)
    }
    onWheel: wheel => setVolume(volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks)
    }

    BarPopup {
        id: popup
        target: root
        popupId: "audio"
        screenName: root.screenName
        panelWidth: 340

        PopupTitle {
            text: "Som"
            icon: Icons.audio
        }

        Text {
            Layout.fillWidth: true
            text: root.sink ? "Saída: " + root.nodeName(root.sink) : "Nenhuma saída de áudio"
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            elide: Text.ElideRight
        }

        SliderBar {
            icon: root.icon
            value: root.volume
            dimmed: root.muted
            onMoved: v => root.setVolume(v)
            onIconClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
        }

        Text {
            visible: root.source !== null
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: "Entrada: " + root.nodeName(root.source)
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            elide: Text.ElideRight
        }

        SliderBar {
            visible: root.source !== null
            icon: root.source?.audio?.muted ? Icons.micOff : Icons.mic
            value: root.source?.audio?.volume ?? 0
            dimmed: root.source?.audio?.muted ?? false
            onMoved: v => {
                if (!root.source?.audio) return
                root.source.audio.muted = false
                root.source.audio.volume = v
            }
            onIconClicked: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
        }

        Rectangle {
            visible: root.sinks.length > 1
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.muted
        }

        Text {
            visible: root.sinks.length > 1
            text: "Saída"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.textBody
            font.bold: true
        }

        Repeater {
            model: root.sinks.length > 1 ? root.sinks : []

            MouseArea {
                id: dev
                required property var modelData
                readonly property bool current: modelData === root.sink

                Layout.fillWidth: true
                implicitHeight: 34
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Pipewire.preferredDefaultAudioSink = modelData

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: dev.current ? Theme.selectionTint : (dev.containsMouse ? Theme.bgAlt : "transparent")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10
                    Icon {
                        text: dev.current ? Icons.check : Icons.headphones
                        color: dev.current ? Theme.accent : Theme.fgDim
                        size: Theme.fontSize + 2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.nodeName(dev.modelData)
                        color: dev.current ? Theme.fgBright : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.textBody
                        elide: Text.ElideRight
                    }
                }
            }
        }

        PlainButton {
            Layout.fillWidth: true
            icon: Icons.cog
            text: "Mixer de Áudio"
            onClicked: {
                Popups.close()
                Settings.shell(Settings.data.audioApp)
            }
        }
    }
}
