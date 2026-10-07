import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Tela "Exibição" do painel Recursos: o que aparece na barra e qual armazenamento.
ColumnLayout {
    id: root

    component Caption: Text {
        Layout.fillWidth: true
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: Theme.textSmall
        wrapMode: Text.Wrap
    }

    Layout.fillWidth: true
    spacing: 10

    Caption { text: "Mostrar na barra" }

    ToggleRow {
        text: "CPU"
        checked: Settings.data.statsCpu
        onToggled: value => Settings.data.statsCpu = value
    }

    ToggleRow {
        text: "RAM"
        checked: Settings.data.statsMem
        onToggled: value => Settings.data.statsMem = value
    }

    ToggleRow {
        visible: SystemStats.gpu !== null
        text: "GPU (uso)"
        checked: Settings.data.statsGpu
        onToggled: value => Settings.data.statsGpu = value
    }

    ToggleRow {
        visible: SystemStats.vramGpu !== null
        text: "GPU (memória de vídeo)"
        checked: Settings.data.statsVram
        onToggled: value => Settings.data.statsVram = value
    }

    ToggleRow {
        visible: SystemStats.disk !== null
        text: "Armazenamento"
        checked: Settings.data.statsDisk
        onToggled: value => Settings.data.statsDisk = value
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: SystemStats.disks.length > 1
        spacing: 10

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.muted }

        Caption { text: "Armazenamento na barra" }

        Chips {
            model: SystemStats.disks.map(d => ({ label: d.mount, value: d.mount }))
            current: SystemStats.disk ? SystemStats.disk.mount : ""
            onPicked: value => Settings.data.statsDiskMount = value
        }
    }
}
