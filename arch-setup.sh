#!/usr/bin/env bash
# =============================================================================
#  Kortex — instalador para uma instalação LIMPA do Arch Linux
#
#  Parte de um Arch com: sistema base, um usuário comum com sudo e internet.
#  Instala Hyprland, Quickshell, drivers de vídeo, áudio, rede, Bluetooth,
#  fontes, utilitários, Firefox, Nautilus, o Kortex e uma configuração inicial do Hyprland.
#
#  Uso (como usuário comum, NÃO como root, na pasta extraída do pacote):
#     ./arch-setup.sh                 # interativo
#     ./arch-setup.sh --yes           # sem perguntas
#
#  Opções:
#     -y, --yes              Não pergunta nada (aceita os padrões)
#     --login MODO           sddm (padrão, tela de login gráfica com as cores do tema)
#                            | tty (Hyprland inicia ao entrar no tty1) | none (não mexe)
#     --terminal NOME        kitty (padrão; as cores seguem o tema do Kortex) | alacritty | ghostty | foot
#     --no-drivers           Não instala drivers de vídeo
#     --no-hypr-config       Não mexe em ~/.config/hypr
#     --quickshell-git       Usa quickshell-git do AUR em vez do pacote oficial
#     --extras LISTA         Instala adicionais sem perguntar: yay, disks, calculator, editor, hyprmod,
#                            tailscale (separados por vírgula) | todos | nenhum
#     -h, --help             Mostra esta ajuda
# =============================================================================
set -Eeuo pipefail

# ----------------------------------------------------------------- opções ----
ASSUME_YES=0
LOGIN_MODE="sddm"
LOGIN_EXPLICIT=0
TERMINAL_APP=""
INSTALL_DRIVERS=1
WRITE_HYPR=1
QS_GIT=0
EXTRAS_ARG=""; EXTRAS_SET=0

# Programas adicionais oferecidos (nome | pacote | descrição). Nenhum vem marcado.
EXTRAS=(
    "yay|yay-bin|yay: instala pacotes do AUR (o HyprMod e os ícones Yaru vêm de lá)"
    "disks|gnome-disk-utility|Discos (GNOME): particiona, formata e mostra a saúde dos discos"
    "calculator|gnome-calculator|Calculadora (GNOME)"
    "editor|gnome-text-editor|Editor de Texto (GNOME)"
    "hyprmod|hyprmod|HyprMod: configura o Hyprland numa janela (vem do AUR)"
    "tailscale|tailscale|Tailscale: VPN em malha entre os seus dispositivos"
)
extra_valid() { local e; for e in "${EXTRAS[@]}"; do [ "${e%%|*}" = "$1" ] && return 0; done; return 1; }

usage() { sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)          ASSUME_YES=1 ;;
        --login)           LOGIN_MODE="${2:-}"; LOGIN_EXPLICIT=1; shift ;;
        --terminal)        TERMINAL_APP="${2:-}"; shift ;;
        --no-drivers)      INSTALL_DRIVERS=0 ;;
        --no-hypr-config)  WRITE_HYPR=0 ;;
        --quickshell-git)  QS_GIT=1 ;;
        --extras)          EXTRAS_ARG="${2:-}"; EXTRAS_SET=1; shift ;;
        -h|--help)         usage ;;
        *) echo "Opção desconhecida: $1 (use --help)"; exit 1 ;;
    esac
    shift
done

case "$LOGIN_MODE" in tty|sddm|none) ;; *) echo "--login deve ser tty, sddm ou none"; exit 1 ;; esac
case "${TERMINAL_APP:-kitty}" in kitty|alacritty|ghostty|foot) ;; *) echo "--terminal deve ser alacritty, ghostty, kitty ou foot"; exit 1 ;; esac
case "$EXTRAS_ARG" in
    ""|todos|all|nenhum|none) ;;
    *) IFS=, read -ra _list <<<"$EXTRAS_ARG"
       for _n in "${_list[@]}"; do
           extra_valid "$_n" || { echo "--extras: '$_n' desconhecido. Use: yay, disks, calculator, editor, hyprmod, tailscale, todos ou nenhum"; exit 1; }
       done ;;
esac

