#!/usr/bin/env bash
# Verificações do Kortex que não precisam do Hyprland nem do Quickshell rodando.
#   bash dev/verificar.sh [--sem-instalar] [--so-scripts | --so-qml]
#
#  1. Repositório: os dois README e as duas LICENSE iguais, scripts executáveis e QML sem +x.
#  2. Scripts: bash -n em todos, o shellcheck (nível info) e a sintaxe dos scripts em Python.
#  3. QML: sintaxe de todos os arquivos (qmlformat) e o qmllint, mostrando só o que ele consegue
#     afirmar sem os tipos do Quickshell: imports sem uso, expressões com vírgula, ids que escondem
#     propriedades e erros. Os shaders de kortex/shaders: cada .frag tem o .qsb compilado e, com o
#     qsb do Qt 6 (pacote qt6-shadertools), o .qsb é igual ao que a fonte gera hoje.
#  4. Fumaça: roda os scripts do tema, dos ícones, do terminal, da captura, do Matugen (com um
#     matugen falso), do Firefox e do SDDM (modo de ensaio) num HOME temporário e confere o que
#     eles gravam. Nada fora da pasta temporária é tocado.
#  5. Hyprland em Lua: o hyprland.lua que o arch-setup.sh grava, com os arquivos que a fumaça deixou
#     (cores, desfoque do terminal, monitores convertidos do monitors.conf pelo install.sh). O
#     dev/hl-mock.lua confere a forma das chamadas sem o Hyprland (precisa do lua); com o Hyprland
#     instalado, o Hyprland --verify-config confere também os nomes das opções e das regras e, com
#     o qml do Qt 6, todo o Lua que o Motion.qml e o HyprSync.qml geram (cada combinação das animações).
#
# Ferramentas: usa o shellcheck, o qmllint e o qmlformat do sistema (no Arch: pacotes shellcheck e
# qt6-declarative, em /usr/lib/qt6/bin). Os de /usr/bin, quando existem, costumam ser do Qt 5
# (qt5-declarative), que não entende ?., espalhamento nem funções com tipo, e são ignorados. Sem
# eles, instala o shellcheck-py e o PySide6-Essentials num venv em ~/.cache/kortex-dev (a menos
# que receba --sem-instalar, que só pula o que faltar).
# Sai com código 1 se alguma verificação falhar.
set -u

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo/kortex"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/kortex-dev"
install=1; only=""
for a in "$@"; do
    case "$a" in
        --sem-instalar) install=0 ;;
        --so-scripts) only=scripts ;;
        --so-qml) only=qml ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Opção desconhecida: $a" >&2; exit 2 ;;
    esac
done

fails=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FALHA %s\n' "$*"; fails=$((fails + 1)); }
skip() { printf '  pula  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

# Fora de um terminal, o Qt manda as mensagens para o journald, e o qmlformat e o qmllint falhariam
# sem dizer por quê
export QT_FORCE_STDERR_LOGGING=1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Primeira ferramenta encontrada entre os nomes dados, em /usr/lib/qt6/bin, no venv ou no PATH. As
# do QML precisam ser do Qt 6: as do Qt 5 se apresentam como "qmlformat 1.0" e acusariam erro de
# sintaxe no que o Quickshell aceita.
tool() {
    local n p
    for n in "$@"; do
        for p in "/usr/lib/qt6/bin/$n" "$cache/venv/bin/$n" "$(command -v "$n" 2>/dev/null)"; do
            [ -n "$p" ] && [ -x "$p" ] || continue
            case "$n" in
                *qml*) "$p" --version 2>&1 | grep -q ' 6\.' || continue ;;
            esac
            echo "$p"; return 0
        done
    done
    return 1
}
venv_install() {   # venv_install <pacote pip>...
    [ "$install" = 1 ] || return 1
    command -v python3 >/dev/null || return 1
    [ -x "$cache/venv/bin/pip" ] || python3 -m venv "$cache/venv" >/dev/null 2>&1 || return 1
    echo "  (instalando $* em $cache/venv)"
    "$cache/venv/bin/pip" install -q "$@" >/dev/null 2>&1
}

