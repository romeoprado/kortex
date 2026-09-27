#!/usr/bin/env bash
# Abre o aplicativo padrão do Kortex: terminal, explorador de arquivos ou navegador.
#   open-app.sh terminal|files|browser [argumentos]
# Os atalhos do hyprland.conf chamam este script, então ele não depende do shell estar rodando:
# lê ~/.local/state/kortex/apps.sh (gravado por apps-apply.sh, a partir das Configurações) e, sem
# escolha feita, cai nos programas mais comuns.
what="${1:-}"; shift 2>/dev/null || true
state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
KORTEX_TERMINAL=(); KORTEX_FILES=(); KORTEX_BROWSER=()
[ -f "$state/apps.sh" ] && . "$state/apps.sh"

# Executa o primeiro argumento (com os demais) se ele existir; senão segue para a próxima opção
try() { command -v "$1" >/dev/null 2>&1 && exec "$@"; }

case "$what" in
    terminal)
        [ ${#KORTEX_TERMINAL[@]} -gt 0 ] && try "${KORTEX_TERMINAL[@]}" "$@"
        [ -n "${TERMINAL:-}" ] && try "$TERMINAL" "$@"
        for t in xdg-terminal-exec kitty alacritty ghostty foot wezterm konsole gnome-terminal xterm; do try "$t" "$@"; done
        ;;
    files)
        [ ${#KORTEX_FILES[@]} -gt 0 ] && try "${KORTEX_FILES[@]}" "$@"
        for f in nautilus thunar dolphin pcmanfm nemo; do try "$f" "$@"; done
        exec xdg-open "${1:-$HOME}"
        ;;
    browser)
        [ ${#KORTEX_BROWSER[@]} -gt 0 ] && try "${KORTEX_BROWSER[@]}" "$@"
        if [ $# -gt 0 ]; then exec xdg-open "$1"; fi
        id="$(xdg-mime query default x-scheme-handler/https 2>/dev/null)"
        [ -n "$id" ] && command -v gtk-launch >/dev/null 2>&1 && exec gtk-launch "$id"
        for b in firefox chromium google-chrome-stable brave zen-browser; do try "$b"; done
        ;;
    *)
        echo "Uso: open-app.sh terminal|files|browser [argumentos]" >&2
        exit 2
        ;;
esac
echo "open-app.sh: nenhum aplicativo encontrado para '$what'" >&2
exit 1
