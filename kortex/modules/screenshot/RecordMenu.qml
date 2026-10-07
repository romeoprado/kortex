import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

// Menu da gravação de tela (SHIFT+Print), igual ao da captura: Tela Inteira (o monitor em que o menu
// abriu), Janela (clique numa janela) ou Área (arraste um retângulo), mais o áudio: som do sistema
// e microfone (lembrados). A gravação começa assim que se escolhe; para, clique no tempo na barra
// ou repita o atalho.
//   1, 2, 3 escolhem · Esc fecha
LazyLoader {
    active: Popups.recordOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-record"
        panelWidth: 420
        panelHeight: frame.implicitHeight
        onDismissed: close()

        readonly property var modes: [
            { id: "screen", icon: Icons.shotScreen, text: "Tela Inteira" },
            { id: "window", icon: Icons.shotWindow, text: "Janela" },
            { id: "area", icon: Icons.shotArea, text: "Área" }
        ]

        function close() { Popups.recordOpen = false }

        GradientFrame {
            id: frame
            width: win.panelWidth
            implicitHeight: column.implicitHeight + 40
            color: Theme.bg
            radius: Theme.radius
            focus: true
            Keys.onEscapePressed: win.close()
            Keys.onPressed: event => {
                const i = event.key - Qt.Key_1
                if (i >= 0 && i < win.modes.length) {
                    ScreenRecord.start(win.modes[i].id)
                    event.accepted = true
                }
            }

            ColumnLayout {
                id: column
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 14

                PopupTitle {
                    icon: Icons.record
                    text: "Gravação de Tela"

                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: win.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: win.modes

                        TileButton {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: modelData.icon
                            text: modelData.text
                            onClicked: ScreenRecord.start(modelData.id)
                        }
                    }
                }

                // Áudio: uma linha por fonte, com o interruptor (a linha inteira alterna)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "recordSystemAudio", icon: Icons.systemAudio, text: "Áudio do Sistema" },
                            { key: "recordMicrophone", icon: Icons.microphone, text: "Microfone" }
                        ]

                        MouseArea {
                            id: source
                            required property var modelData
                            readonly property bool on: Settings.data[modelData.key]
                            function flip() { Settings.data[modelData.key] = !on }

                            Layout.fillWidth: true
                            implicitHeight: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: flip()

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSmall
                                color: source.containsMouse ? Qt.tint(Theme.bgAlt, Qt.alpha(Theme.accent, 0.08)) : Theme.bgAlt
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Icon {
                                    text: source.modelData.icon
                                    color: source.on ? Theme.accent : Theme.fgDim
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: source.modelData.text
                                    color: source.on ? Theme.fg : Theme.fgDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textBody
                                    elide: Text.ElideRight
                                }
                                Toggle {
                                    checked: source.on
                                    onToggled: source.flip()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