# ------------------------------------------------------------ utilitários ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HOME/kortex-setup.log"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [ -t 1 ]; then
    C_B=$'\e[1m'; C_A=$'\e[34m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_0=$'\e[0m'
else
    C_B=""; C_A=""; C_G=""; C_Y=""; C_R=""; C_0=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$C_A" "$C_0" "$C_B" "$*" "$C_0"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '    %s!%s %s\n' "$C_Y" "$C_0" "$*"; WARNINGS+=("$*"); }
die()  { printf '\n%sErro:%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }
WARNINGS=()

confirm() {   # confirm "Pergunta" [padrão s|n]
    local def="${2:-s}" ans
    [ "$ASSUME_YES" = 1 ] && [ "$def" = s ] && return 0
    [ "$ASSUME_YES" = 1 ] && return 1
    if [ "$def" = s ]; then read -rp "    $1 [S/n] " ans; ans="${ans:-s}"
    else                    read -rp "    $1 [s/N] " ans; ans="${ans:-n}"; fi
    [[ "$ans" =~ ^[sSyY] ]]
}

backup() {    # guarda uma cópia antes de sobrescrever
    [ -e "$1" ] || return 0
    cp -a "$1" "$1.bak-$STAMP"
    info "backup: $1.bak-$STAMP"
}

# Layouts de teclado: só entra no hyprland.conf o que o XKB (xkeyboard-config) conhece; um código
# inválido faz o Hyprland cair no layout "us" já no primeiro boot. Confere nos arquivos symbols/,
# que são o que o XKB carrega de fato (o evdev.lst não lista variantes como br(abnt2)).
kb_known() {    # kb_known layout [variante]
    [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]] || return 1
    [[ -z "${2:-}" || "$2" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
    local d dir=""
    for d in /usr/share/xkeyboard-config-2 /usr/share/X11/xkb; do
        if [ -d "$d/symbols" ]; then dir="$d"; break; fi
    done
    [ -n "$dir" ] || return 0    # xkeyboard-config ainda não instalado: só a forma do código
    [ -f "$dir/symbols/$1" ] || return 1
    [ -z "${2:-}" ] || grep -qF "xkb_symbols \"$2\"" "$dir/symbols/$1"
}

kb_sanitize() {    # limpa KB_LAYOUT/KB_VARIANT (listas separadas por vírgula, no máximo 4 layouts)
    local -a L=() V=() out_l=() out_v=()
    local i l v
    IFS=, read -ra L <<< "$KB_LAYOUT"
    IFS=, read -ra V <<< "$KB_VARIANT"
    for i in "${!L[@]}"; do
        l="${L[$i]}"; v="${V[$i]:-}"
        [ -n "$l" ] || continue
        if ! kb_known "$l"; then warn "Layout de teclado desconhecido, ignorado: '$l'"; continue; fi
        if [ -n "$v" ] && ! kb_known "$l" "$v"; then warn "Variante de teclado desconhecida, ignorada: $l($v)"; v=""; fi
        out_l+=("$l"); out_v+=("$v")
        [ "${#out_l[@]}" -ge 4 ] && break
    done
    if [ "${#out_l[@]}" -eq 0 ]; then out_l=(us); out_v=(""); fi
    KB_LAYOUT="$(IFS=,; echo "${out_l[*]}")"
    KB_VARIANT="$(IFS=,; echo "${out_v[*]}")"
    if [[ "$KB_VARIANT" =~ ^,*$ ]]; then KB_VARIANT=""; fi
}

on_error() {
    printf '\n%sFalhou na linha %s:%s %s\n' "$C_R" "$1" "$C_0" "$2" >&2
    printf 'Veja o log completo em %s\n' "$LOG" >&2
    printf 'O script pode ser executado de novo com segurança: o que já foi feito é pulado.\n' >&2
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

PAC=(sudo pacman --needed)
if [ "$ASSUME_YES" = 1 ]; then PAC+=(--noconfirm); fi

# Tudo que aparece na tela também vai para o log
exec > >(tee -a "$LOG") 2>&1
echo "===== Kortex setup — $(date) =====" >> "$LOG"

printf '%s%s\n' "$C_A" "$C_B"
cat <<'BANNER'
   _  __          _
  | |/ /___  _ __| |_ _____  __
  | ' // _ \| '__| __/ _ \ \/ /
  | . \ (_) | |  | ||  __/>  <
  |_|\_\___/|_|   \__\___/_/\_\
BANNER
printf '%s\n  Instalador para Arch Linux + Hyprland\n  Desenvolvido por R. Prado\n' "$C_0"

# ---------------------------------------------------------- verificações ----
step "Verificando o sistema"

[ "$EUID" -ne 0 ] || die "Não rode como root. Crie um usuário comum com sudo:
      useradd -m -G wheel -s /bin/bash seu_nome && passwd seu_nome
      EDITOR=nano visudo   # descomente a linha %wheel ALL=(ALL:ALL) ALL
  Depois entre com esse usuário e rode o script de novo."

[ -f /etc/arch-release ] || die "Este script é só para Arch Linux."
[ "$(uname -m)" = x86_64 ] || warn "Arquitetura $(uname -m) não testada; alguns pacotes podem não existir."
command -v sudo >/dev/null || die "sudo não está instalado. Como root: pacman -S sudo"
[ -d "$SCRIPT_DIR/kortex" ] || die "Pasta 'kortex/' não encontrada ao lado deste script. Extraia o pacote completo."

if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
    warn "Você está dentro de uma sessão gráfica. Funciona, mas o ideal é rodar num TTY."
fi

info "Pedindo a senha do sudo (ela é mantida ativa durante a instalação)…"
sudo -v || die "Seu usuário não tem permissão de sudo."
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null || true' EXIT

curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
    || die "Sem acesso à internet. Conecte-se primeiro (ex.: iwctl ou nmtui) e tente de novo."
ok "Arch Linux, usuário $USER, internet ok"

# ----------------------------------------------------- detecção de hardware --
step "Detectando hardware"

VIRT="$(systemd-detect-virt 2>/dev/null || true)"
[ "$VIRT" = none ] && VIRT=""

# GPUs pelo ID do fabricante em /sys (não depende de pacotes extras)
HAS_INTEL=0; HAS_AMD=0; HAS_NVIDIA=0
for v in /sys/class/drm/card*/device/vendor; do
    [ -r "$v" ] || continue
    case "$(cat "$v")" in
        0x8086) HAS_INTEL=1 ;;
        0x1002) HAS_AMD=1 ;;
        0x10de) HAS_NVIDIA=1 ;;
    esac
done
if [ "$HAS_INTEL" = 1 ]; then info "GPU: Intel"; fi
if [ "$HAS_AMD" = 1 ]; then info "GPU: AMD"; fi
if [ "$HAS_NVIDIA" = 1 ]; then info "GPU: NVIDIA"; fi
if [ "$HAS_INTEL$HAS_AMD$HAS_NVIDIA" = 000 ]; then info "GPU: não identificada (usando só mesa)"; fi

if [ -n "$VIRT" ]; then
    info "Máquina virtual detectada: $VIRT"
    if [ -z "$TERMINAL_APP" ]; then TERMINAL_APP="foot"; fi   # o kitty exige OpenGL; o foot funciona sem aceleração 3D
fi
TERMINAL_APP="${TERMINAL_APP:-kitty}"

# Kernels instalados → headers correspondentes (para módulos DKMS da NVIDIA)
KERNELS=()
for k in linux linux-lts linux-zen linux-hardened; do
    if pacman -Q "$k" &>/dev/null; then KERNELS+=("$k"); fi
done
info "Kernel(s): ${KERNELS[*]:-desconhecido}"

# Layout do teclado: X11 do localectl, senão o KEYMAP do console
# (sem X11 configurado o localectl escreve "(unset)" ou "n/a", que não é um layout)
KB_LAYOUT="$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/{print $2}' | tr -d ' ' || true)"
KB_VARIANT="$(localectl status 2>/dev/null | awk -F': *' '/X11 Variant/{print $2}' | tr -d ' ' || true)"
case "$KB_LAYOUT" in "(unset)"|"n/a") KB_LAYOUT=""; KB_VARIANT="" ;; esac
if [ -z "$KB_LAYOUT" ] && [ -f /etc/vconsole.conf ]; then
    km="$(sed -n 's/^KEYMAP=//p' /etc/vconsole.conf | tr -d '"')"
    case "$km" in
        br-abnt2|br-abnt|br*) KB_LAYOUT="br" ;;
        us-acentos)           KB_LAYOUT="us"; KB_VARIANT="intl" ;;
        pt-latin1|pt*)        KB_LAYOUT="pt" ;;
        uk)                   KB_LAYOUT="gb" ;;    # no console "uk" é o inglês britânico; no XKB é o ucraniano
        "")                   ;;
        *)                    KB_LAYOUT="${km%%-*}" ;;
    esac
