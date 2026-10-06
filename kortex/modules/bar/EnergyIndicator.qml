import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Widget Energia: carga da bateria na barra; no painel, o modo de energia e os dados da bateria
BarButton {
    id: root
    required property string screenName

    readonly property var bat: Energy.battery
    property int hoveredMode: -1   // modo sob o mouse (índice em Energy.profiles), para a etiqueta
    // Etiqueta à direita do título: o modo sob o mouse ou, parado, o modo em uso (no acento, negrito)
    readonly property int currentMode: Energy.profiles.findIndex(p => p.id === Energy.profile)
    readonly property int tagIndex: hoveredMode >= 0 ? hoveredMode : currentMode

    // Largura da ficha da bateria: o rótulo mais comprido e um valor longo (data de fabricação) lado a lado,
    // mais o espaço entre eles (8) e as margens da ficha (12 + 12)
    FontMetrics { id: rowMetrics; font.family: Theme.font; font.pixelSize: Theme.textBody }
    readonly property real cardWidth: {
        void rowMetrics.font   // refaz a conta quando a fonte muda
        return rowMetrics.advanceWidth("Capacidade de fábrica") + rowMetrics.advanceWidth("00/00/0000") + 8 + 24
    }

    // Cabeçalho mais largo possível: ícone, "Energia" e o nome de modo mais comprido (em negrito)
    FontMetrics { id: tagMetrics; font.family: Theme.font; font.pixelSize: Theme.textSmall; font.bold: true }
    FontMetrics { id: titleMetrics; font.family: Theme.titleFont; font.pixelSize: Theme.textTitle; font.bold: true }
    readonly property real headerWidth: {
        void tagMetrics.font, titleMetrics.font   // refaz a conta quando a fonte muda
        const tag = Energy.profilesAvailable ? Math.max(0, ...Energy.profiles.map(p => tagMetrics.advanceWidth(p.text))) + 20 + 8 : 0
        return Theme.iconSize + 8 + 10 + titleMetrics.advanceWidth("Energia") + tag
    }

    // Linhas da ficha da bateria um ponto maiores que as do padrão
    component InfoRow: StatRow { textSize: Theme.textBody }

    icon: Energy.batteryIcon(bat)
    color: Energy.isLow(bat) ? Theme.red : Theme.fg
    active: popup.visible
    onClicked: Popups.toggle("energy", screenName)

    BarPopup {
        id: popup
        target: root
        popupId: "energy"
        screenName: root.screenName
        // Justo ao conteúdo: só os modos → a linha de botões; com bateria ou algum aviso (que quebra em
        // várias linhas) → a linha mais comprida da ficha da bateria; nunca menos que o cabeçalho
        panelWidth: Math.ceil(Math.max(root.headerWidth,
                              Energy.batteries.length > 0 || !Energy.profilesAvailable || Energy.degradation !== ""
                              ? root.cardWidth : Math.max(Energy.profiles.length * 52 - 8, 150))) + padding * 2

        PopupTitle {
            text: "Energia"
            icon: Icons.bolt

            // Etiqueta à direita do título: o modo em uso (acento, negrito) ou o modo sob o mouse.
            // Guarda o último texto para sumir inteira (sem encolher antes de apagar).
            Rectangle {
                id: tag
                readonly property bool inUse: root.hoveredMode < 0
                property string shown: ""
                implicitWidth: tagLabel.implicitWidth + 20
                implicitHeight: tagLabel.implicitHeight + 6
                radius: height / 2
                color: Theme.bgAlt
                opacity: Energy.profilesAvailable && root.tagIndex >= 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                function sync() { if (root.tagIndex >= 0) shown = Energy.profiles[root.tagIndex].text }
                Component.onCompleted: sync()
                Connections {
                    target: root
                    function onTagIndexChanged() { tag.sync() }
                }

                Text {
                    id: tagLabel
                    anchors.centerIn: parent
                    text: tag.shown
                    color: tag.inUse ? Theme.accent : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    font.bold: tag.inUse
                }
            }
        }

        // Modo de energia: um botão só com ícone por modo, os três dividindo a largura do painel;
        // o nome do modo fica na etiqueta do cabeçalho
        RowLayout {
            visible: Energy.profilesAvailable
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: Energy.profiles

                TileButton {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    icon: modelData.icon
                    selected: Energy.profile === modelData.id
                    onClicked: Energy.setProfile(modelData.id)
                    onContainsMouseChanged: {
                        if (containsMouse) root.hoveredMode = index
                        else if (root.hoveredMode === index) root.hoveredMode = -1
                    }
                }
            }
        }

        Text {
            visible: Energy.profilesAvailable && Energy.degradation !== ""
            Layout.fillWidth: true
            text: "Modo Desempenho limitado: " + Energy.degradation + "."
            color: Theme.yellow
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            wrapMode: Text.WordWrap
        }

        Text {
            visible: !Energy.profilesAvailable
            Layout.fillWidth: true
            text: "Modos de energia indisponíveis: instale o power‑profiles‑daemon."
            color: Theme.yellow
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            wrapMode: Text.WordWrap
        }

        // Uma ficha por bateria (notebooks com duas baterias mostram as duas)
        Repeater {
            model: Energy.batteries

            StatCard {
                required property var modelData
                required property int index
                readonly property var b: modelData
                readonly property real hours: Energy.hoursLeft(b)

                icon: Energy.batteryIcon(b)
                title: Energy.batteries.length > 1 ? "Bateria " + (index + 1) : "Bateria"
                subtitle: Energy.statusText(b)
                valueText: b.percent + "%"
                value: b.percent / 100
                lowAlert: true
                subtitleSize: Theme.textBody

                InfoRow {
                    label: b.status === "Charging" ? "Tempo até completar" : "Tempo restante"
                    value: hours >= 0 ? Energy.duration(hours) : ""
                }
                InfoRow {
                    label: b.status === "Charging" ? "Potência de carga" : "Consumo"
                    value: (b.status === "Charging" || b.status === "Discharging") && b.power >= 0.05 ? Theme.decimal(b.power, 1) + " W" : ""
                }
                InfoRow {
                    label: "Energia atual"
                    value: b.energyNow >= 0 ? Theme.decimal(b.energyNow, 1) + " Wh" : ""
                }
                InfoRow {
                    label: "Capacidade atual"
                    value: b.energyFull > 0 ? Theme.decimal(b.energyFull, 1) + " Wh" : ""
                }
                InfoRow {
                    label: "Capacidade de fábrica"
                    value: b.energyDesign > 0 ? Theme.decimal(b.energyDesign, 1) + " Wh" : ""
                }
                InfoRow {
                    readonly property real health: b.energyFull > 0 && b.energyDesign > 0 ? b.energyFull / b.energyDesign : -1
                    label: "Saúde"
                    value: health >= 0 ? Math.round(health * 100) + "%" : ""
                    warn: health >= 0 && health < 0.7
                }
                InfoRow {
                    label: "Ciclos de carga"
                    value: b.cycles >= 0 ? String(b.cycles) : ""
                }
                InfoRow {
                    label: "Tensão"
                    value: b.voltage > 0 ? Theme.decimal(b.voltage, 2) + " V" : ""
                }
                InfoRow {
                    label: "Temperatura"
                    value: b.temp >= 0 ? Theme.decimal(b.temp, 1) + " °C" : ""
                    warn: b.temp >= 50
                }
                InfoRow { label: "Tecnologia"; value: b.technology }
                InfoRow { label: "Fabricante"; value: b.manufacturer }
                InfoRow { label: "Modelo"; value: b.model }
                InfoRow { label: "Fabricação"; value: b.made }
            }
        }
    }
}
