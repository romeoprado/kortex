import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services

// Barra superior (uma por monitor)
//  esquerda: lançador · áreas de trabalho · CPU/RAM
//  centro:   relógio/calendário · clima
//  direita:  teclado · bluetooth · wi-fi · som · tela · notificações · energia · sessão
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property string screenName: modelData ? modelData.name : ""

    screen: modelData
    anchors { top: !Theme.barBottom; bottom: Theme.barBottom; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bg
    WlrLayershell.namespace: "kortex-bar"
    WlrLayershell.layer: WlrLayer.Top

    Behavior on color { ColorAnimation { duration: 300 } }

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
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 4 }
        spacing: 2

        LauncherButton {}
        // espaçadores ao redor das áreas de trabalho, com folga só do lado de fora do conjunto
        Rectangle { Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 6; width: 4; height: 4; color: Theme.muted }
        Workspaces { shellScreen: bar.modelData }
        Rectangle { Layout.alignment: Qt.AlignVCenter; Layout.rightMargin: 6; width: 4; height: 4; color: Theme.muted }
        StatsIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("stats") }
    }

    RowLayout {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
        spacing: 0

        ClockIndicator { screenName: bar.screenName }
        WeatherIndicator { screenName: bar.screenName; visible: Settings.barItemVisible("weather") }
    }

    RowLayout {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 4 }
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
