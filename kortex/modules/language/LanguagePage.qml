import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Idioma do sistema (LANG) e formato de hora. Idiomas ainda não gerados aparecem na lista:
// escolher um deles habilita em /etc/locale.gen, roda o locale-gen e define como padrão.
ColumnLayout {
    id: page
    signal closeRequested()
    spacing: 10

    property string sel: ""

    readonly property var selected: Language.entries.find(e => e.code === sel) ?? null
    readonly property var results: {
        const words = search.text.trim().toLowerCase().split(/\s+/).filter(w => w)
        return Language.entries.filter(e => words.every(w => e.search.includes(w)))
    }

    function focusSearch() { search.focusInput() }

    onVisibleChanged: if (visible) Qt.callLater(focusSearch)
    Component.onCompleted: Qt.callLater(() => { if (visible) focusSearch() })

    component Caption: Text {
        Layout.fillWidth: true
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        wrapMode: Text.Wrap
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Idioma do sistema"
            color: Theme.fgBright
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 3
            font.bold: true
        }
        Text {
            Layout.fillWidth: true
            text: Language.currentName + "  ·  " + Language.current
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
    }

    Field {
        id: search
        icon: Icons.search
        placeholder: "Buscar idioma (ex.: english, deutsch, ja_JP)"
        onAccepted: if (page.results.length > 0) page.sel = page.results[0].code
        onKeyPressed: event => {
            if (event.key === Qt.Key_Escape) { page.closeRequested(); event.accepted = true }
        }
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
            readonly property bool chosen: modelData.code === page.sel

            width: ListView.view.width
            height: 36
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.sel = modelData.code
            onDoubleClicked: if (!modelData.current) Language.setLanguage(modelData.code)

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: item.chosen ? Theme.selection : item.containsMouse ? Theme.bgAlt : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: item.modelData.name
                    color: item.chosen ? Theme.fgBright : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: item.modelData.current
                    elide: Text.ElideRight
                }
                Text {
                    text: item.modelData.code
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
                Text {
                    Layout.preferredWidth: 78
                    horizontalAlignment: Text.AlignRight
                    text: item.modelData.current ? "em uso" : item.modelData.installed ? "instalado" : "a gerar"
                    color: item.modelData.current ? Theme.green : Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }
    }

    Text {
        visible: page.results.length === 0
        Layout.fillWidth: true
        text: "Nenhum idioma encontrado."
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.muted }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Caption {
            text: page.selected === null ? "Escolha um idioma na lista."
                : page.selected.current ? "Este já é o idioma do sistema."
                : page.selected.installed ? "Vale a partir do próximo login. Pede a senha de administrador."
                : "Este idioma ainda não foi gerado: o locale-gen roda antes de defini-lo. Vale a partir do próximo login e pede a senha de administrador."
        }

        PlainButton {
            highlighted: true
            enabled: page.selected !== null && !page.selected.current && !Language.busy
            icon: Icons.globe
            text: Language.busy ? "Aplicando…" : "Definir como idioma do sistema"
            onClicked: Language.setLanguage(page.sel)
        }
    }

    Caption {
        visible: Language.message !== ""
        text: Language.message
        color: Language.failed ? Theme.red : Theme.green
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: "Relógio de 24 horas"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Toggle {
            checked: Settings.data.use24h
            onToggled: value => Settings.data.use24h = value
        }
    }
}
