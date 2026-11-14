pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Leva ao Hyprland as opções das Configurações que dependem dele, ao vivo, em Lua (hyprctl eval):
//  • atalhos SUPER+6…0 (e SUPER+SHIFT+…) para as áreas de trabalho além da quinta, quando a barra
//    mostra mais de cinco. Os atalhos 1–5 já vêm do hyprland.lua.
//  • espessura da borda e raio dos cantos das janelas, quando "aplicar às janelas" está ligado.
//  • atalhos do Caps Lock e do Num Lock que avisam o OSD (non_consuming: não consomem a tecla).
//  • o desfoque atrás da barra, dos painéis, das janelas e dos avisos do Kortex, quando eles estão
//    translúcidos (Configurações › Aparência › Painéis): uma regra de camada com nome, que o Hyprland
//    atualiza no lugar quando ela é mandada de novo e reaplica às camadas já abertas.
//  • as animações do Hyprland (Configurações › Animações, ver services/Motion.qml): janelas, áreas
//    de trabalho, camadas e popups, reaplicadas a cada mudança. As janelas do Kortex (lançador,
//    temas, Configurações, rede, cidade, idioma, confirmação de tela, OSD, captura de tela, processos) crescem
//    do centro, a barra e o carrossel deslizam da borda, e os avisos e os painéis da barra se movem
//    pelo Qt. A seleção do slurp fica sem animação, para não sair na imagem.
// Um "hyprctl reload" recria o estado do Lua e apaga o que foi aplicado em tempo de execução, então
// tudo é reaplicado quando o Hyprland avisa que recarregou (configreloaded). Nada aqui grava no hyprland.lua.
//
// O Kortex exige a configuração em Lua (Hyprland 0.55 ou mais novo; o 0.57 já não lê o hyprland.conf).
// Com o hyprland.conf antigo, o hyprctl eval recusa o código e um aviso explica a migração.
Singleton {
    id: root

    readonly property int workspaces: Math.max(1, Math.min(10, Settings.data.workspaceCount))
    readonly property bool syncWindows: Settings.data.hyprSyncAppearance
    readonly property int windowBorder: Math.round(Theme.border)
    readonly property int windowRounding: Theme.radius
    // falso quando o Hyprland ainda carrega o hyprland.conf (o eval só existe com a configuração em Lua)
    property bool luaConfig: true

    // atalhos que este serviço criou (e por isso pode remover); um reload do Hyprland os apaga
    property var _bound: []
    property bool _wasSyncing: false
    property bool _osdBound: false   // atalhos do OSD já criados (um reload do Hyprland os apaga)
    property bool _animsSet: false   // regras de camada já aplicadas (se repetiriam a cada vez)
    property bool _blurSent: false   // o desfoque que o Hyprland tem agora (um reload volta a "sem regra")
    property var _queued: []         // instruções que chegaram com o eval anterior ainda rodando
    property bool _warned: false

    // Desfoque atrás do que é translúcido: só com a opacidade dos painéis abaixo de 100%
    readonly property bool panelBlur: Settings.data.panelBlur && Theme.panelOpacity < 100

    // Janelas do Kortex feitas com OverlayPanel (e a confirmação de tela), sem o prefixo "kortex-"
    readonly property string _windows: "themes|settings|network-settings|network-prompt|city|language|display-confirm|screenshot|screenshot-save|record|record-save|processes"

    // Regras das camadas do Kortex (as curvas e velocidades vêm de Motion, ver services/Motion.qml)
    readonly property var _layerRules: [
        // janelas do Kortex crescem do centro; a barra e o carrossel deslizam da borda em que estão
        _layerRule("kortex-popin", "^kortex-(" + _windows + ")$", 'animation = "popin 90%"'),
        _layerRule("kortex-slide", "^kortex-(bar|wallpaper-carousel)$", 'animation = "slide"'),
        // o lançador só esmaece: a cascata de dentro é do Qt (modules/launcher/Launcher.qml)
        _layerRule("kortex-fade", "^kortex-launcher$", 'animation = "fade"'),
        // os avisos, o OSD e a camada de clique fora se animam sozinhos (Qt) ou não precisam
        _layerRule("kortex-no-anim", "^kortex-(notifications|osd|clickaway)$", "no_anim = true"),
        // a marcação do slurp (captura de tela) some na hora: com a animação de saída, o grim a pegaria
        _layerRule("kortex-slurp", "^selection$", "no_anim = true")
    ]

    // Texto como literal de string do Lua. Todo valor que entra no código do hyprctl eval passa por aqui.
    function lua(s) {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
                              .replace(/\n/g, "\\n").replace(/\r/g, "\\r") + '"'
    }

    function _layerRule(name, namespace, effect) {
        return "hl.layer_rule({ name = " + lua(name) + ", match = { namespace = " + lua(namespace) + " }, " + effect + " })"
    }

    // Desfoque das camadas translúcidas do Kortex: a barra (e os painéis dela, que são popups), o
    // lançador, as janelas, os avisos e o OSD. Ficam de fora o papel de parede, a camada de clique
    // fora e o carrossel, que tem fundo próprio. O ignore_alpha deixa sem desfoque o que é
    // transparente (o resto da tela nas janelas de tela cheia, o vão entre os avisos) e fica abaixo
    // da menor opacidade que os painéis podem ter (60%). Desligado, a mesma regra vai com
    // blur = false: mandada com o mesmo nome, vale a última.
    function _blurRule() {
        const on = panelBlur ? "true" : "false"
        return _layerRule("kortex-blur", "^kortex-(bar|launcher|notifications|osd|" + _windows + ")$",
                          "blur = " + on + ", blur_popups = " + on + ", ignore_alpha = 0.35")
    }

    function _key(n) { return n === 10 ? "0" : String(n) }

    // Junta as instruções num bloco só para o hyprctl eval, cada uma no seu pcall. No Lua, um erro
    // interrompe o bloco: sem isso, uma instrução recusada (um estilo ou um campo que uma versão nova
    // do Hyprland não conheça) levaria junto todas as que vêm depois. Os erros voltam juntos no fim,
    // como um erro só, para a resposta do eval. (Uma opção desconhecida no hl.config não interrompe
    // nada: o Hyprland só a registra como erro de configuração, que o eval também devolve.)
    function guard(statements) {
        return "local kortex_errors = {}\n"
             + statements.map(s => "do local ok, err = pcall(function() " + s
                                   + " end) if not ok then kortex_errors[#kortex_errors + 1] = tostring(err) end end").join("\n")
             + '\nif #kortex_errors > 0 then error(table.concat(kortex_errors, "\\n"), 0) end'
    }

    function apply() {
        const code = []
        const bound = []
        for (let n = 6; n <= 10; n++) {
            const k = _key(n)
            if (n <= workspaces) {
                if (!_bound.includes(n)) {
                    code.push('hl.bind("SUPER + ' + k + '", hl.dsp.focus({ workspace = ' + n + " }))")
                    code.push('hl.bind("SUPER + SHIFT + ' + k + '", hl.dsp.window.move({ workspace = ' + n + " }))")
                }
                bound.push(n)
            } else if (_bound.includes(n)) {
                code.push('hl.unbind("SUPER + ' + k + '")')
                code.push('hl.unbind("SUPER + SHIFT + ' + k + '")')
            }
        }
        _bound = bound

        if (!_osdBound) {
            code.push('hl.bind("Caps_Lock", hl.dsp.exec_cmd("qs -c kortex ipc call osd locks"), { non_consuming = true })')
            code.push('hl.bind("Num_Lock", hl.dsp.exec_cmd("qs -c kortex ipc call osd locks"), { non_consuming = true })')
            _osdBound = true
        }
        if (!_animsSet) {
            code.push(..._layerRules)
            _animsSet = true
        }
        // O desfoque muda com as Configurações, então vai a cada vez que mudou (ou depois de um reload).
        // Com os painéis opacos e nenhuma regra mandada antes, não há o que desligar.
        if (panelBlur !== _blurSent) {
            code.push(_blurRule())
            _blurSent = panelBlur
        }
        code.push(...Motion.hyprlandLua)
        // As cores da borda das janelas não entram aqui: o theme-apply.sh as aplica ao trocar de tema e
        // grava no hyprland-colors.lua, que o hyprland.lua relê a cada reload (com hyprBorders e o alfa).
        if (syncWindows)
            code.push("hl.config({ general = { border_size = " + windowBorder + " }, decoration = { rounding = " + windowRounding + " } })")
        if (code.length > 0) _eval(code)

        // desligou "aplicar às janelas": o reload devolve os valores do hyprland.lua
        if (!syncWindows && _wasSyncing) Quickshell.execDetached(["hyprctl", "reload"])
        _wasSyncing = syncWindows
    }

    // statements: lista de instruções em Lua. A fila guarda instruções soltas (não blocos já
    // protegidos), para o próximo eval levar tudo num guard() só.
    function _eval(statements) {
        if (evaluator.running) {
            _queued = _queued.concat(statements)
            return
        }
        evaluator.command = ["hyprctl", "eval", guard(statements)]
        evaluator.running = true
    }

    // hyprctl eval responde "ok" ou o erro do Lua
    function _reply(text) {
        const t = text.trim()
        if (t.indexOf("only supported with the lua") >= 0) {
            luaConfig = false
            if (!_warned) {
                _warned = true
                Notifs.flash("hyprLua", Icons.warning, "O Hyprland ainda usa o hyprland.conf",
                             "O Kortex agora usa a configuração em Lua. Rode o arch-setup.sh de novo ou veja a seção 3 do README.")
            }
        } else if (t !== "" && t !== "ok") {
            console.warn("HyprSync: o Hyprland recusou o código: " + t)
        } else {
            luaConfig = true
        }
    }

    onWorkspacesChanged: settle.restart()
    readonly property var _motion: Motion.hyprlandLua
    on_MotionChanged: settle.restart()
    onSyncWindowsChanged: settle.restart()
    onWindowBorderChanged: if (syncWindows) settle.restart()
    onWindowRoundingChanged: if (syncWindows) settle.restart()
    onPanelBlurChanged: settle.restart()

    Timer {
        id: settle
        interval: 350
        onTriggered: root.apply()
    }

    Process {
        id: evaluator
        stdout: StdioCollector {
            id: evalOut
            onStreamFinished: root._reply(evalOut.text)
        }
        onExited: {
            if (root._queued.length === 0) return
            const next = root._queued
            root._queued = []
            root._eval(next)
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root._bound = []
                root._osdBound = false
                root._animsSet = false
                root._blurSent = false
                settle.restart()
            }
        }
    }

    Component.onCompleted: settle.restart()
}
