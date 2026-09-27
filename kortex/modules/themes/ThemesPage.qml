import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    id: page
    signal closeRequested()

    readonly property var shown: Theme.themes

    // Lista de estilos do Matugen, aberta pelo botão no cartão do tema
    property bool stylesOpen: false

    function toggleStyles(button) {
        if (stylesOpen) { stylesOpen = false; return }
        const p = button.mapToItem(grid.contentItem, 0, button.height + 4)
        stylesMenu.x = Math.max(0, p.x + button.width - stylesMenu.width)   // alinhada pela direita do botão
        stylesMenu.y = Math.max(grid.contentY, Math.min(p.y, grid.contentY + grid.height - stylesMenu.height))
        stylesOpen = true
    }

    // Botão pequeno sobre a imagem do cartão do Matugen (modo e estilo)
    component CardChip: MouseArea {
        id: chip
        property string icon: ""
        property string text: ""
        property string trailingIcon: ""
        property bool on: false

        implicitWidth: chipRow.implicitWidth + 14
        implicitHeight: 24
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        GradientBorder {
            anchors.fill: parent
            radius: Theme.radiusSmall
            borderWidth: 1
            fill: chip.on ? Theme.accent : Qt.alpha(Theme.bg, 0.85)
            color: chip.on ? Theme.accent : chip.containsMouse ? Theme.fg : Theme.muted
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            Icon {
                visible: chip.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                size: Theme.fontSize
                color: chip.on ? Theme.bg : Theme.fg
            }
            Text {
                visible: chip.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: chip.on ? Theme.bg : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
            Icon {
                visible: chip.trailingIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.trailingIcon
                size: Theme.fontSize
                color: chip.on ? Theme.bg : Theme.fgDim
            }
        }
    }

    spacing: 12

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: page.shown
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 240)))
        cellHeight: Math.round(cellWidth * 0.5625) + 44
        keyNavigationEnabled: true
        currentIndex: -1
        Component.onCompleted: forceActiveFocus()   // setas, Enter e Esc funcionam assim que a janela abre

        Keys.onReturnPressed: if (currentItem) Theme.apply(currentItem.modelData.name)
        Keys.onEscapePressed: {
            if (page.stylesOpen) page.stylesOpen = false
            else page.closeRequested()
        }
        Keys.onDeletePressed: if (currentItem) currentItem.requestRemove()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F2 && currentItem) { currentItem.startNaming("rename"); event.accepted = true }
        }

        // Com a lista de estilos aberta, um clique fora dela só a fecha (não aplica o tema de baixo)
        MouseArea {
            visible: page.stylesOpen
            z: 99
            y: grid.contentY
            width: grid.width
            height: grid.height
            onClicked: page.stylesOpen = false
        }

        // Lista de estilos do Matugen. Fica aqui (e não no cartão) para passar por cima dos outros cartões.
        GradientBorder {
            id: stylesMenu
            visible: page.stylesOpen
            z: 100
            width: 190
            height: stylesColumn.implicitHeight + 8
            radius: Theme.radiusSmall
            borderWidth: 1
            fill: Theme.bg
            color: Theme.muted

            Column {
                id: stylesColumn
                x: 4
                y: 4
                width: parent.width - 8

                Repeater {
                    model: Theme.matugenSchemes

                    MouseArea {
                        id: styleRow
                        required property var modelData
                        readonly property bool current: modelData.value === Settings.data.matugenScheme
                        width: stylesColumn.width
                        height: 28
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.stylesOpen = false
                            Theme.setMatugenOption("matugenScheme", modelData.value)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: styleRow.current ? Theme.accent : styleRow.containsMouse ? Theme.bgAlt : "transparent"
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: styleRow.modelData.label
                            color: styleRow.current ? Theme.bg : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: styleRow.current
                        }
                        Icon {
                            visible: styleRow.current
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.check
                            size: Theme.fontSize + 1
                            color: Theme.bg
                        }
                    }
                }
            }
        }

        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property bool isCurrent: modelData.name === Settings.data.theme
            readonly property bool removable: Theme.canRemove(modelData)
            property bool confirming: false   // 1º clique pede confirmação, o 2º exclui
            // Campo de nome no rodapé: "save" (Matugen: salvar as cores como tema novo) ou "rename"
            property string naming: ""
            readonly property bool renamable: Theme.canRename(modelData)
            readonly property bool dynamic: modelData.name === Theme.dynamicName   // cores do papel de parede em uso
            // Só o tema dinâmico (Matugen) mostra imagem (o papel de parede em uso); os demais sempre
            // mostram a amostra da paleta, nunca o screenshot do tema.
            readonly property string cover: dynamic ? Settings.data.wallpaper : ""

            width: grid.cellWidth
            height: grid.cellHeight

            function startNaming(mode) {
                if (mode === "rename" && !renamable) return
                naming = mode
                nameField.text = mode === "rename" ? Theme.prettyName(modelData.name) : ""
                Qt.callLater(() => { nameField.focusInput(); nameField.input.selectAll() })
            }

            function requestRemove() {
                if (!removable) return
                if (!confirming) {
                    confirming = true
                    confirmTimer.restart()
                    Theme.status = "Clique novamente para excluir “" + Theme.prettyName(modelData.name) + "”."
                } else {
                    confirming = false
                    Theme.remove(modelData.name)
                }
            }

            Timer {
                id: confirmTimer
                interval: 3000
                onTriggered: card.confirming = false
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: 6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onContainsMouseChanged: if (!containsMouse) card.confirming = false
                onClicked: mouse => {
                    grid.currentIndex = card.index
                    if (mouse.button === Qt.RightButton) {
                        card.requestRemove()
                        return
                    }
                    Theme.apply(card.modelData.name)
                }

                GradientBorder {
                    anchors.fill: parent
                    radius: Theme.radius
                    fill: Theme.bgAlt
                    borderWidth: card.isCurrent ? 2 : 1
                    color: card.isCurrent ? Theme.accent
                         : (area.containsMouse || grid.currentIndex === card.index) ? Theme.fg : Theme.muted

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Rectangle {
                            id: preview
                            // Lado de cada quadradinho das 16 cores (2 linhas de 8): até 18 px, menor se o cartão for estreito
                            readonly property int chip: Math.max(8, Math.min(18, Math.floor((width - 24 - 7 * 4) / 8)))
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 3
                            color: card.modelData.palette.bg
                            clip: true

                            Image {
                                id: cover
                                anchors.fill: parent
                                visible: status === Image.Ready
                                source: Theme.url(card.cover)
                                sourceSize.width: 480
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            // Tema do Matugen: modo (lua/sol) e estilo por cima da imagem. Com o tema ativo
                            // a troca vale na hora para tudo; sem ele, só as cores deste cartão mudam.
                            RowLayout {
                                visible: card.dynamic && Theme.matugenAvailable
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                spacing: 4

                                Repeater {
                                    model: Theme.matugenModes
                                    CardChip {
                                        required property var modelData
                                        icon: modelData.value === "light" ? Icons.sun : Icons.moon
                                        on: Settings.data.matugenMode === modelData.value
                                        onClicked: Theme.setMatugenOption("matugenMode", modelData.value)
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                CardChip {
                                    id: styleButton
                                    text: Theme.matugenSchemeLabel(Settings.data.matugenScheme)
                                    trailingIcon: page.stylesOpen ? Icons.up : Icons.down
                                    onClicked: page.toggleStyles(styleButton)
                                }
                            }

                            // Tema do Matugen: as 16 cores geradas por cima do papel de parede
                            Grid {
                                visible: card.dynamic && cover.visible
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                columns: 8
                                spacing: 4
                                Repeater {
                                    model: card.modelData.palette.swatch
                                    GradientBorder {
                                        required property var modelData
                                        width: preview.chip - 2
                                        height: preview.chip - 2
                                        radius: 3
                                        fill: modelData
                                        borderWidth: 1
                                        color: Theme.bg
                                    }
                                }
                            }

                            // Sem imagem: amostra da paleta
                            Column {
                                visible: !cover.visible
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: Theme.prettyName(card.modelData.name)
                                    color: card.modelData.palette.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 2
                                }

                                // As 16 cores do tema; o contorno fraco deixa ver as que são iguais ao fundo
                                Grid {
                                    columns: 8
                                    spacing: 4
                                    Repeater {
                                        model: card.modelData.palette.swatch
                                        GradientBorder {
                                            required property var modelData
                                            width: preview.chip
                                            height: preview.chip
                                            radius: 3
                                            fill: modelData
                                            borderWidth: 1
                                            color: Qt.alpha(card.modelData.palette.fg, 0.25)
                                        }
                                    }
                                }
                            }
                        }

                        // Nome: do tema novo (Matugen: Enter salva as cores atuais com esse nome) ou o
                        // novo nome deste tema (Enter renomeia). Esc cancela.
                        Field {
                            id: nameField
                            visible: card.naming !== ""
                            implicitHeight: 28
                            icon: card.naming === "save" ? Icons.save : Icons.edit
                            placeholder: card.naming === "save" ? "Nome do novo tema" : "Novo nome"
                            function finish() {
                                text = ""
                                card.naming = ""
                                grid.forceActiveFocus()
                            }
                            onAccepted: {
                                if (text.trim() === "") return
                                if (card.naming === "save") {
                                    if (Theme.savingDynamic) return
                                    Theme.saveDynamic(text)
                                } else {
                                    Theme.rename(card.modelData.name, text)
                                }
                                finish()
                            }
                            onKeyPressed: event => {
                                if (event.key === Qt.Key_Escape) { finish(); event.accepted = true }
                            }
                        }

                        RowLayout {
                            visible: card.naming === ""
                            Layout.fillWidth: true
                            spacing: 6

                            // Só o cartão com imagem (o dinâmico do Matugen) precisa do nome aqui: os
                            // demais já mostram o nome dentro do retângulo, e mostrar duas vezes é redundante
                            Text {
                                visible: cover.visible
                                Layout.fillWidth: true
                                text: Theme.prettyName(card.modelData.name)
                                color: card.isCurrent ? Theme.accent : Theme.fgBright
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: card.isCurrent
                                elide: Text.ElideRight
                            }

                            Item { visible: !cover.visible; Layout.fillWidth: true }

                            // No Matugen o modo já está nos botões sobre a imagem
                            Icon {
                                visible: !card.dynamic
                                text: card.modelData.palette.light ? Icons.sun : Icons.moon
                                color: Theme.fgDim
                                size: Theme.fontSize + 1
                            }

                            // Matugen: salvar as cores atuais como um tema novo, com nome
                            Icon {
                                visible: card.dynamic && Theme.matugenAvailable
                                text: Icons.save
                                color: saveArea.containsMouse ? Theme.accent : Theme.fgDim
                                size: Theme.fontSize + 2
                                opacity: area.containsMouse ? 1 : 0.5

                                MouseArea {
                                    id: saveArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.startNaming("save")
                                }
                            }

                            // Renomear (temas da sua pasta; F2 também)
                            Icon {
                                visible: card.renamable
                                text: Icons.edit
                                color: renameArea.containsMouse ? Theme.accent : Theme.fgDim
                                size: Theme.fontSize + 2
                                opacity: area.containsMouse ? 1 : 0.5

                                MouseArea {
                                    id: renameArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.startNaming("rename")
                                }
                            }

                            Item {
                                visible: card.removable
                                implicitWidth: card.confirming ? confirmText.implicitWidth : trashIcon.implicitWidth
                                implicitHeight: Math.max(trashIcon.implicitHeight, confirmText.implicitHeight)
                                opacity: (card.confirming || area.containsMouse) ? 1 : 0.5

                                Icon {
                                    id: trashIcon
                                    visible: !card.confirming
                                    text: Icons.trash
                                    color: trashArea.containsMouse ? Theme.red : Theme.fgDim
                                    size: Theme.fontSize + 2
                                }
                                Text {
                                    id: confirmText
                                    visible: card.confirming
                                    text: "Excluir?"
                                    color: Theme.red
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                }
                                MouseArea {
                                    id: trashArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.requestRemove()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: page.shown.length === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Nenhum tema encontrado. Cole a URL de um tema acima para instalar."
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