fi
KB_LAYOUT="${KB_LAYOUT:-us}"
kb_sanitize
info "Teclado: $KB_LAYOUT${KB_VARIANT:+ ($KB_VARIANT)}"

# ------------------------------------------------------ lista de pacotes -----
PKGS=(
    # Base e compilação (necessário para o AUR)
    base-devel git curl wget unzip jq

    # Hyprland e ecossistema
    hyprland hyprlock hypridle hyprsunset hyprpolkitagent
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    xdg-utils xdg-user-dirs qt5-wayland qt6-wayland

    # Quickshell e módulos Qt usados pelo Kortex
    qt6-declarative qt6-svg qt6-imageformats qt6-5compat

    # Fontes
    ttf-jetbrains-mono-nerd ttc-iosevka noto-fonts noto-fonts-emoji

    # Cores do tema geradas do papel de parede (tema "Matugen")
    matugen

    # Áudio
    pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol playerctl

    # Rede e Bluetooth
    networkmanager nm-connection-editor bluez bluez-utils

    # Tela, capturas, área de transferência
    brightnessctl grim slurp wl-clipboard

    # Aplicativos básicos
    "$TERMINAL_APP" nautilus gvfs firefox btop pciutils

    # Ícones dos apps: o icons.theme de cada tema do Kortex escolhe uma variante do Yaru (vem do AUR)
    yaru-icon-theme
    polkit gnome-keyring
)

if [ "$QS_GIT" = 1 ]; then AUR_WANT=(quickshell-git); else PKGS+=(quickshell); AUR_WANT=(); fi

# Pulseaudio conflita com pipewire-pulse
if pacman -Q pulseaudio &>/dev/null; then
    warn "pulseaudio está instalado e será substituído por pipewire-pulse (o pacman vai perguntar)."
fi

