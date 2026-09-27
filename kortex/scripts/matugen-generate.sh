#!/usr/bin/env bash
# Gera as cores de um tema a partir de um papel de parede, com o Matugen.
#   matugen-generate.sh <imagem> [escuro|claro] [esquema] [pasta-de-temas] [nome]
# Grava <pasta-de-temas>/<nome>/colors.toml e icons.theme (nome padrão: "matugen", o tema dinâmico)
# e imprime o colors.toml na saída padrão. Com "-" no lugar da pasta é só uma PRÉVIA: imprime o colors.toml
# e não grava nada. Com um <nome> diferente de "matugen" (salvar o tema atual com nome próprio), o
# papel de parede também é copiado para <pasta-de-temas>/<nome>/backgrounds/, para o tema salvo
# lembrar sozinho qual imagem gerou essas cores.
# Em caso de erro imprime UMA linha na saída de erro e sai com código diferente de zero,
# sem tocar no tema que já existe. O Matugen roda só com o config temporário daqui: a configuração
# pessoal dele (~/.config/matugen) não é lida nem alterada.
wallpaper="$1"
mode="${2:-dark}"
scheme="${3:-scheme-tonal-spot}"
themes="${4:-${XDG_DATA_HOME:-$HOME/.local/share}/kortex/themes}"
name="${5:-matugen}"

fail() { echo "$1" >&2; exit "${2:-1}"; }

case "$name" in
    ""|.|..|*/*) fail "Nome de tema inválido." ;;
esac

command -v matugen >/dev/null || fail "O Matugen não está instalado (sudo pacman -S matugen)." 127
[ -n "$wallpaper" ] && [ -f "$wallpaper" ] || fail "Papel de parede não encontrado."

case "$mode" in
    light|claro) mode=light ;;
    *) mode=dark ;;
esac
case "$scheme" in
    scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|\
    scheme-neutral|scheme-rainbow|scheme-tonal-spot|scheme-vibrant|scheme-smart) ;;
    *) scheme=scheme-tonal-spot ;;
esac

base="$(cd "$(dirname "$0")/.." && pwd)/matugen"
template="$base/colors.toml"
semantic="$base/semantic-$([ "$mode" = light ] && echo light || echo dark).json"
[ -f "$template" ] && [ -f "$semantic" ] || fail "Modelo do Matugen ausente em $base."

work="$(mktemp -d)" || fail "Não foi possível criar uma pasta temporária."
trap 'rm -rf "$work"' EXIT
cp "$template" "$work/template.toml"

# Só o modelo de saída: as cores vermelho, verde etc. vêm do semantic-<modo>.json (ver o modelo).
cat > "$work/config.toml" <<CONF
[config]

[templates.kortex]
input_path = '$work/template.toml'
output_path = '$work/colors.toml'
CONF

# Índice 0 = a cor mais dominante; sem ele o Matugen pergunta no terminal quando há várias.
if ! NO_COLOR=1 matugen -c "$work/config.toml" image "$wallpaper" --mode "$mode" --type "$scheme" \
        --source-color-index 0 --import-json "$semantic" -q >"$work/log" 2>&1; then
    fail "O Matugen não conseguiu ler essa imagem."
fi

# Confere o resultado antes de substituir o tema: precisa ter as cores principais e nenhum modelo sobrando
for k in background foreground accent red green yellow blue magenta cyan; do
    grep -Eq "^$k = \"#[0-9a-fA-F]{6}\"" "$work/colors.toml" || fail "O Matugen não gerou a cor \"$k\"."
done

if [ "$themes" = "-" ]; then
    cat "$work/colors.toml"
    exit 0
fi

dest="$themes/$name"
mkdir -p "$dest" || fail "Não foi possível criar $dest."
cp -f "$work/colors.toml" "$dest/colors.toml.new" && mv -f "$dest/colors.toml.new" "$dest/colors.toml" \
    || fail "Não foi possível gravar $dest/colors.toml."
rm -f "$dest/source.txt"    # de versões anteriores

# Ícones: o Yaru mais próximo do acento gerado
accent="$(sed -nE 's/^accent = "(#[0-9a-fA-F]{6})"$/\1/p' "$dest/colors.toml" | head -n1)"
bash "$(dirname "$0")/icon-theme.sh" pick "$accent" "$([ "$mode" = light ] && echo 1 || echo 0)" > "$dest/icons.theme"

# Tema salvo com nome próprio (não o dinâmico): guarda a imagem usada, para lembrar sozinho o
# papel de parede ao ser aplicado depois. Troca a de uma vez anterior, se houver.
if [ "$name" != "matugen" ]; then
    rm -rf "$dest/backgrounds"
    mkdir -p "$dest/backgrounds" || fail "Não foi possível criar $dest/backgrounds."
    cp -f "$wallpaper" "$dest/backgrounds/$(basename "$wallpaper")" \
        || fail "Não foi possível copiar o papel de parede."
fi

cat "$dest/colors.toml"
