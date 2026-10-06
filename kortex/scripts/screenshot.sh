#!/usr/bin/env bash
# Captura de tela do Kortex (services/Screenshot.qml). A captura vai primeiro para um arquivo
# temporário em PNG; a janela de salvar escolhe depois o nome, a pasta e o formato.
#
#   screenshot.sh capture <screen|window|area> <monitor> <arquivo.png> [acento] [fundo]
#       screen = o monitor inteiro; window = clique numa janela; area = arraste um retângulo.
#       Saída: "largura altura" (pixels). Código 1 = cancelado (Esc no slurp), 2 = erro.
#   screenshot.sh save <arquivo.png> <destino> <png|jpeg> [force]
#       Grava o destino (PNG copiado, JPEG com o cjpeg, qualidade 90) e cria a pasta se faltar.
#       Código 3 = o destino já existe (sem "force"), 2 = erro (uma linha em stderr).
#   screenshot.sh dirs
#       Pastas de atalho, uma por linha: "rótulo<TAB>caminho" (Capturas e Pasta Pessoal sempre; as outras se existirem).
set -u
cmd="${1:-}"

hexa() {   # #rrggbb + alfa (00–ff) → #rrggbbaa, no formato do slurp
    [[ "$1" =~ ^#[0-9a-fA-F]{6}$ ]] && printf '%s%s' "$1" "$2" || printf '%s' "$3"
}

# grim sem o cursor. Com o cursor desenhado por software (o "auto" do Hyprland faz isso em várias
# máquinas, por exemplo com placa NVIDIA), o Hyprland pinta o cursor no próprio quadro e o grim o
# captura mesmo sem -c. Durante a captura o cursor passa para o plano de hardware, que fica fora da
# imagem; um passo de 1 px (e a volta) faz o Hyprland trocar na hora. Depois tudo volta como era.
hw_orig=""; hw_x=""; hw_y=""
hw_restore() {
    [ -n "$hw_orig" ] || return 0
    hyprctl --batch "keyword cursor:no_hardware_cursors $hw_orig ; dispatch movecursor $hw_nx $hw_y ; dispatch movecursor $hw_x $hw_y" >/dev/null 2>&1
    hw_orig=""
}
grab() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null && command -v jq >/dev/null; then
        local orig pos
        orig="$(hyprctl -j getoption cursor:no_hardware_cursors 2>/dev/null | jq -r '.int // empty' 2>/dev/null)"
        pos="$(hyprctl -j cursorpos 2>/dev/null | jq -r '"\(.x) \(.y)"' 2>/dev/null)"
        if [[ "$orig" =~ ^[0-9]+$ ]] && [ "$orig" != 0 ] && [[ "$pos" =~ ^-?[0-9]+\ -?[0-9]+$ ]]; then
            hw_x="${pos% *}"; hw_y="${pos#* }"
            hw_nx=$(( hw_x > 0 ? hw_x - 1 : hw_x + 1 ))
            hw_orig="$orig"
            trap hw_restore EXIT
            hyprctl --batch "keyword cursor:no_hardware_cursors 0 ; dispatch movecursor $hw_nx $hw_y ; dispatch movecursor $hw_x $hw_y" >/dev/null 2>&1
            sleep 0.1
        fi
    fi
    grim "$@"
    local rc=$?
    hw_restore
    return $rc
}

user_dir() {   # pasta do xdg-user-dirs (ou o padrão em inglês)
    local key="$1" fallback="$2" line val
    line="$(grep -E "^XDG_${key}_DIR=" "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs" 2>/dev/null | tail -n1)"
    val="${line#*=}"; val="${val//\"/}"; val="${val//\$HOME/$HOME}"
    [ -n "$val" ] && [ "$val" != "$HOME/" ] && printf '%s' "$val" || printf '%s' "$HOME/$fallback"
}

case "$cmd" in
capture)
    mode="${2:-}"; monitor="${3:-}"; out="${4:-}"
    accent="${5:-}"; bg="${6:-}"
    [ -n "$out" ] || { echo "Uso: screenshot.sh capture <modo> <monitor> <arquivo>" >&2; exit 2; }
    command -v grim >/dev/null || { echo "O grim não está instalado." >&2; exit 2; }
    mkdir -p "$(dirname "$out")"
    # Cores do slurp: fundo do tema esmaecendo a tela, contorno no acento
    sl=(-b "$(hexa "$bg" 66 '#00000066')" -c "$(hexa "$accent" ff '#ffffffff')"
        -s "$(hexa "$accent" 22 '#ffffff22')" -B "$(hexa "$accent" 18 '#ffffff18')" -w 2)

    case "$mode" in
    screen)
        if [ -n "$monitor" ]; then grab -o "$monitor" "$out"; else grab "$out"; fi || exit 2 ;;
    window)
        command -v slurp >/dev/null || { echo "O slurp não está instalado." >&2; exit 2; }
        # Janelas visíveis (áreas de trabalho em exibição em cada monitor), da usada por último para
        # a mais antiga, para a de cima ganhar onde elas se sobrepõem
        boxes="$(hyprctl -j monitors 2>/dev/null | jq -r '[.[] | .activeWorkspace.id, .specialWorkspace.id] | map(select(. != 0)) | @json' 2>/dev/null)"
        [ -n "$boxes" ] || { echo "Não foi possível ler as janelas do Hyprland." >&2; exit 2; }
        rects="$(hyprctl -j clients 2>/dev/null | jq -r --argjson ws "$boxes" '
            [.[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $ws | index($w)))]
            | sort_by(.focusHistoryID) | .[]
            | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        [ -n "$rects" ] || { echo "Nenhuma janela aberta." >&2; exit 2; }
        geom="$(printf '%s\n' "$rects" | slurp -r "${sl[@]}")" || exit 1
        [ -n "$geom" ] || exit 1
        sleep 0.1   # um quadro sem a marcação do slurp (o HyprSync também tira a animação de saída dela)
        grab -g "$geom" "$out" || exit 2 ;;
    area)
        command -v slurp >/dev/null || { echo "O slurp não está instalado." >&2; exit 2; }
        # </dev/null: sem entrada fechada o slurp espera retângulos nela e nunca aparece (o shell
        # deixa a entrada do processo aberta)
        geom="$(slurp -d "${sl[@]}" </dev/null)" || exit 1
        [ -n "$geom" ] || exit 1
        sleep 0.1
        grab -g "$geom" "$out" || exit 2 ;;
    *)
        echo "Modo desconhecido: $mode" >&2; exit 2 ;;
    esac

    # Tamanho em pixels, do cabeçalho do PNG (bytes 16–23: largura e altura, big-endian)
    od -An -tu1 -j16 -N8 "$out" 2>/dev/null |
        awk '{ printf "%d %d\n", $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8 }'
    ;;

