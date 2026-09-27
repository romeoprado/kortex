#!/usr/bin/env bash
# Abre um comando no terminal preferido: term.sh <terminal|""> <comando...>
t="$1"; shift
if [ -z "$t" ]; then
    if command -v xdg-terminal-exec >/dev/null; then exec xdg-terminal-exec "$@"; fi
    t="${TERMINAL:-}"
    if [ -z "$t" ]; then
        for c in kitty ghostty alacritty foot wezterm konsole gnome-terminal xterm; do
            command -v "$c" >/dev/null && { t="$c"; break; }
        done
    fi
fi
case "$t" in
    kitty) exec kitty "$@" ;;   # o Kitty não tem -e: o comando vem direto depois das opções
    wezterm) exec wezterm start -- "$@" ;;
    gnome-terminal) exec gnome-terminal -- "$@" ;;
    *) exec "$t" -e "$@" ;;
esac
