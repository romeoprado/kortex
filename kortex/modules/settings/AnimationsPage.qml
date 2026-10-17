import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Configurações › Animações: liga/desliga, intensidade, velocidade e estilos das janelas e áreas
// de trabalho. Tudo vale na hora (ver services/Motion.qml e HyprSync).
SettingsPage {
    id: page

    SettingsSection { text: "Geral" }

    SettingRow {
        title: "Animações"
        Toggle {
            checked: Settings.data.animations
            onToggled: v => Settings.data.animations = v
        }
    }

    SettingRow {
        title: "Intensidade"
        dimmed: !Motion.enabled
        Segmented {
            current: Settings.data.animIntensity
            model: [
                { label: "Sóbria", value: "subtle" },
                { label: "Elegante", value: "elegant" },
                { label: "Intensa", value: "intense" }
            ]
            onPicked: v => Settings.data.animIntensity = v
        }
    }

    SettingRow {
        title: "Velocidade"
        dimmed: !Motion.enabled
        Segmented {
            current: Settings.data.animSpeed
            model: [
                { label: "Lenta", value: "slow" },
                { label: "Normal", value: "normal" },
                { label: "Rápida", value: "fast" }
            ]
            onPicked: v => Settings.data.animSpeed = v
        }
    }

    SettingsSection { text: "Janelas e Áreas de Trabalho" }

    SettingRow {
        title: "Abertura das janelas"
        dimmed: !Motion.enabled
        Segmented {
            current: Settings.data.animWindows
            model: [
                { label: "Crescer", value: "popin" },
                { label: "Deslizar", value: "slide" },
                { label: "Desdobrar", value: "gnomed" }
            ]
            onPicked: v => Settings.data.animWindows = v
        }
    }

    SettingRow {
        title: "Troca de área de trabalho"
        dimmed: !Motion.enabled
        Segmented {
            current: Settings.data.animWorkspaces
            model: [
                { label: "Horizontal", value: "horizontal" },
                { label: "Vertical", value: "vertical" },
                { label: "Esmaecer", value: "fade" }
            ]
            onPicked: v => Settings.data.animWorkspaces = v
        }
    }

    SettingsSection { text: "Papel de Parede" }

    SettingRow {
        title: "Troca do papel de parede"
        dimmed: !Motion.enabled
        Chips {
            Layout.fillWidth: false
            Layout.maximumWidth: 330
            current: Settings.data.wallpaperTransition
            model: [
                { label: "Esmaecer", value: "fade" },
                { label: "Círculo", value: "circle" },
                { label: "Íris", value: "iris" },
                { label: "Tinta", value: "ink" },
                { label: "Ladrilhos", value: "tiles" },
                { label: "Varredura", value: "scan" },
                { label: "Falha", value: "glitch" }
            ]
            onPicked: v => Settings.data.wallpaperTransition = v
        }
    }

    SettingRow {
        title: "Ver a troca"
        dimmed: !Motion.enabled
        PlainButton {
            icon: Icons.shuffle
            text: "Trocar ao acaso"
            onClicked: Theme.randomWallpaper()
        }
    }

    SettingsSection { text: "Prévia" }

    SettingRow {
        title: "Aviso de exemplo"
        dimmed: !Motion.enabled
        PlainButton {
            icon: Icons.animation
            text: "Mostrar"
            onClicked: Notifs.flash("animPreview", Icons.animation, "Aviso de exemplo",
                                    "Assim os avisos entram e saem.")
        }
    }
}