# Modos de energia do widget Energia (Economia, Equilibrado, Desempenho). O power-profiles-daemon
# conflita com o TLP e o tuned: se um deles já cuida da energia, ele fica de fora.
PPD_CONFLICT=""
for _p in tlp tuned tuned-ppd auto-cpufreq; do
    if pacman -Q "$_p" &>/dev/null; then PPD_CONFLICT="$_p"; break; fi
done
if [ -z "$PPD_CONFLICT" ]; then
    PKGS+=(power-profiles-daemon)
elif [ "$PPD_CONFLICT" = tuned-ppd ]; then
    info "tuned-ppd instalado: ele atende os modos do widget Energia no lugar do power-profiles-daemon."
else
    warn "$PPD_CONFLICT instalado: o power-profiles-daemon fica de fora e o widget Energia não troca o modo de energia."
fi

if [ "$INSTALL_DRIVERS" = 1 ]; then
    PKGS+=(mesa)
    if [ "$HAS_INTEL" = 1 ]; then PKGS+=(vulkan-intel intel-media-driver); fi
    if [ "$HAS_AMD" = 1 ]; then PKGS+=(vulkan-radeon); fi
    if [ "$HAS_NVIDIA" = 1 ] && [ -z "$VIRT" ]; then
        PKGS+=(nvidia-open-dkms nvidia-utils libva-nvidia-driver egl-wayland)
        for k in "${KERNELS[@]}"; do PKGS+=("$k-headers"); done
        warn "NVIDIA: instalando o driver 'nvidia-open'. Ele exige GPU Turing (GTX 16xx/RTX 20xx) ou mais nova.
      Para placas mais antigas, remova-o depois e siga https://wiki.archlinux.org/title/NVIDIA"
    fi
fi

# O padrão (sddm) não substitui um gerenciador de login que já esteja ativo; só com --login sddm explícito.
if [ "$LOGIN_MODE" = sddm ] && [ "$LOGIN_EXPLICIT" = 0 ] && systemctl is-enabled display-manager.service &>/dev/null; then
    dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    if [ "$dm" != sddm ]; then
        info "Gerenciador de login já ativo ($dm): mantido. Para trocar pelo SDDM, use --login sddm."
        LOGIN_MODE=none
    fi
fi

if [ "$LOGIN_MODE" = sddm ]; then PKGS+=(sddm); fi

# ------------------------------------------------ programas adicionais ----
# >>> extras
declare -F have >/dev/null || have() { command -v "$1" >/dev/null 2>&1; }
CHOSEN=()
add_chosen() { local n; for n in "${CHOSEN[@]}"; do [ "$n" = "$1" ] && return 0; done; CHOSEN+=("$1"); }

if [ "$EXTRAS_SET" = 1 ]; then
    # --extras: sem perguntas
    case "$EXTRAS_ARG" in
        todos|all) for e in "${EXTRAS[@]}"; do add_chosen "${e%%|*}"; done ;;
        ""|nenhum|none) ;;
        *) IFS=, read -ra _list <<<"$EXTRAS_ARG"; for n in "${_list[@]}"; do add_chosen "$n"; done ;;
    esac
elif [ "$ASSUME_YES" != 1 ]; then
    step "Programas adicionais (opcionais)"
    i=1
    for e in "${EXTRAS[@]}"; do
        IFS='|' read -r _n _p _d <<<"$e"
        printf '    %d) %s\n' "$i" "$_d"
        i=$((i + 1))
    done
    read -rp "    Números separados por espaço, 'todos' ou Enter para nenhum: " sel
    for tok in $sel; do
        if [[ "$tok" =~ ^(todos|all)$ ]]; then
            for e in "${EXTRAS[@]}"; do add_chosen "${e%%|*}"; done
        elif [[ "$tok" =~ ^[0-9]+$ ]] && [ "$tok" -ge 1 ] && [ "$tok" -le "${#EXTRAS[@]}" ]; then
            e="${EXTRAS[$((tok - 1))]}"; add_chosen "${e%%|*}"
        else
            warn "Adicional ignorado (não reconhecido): $tok"
        fi
    done
fi

# nome → pacote. O yay não entra se já houver um ajudante do AUR (o yay-bin conflitaria com o yay).
for n in "${CHOSEN[@]}"; do
    for e in "${EXTRAS[@]}"; do
        IFS='|' read -r _n _p _d <<<"$e"
        [ "$_n" = "$n" ] || continue
        if [ "$n" = yay ] && { have yay || have paru; }; then
            info "Ajudante do AUR já instalado: o yay não será instalado de novo."
            continue
        fi
        PKGS+=("$_p")
    done
done
if [[ " ${CHOSEN[*]} " == *" hyprmod "* ]] && ! have yay && ! have paru && [[ " ${CHOSEN[*]} " != *" yay "* ]]; then
    info "O HyprMod vem do AUR: o yay será instalado junto."
fi
# <<< extras

