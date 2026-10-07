#!/usr/bin/env bash
# Gravação de tela do Kortex (services/ScreenRecord.qml), com o gpu-screen-recorder (codifica na
# placa de vídeo). A gravação vai primeiro para um MKV temporário; a janela de salvar escolhe
# depois o nome, a pasta e o formato.
#
#   screenrecord.sh target <screen|window|area> <monitor> [acento] [fundo]
#       Imprime o alvo: o nome do monitor ou "LxA+X+Y" (janela ou área, escolhidas com o slurp
#       como na captura). Código 1 = cancelado (Esc no slurp), 2 = erro.
#   screenrecord.sh record <alvo> <arquivo.mkv> <sistema 0|1> <microfone 0|1>
#       Grava até receber SIGINT, que finaliza o arquivo. Vídeo H.264 a 60 qps; áudio AAC, com o
#       som do sistema e o microfone misturados numa faixa só. Código 2 = erro.
#   screenrecord.sh info <arquivo> <prévia.png>
#       Imprime "largura altura segundos" e grava um quadro do vídeo como prévia.
#   screenrecord.sh save <arquivo.mkv> <destino> <mp4|mkv> [force]
#       Grava o destino (MP4 = o mesmo vídeo trocado de contêiner, sem recodificar) e cria a pasta
#       se faltar. Código 3 = o destino já existe (sem "force"), 2 = erro (uma linha em stderr).
#   screenrecord.sh dirs
#       Pastas de atalho, uma por linha: "rótulo<TAB>caminho".
set -u
cmd="${1:-}"
here="$(dirname "$(readlink -f "$0")")"

case "$cmd" in
target)
    mode="${2:-}"; monitor="${3:-}"
    case "$mode" in
    screen)
        [ -n "$monitor" ] || { echo "Monitor desconhecido." >&2; exit 2; }
        printf '%s\n' "$monitor" ;;
    window|area)
        geom="$(bash "$here/screenshot.sh" pick "$mode" "${4:-}" "${5:-}")" || exit $?
        # "X,Y LxA" → "LxA+X+Y"
        [[ "$geom" =~ ^(-?[0-9]+),(-?[0-9]+)\ ([0-9]+)x([0-9]+)$ ]] || { echo "Seleção inválida." >&2; exit 2; }
        printf '%sx%s+%s+%s\n' "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" ;;
    *)
        echo "Modo desconhecido: $mode" >&2; exit 2 ;;
    esac
    ;;

record)
    target="${2:-}"; out="${3:-}"; sys="${4:-0}"; mic="${5:-0}"
    [ -n "$target" ] && [ -n "$out" ] || { echo "Uso: screenrecord.sh record <alvo> <arquivo> <sistema> <microfone>" >&2; exit 2; }
    command -v gpu-screen-recorder >/dev/null || { echo "O gpu-screen-recorder não está instalado." >&2; exit 2; }
    mkdir -p "$(dirname "$out")"
    args=(-c mkv -f 60 -k h264 -ac aac -q very_high -o "$out")
    if [[ "$target" =~ ^[0-9]+x[0-9]+\+-?[0-9]+\+-?[0-9]+$ ]]; then
        args+=(-w region -region "$target")
    else
        args+=(-w "$target")
    fi
    audio=""
    [ "$sys" = 1 ] && audio="default_output"
    [ "$mic" = 1 ] && audio="${audio:+$audio|}default_input"
    [ -n "$audio" ] && args+=(-a "$audio")
    # exec: o SIGINT do shell chega direto ao gravador
    exec gpu-screen-recorder "${args[@]}"
    ;;

info)
    src="${2:-}"; thumb="${3:-}"
    [ -s "$src" ] || { echo "A gravação ficou vazia." >&2; exit 2; }
    probe="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height:format=duration \
             -of default=nw=1 "$src" 2>/dev/null)"
    w="$(sed -n 's/^width=//p' <<<"$probe")"; h="$(sed -n 's/^height=//p' <<<"$probe")"
    d="$(sed -n 's/^duration=//p' <<<"$probe")"
    [ -n "$w" ] && [ -n "$h" ] || { echo "A gravação não pôde ser lida." >&2; exit 2; }
    [[ "$d" =~ ^[0-9.]+$ ]] || d=0
    # Prévia: o quadro do meio, até 2 s depois do início (o primeiro pode ser preto)
    at="$(awk -v d="$d" 'BEGIN { t = d / 2; if (t > 2) t = 2; printf "%.2f", t }')"
    [ -n "$thumb" ] && ffmpeg -v error -y -ss "$at" -i "$src" -frames:v 1 "$thumb" 2>/dev/null
    printf '%s %s %s\n' "$w" "$h" "$d"
    ;;

save)
    src="${2:-}"; dest="${3:-}"; fmt="${4:-mp4}"; force="${5:-}"
    [ -f "$src" ] || { echo "A gravação não existe mais." >&2; exit 2; }
    [ -n "$dest" ] || { echo "Falta o nome do arquivo." >&2; exit 2; }
    if [ -e "$dest" ] && [ "$force" != force ]; then exit 3; fi
    mkdir -p "$(dirname "$dest")" 2>/dev/null || { echo "Não foi possível criar a pasta." >&2; exit 2; }
    [ -w "$(dirname "$dest")" ] || { echo "Sem permissão para gravar nesta pasta." >&2; exit 2; }
    tmp="$(mktemp "$(dirname "$dest")/.kortex-gravacao.XXXXXX")" || { echo "Não foi possível gravar na pasta." >&2; exit 2; }
    case "$fmt" in
    mp4)
        ffmpeg -v error -y -i "$src" -map 0 -c copy -movflags +faststart -f mp4 "$tmp" 2>/dev/null ||
            { rm -f "$tmp"; echo "Falha ao converter para MP4." >&2; exit 2; } ;;
    *)
        cp "$src" "$tmp" || { rm -f "$tmp"; echo "Falha ao gravar o arquivo." >&2; exit 2; } ;;
    esac
    chmod 644 "$tmp"
    mv -f "$tmp" "$dest" || { rm -f "$tmp"; echo "Falha ao gravar o arquivo." >&2; exit 2; }
    ;;

dirs)
    exec bash "$here/screenshot.sh" dirs video
    ;;

*)
    echo "Uso: screenrecord.sh target|record|info|save|dirs …" >&2; exit 2 ;;
esac
exit 0
