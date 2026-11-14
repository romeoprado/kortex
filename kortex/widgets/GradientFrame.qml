import QtQuick
import qs.services

// Moldura dos painéis: fundo arredondado com borda de cor sólida (o acento do tema, sem ajuste, e a
// espessura em pixels lógicos: iguais às bordas das janelas do Hyprland). O fundo é o Theme.surface,
// que fica translúcido com a opacidade dos painéis abaixo de 100% (Configurações › Aparência).
// Use no lugar de um Rectangle com border.color; os filhos entram por cima da borda.
Rectangle {
    id: root

    property alias borderWidth: ring.borderWidth
    property alias borderColor: ring.color

    color: Theme.surface
    radius: Theme.radius

    GradientBorder {
        id: ring
        anchors.fill: parent
        radius: root.radius
        color: Theme.borderColor
        scaled: true
    }
}
