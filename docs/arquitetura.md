# Arquitetura do Kortex

Como as peças do shell se encaixam. O `CLAUDE.md` tem as regras de trabalho e as receitas; o `README.md` descreve cada recurso do ponto de vista de quem usa.

## Início

`kortex/shell.qml` é o ponto de entrada (`qs -c kortex`). Ele cria as camadas fixas (papel de parede, uma barra por monitor, a camada de clique fora, os avisos e o OSD), declara todas as janelas e define os atalhos IPC. As duas linhas `//@ pragma` do topo fixam o estilo básico do Qt Quick Controls (usado só pelo calendário) e escondem o aviso de recarga do Quickshell.

Os singletons de `services/` só nascem no primeiro acesso. Por isso o `Component.onCompleted` do `shell.qml` lê uma propriedade de cada serviço que precisa rodar desde o começo (notificações, brilho, temas, teclado, HyprSync, terminal, aplicativos e energia). Os outros nascem quando a barra ou uma janela os usa. O `BluetoothAgent` nasce de propósito só com o item Bluetooth da barra: é ali que os pedidos de pareamento aparecem, e sem ele o Kortex não se registra como agente no BlueZ.

## Janelas e camadas

| Arquivo | Tipo | Camada | Namespace | Teclado | Existe quando |
|---|---|---|---|---|---|
| `modules/wallpaper/Wallpaper.qml` | `PanelWindow` por monitor | Background | `kortex-wallpaper` | não | `wallpaperEnabled` ligado |
| `modules/bar/Bar.qml` | `PanelWindow` por monitor | Top | `kortex-bar` | não | sempre |
| `modules/clickaway/ClickAway.qml` | `PanelWindow` por monitor | Top | `kortex-clickaway` | não | um popup da barra aberto |
| `widgets/BarPopup.qml` | `PopupWindow` ancorado ao botão | (popup) | | não | `Popups.current` é o dele |
| janelas com `widgets/OverlayPanel.qml` | `PanelWindow` de tela cheia | Overlay | `kortex-<janela>` | exclusivo | a flag em `Popups` (ou a captura pendente) |
| `modules/wallpaper/WallpaperCarousel.qml` | `PanelWindow` | Top | `kortex-wallpaper-carousel` | exclusivo | `Popups.wallpaperCarouselOpen` |
| `modules/display/ApplyConfirm.qml` | `PanelWindow` | Overlay | `kortex-display-confirm` | exclusivo | mudança de tela em teste ou erro |
| `modules/notifications/NotificationToasts.qml` | `PanelWindow` | Overlay | `kortex-notifications` | não | sempre (visível com avisos) |
| `modules/osd/OsdWindow.qml` | `PanelWindow` sem área de clique | Overlay | `kortex-osd` | não | sempre (visível durante o aviso) |

As janelas com `OverlayPanel` são o lançador, o seletor de temas, as Configurações, o editor de rede, a senha do Wi-Fi, a cidade do clima, teclado e idioma, os menus de captura e de gravação e as duas janelas de salvar. Cada uma fica dentro de um `LazyLoader`, então só existe enquanto está aberta e começa do zero a cada vez.

Os namespaces importam: `services/HyprSync.qml` usa as regras de camada do Hyprland para dar a animação de cada uma (as janelas crescem do centro, a barra e o carrossel deslizam, os avisos e a camada de clique fora não têm animação do Hyprland).

### Por que dois tipos de janela

Um `PopupWindow` não recebe o teclado no Wayland e não sabe quando o clique foi fora dele. Os painéis da barra são `PopupWindow` (só mouse) e, enquanto um está aberto, a camada `ClickAway` cobre a tela inteira com um recorte do tamanho da barra: clicar em qualquer lugar fora fecha o painel, e a barra continua recebendo cliques pelo recorte. Na barra flutuante, a largura do recorte vem de `Popups.barWidths`, que cada barra informa.

O que precisa de teclado vira uma janela `OverlayPanel`: uma camada de tela cheia, transparente, com teclado exclusivo e o painel centralizado. O próprio fundo dela recebe o clique fora e emite `dismissed()`. (O `HyprlandFocusGrab` não resolve: não ativa para `PopupWindow` e, com teclado exclusivo, nunca avisa do clique fora.)

