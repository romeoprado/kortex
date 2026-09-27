import QtQuick
import QtQuick.Layouts
import qs.services

// Lista de fontes instaladas, com busca; cada nome aparece na própria fonte.
//   current: família escolhida ("" = a padrão)   picked(family)   closeRequested()
ColumnLayout {
    id: root

    property string current: ""
    property string fallback: ""      // família que vale quando current está vazio
    property string filter: ""
    readonly property var families: {
        const seen = {}
        const out = []
        for (const f of Qt.fontFamilies()) {
            if (!seen[f]) { seen[f] = true; out.push(f) }
        }
        return out.sort((a, b) => a.localeCompare(b))
    }
    readonly property var shown: {
        const q = filter.trim().toLowerCase()
        return q ? families.filter(f => f.toLowerCase().includes(q)) : families
    }
    signal picked(string family)
    signal closeRequested()

    Layout.fillWidth: true
    spacing: 8

    Field {
        id: search
        icon: Icons.search
        placeholder: "Buscar fonte…  (" + root.families.length + " instaladas)"
        onTextChanged: root.filter = text
        onKeyPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested()
                event.accepted = true
            }
        }
        Component.onCompleted: focusInput()
    }

    GradientBorder {
        Layout.fillWidth: true
        Layout.preferredHeight: 210
        radius: Theme.radiusSmall
        fill: Theme.bgDark
        borderWidth: 1
        color: Theme.muted

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            spacing: 1

            delegate: MouseArea {
                id: item
                required property string modelData
                readonly property bool chosen: modelData === (root.current || root.fallback)

                width: ListView.view.width
                height: 34
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(modelData)

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: item.chosen ? Theme.selection : item.containsMouse ? Theme.bgAlt : "transparent"
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: item.modelData
                    color: item.chosen ? Theme.accent : Theme.fgBright
                    font.family: item.modelData
                    font.pixelSize: Theme.fontSize + 3
                    font.bold: item.chosen
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            visible: root.shown.length === 0
            anchors.centerIn: parent
            text: "Nenhuma fonte encontrada."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
