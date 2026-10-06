import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    id: page
    signal closeRequested()
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Field {
            id: dir
            Layout.fillWidth: false
            Layout.preferredWidth: 320
            icon: Icons.folder
            text: Settings.data.wallpaperDir
            placeholder: "~/Pictures/Wallpapers"
            onAccepted: Settings.data.wallpaperDir = text.trim()
            onKeyPressed: event => {
                if (event.key === Qt.Key_Escape) { page.closeRequested(); event.accepted = true }
            }
        }

        Item { Layout.fillWidth: true }

        PlainButton {
            icon: Icons.refresh
            text: "Recarregar"
            onClicked: Theme.listWallpapers()
        }
    }

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Theme.wallpapers
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 240)))
        cellHeight: Math.round(cellWidth * 0.5625)
        focus: true
        keyNavigationEnabled: true
        Keys.onReturnPressed: if (currentIndex >= 0) Theme.setWallpaper(Theme.wallpapers[currentIndex])
        Keys.onEscapePressed: page.closeRequested()
        Keys.onDeletePressed: if (currentItem) currentItem.requestRemove()

        delegate: MouseArea {
            id: cell
            required property string modelData
            required property int index
            readonly property bool isCurrent: modelData === Settings.data.wallpaper
            readonly property bool removable: Theme.canRemoveWallpaper(modelData)
            readonly property string fileName: modelData.split("/").pop()
            property bool confirming: false   // 1º clique pede confirmação, o 2º move para a lixeira

            width: grid.cellWidth
            height: grid.cellHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onContainsMouseChanged: if (!containsMouse) confirming = false
            onClicked: mouse => {
                grid.currentIndex = index
                if (mouse.button === Qt.RightButton) {
                    requestRemove()
                    return
                }
                Theme.setWallpaper(modelData)
            }

            function requestRemove() {
                if (!removable) {
                    Theme.status = "Este papel de parede pertence a outro programa e não pode ser excluído aqui."
                    return
                }
                if (!confirming) {
                    confirming = true
                    confirmTimer.restart()
                    Theme.status = "Clique novamente para mover “" + fileName + "” para a lixeira."
                } else {
                    confirming = false
                    Theme.removeWallpaper(modelData)
                }
            }

            Timer {
                id: confirmTimer
                interval: 3000
                onTriggered: cell.confirming = false
            }

            GradientBorder {
                id: frame
                anchors.fill: parent
                anchors.margins: 6
                radius: Theme.radius
                fill: Theme.bgAlt
                borderWidth: cell.isCurrent ? 3 : 1
                color: cell.isCurrent ? Theme.accent
                     : (cell.containsMouse || grid.currentIndex === cell.index) ? Theme.fg : Theme.outline

                Image {
                    anchors.fill: parent
                    anchors.margins: frame.b
                    source: Theme.url(cell.modelData)
                    sourceSize.width: 480
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Lixeira: aparece ao passar o mouse, na imagem selecionada e enquanto pede confirmação
            Rectangle {
                id: trash
                visible: cell.removable && (cell.containsMouse || cell.confirming || grid.currentIndex === cell.index)
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 6 + frame.b + 6
                anchors.rightMargin: 6 + frame.b + 6
                width: cell.confirming ? confirmText.implicitWidth + 18 : 28
                height: 28
                radius: Theme.radiusSmall
                color: cell.confirming ? Theme.red : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.8)

                Icon {
                    anchors.centerIn: parent
                    visible: !cell.confirming
                    text: Icons.trash
                    color: trashArea.containsMouse ? Theme.red : Theme.fg
                    size: Theme.iconSize + 2
                }
                Text {
                    id: confirmText
                    anchors.centerIn: parent
                    visible: cell.confirming
                    text: "Excluir?"
                    color: Theme.bg
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    font.bold: true
                }
                MouseArea {
                    id: trashArea
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cell.requestRemove()
                }
            }
        }
    }

    Text {
        visible: Theme.wallpapers.length === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Nenhuma imagem encontrada. Coloque imagens em " + Settings.data.wallpaperDir + " ou instale um tema com a pasta backgrounds/."
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: Theme.textBody
        wrapMode: Text.Wrap
    }
}
