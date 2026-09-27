# Funções compartilhadas pelos scripts do Firefox (usar com `source`).

# Pastas onde o Firefox guarda os perfis: instalação comum, caminho XDG (Firefox 147+), Flatpak e Snap
firefox_roots() {
    printf '%s\n' "$HOME/.mozilla/firefox" "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox" \
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" "$HOME/snap/firefox/common/.mozilla/firefox"
}

# Perfil padrão de cada pasta, um por linha (caminho absoluto): o do bloco [Install…] do profiles.ini,
# senão o marcado Default=1, senão o primeiro. Só perfis que existem.
firefox_profiles() {
    local root ini p line path rel def_install="" def_flag="" first="" cur_rel="" cur_path="" cur_default=""
    while IFS= read -r root; do
        ini="$root/profiles.ini"; [ -f "$ini" ] || continue
        def_install=""; def_flag=""; first=""; cur_path=""; cur_rel=1; cur_default=0; local section=""
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%$'\r'}"
            case "$line" in
                \[*\])
                    # fecha o perfil anterior
                    if [ "$section" = profile ] && [ -n "$cur_path" ]; then
                        [ "$cur_rel" = 1 ] && p="$root/$cur_path" || p="$cur_path"
                        [ -z "$first" ] && first="$p"
                        [ "$cur_default" = 1 ] && [ -z "$def_flag" ] && def_flag="$p"
                    fi
                    cur_path=""; cur_rel=1; cur_default=0
                    case "$line" in \[Install*) section=install;; \[Profile*) section=profile;; *) section=other;; esac ;;
                Path=*) [ "$section" = profile ] && cur_path="${line#Path=}" ;;
                IsRelative=*) [ "$section" = profile ] && cur_rel="${line#IsRelative=}" ;;
                Default=1) [ "$section" = profile ] && cur_default=1 ;;
                Default=*) [ "$section" = install ] && [ -z "$def_install" ] && def_install="${line#Default=}" ;;
            esac
        done < "$ini"
        if [ "$section" = profile ] && [ -n "$cur_path" ]; then
            [ "$cur_rel" = 1 ] && p="$root/$cur_path" || p="$cur_path"
            [ -z "$first" ] && first="$p"
            [ "$cur_default" = 1 ] && [ -z "$def_flag" ] && def_flag="$p"
        fi
        if [ -n "$def_install" ]; then
            case "$def_install" in /*) p="$def_install";; *) p="$root/$def_install";; esac
        elif [ -n "$def_flag" ]; then p="$def_flag"
        else p="$first"; fi
        [ -n "$p" ] && [ -d "$p" ] && printf '%s\n' "$p"
    done < <(firefox_roots)
}
