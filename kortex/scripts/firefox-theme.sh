#!/usr/bin/env bash
# Grava as cores do tema atual do Kortex nos perfis do Firefox que o firefox-setup.sh já configurou:
# escreve chrome/kortex-colors.css, que o kortex-chrome.css e o kortex-content.css importam.
#   firefox-theme.sh [<pasta-de-perfil>...]    (sem argumentos: o perfil padrão de cada instalação)
# O Firefox lê esses arquivos ao abrir: a troca vale na próxima vez que ele iniciar.
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=firefox-common.sh
. "$here/firefox-common.sh"

state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
[ -f "$state/colors.sh" ] || exit 0
# shellcheck disable=SC1091
. "$state/colors.sh"

bg="${KORTEX_BG:-#1e1e2e}"; fg="${KORTEX_FG:-#cdd6f4}"; accent="${KORTEX_ACCENT:-#89b4fa}"
scheme=dark; [ "${KORTEX_LIGHT:-0}" = 1 ] && scheme=light

if [ "$#" -gt 0 ]; then profiles=("$@"); else mapfile -t profiles < <(firefox_profiles); fi

for p in "${profiles[@]}"; do
    # só perfis já configurados pelo Kortex
    [ -f "$p/chrome/kortex-chrome.css" ] || continue
    tmp="$p/chrome/.kortex-colors.css.$$"
    cat > "$tmp" <<CSS
/* Gerado pelo Kortex a cada troca de tema (${KORTEX_THEME:-tema}). Não edite: será sobrescrito. */
:root {
  --kortex-scheme: $scheme;
  --kortex-bg: $bg;
  --kortex-bg-alt: ${KORTEX_BG_ALT:-$bg};
  --kortex-bg-dark: ${KORTEX_BG_DARK:-$bg};
  --kortex-fg: $fg;
  --kortex-fg-bright: ${KORTEX_FG_BRIGHT:-$fg};
  --kortex-fg-dim: ${KORTEX_FG_DIM:-$fg};
  --kortex-accent: $accent;
  --kortex-muted: ${KORTEX_MUTED:-$fg};
  --kortex-selection: ${KORTEX_SELECTION:-$accent};
  --kortex-red: ${KORTEX_RED:-$accent};
}
CSS
    mv -f "$tmp" "$p/chrome/kortex-colors.css"
done
exit 0
