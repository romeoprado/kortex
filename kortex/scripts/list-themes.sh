#!/usr/bin/env bash
# Lista os temas (pastas com colors.toml). Saída para o Theme.qml:
#   @@THEME<TAB>nome<TAB>pasta<TAB>1º fundo<TAB>origem
#   <conteúdo do colors.toml>
# Pastas posteriores têm prioridade quando o nome se repete.
builtin_dir="$1"
dirs=(
    "$builtin_dir"
    "${XDG_DATA_HOME:-$HOME/.local/share}/kortex/themes"
)

shopt -s nullglob
for base in "${dirs[@]}"; do
    [ -d "$base" ] || continue
    for d in "$base"/*/; do
        d="${d%/}"
        name="$(basename "$d")"

        [ -f "$d/colors.toml" ] || continue

        bg=""
        if [ -d "$d/backgrounds" ]; then
            bg="$(find -L "$d/backgrounds" -maxdepth 1 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -n1)"
        fi

        printf '@@THEME\t%s\t%s\t%s\t%s\n' "$name" "$d" "$bg" "$base"
        cat "$d/colors.toml"
        echo
    done
done
