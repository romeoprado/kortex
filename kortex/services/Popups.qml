pragma Singleton

import QtQuick
import Quickshell

// Estado global de janelas: só um popup da barra aberto por vez.
// Campos de texto não funcionam em popups da barra (PopupWindow não recebe o teclado do
// Wayland); por isso lançador, temas, cidade do clima e rede têm janelas próprias (OverlayPanel).
// Clicar fora fecha: os popups da barra usam a camada ClickAway e os overlays tratam o clique
// no próprio fundo. (HyprlandFocusGrab não serve: não ativa para PopupWindow e, com teclado
// exclusivo, nunca avisa do clique fora.)
Singleton {
    id: root

    property string current: ""
    property string screen: ""
    property bool launcherOpen: false
    property bool themePickerOpen: false
    property bool cityPromptOpen: false
    property string networkPromptSsid: ""      // não vazio = janela de senha do Wi-Fi aberta
    property bool networkSettingsOpen: false
    property string networkSettingsTarget: ""  // perfil que a janela de rede abre selecionado
    property string pickerTab: "themes"        // themes | wallpapers
    property bool languageOpen: false
    property bool settingsOpen: false
    property bool wallpaperCarouselOpen: false   // seletor rápido de papel de parede (carrossel)
    property bool screenshotOpen: false          // menu da captura de tela (a janela de salvar segue Screenshot.pending)
    property string settingsPage: "appearance"  // appearance | animations | bar | apps | power | general | about
    property string languageTab: "keyboard"    // "keyboard" | "language"

    // Largura da barra flutuante em cada monitor (nome → px; a barra informa), para a camada
    // ClickAway recortar exatamente o espaço dela
    property var barWidths: ({})

    function setBarWidth(screenName, width) {
        if (!screenName || barWidths[screenName] === width) return
        const widths = Object.assign({}, barWidths)
        widths[screenName] = width
        barWidths = widths
    }

    // Ignora um segundo clique em até 300 ms no botão que acabou de fechar o popup (duplo clique)
    property real _closedAt: 0
    property string _closedKey: ""

    function _closeOverlays() {
        launcherOpen = false
        themePickerOpen = false
        cityPromptOpen = false
        networkPromptSsid = ""
        networkSettingsOpen = false
        languageOpen = false
        settingsOpen = false
        wallpaperCarouselOpen = false
        screenshotOpen = false
    }

    // Clique fora de tudo: fecha o popup da barra e as janelas
    function dismiss() {
        close()
        _closeOverlays()
    }

    function toggle(id, screenName) {
        if (current === id && screen === screenName) {
            close()
            return
        }
        if (_closedKey === id + "@" + screenName && Date.now() - _closedAt < 300) return
        _closeOverlays()
        screen = screenName
        current = id
    }

    function close(id) {
        if (id !== undefined && id !== current) return
        if (current === "") return
        _closedKey = current + "@" + screen
        _closedAt = Date.now()
        current = ""
    }

    function toggleLauncher() {
        const wasOpen = launcherOpen
        close()
        _closeOverlays()
        launcherOpen = !wasOpen
    }

    function openPicker(tab) {
        close()
        _closeOverlays()
        pickerTab = tab || "themes"
        themePickerOpen = true
    }

    function toggleWallpaperCarousel() {
        const wasOpen = wallpaperCarouselOpen
        close()
        _closeOverlays()
        wallpaperCarouselOpen = !wasOpen
    }

    function openScreenshot() {
        close()
        _closeOverlays()
        screenshotOpen = true
    }

    function openCityPrompt() {
        close()
        _closeOverlays()
        cityPromptOpen = true
    }

    function openNetworkPrompt(ssid) {
        close()
        _closeOverlays()
        networkPromptSsid = ssid
    }

    // name vazio = a conexão ativa (ou a primeira)
    function openNetworkSettings(name) {
        close()
        _closeOverlays()
        networkSettingsTarget = name || ""
        networkSettingsOpen = true
    }

    function openSettings(page) {
        close()
        _closeOverlays()
        settingsPage = page || settingsPage
        settingsOpen = true
    }

    function openLanguage(tab) {
        close()
        _closeOverlays()
        languageTab = tab || "keyboard"
        languageOpen = true
    }
}