### Estado das janelas: `services/Popups.qml`

- `current` e `screen` dizem qual painel da barra está aberto e em qual monitor. Só um por vez. `toggle(id, tela)` abre ou fecha, `close(id)` fecha, e um segundo clique em até 300 ms no botão que acabou de fechar é ignorado.
- Uma flag por janela (`launcherOpen`, `settingsOpen`, `networkPromptSsid`…) e uma função `openX()` para cada. Abrir qualquer uma fecha as outras e o painel da barra (`_closeOverlays()`); `dismiss()` fecha tudo.
- Alguns serviços só trabalham com o painel deles aberto, olhando `Popups.current`: Energia (leitura a cada 2 s em vez de 10 s), Recursos (GPU, disco e sensores), Rede (conexão em uso e dados da sessão). O OSD fica quieto com o painel de Som ou de Tela aberto.

## Barra

`Bar.qml` é uma `PanelWindow` por monitor (`Variants` sobre `Quickshell.screens`). O lançador e as áreas de trabalho ficam fixos no começo; o resto vem de `Settings.barLayout()` (grupos esquerda, centro e direita) ou, no estilo flutuante, de `Settings.barFloatingLayout()` (uma fileira só). Cada id vira um `Loader` com o componente do mapa `components`, e a visibilidade vem de `Settings.barItemVisible(id)` e do `present` do item (mídia sem player, bandeja vazia, atualizações sem `checkupdates`).

Todo item é um `widgets/BarButton.qml`. Ele trata o realce, o espaço entre ícone e texto, a roda do mouse em passos inteiros (`wheelSteps`, que soma os movimentos pequenos do touchpad) e o arrastar para reordenar: segurar 450 ms começa o arrasto, a barra calcula os lugares possíveis (`_slots()`), mostra uma cópia do item (`ShaderEffectSource`) e o traço de onde ele cai, e soltar grava com `Settings.moveBarItem` ou `moveFloatingItem`.

## Serviços

| Serviço | Responsabilidade | Fontes e processos |
|---|---|---|
| `Settings` | preferências persistidas, ordem da barra, utilitários de execução | `~/.local/state/kortex/settings.json` (`FileView` + `JsonAdapter`) |
| `Theme` | paleta, fontes e métricas, catálogo de temas e papéis de parede, Matugen | `list-themes.sh`, `list-wallpapers.sh`, `matugen-generate.sh`, `theme-apply.sh`, `gio trash`, `rm`, `mv` |
| `Motion` | parâmetros das animações (Qt e Hyprland) | `Settings` |
| `HyprSync` | o que as Configurações aplicam ao Hyprland ao vivo, e o aviso quando o Hyprland ainda usa o `hyprland.conf` | `hyprctl eval` (Lua) |
| `Popups` | estado das janelas e painéis | |
| `Icons` | nomes dos ícones (Material Symbols) e a fonte | `fonts/MaterialSymbolsOutlined.ttf` |
| `Notifs` | servidor de notificações, avisos flutuantes, `flash()` do próprio Kortex | `NotificationServer` |
| `Osd` | aviso de volume, brilho, Caps Lock e Num Lock | PipeWire, `udevadm monitor`, `hyprctl devices` |
| `Brightness` | brilho e luz noturna | `brightnessctl` (a cada 5 s), `hyprsunset` |
| `Monitors` | resolução, taxa e escala, com teste e confirmação | `hyprctl monitors`, `hyprctl eval` com `hl.monitor`, `monitors.lua` |
| `Keyboard` | layouts, atalho de alternância, catálogo traduzido | `hyprctl devices`, `hyprctl eval` com `hl.config`, `evdev.lst`, `msgunfmt`, `localectl` |
| `Language` | idioma do sistema | `localectl`, `/etc/locale.conf`, `/etc/locale.gen`, `pkexec` |
| `Network` | Wi-Fi, cabo, perfis, conexão em uso e dados da sessão | `nmcli` (estado a cada 8 s), `/sys/class/net/*/statistics`, `network-sessions.json` |
| `Energy` | bateria e modos de energia | `/sys/class/power_supply/*/uevent`, `PowerProfiles` (D-Bus) |
| `SystemStats` | CPU, RAM, GPU, discos e temperaturas | `/proc` (a cada 2 s), `gpu-stats.sh`, `disk-stats.sh`, `sensors.sh` |
| `Weather` | tempo atual e 7 dias | `curl` no Open-Meteo e no ipinfo.io (a cada 30 min) |
| `Media` | player MPRIS em destaque | `Mpris` |
| `Updates` | pacotes com versão nova | `checkupdates` (a cada 10 min) |
| `Apps` | terminal, explorador e navegador padrão | `DesktopEntries`, `xdg-mime`, `apps-apply.sh` |
| `TerminalStyle` | opacidade e desfoque do Kitty | `terminal-apply.sh` |
| `KeepAwake` | Manter Acordado (o `IdleInhibitor` fica na barra) | |
| `BluetoothAgent` | agente de pareamento Bluetooth: aceita sozinho o que você pediu pelo painel e pergunta o resto | `bt-agent.py` (Python, `org.bluez.Agent1` no D-Bus do sistema), linhas JSON no stdout e respostas no stdin |
| `Screenshot`, `ScreenRecord` | captura e gravação de tela | `screenshot.sh`, `screenrecord.sh`, `$XDG_RUNTIME_DIR/kortex` |
| `Processes` | Gerenciador de Processos: os processos do usuário agrupados por aplicativo, encerrar e forçar | `processes.sh` (a cada 2 s, só com a janela aberta), `hyprctl clients`, `kill` |
| `Tailscale` | estado da VPN, este computador e os dispositivos da tailnet; ligar e desligar | `tailscale status --json` (a cada 3 s, só com o painel de rede aberto), `tailscale up`/`down` (com `pkexec` se preciso), `systemctl start tailscaled` |

