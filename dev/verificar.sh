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
        -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
        check "theme-apply: theme.name e current-theme" "[ \"\$(cat '$st/theme.name')\" = morello ] && [ \"\$(readlink '$st/current-theme')\" = '$src/themes/morello' ]"
        check "kitty-theme.conf" "grep -qx 'background #222222' '$st/kitty-theme.conf'"
        check "btop: kortex.theme" "grep -qF 'theme[hi_fg]=\"#686868\"' '$H/.config/btop/themes/kortex.theme'"
        check "sddm-colors: 9 cores" "[ \"\$(grep -c '=' '$H/sddm/theme.conf.user')\" = 9 ] && grep -qx 'accent=#686868' '$H/sddm/theme.conf.user'"
        check "firefox: theme-apply configura o perfil" "[ -f '$H/.mozilla/firefox/p.default/chrome/kortex-chrome.css' ] && grep -qF '// kortex' '$H/.mozilla/firefox/p.default/user.js'"
        uj="$H/.mozilla/firefox/p.default/user.js"
        check "firefox: sites com a aparência clara" "grep -qx 'user_pref(\"layout.css.prefers-color-scheme.content-override\", 1); // kortex' '$uj'"
        sed -i '/content-override/d' "$uj"; bash "$src/scripts/firefox-setup.sh" --auto >/dev/null 2>&1
        check "firefox-setup --auto completa um perfil já configurado" "[ \"\$(grep -c 'content-override' '$uj')\" = 1 ]"
        sed -i '/content-override/d' "$uj"; echo 'user_pref("layout.css.prefers-color-scheme.content-override", 0);' >> "$uj"
        bash "$src/scripts/firefox-setup.sh" --auto >/dev/null 2>&1
        check "firefox-setup respeita a preferência do usuário" "[ \"\$(grep -c 'content-override' '$uj')\" = 1 ] && grep -qF 'content-override\", 0);' '$uj'"
        sed -i '/content-override/d' "$uj"   # a escolha simulada sai, para o --remove abaixo poder apagar o user.js
        check "firefox: kortex-colors.css" "grep -qF -- '--kortex-accent: #686868' '$H/.mozilla/firefox/p.default/chrome/kortex-colors.css'"
        check "gnome: kortex-colors.css" "grep -qF -- '--accent-bg-color: #686868' '$H/.config/gtk-4.0/kortex-colors.css' && grep -qF -- '--card-shade-color: rgba(0, 0, 0, 0.36);' '$H/.config/gtk-4.0/kortex-colors.css'"
        check "gnome: gtk-3.0 importa as cores e guarda o gtk.css" "head -1 '$H/.config/gtk-3.0/gtk.css' | grep -qF '>>> kortex' && grep -qF 'minha-regra' '$H/.config/gtk-3.0/gtk.css' && ls '$H/.config/gtk-3.0/' | grep -q 'gtk.css.bak-kortex-'"
        check "gnome: gtk-3.0 kortex-colors.css" "grep -qx '@define-color accent_bg_color #686868;' '$H/.config/gtk-3.0/kortex-colors.css' && grep -qx '@define-color window_bg_color #222222;' '$H/.config/gtk-3.0/kortex-colors.css'"
        check "icon-theme pick (awk POSIX)" "[ \"\$(bash '$src/scripts/icon-theme.sh' pick '#61afef' 0)\" = Yaru-blue-dark ] && [ \"\$(bash '$src/scripts/icon-theme.sh' pick '#686868' 1)\" = Yaru-sage ]"
        check "list-themes: 8 temas" "[ \"\$(bash '$src/scripts/list-themes.sh' '$src/themes' | grep -c '^@@THEME')\" = 8 ]"
        bash "$src/scripts/terminal-apply.sh" 70 0 >/dev/null 2>&1
        check "terminal-apply" "grep -qx 'background_opacity 0.70' '$st/kitty-window.conf' && grep -q 'no_blur' '$st/hyprland-terminal.conf'"
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

echo
if [ "$fails" = 0 ]; then echo "Tudo certo."; else echo "$fails verificação(ões) falharam."; exit 1; fi
