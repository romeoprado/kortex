#!/usr/bin/env bash
# Instala o Kortex em ~/.config/quickshell/kortex
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)/kortex"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/kortex"

command -v qs >/dev/null || echo "Aviso: 'qs' (Quickshell) não encontrado. Instale com: yay -S quickshell-git"
for dep in nmcli brightnessctl hyprsunset curl bluetoothctl xdg-mime; do
    command -v "$dep" >/dev/null || echo "Aviso: '$dep' não encontrado (alguns widgets ficarão limitados)."
done
command -v powerprofilesctl >/dev/null || echo "Aviso: 'power-profiles-daemon' não encontrado (sem ele o widget Energia só mostra a bateria). Instale com: sudo pacman -S power-profiles-daemon && sudo systemctl enable --now power-profiles-daemon"
command -v matugen >/dev/null || echo "Aviso: 'matugen' não encontrado (sem ele o tema Matugen não gera cores do papel de parede). Instale com: sudo pacman -S matugen"
[ -d /usr/share/icons/Yaru ] || [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/icons/Yaru" ] || echo "Aviso: ícones Yaru não encontrados (sem eles os temas não trocam os ícones dos apps). Instale com: yay -S yaru-icon-theme"
# A saída do fc-list é capturada antes do grep: com "set -o pipefail", "fc-list | grep -q" acusa falha
# (o grep sai cedo e o fc-list recebe SIGPIPE) e o aviso apareceria mesmo com a fonte instalada.
fonts="$(fc-list 2>/dev/null || true)"
grep -qi "JetBrainsMono Nerd" <<<"$fonts" || echo "Aviso: fonte JetBrainsMono Nerd Font ausente (pacote ttf-jetbrains-mono-nerd)."
grep -qi "Iosevka Fixed" <<<"$fonts" || echo "Aviso: fonte dos títulos (Iosevka) ausente, usando o Noto Sans (pacote ttc-iosevka)."

if [ -d "$dest" ]; then
    bak="$dest.bak-$(date +%Y%m%d-%H%M%S)"
    echo "Configuração existente movida para $bak"
    mv "$dest" "$bak"
fi
mkdir -p "$(dirname "$dest")"
cp -r "$src" "$dest"
chmod +x "$dest"/scripts/*.sh
[ -f "$dest/fonts/MaterialSymbolsOutlined.ttf" ] || echo "Aviso: a fonte dos ícones (fonts/MaterialSymbolsOutlined.ttf) não foi copiada; os ícones apareceriam como palavras."

state="${XDG_STATE_HOME:-$HOME/.local/state}/kortex"
mkdir -p "$state"
touch "$state/hyprland-colors.conf"
[ -f "$state/monitors.conf" ] || printf '# Gerado pelo Kortex (widget de tela). Carregado pelo Hyprland.\n' > "$state/monitors.conf"
[ -f "$state/hyprland-terminal.conf" ] || printf '# Gerado pelo Kortex (Configurações). Carregado pelo Hyprland.\n' > "$state/hyprland-terminal.conf"

cat <<MSG

Kortex instalado em $dest

Próximos passos:
  1. Teste agora:           qs -c kortex
  2. No hyprland.conf, troque waybar/mako/hyprpaper por:
       exec-once = qs -c kortex
       source = $state/hyprland-colors.conf
       source = $state/monitors.conf
       source = $state/hyprland-terminal.conf
       bind = SUPER, SPACE, exec, qs -c kortex ipc call launcher toggle
       bind = SUPER SHIFT, T, exec, qs -c kortex ipc call themes toggle
       bind = SUPER, comma, exec, qs -c kortex ipc call settings toggle
  3. Opcional: tela de login gráfica (SDDM) com as cores do tema ativo:
       bash $dest/scripts/sddm-setup.sh
  4. Opcional: cores do tema no Kitty (e o terminal translúcido). Ponha por ÚLTIMO no ~/.config/kitty/kitty.conf:
       include $state/kitty-theme.conf
  5. Opcional: atalhos de terminal, explorador e navegador que seguem Configurações › Aplicativos:
       bind = SUPER, RETURN, exec, $dest/scripts/open-app.sh terminal
       bind = SUPER, E, exec, $dest/scripts/open-app.sh files
       bind = SUPER, W, exec, $dest/scripts/open-app.sh browser
  6. Opcional: cores do tema no Firefox (rode depois de abri-lo uma vez; ele lê as cores ao abrir):
       bash $dest/scripts/firefox-setup.sh
  7. Opcional: cores do tema nos apps do GNOME (Nautilus, Calculadora, Editor de Texto):
       bash $dest/scripts/gnome-setup.sh
  Veja $dest/README.md para mais detalhes.
MSG