Padrões que se repetem nos serviços:

- **Processo único com pedido acumulado.** `if (!proc.running) proc.running = true`; um pedido que chega durante a execução liga uma flag (`_again`, `_genAgain`) e é feito ao terminar.
- **Fila de comandos.** `Monitors._send/_pump` e `Keyboard._push/_pump` mandam um comando por vez ao `hyprctl` e leem o resultado (`ok` ou o erro).
- **Releitura com atraso.** Depois de mudar algo, um `Timer` curto relê o estado (o Hyprland, o NetworkManager e o `xdg-mime` não respondem na hora).
- **Mensagens previsíveis.** Os comandos do `nmcli` que podem falhar rodam com `LC_MESSAGES=C`, e `Network.friendly()` traduz os erros mais comuns.

## O caminho de uma troca de tema

1. `Theme.refresh()` roda `list-themes.sh`, que imprime cada tema (embutidos em `kortex/themes`, depois os do usuário em `~/.local/share/kortex/themes`, que têm prioridade) como um bloco `@@THEME<TAB>nome<TAB>pasta<TAB>1º fundo<TAB>origem` seguido do `colors.toml`. `parseThemes()` monta a lista e `normalize()` completa as cores que o tema não define.
2. `Theme.apply(nome)` grava `Settings.data.theme`. O handler `onThemeChanged` chama `loadCurrent()`, que aplica a paleta (`setPalette`) e relê os papéis de parede. `apply` também escolhe o papel de parede (o lembrado para esse tema, o primeiro do tema ou o atual) e chama `runHook()`.
3. `setPalette()` não usa as cores cruas: texto apagado, acento, vermelho, verde e amarelo são levados ao contraste mínimo (WCAG 4,5:1) sobre o fundo, o contorno a 3:1, e o texto sobre o acento e sobre o vermelho é a cor que mais contrasta. Só a interface do Kortex vê esses ajustes. `borderColor` é o acento sem ajuste, igual à borda das janelas do Hyprland.
4. `runHook()` chama `theme-apply.sh` com 20 argumentos posicionais (nome, pasta e as cores). O script grava os arquivos de estado e chama, em sequência, `sddm-colors.sh`, `kitty-theme.sh`, `btop-theme.sh`, `firefox-setup.sh --auto` (configura o perfil do Firefox que ainda não tem o Kortex), `firefox-theme.sh`, `gnome-theme.sh`, as bordas do Hyprland pelo `hyprctl`, `icon-theme.sh apply` e, por fim, o gancho do usuário em `~/.config/kortex/hooks/theme-set`, se existir e for executável.

