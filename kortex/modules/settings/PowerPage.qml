import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Configurações › Sessão: quais botões o widget de sessão mostra
SettingsPage {
    id: page

    readonly property var actions: [
        { id: "lock", text: "Bloquear" },
        { id: "suspend", text: "Suspender" },
        { id: "logout", text: "Sair" },
        { id: "reboot", text: "Reiniciar" },
        { id: "firmware", text: "UEFI" },
        { id: "shutdown", text: "Desligar" }
    ]
    readonly property int enabledCount: actions.filter(a => Settings.powerActionEnabled(a.id)).length

    SettingsSection { text: "Botões de Sessão" }

    Repeater {
        model: page.actions

        SettingRow {
            required property var modelData
            title: modelData.text
            Toggle {
                checked: Settings.powerActionEnabled(modelData.id)
                onToggled: v => Settings.setFlag("powerActions", modelData.id, v)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: page.enabledCount === 0
        text: "Com todos desligados, o painel de sessão mostra só um aviso."
        color: Theme.yellow
        font.family: Theme.font
        font.pixelSize: Theme.textSmall
    }

    SettingsSection { text: "Segurança" }

    SettingRow {
        title: "Pedir confirmação"
        Toggle {
            checked: Settings.data.powerConfirm
            onToggled: v => Settings.data.powerConfirm = v
        }
    }
}
