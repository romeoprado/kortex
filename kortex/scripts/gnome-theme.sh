#!/usr/bin/env bash
# Grava as cores do tema atual do Kortex para os apps GTK4/libadwaita (Nautilus, Calculadora, Editor de
# Texto…), se o gnome-setup.sh já os configurou:
#   - ~/.config/gtk-4.0/kortex-colors.css (importado pelo gtk.css do usuário);
#   - o esquema claro/escuro do sistema (org.gnome.desktop.interface color-scheme);
#   - um esquema de cores do GtkSourceView ("kortex"), que o Editor de Texto passa a usar.
# Os apps já abertos só mudam ao reabrir, exceto o claro/escuro, que o libadwaita segue ao vivo.
# KORTEX_GNOME_NO_GSETTINGS=1 pula as chamadas ao gsettings (testes).
state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
[ -f "$state/colors.sh" ] || exit 0
# shellcheck disable=SC1091
. "$state/colors.sh"

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"; gtk4="$cfg/gtk-4.0"
grep -qF '>>> kortex' "$gtk4/gtk.css" 2>/dev/null || exit 0     # só se já configurado

bg="${KORTEX_BG:-#1e1e2e}"; fg="${KORTEX_FG:-#cdd6f4}"; accent="${KORTEX_ACCENT:-#89b4fa}"
bg_alt="${KORTEX_BG_ALT:-$bg}"; bg_dark="${KORTEX_BG_DARK:-$bg}"; fg_bright="${KORTEX_FG_BRIGHT:-$fg}"
fg_dim="${KORTEX_FG_DIM:-$fg}"; muted="${KORTEX_MUTED:-$fg}"; selection="${KORTEX_SELECTION:-$muted}"
red="${KORTEX_RED:-$accent}"; yellow="${KORTEX_YELLOW:-$accent}"; green="${KORTEX_GREEN:-$accent}"
blue="${KORTEX_BLUE:-$accent}"; magenta="${KORTEX_MAGENTA:-$accent}"; cyan="${KORTEX_CYAN:-$accent}"
light="${KORTEX_LIGHT:-0}"

# Preto ou branco, o que contrasta com a cor dada (luminância aproximada)
on() {
    local h="${1#\#}"; [ "${#h}" -eq 6 ] || { echo "#ffffff"; return; }
    awk -v r="$((16#${h:0:2}))" -v g="$((16#${h:2:2}))" -v b="$((16#${h:4:2}))" \
        'BEGIN { print ((0.299*r + 0.587*g + 0.114*b) > 150) ? "#000000" : "#ffffff" }'
}
if [ "$light" = 1 ]; then shade="rgb(0 0 0 / 7%)"; scroll="rgb(255 255 255)"; variant=light
else shade="rgb(0 0 0 / 36%)"; scroll="rgb(0 0 0 / 50%)"; variant=dark; fi

# --- cores do libadwaita (variáveis CSS do :root, que é o que a 1.6 em diante respeita) ---
tmp="$gtk4/.kortex-colors.css.$$"
cat > "$tmp" <<CSS
/* Gerado pelo Kortex a cada troca de tema (${KORTEX_THEME:-tema}). Não edite: será sobrescrito. */
:root {
  --window-bg-color: $bg;              --window-fg-color: $fg;
  --view-bg-color: $bg_dark;           --view-fg-color: $fg;
  --headerbar-bg-color: $bg_alt;       --headerbar-fg-color: $fg_bright;
  --headerbar-border-color: $muted;    --headerbar-backdrop-color: $bg;
  --headerbar-shade-color: $shade;     --headerbar-darker-shade-color: $shade;
  --card-bg-color: $bg_alt;            --card-fg-color: $fg;   --card-shade-color: $shade;
  --dialog-bg-color: $bg_alt;          --dialog-fg-color: $fg;
  --popover-bg-color: $bg_alt;         --popover-fg-color: $fg;  --popover-shade-color: $shade;
  --thumbnail-bg-color: $bg_alt;       --thumbnail-fg-color: $fg;
  --sidebar-bg-color: $bg_alt;         --sidebar-fg-color: $fg;
  --sidebar-backdrop-color: $bg;       --sidebar-border-color: $muted;   --sidebar-shade-color: $shade;
  --secondary-sidebar-bg-color: $bg;   --secondary-sidebar-fg-color: $fg;
  --secondary-sidebar-backdrop-color: $bg;  --secondary-sidebar-border-color: $muted;
  --secondary-sidebar-shade-color: $shade;
  --shade-color: $shade;               --scrollbar-outline-color: $scroll;
  --accent-bg-color: $accent;          --accent-fg-color: $(on "$accent");   --accent-color: $accent;
  --destructive-bg-color: $red;        --destructive-fg-color: $(on "$red"); --destructive-color: $red;
  --success-bg-color: $green;          --success-fg-color: $(on "$green");   --success-color: $green;
  --warning-bg-color: $yellow;         --warning-fg-color: $(on "$yellow");  --warning-color: $yellow;
  --error-bg-color: $red;              --error-fg-color: $(on "$red");       --error-color: $red;
}
CSS
mv -f "$tmp" "$gtk4/kortex-colors.css"

