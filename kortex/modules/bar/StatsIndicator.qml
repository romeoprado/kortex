import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName

    property bool configuring: false

    // O que a barra mostra, na ordem: [{ icon, text, hot }]. Sem nenhum item ligado sobra só o ícone,
    // para o botão continuar existindo.
    readonly property var items: {
        const d = Settings.data, s = SystemStats, list = []
        const add = (icon, text, hot) => list.push({ icon: icon, text: text, hot: hot })
        if (d.statsCpu) add(Icons.cpu, s.pct(s.cpu), s.cpu > 0.9)
        if (d.statsMem) add(Icons.ram, s.pct(s.mem), s.mem > 0.9)
        if (d.statsGpu && s.gpu) add(Icons.gpu, s.pct(s.gpu.util), s.gpu.util > 0.9)
        if (d.statsVram && s.vramGpu) {
            const g = s.vramGpu
            add(Icons.vram, s.pct(g.vramUsed / g.vramTotal), g.vramUsed / g.vramTotal > 0.9)
        }
        if (d.statsDisk && s.disk) add(Icons.disk, s.pct(s.disk.frac), s.disk.frac > 0.9)
        if (list.length === 0) list.push({ icon: Icons.cpu, text: "", hot: false })
        return list
    }

    implicitWidth: content.implicitWidth + 16
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) Settings.runInTerminal(["btop"])
        else Popups.toggle("stats", screenName)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.items

            Row {
                required property var modelData
                readonly property real iconInkRight: Math.max(0, iconInk.advanceWidth - iconInk.tightBoundingRect.x - iconInk.tightBoundingRect.width)
                readonly property color tone: modelData.hot ? Theme.red : root.shownColor
                spacing: Math.max(0, root.labelGap - iconInkRight)   // mesma distância visível dos outros itens

                TextMetrics {
                    id: iconInk
                    font: statIcon.font
                    text: statIcon.text
                }

                TextMetrics {
                    id: digits
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    text: "000"
                }

                Icon {
                    id: statIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.icon
                    color: parent.tone
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.text !== ""
                    width: Math.max(implicitWidth, digits.width)   // largura mínima de 3 caracteres: os itens seguintes não pulam
                    text: modelData.text
                    color: parent.tone
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }
    }

    BarPopup {
        id: popup
        target: root
        popupId: "stats"
        screenName: root.screenName
        panelWidth: 400
        onWantedChanged: if (!wanted) root.configuring = false

        PopupTitle {
            text: root.configuring ? "Exibição" : "Recursos"
            icon: root.configuring ? Icons.cog : Icons.chart

            PlainButton {
                implicitWidth: 30
                implicitHeight: 26
                icon: root.configuring ? Icons.check : Icons.cog
                highlighted: root.configuring
                onClicked: root.configuring = !root.configuring
            }
        }

        StatsCards { visible: !root.configuring }
        StatsSettings { visible: root.configuring }
    }
}
