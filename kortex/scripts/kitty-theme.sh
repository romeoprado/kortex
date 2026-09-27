#!/usr/bin/env bash
# Cores do Kitty a partir do tema ativo. Chamado pelo theme-apply.sh a cada troca de tema.
#   kitty-theme.sh <nome> <pasta-do-tema> <claro 0|1> <fundo> <fundo-alt> <fundo-escuro> <texto> <texto-forte>
#                  <acento> <muted> <seleção> <vermelho> <verde> <amarelo> <azul> <magenta> <ciano>
#
# Grava ~/.local/state/kortex/kitty-theme.conf, que o kitty.conf inclui (o instalador põe essa linha),
# e manda os Kitty abertos recarregarem a configuração. O arquivo também inclui o kitty-window.conf
# (opacidade do terminal, do terminal-apply.sh), que não depende do tema.
# As cores de terminal do colors.toml do tema (color0 a color15, cursor, selection_foreground e
# selection_background), quando ele as traz, vão por cima da paleta gerada.
name="$1"; dir="$2"; light="$3"
bg="$4"; bg_alt="$5"; bg_dark="$6"; fg="$7"; fg_bright="$8"
accent="$9"; muted="${10}"; sel="${11}"
red="${12}"; green="${13}"; yellow="${14}"; blue="${15}"; magenta="${16}"; cyan="${17}"

# Cor inválida: melhor não mexer no que já existe do que gravar uma configuração quebrada
for c in "$bg" "$bg_alt" "$bg_dark" "$fg" "$fg_bright" "$accent" "$muted" "$sel" \
         "$red" "$green" "$yellow" "$blue" "$magenta" "$cyan"; do
    [[ "$c" =~ ^#[0-9a-fA-F]{6}$ ]] || exit 0
done

state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
mkdir -p "$state"
out="$state/kitty-theme.conf"
tmp="$(mktemp "$state/.kitty-theme.XXXXXX")" || exit 0
trap 'rm -f "$tmp"' EXIT

# "Preto" e "branco" ANSI: em tema escuro o preto é o fundo mais escuro; em tema claro os papéis se invertem
if [ "$light" = 1 ]; then
    c0="$fg_bright"; c7="$sel"; c8="$muted"; c15="$bg_dark"
else
    c0="$bg_dark"; c7="$fg"; c8="$muted"; c15="$fg_bright"
fi

{
    printf '# Gerado pelo Kortex (scripts/kitty-theme.sh) para o tema "%s".\n' "${name//[^A-Za-z0-9._ -]/}"
    printf '# É reescrito a cada troca de tema: para mudar algo, use o kitty.conf, depois da linha "include".\n'
    cat <<CONF
foreground $fg
background $bg
selection_foreground $fg_bright
selection_background $sel
cursor $accent
cursor_text_color $bg
url_color $accent
active_border_color $accent
inactive_border_color $muted
bell_border_color $yellow
active_tab_foreground $bg
active_tab_background $accent
inactive_tab_foreground $fg
inactive_tab_background $bg_alt
tab_bar_background $bg_dark

color0 $c0
color1 $red
color2 $green
color3 $yellow
color4 $blue
color5 $magenta
color6 $cyan
color7 $c7
color8 $c8
color9 $red
color10 $green
color11 $yellow
color12 $blue
color13 $magenta
color14 $cyan
color15 $c15

# Opacidade do terminal: vem das Configurações (terminal-apply.sh), não do tema
include $state/kitty-window.conf
CONF

    # Cores de terminal do próprio tema, se o colors.toml as traz. Só chave conhecida + valor #rrggbb.
    if [ -f "$dir/colors.toml" ]; then
        printf '\n# Cores de terminal do colors.toml do tema\n'
        sed -nE 's/^[[:space:]]*(color([0-9]|1[0-5])|cursor|selection_foreground|selection_background)[[:space:]]*=[[:space:]]*"?(#[0-9a-fA-F]{6})"?[[:space:]]*(#.*)?$/\1 \3/p' \
            "$dir/colors.toml" 2>/dev/null | head -n 20
    fi
} > "$tmp"

# Sem mudança, nada a fazer (o shell chama isto a cada início, e recarregar o Kitty é desnecessário)
if [ -f "$out" ] && cmp -s "$tmp" "$out"; then exit 0; fi

chmod 644 "$tmp"
mv -f "$tmp" "$out"
trap - EXIT

# Recarrega a configuração dos Kitty abertos (SIGUSR1 é o mecanismo do próprio Kitty)
pkill -USR1 -x kitty 2>/dev/null || true
exit 0
