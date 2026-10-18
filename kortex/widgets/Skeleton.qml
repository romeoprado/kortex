import QtQuick
import qs.services

// Bloco de esqueleto: o lugar de um texto ou ícone que ainda está carregando, respirando devagar.
// `delay` atrasa o começo, para blocos vizinhos pulsarem em onda em vez de piscarem juntos (dê
// 0, 120, 240…). Tamanho e raio como num Rectangle. Ideia do SkeletonPulse do dhrruvsharma/shell
// (GPLv3).
Rectangle {
    id: root

    property int delay: 0
    property int period: 1400

    radius: Theme.radiusSmall
    color: Theme.bgAlt

    SequentialAnimation {
        running: root.visible
        PauseAnimation { duration: root.delay }
        SequentialAnimation {
            loops: Animation.Infinite
            NumberAnimation { target: root; property: "opacity"; to: 0.35; duration: root.period / 2; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: root.period / 2; easing.type: Easing.InOutSine }
        }
    }
}
