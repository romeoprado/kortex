#!/usr/bin/env bash
# Processos do usuário para o Gerenciador de Processos (services/Processes.qml):
#   cpu <total>                               jiffies de todas as CPUs desde o boot (1ª linha de /proc/stat)
#   <pid> TAB <ppid> TAB <ticks> TAB <mem_kb> TAB <comm> TAB <linha de comando>
#   ...
#   --clients--
#   <JSON do hyprctl clients>                 janelas abertas (pid → aplicativo)
# Só processos do próprio usuário (os únicos que ele pode encerrar). Só lê /proc, sem
# processos extras por item: tudo com comandos internos do bash.
# Memória = residente menos a compartilhada (statm): a parte que é só do processo. Somar o RSS
# contaria as bibliotecas várias vezes (o Firefox, com 20 processos, quase dobraria).

read -r _ a b c d e f g h _ </proc/stat
echo "cpu $((a + b + c + d + e + f + g + h))"

page_kb=$(($(getconf PAGESIZE) / 1024))

for dir in /proc/[0-9]*; do
    [[ -O $dir ]] || continue
    read -r stat <"$dir/stat" 2>/dev/null || continue
    # O nome (2º campo) vem entre parênteses e pode ter espaços: separa pelo último ")"
    comm=${stat#*(}
    comm=${comm%)*}
    read -r -a f <<<"${stat##*) }"
    # f[0]=estado f[1]=ppid … f[11]=utime f[12]=stime
    [[ ${f[0]} == Z ]] && continue   # zumbi: já terminou, só espera o pai
    read -r _ resident shared _ <"$dir/statm" 2>/dev/null || continue
    mapfile -d '' -t args <"$dir/cmdline" 2>/dev/null
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${dir#/proc/}" "${f[1]}" "$((f[11] + f[12]))" \
        "$(((resident - shared) * page_kb))" "${comm//$'\t'/ }" "${args[*]//$'\t'/ }"
done

echo "--clients--"
hyprctl -j clients 2>/dev/null
