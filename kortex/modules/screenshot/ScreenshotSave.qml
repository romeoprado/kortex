import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.services
import qs.widgets

// Janela de salvar a captura: prévia, nome, formato (PNG ou JPEG) e pasta (atalhos e as subpastas da
// pasta atual). Abre sozinha quando há uma captura pendente (Screenshot.pending). Clicar fora não
// descarta a captura: só Descartar ou Esc. A pasta e o formato usados ficam salvos para a próxima.
//   Enter salva · Esc descarta
LazyLoader {
    active: Screenshot.pending !== ""

    OverlayPanel {
        id: win

        layerNamespace: "kortex-screenshot-save"
        panelWidth: 560
        panelHeight: frame.implicitHeight

        property string dir: Screenshot.startDir
        property string format: Settings.data.screenshotFormat === "jpeg" ? "jpeg" : "png"
        function save() {
            if (!Screenshot.saving) Screenshot.save(field.text, dir, format, Screenshot.conflict !== "")
        }

        onDirChanged: Screenshot.conflict = ""
        onFormatChanged: Screenshot.conflict = ""

        Component.onCompleted: {
            field.focusInput()
            field.input.selectAll()
        }

        GradientFrame {
            id: frame
            width: win.panelWidth
            implicitHeight: column.implicitHeight + 40
            color: Theme.bg
            radius: Theme.radius
            focus: true
            Keys.onEscapePressed: Screenshot.discard()
            Keys.onReturnPressed: win.save()
            Keys.onEnterPressed: win.save()

            ColumnLayout {
                id: column
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 12

                PopupTitle {
                    icon: Icons.screenshot
                    text: "Salvar Captura"
                    subtitle: Screenshot.pixelWidth + " × " + Screenshot.pixelHeight + " px"

                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: Screenshot.discard()
                    }
                }

                // Prévia
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230
                    radius: Theme.radiusSmall
                    color: Theme.bgDark

                    Image {
                        anchors.fill: parent
                        anchors.margins: 6
                        source: Screenshot.pending !== "" ? "file://" + Screenshot.pending : ""
                        sourceSize.width: Math.min(Screenshot.pixelWidth, 1100)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        cache: false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Field {
                        id: field
                        icon: Icons.edit
                        placeholder: "Nome do arquivo"
                        text: Screenshot.defaultName
                        onTextChanged: Screenshot.conflict = ""
                        onAccepted: win.save()
                    }

                    Segmented {
                        model: [{ label: "PNG", value: "png" }, { label: "JPEG", value: "jpeg" }]
                        current: win.format
                        onPicked: value => win.format = value
                    }
                }

                Chips {
                    model: Screenshot.folders
                    current: win.dir
                    onPicked: value => win.dir = value
                }

                // Pasta atual e as subpastas dela
                GradientBorder {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 176
                    radius: Theme.radiusSmall
                    fill: Theme.bgDark
                    borderWidth: 1
                    color: Theme.outline

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            PlainButton {
                                icon: Icons.parentFolder
                                implicitWidth: 34
                                implicitHeight: 30
                                enabled: win.dir !== "/"
                                onClicked: win.dir = win.dir.slice(0, win.dir.lastIndexOf("/")) || "/"
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Screenshot.displayPath(win.dir)
                                color: Theme.fgBright
                                font.family: Theme.font
                                font.pixelSize: Theme.textBody
                                font.bold: true
                                elide: Text.ElideMiddle
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.muted
                        }

                        ListView {
                            id: list
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 1

                            model: FolderListModel {
                                id: folders
                                folder: "file://" + win.dir
                                showFiles: false
                                showHidden: false
                                showDotAndDotDot: false
                                sortCaseSensitive: false
                            }

                            delegate: MouseArea {
                                id: row
                                required property string fileName
                                required property string filePath

                                width: ListView.view.width
                                height: 30
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.dir = filePath

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: row.containsMouse ? Theme.bgAlt : "transparent"
                                }

                                Icon {
                                    id: glyph
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.folder
                                    color: row.containsMouse ? Theme.accent : Theme.fgDim
                                    size: Theme.iconSize - 1
                                }

                                Text {
                                    anchors.left: glyph.right
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.fileName
                                    color: row.containsMouse ? Theme.fgBright : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.textBody
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                visible: list.count === 0
                                anchors.centerIn: parent
                                text: "Nenhuma subpasta."
                                color: Theme.fgDim
                                font.family: Theme.font
                                font.pixelSize: Theme.textBody
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Screenshot.error !== "" ? Screenshot.error
                        : Screenshot.conflict !== "" ? "Já existe \"" + Screenshot.conflict.split("/").pop() + "\" nesta pasta." : ""
                    color: Screenshot.error !== "" ? Theme.red : Theme.yellow
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    PlainButton {
                        text: "Descartar (Esc)"
                        onClicked: Screenshot.discard()
                    }

                    PlainButton {
                        highlighted: true
                        enabledLook: !Screenshot.saving
                        text: Screenshot.conflict !== "" ? "Substituir (Enter)" : "Salvar (Enter)"
                        onClicked: win.save()
                    }
                }
            }
        }
    }
}