Ao iniciar, o tema salvo passa pelo mesmo caminho uma vez (`_hookRan`), para os arquivos de estado existirem mesmo sem troca.

### Matugen

O tema `matugen` não é uma pasta fixa: `Theme.generate()` roda `matugen-generate.sh <imagem> <modo> <estilo> <pasta>` e o script imprime o `colors.toml` gerado, que `applyGenerated()` põe no catálogo na hora. Enquanto ele está ativo, cada troca de papel de parede gera de novo. O modelo `kortex/matugen/colors.toml` diz qual cor do Material You vira qual cor do Kortex; vermelho, verde, amarelo, azul, magenta e ciano vêm fixos de `semantic-dark.json` e `semantic-light.json`. Com um nome no quinto argumento o script salva um tema independente e copia o papel de parede para `backgrounds/`; com `-` no lugar da pasta, só imprime (prévia, útil para diagnóstico).

## `settings.json`

`Settings.qml` liga um `FileView` (com `watchChanges`) a um `JsonAdapter`. Mudar uma propriedade de `Settings.data` grava o arquivo (`onAdapterUpdated: writeAdapter()`), e uma edição externa é relida (`onFileChanged: reload()`). Arquivo ausente é criado com os padrões. Duas consequências estão nas armadilhas do `CLAUDE.md`: várias chaves na mesma volta precisam de `applyBatch`, e mapas e listas precisam ser reatribuídos, não mudados no lugar.

## Arquivos

Estado do Kortex, em `~/.local/state/kortex/`:

| Arquivo | Quem grava | Quem lê |
|---|---|---|
| `settings.json` | `Settings` | `Settings` |
| `colors.sh` | `theme-apply.sh` | `firefox-theme.sh`, `gnome-theme.sh`, `sddm-setup.sh`, ganchos do usuário |
| `colors.css` | `theme-apply.sh` | programas do usuário (`@define-color`) |
| `hyprland-colors.conf` | `theme-apply.sh` | `hyprlock.conf` (`source`) |
| `hyprland-colors.lua` | `theme-apply.sh` | `hyprland.lua` (`kortex_load`, devolve uma tabela) |
| `kitty-theme.conf` | `kitty-theme.sh` | `kitty.conf` (`include`) |
| `kitty-window.conf` | `terminal-apply.sh` | `kitty-theme.conf` (`include`) |
| `hyprland-terminal.lua` | `terminal-apply.sh` | `hyprland.lua` (`kortex_load`) |
| `monitors.lua` | `Monitors` (e o `install.sh`, que converte o `monitors.conf` antigo) | `hyprland.lua` (`kortex_load`) |
| `apps.sh` | `apps-apply.sh` | `open-app.sh` |
| `theme.name`, `current-theme` | `theme-apply.sh` | `sddm-setup.sh`, o usuário |
| `network-sessions.json` | `Network` | `Network` |
| `gnome-original.txt` | `gnome-setup.sh` | `gnome-setup.sh --remove` |
| `firefox-off` | `firefox-setup.sh --remove` (e apagado pelo `firefox-setup.sh` sem opções) | `firefox-setup.sh --auto` |

Outros lugares:

- `~/.local/share/kortex/themes/` guarda os temas do usuário (o `matugen` gerado e os salvos dele).
- `~/.local/share/kortex/backgrounds/<tema>/` guarda papéis de parede extras de um tema.
- `$XDG_RUNTIME_DIR/kortex/` guarda as capturas e gravações ainda não salvas (apagadas ao iniciar o shell).
- Fora do Kortex, a cada troca de tema: `~/.config/btop/themes/kortex.theme` (e `btop.conf`, só se nenhum tema foi escolhido), `~/.config/gtk-4.0/kortex-colors.css`, `~/.config/gtk-3.0/kortex-colors.css`, `~/.local/share/gtksourceview-5/styles/kortex.xml`, o `gtk-icon-theme-name` dos `settings.ini` do GTK que existirem, o `gsettings` (`color-scheme`, o `gtk-theme` quando há o adw-gtk3 e o esquema do Editor de Texto), o `chrome/kortex-colors.css` dos perfis do Firefox configurados e o `/usr/share/sddm/themes/kortex/theme.conf.user` (que pertence ao usuário).

