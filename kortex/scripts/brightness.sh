#!/usr/bin/env bash
# Brilho da tela pelo brightnessctl, na luz de fundo certa (chamado pelo Kortex e pelos atalhos do Hyprland).
#   brightness.sh [argumentos do brightnessctl...]      ex.: brightness.sh -m    brightness.sh set 5%+
# Notebooks com duas GPUs costumam ter duas luzes de fundo (ex.: intel_backlight e nvidia_0) e o
# brightnessctl, sem -d, usa a primeira que acha, que pode não ser a da tela: ele muda o valor e nada
# acontece. Aqui vale a que pertence a um conector conectado (…/card1-eDP-1/intel_backlight); se
# nenhuma pertencer (ex.: acpi_video0), a primeira, como o brightnessctl faria.
dev=""
for d in /sys/class/backlight/*; do
    [ -e "$d" ] || continue
    [ -n "$dev" ] || dev="${d##*/}"
    if [ "$(cat "$(dirname "$(readlink -f "$d")")/status" 2>/dev/null)" = connected ]; then
        dev="${d##*/}"
        break
    fi
done
[ -n "$dev" ] || { echo "nenhuma luz de fundo encontrada" >&2; exit 1; }
exec brightnessctl -c backlight -d "$dev" "$@"
