#!/usr/bin/env bash
# Lista imagens: fundos do tema, fundos extras do usuário (~/.local/share/kortex/backgrounds/<tema>) e a pasta escolhida.
theme_dir="$1"
theme_name="$2"
extra="${3/#\~/$HOME}"

for dir in \
    "$theme_dir/backgrounds" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/kortex/backgrounds/$theme_name" \
    "$extra"; do
    [ -n "$dir" ] && [ -d "$dir" ] || continue
    find -L "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort
done
