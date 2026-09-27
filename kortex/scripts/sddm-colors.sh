#!/usr/bin/env bash
# Grava as cores do tema ativo na tela de login (SDDM), se o tema "kortex" do SDDM estiver instalado.
#   sddm-colors.sh <acento> <fundo> <texto> <muted> <vermelho> <fundo-alt> <texto-forte> <texto-apagado> <amarelo> <acento2>
# O theme.conf.user do tema pertence ao usuário (veja sddm-setup.sh), então isto não pede senha.
# Sem o tema instalado, ou sem permissão de escrita, não faz nada.
accent="$1"; bg="$2"; fg="$3"; muted="$4"; red="$5"; bg_alt="$6"; fg_bright="$7"; fg_dim="$8"; yellow="$9"; accent2="${10}"

file="${KORTEX_SDDM_THEME_DIR:-/usr/share/sddm/themes/kortex}/theme.conf.user"
[ -w "$file" ] || exit 0

out="[General]"$'\n'
add() {
    # Só aceita #rrggbb; um valor estranho fica de fora e o tema usa o padrão do theme.conf
    [[ "$2" =~ ^#[0-9a-fA-F]{6}$ ]] && out+="$1=$2"$'\n'
    return 0
}
add bg "$bg"
add bgAlt "$bg_alt"
add fg "$fg"
add fgBright "$fg_bright"
add fgDim "$fg_dim"
add accent "$accent"
add accent2 "$accent2"
add muted "$muted"
add red "$red"
add yellow "$yellow"

# Uma única escrita, no mesmo arquivo (a pasta é do root, então não dá para trocar por rename)
printf '%s' "$out" > "$file"
exit 0
