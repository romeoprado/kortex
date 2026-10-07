//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1

// Kortex — barra, lançador, notificações e gerenciador de temas para Hyprland.
// Execute com:  qs -c kortex

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.bar
import qs.modules.launcher
import qs.modules.themes
import qs.modules.display
import qs.modules.weather
import qs.modules.network
import qs.modules.language
import qs.modules.clickaway
import qs.modules.notifications
import qs.modules.wallpaper
import qs.modules.settings
import qs.modules.osd
import qs.modules.screenshot

ShellRoot {
    Wallpaper {}

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    ClickAway {}
    Launcher {}
    ThemePicker {}
    WallpaperCarousel {}
    ApplyConfirm {}
    CityPrompt {}
    NetworkPrompt {}
    NetworkSettings {}
    LanguageSettings {}
    KortexSettings {}
    NotificationToasts {}
    OsdWindow {}
    ScreenshotMenu {}
    ScreenshotSave {}
    RecordMenu {}
    RecordSave {}

    // Atalhos via IPC (use no hyprland.conf):
    //   qs -c kortex ipc call launcher toggle
    //   qs -c kortex ipc call themes toggle | wallpapers | matugen | set <nome>
    //   qs -c kortex ipc call keyboard next | prev | set <posição> | settings | language
    //   qs -c kortex ipc call settings toggle | open <appearance|bar|apps|power|general|about>
    //   qs -c kortex ipc call screenshot toggle
    //   qs -c kortex ipc call record toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { Popups.toggleLauncher() }
    }

    IpcHandler {
        target: "themes"
        function toggle(): void {
            if (Popups.themePickerOpen) Popups.themePickerOpen = false
            else Popups.openPicker("themes")
        }
        function wallpapers(): void { Popups.openPicker("wallpapers") }
        function matugen(): void { Popups.openPicker("themes") }   // as opções do Matugen ficam no cartão do tema
        function set(name: string): void { Theme.apply(name) }
        function randomWallpaper(): void { Theme.randomWallpaper() }
        function carousel(): void { Popups.toggleWallpaperCarousel() }   // seletor rápido
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifs.clearAll() }
        function toggleDnd(): void { Settings.data.dnd = !Settings.data.dnd }
    }

    IpcHandler {
        target: "keyboard"
        function next(): void { Keyboard.next() }
        function prev(): void { Keyboard.prev() }
        function set(index: int): void { Keyboard.switchTo(index) }   // 0 = primeiro layout
        function settings(): void { Popups.openLanguage("keyboard") }
        function language(): void { Popups.openLanguage("language") }
    }

    // Aviso de Caps Lock e Num Lock (chamado pelos atalhos que o HyprSync cria)
    IpcHandler {
        target: "osd"
        function locks(): void { Osd.checkLocks() }
    }

    // Captura de tela (a tecla Print): abre o menu Tela Inteira / Janela / Área
    IpcHandler {
        target: "screenshot"
        function toggle(): void { Screenshot.toggle() }
    }

    // Gravação de tela (SHIFT+Print): abre o menu ou, gravando, para
    IpcHandler {
        target: "record"
        function toggle(): void { ScreenRecord.toggle() }
    }

    IpcHandler {
        target: "keepAwake"
        function toggle(): void { KeepAwake.toggle() }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void {
            if (Popups.settingsOpen) Popups.settingsOpen = false
            else Popups.openSettings()
        }
        function open(page: string): void { Popups.openSettings(page) }
    }

    // Garante que os serviços de fundo iniciem junto com o shell
    Component.onCompleted: {
        Notifs.count
        Brightness.available
        Theme.themes
        Keyboard.layouts
        HyprSync.workspaces
        TerminalStyle.percent
        Apps.terminals
        Energy.batteries
    }
}
