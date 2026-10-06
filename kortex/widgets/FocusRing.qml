import QtQuick
import qs.services

// Contorno de foco do teclado (Tab): aparece em volta do controle que está com o foco, só enquanto
// ele estiver com o foco. O clique do mouse não dá foco aos botões, então ele não aparece ao clicar.
Rectangle {
    property real baseRadius: Theme.radiusSmall

    anchors.fill: parent
    anchors.margins: -3
    radius: baseRadius + 3
    color: "transparent"
    border.color: Theme.accent
    border.width: 2
    visible: parent.activeFocus
}
