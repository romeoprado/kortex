#!/usr/bin/env bash
# Cores do btop a partir do tema ativo. Chamado pelo theme-apply.sh a cada troca de tema.
#   btop-theme.sh <nome> <fundo> <fundo-alt> <texto> <texto-forte> <texto-apagado>
#                 <acento> <muted> <vermelho> <verde> <amarelo> <azul> <magenta> <ciano>
#
# Grava ~/.config/btop/themes/kortex.theme e, se o btop ainda não tem tema escolhido (sem btop.conf,
# sem a linha color_theme ou com o "Default"), escolhe o "kortex" no btop.conf. Um tema que você
# escolheu no próprio btop é respeitado. Os btop abertos recarregam a configuração (SIGUSR2).
# O fundo fica vazio de propósito: o btop usa o do terminal, que já é o do tema (e translúcido no Kitty).
name="$1"
bg="$2"; bg_alt="$3"; fg="$4"; fg_bright="$5"; fg_dim="$6"; accent="$7"; muted="$8"
red="$9"; green="${10}"; yellow="${11}"; blue="${12}"; magenta="${13}"; cyan="${14}"

# Cor inválida: melhor não mexer no que já existe do que gravar um tema quebrado
for c in "$bg" "$bg_alt" "$fg" "$fg_bright" "$fg_dim" "$accent" "$muted" \
         "$red" "$green" "$yellow" "$blue" "$magenta" "$cyan"; do
    [[ "$c" =~ ^#[0-9a-fA-F]{6}$ ]] || exit 0
done

# mix <cor> <outra> <% da primeira>: mistura as duas, canal a canal
mix() {
    local a="${1#\#}" b="${2#\#}" p="$3" out="#" i x y
    for i in 0 2 4; do
        x=$((16#${a:i:2})); y=$((16#${b:i:2}))
        out+=$(printf '%02x' $(( (x * p + y * (100 - p) + 50) / 100 )))
    done
    printf '%s' "$out"
}
# Começo dos degradês: a cor apagada em direção ao fundo, para o gráfico "acender" conforme sobe
dim() { mix "$1" "$bg" 55; }

conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/btop"
mkdir -p "$conf_dir/themes" || exit 0
out="$conf_dir/themes/kortex.theme"
tmp="$(mktemp "$conf_dir/themes/.kortex.XXXXXX")" || exit 0
trap 'rm -f "$tmp"' EXIT

{
    printf '# Gerado pelo Kortex (scripts/btop-theme.sh) para o tema "%s".\n' "${name//[^A-Za-z0-9._ -]/}"
    printf '# É reescrito a cada troca de tema: para personalizar, copie com outro nome e escolha a cópia no btop.\n'
    cat <<THEME
theme[main_bg]=""
theme[main_fg]="$fg"
theme[title]="$fg_bright"
theme[hi_fg]="$accent"
theme[selected_bg]="$accent"
theme[selected_fg]="$bg"
theme[inactive_fg]="$fg_dim"
theme[graph_text]="$fg_dim"
theme[meter_bg]="$bg_alt"
theme[proc_misc]="$accent"
theme[cpu_box]="$muted"
theme[mem_box]="$muted"
theme[net_box]="$muted"
theme[proc_box]="$muted"
theme[div_line]="$muted"
theme[temp_start]="$blue"
theme[temp_mid]="$yellow"
theme[temp_end]="$red"
theme[cpu_start]="$accent"
theme[cpu_mid]="$yellow"
theme[cpu_end]="$red"
theme[free_start]="$(dim "$green")"
theme[free_mid]=""
theme[free_end]="$green"
theme[cached_start]="$(dim "$blue")"
theme[cached_mid]=""
theme[cached_end]="$blue"
theme[available_start]="$(dim "$yellow")"
theme[available_mid]=""
theme[available_end]="$yellow"
theme[used_start]="$(dim "$red")"
theme[used_mid]=""
theme[used_end]="$red"
theme[download_start]="$(dim "$cyan")"
theme[download_mid]=""
theme[download_end]="$cyan"
theme[upload_start]="$(dim "$magenta")"
theme[upload_mid]=""
theme[upload_end]="$magenta"
theme[process_start]="$accent"
theme[process_mid]="$yellow"
theme[process_end]="$red"
THEME
} > "$tmp"

changed=0
if ! { [ -f "$out" ] && cmp -s "$tmp" "$out"; }; then
    chmod 644 "$tmp"
    mv -f "$tmp" "$out"
    changed=1
fi
trap - EXIT

# Escolhe o tema "kortex" no btop.conf, só se nenhum outro foi escolhido. Sem btop.conf, basta a
# linha color_theme: o btop completa o resto com os padrões dele e regrava o arquivo ao sair.
conf="$conf_dir/btop.conf"
current=""
[ -f "$conf" ] && current="$(sed -nE 's/^[[:space:]]*color_theme[[:space:]]*=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/p' "$conf" | tail -n1)"
case "$current" in
    kortex|"$out") ;;
    ""|Default)
        if [ ! -f "$conf" ]; then
            printf 'color_theme = "kortex"\n' > "$conf"
        elif grep -qE '^[[:space:]]*color_theme[[:space:]]*=' "$conf"; then
            sed -i -E 's/^([[:space:]]*color_theme[[:space:]]*=).*/\1 "kortex"/' "$conf"
        else
            printf 'color_theme = "kortex"\n' >> "$conf"
        fi
        changed=1 ;;
    *) exit 0 ;;
esac

# Recarrega a configuração (e o tema) dos btop abertos: SIGUSR2 é o mecanismo do próprio btop
[ "$changed" = 1 ] && { pkill -USR2 -x btop 2>/dev/null || true; }
exit 0