# ── 1. Repositório ────────────────────────────────────────────────────────
step "Repositório"
if cmp -s "$repo/README.md" "$src/README.md"; then ok "README.md e kortex/README.md iguais"
else bad "README.md e kortex/README.md diferentes (copie o da raiz: cp README.md kortex/README.md)"; fi
if cmp -s "$repo/LICENSE" "$src/LICENSE"; then ok "LICENSE e kortex/LICENSE iguais"
else bad "LICENSE e kortex/LICENSE diferentes"; fi
nx=$(find "$src/scripts" -name '*.sh' ! -name 'firefox-common.sh' ! -perm -u+x | wc -l)
if [ "$nx" = 0 ]; then ok "scripts executáveis"; else bad "$nx script(s) sem +x em kortex/scripts"; fi
qx=$(find "$src" -name '*.qml' -perm -u+x | wc -l)
if [ "$qx" = 0 ]; then ok "arquivos QML sem +x"; else bad "$qx arquivo(s) QML com +x (chmod 644)"; fi

# ── 2. Scripts ────────────────────────────────────────────────────────────
if [ "$only" != qml ]; then
    step "Scripts"
    n=0; e=0
    for f in "$src"/scripts/*.sh "$repo"/*.sh "$repo"/dev/*.sh; do
        n=$((n + 1)); bash -n "$f" 2>"$work/err" || { e=$((e + 1)); bad "bash -n $f: $(head -1 "$work/err")"; }
    done
    [ "$e" = 0 ] && ok "bash -n em $n arquivos"
    # Python (bt-agent.py): só a sintaxe, com ast.parse, para não deixar __pycache__ no repositório
    if command -v python3 >/dev/null; then
        n=0; e=0
        for f in "$src"/scripts/*.py; do
            [ -e "$f" ] || continue
            n=$((n + 1))
            python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$f" 2>"$work/err" \
                || { e=$((e + 1)); bad "python $f: $(tail -1 "$work/err")"; }
        done
        [ "$e" = 0 ] && ok "sintaxe Python em $n arquivo(s)"
    else
        skip "sintaxe Python (python3 não encontrado)"
    fi
    sc="$(tool shellcheck)" || { venv_install shellcheck-py && sc="$(tool shellcheck)"; } || sc=""
    if [ -n "$sc" ]; then
        if "$sc" -S info -s bash -x -P "$src/scripts" "$src"/scripts/*.sh "$repo"/*.sh "$repo"/dev/*.sh >"$work/sc" 2>&1; then
            ok "shellcheck sem avisos"
        else
            bad "shellcheck:"; sed 's/^/        /' "$work/sc"
        fi
    else
        skip "shellcheck (não encontrado)"
    fi
fi

# ── 3. QML ────────────────────────────────────────────────────────────────
if [ "$only" != scripts ]; then
    step "QML"
    fmt="$(tool qmlformat pyside6-qmlformat)" || { venv_install PySide6-Essentials && fmt="$(tool qmlformat pyside6-qmlformat)"; } || fmt=""
    lint="$(tool qmllint pyside6-qmllint)" || lint=""
    if [ -n "$fmt" ]; then
        n=0; e=0
        while IFS= read -r f; do
            n=$((n + 1))
            "$fmt" "$f" >/dev/null 2>"$work/err" || { e=$((e + 1)); bad "sintaxe: ${f#"$repo"/}"; sed 's/^/        /' "$work/err"; }
        done < <(find "$src" -name '*.qml' | sort)
        [ "$e" = 0 ] && ok "sintaxe de $n arquivos QML"
    else
        skip "sintaxe QML (qmlformat não encontrado)"
    fi
    if [ -n "$lint" ]; then
        # O Quickshell cria os módulos qs.* sozinho; aqui eles são montados à mão (cópia + qmldir)
        tree="$work/qs"; mkdir -p "$tree/qs"
        for d in services widgets $(cd "$src" && find modules -mindepth 1 -maxdepth 1 -type d | sort); do
            mkdir -p "$tree/qs/$d"; cp "$src/$d"/*.qml "$tree/qs/$d/"
            { echo "module qs.${d//\//.}"
              for f in "$src/$d"/*.qml; do
                  n="$(basename "$f" .qml)"
                  if grep -q '^pragma Singleton' "$f"; then echo "singleton $n 1.0 $n.qml"; else echo "$n 1.0 $n.qml"; fi
              done; } > "$tree/qs/$d/qmldir"
        done
        cp "$src/shell.qml" "$tree/qs/"
        ( cd "$tree/qs" && find . -name '*.qml' | sort | xargs "$lint" -I "$tree" ) >"$work/lint" 2>&1
        # Avisos que não dependem dos tipos do Quickshell (o resto é ruído de import não resolvido)
        grep -E '^Error|\[(unused-imports|comma|id-shadows-member|duplicate-property-binding|duplicated-name|syntax)\]' "$work/lint" >"$work/lint.real"
        if [ -s "$work/lint.real" ]; then bad "qmllint:"; sed 's/^/        /' "$work/lint.real"; else ok "qmllint sem imports sem uso nem erros"; fi
    else
        skip "qmllint (não encontrado)"
    fi
    # Shaders: o Quickshell carrega o .qsb, não o .frag, então um .frag mudado sem recompilar não vale.
    # As opções são as do cabeçalho de cada .frag; o qsb gera sempre os mesmos bytes.
    qsb="$(tool qsb)" || qsb=""
    while IFS= read -r f; do
        rel="${f#"$repo"/}"
        if [ ! -f "$f.qsb" ]; then bad "shader sem .qsb: $rel"; continue; fi
        if [ -z "$qsb" ]; then skip "$rel.qsb atualizado (qsb não encontrado)"; continue; fi
        if "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$work/s.qsb" "$f" >"$work/err" 2>&1 && cmp -s "$work/s.qsb" "$f.qsb"; then
            ok "$rel.qsb atualizado"
        else
            bad "$rel.qsb desatualizado ou o shader não compila (recompile com o comando do cabeçalho)"; sed 's/^/        /' "$work/err"
        fi
    done < <(find "$src" -name '*.frag' | sort)
fi

# ── 4. Fumaça dos scripts ─────────────────────────────────────────────────
if [ "$only" != qml ]; then
    step "Fumaça dos scripts (HOME temporário)"
    H="$work/home"; mkdir -p "$H" "$work/bin"
    # id falso: o sddm-setup.sh se recusa a rodar como root, inclusive no modo de ensaio
    # shellcheck disable=SC2016
    printf '#!/bin/sh\n[ "$1" = "-u" ] && [ $# -eq 1 ] && { echo 1000; exit 0; }\nexec /usr/bin/id "$@"\n' > "$work/bin/id"
    # matugen falso: grava uma paleta fixa no output_path do config que recebe com -c
    cat > "$work/bin/matugen" <<'EOF'
#!/usr/bin/env bash
cfg=""; while [ $# -gt 0 ]; do [ "$1" = -c ] && cfg="$2"; shift; done
out=$(sed -nE "s/^output_path = '(.*)'$/\1/p" "$cfg")
printf 'mode = "dark"\naccent = "#61afef"\nbackground = "#1e1e2e"\nforeground = "#cdd6f4"\nred = "#ffb2bc"\ngreen = "#b0d18b"\nyellow = "#f3bd6e"\nblue = "#aec6ff"\nmagenta = "#d3bbfc"\ncyan = "#91cef4"\n' > "$out"
EOF
    chmod +x "$work/bin/id" "$work/bin/matugen"
    (
        export HOME="$H" XDG_STATE_HOME="$H/.local/state" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share"
        export KORTEX_GNOME_NO_GSETTINGS=1 KORTEX_SDDM_THEME_DIR="$H/sddm" PATH="$work/bin:$PATH"
        unset HYPRLAND_INSTANCE_SIGNATURE
        st="$XDG_STATE_HOME/kortex"
        mkdir -p "$H/sddm" "$H/.config/gtk-4.0" "$H/.config/gtk-3.0" "$H/.mozilla/firefox/p.default"; : > "$H/sddm/theme.conf.user"
        printf '/* >>> kortex */\n@import url("kortex-colors.css");\n/* <<< kortex */\n' > "$H/.config/gtk-4.0/gtk.css"
        printf '.minha-regra { color: red; }\n' > "$H/.config/gtk-3.0/gtk.css"
        bash "$src/scripts/gnome-setup.sh" >/dev/null 2>&1
        printf '[Install1]\nDefault=p.default\n\n[Profile0]\nName=p\nIsRelative=1\nPath=p.default\nDefault=1\n' > "$H/.mozilla/firefox/profiles.ini"
        check() { if eval "$2" >/dev/null 2>&1; then echo "ok $1"; else echo "FALHA $1"; fi; }

        bash "$src/scripts/theme-apply.sh" morello "$src/themes/morello" "#686868" "#222222" "#ffffff" "#525252" "#7c7c7c" 1 \
            "#343434" "#ffffff" "#9c9c9c" "#a0a0a0" "#393939" "#8b8b8b" "#686868" "#747474" "#868686" "#686868" "#1b1b1b" 0 >/dev/null 2>&1
        check "theme-apply: colors.sh" "( . '$st/colors.sh'; [ \"\$KORTEX_ACCENT\" = '#686868' ] && [ \"\$KORTEX_THEME\" = morello ] )"
        check "theme-apply: hyprland-colors.conf" "grep -qF '\$kortex_accent = rgb(686868)' '$st/hyprland-colors.conf'"
        check "theme-apply: hyprland-colors.lua" "grep -qF 'accent    = \"rgb(686868)\",' '$st/hyprland-colors.lua' && grep -qF 'inactive_border = \"rgba(525252aa)\",' '$st/hyprland-colors.lua' && grep -qF 'borders         = true,' '$st/hyprland-colors.lua'"
        check "theme-apply: theme.name e current-theme" "[ \"\$(cat '$st/theme.name')\" = morello ] && [ \"\$(readlink '$st/current-theme')\" = '$src/themes/morello' ]"
        check "kitty-theme.conf" "grep -qx 'background #222222' '$st/kitty-theme.conf'"
        check "btop: kortex.theme" "grep -qF 'theme[hi_fg]=\"#686868\"' '$H/.config/btop/themes/kortex.theme'"
        # o mesmo tema de novo (como a cada início do shell): nada muda e o temporário não pode sobrar
        for _ in 1 2; do
            bash "$src/scripts/btop-theme.sh" morello "#222222" "#343434" "#ffffff" "#ffffff" "#9c9c9c" "#686868" \
                "#525252" "#7c7c7c" "#8b8b8b" "#a0a0a0" "#747474" "#868686" "#686868" >/dev/null 2>&1
        done
        check "btop: sem temporário depois de reaplicar" "! ls -A '$H/.config/btop/themes/' | grep -q '^\.kortex\.'"
        check "sddm-colors: 9 cores" "[ \"\$(grep -c '=' '$H/sddm/theme.conf.user')\" = 9 ] && grep -qx 'accent=#686868' '$H/sddm/theme.conf.user'"
        check "firefox: theme-apply configura o perfil" "[ -f '$H/.mozilla/firefox/p.default/chrome/kortex-chrome.css' ] && grep -qF '// kortex' '$H/.mozilla/firefox/p.default/user.js'"
        check "firefox: kortex-colors.css" "grep -qF -- '--kortex-accent: #686868' '$H/.mozilla/firefox/p.default/chrome/kortex-colors.css'"
        check "gnome: kortex-colors.css" "grep -qF -- '--accent-bg-color: #686868' '$H/.config/gtk-4.0/kortex-colors.css' && grep -qF -- '--card-shade-color: rgba(0, 0, 0, 0.36);' '$H/.config/gtk-4.0/kortex-colors.css'"
        check "gnome: gtk-3.0 importa as cores e guarda o gtk.css" "head -1 '$H/.config/gtk-3.0/gtk.css' | grep -qF '>>> kortex' && grep -qF 'minha-regra' '$H/.config/gtk-3.0/gtk.css' && ls '$H/.config/gtk-3.0/' | grep -q 'gtk.css.bak-kortex-'"
        check "gnome: gtk-3.0 kortex-colors.css" "grep -qx '@define-color accent_bg_color #686868;' '$H/.config/gtk-3.0/kortex-colors.css' && grep -qx '@define-color window_bg_color #222222;' '$H/.config/gtk-3.0/kortex-colors.css'"
        check "icon-theme pick (awk POSIX)" "[ \"\$(bash '$src/scripts/icon-theme.sh' pick '#61afef' 0)\" = Yaru-blue-dark ] && [ \"\$(bash '$src/scripts/icon-theme.sh' pick '#686868' 1)\" = Yaru-sage ]"
        check "list-themes: 8 temas" "[ \"\$(bash '$src/scripts/list-themes.sh' '$src/themes' | grep -c '^@@THEME')\" = 8 ]"
        bash "$src/scripts/terminal-apply.sh" 70 0 >/dev/null 2>&1
        check "terminal-apply" "grep -qx 'background_opacity 0.70' '$st/kitty-window.conf' && grep -q 'no_blur = true' '$st/hyprland-terminal.lua'"
        bash "$src/scripts/apps-apply.sh" terminal kitty kitty >/dev/null 2>&1
        check "apps-apply" "grep -qx 'KORTEX_TERMINAL=(kitty )' '$st/apps.sh'"
        check "screenshot.sh dirs" "bash '$src/scripts/screenshot.sh' dirs | head -1 | grep -qx \"Capturas\$(printf '\\t')$H/Pictures/Screenshots\""
        printf 'x' > "$H/papel.jpg"
        check "matugen-generate: prévia" "bash '$src/scripts/matugen-generate.sh' '$H/papel.jpg' dark scheme-vibrant - | grep -qx 'accent = \"#61afef\"' && [ ! -e '$H/.local/share/kortex/themes/matugen' ]"
        bash "$src/scripts/matugen-generate.sh" "$H/papel.jpg" dark scheme-vibrant "$H/t" salvo >/dev/null 2>&1
        check "matugen-generate: tema salvo" "[ -f '$H/t/salvo/backgrounds/papel.jpg' ] && [ \"\$(cat '$H/t/salvo/icons.theme')\" = Yaru-blue-dark ]"
        bash "$src/scripts/firefox-setup.sh" --remove >/dev/null 2>&1
        bash "$src/scripts/gnome-setup.sh" --remove >/dev/null 2>&1
        check "gnome-setup --remove" "[ ! -e '$H/.config/gtk-4.0' ] && [ ! -e '$H/.config/gtk-3.0/kortex-colors.css' ] && [ \"\$(cat '$H/.config/gtk-3.0/gtk.css')\" = '.minha-regra { color: red; }' ]"
        check "firefox-setup --remove" "[ ! -e '$H/.mozilla/firefox/p.default/chrome' ] && [ ! -e '$H/.mozilla/firefox/p.default/user.js' ]"
        bash "$src/scripts/firefox-setup.sh" --auto >/dev/null 2>&1
        check "firefox-setup --auto respeita o --remove" "[ ! -e '$H/.mozilla/firefox/p.default/chrome' ] && grep -qxF '$H/.mozilla/firefox/p.default' '$st/firefox-off'"
        bash "$src/scripts/firefox-setup.sh" >/dev/null 2>&1
        check "firefox-setup religa e apaga a anotação" "[ -f '$H/.mozilla/firefox/p.default/chrome/kortex-chrome.css' ] && [ ! -e '$st/firefox-off' ]"
        root="$work/sddmroot"
        KORTEX_SDDM_ROOT="$root" bash "$src/scripts/sddm-setup.sh" --yes >/dev/null 2>&1
        check "sddm-setup (ensaio)" "[ -f '$root/usr/share/sddm/themes/kortex/Main.qml' ] && grep -qx 'Current=kortex' '$root/etc/sddm.conf.d/kortex.conf' && grep -qx 'accent=#686868' '$root/usr/share/sddm/themes/kortex/theme.conf.user'"
    ) > "$work/smoke" 2>&1
    while IFS= read -r l; do
        case "$l" in "ok "*) ok "${l#ok }" ;; "FALHA "*) bad "${l#FALHA }" ;; *) printf '        %s\n' "$l" ;; esac
    done < "$work/smoke"
