import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Configurações › Barra: estilo, opacidade e desfoque, posição, áreas de trabalho e itens
SettingsPage {
    id: page

    readonly property var items: [
        { id: "stats", text: "Recursos" },
        { id: "updates", text: "Atualizações" },
        { id: "weather", text: "Clima" },
        { id: "media", text: "Mídia" },
        { id: "tray", text: "Bandeja" },
        { id: "keyboard", text: "Teclado" },
        { id: "bluetooth", text: "Bluetooth" },
        { id: "network", text: "Rede" },
        { id: "audio", text: "Som" },
        { id: "display", text: "Tela" },
        { id: "notifications", text: "Notificações" },
        { id: "energy", text: "Energia" },
        { id: "power", text: "Sessão" }
    ]

    SettingsSection { text: "Estilo e Posição" }

    SettingRow {
        title: "Estilo da barra"
        Segmented {
            current: Settings.data.barStyle
            model: [{ label: "Inteira", value: "full" }, { label: "Flutuante", value: "floating" }]
            onPicked: v => Settings.data.barStyle = v
        }
    }

    SettingRow {
        title: "Borda da barra flutuante"
        dimmed: !Theme.barFloating
        Toggle {
            checked: Settings.data.barBorder
            onToggled: v => Settings.data.barBorder = v
        }
    }

    // Fundo translúcido da barra e dos painéis dela, como o do terminal (Aparência › Terminal): de 30% a
    // 100%, de 5 em 5. O desfoque só aparece com o fundo translúcido, então fica apagado em 100%.
    SettingRow {
        title: "Opacidade da barra e dos painéis"
        SliderBar {
            Layout.fillWidth: false
            Layout.preferredWidth: 260
            value: (Math.round(Theme.barAlpha * 100) - 30) / 70
            valueText: Math.round(Theme.barAlpha * 100) + "%"
            step: 1 / 14
            onMoved: v => Settings.data.barOpacity = 30 + Math.round(v * 14) * 5
        }
    }

    SettingRow {
        title: "Desfoque da barra e dos painéis"
        dimmed: Theme.barAlpha >= 1
        Toggle {
            checked: Settings.data.barBlur
            onToggled: v => Settings.data.barBlur = v
        }
    }

    SettingRow {
        title: "Posição da barra"
        Segmented {
            current: Settings.data.barPosition
            model: [{ label: "Topo", value: "top" }, { label: "Fundo", value: "bottom" }]
            onPicked: v => Settings.data.barPosition = v
        }
    }

    SettingsSection { text: "Áreas de Trabalho e Relógio" }

    SettingRow {
        title: "Quantidade de áreas de trabalho"
        Stepper {
            from: 1
            to: 10
            value: Settings.data.workspaceCount
            onMoved: v => Settings.data.workspaceCount = v
        }
    }

    SettingRow {
        title: "Relógio de 24 horas"
        Toggle {
            checked: Settings.data.use24h
            onToggled: v => Settings.data.use24h = v
        }
    }

    SettingsSection { text: "Itens da Barra" }

    // a ordem muda na própria barra: segurar um item e arrastar
    SettingRow {
        title: "Ordem dos itens"
        dimmed: Settings.barLayoutIsDefault()
        PlainButton {
            icon: Icons.undo
            text: "Restaurar ordem padrão"
            enabled: !Settings.barLayoutIsDefault()
            onClicked: Settings.resetBarOrder()
        }
    }

    // Na ordem padrão da barra, da esquerda para a direita, lida coluna por coluna
    GridLayout {
        Layout.fillWidth: true
        flow: GridLayout.TopToBottom
        rows: Math.ceil(page.items.length / 2)
        columnSpacing: 36
        rowSpacing: 10

        Repeater {
            model: page.items

            ToggleRow {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: modelData.text
                checked: Settings.barItemVisible(modelData.id)
                onToggled: v => Settings.setFlag("barItems", modelData.id, v)
            }
        }
    }
}