## Scripts

Todos ficam em `kortex/scripts/` e começam com o uso no cabeçalho. Os que gravam arquivos escrevem num temporário e trocam com `mv`, e os que recebem cores conferem `#rrggbb` antes de gravar.

| Script | Chamado por | Faz |
|---|---|---|
| `theme-apply.sh` | `Theme.runHook` | efeitos de um tema fora do shell (ver acima) |
| `kitty-theme.sh`, `btop-theme.sh`, `sddm-colors.sh`, `firefox-theme.sh`, `gnome-theme.sh` | `theme-apply.sh` | as cores de cada programa |
| `icon-theme.sh` | `theme-apply.sh`, `matugen-generate.sh` | `pick` escolhe a variante do Yaru pelo acento; `apply` aplica o tema de ícones |
| `list-themes.sh`, `list-wallpapers.sh` | `Theme` | catálogo de temas e de imagens |
| `matugen-generate.sh` | `Theme` | cores do papel de parede (código 127 = sem Matugen) |
| `terminal-apply.sh` | `TerminalStyle` | opacidade do Kitty e regra de desfoque |
| `apps-apply.sh` | `Apps` | grava `apps.sh` e o `xdg-mime` |
| `open-app.sh` | atalhos do `hyprland.lua` | abre terminal, explorador ou navegador, sem depender do shell |
| `term.sh` | `Settings.runInTerminal` | abre um comando no terminal (trata o Kitty, que não tem `-e`) |
| `screenshot.sh` | `Screenshot` | `capture`, `save`, `pick`, `dirs` (1 = cancelado, 2 = erro, 3 = destino existe) |
| `screenrecord.sh` | `ScreenRecord` | `target`, `record`, `info`, `save`, `dirs` (mesmos códigos) |
| `gpu-stats.sh`, `disk-stats.sh`, `sensors.sh` | `SystemStats` | linhas com TAB ou `chave=valor` |
| `processes.sh` | `Processes` | processos do usuário (PID, pai, CPU, memória própria, nome e comando) e as janelas do `hyprctl clients` |
| `brightness.sh` | `Brightness` e as teclas de brilho do `hyprland.lua` | o `brightnessctl` na luz de fundo da tela conectada (notebooks com duas GPUs têm duas) |
| `firefox-setup.sh`, `gnome-setup.sh`, `sddm-setup.sh` | o usuário e o `arch-setup.sh`; o `firefox-setup.sh --auto` também pelo `theme-apply.sh` | instalam a integração (todos aceitam desfazer) |
| `firefox-common.sh` | `source` nos scripts do Firefox | acha os perfis padrão |

Variáveis só para teste: `KORTEX_GNOME_NO_GSETTINGS=1` (pula o `gsettings`), `KORTEX_SDDM_THEME_DIR` (outra pasta para o `theme.conf.user`) e `KORTEX_SDDM_ROOT` (o `sddm-setup.sh` instala numa raiz falsa, sem sudo nem pacotes). O `dev/verificar.sh` usa as três.

## IPC

`qs -c kortex ipc call <alvo> <função> [arg]`, definidos em `shell.qml`:

| Alvo | Funções |
|---|---|
| `launcher` | `toggle` |
| `themes` | `toggle`, `wallpapers`, `matugen`, `set <nome>`, `randomWallpaper`, `carousel` |
| `notifications` | `clear`, `toggleDnd` |
| `keyboard` | `next`, `prev`, `set <posição>`, `settings`, `language` |
| `settings` | `toggle`, `open <página>` (`appearance`, `animations`, `bar`, `apps`, `power`, `general`, `about`) |
| `screenshot`, `record`, `processes`, `keepAwake` | `toggle` |
| `osd` | `locks` (chamado pelos atalhos `non_consuming` de Caps Lock e Num Lock que o HyprSync cria) |

## Animações

