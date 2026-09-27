#!/usr/bin/env bash
# Instala e ativa o SDDM com o tema do Kortex. As cores da tela de login seguem o tema ativo do shell.
#   sddm-setup.sh [--yes] [--no-enable] [--keep-tty-autostart]
#
#   --yes                  não pergunta nada ao instalar o pacote
#   --no-enable            instala o tema, mas não ativa o SDDM no boot
#   --keep-tty-autostart   não remove do ~/.bash_profile/.zprofile o início automático no tty1
#
# Pede a senha de administrador (sudo). Pode ser rodado de novo com segurança.
# Para desfazer:  sudo systemctl disable sddm   (o Hyprland volta a iniciar pelo tty, veja o README)
set -Eeuo pipefail

ASSUME_YES=0; ENABLE=1; KEEP_TTY=0
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)              ASSUME_YES=1 ;;
        --no-enable)           ENABLE=0 ;;
        --keep-tty-autostart)  KEEP_TTY=1 ;;
        -h|--help)             sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Opção desconhecida: $1"; exit 1 ;;
    esac
    shift
done

if [ -t 1 ]; then C_G=$'\e[32m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_0=$'\e[0m'; else C_G=""; C_Y=""; C_R=""; C_0=""; fi
ok()   { printf '%s✓%s %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '%s!%s %s\n' "$C_Y" "$C_0" "$*"; }
die()  { printf '%s✗%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Rode como seu usuário comum, não como root (o script usa sudo só onde precisa)."

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../sddm"
[ -f "$SRC/Main.qml" ] || die "Tema do SDDM não encontrado em $SRC"

# KORTEX_SDDM_ROOT: só para ensaio. Instala numa raiz falsa, sem sudo, sem pacote e sem systemctl.
ROOT="${KORTEX_SDDM_ROOT:-}"
SU=(sudo)
[ -z "$ROOT" ] || SU=()
THEME_DIR="$ROOT/usr/share/sddm/themes/kortex"
CONF_DIR="$ROOT/etc/sddm.conf.d"
ME="$(id -un)"; MY_GROUP="$(id -gn)"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -n "$ROOT" ] || sudo -v

# --- pacote (o sddm depende do xorg-server, que é o servidor do greeter) ----------
if [ -z "$ROOT" ] && ! pacman -Qq sddm &>/dev/null; then
    flags=(); [ "$ASSUME_YES" = 1 ] && flags=(--noconfirm)
    sudo pacman -S --needed "${flags[@]}" sddm
fi
if [ -z "$ROOT" ]; then
    pacman -Qq sddm &>/dev/null || die "O pacote sddm não está instalado."
    [ -x /usr/bin/Xorg ] || warn "Xorg não encontrado: o greeter do SDDM precisa dele (pacote xorg-server)."
fi
ok "SDDM instalado"

# --- tema ---------------------------------------------------------------------
"${SU[@]}" install -d -m755 "$THEME_DIR"
"${SU[@]}" install -m644 "$SRC/Main.qml" "$SRC/metadata.desktop" "$SRC/theme.conf" "$THEME_DIR/"
# O theme.conf.user é do usuário: assim o shell reescreve as cores a cada troca de tema, sem senha.
[ -e "$THEME_DIR/theme.conf.user" ] || "${SU[@]}" install -m644 /dev/null "$THEME_DIR/theme.conf.user"
"${SU[@]}" chown "$ME:$MY_GROUP" "$THEME_DIR/theme.conf.user"

colors="${XDG_STATE_HOME:-$HOME/.local/state}/kortex/colors.sh"
if [ -f "$colors" ]; then
    ( . "$colors"
      KORTEX_SDDM_THEME_DIR="$THEME_DIR" bash "$HERE/sddm-colors.sh" \
          "${KORTEX_ACCENT:-}" "${KORTEX_BG:-}" "${KORTEX_FG:-}" "${KORTEX_MUTED:-}" "${KORTEX_RED:-}" \
          "${KORTEX_BG_ALT:-}" "${KORTEX_FG_BRIGHT:-}" "${KORTEX_FG_DIM:-}" "${KORTEX_YELLOW:-}" "${KORTEX_ACCENT2:-}" )
    ok "Tema \"kortex\" do SDDM instalado com as cores do tema ativo ($(cat "$(dirname "$colors")/theme.name" 2>/dev/null || echo "?"))"
else
    ok "Tema \"kortex\" do SDDM instalado (as cores passam a seguir o tema quando o shell abrir)"
fi

# --- configuração -------------------------------------------------------------
"${SU[@]}" install -d -m755 "$CONF_DIR"
printf '[Theme]\nCurrent=kortex\n' | "${SU[@]}" tee "$CONF_DIR/kortex.conf" >/dev/null
ok "Tema selecionado em /etc/sddm.conf.d/kortex.conf"

# Outro arquivo de configuração pode escolher um tema por cima do nosso
others="$(grep -lE '^[[:space:]]*Current=' "$ROOT/etc/sddm.conf" "$CONF_DIR"/*.conf 2>/dev/null | grep -v '/kortex\.conf$' || true)"
[ -z "$others" ] || warn "Estes arquivos também definem o tema e podem sobrepor o Kortex: $(echo $others). Remova a linha 'Current='."

# O SDDM lista as sessões por arquivo; sem isto ele pode oferecer primeiro a "Hyprland (uwsm)", que
# só funciona com o uwsm instalado. Só preenche se ainda não há um "último usuário/sessão" gravado.
sess=/usr/share/wayland-sessions/hyprland.desktop
state=/var/lib/sddm/state.conf
if [ -z "$ROOT" ] && [ -f "$sess" ] && id sddm &>/dev/null && ! sudo test -e "$state"; then
    printf '[Last]\nSession=%s\nUser=%s\n' "$sess" "$ME" | sudo tee "$state" >/dev/null
    sudo chown sddm:sddm "$state"
    sudo chmod 644 "$state"
    ok "Sessão Hyprland e usuário $ME pré-selecionados"
fi

# --- ativar -------------------------------------------------------------------
if [ "$ENABLE" = 1 ]; then
    if [ -n "$ROOT" ]; then
        ok "(ensaio) systemctl enable --force sddm"
    else
        prev=""
        [ -e /etc/systemd/system/display-manager.service ] && prev="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
        # Sem --now de propósito: a sessão atual continua; o SDDM assume no próximo boot.
        sudo systemctl enable --force sddm.service
        if [ -n "$prev" ] && [ "$prev" != sddm ]; then
            ok "SDDM ativado, no lugar do $prev (tela de login no próximo boot)"
        else
            ok "SDDM ativado (tela de login no próximo boot)"
        fi
    fi

    # O SDDM ocupa o tty1: o início automático do Hyprland por lá passa a ser desnecessário (e conflita).
    if [ "$KEEP_TTY" = 0 ]; then
        for f in "$HOME/.bash_profile" "$HOME/.zprofile"; do
            if grep -q '# >>> kortex-autostart >>>' "$f" 2>/dev/null; then
                cp -p "$f" "$f.bak-kortex-$STAMP"
                sed -i '/# >>> kortex-autostart >>>/,/# <<< kortex-autostart <<</d' "$f"
                ok "Início automático pelo tty1 removido de $f (backup: $f.bak-kortex-$STAMP)"
            fi
        done
    fi
else
    warn "SDDM não ativado (--no-enable). Para ativar: sudo systemctl enable --force sddm"
fi

cat <<MSG

Pronto. Reinicie para ver a tela de login.
Se ela não aparecer, use Ctrl+Alt+F3, entre com seu usuário e rode:  start-hyprland
Para voltar ao início pelo tty:  sudo systemctl disable sddm
MSG
