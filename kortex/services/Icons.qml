pragma Singleton

import QtQuick
import Quickshell

// Ícones do Google (Material Symbols, estilo Outlined), de fonts.google.com/icons. A fonte vai dentro
// do Kortex (fonts/, licença Apache-2.0) e é carregada aqui, então não precisa instalar nada. Cada
// ícone é escrito pelo NOME que aparece no site do Google: a fonte transforma o texto ("wifi") no
// desenho (ligadura). Para trocar um ícone, ponha outro nome do catálogo. Desenhe com o componente
// `Icon` (widgets/Icon.qml), que usa esta família; só a marca do Arch é um logo da Nerd Font.
Singleton {
    readonly property var _loader: FontLoader { source: Qt.resolvedUrl("../fonts/MaterialSymbolsOutlined.ttf") }
    readonly property string family: _loader.name !== "" ? _loader.name : "Material Symbols Outlined"
    readonly property int weight: 400   // 100 a 700

    readonly property string arch: ""   // logo (Nerd Font), não é ícone do Google

    readonly property string cpu: "memory"
    readonly property string ram: "memory_alt"
    readonly property string gpu: "developer_board"
    readonly property string vram: "database"
    readonly property string disk: "hard_drive"
    readonly property string bluetooth: "bluetooth"
    readonly property string wifi: "wifi"
    readonly property string ethernet: "lan"
    readonly property string audio: "headphones"        // widget Som (barra e painel)
    readonly property string audioOff: "headset_off"    // widget Som no mudo
    readonly property string volHigh: "volume_up"
    readonly property string volLow: "volume_mute"
    readonly property string volMute: "no_sound"
    readonly property string capsLock: "keyboard_capslock"
    readonly property string numLock: "dialpad"
    readonly property string mic: "mic"
    readonly property string micOff: "mic_off"
    readonly property string headphones: "headphones"
    readonly property string sun: "light_mode"
    readonly property string moon: "bedtime"
    readonly property string bell: "notifications"
    readonly property string bellOff: "notifications_off"
    readonly property string power: "power_settings_new"
    readonly property string bolt: "bolt"        // widget Energia sem bateria (computador de mesa)
    // Widget Energia: modos e alerta de carga baixa. O ícone da bateria na barra muda com a carga
    // (battery_N_bar, battery_charging_N; ver Energy.batteryIcon)
    readonly property string eco: "eco"
    readonly property string balanced: "balance"
    readonly property string performance: "speed"
    readonly property string batteryAlert: "battery_alert"
    readonly property string keepAwake: "coffee"   // Manter Acordado (aviso ao ligar e desligar)
    readonly property string session: "account_circle"   // widget Sessão (barra, painel e Configurações)
    readonly property string lock: "lock"
    readonly property string lockOpen: "lock_open_right"   // rede Wi-Fi sem senha
    // Dados da conexão em uso (painel de rede)
    readonly property string ipAddress: "tag"
    readonly property string gateway: "router"
    readonly property string dns: "dns"
    readonly property string ipv6: "public"
    readonly property string mac: "fingerprint"
    readonly property string logout: "logout"
    readonly property string reboot: "restart_alt"
    readonly property string firmware: "developer_board"   // reiniciar direto na BIOS/UEFI
    readonly property string refresh: "refresh"
    readonly property string close: "close"
    readonly property string check: "check"
    readonly property string trash: "delete"
    readonly property string left: "chevron_left"
    readonly property string right: "chevron_right"
    readonly property string search: "search"
    readonly property string cloud: "cloud"
    readonly property string rain: "rainy"
    readonly property string drizzle: "cloudy_snowing"
    readonly property string storm: "thunderstorm"
    readonly property string snow: "weather_snowy"
    readonly property string fog: "foggy"
    readonly property string rainChance: "water_drop"   // chance de chuva na previsão
    readonly property string brush: "brush"
    readonly property string palette: "palette"
    readonly property string image: "image"
    readonly property string download: "download"
    readonly property string save: "save"
    readonly property string edit: "edit"
    readonly property string shuffle: "shuffle"
    readonly property string folder: "folder"
    readonly property string parentFolder: "drive_folder_upload"   // subir para a pasta de cima
    readonly property string screenshot: "screenshot_region"       // captura de tela (título e avisos)
    readonly property string shotScreen: "fullscreen"              // captura: tela inteira
    readonly property string shotWindow: "select_window"           // captura: janela
    readonly property string shotArea: "highlight_alt"             // captura: área
    readonly property string cog: "settings"
    readonly property string terminal: "terminal"
    readonly property string display: "monitor"
    readonly property string calendar: "calendar_month"
    readonly property string chart: "bar_chart"
    readonly property string sliders: "tune"
    readonly property string apps: "apps"
    readonly property string font: "text_fields"
    readonly property string bars: "menu"
    readonly property string minus: "remove"
    readonly property string undo: "undo"
    readonly property string info: "info"
    readonly property string location: "location_on"
    readonly property string battery: "battery_full"
    readonly property string warning: "warning"
    readonly property string keyboard: "keyboard"
    readonly property string star: "star"        // cheio: Icon { filled: true }; vazado: filled: false
    readonly property string starOff: "star"
    readonly property string globe: "language"
    readonly property string plus: "add"
    readonly property string up: "expand_less"
    readonly property string down: "expand_more"
}
