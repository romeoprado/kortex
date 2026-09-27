#!/usr/bin/env bash
# Tema de ícones (icons.theme) dos temas do Kortex.
#   icon-theme.sh pick <acento> <claro 0|1>   imprime a variante do Yaru mais próxima do acento
#                                             ("-dark" em tema escuro), para temas sem icons.theme
#   icon-theme.sh apply <nome>                aplica o tema de ícones aos apps GTK (gsettings e o
#                                             settings.ini do GTK 3 e 4), se ele estiver instalado
# KORTEX_GNOME_NO_GSETTINGS=1 pula o gsettings (testes).

pick() {
    local accent="${1#\#}" light="${2:-0}" name
    [[ "$accent" =~ ^[0-9a-fA-F]{6}$ ]] || accent=2686e6
    # Pela tonalidade (OKLCh) da cor das pastas de cada variante do Yaru: acento com cor nítida vai
    # para a variante de tonalidade mais próxima; acento quase cinza, para a Sage (fria) ou a
    # Wartybrown (quente), as duas variantes acinzentadas
    name="$(awk -v c="$accent" '
        function lin(v) { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
        function cbrt(x) { return x < 0 ? -((-x) ^ (1/3)) : x ^ (1/3) }
        function lch(h,   r, g, b, l, m, s, A, B) {
            r = lin(strtonum("0x" substr(h, 1, 2))); g = lin(strtonum("0x" substr(h, 3, 2))); b = lin(strtonum("0x" substr(h, 5, 2)))
            l = cbrt(0.4122214708*r + 0.5363325363*g + 0.0514459929*b)
            m = cbrt(0.2119034982*r + 0.6806995451*g + 0.1073969566*b)
            s = cbrt(0.0883024619*r + 0.2817188376*g + 0.6299787005*b)
            A = 1.9779984951*l - 2.4285922050*m + 0.4505937099*s
            B = 0.0259040371*l + 0.7827717662*m - 0.8086757660*s
            C = sqrt(A*A + B*B); H = atan2(B, A) * 180 / 3.14159265358979; if (H < 0) H += 360
        }
        BEGIN {
            lch(c)
            if (C < 0.05) { print (C >= 0.015 && H >= 20 && H <= 110) ? "Yaru-wartybrown" : "Yaru-sage"; exit }
            h0 = H
            n = split("Yaru:da5b2a Yaru-blue:2686e6 Yaru-magenta:bc65bd Yaru-olive:669427 " \
                      "Yaru-prussiangreen:4e9291 Yaru-purple:8a79dc Yaru-red:dd5169 Yaru-yellow:b17d26", v, " ")
            best = ""; bd = 1e9
            for (i = 1; i <= n; i++) {
                split(v[i], p, ":"); lch(p[2])
                d = h0 - H; if (d < 0) d = -d; if (d > 180) d = 360 - d
                if (d < bd) { bd = d; best = p[1] }
            }
            print best
        }')"
    [ "$light" = 1 ] || name="$name-dark"
    printf '%s\n' "$name"
}

apply() {
    local name="$1" found="" d cfg f
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || exit 0
    for d in "${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons" /usr/local/share/icons /usr/share/icons; do
        [ -f "$d/$name/index.theme" ] && { found=1; break; }
    done
    [ -n "$found" ] || exit 0    # não instalado: os ícones atuais ficam

    # GTK 3 e 4 fora do GNOME leem o settings.ini; só onde ele já existe
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
    for f in "$cfg/gtk-3.0/settings.ini" "$cfg/gtk-4.0/settings.ini"; do
        [ -f "$f" ] || continue
        if grep -q '^[[:space:]]*gtk-icon-theme-name[[:space:]]*=' "$f"; then
            sed -i "s|^[[:space:]]*gtk-icon-theme-name[[:space:]]*=.*|gtk-icon-theme-name=$name|" "$f"
        elif grep -q '^\[Settings\]' "$f"; then
            sed -i "/^\[Settings\]/a gtk-icon-theme-name=$name" "$f"
        fi
    done

    [ "${KORTEX_GNOME_NO_GSETTINGS:-0}" = 1 ] && exit 0
    command -v gsettings >/dev/null 2>&1 || exit 0
    [ "$(timeout 5 gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null)" = "'$name'" ] && exit 0
    timeout 5 gsettings set org.gnome.desktop.interface icon-theme "$name" 2>/dev/null || true
}

case "${1:-}" in
    pick) pick "$2" "$3" ;;
    apply) apply "$2" ;;
    *) echo "Uso: icon-theme.sh pick <acento> <claro 0|1> | apply <nome>" >&2; exit 2 ;;
esac
exit 0