# --- esquema de cores do GtkSourceView, usado pelo Editor de Texto ---
data="${XDG_DATA_HOME:-$HOME/.local/share}/gtksourceview-5/styles"
mkdir -p "$data"
cat > "$data/.kortex.xml.$$" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!-- Gerado pelo Kortex a cada troca de tema (${KORTEX_THEME:-tema}). Não edite: será sobrescrito. -->
<style-scheme id="kortex" name="Kortex" version="1.0">
  <author>Kortex</author>
  <description>Cores do tema ativo do Kortex</description>
  <metadata><property name="variant">$variant</property></metadata>

  <color name="bg" value="$bg_dark"/>
  <color name="bg-alt" value="$bg_alt"/>
  <color name="fg" value="$fg"/>
  <color name="dim" value="$fg_dim"/>
  <color name="muted" value="$muted"/>
  <color name="sel" value="$selection"/>
  <color name="accent" value="$accent"/>
  <color name="red" value="$red"/>
  <color name="green" value="$green"/>
  <color name="yellow" value="$yellow"/>
  <color name="blue" value="$blue"/>
  <color name="magenta" value="$magenta"/>
  <color name="cyan" value="$cyan"/>

  <style name="text" foreground="fg" background="bg"/>
  <style name="selection" background="sel"/>
  <style name="selection-unfocused" background="muted"/>
  <style name="cursor" foreground="accent"/>
  <style name="secondary-cursor" foreground="dim"/>
  <style name="current-line" background="bg-alt"/>
  <style name="line-numbers" foreground="dim" background="bg"/>
  <style name="current-line-number" foreground="fg" background="bg-alt" bold="true"/>
  <style name="right-margin" foreground="muted"/>
  <style name="draw-spaces" foreground="muted"/>
  <style name="bracket-match" foreground="fg" background="sel" bold="true"/>
  <style name="bracket-mismatch" foreground="red" underline="true"/>
  <style name="search-match" background="sel" underline="true"/>
  <style name="def:error" foreground="red" underline="true"/>
  <style name="def:warning" foreground="yellow" underline="true"/>
  <style name="def:note" foreground="bg" background="yellow"/>
  <style name="def:comment" foreground="dim" italic="true"/>
  <style name="def:shebang" foreground="dim" bold="true"/>
  <style name="def:doc-comment-element" foreground="dim" italic="true"/>
  <style name="def:string" foreground="green"/>
  <style name="def:special-char" foreground="cyan"/>
  <style name="def:character" foreground="green"/>
  <style name="def:keyword" foreground="magenta"/>
  <style name="def:statement" foreground="magenta"/>
  <style name="def:builtin" foreground="blue"/>
  <style name="def:function" foreground="blue"/>
  <style name="def:type" foreground="yellow"/>
  <style name="def:constant" foreground="cyan"/>
  <style name="def:number" foreground="cyan"/>
  <style name="def:boolean" foreground="cyan"/>
  <style name="def:special-constant" foreground="cyan"/>
  <style name="def:preprocessor" foreground="accent"/>
  <style name="def:identifier" foreground="fg"/>
  <style name="def:operator" foreground="fg"/>
  <style name="def:heading" foreground="accent" bold="true"/>
  <style name="def:bold" bold="true"/>
  <style name="def:emphasis" italic="true"/>
  <style name="def:underlined" underline="true"/>
  <style name="def:link-destination" foreground="accent" underline="true"/>
  <style name="def:inline-code" foreground="cyan"/>
  <style name="def:list-marker" foreground="accent"/>
</style-scheme>
XML
mv -f "$data/.kortex.xml.$$" "$data/kortex.xml"

# --- esquema do sistema e escolha do Editor de Texto ---
[ "${KORTEX_GNOME_NO_GSETTINGS:-0}" = 1 ] && exit 0
command -v gsettings >/dev/null 2>&1 || exit 0
scheme=prefer-dark; [ "$light" = 1 ] && scheme=prefer-light
timeout 5 gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null || true
if gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.TextEditor'; then
    timeout 5 gsettings set org.gnome.TextEditor style-scheme kortex 2>/dev/null || true
    timeout 5 gsettings set org.gnome.TextEditor style-variant "$variant" 2>/dev/null || true
fi
exit 0