# ---------------------------------------------------------------- resumo -----
step "Resumo"
info "Terminal:         $TERMINAL_APP"
info "Início da sessão: $(case "$LOGIN_MODE" in sddm) echo "tela de login SDDM (tema Kortex)";; tty) echo "automático no tty1";; *) echo "não mexer";; esac)"
info "Drivers de vídeo: $([ "$INSTALL_DRIVERS" = 1 ] && echo sim || echo não)"
info "Config Hyprland:  $([ "$WRITE_HYPR" = 1 ] && echo "escrever (com backup)" || echo "não mexer")"
info "Quickshell:       $([ "$QS_GIT" = 1 ] && echo "quickshell-git (AUR)" || echo "quickshell (oficial)")"
info "Adicionais:       ${CHOSEN[*]:-nenhum}"
info "Log:              $LOG"
confirm "Continuar?" s || { echo "Cancelado."; exit 0; }

# -------------------------------------------------------- atualização base ---
step "Atualizando o sistema"
"${PAC[@]}" -Sy --noconfirm archlinux-keyring
"${PAC[@]}" -Su
ok "Sistema atualizado"

# ---------------------------------------------- pacotes oficiais vs. AUR -----
step "Instalando pacotes dos repositórios oficiais"
REPO_PKGS=(); AUR_PKGS=("${AUR_WANT[@]}")
for p in "${PKGS[@]}"; do
    # -Sp também resolve pacotes "virtuais" (fornecidos por outro pacote)
    if pacman -Sp --print-format %n "$p" &>/dev/null; then
        REPO_PKGS+=("$p")
    else
        AUR_PKGS+=("$p")      # não está nos repositórios → tenta o AUR
    fi
done
"${PAC[@]}" -S "${REPO_PKGS[@]}"
ok "${#REPO_PKGS[@]} pacotes verificados/instalados"

# ------------------------------------------------------------------- AUR -----
if [ "${#AUR_PKGS[@]}" -gt 0 ]; then
    step "Instalando do AUR: ${AUR_PKGS[*]}"
    AUR_HELPER=""
    for h in yay paru; do command -v "$h" >/dev/null && { AUR_HELPER="$h"; break; }; done
    if [ -z "$AUR_HELPER" ]; then
        info "Instalando o yay…"
        tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
        rm -rf "$tmp"
        AUR_HELPER=yay
    fi
    AUR_FLAGS=(--needed)
    if [ "$ASSUME_YES" = 1 ]; then AUR_FLAGS+=(--noconfirm --answerdiff None --answerclean None --removemake); fi
    "$AUR_HELPER" -S "${AUR_FLAGS[@]}" "${AUR_PKGS[@]}"
    ok "Pacotes do AUR instalados"
fi

command -v qs >/dev/null || die "O Quickshell (qs) não foi instalado."
ok "Quickshell $(qs --version 2>/dev/null | head -1 || echo instalado)"

# --------------------------------------------------------------- serviços ----
step "Configurando serviços"

# Só um gerenciador de rede pode ficar ativo. Se outro estiver em uso agora,
# trocamos apenas na próxima inicialização para não derrubar a conexão.
OTHER_NET=()
for svc in systemd-networkd iwd dhcpcd; do
    if systemctl is-enabled "$svc" &>/dev/null; then OTHER_NET+=("$svc"); fi
done
if [ "${#OTHER_NET[@]}" -gt 0 ]; then
    sudo systemctl disable "${OTHER_NET[@]}" 2>/dev/null || true
    sudo systemctl enable NetworkManager
    warn "Desativados para o próximo boot: ${OTHER_NET[*]}. O NetworkManager assume após reiniciar."
else
    sudo systemctl enable --now NetworkManager
fi
ok "NetworkManager"

sudo systemctl enable --now bluetooth && ok "Bluetooth"
if pacman -Q power-profiles-daemon &>/dev/null; then
    sudo systemctl enable --now power-profiles-daemon && ok "Modos de energia (power-profiles-daemon)"
fi
if [[ " ${CHOSEN[*]} " == *" tailscale "* ]]; then
    sudo systemctl enable --now tailscaled && ok "Tailscale (serviço tailscaled)"
fi
systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service &>/dev/null || true
ok "PipeWire (sessão do usuário)"

for g in video input; do
    if ! id -nG "$USER" | grep -qw "$g"; then sudo usermod -aG "$g" "$USER"; fi
done
ok "Usuário nos grupos video e input"

xdg-user-dirs-update || true
mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"

# ------------------------------------------------------------ Kortex -----
step "Instalando o Kortex"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/kortex"
if [ -d "$DEST" ]; then
    mv "$DEST" "$DEST.bak-$STAMP"
    info "versão anterior movida para $DEST.bak-$STAMP"
