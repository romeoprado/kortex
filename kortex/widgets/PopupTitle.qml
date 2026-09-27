import QtQuick
import QtQuick.Layouts
import qs.services

// Cabeçalho de painel: ícone (sem fundo nem contorno), título (e, se houver, uma linha de estado embaixo)
// à esquerda, controles à direita e, por baixo, um filete que esmaece a partir do acento.
// O ícone se alinha ao título principal, não à legenda. Com clickable: true, clicar no título emite clicked().
ColumnLayout {
    id: root
    property string text: ""
    property string icon: ""
    property string subtitle: ""
    property color tone: Theme.accent          // cor do ícone
    property color titleColor: Theme.fgBright
    property bool separator: true
    property bool clickable: false
    // Faixa de referência do cabeçalho: título, ícone e controles se centralizam nela, com ou sem
    // legenda, e a legenda fica pendurada embaixo. Assim o título está sempre à mesma distância da borda.
    readonly property real band: 38
    signal clicked()
    default property alias trailing: extra.data
    Layout.fillWidth: true
    spacing: 9

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // ícone + textos: é a área que responde ao clique quando clickable
        Item {
            id: lead
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            implicitWidth: leadRow.implicitWidth
            implicitHeight: Math.max(root.band, leadRow.implicitHeight)

            RowLayout {
                id: leadRow
                anchors.fill: parent
                spacing: 10

                // reserva o espaço do ícone, com largura fixa: os títulos ficam alinhados entre os
                // painéis, seja qual for o ícone (o ícone em si é desenhado abaixo)
                Item {
                    visible: root.icon !== ""
                    Layout.preferredWidth: Theme.iconSize + 8
                    Layout.preferredHeight: 1
                }

                ColumnLayout {
                    id: textCol
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.max(0, (root.band - titleText.implicitHeight) / 2)
                    spacing: 1

                    Text {
                        id: titleText
                        Layout.fillWidth: true
                        text: root.text
                        color: root.clickable && hit.containsMouse ? Theme.accent : root.titleColor
                        font.family: Theme.titleFont
                        font.pixelSize: Theme.fontSize + 5
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.subtitle !== ""
                        text: root.subtitle
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                    }
                }
            }

            // Altura das maiúsculas da fonte do título: o ícone se alinha ao centro delas (o das letras,
            // não o da caixa de texto, que reserva espaço para descendentes).
            TextMetrics {
                id: caps
                font: titleText.font
                text: "H"
            }

            // O ícone se alinha ao título principal, não ao conjunto título + subtítulo: seu centro
            // fica no centro do título, com ou sem legenda embaixo.
            Icon {
                visible: root.icon !== ""
                x: (Theme.iconSize + 8 - width) / 2
                y: leadRow.y + textCol.y + titleText.y + titleText.baselineOffset
                   + caps.tightBoundingRect.y + caps.tightBoundingRect.height / 2 - height / 2
                text: root.icon
                color: root.tone
                size: Math.round((Theme.iconSize + 4) * 1.1)
            }

            MouseArea {
                id: hit
                anchors.fill: parent
                enabled: root.clickable
                hoverEnabled: true
                cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.clicked()
            }
        }

        RowLayout {
            id: extra
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Math.max(0, (root.band - extra.implicitHeight) / 2)
            spacing: 8
        }
    }

    Rectangle {
        visible: root.separator
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(Theme.accent, 0.55)
    }
}
