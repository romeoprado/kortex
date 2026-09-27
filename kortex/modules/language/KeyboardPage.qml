import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// À esquerda: layouts ativos (clique troca, setas reordenam), atalho para alternar e campo de teste.
// À direita: busca no catálogo do xkeyboard-config para adicionar mais layouts.
RowLayout {
    id: page
    signal closeRequested()
    spacing: 16

    readonly property bool full: Keyboard.layouts.length >= Keyboard.maxLayouts

    // Sem busca: layouts base antes das variantes. Com busca: código exato, depois o que começa
    // com o termo, depois o resto (sempre em ordem alfabética dentro de cada grupo)
    readonly property var results: {
        const words = search.text.trim().toLowerCase().split(/\s+/).filter(w => w)
        const rank = e => words.length === 0 ? (e.variant ? 1 : 0)
            : (e.code === words[0] ? 0 : (e.code.startsWith(words[0]) || e.name.toLowerCase().startsWith(words[0])) ? 1 : 2)
        return Keyboard.catalog
            .filter(e => words.every(w => e.search.includes(w)))
            .sort((a, b) => (rank(a) - rank(b)) || (a.order - b.order))
    }

    function addFirst() {
        const first = results.find(e => !Keyboard.hasLayout(e))
        if (first) Keyboard.addLayout(first)
    }

    function focusSearch() { search.focusInput() }

    onVisibleChanged: if (visible) Qt.callLater(focusSearch)
    Component.onCompleted: Qt.callLater(() => { if (visible) focusSearch() })

    component Section: Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        color: Theme.fgBright
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 1
        font.bold: true
    }

    component Caption: Text {
        Layout.fillWidth: true
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        wrapMode: Text.Wrap
    }

    // ── layouts ativos ──────────────────────────────────────────────────
    Flickable {
        id: scroller
        // largura fixa: um layout aninhado não respeita só o preferredWidth
        Layout.preferredWidth: 340
        Layout.minimumWidth: 340
        Layout.maximumWidth: 340
        Layout.fillHeight: true
        clip: true
        contentHeight: left.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: left
            width: scroller.width - 12
            spacing: 8

            Text {
                text: "Layouts Ativos"
                color: Theme.fgBright
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 3
                font.bold: true
            }

            Repeater {
                model: Keyboard.layouts

                Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isActive: index === Keyboard.activeIndex

                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 4
                    color: "transparent"

                    GradientBorder {
                        anchors.fill: parent
                        radius: row.radius
                        borderWidth: 1
                        fill: row.isActive ? Theme.selection : (hover.containsMouse ? Theme.bgAlt : "transparent")
                        color: row.isActive ? Theme.accent : Theme.muted
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Keyboard.switchTo(row.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 8

                        Text {
                            Layout.preferredWidth: Math.min(84, Math.max(40, implicitWidth))
                            text: Keyboard.labelOf(row.modelData)
                            color: row.isActive ? Theme.fgBright : Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Keyboard.nameOf(row.modelData)
                            color: row.isActive ? Theme.fgBright : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        PlainButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            enabled: row.index > 0
                            icon: Icons.up
                            onClicked: Keyboard.moveLayout(row.index, -1)
                        }
                        PlainButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            enabled: row.index < Keyboard.layouts.length - 1
                            icon: Icons.down
                            onClicked: Keyboard.moveLayout(row.index, 1)
                        }
                        PlainButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            danger: true
                            enabled: Keyboard.layouts.length > 1
                            icon: Icons.trash
                            onClicked: Keyboard.removeLayout(row.index)
                        }
                    }
                }
            }

            Caption {
                visible: Keyboard.error !== ""
                text: Keyboard.error
                color: Theme.red
            }

            Section { text: "Atalho para Alternar" }
            Chips {
                model: Keyboard.switchKeys
                current: Keyboard.switchKey
                onPicked: value => Keyboard.setSwitchKey(value)
            }

            Section { text: "Testar" }
            Field {
                icon: Icons.keyboard
                placeholder: "Digite aqui para testar o layout"
                onKeyPressed: event => {
                    if (event.key === Qt.Key_Escape) { page.closeRequested(); event.accepted = true }
                }
            }

            Section { text: "Console e Login" }
            Caption {
                text: "Aplica os layouts ao console e à tela de login. Pede a senha de administrador."
            }
            PlainButton {
                Layout.fillWidth: true
                enabled: !Keyboard.systemBusy
                icon: Icons.download
                text: Keyboard.systemBusy ? "Gravando…" : "Gravar no Sistema"
                onClicked: Keyboard.applySystem()
            }
            Caption {
                visible: Keyboard.systemMessage !== ""
                text: Keyboard.systemMessage
                color: Keyboard.systemFailed ? Theme.red : Theme.green
            }
        }
    }

    Rectangle {
        Layout.fillHeight: true
        implicitWidth: 1
        color: Theme.muted
    }

    // ── adicionar ───────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        Text {
            text: "Adicionar Layout"
            color: Theme.fgBright
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 3
            font.bold: true
        }

        Field {
            id: search
            icon: Icons.search
            placeholder: "Buscar por nome ou código (ex.: portuguese, br, dvorak)"
            onAccepted: page.addFirst()
            onKeyPressed: event => {
                if (event.key === Qt.Key_Escape) { page.closeRequested(); event.accepted = true }
            }
        }

        Caption {
            visible: page.full
            text: "Limite de " + Keyboard.maxLayouts + " layouts. Remova um para adicionar outro."
            color: Theme.yellow
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: page.results

            delegate: MouseArea {
                id: item
                required property var modelData
                readonly property bool taken: Keyboard.hasLayout(modelData)

                width: ListView.view.width
                height: 36
                enabled: !taken && !page.full
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Keyboard.addLayout(modelData)

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: item.containsMouse && item.enabled ? Theme.bgAlt : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    opacity: item.taken || page.full ? 0.5 : 1

                    Text {
                        Layout.fillWidth: true
                        text: item.modelData.name
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        text: item.modelData.code
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Icon {
                        Layout.preferredWidth: 16
                        text: item.taken ? Icons.check : Icons.plus
                        color: item.taken ? Theme.green : Theme.accent
                        size: Theme.iconSize
                    }
                }
            }
        }

        Text {
            visible: page.results.length === 0
            Layout.fillWidth: true
            text: Keyboard.catalog.length === 0
                ? "Catálogo de layouts não encontrado (pacote xkeyboard-config)."
                : "Nenhum layout encontrado."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            wrapMode: Text.Wrap
        }

        Caption { text: "Enter adiciona o primeiro resultado." }
    }
}
