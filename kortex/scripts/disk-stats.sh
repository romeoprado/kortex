#!/usr/bin/env bash
# Discos montados para o widget Recursos, um por linha, campos separados por TAB:
#   dispositivo  sistema-de-arquivos  tamanho  usado  disponível  temperatura(°C)  ponto-de-montagem
# Tamanhos em bytes. A temperatura só vem quando o kernel expõe um sensor do disco
# (NVMe, ou SATA com o módulo drivetemp); senão o campo fica vazio.

# Temperatura do disco físico por trás de um dispositivo (partição, disco ou volume LVM/LUKS)
disk_temp() {
    local dev sys h
    dev=$(readlink -f "$1") || return
    sys=/sys/class/block/${dev##*/}
    [ -e "$sys" ] || return
    # dm-crypt/LVM: desce até o primeiro dispositivo de baixo
    while [ -d "$sys/slaves" ] && [ -n "$(ls -A "$sys/slaves" 2>/dev/null)" ]; do
        sys=/sys/class/block/$(ls "$sys/slaves" | head -n1)
    done
    # partição: sobe para o disco que a contém
    if [ -e "$sys/partition" ]; then sys=$(dirname "$(readlink -f "$sys")"); fi
    for h in "$sys"/device/hwmon*/temp1_input "$sys"/device/hwmon/hwmon*/temp1_input; do
        if [ -r "$h" ]; then echo $(( $(cat "$h") / 1000 )); return; fi
    done
}

main() {
    timeout 3 df -B1 --output=source,fstype,size,used,avail,target 2>/dev/null | tail -n +2 |
    while read -r source fs size used avail target; do
        case $source in /dev/*) ;; *) continue ;; esac
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$source" "$fs" "$size" "$used" "$avail" "$(disk_temp "$source")" "$target"
    done
}

# Permite `source disk-stats.sh` para testar as funções
if [ "${BASH_SOURCE[0]}" = "$0" ]; then main; fi