fi
mkdir -p "$(dirname "$DEST")"
cp -r "$SCRIPT_DIR/kortex" "$DEST"
chmod +x "$DEST"/scripts/*.sh

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
mkdir -p "$STATE"
touch "$STATE/hyprland-colors.conf"
# Resolução/taxa/escala confirmadas no widget de tela (o hyprland.conf carrega este arquivo).
# Não sobrescreve: numa reinstalação, a configuração de tela do usuário é preservada.
[ -f "$STATE/monitors.conf" ] || printf '# Gerado pelo Kortex (widget de tela). Carregado pelo Hyprland.\n' > "$STATE/monitors.conf"
# Desfoque do terminal (Configurações › Aparência): o shell reescreve este arquivo; vazio = desfoque ligado
[ -f "$STATE/hyprland-terminal.conf" ] || printf '# Gerado pelo Kortex (Configurações). Carregado pelo Hyprland.\n' > "$STATE/hyprland-terminal.conf"

# Terminal escolhido vira o padrão do Kortex (só se ainda não há configurações)
if [ ! -f "$STATE/settings.json" ]; then
    printf '{\n    "terminal": "%s"\n}\n' "$TERMINAL_APP" > "$STATE/settings.json"
fi

# Aplicativos padrão iniciais (Configurações › Aplicativos os troca depois). Só na primeira instalação:
# o terminal escolhido, o Nautilus para pastas (senão programas como o kitty ficam com o padrão do
# sistema para pastas: o kitty-open abre uma pasta num terminal) e o Firefox para links.
if [ ! -f "$STATE/apps.sh" ]; then
    bash "$DEST/scripts/apps-apply.sh" terminal "$TERMINAL_APP" "$TERMINAL_APP" || true
    command -v nautilus >/dev/null && bash "$DEST/scripts/apps-apply.sh" files org.gnome.Nautilus nautilus || true
    command -v firefox >/dev/null && bash "$DEST/scripts/apps-apply.sh" browser firefox firefox || true
fi

# Kitty: configuração inicial e a linha que inclui as cores do tema ativo. O shell reescreve o
# kitty-theme.conf a cada troca de tema e recarrega os Kitty abertos (scripts/kitty-theme.sh).
if [ "$TERMINAL_APP" = kitty ]; then
    KITTY_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
    mkdir -p "$(dirname "$KITTY_CONF")"
    if [ ! -f "$KITTY_CONF" ]; then
        cat > "$KITTY_CONF" <<CONF
# Kitty — configuração inicial do Kortex
font_family             JetBrainsMono Nerd Font
font_size               11.0
window_padding_width    8
confirm_os_window_close 0

# Cores do tema ativo do Kortex (reescritas a cada troca de tema). Deixe esta linha por último.
include $STATE/kitty-theme.conf
CONF
        ok "kitty.conf (as cores seguem o tema do Kortex)"
    elif ! grep -q "kitty-theme.conf" "$KITTY_CONF"; then
        backup "$KITTY_CONF"
        printf '\n# Cores do tema ativo do Kortex (reescritas a cada troca de tema). Deixe esta linha por último.\ninclude %s/kitty-theme.conf\n' "$STATE" >> "$KITTY_CONF"
        ok "kitty.conf: linha das cores do tema adicionada (backup feito)"
    fi
fi
# Firefox: se já existe um perfil, liga as cores do tema (interface e páginas internas). O Firefox só
# lê isso ao abrir; num Arch limpo o perfil só nasce na primeira abertura, e então basta rodar o script.
if command -v firefox >/dev/null; then
    bash "$DEST/scripts/firefox-setup.sh" || true
fi
# Apps GNOME (GTK4/libadwaita: Nautilus, Calculadora, Editor de Texto…): cores do tema, claro/escuro e
# esquema do editor. Só se algum deles existir; o gsettings precisa de sessão gráfica, então numa instalação
# pelo tty a escolha claro/escuro fica para a primeira troca de tema.
if command -v nautilus >/dev/null || command -v gnome-calculator >/dev/null || command -v gnome-text-editor >/dev/null; then
    bash "$DEST/scripts/gnome-setup.sh" || true
fi
ok "Instalado em $DEST"

# ------------------------------------------------------ config do Hyprland ---
if [ "$WRITE_HYPR" = 1 ]; then
    step "Escrevendo a configuração do Hyprland"
    HYPR="$HOME/.config/hypr"
    mkdir -p "$HYPR"

    # hyprland.conf
    if [ -f "$HYPR/hyprland.conf" ] && ! grep -q "Kortex" "$HYPR/hyprland.conf"; then
        backup "$HYPR/hyprland.conf"
    fi

    NVIDIA_ENV=""
    if [ "$HAS_NVIDIA" = 1 ] && [ -z "$VIRT" ] && [ "$INSTALL_DRIVERS" = 1 ]; then
        NVIDIA_ENV="
# NVIDIA
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct"
    fi
    VM_ENV=""
    if [ -n "$VIRT" ]; then
        VM_ENV="
# Máquina virtual: cursor por software
cursor {
    no_hardware_cursors = 1
}"
    fi

    kb_sanitize    # de novo: agora o catálogo do xkeyboard-config já está instalado

    cat > "$HYPR/hyprland.conf" <<CONF
# =============================================================================
#  Hyprland — gerado pelo instalador do Kortex em $(date +%F)
#  Documentação: https://wiki.hypr.land
#  Suas personalizações: coloque em ~/.config/hypr/user.conf (carregado no fim)
# =============================================================================

monitor = , preferred, auto, 1
# Resolução, taxa e escala por monitor, escolhidas no widget de tela do Kortex
source = $STATE/monitors.conf
# Desfoque do terminal (regra de janela), escolhido em Configurações › Aparência › Terminal
source = $STATE/hyprland-terminal.conf

# Terminal, explorador de arquivos e navegador: o open-app.sh abre o que foi escolhido em
# Configurações › Aplicativos (lê ~/.local/state/kortex/apps.sh), então a troca vale sem editar este arquivo.
\$terminal    = $DEST/scripts/open-app.sh terminal
\$fileManager = $DEST/scripts/open-app.sh files
\$browser     = $DEST/scripts/open-app.sh browser
\$kortex        = qs -c kortex ipc call

# ---------------------------------------------------------------- cores ----
# Valores padrão; o tema ativo do Kortex sobrescreve pelo arquivo abaixo.
\$kortex_accent = rgb(686868)
\$kortex_bg     = rgb(222222)
\$kortex_fg     = rgb(ffffff)
\$kortex_muted  = rgb(525252)
\$kortex_red    = rgb(7c7c7c)
source = $STATE/hyprland-colors.conf

# ------------------------------------------------------------- ambiente ----
env = XCURSOR_SIZE,22
env = HYPRCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland;xcb
env = ELECTRON_OZONE_PLATFORM_HINT,auto
env = TERMINAL,$TERMINAL_APP
$NVIDIA_ENV

# -------------------------------------------------------------- início ----
exec-once = systemctl --user start hyprpolkitagent
exec-once = hypridle
exec-once = qs -c kortex

# ------------------------------------------------------------ aparência ----
general {
    gaps_in = 3
    gaps_out = 6
    border_size = 1
    col.active_border = \$kortex_accent
    col.inactive_border = \$kortex_muted
    layout = master
    resize_on_border = false
}

decoration {
    rounding = 8
    inactive_opacity = 1.0
    shadow {
        enabled = false
    }
    blur {
        enabled = true
        size = 4
        passes = 2
    }
}

animations {
    enabled = true
}

dwindle {
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}
$VM_ENV

# ---------------------------------------------------------------- entrada --
input {
    kb_layout = $KB_LAYOUT
    kb_variant = $KB_VARIANT
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# ------------------------------------------------------------- atalhos ----
bind = SUPER, RETURN, exec, \$terminal
bind = SUPER, E, exec, \$fileManager
bind = SUPER, W, exec, \$browser
bind = SUPER, SPACE, exec, \$kortex launcher toggle
bind = SUPER, C, killactive
bind = SUPER, F, fullscreen
bind = SUPER, V, togglefloating
bind = SUPER CTRL, L, exec, pidof hyprlock || hyprlock

# Kortex
bind = SUPER SHIFT, T, exec, \$kortex themes toggle
bind = SUPER SHIFT, W, exec, \$kortex themes carousel
bind = SUPER CTRL, W, exec, \$kortex themes randomWallpaper
bind = SUPER, N, exec, \$kortex notifications toggleDnd
bind = SUPER SHIFT, N, exec, \$kortex notifications clear
bind = SUPER, comma, exec, \$kortex settings toggle
bind = SUPER SHIFT, A, exec, \$kortex keepAwake toggle

# Foco e movimento
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
bind = SUPER SHIFT, left, movewindow, l
bind = SUPER SHIFT, right, movewindow, r
bind = SUPER SHIFT, up, movewindow, u
bind = SUPER SHIFT, down, movewindow, d

# Áreas de trabalho 1–5 (a barra pode mostrar até 10 nas Configurações; o Kortex cria SUPER+6…0 quando precisar)
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER, mouse_down, workspace, e+1
bind = SUPER, mouse_up, workspace, e-1

# Mouse: SUPER + arrastar move / redimensiona
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow

# Captura de tela do Kortex: tela inteira, janela ou área; depois escolhe nome, formato e pasta
bind = , Print, exec, \$kortex screenshot toggle

# Teclas de mídia
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl  = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = , XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
bindl  = , XF86AudioPlay, exec, playerctl play-pause
bindl  = , XF86AudioNext, exec, playerctl next
bindl  = , XF86AudioPrev, exec, playerctl previous

# --------------------------------------------------------- do usuário ----
source = $HYPR/user.conf
CONF
    [ -f "$HYPR/user.conf" ] || printf '# Suas configurações pessoais do Hyprland (este arquivo não é sobrescrito)\n' > "$HYPR/user.conf"
    ok "hyprland.conf"

    # hypridle.conf
    if [ ! -f "$HYPR/hypridle.conf" ]; then
        cat > "$HYPR/hypridle.conf" <<'CONF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

# 5 min: bloqueia
listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

# 5,5 min: desliga a tela
listener {
    timeout = 330
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
CONF
        ok "hypridle.conf (bloqueio após 5 min)"
    fi

    # hyprlock.conf
    if [ ! -f "$HYPR/hyprlock.conf" ]; then
        cat > "$HYPR/hyprlock.conf" <<'CONF'
# Tela de bloqueio do Kortex. As cores são as do tema ativo: o shell as grava em
# ~/.local/state/kortex/hyprland-colors.conf a cada troca de tema. Os valores abaixo (Morello)
# valem enquanto esse arquivo não existe.
$kortex_accent = rgb(686868)
$kortex_accent2 = rgb(393939)
$kortex_bg = rgb(222222)
$kortex_bg_alt = rgb(343434)
$kortex_fg_bright = rgb(ffffff)
$kortex_red = rgb(7c7c7c)
$kortex_yellow = rgb(a0a0a0)
source = ~/.local/state/kortex/hyprland-colors.conf

general {
    hide_cursor = true
}

background {
    monitor =
    color = $kortex_bg
}

label {
    monitor =
    text = $TIME
    color = $kortex_fg_bright
    font_size = 72
    font_family = JetBrainsMono Nerd Font
    position = 0, 120
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 320, 48
    outline_thickness = 2
    outer_color = $kortex_accent $kortex_accent2 45deg
    inner_color = $kortex_bg_alt
    font_color = $kortex_fg_bright
    check_color = $kortex_yellow
    fail_color = $kortex_red
    placeholder_text = Senha…
    fail_text = Senha incorreta
    rounding = 6
    position = 0, -40
    halign = center
    valign = center
}
CONF
        ok "hyprlock.conf"
    fi
fi

# ------------------------------------------------------- início da sessão ----
step "Configurando o início da sessão"

if systemctl is-enabled display-manager.service &>/dev/null && [ "$LOGIN_MODE" != sddm ]; then
    dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    info "Gerenciador de login já ativo ($dm). Escolha a sessão 'Hyprland' na tela de login."
    LOGIN_MODE=none
fi

case "$LOGIN_MODE" in
    tty)
        case "$(basename "${SHELL:-bash}")" in
            zsh)  PROFILE="$HOME/.zprofile" ;;
            fish) PROFILE="" ;;
            *)    PROFILE="$HOME/.bash_profile" ;;
        esac
        if [ -z "$PROFILE" ]; then
            warn "Shell fish: adicione manualmente ao config.fish o início do Hyprland no tty1 (start-hyprland)."
        elif ! grep -q "kortex-autostart" "$PROFILE" 2>/dev/null; then
            touch "$PROFILE"
            cat >> "$PROFILE" <<'PROF'

# >>> kortex-autostart >>>
# Inicia o Hyprland ao entrar no tty1. Para desativar, apague este bloco.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" -eq 1 ]; then
    if command -v start-hyprland >/dev/null; then exec start-hyprland; else exec Hyprland; fi
fi
# <<< kortex-autostart <<<
PROF
            ok "Hyprland inicia automaticamente ao entrar no tty1 ($PROFILE)"
        else
            ok "Início automático já configurado"
        fi
        ;;
    sddm)
        # Instala o tema "kortex" do SDDM (cores seguem o tema do shell), ativa o serviço e tira o início pelo tty1
        bash "$DEST/scripts/sddm-setup.sh" --yes
        ;;
    none)
        info "Nada alterado. Para iniciar manualmente: start-hyprland"
        ;;
esac

# ------------------------------------------------------------------ fim ------
step "Pronto!"
EXTRA_NOTE=""
if [[ " ${CHOSEN[*]} " == *" tailscale "* ]]; then
    EXTRA_NOTE="  Tailscale: para entrar na sua rede, rode:  sudo tailscale up"$'\n'
fi
LOGIN_NOTE=""
if [ "$LOGIN_MODE" = sddm ]; then
    LOGIN_NOTE="  Na tela de login (SDDM), entre com seu usuário; a sessão Hyprland já vem selecionada."$'\n\n'
fi
cat <<FIM

  O Kortex está instalado. ${C_B}Reinicie o computador${C_0}:

      sudo reboot

${LOGIN_NOTE}  Atalhos principais:
      SUPER + ESPAÇO        lançador de aplicativos
      SUPER + ENTER         terminal ($TERMINAL_APP)
      SUPER + E             explorador de arquivos
      SUPER + W             navegador
      SUPER + C             fechar janela
      SUPER + 1…5           áreas de trabalho
      SUPER + SHIFT + T     temas
      SUPER + SHIFT + W     papéis de parede
      SUPER + ,             configurações do Kortex
      SUPER + CTRL + L      bloquear a tela

  Arquivos:
      Shell:        $DEST
      Hyprland:     ~/.config/hypr/hyprland.conf  (personalize em user.conf)
      Log:          $LOG

  Firefox (cores do tema):  depois de abri-lo uma vez, rode
      bash $DEST/scripts/firefox-setup.sh

${EXTRA_NOTE}
  Se a barra não aparecer:  qs -c kortex log
FIM

if [ "${#WARNINGS[@]}" -gt 0 ]; then
    printf '\n  %sAvisos:%s\n' "$C_Y" "$C_0"
    for w in "${WARNINGS[@]}"; do printf '   • %s\n' "$w"; done
fi
echo
