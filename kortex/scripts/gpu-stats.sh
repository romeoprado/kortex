#!/usr/bin/env bash
# Estado das GPUs para o widget Recursos. Uma linha por placa, campos separados por TAB:
#   endereço-pci  fabricante  nome  uso(%)  vram_usada(MiB)  vram_total(MiB)  temp(°C)  potência(W)  freq(MHz)  freq_max(MHz)  estado
# Campo desconhecido = vazio. estado: ok | suspended | unavailable.
#
# Só lê o sysfs e, no caso da NVIDIA, o nvidia-smi, e isso apenas com a placa ativa: consultar
# uma GPU dedicada em repouso a acordaria e gastaria bateria. A Intel (i915/xe) não expõe uso
# sem root, só a frequência.

# Imprime o valor se for número, senão nada
num() { [[ $1 =~ ^[0-9]+([.][0-9]+)?$ ]] && printf '%s' "$1"; }
# Conteúdo do primeiro arquivo legível
first() { local f; for f in "$@"; do [ -r "$f" ] && { cat "$f" 2>/dev/null; return; }; done; }

for card in /sys/class/drm/card*; do
    case ${card##*/} in card[0-9] | card[0-9][0-9]) ;; *) continue ;; esac
    dev=$(readlink -f "$card/device") || continue
    addr=${dev##*/}
    vendor=$(first "$dev/vendor")
    name=$(lspci -mm -s "$addr" 2>/dev/null | awk -F'"' '{print $6}' | sed 's/.*\[\(.*\)\]/\1/')
    util= vu= vt= temp= power= freq= fmax= state=ok
    status=$(first "$dev/power/runtime_status")

    case $vendor in
    0x10de)
        kind=nvidia
        if [ -n "$status" ] && [ "$status" != active ]; then
            state=suspended
        elif command -v nvidia-smi >/dev/null 2>&1; then
            IFS=, read -r u mu mt t p < <(timeout 3 nvidia-smi -i "$addr" \
                --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
                --format=csv,noheader,nounits 2>/dev/null)
            util=$(num "${u// /}"); vu=$(num "${mu// /}"); vt=$(num "${mt// /}")
            temp=$(num "${t// /}"); power=$(num "${p// /}")
            [ -n "$util" ] || state=unavailable
        else
            state=unavailable
        fi
        ;;
    0x1002)
        kind=amd
        if [ -n "$status" ] && [ "$status" != active ]; then
            state=suspended
        else
            util=$(num "$(first "$dev/gpu_busy_percent")")
            vu=$(num "$(first "$dev/mem_info_vram_used")"); [ -n "$vu" ] && vu=$((vu / 1048576))
            vt=$(num "$(first "$dev/mem_info_vram_total")"); [ -n "$vt" ] && vt=$((vt / 1048576))
            for h in "$dev"/hwmon/hwmon*; do
                t=$(num "$(first "$h/temp1_input")"); [ -n "$t" ] && temp=$((t / 1000))
                p=$(num "$(first "$h/power1_average" "$h/power1_input")")
                [ -n "$p" ] && power=$(awk -v p="$p" 'BEGIN { printf "%.1f", p / 1000000 }')
            done
            [ -n "$util" ] || state=unavailable
        fi
        ;;
    0x8086)
        kind=intel
        freq=$(num "$(first "$card/gt_act_freq_mhz" "$dev/tile0/gt0/freq0/act_freq")")
        fmax=$(num "$(first "$card/gt_max_freq_mhz" "$dev/tile0/gt0/freq0/max_freq")")
        ;;
    *)
        kind=other
        state=unavailable
        ;;
    esac

    [ -n "$name" ] || name=$kind
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$addr" "$kind" "$name" "$util" "$vu" "$vt" "$temp" "$power" "$freq" "$fmax" "$state"
done
