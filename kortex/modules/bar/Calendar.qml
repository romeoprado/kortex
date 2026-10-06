import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    id: root

    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    // Tamanho do calendário em relação ao desenho original (fontes, setas, cantos e espaços);
    // a largura do painel fica em ClockIndicator.qml e as células acompanham a largura
    readonly property real size: 0.8

    Layout.fillWidth: true
    spacing: Math.round(8 * size)

    function reset() {
        today = new Date()
        month = today.getMonth()
        year = today.getFullYear()
    }

    function shift(delta) {
        let m = month + delta, y = year
        if (m < 0) { m = 11; y-- }
        if (m > 11) { m = 0; y++ }
        month = m
        year = y
    }

    // Mês e ano no padrão dos títulos dos outros painéis; clicar no título volta para hoje
    PopupTitle {
        icon: Icons.calendar
        clickable: true
        onClicked: root.reset()
        text: {
            const s = Qt.locale().standaloneMonthName(root.month, Locale.LongFormat)
            return s.charAt(0).toUpperCase() + s.slice(1) + " " + root.year
        }

        // Mês anterior e seguinte: botões com contorno, como os controles dos outros cabeçalhos
        PlainButton {
            icon: Icons.left
            implicitWidth: 34
            onClicked: root.shift(-1)
        }

        PlainButton {
            icon: Icons.right
            implicitWidth: 34
            onClicked: root.shift(1)
        }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: grid.locale
        delegate: Text {
            required property string shortName
            horizontalAlignment: Text.AlignHCenter
            text: shortName.replace(/\.$/, "")
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Math.round((Theme.textBody) * root.size)
        }
    }

    // O MonthGrid sempre gera 6 linhas e pode trazer uma semana inteira de outro mês, no começo (mês que
    // começa no primeiro dia da semana) ou no fim (mês de 4 ou 5 semanas). Ele mantém a altura das 6
    // linhas (senão as células se esticam) dentro de uma caixa que corta o excedente: a grade sobe até a
    // linha do dia 1 e a caixa só tem a altura das linhas que têm ao menos um dia do mês.
    Item {
        id: gridBox
        Layout.fillWidth: true
        Layout.preferredHeight: grid.cellSize * grid.rows + grid.spacing * (grid.rows - 1)
        clip: true

        MonthGrid {
            id: grid
            // Cada dia ocupa um quadrado: a altura da célula acompanha a largura dela (7 colunas)
            readonly property real cellSize: Math.max(0, (width - spacing * 6) / 7)
            readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
            // Posições (0…41) do dia 1 e do último dia do mês, avisadas pelas próprias células
            property int firstIndex: 0
            property int lastIndex: 41
            readonly property int firstRow: Math.floor(firstIndex / 7)
            readonly property int rows: Math.floor(lastIndex / 7) - firstRow + 1

            anchors.left: parent.left
            anchors.right: parent.right
            y: -firstRow * (cellSize + spacing)
            // Altura explícita: o MonthGrid divide a própria altura entre as 6 linhas, e a
            // altura dele vem da soma das células. Sem isso tudo colapsa para 0 e os dias somem.
            height: cellSize * 6 + spacing * 5
            month: root.month
            year: root.year
            locale: Qt.locale()
            spacing: 2

            delegate: Rectangle {
                id: cell
                required property var model
                readonly property bool firstDay: cell.model.month === grid.month && cell.model.day === 1
                readonly property bool lastDay: cell.model.month === grid.month && cell.model.day === grid.daysInMonth
                implicitHeight: grid.cellSize
                radius: Math.round(4 * root.size)
                color: cell.model.today ? Theme.accent : (dayArea.containsMouse ? Theme.bgAlt : "transparent")

                onFirstDayChanged: if (firstDay) grid.firstIndex = cell.model.index
                onLastDayChanged: if (lastDay) grid.lastIndex = cell.model.index
                Component.onCompleted: {
                    if (firstDay) grid.firstIndex = cell.model.index
                    if (lastDay) grid.lastIndex = cell.model.index
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.model.day
                    font.family: Theme.font
                    font.pixelSize: Math.round((Theme.textLarge) * root.size)
                    font.bold: cell.model.today
                    color: cell.model.today ? Theme.accentText
                         : cell.model.month === grid.month ? Theme.fg : Theme.muted
                }

                MouseArea { id: dayArea; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }
}