`services/Motion.qml` concentra tudo. Para o Hyprland, `hyprlandLua` gera as curvas Bézier (`hl.curve`) (`kortexOut`, `kortexIn`, `kortexStd`, `kortexBack`) e as animações (`hl.animation`) de janelas, áreas de trabalho, camadas e popups, que o `HyprSync` aplica ao vivo e reaplica a cada recarga. Para o Qt, expõe as curvas no formato do `easing.bezierCurve`, `ms(base)` (a duração na velocidade escolhida) e os deslocamentos e escalas dos painéis (`BarPopup`) e dos avisos (`NotificationToasts`), que o Hyprland não sabe animar além de esmaecer.

## Hyprland em Lua

O Kortex exige a configuração do Hyprland em Lua (`~/.config/hypr/hyprland.lua`, Hyprland 0.55 ou mais novo; o 0.57 não lê mais o `hyprland.conf`). Ele conversa com o Hyprland de três jeitos:

- **Ao vivo, pelo `hyprctl eval`.** `HyprSync`, `Keyboard`, `Monitors`, `theme-apply.sh` e `screenshot.sh` mandam código Lua (`hl.config`, `hl.bind`, `hl.monitor`, `hl.layer_rule`, `hl.animation`…), e o Hyprland responde `ok` ou o erro. O `HyprSync` manda as instruções pelo `guard()`, que põe cada uma no seu `pcall` e devolve os erros juntos no fim: no Lua um erro interrompe o bloco, e sem isso uma instrução recusada levaria as seguintes. Todo texto que entra nesse código passa por `HyprSync.lua(s)`, que o devolve como literal de string do Lua; nos scripts, só entram números e cores já validadas como hexadecimal. Os dispatchers usam a sintaxe nova também pelo `Hyprland.dispatch` do Quickshell e pelo `hyprctl dispatch` (`hl.dsp.focus({ workspace = 3 })`, `hl.dsp.exit()`).
- **Por arquivos em `~/.local/state/kortex`.** `hyprland-colors.lua` (devolve uma tabela com a paleta), `monitors.lua` e `hyprland-terminal.lua` são carregados pelo `hyprland.lua` com o `kortex_load`, que ignora um arquivo ausente e transforma um erro dentro dele em aviso, sem interromper o resto da configuração.
- **Pelo `hyprland.lua` que o `arch-setup.sh` grava**, com os atalhos e as regras fixas, e o `user.lua` do usuário, carregado no fim com `pcall(require, "user")`.

Com o Hyprland ainda no `hyprland.conf`, o `hyprctl eval` responde "eval is only supported with the lua config manager": o `HyprSync` então mostra um aviso uma vez e marca `luaConfig: false`. Um `hyprctl reload` recria o estado do Lua e apaga o que foi aplicado ao vivo; por isso `HyprSync` e `Keyboard` reaplicam tudo no evento `configreloaded`.

O `dev/verificar.sh` confere esse Lua sem tocar na sessão: monta o `hyprland.lua` do `arch-setup.sh` com os arquivos que a fumaça gravou, roda o `dev/hl-mock.lua` (uma imitação da API `hl` que confere a forma das chamadas) e, com o Hyprland instalado, o `Hyprland --verify-config`, que acusa opções, campos de regra, estilos e curvas desconhecidos. As funções do `Motion.qml` e do `HyprSync.qml` são copiadas para um QML de teste que gera todas as combinações de animação, conferidas do mesmo jeito.

## Escala fracionária

Com escala de 1,25× ou 1,6×, um tamanho lógico só cai num número inteiro de pixels físicos se for múltiplo de um passo (4 a 1,25×, 5 a 1,6×). `Theme.snapStep(dpr)` acha o passo e `Theme.snapUp(px, dpr)` arredonda para cima. As janelas dos painéis e dos avisos usam esses tamanhos, as camadas soltas da borda (barra flutuante e avisos) ficam a uma distância que também cai em pixel inteiro, e `widgets/GradientBorder.qml` desenha borda e preenchimento juntos, alinhados à grade de pixels da janela (com `scaled: true`, a espessura conta em pixels lógicos, como a borda das janelas do Hyprland). Sem isso o compositor reamostra a janela e a borda sai borrada.