save)
    src="${2:-}"; dest="${3:-}"; fmt="${4:-png}"; force="${5:-}"
    [ -f "$src" ] || { echo "A captura não existe mais." >&2; exit 2; }
    [ -n "$dest" ] || { echo "Falta o nome do arquivo." >&2; exit 2; }
    if [ -e "$dest" ] && [ "$force" != force ]; then exit 3; fi
    mkdir -p "$(dirname "$dest")" 2>/dev/null || { echo "Não foi possível criar a pasta." >&2; exit 2; }
    [ -w "$(dirname "$dest")" ] || { echo "Sem permissão para gravar nesta pasta." >&2; exit 2; }
    tmp="$(mktemp "$(dirname "$dest")/.kortex-captura.XXXXXX")" || { echo "Não foi possível gravar na pasta." >&2; exit 2; }
    case "$fmt" in
    jpeg)
        command -v cjpeg >/dev/null || { rm -f "$tmp"; echo "O cjpeg (pacote libjpeg-turbo) não está instalado." >&2; exit 2; }
        cjpeg -quality 90 -optimize "$src" > "$tmp" 2>/dev/null || { rm -f "$tmp"; echo "Falha ao converter para JPEG." >&2; exit 2; } ;;
    *)
        cp "$src" "$tmp" || { rm -f "$tmp"; echo "Falha ao gravar o arquivo." >&2; exit 2; } ;;
    esac
    chmod 644 "$tmp"
    mv -f "$tmp" "$dest" || { rm -f "$tmp"; echo "Falha ao gravar o arquivo." >&2; exit 2; }
    ;;

dirs)
    # Capturas: a mesma pasta do atalho antigo do Print e do arch-setup.sh (ao lado de Wallpapers)
    printf 'Capturas\t%s\n' "$HOME/Pictures/Screenshots"
    pics="$(user_dir PICTURES Pictures)"
    [ -d "$pics" ] && printf 'Imagens\t%s\n' "$pics"
    d="$(user_dir DESKTOP Desktop)";   [ -d "$d" ] && printf 'Área de Trabalho\t%s\n' "$d"
    d="$(user_dir DOWNLOAD Downloads)"; [ -d "$d" ] && printf 'Downloads\t%s\n' "$d"
    printf 'Pasta Pessoal\t%s\n' "$HOME"
    ;;

*)
    echo "Uso: screenshot.sh capture|save|dirs …" >&2; exit 2 ;;
esac
exit 0
