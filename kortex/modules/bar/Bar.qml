import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Barra superior (uma por monitor)
//  esquerda: lançador · áreas de trabalho · CPU/RAM
//  centro:   relógio/calendário · clima
//  direita:  teclado · bluetooth · wi-fi · som · tela · notificações · energia · sessão
//
// Dois estilos (Configurações › Barra › Estilo da barra):
//  Inteira (padrão): de ponta a ponta, colada à borda da tela.
//  Flutuante: solta da borda e das laterais (a Theme.gap px), centralizada, só da largura do
//    conteúdo e com o raio e a borda dos painéis (a borda pode ser desligada). A largura é
//    simétrica (o lado maior vale para os dois), para o relógio continuar no centro da tela.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property string screenName: modelData ? modelData.name : ""
    readonly property bool floating: Theme.barFloating
    // borda da barra flutuante: a dos painéis, ou nenhuma (Configurações › Barra › Borda da barra flutuante)
    readonly property int frameBorder: Settings.data.barBorder ? Theme.border : 0

    // folga entre os grupos e a ponta da barra, e entre os grupos e o relógio (estilo flutuante)
    readonly property int inset: floating ? Math.max(4, Math.round(Theme.radius / 2)) + frameBorder : 4
    readonly property int groupGap: 16
    readonly property real contentWidth: 2 * (Math.max(leftGroup.implicitWidth, rightGroup.implicitWidth) + inset + groupGap)
                                         + centerGroup.implicitWidth

    screen: modelData
    // sem âncoras laterais, o Hyprland centraliza a camada
    anchors { top: !Theme.barBottom; bottom: Theme.barBottom; left: !floating; right: !floating }
    margins.top: floating && !Theme.barBottom ? Theme.gap : 0
    margins.bottom: floating && Theme.barBottom ? Theme.gap : 0
    implicitWidth: floating ? Theme.snapUp(Math.min(contentWidth, (modelData ? modelData.width : 1920) - 2 * Theme.gap), devicePixelRatio) : 0
    implicitHeight: Theme.barHeight
    color: floating ? "transparent" : Theme.bg
    WlrLayershell.namespace: "kortex-bar"
    WlrLayershell.layer: WlrLayer.Top

    Behavior on color { ColorAnimation { duration: 300 } }

    // fundo da barra flutuante: a mesma moldura dos painéis
    GradientFrame {
        anchors.fill: parent
        visible: bar.floating
        borderWidth: bar.frameBorder
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    // Manter Acordado: a barra está sempre à vista, então segura o pedido de "não ficar inativo"
    IdleInhibitor {
        window: bar
        enabled: KeepAwake.active
    }

    // Espaço vazio da barra: a camada ClickAway começa abaixo dela, então fecha aqui também
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Popups.dismiss()
    }

    RowLayout {
        id: leftGroup
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: bar.inset }
        spacing: 2

        LauncherButton {}
        // espaçadores ao redor das áreas de trabalho, com folga só do lado de fora do conjunto
        Rectangle { Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 6; width: 4; height: 4; color: Theme.muted }
        Workspaces { shellScreen: bar.modelData }
        Rectangle { Layout.alignment: Qt.AlignVCenter; Layout.rightMargin: 6; width: 4; height: 4; color: Theme.muted }
        StatsIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("stats") }
    }

    RowLayout {
        id: centerGroup
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
        spacing: 0

        ClockIndicator { screenName: bar.screenName }
        WeatherIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("weather") }
    }

    RowLayout {
        id: rightGroup
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: bar.inset }
        spacing: 0

        KeyboardIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("keyboard") }
        BluetoothIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("bluetooth") }
        NetworkIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("network") }
        AudioIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("audio") }
        DisplayIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("display") }
        NotificationIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("notifications") }
        EnergyIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("energy") }
        PowerIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("power") }
    }
}
