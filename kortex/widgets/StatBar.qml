import QtQuick
import qs.services

// Barra de progresso fina. Com alert: true muda de cor conforme enche (amarelo > 60%, vermelho > 85%);
// alert: false mantém o acento, para valores que não são carga (como frequência).
// lowAlert: true avisa quando ESVAZIA (amarelo < 30%, vermelho ≤ 15%), como a bateria.
Rectangle {
    id: root
    property real value: 0
    property bool alert: true
    property bool lowAlert: false

    implicitHeight: 4
    radius: 2
    color: Theme.bg

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: parent.radius
        color: root.lowAlert ? (root.value <= 0.15 ? Theme.red : root.value < 0.3 ? Theme.yellow : Theme.accent)
             : root.alert && root.value > 0.85 ? Theme.red : root.alert && root.value > 0.6 ? Theme.yellow : Theme.accent
        Behavior on width { NumberAnimation { duration: 300 } }
    }
}
