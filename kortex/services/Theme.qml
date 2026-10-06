pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Paleta ativa + catálogo de temas.
//
// Um tema é uma pasta com `colors.toml` (as cores; `mode = "light"` para tema claro), `icons.theme`
// (o tema de ícones) e `backgrounds/` (os papéis de parede). Nada dentro de um tema é executado:
// só lemos cores, o nome dos ícones e imagens.
//
// O tema "matugen" é especial: suas cores são geradas pelo Matugen a partir do papel de parede em uso
// (scripts/matugen-generate.sh) e regeradas a cada troca de imagem enquanto ele estiver ativo.
Singleton {
    id: root

    // ── Tipografia e métricas ───────────────────────────────────────────
    readonly property string baseFont: "JetBrainsMono Nerd Font"
    // Fonte principal: a escolhida em Configurações, se estiver instalada; senão a Nerd Font (que também
    // traz os ícones) e, por último, uma sans-serif qualquer.
    readonly property string font: firstInstalled([Settings.data.mainFont, baseFont, "Noto Sans"], "monospace")
    // Fonte secundária, só para títulos (cabeçalhos de painel e cartões). Usa a primeira da lista que estiver
    // instalada; sem a Iosevka (pacote ttc-iosevka), cai no Noto Sans.
    readonly property string titleFont: firstInstalled([Settings.data.titleFont, "Iosevka Fixed SmBd Ex", "Noto Sans", "Liberation Sans"], "sans-serif")
    readonly property int fontSize: Math.max(10, Math.min(16, Settings.data.fontSize))
    readonly property int iconSize: fontSize + 2
    // Escala de texto: quatro tamanhos, todos derivados do tamanho escolhido nas Configurações
    readonly property int textSmall: fontSize - 1   // legendas, rótulos secundários, horários
    readonly property int textBody: fontSize        // texto comum, campos, linhas de lista
    readonly property int textLarge: fontSize + 2   // destaques, títulos de seção e de cartão
    readonly property int textTitle: fontSize + 5   // títulos dos painéis e números grandes
    // Altura da barra: fixa em 30 px (cabe o maior tamanho de texto, 16 + 12)
    readonly property int barHeight: 30
    readonly property int radius: Math.max(0, Math.min(20, Settings.data.radius))
    readonly property int radiusSmall: Math.max(0, radius - 2)   // controles dentro dos painéis
    readonly property int gap: 8
    // Espessura da borda: só valores inteiros, de 0 (sem borda) a 5 px; um valor fracionário antigo é arredondado
    readonly property int border: Math.max(0, Math.min(5, Math.round(Settings.data.borderWidth)))
    readonly property bool barBottom: Settings.data.barPosition === "bottom"
    // Barra flutuante: centralizada, do tamanho do conteúdo, a `gap` px da borda e com o raio e a
    // borda dos painéis. `barReserved` é o espaço da borda da tela até o fim da barra.
    readonly property bool barFloating: Settings.data.barStyle === "floating"
    readonly property int barReserved: barHeight + (barFloating ? gap : 0)

    // Primeira família da lista que está instalada (o Qt só escolhe uma família por vez)
    function firstInstalled(names, fallback) {
        const have = Qt.fontFamilies()
        return names.find(f => f && have.includes(f)) || fallback
    }

    // ── Paleta (padrão: Morello) ───────────────────────────────────────
    property color bg: "#222222"
    property color bgAlt: "#343434"
    property color bgDark: "#1b1b1b"
    property color fg: "#ffffff"
    property color fgBright: "#ffffff"
    property color fgDim: "#9c9c9c"
    property color accent: "#686868"
    property color accent2: "#393939"   // segunda cor do contorno em degradê do hyprlock e do SDDM: o acento, mais escuro
    property color muted: "#525252"
    property color selection: "#686868"
    property color red: "#7c7c7c"
    property color green: "#8b8b8b"
    property color yellow: "#a0a0a0"
    property bool light: false
    // Derivadas para a interface (setPalette), com contraste mínimo garantido sobre o fundo, sem mudar o
    // arquivo do tema nem o que vai para outros programas (Kitty, Hyprland, SDDM):
    property color outline: "#7a7a7a"      // contorno de botões, campos e cartões (≥ 3:1 sobre o fundo)
    property color accentText: "#ffffff"   // texto e ícones sobre fundo no acento (≥ 4,5:1, ou o melhor possível)
    property color redText: "#ffffff"      // texto e ícones sobre fundo vermelho (confirmações)
    // Fundo da linha escolhida numa lista (dispositivo em uso, fonte, layout, app selecionado): o cartão com
    // um toque do acento. Theme.selection não serve: em alguns temas é igual ao acento e apaga o conteúdo.
    readonly property color selectionTint: Qt.tint(bgAlt, Qt.alpha(accent, 0.22))

    // ── Catálogo ────────────────────────────────────────────────────────
    property var themes: []
    property var wallpapers: []
    // Papel de parede em prévia (seletor rápido): o shell o desenha no lugar do salvo; "" = nenhum
    property string previewWallpaper: ""
    property string status: ""
    // Para bindings. Dentro de handlers de mudança use themeByName(): quando onThemeChanged
    // roda, esta propriedade ainda não foi reavaliada e devolveria o tema anterior.
    readonly property var currentTheme: themeByName(Settings.data.theme)
    readonly property string userThemesDir: Settings.dataDir + "/themes"
    readonly property string builtinThemesDir: Quickshell.shellDir + "/themes"
    property string _pendingApply: ""
    property bool _hookRan: false

    // ── Cores do papel de parede (Matugen) ──────────────────────────────
    readonly property string dynamicName: "matugen"
    readonly property bool dynamicActive: Settings.data.theme === dynamicName
    property bool matugenAvailable: true    // atualizado por refresh()
    property bool generating: false
    property bool _genActivate: false       // a geração em curso deve também ATIVAR o tema
    property bool _genAgain: false          // outra geração foi pedida durante a atual
    property bool savingDynamic: false      // salvando as cores atuais do Matugen como um tema com nome
    property string _savingName: ""
    property string _savingSlug: ""
    property var _pendingRename: null       // { slug, pairs, active }: aplicado quando o catálogo já tiver o novo nome
    // Modos e estilos (variantes) do Matugen, na ordem em que aparecem no cartão do tema
    readonly property var matugenModes: [{ label: "Escuro", value: "dark" }, { label: "Claro", value: "light" }]
    readonly property var matugenSchemes: [
        { label: "Tonal", value: "scheme-tonal-spot" },
        { label: "Vibrante", value: "scheme-vibrant" },
        { label: "Expressivo", value: "scheme-expressive" },
        { label: "Neutro", value: "scheme-neutral" },
        { label: "Fiel", value: "scheme-fidelity" },
        { label: "Conteúdo", value: "scheme-content" },
        { label: "Monocromático", value: "scheme-monochrome" },
        { label: "Arco-íris", value: "scheme-rainbow" },
        { label: "Salada de frutas", value: "scheme-fruit-salad" },
        { label: "Automático", value: "scheme-smart" }
    ]

    Component.onCompleted: refresh()

    Connections {
        target: Settings.data
        function onThemeChanged() { root.loadCurrent() }
        function onWallpaperDirChanged() { root.listWallpapers() }
    }

    // ── API pública ─────────────────────────────────────────────────────
    function refresh() {
        if (!lister.running) lister.running = true
        if (!matugenCheck.running) matugenCheck.running = true
    }

    function apply(name) {
        const t = themes.find(x => x.name === name)
        if (name === dynamicName) {   // existe mesmo antes da 1ª geração (o tema-base pode ter sido apagado)
            applyDynamic()
            return
        }
        if (!t) {
            status = "Tema não encontrado: " + name
            return
        }
        const remembered = (Settings.data.themeWallpapers || {})[name]
        Settings.data.theme = name
        setWallpaper(remembered || t.background || Settings.data.wallpaper, false)
        runHook(t)
        status = "Tema aplicado: " + prettyName(name)
    }

    function setWallpaper(path, remember) {
        if (!path) return
        Settings.data.wallpaper = path
        if (remember !== false) {
            if (dynamicActive) {
                generate(false)   // as cores seguem a imagem; o tema "matugen" não guarda papel de parede próprio
            } else {
                const map = Object.assign({}, Settings.data.themeWallpapers || {})
                map[Settings.data.theme] = path
                Settings.data.themeWallpapers = map
            }
        }
    }

    // Tema "matugen": as cores saem do papel de parede em uso, sem trocá-lo. O tema só passa a valer
    // quando a geração dá certo; se falhar, nada muda.
    function applyDynamic() {
        if (!matugenAvailable) {
            status = "O Matugen não está instalado (sudo pacman -S matugen)."
            return
        }
        generate(true)
    }

    // Gera as cores do papel de parede (wp, ou o que está em uso) com o modo e a variante escolhidos.
    // Pedidos que chegam durante uma geração se juntam num só, feito ao terminar.
    function generate(activate, wp) {
        if (activate) _genActivate = true
        if (generator.running) {
            _genAgain = true
            return
        }
        wp = wp || Settings.data.wallpaper
        if (!wp) {
            _genActivate = false
            status = "Escolha um papel de parede para gerar as cores."
            return
        }
        generating = true
        status = "Gerando cores do papel de parede…"
        generator.command = ["bash", Settings.scripts + "/matugen-generate.sh", wp,
                             Settings.data.matugenMode, Settings.data.matugenScheme, userThemesDir]
        generator.running = true
    }

    // Modo (escuro/claro) e variante do Matugen. Regera na hora: com o tema "matugen" ativo, tudo
    // muda junto; sem ele, só o cartão do tema no seletor (o tema em uso continua o mesmo).
    function setMatugenOption(key, value) {
        if (Settings.data[key] === value) return
        Settings.data[key] = value
        if (matugenAvailable) generate(false)
    }

    function matugenSchemeLabel(value) {
        return (matugenSchemes.find(s => s.value === value) ?? matugenSchemes[0]).label
    }

    // Nome de pasta a partir do que o usuário digitou: minúsculas, sem acento, só [a-z0-9-]
    function slugify(name) {
        return String(name).trim().toLowerCase()
            .normalize("NFD").replace(/[̀-ͯ]/g, "")
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/^-+|-+$/g, "")
    }

    // Salva as cores ATUAIS do Matugen (papel de parede + modo + estilo em uso) como um tema novo,
    // independente: regera do zero com esse nome (não copia o tema "matugen", que pode estar
    // desatualizado se o usuário só mudou o estilo sem regerar o tema dinâmico). O papel de
    // parede usado vai junto, em backgrounds/, para o tema lembrar sozinho a imagem ao ser aplicado.
    function saveDynamic(name) {
        const slug = slugify(name)
        if (!slug) { status = "Digite um nome para o tema."; return }
        if (slug === dynamicName) { status = "Esse nome é reservado ao tema automático; escolha outro."; return }
        if (!Settings.data.wallpaper) { status = "Escolha um papel de parede para gerar as cores."; return }
        if (savingDynamic) return
        savingDynamic = true
        _savingName = String(name).trim()
        _savingSlug = slug
        status = "Salvando tema…"
        dynamicSaver.command = ["bash", Settings.scripts + "/matugen-generate.sh", Settings.data.wallpaper,
                                Settings.data.matugenMode, Settings.data.matugenScheme, userThemesDir, slug]
        dynamicSaver.running = true
    }

    // Resultado do script: o colors.toml gerado. Atualiza o catálogo na hora (sem esperar a releitura
    // das pastas) e, se o tema "matugen" está ou deve ficar ativo, aplica a paleta e os efeitos externos.
    function applyGenerated(text) {
        if (!/^background\s*=/m.test(text)) return
        const entry = {
            name: dynamicName,
            dir: userThemesDir + "/" + dynamicName,
            background: "",
            source: userThemesDir,
            palette: normalize(parseToml(text))
        }
        themes = themes.filter(t => t.name !== dynamicName).concat([entry]).sort(themeOrder)
        if (_genActivate || dynamicActive) {
            _genActivate = false
            if (!dynamicActive) Settings.data.theme = dynamicName
            setPalette(entry.palette)
            runHook(entry)
            status = "Cores geradas do papel de parede."
        } else if (status === "Gerando cores do papel de parede…") {
            status = ""   // gerou só para o cartão do seletor (tema desligado)
        }
        refresh()
    }

    // Papéis de parede que o Kortex pode excluir: os da pasta escolhida em Papéis de Parede, de
    // ~/.local/share/kortex/backgrounds (arquivos do usuário) e os dos temas do próprio Kortex.
    function wallpaperRoots() {
        const dir = (Settings.data.wallpaperDir || "").trim().replace(/^~(?=\/|$)/, Settings.home).replace(/\/+$/, "")
        return [dir, Settings.dataDir + "/backgrounds", userThemesDir, builtinThemesDir].filter(r => r.length > 1)
    }

    function canRemoveWallpaper(path) {
        return typeof path === "string" && path.length > 0 && wallpaperRoots().some(r => path.startsWith(r + "/"))
    }

    // Move para a Lixeira (gio trash), então dá para recuperar; se a lixeira falhar, nada é apagado.
    function removeWallpaper(path) {
        if (!canRemoveWallpaper(path) || wpRemover.running) return
        const i = wallpapers.indexOf(path)

        // Referências ao arquivo que vai sair: os lembrados por tema e o papel de parede em uso. Tudo é
        // calculado antes e gravado em lote (uma propriedade por vez, com intervalo), porque gravações
        // seguidas no Settings se atropelam com a recarga do arquivo.
        const remembered = Object.assign({}, Settings.data.themeWallpapers || {})
        let changed = false
        for (const k of Object.keys(remembered)) if (remembered[k] === path) { delete remembered[k]; changed = true }
        const pairs = []
        if (Settings.data.wallpaper === path) {
            const next = i >= 0 ? (wallpapers[i + 1] ?? wallpapers[i - 1] ?? "") : (wallpapers.find(w => w !== path) ?? "")
            if (next) remembered[Settings.data.theme] = next
            pairs.push(["themeWallpapers", remembered], ["wallpaper", next])
            if (dynamicActive && next) generate(false, next)
        } else if (changed) {
            pairs.push(["themeWallpapers", remembered])
        }
        if (pairs.length) Settings.applyBatch(pairs)

        wallpapers = wallpapers.filter(w => w !== path)   // some da grade já; a lista é relida ao terminar
        wpRemover.command = ["gio", "trash", "--", path]
        wpRemover.running = true
        status = "Movendo para a lixeira…"
    }

    function randomWallpaper() {
        const others = wallpapers.filter(w => w !== Settings.data.wallpaper)
        if (others.length) setWallpaper(others[Math.floor(Math.random() * others.length)])
    }

    // Só apaga temas de pastas do próprio Kortex (a sua e a dos embutidos); o que estiver fora delas
    // pertence a outro programa. Sempre sobra pelo menos um tema.
    function canRemove(t) {
        if (!t || themes.length <= 1) return false
        return (t.source === userThemesDir || t.source === builtinThemesDir) && t.dir.startsWith(t.source + "/")
    }

    function remove(name) {
        const t = themeByName(name)
        if (!canRemove(t)) return
        const inside = p => typeof p === "string" && p.startsWith(t.dir + "/")

        // Referências a arquivos que vão sumir: papel de parede em uso e os lembrados por tema
        const remembered = Object.assign({}, Settings.data.themeWallpapers || {})
        delete remembered[name]
        for (const k of Object.keys(remembered)) if (inside(remembered[k])) delete remembered[k]
        Settings.data.themeWallpapers = remembered
        // Se o papel de parede em uso estava na pasta, usa um que o usuário já usou em outro tema
        if (inside(Settings.data.wallpaper)) Settings.data.wallpaper = Object.values(remembered).find(w => w) ?? ""

        // Se era o tema ativo, troca antes de apagar
        if (Settings.data.theme === name) {
            const fallback = themes.find(x => x.name !== name)
            if (fallback) apply(fallback.name)
        }

        remover.command = ["rm", "-rf", "--", t.dir]
        remover.running = true
        status = "Tema excluído: " + prettyName(name) + (t.source === builtinThemesDir ? " (volta ao reinstalar o Kortex)" : "")
    }

    // Renomear: só temas da pasta do usuário (os embutidos voltariam com o nome antigo ao reinstalar)
    // e nunca o Matugen, cujo nome é reservado. O nome vira o da pasta, como ao salvar um tema.
    function canRename(t) {
        return !!t && t.name !== dynamicName && t.source === userThemesDir && t.dir === userThemesDir + "/" + t.name
    }

    function rename(name, newName) {
        const t = themeByName(name)
        if (!canRename(t) || renamer.running) return
        const slug = slugify(newName)
        if (!slug) { status = "Digite um nome para o tema."; return }
        if (slug === name) return
        if (slug === dynamicName) { status = "Esse nome é reservado ao tema automático; escolha outro."; return }
        if (themeByName(slug)) { status = "Já existe um tema chamado “" + prettyName(slug) + "”."; return }

        // Referências à pasta antiga, corrigidas só depois que a pasta mudar de nome: papel de parede em
        // uso e os lembrados por tema (podem estar em backgrounds/ do próprio tema) e o tema em uso
        const oldDir = t.dir, newDir = userThemesDir + "/" + slug
        const moved = p => (typeof p === "string" && p.startsWith(oldDir + "/")) ? newDir + p.slice(oldDir.length) : p
        const remembered = {}
        for (const [k, v] of Object.entries(Settings.data.themeWallpapers || {}))
            remembered[k === name ? slug : k] = moved(v)
        const pairs = [["themeWallpapers", remembered]]
        if (moved(Settings.data.wallpaper) !== Settings.data.wallpaper) pairs.unshift(["wallpaper", moved(Settings.data.wallpaper)])
        const active = Settings.data.theme === name
        if (active) pairs.push(["theme", slug])

        _pendingRename = { from: name, slug: slug, pairs: pairs, active: active }
        status = "Renomeando…"
        // falha (sem mover nada) se já houver qualquer coisa com o nome novo
        renamer.command = ["sh", "-c", '[ ! -e "$2" ] && mv -T -- "$1" "$2"', "sh", oldDir, newDir]
        renamer.running = true
    }

    // Ordem do seletor: o Matugen (cores do papel de parede) sempre primeiro, os demais em ordem alfabética
    function themeOrder(a, b) {
        return (b.name === dynamicName) - (a.name === dynamicName) || a.name.localeCompare(b.name)
    }

    function themeByName(name) {
        return themes.find(t => t.name === name) ?? null
    }

    function listWallpapers() {
        const t = themeByName(Settings.data.theme)
        wpLister.command = ["bash", Settings.scripts + "/list-wallpapers.sh",
                            t ? t.dir : "", t ? t.name : "", Settings.data.wallpaperDir]
        if (!wpLister.running) wpLister.running = true
    }

    function prettyName(name) {
        return String(name).split(/[-_]/).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ")
    }

    // Escala fracionária (ex.: 1.6×): o tamanho lógico de uma janela é sempre inteiro, e só cabe
    // num número inteiro de pixels físicos se for múltiplo de um passo (5 a 1.6×, 4 a 1.25×, 2 a 1.5×,
    // 1 a 1× e 2×). Fora disso o compositor reamostra a janela e a borda de baixo sai borrada.
    function snapStep(dpr) {
        for (let n = 1; n <= 20; n++)
            if (Math.abs(n * dpr - Math.round(n * dpr)) < 0.001) return n
        return 1
    }
    function snapUp(size, dpr) {
        const n = snapStep(dpr)
        return Math.ceil(size / n - 0.000001) * n
    }

    function url(path) {
        if (!path) return ""
        if (/^(file|image|qrc|https?):/.test(path)) return path
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    // ── Internos ────────────────────────────────────────────────────────
    function loadCurrent() {
        // Tema salvo que não existe mais (ex.: os antigos embutidos, como tokyo-night): o padrão, Morello
        const t = themeByName(Settings.data.theme) ?? themeByName("morello") ?? themes[0]
        if (!t) return
        setPalette(t.palette)
        listWallpapers()
        if (!Settings.data.wallpaper && t.background) setWallpaper(t.background, false)
        if (!_hookRan) {
            _hookRan = true
            runHook(t)
        }
    }

    // Cores da interface. Algumas são ajustadas para ficarem legíveis (WCAG: texto 4,5:1, contornos 3:1):
    // texto apagado e cores de aviso clareiam ou escurecem só o necessário; o texto sobre o acento e sobre
    // o vermelho é a cor que mais contrasta. O tema em si (e o que vai para outros programas) não muda.
    function setPalette(p) {
        bg = p.bg; bgAlt = p.bgAlt; bgDark = p.bgDark
        fg = p.fg; fgBright = p.fgBright
        fgDim = legible(p.fgDim, [p.bg, p.bgAlt, p.bgDark], 4.5)
        accent = legible(p.accent, [p.bg], 4.5)
        accent2 = p.accent2; muted = p.muted; selection = p.selection
        outline = legible(p.muted, [p.bg, p.bgDark], 3)
        red = legible(p.red, [p.bg], 4.5)
        green = legible(p.green, [p.bg], 4.5)
        yellow = legible(p.yellow, [p.bg], 4.5)
        accentText = textOn(accent, [p.bg, p.fgBright])
        redText = textOn(red, [p.bg, p.fgBright])
        light = p.light
    }

    // Número com casas decimais no formato brasileiro: decimal(46.25, 1) → "46,3"
    function decimal(v, digits) {
        return Number(v).toFixed(digits).replace(".", ",")
    }

    // Luminância relativa e razão de contraste (WCAG 2)
    function luminance(c) {
        c = hex(c)
        let l = 0
        const w = [0.2126, 0.7152, 0.0722]
        for (let i = 0; i < 3; i++) {
            const v = parseInt(c.substr(1 + 2 * i, 2), 16) / 255
            l += w[i] * (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4))
        }
        return l
    }
    function contrast(a, b) {
        const x = luminance(a), y = luminance(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }

    // A cor, levada aos poucos para o branco (fundos escuros) ou o preto (claros) até contrastar o mínimo
    // com todos os fundos dados. Já legível, fica como está.
    function legible(c, backs, min) {
        c = hex(c)
        const ok = x => backs.every(b => contrast(x, b) >= min)
        if (ok(c)) return c
        const target = luminance(backs[0]) < 0.4 ? "#ffffff" : "#000000"
        for (let t = 0.05; t < 1; t += 0.05) {
            const m = mix(c, target, t)
            if (ok(m)) return m
        }
        return target
    }

    // Texto sobre um fundo colorido: a primeira das cores do tema que chega a 4,5:1; se nenhuma chega,
    // preto ou branco, o que contrastar mais
    function textOn(fill, prefs) {
        for (const c of prefs) if (contrast(c, fill) >= 4.5) return hex(c)
        return contrast("#000000", fill) >= contrast("#ffffff", fill) ? "#000000" : "#ffffff"
    }

    function runHook(t) {
        const p = t.palette
        Quickshell.execDetached(["bash", Settings.scripts + "/theme-apply.sh",
            t.name, t.dir, p.accent, p.bg, p.fg, p.muted, p.red,
            Settings.data.hyprBorders ? "1" : "0",
            p.bgAlt, p.fgBright, p.fgDim, p.yellow, p.accent2,
            p.green, p.blue, p.magenta, p.cyan, p.selection, p.bgDark, p.light ? "1" : "0"])
    }

    function hex(c) {
        c = String(c).trim().replace(/^0x/i, "#")
        if (!c.startsWith("#")) c = "#" + c
        if (c.length === 4) c = "#" + c[1] + c[1] + c[2] + c[2] + c[3] + c[3]
        return c.slice(0, 7).toLowerCase()
    }

    function mix(a, b, t) {
        a = hex(a); b = hex(b)
        let out = "#"
        for (const i of [1, 3, 5]) {
            const v = Math.round(parseInt(a.substr(i, 2), 16) * (1 - t) + parseInt(b.substr(i, 2), 16) * t)
            out += (v < 16 ? "0" : "") + v.toString(16)
        }
        return out
    }

    // TOML mínimo: seções [a.b] e pares chave = "valor"
    function parseToml(text) {
        const out = {}
        let section = ""
        for (const raw of text.split("\n")) {
            const line = raw.trim()
            if (!line || line.startsWith("#")) continue
            const sec = line.match(/^\[([^\]]+)\]/)
            if (sec) { section = sec[1].trim(); continue }
            let m = line.match(/^([A-Za-z0-9_.\-]+)\s*=\s*["']([^"']*)["']/)
            if (!m) m = line.match(/^([A-Za-z0-9_.\-]+)\s*=\s*([^\s#]+)/)
            if (m) out[(section ? section + "." : "") + m[1]] = m[2]
        }
        return out
    }

    function normalize(m) {
        const pick = keys => {
            for (const k of keys) {
                const v = m[k]
                if (v && /^(#|0x)?[0-9a-fA-F]{3,8}$/.test(v)) return hex(v)
            }
            return ""
        }
        const bg = pick(["background", "bg"]) || "#1a1b26"
        const fg = pick(["foreground", "fg"]) || "#c0caf5"
        const light = String(m["mode"] || "").toLowerCase() === "light"
        const accent = pick(["accent", "color4", "blue"]) || fg

        // Segunda cor do contorno em degradê do hyprlock e do SDDM: a do tema (accent2/secondary) ou o próprio acento, mais escuro
        const accent2 = pick(["accent2", "secondary"]) || mix(accent, "#000000", 0.45)

        const p = {
            bg: bg,
            fg: fg,
            accent: accent,
            accent2: accent2,
            light: light,
            bgAlt: pick(["lighter_background", "lighter_bg"]) || mix(bg, fg, 0.08),
            bgDark: pick(["dark_background", "dark_bg"]) || (light ? mix(bg, fg, 0.04) : mix(bg, "#000000", 0.2)),
            fgBright: pick(["bright_foreground", "bright_fg"]) || fg,
            fgDim: pick(["dark_foreground", "dark_fg"]) || mix(fg, bg, 0.45),
            muted: pick(["muted", "color8"]) || mix(bg, fg, 0.3),
            selection: pick(["selection", "selection_background"]) || mix(bg, accent, 0.25),
            red: pick(["red", "color1"]) || "#f7768e",
            green: pick(["green", "color2"]) || "#9ece6a",
            yellow: pick(["yellow", "color3"]) || "#e0af68",
            blue: pick(["blue", "color4"]) || accent,
            magenta: pick(["magenta", "color5"]) || accent,
            cyan: pick(["cyan", "color6"]) || accent
        }
        // As 16 cores do tema, na ordem da amostra do seletor (2 linhas de 8): fundos, textos e
        // destaques; depois apagado, seleção e as seis cores de sinal
        p.swatch = [p.bg, p.bgAlt, p.bgDark, p.fg, p.fgBright, p.fgDim, p.accent, p.accent2,
                    p.muted, p.selection, p.red, p.green, p.yellow, p.blue, p.magenta, p.cyan]
        return p
    }

    function parseThemes(out) {
        const byName = {}
        const order = []
        for (const block of out.split("@@THEME\t").slice(1)) {
            const nl = block.indexOf("\n")
            const head = (nl < 0 ? block : block.slice(0, nl)).split("\t")
            const body = nl < 0 ? "" : block.slice(nl + 1)
            if (head.length < 4 || !head[0]) continue
            const t = {
                name: head[0],
                dir: head[1],
                background: head[2],
                source: head[3].trim(),
                palette: normalize(parseToml(body))
            }
            if (!(t.name in byName)) order.push(t.name)
            byName[t.name] = t   // diretórios posteriores sobrescrevem os anteriores
        }
        themes = order.map(n => byName[n]).sort(themeOrder)

        // Renomeado: grava as referências novas (o tema em uso muda de nome, não de cores) e refaz os
        // efeitos externos do tema em uso, que apontam para a pasta (link current-theme, colors.sh).
        // Sem loadCurrent() aqui: o nome antigo já não existe e ele cairia no primeiro tema da lista.
        if (_pendingRename && byName[_pendingRename.slug]) {
            const r = _pendingRename
            _pendingRename = null
            Settings.applyBatch(r.pairs)
            if (r.active) runHook(byName[r.slug])
            status = "Tema renomeado: " + prettyName(r.from) + " → " + prettyName(r.slug)
            return
        }

        if (_pendingApply && byName[_pendingApply]) {
            const name = _pendingApply
            _pendingApply = ""
            apply(name)
        } else {
            loadCurrent()
        }
    }

    Process {
        id: lister
        command: ["bash", Settings.scripts + "/list-themes.sh", Quickshell.shellDir + "/themes"]
        stdout: StdioCollector {
            id: listerOut
            onStreamFinished: root.parseThemes(listerOut.text)
        }
    }

    Process {
        id: wpLister
        stdout: StdioCollector {
            id: wpOut
            onStreamFinished: root.wallpapers = [...new Set(wpOut.text.split("\n").filter(s => s.length > 0))]
        }
    }

    Process {
        id: remover
        onExited: root.refresh()
    }

    Process {
        id: renamer
        onExited: code => {
            if (code === 0) {
                root.refresh()
            } else {
                root._pendingRename = null
                root.status = "Não foi possível renomear o tema."
            }
        }
    }

    Process {
        id: generator
        stdout: StdioCollector {
            id: genOut
            onStreamFinished: root.applyGenerated(genOut.text)
        }
        stderr: StdioCollector {
            id: genErr
            onStreamFinished: {
                const msg = genErr.text.trim()
                if (msg) root.status = msg.split("\n").pop()
            }
        }
        onExited: code => {
            root.generating = false
            if (code !== 0) {
                root._genActivate = false
                root._genAgain = false
                if (!root.status || root.status === "Gerando cores do papel de parede…")
                    root.status = "Não foi possível gerar as cores."
            } else if (root._genAgain) {
                root._genAgain = false
                root.generate(false)
            }
        }
    }

    Process {
        id: dynamicSaver
        stderr: StdioCollector {
            id: saveErr
            onStreamFinished: {
                const msg = saveErr.text.trim()
                if (msg) root.status = msg.split("\n").pop()
            }
        }
        onExited: code => {
            root.savingDynamic = false
            if (code === 0) {
                root.status = "Tema salvo e aplicado: " + root._savingName
                root._pendingApply = root._savingSlug   // aplica assim que a releitura das pastas o encontrar
                root.refresh()
            } else if (!root.status || root.status === "Salvando tema…") {
                root.status = "Não foi possível salvar o tema."
            }
        }
    }

    Process {
        id: matugenCheck
        command: ["sh", "-c", "command -v matugen >/dev/null"]
        onExited: code => root.matugenAvailable = code === 0
    }

    Process {
        id: wpRemover
        onExited: (code, exitStatus) => {
            root.status = code === 0 ? "Papel de parede movido para a lixeira."
                : "Não foi possível mover para a lixeira; o arquivo continua onde estava."
            root.refresh()          // o tema pode ter usado o arquivo como capa ou fundo padrão
            root.listWallpapers()
        }
    }
}
