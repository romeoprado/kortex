import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName

    icon: Weather.ready ? Weather.icon : (Weather.loading ? "" : Icons.cloud)
    label: Weather.ready ? Weather.temp + "°" : (Weather.loading ? "…" : "")
    active: popup.visible
    onClicked: Popups.toggle("weather", screenName)

    BarPopup {
        id: popup
        target: root
        popupId: "weather"
        screenName: root.screenName
        panelWidth: 450

        PopupTitle {
            text: Weather.location || "Clima"
            icon: Icons.location
            PlainButton {
                icon: Icons.refresh
                implicitWidth: 32
                implicitHeight: 28
                onClicked: Weather.refresh()
            }
        }

        RowLayout {
            visible: Weather.ready
            Layout.fillWidth: true
            spacing: 14

            Icon {
                text: Weather.icon
                color: Theme.accent
                size: 44
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text {
                    text: Weather.temp + "°C"
                    color: Theme.fgBright
                    font.family: Theme.font
                    font.pixelSize: 24
                    font.bold: true
                }
                Text {
                    text: Weather.desc
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
            }
        }

        RowLayout {
            visible: Weather.ready
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { k: "Sensação", v: Weather.feels + "°" },
                    { k: "Umidade", v: Weather.humidity + "%" },
                    { k: "Vento", v: Weather.wind + " km/h" }
                ]
                // Item + Column (não ColumnLayout): um layout aninhado não se estica na linha
                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1   // 3 colunas de mesma largura
                    implicitHeight: stat.implicitHeight
                    Column {
                        id: stat
                        Text { text: modelData.k; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                        Text { text: modelData.v; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                    }
                }
            }
        }

        Rectangle {
            visible: Weather.days.length > 0
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.muted
        }

        // Um dia por linha: com 7 dias, colunas lado a lado ficam apertadas demais
        ColumnLayout {
            visible: Weather.days.length > 0
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: Weather.days
                Rectangle {
                    id: dayRow
                    required property var modelData
                    required property int index
                    readonly property date day: new Date(modelData.date + "T12:00:00")

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Theme.radiusSmall
                    color: index === 0 ? Theme.bgAlt : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Text {
                            Layout.preferredWidth: 64
                            text: dayRow.index === 0 ? "Hoje"
                                : dayRow.day.toLocaleDateString(Qt.locale(), "ddd").replace(/\.$/, "") + " " + dayRow.day.getDate()
                            color: dayRow.index === 0 ? Theme.fgBright : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: dayRow.index === 0
                        }
                        Icon {
                            Layout.preferredWidth: 22
                            text: dayRow.modelData.icon
                            color: Theme.accent
                            size: 22
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dayRow.modelData.text
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                        Row {
                            Layout.preferredWidth: 58
                            layoutDirection: Qt.RightToLeft   // encosta à direita, como o texto que havia
                            spacing: 2
                            // Largura fixa (a de "100%"): o ícone de chuva fica na mesma coluna em todas as linhas
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: rainWidth.advanceWidth
                                horizontalAlignment: Text.AlignRight
                                text: dayRow.modelData.rain + "%"
                                color: Theme.fgDim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                TextMetrics { id: rainWidth; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; text: "100%" }
                            }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.rainChance
                                color: Theme.fgDim
                                size: Theme.fontSize + 1
                            }
                        }
                        Text {
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                            text: dayRow.modelData.min + "°"
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                            text: dayRow.modelData.max + "°"
                            color: Theme.fgBright
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                    }
                }
            }
        }

        Text {
            visible: Weather.error !== ""
            Layout.fillWidth: true
            text: Weather.error
            color: Theme.red
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
        }

        // Popups da barra não recebem teclado: digitar a cidade abre uma janela própria
        PlainButton {
            Layout.fillWidth: true
            alignLeft: true
            icon: Icons.location
            text: "Cidade: " + (Settings.data.weatherCity.trim() || "automática")
            onClicked: Popups.openCityPrompt()
        }
    }
}
