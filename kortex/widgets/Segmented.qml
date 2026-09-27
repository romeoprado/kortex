import QtQuick
import QtQuick.Layouts
import qs.services

// Opções lado a lado; a atual fica em destaque.
//   model: [{ label, value }]   current: valor selecionado   picked(value)
Row {
    id: root

    property var model: []
    property var current: null
    signal picked(var value)

    spacing: 6

    Repeater {
        model: root.model

        PlainButton {
            required property var modelData
            text: modelData.label
            highlighted: modelData.value === root.current
            onClicked: root.picked(modelData.value)
        }
    }
}
