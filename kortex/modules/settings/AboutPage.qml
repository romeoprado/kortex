import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Configurações › Sobre
SettingsPage {
    SettingsSection { text: "Sobre" }

    Text {
        Layout.fillWidth: true
        text: "Kortex 0.1 · Desenvolvido por R. Prado [contato@romeoprado.com.br]"
        color: Theme.fgBright
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 1
        wrapMode: Text.Wrap
    }

    SettingsSection { text: "Créditos" }

    Repeater {
        model: [
            { name: "Arch Linux",
              url: "archlinux.org" },
            { name: "Wayland",
              url: "wayland.freedesktop.org" },
            { name: "Hyprland",
              url: "github.com/hyprwm/Hyprland" },
            { name: "Quickshell",
              url: "git.outfoxxed.me/quickshell/quickshell" }
        ]

        SettingRow {
            required property var modelData
            title: modelData.name

            Text {
                text: modelData.url
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
