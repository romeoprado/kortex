#!/usr/bin/env bash
# Liga as cores do tema do Kortex aos apps GTK: os GTK4/libadwaita (Nautilus, Calculadora, Editor de
# Texto…) e, com o adw-gtk-theme instalado, também os GTK3 (Visualizador de Documentos, Discos…) e os GTK4
# sem libadwaita (Controle de Volume). Põe um @import no ~/.config/gtk-4.0/gtk.css e no
# ~/.config/gtk-3.0/gtk.css, escolhe o esquema de cores "kortex" no Editor de Texto e deixa o
# gnome-theme.sh regravar as cores (e escolher o tema adw-gtk3 claro ou escuro) a cada troca de tema.
#   gnome-setup.sh            liga (rodar de novo é seguro: só acrescenta o que faltar)
#   gnome-setup.sh --remove   desfaz e devolve o gsettings aos valores de antes
# Guarda cópia (.bak-kortex-…) de cada gtk.css que já existir e os valores originais do gsettings em
# ~/.local/state/kortex/gnome-original.txt. Os apps já abertos só mudam ao reabrir. Sai sempre com 0.
# KORTEX_GNOME_NO_GSETTINGS=1 pula o gsettings (testes).
here="$(cd "$(dirname "$0")" && pwd)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"; gtk4="$cfg/gtk-4.0"; gtk3="$cfg/gtk-3.0"
data="${XDG_DATA_HOME:-$HOME/.local/share}/gtksourceview-5/styles"
orig="$state/gnome-original.txt"
begin='/* >>> kortex */'; end='/* <<< kortex */'
stamp="$(date +%Y%m%d-%H%M%S)"

# (esquema chave) que o Kortex mexe
keys=("org.gnome.desktop.interface color-scheme" "org.gnome.desktop.interface gtk-theme"
      "org.gnome.TextEditor style-scheme" "org.gnome.TextEditor style-variant")
have_gs() { [ "${KORTEX_GNOME_NO_GSETTINGS:-0}" != 1 ] && command -v gsettings >/dev/null 2>&1; }
have_schema() { gsettings list-schemas 2>/dev/null | grep -qx "$1"; }

# Põe, no INÍCIO do gtk.css da pasta (um @import só vale antes das outras regras), o bloco que importa
# o kortex-colors.css dela; preserva o resto do arquivo, com cópia
add_import() {
    local css="$1/gtk.css" block
    mkdir -p "$1"
    [ -f "$css" ] && grep -qF -- "$begin" "$css" && return 0
    block="$begin"$'\n''@import url("kortex-colors.css");'$'\n'"$end"$'\n'
    if [ -f "$css" ]; then
        cp -p "$css" "$css.bak-kortex-$stamp"
        { printf '%s\n' "$block"; cat "$css"; } > "$css.tmp.$$" && mv -f "$css.tmp.$$" "$css"
    else
        printf '%s' "$block" > "$css"
    fi
}

drop_import() {
    local css="$1/gtk.css"
    if [ -f "$css" ] && grep -qF -- "$begin" "$css"; then
        sed -i "\|>>> kortex|,\|<<< kortex|d" "$css"
        sed -i '/./,$!d' "$css"          # tira a linha em branco que o bloco deixou no início
        grep -q '[^[:space:]]' "$css" || rm -f "$css"
    fi
    rm -f "$1/kortex-colors.css"
}

if [ "${1:-}" = "--remove" ]; then
    drop_import "$gtk4"
    drop_import "$gtk3"
    rm -f "$data/kortex.xml"
    rmdir "$gtk4" "$gtk3" 2>/dev/null || true
    if have_gs && [ -f "$orig" ]; then
        while IFS='|' read -r schema key value; do
            [ -n "$schema" ] && have_schema "$schema" && timeout 5 gsettings set "$schema" "$key" "$value" 2>/dev/null || true
        done < "$orig"
    fi
    rm -f "$orig"
    echo "Removido: apps GTK4 e Editor de Texto voltam ao padrão ao serem reabertos."
    exit 0
fi

mkdir -p "$state"
add_import "$gtk4"
add_import "$gtk3"

# guarda os valores de antes, uma vez só por chave: uma reinstalação não deve sobrescrever o original, mas
# uma chave que o Kortex passou a mexer depois (o gtk-theme) ainda entra numa instalação antiga
if have_gs; then
    touch "$orig"
    for k in "${keys[@]}"; do
        schema="${k%% *}"; key="${k##* }"
        grep -qF "$schema|$key|" "$orig" && continue
        have_schema "$schema" || continue
        v="$(timeout 5 gsettings get "$schema" "$key" 2>/dev/null)" || continue
        printf '%s|%s|%s\n' "$schema" "$key" "$v" >> "$orig"
    done
fi

bash "$here/gnome-theme.sh"
echo "Configurado: apps GTK4/libadwaita e GTK3 (cores em $gtk4/kortex-colors.css e $gtk3/kortex-colors.css)."
adw=0
for d in "${XDG_DATA_HOME:-$HOME/.local/share}/themes" "$HOME/.themes" /usr/local/share/themes /usr/share/themes; do
    [ -d "$d/adw-gtk3-dark/gtk-3.0" ] && adw=1 && break
done
[ "$adw" = 1 ] || echo "Aviso: sem o adw-gtk-theme, os apps GTK3 e os GTK4 sem libadwaita não mudam de cor (sudo pacman -S adw-gtk-theme)."
have_gs || echo "Aviso: sem gsettings/sessão gráfica; o claro/escuro do sistema será escolhido na próxima troca de tema."
exit 0
