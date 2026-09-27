#!/usr/bin/env bash
# Aplicativos padrão do Kortex (chamado pelas Configurações).
#   apps-apply.sh <terminal|files|browser> <id-do-desktop | -> [comando...]
# Grava a escolha em ~/.local/state/kortex/apps.sh (lido pelo open-app.sh, que os atalhos do Hyprland
# usam) e, para o explorador de arquivos e o navegador, registra também o padrão do sistema com
# xdg-mime, que é o que outros programas consultam ao abrir uma pasta ou um link.
# Com "-" no lugar do id volta ao automático (o padrão do sistema, já registrado, não é desfeito).
kind="${1:-}"; id="${2:--}"; shift 2 2>/dev/null || true

case "$kind" in
    terminal) var=KORTEX_TERMINAL ;;
    files)    var=KORTEX_FILES ;;
    browser)  var=KORTEX_BROWSER ;;
    *) echo "Uso: apps-apply.sh terminal|files|browser <id|-> [comando...]" >&2; exit 2 ;;
esac
[[ "$id" == "-" || "$id" =~ ^[A-Za-z0-9._+-]+$ ]] || { echo "id inválido: $id" >&2; exit 2; }

state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
mkdir -p "$state"
file="$state/apps.sh"
tmp="$(mktemp "$state/.apps.XXXXXX")" || exit 1
[ -f "$file" ] && grep -v "^$var=" "$file" > "$tmp"
if [ "$id" != "-" ] && [ $# -gt 0 ]; then
    { printf '%s=(' "$var"; printf '%q ' "$@"; printf ')\n'; } >> "$tmp"
fi
chmod 644 "$tmp"
mv -f "$tmp" "$file"

if [ "$id" != "-" ]; then
    case "$kind" in
        files)   xdg-mime default "$id.desktop" inode/directory ;;
        browser) xdg-mime default "$id.desktop" x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml ;;
    esac
fi
exit 0
