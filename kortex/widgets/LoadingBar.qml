import QtQuick
import QtQuick.Layouts
import qs.services

// Faixa fina de "carregando" com o conteúdo já à vista (buscar redes, procurar atualizações): um
// pedaço no acento desliza de ponta a ponta sobre uma trilha discreta. Esmaece com `active`; apagada,
// ainda ocupa a altura (para a lista não pular), a menos que `collapse` seja true. Ideia do
// LoadingBar do dhrruvsharma/shell (GPLv3).
Item {
    id: root

    property bool active: false
    property bool collapse: false
    property color color: Theme.accent
    property real slide: 0   // posição do pedaço, 0…1

    Layout.fillWidth: true
    implicitHeight: 2
    opacity: active ? 1 : 0
    visible: !collapse || opacity > 0
    Behavior on opacity { NumberAnimation { duration: 220 } }

    NumberAnimation {
        target: root; property: "slide"; from: 0; to: 1
        duration: 1100; loops: Animation.Infinite; easing.type: Easing.InOutQuad
        running: root.opacity > 0
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(root.color, 0.15)
        clip: true

        Rectangle {
            width: parent.width * 0.3
            height: parent.height
            radius: height / 2
            x: -width + (parent.width + width) * root.slide
            color: root.color
        }
    }
}
