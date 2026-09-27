#!/usr/bin/env bash
# Liga as cores do tema do Kortex aos apps GTK4/libadwaita (Nautilus, Calculadora, Editor de Texto…):
# põe um @import no ~/.config/gtk-4.0/gtk.css, escolhe o esquema de cores "kortex" no Editor de Texto e
# deixa o gnome-theme.sh regravar as cores a cada troca de tema.
#   gnome-setup.sh            liga
#   gnome-setup.sh --remove   desfaz e devolve o gsettings aos valores de antes
# Guarda cópia (.bak-kortex-…) do gtk.css se ele já existir e os valores originais do gsettings em
# ~/.local/state/kortex/gnome-original.txt. Os apps já abertos só mudam ao reabrir.
# KORTEX_GNOME_NO_GSETTINGS=1 pula o gsettings (testes).
here="$(cd "$(dirname "$0")" && pwd)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"; gtk4="$cfg/gtk-4.0"; css="$gtk4/gtk.css"
data="${XDG_DATA_HOME:-$HOME/.local/share}/gtksourceview-5/styles"
orig="$state/gnome-original.txt"
begin='/* >>> kortex */'; end='/* <<< kortex */'
stamp="$(date +%Y%m%d-%H%M%S)"

# (esquema chave) que o Kortex mexe
keys=("org.gnome.desktop.interface color-scheme" "org.gnome.TextEditor style-scheme" "org.gnome.TextEditor style-variant")
have_gs() { [ "${KORTEX_GNOME_NO_GSETTINGS:-0}" != 1 ] && command -v gsettings >/dev/null 2>&1; }
have_schema() { gsettings list-schemas 2>/dev/null | grep -qx "$1"; }

if [ "${1:-}" = "--remove" ]; then
    if [ -f "$css" ] && grep -qF -- "$begin" "$css"; then
        sed -i "\|>>> kortex|,\|<<< kortex|d" "$css"
        sed -i '/./,$!d' "$css"          # tira a linha em branco que o bloco deixou no início
        grep -q '[^[:space:]]' "$css" || rm -f "$css"
    fi
    rm -f "$gtk4/kortex-colors.css" "$data/kortex.xml"
    rmdir "$gtk4" 2>/dev/null || true
    if have_gs && [ -f "$orig" ]; then
        while IFS='|' read -r schema key value; do
            [ -n "$schema" ] && have_schema "$schema" && timeout 5 gsettings set "$schema" "$key" "$value" 2>/dev/null || true
        done < "$orig"
    fi
    rm -f "$orig"
    echo "Removido: apps GTK4 e Editor de Texto voltam ao padrão ao serem reabertos."
    exit 0
fi

mkdir -p "$gtk4" "$state"
if ! { [ -f "$css" ] && grep -qF -- "$begin" "$css"; }; then
    block="$begin"$'\n''@import url("kortex-colors.css");'$'\n'"$end"$'\n'
    if [ -f "$css" ]; then
        cp -p "$css" "$css.bak-kortex-$stamp"
        { printf '%s\n' "$block"; cat "$css"; } > "$css.tmp.$$" && mv -f "$css.tmp.$$" "$css"
    else
        printf '%s' "$block" > "$css"
    fi
fi

# guarda os valores de antes, uma vez só (uma reinstalação não deve sobrescrever o original)
if have_gs && [ ! -f "$orig" ]; then
    : > "$orig"
    for k in "${keys[@]}"; do
        schema="${k%% *}"; key="${k##* }"
        have_schema "$schema" || continue
        v="$(timeout 5 gsettings get "$schema" "$key" 2>/dev/null)" || continue
        printf '%s|%s|%s\n' "$schema" "$key" "$v" >> "$orig"
    done
fi

bash "$here/gnome-theme.sh"
echo "Configurado: apps GTK4/libadwaita (cores em $gtk4/kortex-colors.css)."
have_gs || echo "Aviso: sem gsettings/sessão gráfica; o claro/escuro do sistema será escolhido na próxima troca de tema."
exit 0
