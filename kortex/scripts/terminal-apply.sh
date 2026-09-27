#!/usr/bin/env bash
# Terminal translúcido (Kitty), igual em qualquer tema. Chamado pelo shell (services/TerminalStyle.qml)
# ao iniciar e a cada mudança em Configurações › Aparência › Terminal.
#   terminal-apply.sh <opacidade em %, de 30 a 100> [desfoque 0|1, padrão 1]
#
#  • opacidade: grava ~/.local/state/kortex/kitty-window.conf (background_opacity), que o kitty-theme.conf
#    inclui, e manda os Kitty abertos recarregarem a configuração.
#  • desfoque: é do Hyprland, que desfoca o que aparece por trás de uma janela translúcida. Grava
#    ~/.local/state/kortex/hyprland-terminal.conf, que o hyprland.conf carrega (`source`): vazio = desfoque
#    ligado; desligado = regra `no_blur` para a classe kitty. Uma regra nova só chega às janelas já abertas
#    depois de um reload, então, se o arquivo mudou, o script manda o Hyprland recarregar a configuração.
pct="${1:-85}"
blur="${2:-1}"
[[ "$pct" =~ ^[0-9]+$ ]] || exit 0
(( pct < 30 )) && pct=30
(( pct > 100 )) && pct=100
[ "$blur" = 0 ] || blur=1

state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
mkdir -p "$state"
tmp_op="$(mktemp "$state/.kitty-window.XXXXXX")" || exit 0
tmp_bl="$(mktemp "$state/.hyprland-terminal.XXXXXX")" || { rm -f "$tmp_op"; exit 0; }
trap 'rm -f "$tmp_op" "$tmp_bl"' EXIT

printf '# Gerado pelo Kortex (scripts/terminal-apply.sh): opacidade do terminal, escolhida em Configurações.\nbackground_opacity %d.%02d\n' \
    $((pct / 100)) $((pct % 100)) > "$tmp_op"

{
    printf '# Gerado pelo Kortex (scripts/terminal-apply.sh): desfoque do terminal, escolhido em Configurações.\n'
    printf '# Carregado pelo hyprland.conf. Sem regra = desfoque ligado (o Hyprland desfoca janelas translúcidas).\n'
    [ "$blur" = 1 ] || printf 'windowrule = no_blur on, match:class ^kitty$\n'
} > "$tmp_bl"

# Opacidade
out="$state/kitty-window.conf"
if ! { [ -f "$out" ] && cmp -s "$tmp_op" "$out"; }; then
    chmod 644 "$tmp_op"
    mv -f "$tmp_op" "$out"
    pkill -USR1 -x kitty 2>/dev/null || true
fi

# Desfoque: um arquivo que ainda não existia equivale ao padrão (ligado), então só pede reload se houver regra
out="$state/hyprland-terminal.conf"
reload=0
if [ -f "$out" ]; then
    cmp -s "$tmp_bl" "$out" || reload=1
else
    [ "$blur" = 1 ] || reload=1
fi
if [ ! -f "$out" ] || [ "$reload" = 1 ]; then
    chmod 644 "$tmp_bl"
    mv -f "$tmp_bl" "$out"
fi
if [ "$reload" = 1 ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
    hyprctl reload config-only >/dev/null 2>&1 || true
fi
exit 0
