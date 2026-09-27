import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Configurações › Aparência: fontes, tamanho do texto, cantos e bordas
SettingsPage {
    id: page

    property string picking: ""    // "" | "main" | "title": qual seletor de fonte está aberto

    SettingsSection { text: "Fontes" }

    SettingRow {
        title: "Fonte principal"
        Text {
            Layout.maximumWidth: 190
            text: Theme.font
            color: Theme.fgBright
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        PlainButton {
            text: page.picking === "main" ? "Fechar" : "Alterar…"
            onClicked: page.picking = page.picking === "main" ? "" : "main"
        }
        PlainButton {
            text: "Padrão"
            enabled: Settings.data.mainFont !== ""
            onClicked: Settings.data.mainFont = ""
        }
    }

    Loader {
        active: page.picking === "main"
        visible: active
        Layout.fillWidth: true
        sourceComponent: FontPicker {
            current: Settings.data.mainFont
            fallback: Theme.baseFont
            onPicked: family => Settings.data.mainFont = family
            onCloseRequested: page.picking = ""
        }
    }

    SettingRow {
        title: "Fonte dos títulos"
        Text {
            Layout.maximumWidth: 190
            text: Theme.titleFont
            color: Theme.fgBright
            font.family: Theme.titleFont
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            elide: Text.ElideRight
        }
        PlainButton {
            text: page.picking === "title" ? "Fechar" : "Alterar…"
            onClicked: page.picking = page.picking === "title" ? "" : "title"
        }
        PlainButton {
            text: "Padrão"
            enabled: Settings.data.titleFont !== ""
            onClicked: Settings.data.titleFont = ""
        }
    }

    Loader {
        active: page.picking === "title"
        visible: active
        Layout.fillWidth: true
        sourceComponent: FontPicker {
            current: Settings.data.titleFont
            fallback: "Iosevka Fixed SmBd Ex"
            onPicked: family => Settings.data.titleFont = family
            onCloseRequested: page.picking = ""
        }
    }

    SettingRow {
        title: "Tamanho do texto"
        Segmented {
            current: Settings.data.fontSize
            model: [
                { label: "Pequeno", value: 11 },
                { label: "Normal", value: 12 },
                { label: "Grande", value: 13 }
            ]
            onPicked: v => Settings.data.fontSize = v
        }
    }

    SettingsSection { text: "Cantos e Bordas" }

    SettingRow {
        title: "Raio dos cantos"
        SliderBar {
            Layout.fillWidth: false
            Layout.preferredWidth: 260
            value: Settings.data.radius / 20
            valueText: Settings.data.radius + " px"
            step: 1 / 20
            onMoved: v => Settings.data.radius = Math.round(v * 20)
        }
    }

    SettingRow {
        title: "Espessura das bordas"
        SliderBar {
            Layout.fillWidth: false
            Layout.preferredWidth: 260
            value: Theme.border / 5
            valueText: Theme.border + " px"
            step: 1 / 5
            onMoved: v => Settings.data.borderWidth = Math.round(v * 5)
        }
    }

    SettingRow {
        title: "Aplicar às janelas do Hyprland"
        Toggle {
            checked: Settings.data.hyprSyncAppearance
            onToggled: v => Settings.data.hyprSyncAppearance = v
        }
    }

    SettingsSection { text: "Terminal" }

    SettingRow {
        title: "Opacidade do terminal"
        SliderBar {
            Layout.fillWidth: false
            Layout.preferredWidth: 260
            value: (TerminalStyle.percent - 30) / 70
            valueText: TerminalStyle.percent + "%"
            step: 1 / 14
            onMoved: v => Settings.data.terminalOpacity = 30 + Math.round(v * 14) * 5
        }
    }

    SettingRow {
        title: "Desfoque do terminal"
        dimmed: TerminalStyle.percent >= 100
        Toggle {
            checked: Settings.data.terminalBlur
            onToggled: v => Settings.data.terminalBlur = v
        }
    }

    SettingsSection { text: "Tema" }

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumHeight: 38
        spacing: 8

        PlainButton {
            icon: Icons.brush
            text: "Temas"
            onClicked: Popups.openPicker("themes")
        }
        PlainButton {
            icon: Icons.image
            text: "Papéis de Parede"
            onClicked: Popups.openPicker("wallpapers")
        }
        Item { Layout.fillWidth: true }
    }
}
