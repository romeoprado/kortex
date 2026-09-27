#!/usr/bin/env bash
# Configura o Firefox para usar as cores do tema do Kortex: instala no perfil o kortex-chrome.css (interface)
# e o kortex-content.css (páginas internas: nova aba, about:…) e liga o suporte a essas folhas de estilo.
#   firefox-setup.sh                instala no perfil padrão de cada instalação do Firefox
#   firefox-setup.sh --remove       desfaz (remove os arquivos e as linhas do Kortex)
#   firefox-setup.sh [--remove] <pasta-de-perfil>...   age só nestes perfis
# Mexe só em chrome/ e no user.js do perfil, guarda cópia (.bak-kortex-…) de qualquer arquivo seu que
# alterar e não toca no prefs.js. O Firefox lê tudo ao abrir: reinicie-o depois (o script não o fecha).
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=firefox-common.sh
. "$here/firefox-common.sh"
src="$here/../firefox"

remove=0
if [ "${1:-}" = "--remove" ]; then remove=1; shift; fi
if [ "$#" -gt 0 ]; then profiles=("$@"); else mapfile -t profiles < <(firefox_profiles); fi
if [ "${#profiles[@]}" -eq 0 ]; then
    echo "Nenhum perfil do Firefox encontrado. Abra o Firefox uma vez e rode de novo: $0" >&2
    exit 0
fi

stamp="$(date +%Y%m%d-%H%M%S)"
begin='/* >>> kortex */'; end='/* <<< kortex */'
pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

backup() { [ -f "$1" ] && cp -p "$1" "$1.bak-kortex-$stamp"; }

# Põe, no INÍCIO do arquivo (um @import só vale antes das outras regras), o bloco que importa o CSS do Kortex
add_import() {
    local file="$1" css="$2"
    if [ -f "$file" ] && grep -qF -- "$begin" "$file"; then return 0; fi
    local block; block="$begin"$'\n'"@import \"$css\";"$'\n'"$end"$'\n'
    if [ -f "$file" ]; then
        backup "$file"
        { printf '%s\n' "$block"; cat "$file"; } > "$file.tmp.$$" && mv -f "$file.tmp.$$" "$file"
    else
        printf '%s' "$block" > "$file"
    fi
}

drop_import() {
    local file="$1"
    [ -f "$file" ] || return 0
    grep -qF -- "$begin" "$file" || return 0
    sed -i "\|>>> kortex|,\|<<< kortex|d" "$file"
    # arquivo que ficou só com espaços: remove
    if ! grep -q '[^[:space:]]' "$file"; then rm -f "$file"; fi
}

for p in "${profiles[@]}"; do
    [ -d "$p" ] || { echo "Perfil não encontrado: $p" >&2; continue; }
    if [ "$remove" = 1 ]; then
        rm -f "$p/chrome/kortex-chrome.css" "$p/chrome/kortex-content.css" "$p/chrome/kortex-colors.css"
        drop_import "$p/chrome/userChrome.css"
        drop_import "$p/chrome/userContent.css"
        if [ -f "$p/user.js" ] && grep -qF '// kortex' "$p/user.js"; then
            sed -i '\|// kortex|d' "$p/user.js"
            grep -q '[^[:space:]]' "$p/user.js" || rm -f "$p/user.js"
        fi
        rmdir "$p/chrome" 2>/dev/null || true
        echo "Removido do perfil: $p"
        continue
    fi
    mkdir -p "$p/chrome"
    cp -f "$src/kortex-chrome.css" "$src/kortex-content.css" "$p/chrome/"
    add_import "$p/chrome/userChrome.css" kortex-chrome.css
    add_import "$p/chrome/userContent.css" kortex-content.css
    if [ -f "$p/user.js" ] && grep -q 'legacyUserProfileCustomizations.stylesheets' "$p/user.js"; then
        grep -q 'legacyUserProfileCustomizations.stylesheets", *true' "$p/user.js" \
            || echo "Aviso: o user.js de $p desliga toolkit.legacyUserProfileCustomizations.stylesheets; o Kortex não muda isso." >&2
    else
        backup "$p/user.js"
        printf '%s // kortex\n' "$pref" >> "$p/user.js"
    fi
    bash "$here/firefox-theme.sh" "$p"
    echo "Configurado: $p"
done

if pgrep -x firefox >/dev/null 2>&1 || pgrep -f '/firefox/firefox' >/dev/null 2>&1; then
    echo "O Firefox está aberto: feche-o e abra de novo para aplicar (não o fechei)."
else
    echo "As cores valem na próxima vez que o Firefox abrir."
fi
exit 0
