import QtQuick
import QtQuick.Shapes
import qs.services

// Anel de carregamento indeterminado: um arco que cresce e encolhe enquanto gira sobre uma trilha
// discreta. `size` dá o diâmetro, `running` liga (parado, some). Não recebe cliques. Ideia do
// Spinner do dhrruvsharma/shell (GPLv3).
Item {
    id: root

    property real size: 16
    property real thickness: 2
    property color color: Theme.accent
    property bool running: true
    property int period: 800
    // rotação do anel e o pedaço do círculo que o arco cobre (graus)
    property real spin: 0
    property real sweep: 40

    implicitWidth: size
    implicitHeight: size
    opacity: running ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    NumberAnimation {
        target: root; property: "spin"; from: 0; to: 360
        duration: root.period; loops: Animation.Infinite; running: root.visible
    }

    // o arco estica até quase três quartos e volta, desencontrado da rotação
    SequentialAnimation {
        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { target: root; property: "sweep"; to: 270; duration: root.period * 0.9; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "sweep"; to: 40; duration: root.period * 0.9; easing.type: Easing.InOutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.color, 0.2)
            strokeWidth: root.thickness
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.size - root.thickness) / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.size - root.thickness) / 2; radiusY: radiusX
                startAngle: root.spin - 90; sweepAngle: root.sweep
            }
        }
    }
}
