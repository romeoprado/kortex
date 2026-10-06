#!/usr/bin/env bash
# Efeitos de um tema fora do shell. Nada dentro do tema é executado, só lido.
#   theme-apply.sh <nome> <pasta> <acento> <fundo> <texto> <muted> <vermelho> <bordas 0|1>
#                  [fundo-alt] [texto-forte] [texto-apagado] [amarelo] [acento2]
#                  [verde] [azul] [magenta] [ciano] [seleção] [fundo-escuro] [claro 0|1]
# Os doze últimos são opcionais; na falta deles usa-se a cor mais próxima das obrigatórias.
name="$1"; dir="$2"; accent="$3"; bg="$4"; fg="$5"; muted="$6"; red="$7"; borders="${8:-1}"
bg_alt="${9:-$bg}"; fg_bright="${10:-$fg}"; fg_dim="${11:-$muted}"; yellow="${12:-$accent}"; accent2="${13:-$accent}"
green="${14:-$accent}"; blue="${15:-$accent}"; magenta="${16:-$accent}"; cyan="${17:-$accent}"
selection="${18:-$muted}"; bg_dark="${19:-$bg}"; light="${20:-0}"

state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
mkdir -p "$state"
ln -nsf "$dir" "$state/current-theme"
printf '%s\n' "$name" > "$state/theme.name"

strip() { printf '%s' "${1#\#}"; }

# Variáveis para outros programas
{
    printf 'KORTEX_THEME=%q\n' "$name"
    printf 'KORTEX_THEME_DIR=%q\n' "$dir"
    printf 'KORTEX_ACCENT=%q\nKORTEX_BG=%q\nKORTEX_FG=%q\nKORTEX_MUTED=%q\nKORTEX_RED=%q\n' "$accent" "$bg" "$fg" "$muted" "$red"
    printf 'KORTEX_ACCENT2=%q\nKORTEX_BG_ALT=%q\nKORTEX_FG_BRIGHT=%q\nKORTEX_FG_DIM=%q\nKORTEX_YELLOW=%q\n' "$accent2" "$bg_alt" "$fg_bright" "$fg_dim" "$yellow"
    printf 'KORTEX_BG_DARK=%q\nKORTEX_SELECTION=%q\nKORTEX_LIGHT=%q\n' "$bg_dark" "$selection" "$light"
    printf 'KORTEX_GREEN=%q\nKORTEX_BLUE=%q\nKORTEX_MAGENTA=%q\nKORTEX_CYAN=%q\n' "$green" "$blue" "$magenta" "$cyan"
} > "$state/colors.sh"

# Lido pelo Hyprland e também pelo hyprlock (tela de bloqueio): só variáveis, nada específico de um deles
cat > "$state/hyprland-colors.conf" <<CONF
\$kortex_accent = rgb($(strip "$accent"))
\$kortex_accent2 = rgb($(strip "$accent2"))
\$kortex_bg = rgb($(strip "$bg"))
\$kortex_bg_alt = rgb($(strip "$bg_alt"))
\$kortex_fg = rgb($(strip "$fg"))
\$kortex_fg_bright = rgb($(strip "$fg_bright"))
\$kortex_fg_dim = rgb($(strip "$fg_dim"))
\$kortex_muted = rgb($(strip "$muted"))
\$kortex_red = rgb($(strip "$red"))
\$kortex_yellow = rgb($(strip "$yellow"))
CONF

cat > "$state/colors.css" <<CSS
@define-color kortex_accent $accent;
@define-color kortex_bg $bg;
@define-color kortex_fg $fg;
@define-color kortex_muted $muted;
@define-color kortex_red $red;
@define-color kortex_accent2 $accent2;
@define-color kortex_bg_alt $bg_alt;
@define-color kortex_fg_bright $fg_bright;
@define-color kortex_fg_dim $fg_dim;
@define-color kortex_yellow $yellow;
CSS

# Tela de login (SDDM): as mesmas cores vão para o tema "kortex" do SDDM, se ele estiver instalado
bash "$(dirname "$0")/sddm-colors.sh" "$accent" "$bg" "$fg" "$muted" "$red" "$bg_alt" "$fg_bright" "$fg_dim" "$yellow" "$accent2" || true

# Terminal (Kitty): gera o kitty-theme.conf que o kitty.conf inclui e recarrega os Kitty abertos
bash "$(dirname "$0")/kitty-theme.sh" "$name" "$dir" "$light" "$bg" "$bg_alt" "$bg_dark" "$fg" "$fg_bright" \
    "$accent" "$muted" "$selection" "$red" "$green" "$yellow" "$blue" "$magenta" "$cyan" || true

# Monitor do sistema (btop): gera o tema "kortex" do btop e recarrega os btop abertos
bash "$(dirname "$0")/btop-theme.sh" "$name" "$bg" "$bg_alt" "$fg" "$fg_bright" "$fg_dim" \
    "$accent" "$muted" "$red" "$green" "$yellow" "$blue" "$magenta" "$cyan" || true

# Firefox: grava as cores no perfil, se o firefox-setup.sh já o configurou (vale na próxima abertura dele)
bash "$(dirname "$0")/firefox-theme.sh" || true

# Apps GTK4/libadwaita (Nautilus, Calculadora, Editor de Texto…): cores, claro/escuro e esquema do editor,
# se o gnome-setup.sh já os configurou
bash "$(dirname "$0")/gnome-theme.sh" || true

# Bordas das janelas do Hyprland, ao vivo
if [ "$borders" = 1 ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
    hyprctl --batch "keyword general:col.active_border rgb($(strip "$accent")) ; keyword general:col.inactive_border rgba($(strip "$muted")aa)" >/dev/null 2>&1 || true
fi

# Ícones dos apps GTK: o do icons.theme do tema ou, na falta dele, o Yaru mais próximo do acento
icons=""
[ -f "$dir/icons.theme" ] && icons="$(head -n1 "$dir/icons.theme" | tr -d '[:space:]')"
[ -n "$icons" ] || icons="$(bash "$(dirname "$0")/icon-theme.sh" pick "$accent" "$light")"
bash "$(dirname "$0")/icon-theme.sh" apply "$icons" || true

# Gancho do usuário: ~/.config/kortex/hooks/theme-set <nome> <pasta> <pasta-de-estado>
hook="${XDG_CONFIG_HOME:-$HOME/.config}/kortex/hooks/theme-set"
if [ -x "$hook" ]; then
    "$hook" "$name" "$dir" "$state" >/dev/null 2>&1 &
fi
exit 0
