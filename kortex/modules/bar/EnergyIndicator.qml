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

    // Largura da ficha da bateria: o rótulo mais comprido e um valor longo (data de fabricação) lado a lado,
    // mais o espaço entre eles (8) e as margens da ficha (12 + 12)
    FontMetrics { id: rowMetrics; font.family: Theme.font; font.pixelSize: Theme.textBody }
    readonly property real cardWidth: {
        void rowMetrics.font   // refaz a conta quando a fonte muda
        return rowMetrics.advanceWidth("Capacidade de fábrica") + rowMetrics.advanceWidth("00/00/0000") + 8 + 24
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
        // várias linhas) → a linha mais comprida da ficha da bateria
        panelWidth: Math.ceil(Energy.batteries.length > 0 || !Energy.profilesAvailable || Energy.degradation !== ""
                              ? root.cardWidth : Math.max(Energy.profiles.length * 52 - 8, 150)) + padding * 2

        PopupTitle { text: "Energia"; icon: Icons.bolt }

        // Modo de energia: um botão só com ícone por modo e, embaixo, uma etiqueta com o nome do modo
        // em uso (no acento) ou do modo sob o mouse
        RowLayout {
            visible: Energy.profilesAvailable
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: Energy.profiles

                TileButton {
                    required property var modelData
                    required property int index

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

        ButtonTag {
            visible: Energy.profilesAvailable
            Layout.fillWidth: true
            readonly property int current: Energy.profiles.findIndex(p => p.id === Energy.profile)
            index: root.hoveredMode >= 0 ? root.hoveredMode : current
            text: index >= 0 ? Energy.profiles[index].text : ""
            textColor: root.hoveredMode >= 0 ? Theme.fg : Theme.accent
            bold: root.hoveredMode < 0
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