fi

# ── 5. Hyprland em Lua ────────────────────────────────────────────────────
if [ "$only" != qml ]; then
    step "Hyprland em Lua"
    st="$H/.local/state/kortex"; hypr="$work/hypr"; mkdir -p "$hypr"
    # Uma instalação antiga: o install.sh converte o monitors.conf para o monitors.lua
    printf '# Gerado pelo Kortex (widget de tela). Carregado pelo Hyprland.\nmonitor = eDP-1, 2560x1600@120,0x0,1.6\n' > "$st/monitors.conf"
    HOME="$H" XDG_STATE_HOME="$H/.local/state" XDG_CONFIG_HOME="$H/.config" bash "$repo/install.sh" >/dev/null 2>&1
    if grep -qxF 'hl.monitor({ output = "eDP-1", mode = "2560x1600@120", position = "0x0", scale = "1.6" })' "$st/monitors.lua" 2>/dev/null; then
        ok "install.sh: monitors.conf convertido para monitors.lua"
    else
        bad "install.sh: monitors.lua sem a regra do monitors.conf"
    fi
    # O hyprland.lua do arch-setup.sh: o texto entre "cat > $HYPR/hyprland.lua <<CONF" e "CONF", com as
    # variáveis do instalador preenchidas (inclusive os trechos da NVIDIA e da máquina virtual)
    (
        eval "$(awk "/^ *(NVIDIA|VM)_ENV='\$/{f=1} f{print} f&&/'\$/&&!/_ENV='\$/{f=0}" "$repo/arch-setup.sh")"
        # shellcheck disable=SC2034  # lidas pelo eval abaixo
        STATE="$st" DEST="$src" TERMINAL_APP=kitty KB_LAYOUT=br KB_VARIANT=abnt2
        eval "cat <<CONF
$(awk '/cat > "\$HYPR\/hyprland.lua" <<CONF$/{f=1;next} f&&/^CONF$/{exit} f' "$repo/arch-setup.sh")
CONF"
    ) > "$hypr/hyprland.lua" 2>"$work/err"
    printf -- '-- user.lua de teste\nhl.config({ general = { gaps_in = 4 } })\n' > "$hypr/user.lua"
    if [ -s "$work/err" ] || ! grep -q 'kortex_load("hyprland-colors.lua")' "$hypr/hyprland.lua"; then
        bad "arch-setup.sh: não consegui montar o hyprland.lua"; sed 's/^/        /' "$work/err"
    elif command -v lua >/dev/null; then
        if lua "$repo/dev/hl-mock.lua" "$hypr/hyprland.lua" >"$work/mock" 2>&1; then
            ok "hl-mock: hyprland.lua do arch-setup.sh ($(tail -1 "$work/mock"))"
        else
            bad "hl-mock: hyprland.lua do arch-setup.sh"; sed 's/^/        /' "$work/mock"
        fi
    else
        skip "hl-mock (lua não encontrado)"
    fi
    # O user.lua que o arch-setup.sh grava a partir de um user.conf antigo: precisa ser Lua válido, com o
    # aviso no terminal (um warn dentro do bloco redirecionado já foi parar no arquivo, com as cores ANSI)
    ul="$work/user-lua"; mkdir -p "$ul"
    printf '# comentário\nexec-once = algo\n' > "$ul/user.conf"
    (
        # shellcheck disable=SC2034  # lida pelo eval abaixo
        HYPR="$ul"
        # shellcheck disable=SC2329  # chamada pelo eval abaixo
        warn() { printf 'warn: %s\n' "$*"; }
        eval "$(awk '/^    if \[ ! -f "\$HYPR\/user.lua" \]; then$/{f=1} f{print} f&&/^    fi$/{exit}' "$repo/arch-setup.sh")"
    ) > "$work/ul-out" 2>&1
    if ! [ -s "$ul/user.lua" ]; then
        bad "arch-setup.sh: não consegui montar o user.lua"; sed 's/^/        /' "$work/ul-out"
    elif grep -q $'\e' "$ul/user.lua" || ! grep -q '^-- exec-once = algo$' "$ul/user.lua" ||
        ! grep -q '^warn: Seu ~/.config/hypr/user.conf foi copiado' "$work/ul-out"; then
        bad "arch-setup.sh: user.lua gerado do user.conf (o aviso foi para o arquivo?)"; sed 's/^/        /' "$ul/user.lua"
    elif command -v lua >/dev/null && ! lua -e 'assert(loadfile(arg[1]))' "$ul/user.lua" 2>"$work/ul-err"; then
        bad "arch-setup.sh: user.lua gerado não é Lua válido"; sed 's/^/        /' "$work/ul-err"
    else
        ok "arch-setup.sh: user.lua gerado do user.conf"
    fi
    if command -v Hyprland >/dev/null && [ -s "$hypr/hyprland.lua" ]; then
        Hyprland --verify-config -c "$hypr/hyprland.lua" >"$work/verify" 2>&1
        v="$(Hyprland --version 2>/dev/null | head -1 | awk '{print $2}')"
        if grep -qx 'config ok' "$work/verify"; then
            ok "Hyprland $v --verify-config"
        else
            bad "Hyprland $v --verify-config:"; sed -n '/parsing result/,$p' "$work/verify" | grep -v '^=*\( Config parsing result:\)\?$' | sed 's/^/        /'
        fi
    else
        skip "Hyprland --verify-config (Hyprland não encontrado)"
    fi
    # O Lua do QML: as funções do Motion.qml e do HyprSync.qml copiadas para um QML sem o Quickshell, que
    # imprime as regras de camada e as animações de todas as combinações de velocidade, intensidade e estilo
    qmlrt="$(tool qml)" || qmlrt=""
    if [ -n "$qmlrt" ] && command -v Hyprland >/dev/null; then
        motion="$src/services/Motion.qml"; sync="$src/services/HyprSync.qml"
        cat > "$work/motion.qml" <<EOF
