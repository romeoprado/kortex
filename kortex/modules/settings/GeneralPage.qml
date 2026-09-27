import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Configurações › Geral: notificações, lançador e restaurar padrões
SettingsPage {
    id: page

    property bool confirming: false

    SettingsSection { text: "Notificações" }

    SettingRow {
        title: "Não perturbe"
        Toggle {
            checked: Settings.data.dnd
            onToggled: v => Settings.data.dnd = v
        }
    }

    SettingRow {
        title: "Duração dos avisos"
        Segmented {
            current: Settings.data.toastSeconds
            model: [
                { label: "3 s", value: 3 },
                { label: "6 s", value: 6 },
                { label: "10 s", value: 10 },
                { label: "15 s", value: 15 }
            ]
            onPicked: v => Settings.data.toastSeconds = v
        }
    }

    SettingsSection { text: "Lançador" }

    SettingRow {
        title: "Abrir só com os favoritos"
        Toggle {
            checked: Settings.data.launcherFavoritesOnly
            onToggled: v => Settings.data.launcherFavoritesOnly = v
        }
    }

    SettingsSection { text: "Restaurar" }

    SettingRow {
        title: "Restaurar a aparência e a barra"
        PlainButton {
            danger: true
            icon: Icons.undo
            text: page.confirming ? "Clique novamente para confirmar" : "Restaurar padrões"
            onClicked: {
                if (!page.confirming) {
                    page.confirming = true
                    confirmTimer.restart()
                    return
                }
                page.confirming = false
                Settings.resetAppearance()
            }
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: page.confirming = false
    }
}
