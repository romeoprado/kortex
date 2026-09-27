#!/usr/bin/env bash
# Dados de CPU e memória para o painel Recursos:
#   cpu=54        temperatura da CPU (°C)
#   ram=48        temperatura da memória (°C)
#   threads=28    threads do processador
# Sensor ausente = valor vazio. Só lê o hwmon do kernel.

# Milésimos de grau -> °C, ou nada se não for número
celsius() {
    local v
    v=$(cat "$1" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && echo $((v / 1000))
}

cpu= ram=
for h in /sys/class/hwmon/hwmon*; do
    case $(cat "$h/name" 2>/dev/null) in
    coretemp | k10temp | zenpower)
        [ -z "$cpu" ] || continue
        # Pacote (Intel) ou Tctl/Tdie (AMD); na falta, o primeiro sensor
        for l in "$h"/temp*_label; do
            case $(cat "$l" 2>/dev/null) in
            "Package id "* | Tctl | Tdie) cpu=$(celsius "${l%_label}_input"); break ;;
            esac
        done
        [ -n "$cpu" ] || cpu=$(celsius "$h/temp1_input")
        ;;
    spd5118 | jc42)
        # Sensor de cada módulo de memória (DDR5 / DDR4): vale o mais quente
        t=$(celsius "$h/temp1_input")
        if [ -n "$t" ] && { [ -z "$ram" ] || [ "$t" -gt "$ram" ]; }; then ram=$t; fi
        ;;
    esac
done

echo "cpu=$cpu"
echo "ram=$ram"
echo "threads=$(nproc 2>/dev/null)"