import QtQuick
QtObject {
    property bool enabled: true
    property string speed
    property string intensity
    property string windowStyle
    property string workspaceStyle
$(grep -E '^    readonly property (real factor|int level):' "$motion")
$(grep -E '^    function pick\(' "$motion")
$(awk '/^    function _speed\(/{f=1} f{print} /^    readonly property var hyprlandLua:/{l=1} f&&l&&/^    }$/{exit}' "$motion")
$(awk '/^    function lua\(s\)/{f=1} f{print} f&&/^    }$/{if(++n==2) exit}' "$sync")
$(awk '/^    readonly property var _layerRules:/{f=1} f{print} f&&/^    \]$/{exit}' "$sync")
$(awk '/^    function guard\(/{f=1} f{print} f&&/^    }$/{exit}' "$sync")
    Component.onCompleted: {
        const out = [..._layerRules]
        for (const sp of ["slow", "normal", "fast"])
            for (const it of ["subtle", "elegant", "intense"])
                for (const w of ["popin", "slide", "gnomed"])
                    for (const ws of ["horizontal", "vertical", "fade"]) {
                        speed = sp; intensity = it; windowStyle = w; workspaceStyle = ws
                        out.push(...hyprlandLua)
                    }
        enabled = false
        out.push(...hyprlandLua)
        console.log("@@LUA\n" + out.join("\n") + "\n@@GUARD\n" + guard(out))
        Qt.quit()
    }
}
EOF
        QT_QPA_PLATFORM=offscreen timeout 20 "$qmlrt" "$work/motion.qml" >"$work/motion.out" 2>&1
        sed -n '/@@LUA$/,/@@GUARD$/p' "$work/motion.out" | sed '1d;$d' > "$work/motion.lua"
        sed -n '/@@GUARD$/,$p' "$work/motion.out" | sed '1d' > "$work/guard.lua"
        n="$(grep -c '^hl\.animation(' "$work/motion.lua")"
        if [ "$n" -lt 81 ]; then
            bad "Lua do Motion.qml/HyprSync.qml: o QML de teste não gerou as animações"; sed 's/^/        /' "$work/motion.out" | head -20
        elif Hyprland --verify-config -c "$work/motion.lua" >"$work/verify" 2>&1 && grep -qx 'config ok' "$work/verify"; then
            ok "Lua do Motion.qml e do HyprSync.qml ($n animações, $(grep -c '^hl\.layer_rule(' "$work/motion.lua") regras de camada)"
        else
            bad "Lua do Motion.qml/HyprSync.qml:"; sed -n '/parsing result/,$p' "$work/verify" | grep -v '^=*\( Config parsing result:\)\?$' | sed 's/^/        /'
        fi
        # O mesmo Lua como o HyprSync o manda ao vivo (cada instrução num pcall, os erros juntos no fim),
        # rodado pela imitação da API: confere que o guard() é Lua válido e não esconde nenhum erro
        if command -v lua >/dev/null && [ -s "$work/guard.lua" ]; then
            if lua "$repo/dev/hl-mock.lua" "$work/guard.lua" >"$work/guard.out" 2>&1; then
                ok "HyprSync.guard(): o Lua protegido roda na imitação da API"
            else
                bad "HyprSync.guard():"; sed 's/^/        /' "$work/guard.out" | head -10
            fi
        fi
    else
        skip "Lua do Motion.qml e do HyprSync.qml (precisa do qml do Qt 6 e do Hyprland)"
    fi
fi

echo
if [ "$fails" = 0 ]; then echo "Tudo certo."; else echo "$fails verificação(ões) falharam."; exit 1; fi
