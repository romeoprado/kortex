import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets

// Janela de salvar da captura e da gravação de tela (ScreenshotSave.qml e RecordSave.qml): prévia,
// nome, formato e pasta (atalhos e as subpastas da pasta atual). Clicar fora não descarta: só
// Descartar ou Esc.
//   Enter salva · Esc descarta
OverlayPanel {
    id: win

    // Screenshot ou ScreenRecord: pending, startDir, defaultName, folders, saving, error, conflict,
    // displayPath(), save(nome, pasta, formato, substituir) e discard()
    required property var tool
    property string titleIcon: ""
    property string title: ""
    property string subtitle: ""
    property string previewSource: ""
    property int previewWidth: 0
    property string previewBadge: ""   // texto no canto da prévia (a duração do vídeo)
    property var formats: []           // [{ label, value }]
    property string format: ""

    panelWidth: 560
    panelHeight: frame.implicitHeight

    property string dir: tool.startDir
    function save() {
        if (!tool.saving) tool.save(field.text, dir, format, tool.conflict !== "")
    }

    onDirChanged: {
        tool.conflict = ""
        dirCheck.running = false
        dirCheck.running = true
    }

    // Pasta que ainda não existe (é criada ao salvar): o FolderListModel mostraria outra no lugar
    property bool dirExists: true
    Process {
        id: dirCheck
        command: ["test", "-d", win.dir]
        running: true
        onExited: code => win.dirExists = code === 0
    }
    onFormatChanged: tool.conflict = ""

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
        Keys.onEscapePressed: win.tool.discard()
        Keys.onReturnPressed: win.save()
        Keys.onEnterPressed: win.save()

        ColumnLayout {
            id: column
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 12

            PopupTitle {
                icon: win.titleIcon
                text: win.title
                subtitle: win.subtitle

                PlainButton {
                    icon: Icons.close
                    implicitWidth: 34
                    onClicked: win.tool.discard()
                }
            }

            // Prévia
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 230
                radius: Theme.radiusSmall
                color: Theme.bgDark

                Image {
                    id: shot
                    anchors.fill: parent
                    anchors.margins: 6
                    source: win.previewSource
                    sourceSize.width: Math.min(win.previewWidth, 1100)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    cache: false
                }

                // no canto da imagem (não da caixa), como num reprodutor
                Rectangle {
                    visible: win.previewBadge !== "" && shot.status === Image.Ready
                    x: shot.x + (shot.width + shot.paintedWidth) / 2 - width - 8
                    y: shot.y + (shot.height + shot.paintedHeight) / 2 - height - 8
                    implicitWidth: badgeText.implicitWidth + 16
                    implicitHeight: badgeText.implicitHeight + 6
                    radius: height / 2
                    color: Qt.alpha(Theme.bgDark, 0.85)
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: win.previewBadge
                        color: Theme.fgBright
                        font.family: Theme.font
                        font.pixelSize: Theme.textSmall
                        font.bold: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Field {
                    id: field
                    icon: Icons.edit
                    placeholder: "Nome do arquivo"
                    text: win.tool.defaultName
                    onTextChanged: win.tool.conflict = ""
                    onAccepted: win.save()
                }

                Segmented {
                    model: win.formats
                    current: win.format
                    onPicked: value => win.format = value
                }
            }

            Chips {
                model: win.tool.folders
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
                            text: win.tool.displayPath(win.dir)
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
                            folder: win.dirExists ? Theme.url(win.dir) : ""
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
                            visible: !win.dirExists || list.count === 0
                            anchors.centerIn: parent
                            text: win.dirExists ? "Nenhuma subpasta." : "A pasta será criada ao salvar."
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
                text: win.tool.error !== "" ? win.tool.error
                    : win.tool.conflict !== "" ? "Já existe \"" + win.tool.conflict.split("/").pop() + "\" nesta pasta." : ""
                color: win.tool.error !== "" ? Theme.red : Theme.yellow
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
                    onClicked: win.tool.discard()
                }

                PlainButton {
                    highlighted: true
                    enabledLook: !win.tool.saving
                    text: win.tool.conflict !== "" ? "Substituir (Enter)" : "Salvar (Enter)"
                    onClicked: win.save()
                }
            }
        }
    }
}
