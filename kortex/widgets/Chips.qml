import QtQuick
import QtQuick.Layouts
import qs.services

// Grupo de opções em botões; quebra de linha quando não cabe.
//   model: [{ label, value }]   current: valor selecionado   picked(value)
Flow {
    id: root

    property var model: []
    property var current: null
    signal picked(var value)

    Layout.fillWidth: true
    spacing: 6

    function same(a, b) {
        return typeof a === "number" && typeof b === "number" ? Math.abs(a - b) < 0.005 : a === b
    }

    Repeater {
        model: root.model
        PlainButton {
            required property var modelData
            text: modelData.label
            highlighted: root.same(modelData.value, root.current)
            onClicked: root.picked(modelData.value)
        }
    }
}
