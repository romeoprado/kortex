import QtQuick
import qs.services

// Ícone do Google (Material Symbols): `text` recebe um nome de Icons (ou do catálogo), `size` o
// tamanho em px e `filled` liga o preenchimento. Use no lugar de um Text com glifo.
Text {
    id: root

    property real size: Theme.iconSize
    property bool filled: false

    font.family: Icons.family
    font.pixelSize: size
    // eixos da fonte variável; opsz acompanha o tamanho (20 a 48) para o traço ficar proporcional
    font.variableAxes: ({
        "wght": Icons.weight,
        "FILL": filled ? 1 : 0,
        "GRAD": 0,
        "opsz": Math.max(20, Math.min(48, Math.round(size)))
    })
    // Preenchido, a fonte variável sobrepõe contornos e o desenho padrão do Qt deixa furos (o sino ganhava
    // um traço escuro); o desenho nativo (FreeType) preenche certo
    renderType: filled ? Text.NativeRendering : Text.QtRendering
    color: Theme.fg
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
