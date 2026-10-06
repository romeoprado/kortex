# Kortex

Shell para **Hyprland** feito em **Quickshell**. Versão **0.1**.

Inclui barra superior, lançador estilo Rofi, central de notificações, controles de teclado e idioma, Bluetooth, Wi‑Fi, som e tela, energia (modo de energia e bateria), menu de sessão, calendário, previsão do tempo, estatísticas de hardware, captura de tela e um seletor de temas e papéis de parede. O tema também chega ao Kitty, ao btop, ao Firefox, à tela de login e aos apps do GNOME.

## 0. Instalação em um Arch Linux limpo (recomendado)

Se você acabou de instalar o Arch (sistema base, um usuário com `sudo` e internet), o `arch-setup.sh` faz tudo: Hyprland, Quickshell, drivers de vídeo (Intel, AMD ou NVIDIA), PipeWire, NetworkManager, Bluetooth, modos de energia (`power-profiles-daemon`), fontes, utilitários, o Firefox, o Nautilus (explorador de arquivos padrão), o Kortex e uma configuração inicial do Hyprland com atalhos.

```bash
# como seu usuário, não como root
tar xzf kortex.tar.gz
cd kortex
./arch-setup.sh
sudo reboot
```

Opções úteis: `--yes` (sem perguntas), `--login sddm|tty|none` (o padrão é `sddm`, uma tela de login gráfica com as cores do tema; `tty` inicia o Hyprland direto ao entrar no tty1 e `none` não mexe em nada; se você já usa outro gerenciador de login, ele é mantido, a menos que peça `--login sddm`), `--terminal kitty|alacritty|ghostty|foot` (o padrão é o `kitty`, e só ele tem as cores do tema aplicadas automaticamente; em máquina virtual o padrão vira `foot`, que funciona sem aceleração 3D), `--no-drivers`, `--no-hypr-config`, `--quickshell-git` (usa o `quickshell-git` do AUR em vez do pacote oficial), `--extras LISTA`. Veja `./arch-setup.sh --help`. **Programas adicionais:** no modo interativo, o instalador oferece num menu (nenhum vem marcado) o `yay` (ajudante do AUR), o Discos, a Calculadora e o Editor de Texto do GNOME, o HyprMod (configura o Hyprland numa janela) e o Tailscale. Para instalar sem perguntas, use `--extras yay,disks,calculator,editor,hyprmod,tailscale` (ou `todos`, ou `nenhum`); com `--yes` e sem `--extras`, nenhum adicional é instalado. O HyprMod, o `yay` e os ícones `yaru-icon-theme` (sempre instalados, para os temas) vêm do AUR: sem um ajudante do AUR, o instalador instala o `yay` para buscá-los; se já houver `yay` ou `paru`, ele é usado e o `yay` não é reinstalado. O Tailscale ganha o serviço `tailscaled` ativado, e depois você entra na sua rede com `sudo tailscale up`. Os apps do GNOME recebem o tema do Kortex (veja a seção 6). O log fica em `~/kortex-setup.log`, e o script pode ser rodado de novo com segurança.

Se você já tem Hyprland configurado, pule para as seções 1 e 2.

## 1. Dependências (Arch Linux)

```bash
# Repositórios oficiais
sudo pacman -S --needed qt6-declarative qt6-svg qt6-imageformats qt6-wayland ttf-jetbrains-mono-nerd ttc-iosevka \
    networkmanager bluez bluez-utils pipewire wireplumber pipewire-pulse \
    brightnessctl hyprsunset curl pavucontrol btop pciutils xdg-utils power-profiles-daemon grim slurp jq

# AUR (com yay ou paru)
yay -S quickshell-git     # ou: quickshell
```

Serviços necessários:

```bash
sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
```

O `power-profiles-daemon` dá os modos de energia do widget *Energia*. Ele conflita com o TLP e o tuned: se você já usa um deles, deixe-o de fora (com o `tuned-ppd` os modos funcionam do mesmo jeito; com o TLP o widget mostra só a bateria).

Opcionais: `matugen` (gera as cores do tema a partir do papel de parede; veja *Cores do papel de parede*, na seção 4), `firefox` (navegador; as cores do tema são aplicadas por `scripts/firefox-setup.sh`), `nautilus` (explorador de arquivos, com o tema aplicado por `scripts/gnome-setup.sh`), `hyprlock` (bloquear tela), `hyprpolkitagent` (pede a senha ao gravar o teclado ou o idioma no sistema), `sddm` (tela de login gráfica com as cores do tema; veja a seção 6), `nm-connection-editor` (configurações avançadas de rede), um terminal (`kitty` é o padrão do Kortex e o único com o tema aplicado automaticamente; ghostty, alacritty e foot também funcionam), `yaru-icon-theme` (do AUR; os ícones dos apps que cada tema escolhe no `icons.theme`, veja *Formato dos temas*, na seção 4).

## 2. Instalação

```bash
tar xzf kortex.tar.gz
cd kortex            # a pasta do pacote; o código do shell fica em kortex/kortex
./install.sh
```

Ou manualmente (dentro da pasta do pacote):

```bash
mkdir -p ~/.config/quickshell
cp -r kortex ~/.config/quickshell/kortex
chmod +x ~/.config/quickshell/kortex/scripts/*.sh
```

Teste sem reiniciar a sessão:

```bash
qs -c kortex
```

Para ter também a tela de login com as cores do tema (opcional, pede a senha de administrador): `bash ~/.config/quickshell/kortex/scripts/sddm-setup.sh` (detalhes na seção 6).

## 3. Integração com o Hyprland

O Kortex substitui barra, notificações e papel de parede. **Desative** no `hyprland.conf` qualquer `exec-once` de `waybar`, `mako`, `dunst`, `swaync`, `hyprpaper` ou `swaybg` — dois servidores de notificação não podem rodar ao mesmo tempo.

Adicione em `~/.config/hypr/hyprland.conf`:

```ini
exec-once = qs -c kortex

# Cores do tema atual (variáveis $kortex_accent, $kortex_bg, $kortex_fg, $kortex_muted, $kortex_red)
source = ~/.local/state/kortex/hyprland-colors.conf

# Resolução, taxa e escala confirmadas no widget de tela (ver seção 4)
source = ~/.local/state/kortex/monitors.conf

# Desfoque do terminal, escolhido em Configurações › Aparência › Terminal (ver seção 4)
source = ~/.local/state/kortex/hyprland-terminal.conf

$kortex = qs -c kortex ipc call
bind = SUPER, SPACE, exec, $kortex launcher toggle
bind = SUPER SHIFT, T, exec, $kortex themes toggle
bind = SUPER SHIFT, W, exec, $kortex themes carousel
bind = SUPER CTRL, W, exec, $kortex themes randomWallpaper
bind = SUPER, N, exec, $kortex notifications toggleDnd
bind = SUPER SHIFT, N, exec, $kortex notifications clear
bind = SUPER, comma, exec, $kortex settings toggle
bind = SUPER SHIFT, A, exec, $kortex keepAwake toggle
bind = , Print, exec, $kortex screenshot toggle

# Terminal, explorador de arquivos e navegador: o open-app.sh abre o que foi escolhido em
# Configurações › Aplicativos (ele não depende do shell estar rodando)
$terminal    = ~/.config/quickshell/kortex/scripts/open-app.sh terminal
$fileManager = ~/.config/quickshell/kortex/scripts/open-app.sh files
$browser     = ~/.config/quickshell/kortex/scripts/open-app.sh browser
bind = SUPER, RETURN, exec, $terminal
bind = SUPER, E, exec, $fileManager
bind = SUPER, W, exec, $browser

# Opcional: alternar o layout do teclado (a barra também faz isso com o clique do meio)
bind = SUPER, K, exec, $kortex keyboard next

# Abrem como janela flutuante: Calculadora, Discos, HyprMod, Visualizador de Imagens e Controle de Volume
windowrule = float on, match:class ^(org\.gnome\.Calculator|org\.gnome\.DiskUtility|io\.github\.bluemancz\.hyprmod|org\.gnome\.Loupe|org\.pulseaudio\.pavucontrol)$
```

O `hyprland.conf` que o `arch-setup.sh` cria já traz essa regra de janelas flutuantes (seção *janelas*). Para incluir outro programa, acrescente a classe dele (veja com `hyprctl clients`) numa regra igual no `user.conf`.

Se um arquivo carregado depois (como o de uma ferramenta gráfica de configuração do Hyprland) redefine um desses atalhos, o dele prevalece: o `SUPER+E` pode continuar abrindo um explorador fixo, por exemplo.

**Manter Acordado.** `SUPER+SHIFT+A` liga e desliga (IPC: `qs -c kortex ipc call keepAwake toggle`); um aviso rápido no canto confirma (ele não entra no histórico e aparece mesmo com o Não Perturbe). Ligado, o computador não bloqueia, não apaga a tela e não suspende por inatividade: o Kortex faz o pedido de inibição de ociosidade do Wayland, que o `hypridle` respeita (a menos que o `hypridle.conf` tenha `ignore_wayland_inhibit = true`). Fechar a tampa, suspender pelo menu de sessão e `SUPER+CTRL+L` continuam funcionando. A escolha não é salva: ao reiniciar o shell ou a sessão, volta a desligado.

**Avisos de volume, brilho e travas (OSD).** Ao mudar o volume ou o brilho pelas teclas do teclado ou por atalhos, e ao ligar ou desligar o Caps Lock ou o Num Lock, aparece por 1,5 s um aviso discreto no centro, embaixo da tela (acima da barra, se ela estiver embaixo), no monitor em foco: ícone, barra e porcentagem para volume e brilho; ícone e "ativado"/"desativado" para as travas. Ele não recebe cliques. O volume é o da saída de som padrão (também vale para a roda do mouse no ícone de som da barra e para outros programas; esmaecido quando está no mudo) e não aparece com o painel de Som aberto; o brilho vem da luz de fundo (o kernel avisa cada mudança, lida pelo `udevadm monitor`) e não aparece com o painel da Tela aberto. As travas usam dois atalhos do Hyprland que não consomem a tecla (`bindn` em `Caps_Lock` e `Num_Lock`), criados pelo Kortex ao vivo pelo `hyprctl`, sem gravar no `hyprland.conf`, e refeitos quando o Hyprland recarrega; eles chamam `qs -c kortex ipc call osd locks`, que lê o estado do teclado principal (`hyprctl devices`).

**Mover e redimensionar com o mouse.** O `hyprland.conf` que o `arch-setup.sh` cria traz `bindm = SUPER, mouse:272, movewindow` e `bindm = SUPER, mouse:273, resizewindow`: **SUPER + botão esquerdo** arrastando move a janela e **SUPER + botão direito** arrastando a redimensiona pelo canto mais próximo do ponteiro. Para mudar só a largura, clique (com o direito) perto da borda da esquerda ou da direita e arraste só para o lado; para mudar só a altura, perto da borda de cima ou de baixo e arraste só para cima ou para baixo. Com o SUPER apertado o botão esquerdo sempre move, mesmo sobre a borda. Para redimensionar puxando a borda sem tecla nenhuma, ligue `resize_on_border = true` no bloco `general` (vem desligado).

> Os arquivos `hyprland-colors.conf`, `monitors.conf` e `hyprland-terminal.conf` só existem depois do primeiro tema aplicado, da primeira configuração de tela confirmada e da primeira abertura do shell. Abra o shell uma vez antes de adicionar as linhas `source`, ou crie os arquivos vazios com `mkdir -p ~/.local/state/kortex && touch ~/.local/state/kortex/{hyprland-colors,monitors,hyprland-terminal}.conf`.

## 4. Uso

**Barra.** Esquerda: lançador (clique direito abre temas), áreas de trabalho (5 por padrão, até 10 nas Configurações; a roda do mouse alterna; a atual tem uma linha em cima do número e as que têm janela aberta, uma linha embaixo, idêntica; a atual com janelas mostra as duas), o widget **Recursos** (por padrão CPU e memória; GPU, memória de vídeo e armazenamento se ligam na engrenagem do painel; clique abre o painel, clique direito abre o `btop`). Centro: relógio → calendário (o **clique do meio** no relógio alterna o formato dele: `Sábado 11:46`, `Sáb 19 set 11:46`, `19/09/2026 11:46`, `Sáb 19 set` ou só `11:46`; a escolha fica salva);  clima → previsão de 7 dias; o botão *Cidade* abre uma janela para digitar o local (`Enter` salva, `Esc` cancela, vazio = automático). Direita: teclado, Bluetooth, Wi‑Fi, som (roda ajusta o volume), tela (brilho e luz noturna), notificações, energia e sessão. O widget **Energia** mostra na barra só o ícone da bateria, sem a porcentagem (o ícone acompanha a carga e fica vermelho com 15% ou menos fora da tomada; sem bateria, é um raio); o painel tem os modos de energia *Economia*, *Equilibrado* e *Desempenho*, em três botões só com o ícone (folha, balança e velocímetro) que dividem a largura do painel; uma etiqueta à direita do título *Energia* mostra o nome do modo em uso, na cor de acento, e o do modo sob o mouse (o botão do modo em uso fica destacado; *Desempenho* só aparece se a máquina tiver esse modo, e um aviso amarelo diz quando ele está limitado por temperatura) e a ficha da bateria: estado (carregando, na bateria, na tomada sem carregar, carga completa), carga, tempo restante ou até completar, consumo, energia atual, capacidade atual e de fábrica, saúde (capacidade atual ÷ de fábrica), ciclos de carga, tensão, temperatura, tecnologia, fabricante, modelo e data de fabricação; o que a bateria não informa fica de fora. Os modos vêm do `power-profiles-daemon` (seção 1) e os dados da bateria, de `/sys/class/power_supply`. O menu de sessão mostra Bloquear, Suspender, Sair, Reiniciar, UEFI (reinicia direto no utilitário de configuração UEFI da placa-mãe) e Desligar em botões pequenos só com o ícone (cadeado, lua, porta com seta, seta circular, placa e botão de ligar), numa linha; ao passar o mouse, o nome da ação aparece numa etiqueta à direita do título *Sessão*. Sair, reiniciar, UEFI e desligar pedem um segundo clique para confirmar: o botão fica vermelho, uma barrinha mostra os 3 s restantes e a etiqueta, também vermelha, diz *Confirmar?*

**Reordenar a barra.** Segure qualquer item da barra (menos o lançador e as áreas de trabalho, que ficam fixos no começo) por meio segundo e arraste: uma cópia dele acompanha o cursor, o lugar de origem fica apagado e um traço na cor de acento mostra onde ele vai cair. Soltando, a ordem é gravada na hora, em todos os monitores. Na barra inteira, o item pode mudar de grupo (esquerda, centro ou direita) e um grupo pode ficar vazio; na flutuante, que é uma fileira só, ele vai para qualquer posição dela. As duas guardam ordens separadas: a flutuante começa com a ordem da barra inteira (esquerda, centro e direita em sequência) e passa a ter a sua assim que você arrasta algo nela. Soltar longe da barra (mais de 40 px acima ou abaixo dela) cancela. Segurar o botão faz o clique não acontecer, então um clique demorado não abre o painel. Para voltar à ordem original, use *Restaurar ordem padrão* em *Configurações › Barra* (ou *Restaurar padrões*, na aba Geral).

**Configurações do Kortex.** Uma janela única reúne as opções de aparência e comportamento. Abra pela engrenagem ao lado da estrela no lançador, digitando `config`, `kortex`, `ajustes` ou `fonte` na busca do lançador, com `SUPER+,` (se você adicionou o atalho da seção 3) ou por `qs -c kortex ipc call settings toggle` (`... settings open bar` abre direto uma página). Tudo vale na hora e fica salvo em `settings.json`.

- *Aparência*: **fonte principal** e **fonte dos títulos** (lista das famílias instaladas, com busca, cada uma mostrada na própria fonte; o padrão volta pelo botão *Padrão*), tamanho do texto (pequeno 11, normal 12 ou grande 13), **raio dos cantos** (0 a 20 px), **espessura das bordas** (valores inteiros, de 0 a 5 px; em 0 as bordas somem) e a opção de aplicar as duas também às janelas do Hyprland (nas janelas a espessura segue a escala da tela, porque o Hyprland só aceita valores inteiros em pixels lógicos: a 1.6×, 1 px vira 2 pixels). Essa opção usa o `hyprctl` ao vivo, não grava no `hyprland.conf` e se reaplica quando o Hyprland recarrega; ao desligar, voltam os seus valores. A seção **Terminal** ajusta a **opacidade do terminal** (de 30% a 100%, de 5 em 5; o padrão é 85%) e liga ou desliga o **desfoque** (ligado por padrão); veja *Terminal (Kitty)*. Os ícones não dependem da fonte principal: vêm da fonte Material Symbols empacotada no Kortex (veja *Ícones*).
- *Animações*: liga ou desliga **todas as animações** (do Hyprland e do Kortex), a **intensidade** (*Sóbria*, sem efeito de mola e com movimentos curtos; *Elegante*, o padrão; *Intensa*, com mola mais forte e movimentos maiores), a **velocidade** (*Lenta*, *Normal* ou *Rápida*), a **abertura das janelas** (*Crescer* a partir do centro, *Deslizar* da borda mais próxima ou *Desdobrar* de uma linha, como no GNOME), a **troca de área de trabalho** (*Horizontal*, *Vertical* ou *Esmaecer*) e um botão que mostra um **aviso de exemplo**. Tudo vale na hora, inclusive para as janelas já abertas.
- *Barra*: **estilo** (*Inteira*, o padrão, de ponta a ponta e colada à borda da tela; ou *Flutuante*, solta da borda e das laterais por 8 px, centralizada, só da largura do conteúdo, com o raio e a borda dos painéis e sem seções: o lançador, as áreas de trabalho e todos os itens numa fileira só, com o mesmo espaço entre eles), **borda da barra flutuante** (ligada por padrão; desligada, a barra flutuante fica sem contorno, sem mudar a borda dos painéis), **posição** (topo ou fundo; no fundo os painéis abrem para cima), **altura** (compacta 24 px, padrão 30 px ou confortável 36 px), **quantidade de áreas de trabalho** (1 a 10; os atalhos `SUPER+6…0` e `SUPER+SHIFT+6…0` além da quinta área são criados pelo Kortex ao vivo, os de 1 a 5 vêm do seu `hyprland.conf`), relógio de 24 horas, **Restaurar ordem padrão** (desfaz a ordem dos itens mudada arrastando na barra, nos dois estilos) e **quais itens aparecem** (Recursos, Clima, Teclado, Bluetooth, Rede, Som, Tela, Notificações, Energia e Sessão).
- *Aplicativos*: **terminal**, **explorador de arquivos** e **navegador**, escolhidos entre os instalados (o Kortex lê as categorias dos `.desktop`). O terminal vale para o shell e para o `SUPER+ENTER`; o explorador e o navegador viram também o padrão do sistema (`xdg-mime`, gravado em `~/.config/mimeapps.list`), o que decide, por exemplo, o que abre ao clicar em "mostrar na pasta". A tela avisa quando o padrão atual para pastas não é um explorador de arquivos (é o caso do `kitty-open`, que abre pastas num terminal).
- *Sessão*: quais botões o widget de sessão mostra (Bloquear, Suspender, Sair, Reiniciar, UEFI, Desligar) e se sair, reiniciar, UEFI e desligar pedem confirmação.
- *Sobre*: créditos do desenvolvimento e dos projetos em que o Kortex se apoia: Arch Linux, Wayland, Hyprland e Quickshell (botão no pé da lista de páginas).
- *Geral*: Não Perturbe, duração dos avisos (3 a 15 s), abrir o lançador só com os favoritos e **Restaurar padrões**, que desfaz a aparência (fontes, cantos, bordas e terminal), as animações e a barra, inclusive a ordem dos itens (não mexe no tema, no papel de parede nem nos aplicativos).

**Teclado e idioma.** O ícone de teclado mostra o layout ativo (`US`, `BR`…). O clique abre a troca rápida entre os layouts configurados, o clique do meio passa para o próximo e o clique direito abre a janela de **Teclado** e **Idioma**.

- *Teclado*: adicione layouts buscando por nome ou código (ex.: `portuguese`, `br`, `dvorak`; `Enter` adiciona o primeiro resultado), reordene, remova (até 4, limite do XKB) e escolha o atalho para alternar (Alt+Shift, Ctrl+Shift, Alt+Espaço ou Caps Lock; Super+Espaço não entra porque o Hyprland o usa para o lançador). Um campo de teste ajuda a conferir o resultado. As mudanças valem na hora, ficam em `settings.json` e são reaplicadas quando o shell inicia e quando o Hyprland recarrega a configuração, então prevalecem sobre o `kb_layout` do `hyprland.conf`. Esses layouts valem na sessão do Hyprland; *Gravar no Sistema* (`localectl set-x11-keymap`) estende a escolha ao console (TTY) e à tela de login e pede a senha de administrador. Os nomes dos layouts vêm do xkeyboard-config, em inglês.
- *Idioma*: mostra o idioma do sistema (`LANG` em `/etc/locale.conf`) e lista os idiomas do `/etc/locale.gen`. Um idioma já gerado é definido com `localectl set-locale`; um que ainda não foi gerado é habilitado no `locale.gen`, gerado com `locale-gen` e definido, tudo num só passo com a senha pedida pelo polkit (`hyprpolkitagent`). Só vale a partir do próximo login. A aba também tem a opção de relógio de 24 horas.

**Tela.** O painel do ícone de monitor (amarelo com a luz noturna ligada) controla brilho, luz noturna e, para o monitor daquela barra, **resolução**, **taxa de atualização** e **escala** (1×, 1.25×, 1.6×; edite `Monitors.scales` em `services/Monitors.qml` para outros valores). Escolha e clique em *Aplicar*: a nova configuração fica em teste por 15 s e volta sozinha ao modo anterior se você não confirmar (`Enter` mantém, `Esc` reverte), o que evita ficar preso numa tela preta. Só o que foi confirmado é gravado em `~/.local/state/kortex/monitors.conf`, que o Hyprland carrega (veja o `source` na seção 3), então vale também após reload e relogin.

**Rede.** O painel do ícone de rede mostra, logo abaixo do título, um cartão com a conexão em uso (no topo, o nome da rede, a interface e, no Wi‑Fi, o sinal; embaixo, um bloco para IP (sem o prefixo de rede), gateway, DNS e MAC, e outro de largura inteira para o IPv6 quando há um endereço global; com cabo e Wi‑Fi ao mesmo tempo, vale a que tem o gateway, e o cabo em caso de empate) e depois lista as redes Wi‑Fi, com um cadeado fechado nas que pedem senha e aberto nas abertas (clique conecta; numa rede nova pede a senha numa janela própria e só fecha se conectar; se falhar, mostra o motivo). *Configurações de Rede*, o clique direito no ícone ou o clique na linha do cabo abrem o **editor de conexões**, que substitui o `nm-connection-editor`: escolha uma conexão salva (Wi‑Fi ou cabo) e edite conectar automaticamente, senha do Wi‑Fi, IPv4 (DHCP ou manual, com endereço, máscara ou prefixo e gateway), servidores DNS e IPv6. `Tab` troca de campo, `Enter` aplica, `Esc` fecha. *Aplicar* reconecta a rede se ela estiver ativa. As entradas são validadas antes de chegar ao NetworkManager. Rede que não responde em 30 s falha com mensagem em vez de travar. Dá para *Conectar*, *Desconectar* e *Esquecer* (pede confirmação) por lá.

**Lançador.** Digite para buscar (busca aproximada, aplicativos mais usados sobem). `↑ ↓`, `Tab`, `Ctrl+J/K` navegam; `Enter` abre; `Esc` fecha. **Favoritos:** a estrela na linha do aplicativo (ou `Ctrl+D` no selecionado) marca e desmarca (na lista só de favoritos ela aparece na linha selecionada ou sob o mouse, já que todas seriam favoritas; na lista de todos os aplicativos, também nas favoritas); o botão de estrela ao lado da busca (ou `Ctrl+F`) alterna entre só os favoritos e todos os aplicativos. O lançador **abre nos favoritos por padrão** (sem nenhum favorito ele avisa e mostra como marcar; clique na estrela ou use `Ctrl+F` para ver tudo), e a última escolha fica salva. Comece com `>` para executar um comando no shell, por exemplo `> firefox --private-window`.

**Temas.** Temas embutidos: Gilmour, Hendrix, Knopfler, Morello (o padrão), Santana, Van Halen, Vaughan e Matugen (cores geradas do papel de parede; veja abaixo). Os temas que você salva do Matugen ficam em `~/.local/share/kortex/themes/`. No seletor, o Matugen vem sempre primeiro e os demais em ordem alfabética; cada cartão mostra o nome do tema e as suas 16 cores em duas linhas de oito: fundo, fundo alternativo, fundo escuro, texto, texto forte, texto fraco, acento e acento 2; depois apagado, seleção, vermelho, verde, amarelo, azul, magenta e ciano (as que o tema não define aparecem como o Kortex as calcula). O cartão do Matugen mostra as mesmas 16 cores por cima do papel de parede.

**Formato dos temas.** Todo tema é uma pasta com dois arquivos e uma pasta: `colors.toml` (as cores: `accent`, `foreground`, `background`, `cursor`, `selection_foreground`, `selection_background` e `color0` a `color15`; também valem chaves como `muted`, `selection`, `dark_background`, `lighter_background`, `bright_foreground`, `red` ou `blue`, e um tema claro leva `mode = "light"`), `icons.theme` (uma linha com o nome do tema de ícones, como `Yaru-blue`) e `backgrounds/` (os papéis de parede). Os temas embutidos, o Matugen e os temas salvos dele já vêm com o `icons.theme`, que o Kortex escolhe pela variante do **Yaru** com a tonalidade mais próxima do acento (a versão `-dark` em tema escuro); o mesmo vale para uma pasta de tema sem esse arquivo. Ao aplicar um tema, o tema de ícones vai para os apps GTK (`gsettings` e o `gtk-icon-theme-name` dos `settings.ini` do GTK 3 e 4 que existirem), se estiver instalado (pacote `yaru-icon-theme`, do AUR, que o `arch-setup.sh` instala); se não estiver, os ícones atuais ficam.

**Contraste garantido.** Na interface do Kortex, algumas cores do tema são ajustadas só o necessário para ficarem legíveis (regras de contraste WCAG): o texto apagado chega a 4,5:1 sobre o fundo e os cartões; o vermelho, o verde e o amarelo, a 4,5:1 sobre o fundo; o contorno de botões, campos e cartões, a 3:1; e o acento, a 4,5:1 sobre o fundo (no Morello e no Vaughan ele fica um pouco mais claro). O texto sobre o acento (botões e opções escolhidas) e sobre o vermelho (confirmações) é a cor do tema que mais contrasta, ou preto ou branco. A linha escolhida de uma lista (dispositivo de som em uso, fonte, layout, aplicativo selecionado) tem o fundo do cartão com um toque do acento. Nada disso muda o arquivo do tema nem as cores que vão para o Kitty, o Hyprland, a tela de bloqueio e a de login. Os números usam vírgula decimal (`46,3 W`, `1,25×`) e os nomes dos layouts de teclado vêm traduzidos (a tradução oficial do `xkeyboard-config`, lida com o `msgunfmt` do `gettext`).

**Teclado nas janelas.** Nas janelas do Kortex (Configurações, temas, rede, idioma, captura de tela e as outras que recebem o teclado), `Tab` e `Shift+Tab` passam por botões, opções, interruptores e campos; o que está com o foco ganha um contorno no acento, e `Espaço` ou `Enter` o aciona. Os painéis da barra são só de mouse (o Wayland não entrega o teclado a eles).

**Cores do papel de parede (Matugen).** O tema **Matugen** gera a paleta a partir do papel de parede em uso, com o [Matugen](https://github.com/InioX/matugen) (Material You; pacote `matugen`, já incluído no `arch-setup.sh`). Ele aparece no seletor de temas como um cartão com o papel de parede e as cores geradas por cima, e as opções dele ficam no próprio cartão, no alto da imagem: **lua ou sol** (modo Escuro ou Claro) e o botão do **Estilo**, que abre a lista das variantes (`qs -c kortex ipc call themes matugen` abre o seletor na aba Temas). Escolher o cartão Matugen na aba Temas ou `qs -c kortex ipc call themes set matugen` liga o tema dinâmico: gera as cores da imagem atual, sem trocá-la (para trocar de papel de parede, use a aba Papéis de Parede). Enquanto o tema estiver ativo, **cada troca de papel de parede gera as cores de novo** (escolher uma imagem, o papel de parede aleatório do `SUPER+CTRL+W` ou excluir a atual), e tudo o que segue o tema acompanha: barra e painéis, bordas do Hyprland, tela de bloqueio e de login, Kitty, btop, Firefox e apps do GNOME. O **Estilo** é a variante do Matugen: Tonal (o padrão), Vibrante, Expressivo, Neutro, Fiel, Conteúdo, Monocromático, Arco-íris, Salada de frutas e Automático. **Com o tema ativo, trocar o modo ou o estilo regera as cores na hora e tudo acompanha**; com ele desligado, só as cores do cartão mudam, para mostrar o resultado, e o tema em uso continua o mesmo (clicar no cartão liga o Matugen já com essas escolhas). O acento, os fundos, o texto e a seleção vêm da imagem; vermelho, verde, amarelo, azul, magenta e ciano têm tons fixos (`kortex/matugen/semantic-dark.json` e `semantic-light.json`, editáveis), iguais em qualquer imagem e estilo, porque alguns estilos do Matugen girariam o matiz (o vermelho viraria lilás) ou tirariam toda a cor (Monocromático). O resultado é gravado em `~/.local/share/kortex/themes/matugen/colors.toml` (com o `icons.theme` escolhido pelo acento gerado) e a correspondência entre as cores do Matugen e as do Kortex está no modelo `kortex/matugen/colors.toml`, que pode ser editado. O Kortex chama o Matugen só com um config temporário: a sua configuração pessoal (`~/.config/matugen`) não é lida nem alterada. Sem o Matugen instalado, o tema avisa como instalar e nada muda; se a geração falhar (imagem ilegível), o tema em uso é mantido. Excluir o tema Matugen gerado faz voltar o tema-base embutido, até gerar de novo. O ícone de **disquete** no rodapé do cartão abre um campo para o nome (`Enter` salva, `Esc` cancela): as cores atuais (papel de parede, modo e estilo escolhidos) são gravadas como um **tema novo e independente**, com esse nome, e ele **passa a ser o tema em uso**. Ele existe como qualquer outro tema no seletor (com o papel de parede usado como capa) e não muda mais quando o Matugen gerar de novo ou você trocar de papel de parede.

**Renomear um tema.** Os temas da sua pasta (`~/.local/share/kortex/themes/`: os salvos do Matugen) têm um lápis no rodapé do cartão (ou `F2` no tema selecionado): ele abre um campo com o nome atual; `Enter` renomeia e `Esc` cancela. O nome vira o da pasta do tema, como ao salvar (minúsculas, sem acento, espaços viram hífen; o cartão mostra cada palavra com inicial maiúscula). Se for o tema em uso, ele continua em uso com o nome novo, e o papel de parede lembrado acompanha. Os temas embutidos não podem ser renomeados (voltariam com o nome antigo ao reinstalar o Kortex), nem o Matugen, cujo nome é reservado.

**Excluir um tema.** Cada tema das pastas do Kortex (embutidos e os da sua pasta) tem uma lixeira discreta no cartão. Ela pede confirmação: o primeiro clique mostra *Excluir?* (em vermelho, por 3 s) e o segundo exclui. Também dá para usar o **clique direito** no cartão ou a tecla **Delete** (navegue até o cartão com ↓). Se o tema estava ativo, o Kortex troca para outro antes de apagar e, se o papel de parede em uso estava dentro da pasta dele, passa para um que você já usou. Os temas embutidos voltam ao reinstalar o Kortex. O último tema restante fica protegido contra exclusão.

**Borda dos painéis.** A borda de todos os painéis (popups da barra, lançador, janelas de temas, teclado, rede…) e dos avisos flutuantes tem cor sólida: o acento do tema. A espessura (0 a 5 px) vem de *Espessura das bordas*, em Configurações → Aparência. Avisos críticos seguem em vermelho. A espessura é contada em pixels reais da tela, com qualquer escala: 1 px é sempre 1 pixel, 2 px são 2 pixels (a 1.6× ou a 2×, a borda não engrossa junto com a interface). Com escala fracionária (como 1.6×) o tamanho das janelas dos painéis e dos avisos é ajustado a múltiplos que caibam num número inteiro de pixels físicos (a 1.6×, de 5 em 5 px lógicos; por isso um painel pode ganhar até 4 px de altura), para a borda ter a mesma largura e ficar nítida em todos os lados. A mesma regra vale para as caixas com borda fina, que têm 1 pixel real (campos de texto, botões, chips, interruptores, cartões de tema e de aviso): o componente `widgets/GradientBorder.qml` desenha contorno e preenchimento juntos, alinhados à grade de pixels da janela. A segunda cor do tema, `accent2` (a do `colors.toml` ou, sem ela, o acento 45% mais escuro), não entra mais nos painéis: só compõe o contorno em degradê do `hyprlock` e da tela de login.

**Ícones.** Todos os ícones de interface são os do Google (**Material Symbols**, estilo *Outlined*, peso 400, de [fonts.google.com/icons](https://fonts.google.com/icons)). A fonte vai dentro do Kortex (`kortex/fonts/`, licença Apache-2.0 incluída), então não precisa instalar nada. Cada ícone é escrito pelo nome do catálogo em `services/Icons.qml` (por exemplo `wifi`, `notifications`): para trocar um, ponha outro nome; o peso está em `Icons.weight`. Os ícones são desenhados pelo componente `widgets/Icon.qml`. Só o logo do Arch, no botão do lançador, vem da Nerd Font, porque é uma marca e o Google não a tem.

**Animações.** O Kortex aplica ao vivo um conjunto próprio de animações do Hyprland (`services/Motion.qml` e `services/HyprSync.qml`, sem gravar no `hyprland.conf`, e de novo a cada recarga do Hyprland), com as mesmas curvas em tudo: o que entra chega depressa e assenta devagar, o que sai parte devagar e some depressa. No padrão (intensidade *Elegante*, velocidade *Normal*), as **janelas** abrem crescendo de 80% com um leve efeito de mola (cerca de 450 ms) e fecham encolhendo e esmaecendo, mais depressa; mover e redimensionar desliza suavemente, assim como a troca de cor da borda e o escurecimento das janelas inativas. As **áreas de trabalho** deslizam 20% esmaecendo, e a área especial vem de baixo. O lançador, o seletor de temas, as Configurações, as janelas de rede, cidade, idioma, confirmação de tela e captura de tela e o aviso de volume/brilho crescem do centro com a mesma mola; a barra e o carrossel de papéis de parede deslizam da borda em que estão. Os **painéis da barra** crescem a partir da barra, descendo e surgindo, e ao fechar recolhem em direção a ela; os **avisos** entram deslizando da direita, os que já estavam abrem espaço com suavidade e, ao sair (por tempo, clique ou fechados pelo app), deslizam de volta e esmaecem enquanto os de baixo sobem. Esses dois últimos são animados pelo próprio Kortex (Qt), porque o Hyprland só sabe esmaecer popups. As camadas e os popups de outros programas só esmaecem, na mesma velocidade. Intensidade, velocidade, estilos e o desligamento geral ficam em *Configurações › Animações* (veja acima). As curvas são Bézier: as molas do Hyprland só existem na configuração em Lua. Se você configurar animações no seu `hyprland.conf`, o Kortex as sobrescreve (com as animações desligadas no Kortex, o Hyprland também fica sem animações).

**Cabeçalho dos painéis.** Os painéis da barra e as janelas de cidade do clima, rede (senha e conexões), confirmação de tela e captura de tela começam com o mesmo cabeçalho: um ícone (na cor de acento, sem fundo nem contorno, alinhado ao título principal e não à legenda), o título em fonte maior e numa fonte secundária, a Iosevka Fixed SmBd Ex (pacote `ttc-iosevka`, que o `arch-setup.sh` instala; troque pela chave `titleFont` do `settings.json`, e sem ela o Noto Sans assume), os controles à direita e um filete sólido embaixo, na cor de acento. O título, o ícone e os controles da direita ficam sempre à mesma distância da borda de cima (uma faixa de 38 px de referência), com ou sem legenda: a legenda fica embaixo e só aumenta a altura do painel. Quando há um estado útil, ele aparece numa segunda linha sob o título: o Bluetooth mostra *Desligado* ou quantos dispositivos estão conectados, a Rede mostra o estado (*Conectado*, *Desconectado* ou *Desligado*) e as Notificações avisam quando o *Não Perturbe* está ligado. O ícone do Clima é um pino de localização, o do painel Tela é um monitor, o do Som é um fone de ouvido (riscado no mudo) e o do painel Notificações fica preenchido quando há notificações e troca para o sino cortado no *Não Perturbe*.

Por segurança, **nada dentro do tema é executado**: só são lidos o `colors.toml`, o nome no `icons.theme` e as imagens de `backgrounds/`.

**Seletor rápido de papel de parede.** `SUPER+SHIFT+W`, um clique duplo no papel de parede da área de trabalho ou `qs -c kortex ipc call themes carousel` mostra embaixo um carrossel com as mesmas imagens da aba *Papéis de Parede* (do tema atual e da sua pasta), começando pela que está em uso (marcada *Em uso*). Se a área de trabalho atual tiver janelas, ele leva a uma área vazia do mesmo monitor, para ver o papel de parede de verdade, e volta à anterior ao fechar. As setas, a roda do mouse, arrastar ou clicar numa imagem trocam o papel de parede na hora, com um esmaecimento suave, como prévia; `Enter` ou um clique na imagem do centro aplica; `Esc` ou um clique fora do carrossel cancela e volta ao papel de parede anterior. Nada é gravado antes de aplicar; no tema Matugen, as cores só são geradas ao aplicar. O carrossel dá a volta: depois da última imagem vem a primeira.

**Papéis de Parede.** A aba mostra os fundos do tema atual e os da sua pasta (padrão `~/Pictures/Wallpapers`, alterável na própria aba). Com o tema Matugen ativo, escolher uma imagem aqui já gera as cores dela e troca tudo na hora (veja acima). Para excluir um papel de parede, use o ícone de lixeira no canto da imagem (aparece ao passar o mouse e na imagem selecionada), o clique direito ou a tecla `Delete`: o primeiro toque pede confirmação e o segundo **move o arquivo para a Lixeira** (dá para recuperar pelo gerenciador de arquivos; se a Lixeira falhar, nada é apagado). Só podem ser excluídos arquivos da sua pasta de papéis de parede, de `~/.local/share/kortex/backgrounds` e dos temas do próprio Kortex. Se o papel de parede em uso for excluído, o Kortex passa para o vizinho na lista.

**Recursos.** O painel tem um bloco por componente, com o que a máquina informa (linhas sem dado somem) e a temperatura sempre na primeira linha: *CPU* (temperatura, carga média e threads), *RAM* (temperatura dos módulos e quanto está em uso), *GPU* (temperatura, consumo e memória de vídeo) e *Armazenamento* (temperatura do disco, usado e livre). Havendo mais de uma GPU ou disco, os demais aparecem como subseções do mesmo bloco. A **engrenagem** do painel abre a tela *Exibição*, com interruptores para o que aparece na barra (CPU, RAM, GPU, memória de vídeo e armazenamento; por padrão, só CPU e RAM) e, havendo mais de um disco, qual deles vai para a barra. A barra mostra sempre a porcentagem, e um item fica vermelho a partir de 90%. Detalhes: a NVIDIA é lida com o `nvidia-smi` e a AMD pelo sysfs; a Intel não informa uso sem root, então mostra só a frequência (e fica fora da barra). Numa GPU dedicada em repouso (notebooks híbridos) o Kortex não a consulta, para não acordá-la e gastar bateria: ela aparece como *em repouso*. O consumo da CPU não é exibido porque o kernel restringe o RAPL ao root. A temperatura do disco só aparece para NVMe ou SATA com o módulo `drivetemp`. O armazenamento junta subvolumes do mesmo disco (btrfs) num só e omite `/boot`. GPU e armazenamento só são consultados quando a barra os mostra ou o painel está aberto; as temperaturas, só com o painel aberto. O botão *Monitor do Sistema*, no pé do painel, abre o `btop` no terminal (o mesmo que o clique direito no widget).

**Captura de tela.** A tecla `Print` (ou `qs -c kortex ipc call screenshot toggle`) abre o menu *Captura de Tela* com três opções: **Tela Inteira** (o monitor em que o menu abriu), **Janela** (as janelas visíveis ganham um contorno; clique na que quer capturar) e **Área** (arraste um retângulo; o tamanho aparece durante a seleção). As teclas `1`, `2` e `3` também escolhem, e `Esc` no menu ou durante a seleção cancela sem salvar nada. O menu some antes da captura, então ele não sai na imagem, e nem o cursor nem a marcação da seleção saem (com o cursor desenhado por software, o padrão do Hyprland em máquinas com NVIDIA, o Kortex o passa para o plano de hardware só durante a captura; e a marcação do `slurp` fica sem animação de saída). Em seguida abre a janela *Salvar Captura*, com a prévia e o tamanho em pixels, o **nome** (sugerido com a data e a hora; a extensão é posta sozinha), o **formato** (*PNG*, sem perda, ou *JPEG*, menor, com qualidade 90) e a **pasta**: atalhos para *Capturas* (`~/Pictures/Screenshots`), *Imagens*, *Área de Trabalho* e *Downloads* (as pastas do `xdg-user-dirs`, quando existem) e *Pasta Pessoal*, e embaixo a pasta atual com as subpastas dela (clique para entrar; o botão à esquerda do caminho sobe uma pasta). `Enter` salva e um aviso no canto mostra onde; se a pasta não existir, ela é criada. Se já houver um arquivo com o mesmo nome, a janela avisa e o botão vira *Substituir*. *Descartar* ou `Esc` jogam a captura fora; clicar fora da janela não a descarta. A pasta e o formato usados ficam salvos para a próxima vez. A captura usa o `grim` e o `slurp` (o JPEG sai do `cjpeg`, que vem com o `grim`), e enquanto não é salva fica só em `$XDG_RUNTIME_DIR/kortex`. A captura de uma janela grava o retângulo dela como está na tela: o que estiver por cima dela também sai.

## 5. Configuração

As preferências ficam em `~/.local/state/kortex/settings.json` e são recarregadas ao vivo. Campos úteis:

| Campo | Padrão | Função |
|---|---|---|
| `use24h` | `true` | Relógio em 24 h |
| `clockFormat` | `0` | Formato do relógio na barra, de `0` a `4` (na ordem acima); o clique do meio no relógio troca |
| `weatherCity` | `""` | Cidade do clima: `Cidade` ou `Cidade, Estado` (vazio = detecta pelo IP) |
| `mainFont` | `""` | Fonte principal (vazio = JetBrainsMono Nerd Font) |
| `titleFont` | `""` | Fonte dos títulos dos painéis (vazio = Iosevka Fixed SmBd Ex; se não estiver instalada, o Noto Sans) |
| `fontSize` | `12` | Tamanho do texto, de 10 a 16 (a tela oferece 11, 12 e 13) |
| `radius` | `6` | Raio dos cantos arredondados, de 0 a 20 px |
| `borderWidth` | `2` | Espessura da borda dos painéis, inteiro de 0 a 5 px (um valor fracionário antigo é arredondado) |
| `hyprSyncAppearance` | `false` | Aplica também `borderWidth` e `radius` às janelas do Hyprland (via `hyprctl`, sem gravar no `hyprland.conf`) |
| `terminalOpacity`, `terminalBlur` | `85`, `true` | Opacidade do fundo do Kitty, de 30 a 100 (%), e o desfoque do que aparece por trás dele |
| `animations` | `true` | Liga as animações (do Hyprland e do Kortex); `false` desliga todas |
| `animIntensity` | `"elegant"` | Intensidade das animações: `"subtle"`, `"elegant"` ou `"intense"` |
| `animSpeed` | `"normal"` | Velocidade das animações: `"slow"`, `"normal"` ou `"fast"` |
| `animWindows` | `"popin"` | Abertura das janelas: `"popin"` (crescer), `"slide"` (deslizar) ou `"gnomed"` (desdobrar) |
| `animWorkspaces` | `"horizontal"` | Troca de área de trabalho: `"horizontal"`, `"vertical"` ou `"fade"` (esmaecer) |
| `barPosition` | `"top"` | `"top"` ou `"bottom"` |
| `barStyle` | `"full"` | Estilo da barra: `"full"` (inteira, de ponta a ponta, com esquerda, centro e direita) ou `"floating"` (flutuante, centralizada, arredondada e numa fileira só) |
| `barBorder` | `true` | Borda na barra flutuante (a espessura é a de `borderWidth`); `false` deixa só a barra sem contorno |
| `barSize` | `"normal"` | `"compact"` (24 px), `"normal"` (30 px, o padrão) ou `"comfortable"` (36 px) |
| `workspaceCount` | `5` | Áreas de trabalho mostradas na barra (1 a 10) |
| `barItems` | `{}` | Itens escondidos da barra, por exemplo `{ "weather": false }`; ausente = visível (`stats`, `weather`, `keyboard`, `bluetooth`, `network`, `audio`, `display`, `notifications`, `energy`, `power`) |
| `barLayout` | `{}` | Ordem dos itens da barra por grupo, por exemplo `{ "left": ["stats"], "center": ["clock", "weather"], "right": ["keyboard", …] }`; vazio = ordem padrão. Ids desconhecidos ou repetidos são ignorados e um item que falte volta ao fim do seu grupo padrão (inclui `clock`) |
| `barFloatingOrder` | `[]` | Ordem dos itens na barra flutuante (uma lista só), por exemplo `["clock", "weather", "stats", …]`; vazio = a ordem da barra inteira em sequência |
| `powerActions` | `{}` | Botões de sessão escondidos, por exemplo `{ "suspend": false }` (`lock`, `suspend`, `logout`, `reboot`, `firmware`, `shutdown`) |
| `powerConfirm` | `true` | Sair, reiniciar, UEFI e desligar pedem um segundo clique |
| `toastSeconds` | `6` | Segundos que um aviso flutuante fica na tela |
| `screenshotDir`, `screenshotFormat` | `""`, `"png"` | Pasta e formato (`png` ou `jpeg`) da última captura de tela salva, que a janela de salvar sugere na próxima (vazio = `~/Pictures/Screenshots`) |
| `terminal` | `""` | Terminal usado pelo shell, por exemplo ao abrir o `btop` (vazio = detecta, começando pelo `kitty`) |
| `fileManager`, `browser` | `""` | Ids dos `.desktop` (sem o sufixo) escolhidos em Configurações › Aplicativos; vazio = o padrão do sistema |
| `theme` | `"morello"` | Tema ativo (nome da pasta do tema; o seletor de temas escreve aqui) |
| `wallpaper`, `wallpaperDir` | `""`, `"~/Pictures/Wallpapers"` | Papel de parede atual e a pasta de onde vêm os papéis de parede |
| `matugenMode`, `matugenScheme` | `"dark"`, `"scheme-tonal-spot"` | Modo (`dark` ou `light`) e variante do Matugen (`scheme-…`) das cores geradas do papel de parede; o seletor de temas escreve aqui |
| `dnd` | `false` | Não Perturbe (silencia os avisos flutuantes) |
| `wallpaperEnabled` | `true` | `false` se preferir outro programa de papel de parede |
| `hyprBorders` | `true` | Pinta as bordas das janelas com a cor do tema |
| `favoriteApps` | `[]` | Aplicativos favoritos do lançador (ids dos `.desktop`, ex.: `firefox`) |
| `launcherFavoritesOnly` | `true` | O lançador abre listando só os favoritos (`false` = todos os aplicativos) |
| `lockCommand` | `pidof hyprlock \|\| hyprlock` | Comando de bloqueio |
| `audioApp` | `pavucontrol` | App de configuração avançada de som |
| `nightLight` | `false` | Luz noturna ligada (o clique do meio no ícone de tela também alterna) |
| `nightLightTemp` | `4500` | Temperatura da luz noturna (K) |
| `statsCpu`, `statsMem`, `statsGpu`, `statsVram`, `statsDisk` | `true`, `true`, `false`, `false`, `false` | O que o widget Recursos mostra na barra (também na engrenagem do painel) |
| `statsDiskMount` | `"/"` | Armazenamento mostrado na barra, pelo ponto de montagem |
| `keyboard` | `{}` | Layouts e atalho de alternância escolhidos na janela de teclado (vazio = usa o que o Hyprland já tem) |

O arquivo guarda ainda `themeWallpapers` (o papel de parede de cada tema), `monitorRules` (as telas confirmadas no widget de tela) e `appUsage` (o uso do lançador). O próprio shell os mantém; não é preciso editá-los.

## 6. Levando o tema a outros programas

A cada troca de tema são gerados em `~/.local/state/kortex/`:

- `colors.sh` — variáveis de shell (`source` em scripts)
- `colors.css` — `@define-color` para GTK/wofi etc.
- `hyprland-colors.conf` — variáveis (`$kortex_accent`, `$kortex_accent2`, `$kortex_bg`, `$kortex_bg_alt`, `$kortex_fg`, `$kortex_fg_bright`, `$kortex_fg_dim`, `$kortex_muted`, `$kortex_red`, `$kortex_yellow`), lidas pelo Hyprland e pelo `hyprlock`
- `kitty-theme.conf` — cores do Kitty (veja *Terminal* abaixo)
- `current-theme` — link para a pasta do tema (útil para ler o `colors.toml` ou o `icons.theme` do tema)

**Tela de bloqueio.** O `hyprlock` usa as cores do tema ativo: o `~/.config/hypr/hyprlock.conf` que o `arch-setup.sh` cria começa com valores padrão (Morello) e depois faz `source = ~/.local/state/kortex/hyprland-colors.conf`, então cada troca de tema vale no próximo bloqueio (fundo, relógio, campo de senha, contorno em degradê e as cores de verificação e erro). Se você já tinha um `hyprlock.conf` (o instalador não sobrescreve), use as variáveis nele:

```ini
# valores padrão: valem se o arquivo do tema ainda não existir
$kortex_accent = rgb(686868)
$kortex_accent2 = rgb(393939)
$kortex_bg = rgb(222222)
$kortex_bg_alt = rgb(343434)
$kortex_fg_bright = rgb(ffffff)
$kortex_red = rgb(7c7c7c)
$kortex_yellow = rgb(a0a0a0)
source = ~/.local/state/kortex/hyprland-colors.conf

background {
    color = $kortex_bg
}
label {
    color = $kortex_fg_bright
}
input-field {
    outer_color = $kortex_accent $kortex_accent2 45deg
    inner_color = $kortex_bg_alt
    font_color = $kortex_fg_bright
    check_color = $kortex_yellow
    fail_color = $kortex_red
}
```

Os valores padrão vêm antes do `source`, que os sobrescreve com os do tema. Sem o arquivo do tema, o `hyprlock` só registra um aviso e usa os padrões. (Exemplo resumido: o modelo completo, com relógio e tamanhos, é o que o `arch-setup.sh` grava.)

**Terminal (Kitty).** O Kitty é o terminal padrão e acompanha o tema: a cada troca, o shell grava `~/.local/state/kortex/kitty-theme.conf` (`scripts/kitty-theme.sh`, chamado pelo `theme-apply.sh`) e manda os Kitty abertos recarregarem a configuração, então as janelas já abertas mudam de cor na hora. O `~/.config/kitty/kitty.conf` que o `arch-setup.sh` cria termina com `include ~/.local/state/kortex/kitty-theme.conf`; se você já tinha um `kitty.conf`, o instalador só acrescenta essa linha (com backup) e, se você usa o `install.sh`, acrescente-a você mesmo, **por último**, para o tema prevalecer sobre outras cores. Sem a linha, ou antes de o shell gerar o arquivo, o Kitty usa as cores dele e não dá erro.

A paleta vem das cores do tema: fundo, texto, seleção, cursor no acento, vermelho, verde, amarelo, azul, magenta e ciano nas 16 cores ANSI (as versões "brilhantes" repetem as cores normais, exceto preto e branco). Em tema claro, "preto" e "branco" se invertem para continuarem legíveis. Se o `colors.toml` do tema traz as cores de terminal (`color0` a `color15`, `cursor`, `selection_foreground` e `selection_background`), elas valem por cima da paleta gerada. Para mudar outra coisa (fonte, atalhos), edite o `kitty.conf` **antes** da linha `include`; o `kitty-theme.conf` é reescrito a cada troca.

**Terminal translúcido e com desfoque.** O Kitty vem com o fundo a 85% de opacidade e com desfoque, igual em qualquer tema; mude em *Configurações › Aparência › Terminal* (opacidade de 30% a 100% e desfoque ligado ou desligado; vale na hora, inclusive nos Kitty abertos). A opacidade vai para o `~/.local/state/kortex/kitty-window.conf` (`background_opacity`), que o `kitty-theme.conf` inclui, então a linha `include` do `kitty.conf` é a mesma de antes. O desfoque é do Hyprland, não do Kitty: ele desfoca o que aparece por trás de qualquer janela translúcida (`decoration:blur:enabled`, ligado no `hyprland.conf` que o instalador cria). Desligar o desfoque grava uma regra `no_blur` para a classe `kitty` em `~/.local/state/kortex/hyprland-terminal.conf`, que o `hyprland.conf` carrega (`source`), e o Kortex manda o Hyprland recarregar a configuração para valer nas janelas abertas. Um `background_opacity` escrito no seu `kitty.conf` **depois** da linha `include` prevalece sobre o das Configurações; antes dela, o das Configurações vale. Só o Kitty é tratado.

Outros terminais não são tocados automaticamente; use o gancho abaixo. Para abrir um comando no terminal, o shell usa `scripts/term.sh`, que já trata a diferença do Kitty (ele não tem `-e`: o comando vem direto depois das opções).

**Monitor do sistema (btop).** O `btop` acompanha o tema: a cada troca, `scripts/btop-theme.sh` (chamado pelo `theme-apply.sh`) grava `~/.config/btop/themes/kortex.theme` com as cores do tema (texto, acento nos destaques, na linha selecionada e nos nomes dos processos, contornos na cor apagada, degradês de CPU e temperatura até o vermelho, memória em verde, azul, amarelo e vermelho, rede em ciano e magenta) e manda os `btop` abertos recarregarem (`SIGUSR2`), então eles mudam de cor na hora. O fundo fica vazio de propósito: o `btop` usa o do terminal, que já tem a cor do tema e a opacidade das Configurações. O tema `kortex` só é escolhido no `~/.config/btop/btop.conf` se nenhum outro foi (sem o arquivo, sem a linha `color_theme` ou com o `Default`); se você escolheu outro tema no menu do `btop`, ele é respeitado, e para voltar ao do Kortex basta escolher `kortex` lá. Não edite o `kortex.theme`, que é reescrito a cada troca: copie-o com outro nome e escolha a cópia.

**Navegador (Firefox).** O Firefox acompanha o tema na interface (abas, barras, campo de endereço, menus e painéis) e nas páginas internas (nova aba, `about:…`, configurações); os sites ficam como estão. Ele não aceita um tema de extensão sem assinatura da Mozilla nem lê as cores do tema GTK, então o Kortex usa o `userChrome.css` e o `userContent.css` do perfil: `scripts/firefox-setup.sh` instala `chrome/kortex-chrome.css` e `chrome/kortex-content.css` no perfil padrão (o do bloco `[Install…]` do `profiles.ini`, em `~/.mozilla/firefox` ou `~/.config/mozilla/firefox`), põe um `@import` no início do `userChrome.css` e do `userContent.css` (criando-os ou preservando o que já existe, com cópia `.bak-kortex-…`) e liga `toolkit.legacyUserProfileCustomizations.stylesheets` no `user.js` (o `prefs.js` não é tocado). A cada troca de tema o `theme-apply.sh` chama `scripts/firefox-theme.sh`, que regrava `chrome/kortex-colors.css` (as cores e se o tema é claro ou escuro). **O Firefox só lê esses arquivos ao abrir: a troca vale na próxima vez que ele iniciar** (o Kortex não o fecha). O `arch-setup.sh` roda o `firefox-setup.sh` se o Firefox já estiver instalado; num Arch limpo, rode `bash ~/.config/quickshell/kortex/scripts/firefox-setup.sh` depois de abrir o Firefox uma vez. Para desfazer: `firefox-setup.sh --remove`. Se um update do Firefox mudar o nome das variáveis, o arquivo a ajustar é `kortex/firefox/kortex-chrome.css`.

**Apps do GNOME (GTK4/libadwaita).** Nautilus, Calculadora, Editor de Texto e os demais apps GTK4/libadwaita acompanham o tema. `scripts/gnome-setup.sh` põe um `@import` no início de `~/.config/gtk-4.0/gtk.css` (criando-o ou preservando o seu, com cópia `.bak-kortex-…`) e escolhe o esquema de cores `kortex` no Editor de Texto; a cada troca de tema o `theme-apply.sh` chama `scripts/gnome-theme.sh`, que regrava `~/.config/gtk-4.0/kortex-colors.css` (as variáveis de cor do libadwaita: janela, barra de título, barras laterais, cartões, menus, acento, sucesso, aviso e erro), gera o esquema `~/.local/share/gtksourceview-5/styles/kortex.xml` (fundo, seleção e a sintaxe com as cores da paleta do tema) e ajusta o **esquema claro/escuro do sistema** (`gsettings` `color-scheme`) e o `style-variant` do editor. O libadwaita só respeita as variáveis do `:root` (o `@define-color` sozinho dá cores erradas). Os valores anteriores do `gsettings` ficam em `~/.local/state/kortex/gnome-original.txt`, e `gnome-setup.sh --remove` desfaz tudo. Apps já abertos só mudam ao serem reabertos, exceto o claro/escuro, que o libadwaita segue ao vivo. Como o `color-scheme` é do sistema, ele também vale para outros programas (por exemplo, o Firefox informa aos sites que você prefere o escuro). Apps GTK3 (como o Thunar) não são cobertos.

**Tela de login (SDDM).** O `arch-setup.sh` instala o SDDM com o tema próprio do Kortex (`kortex/sddm/`, copiado para `/usr/share/sddm/themes/kortex`): relógio, data, campo de senha com contorno em degradê (o mesmo desenho do `hyprlock`), escolha de usuário e de sessão, layout do teclado, aviso de Caps Lock e botões de suspender, reiniciar e desligar. As cores são as do tema ativo: a cada troca de tema o shell grava o `theme.conf.user` do tema do SDDM (`scripts/sddm-colors.sh`, chamado pelo `theme-apply.sh`), e a tela de login usa essas cores no próximo boot ou logout. O arquivo pertence ao seu usuário, então isso não pede senha. O tamanho da interface acompanha a altura da tela, sem configurar escala. Sem o arquivo, valem as cores do Morello.

Para instalar ou reinstalar só a tela de login (por exemplo, se você usou `install.sh` em vez do `arch-setup.sh`):

```bash
bash ~/.config/quickshell/kortex/scripts/sddm-setup.sh
```

O script instala o pacote `sddm` se faltar, copia o tema, ativa o serviço (`systemctl enable --force sddm`, sem `--now`: vale a partir do próximo boot), pré-seleciona a sessão *Hyprland* e remove do `~/.bash_profile`/`~/.zprofile` o bloco `kortex-autostart` que iniciava o Hyprland no tty1 (com backup ao lado; `--keep-tty-autostart` mantém). Ele pode ser rodado de novo com segurança. O papel de parede não aparece na tela de login: o SDDM roda como outro usuário e não lê a sua pasta pessoal.

Para voltar ao início direto pelo tty1: `sudo systemctl disable sddm` e recoloque no `~/.bash_profile`:

```bash
# >>> kortex-autostart >>>
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" -eq 1 ]; then
    if command -v start-hyprland >/dev/null; then exec start-hyprland; else exec Hyprland; fi
fi
# <<< kortex-autostart <<<
```

Se existir o executável `~/.config/kortex/hooks/theme-set`, ele é chamado com `<nome> <pasta-do-tema> <pasta-de-estado>`. Exemplo para o Alacritty (o Kitty já é tratado pelo shell):

```bash
#!/usr/bin/env bash
# no alacritty.toml:  [general]  import = ["~/.config/alacritty/theme.toml"]
. "$3/colors.sh"
printf '[colors.primary]\nbackground = "%s"\nforeground = "%s"\n' "$KORTEX_BG" "$KORTEX_FG" \
    > ~/.config/alacritty/theme.toml
```

## 7. Solução de problemas

```bash
qs -c kortex log          # log da instância em execução
qs -c kortex --no-duplicate
qs -c kortex kill; qs -c kortex  # reiniciar por completo
```

- **Palavras como `wifi` ou `settings` no lugar dos ícones:** os ícones são a fonte Material Symbols, carregada da pasta `fonts/` do Kortex. Confira se `~/.config/quickshell/kortex/fonts/MaterialSymbolsOutlined.ttf` existe (rode o `install.sh` de novo, se não existir) e **reinicie o shell por completo** (`qs -c kortex kill` e depois `qs -c kortex`): arquivos novos só são reconhecidos ao iniciar, não numa recarga. Um quadrado no botão do Arch (lançador) significa que falta `ttf-jetbrains-mono-nerd`: instale e rode `fc-cache -f`.
- **O Firefox ou os apps do GNOME não mudaram de cor:** eles só leem as cores ao abrir, então feche e abra de novo. Se ainda assim não mudar, rode `bash ~/.config/quickshell/kortex/scripts/firefox-setup.sh` (o Firefox precisa ter sido aberto uma vez) ou `.../gnome-setup.sh`; ambos aceitam `--remove` para desfazer. O Firefox é configurado no perfil padrão; num perfil extra, passe a pasta dele: `firefox-setup.sh ~/.mozilla/firefox/<perfil>`.
- **O tema Matugen diz que o Matugen não está instalado, ou as cores não mudam:** instale com `sudo pacman -S matugen` (o shell só percebe ao reabrir o seletor de temas). Para ver o motivo de uma falha, rode `bash ~/.config/quickshell/kortex/scripts/matugen-generate.sh <imagem> dark`: ele imprime a paleta ou uma linha com o erro.
- **Excluir um papel de parede diz que não foi possível:** a exclusão usa a Lixeira (`gio trash`); se ela falhar (por exemplo, numa pasta sem lixeira disponível), o arquivo não é apagado.
- **O terminal não ficou translúcido ou desfocado:** a opacidade precisa do `include` do `kitty-theme.conf` no `kitty.conf` (seção 4, *Terminal*) e de nenhum `background_opacity` depois dele; o desfoque precisa da linha `source = ~/.local/state/kortex/hyprland-terminal.conf` no `hyprland.conf` (o instalador já a põe) e de `decoration:blur:enabled` ligado no Hyprland. Ao desligar o desfoque, o Hyprland recarrega a configuração: se houver erro, `hyprctl configerrors` mostra.
- **Brilho não aparece:** seu usuário precisa estar no grupo `video` (`sudo usermod -aG video $USER`) ou o monitor é externo sem suporte a DDC.
- **Notificações não chegam:** outro daemon (mako/dunst/swaync) ainda está rodando.
- **Clima vazio ou com erro:** a previsão vem do Open-Meteo (`api.open-meteo.com`) e, no modo automático, a localização vem de `ipinfo.io`. Se a detecção falhar (VPN, rede restrita), defina a cidade no botão *Cidade* do clima. Para nomes repetidos use `Cidade, Estado` (estado/país em português).
- **Não consigo digitar num campo dentro de um popup da barra:** popups não recebem o teclado do Wayland. Campos de texto ficam em janelas próprias (lançador, temas, cidade do clima, senha e configurações de rede, teclado e idioma).
- **Definir o idioma ou gravar o teclado no sistema não faz nada:** essas ações precisam de um agente do polkit rodando para pedir a senha (`systemctl --user start hyprpolkitagent`). Sem ele, o comando falha e a janela mostra o motivo.
- **O Hyprland acusou erro de teclado ou o layout ficou em `US`:** o `arch-setup.sh` grava o `kb_layout` e o `kb_variant` do bloco `input` do `hyprland.conf` a partir do layout X11 do `localectl` (se não houver, do `KEYMAP` do console) e só aceita códigos que existem no xkeyboard-config; um código desconhecido é ignorado, com aviso no resumo final, e o padrão é `us`. Corrija na janela de *Teclado* (vale já e se repete a cada início do shell) ou edite esse bloco `input`; para valer também no console e na tela de login, use *Gravar no Sistema* na mesma janela.
- **A tela de login não aparece depois de ativar o SDDM:** use `Ctrl+Alt+F3`, entre com seu usuário e rode `start-hyprland` (ou `sudo systemctl disable sddm` para voltar ao início pelo tty). O log do SDDM está em `journalctl -b -u sddm`. O greeter roda no Xorg, que o pacote `sddm` já traz como dependência.
- **A tela de login não muda de cor com o tema:** confira se `/usr/share/sddm/themes/kortex/theme.conf.user` pertence ao seu usuário (`ls -l`) e se `/etc/sddm.conf.d/` não tem outro arquivo com `Current=` escolhendo outro tema. Rodar `sddm-setup.sh` de novo corrige a posse do arquivo.
- **Escolhi um explorador ou terminal e o atalho abre outro:** um arquivo do Hyprland carregado depois do `hyprland.conf` (por exemplo o de uma ferramenta gráfica) pode redefinir o atalho, e o dele prevalece. Confira com `hyprctl binds | grep -i -A2 "key: E"`.
- **Os atalhos das áreas 6 a 10 sumiram:** um `hyprctl reload` apaga o que foi criado ao vivo; o Kortex os recria em instantes. Se não voltarem, confira `qs -c kortex log`.
- **O layout volta ao anterior depois de um `hyprctl reload`:** o shell reaplica a sua escolha em instantes; se não reaplicar, confira `qs -c kortex log`.
- **O widget Energia diz que os modos estão indisponíveis:** instale e ative o serviço (`sudo pacman -S power-profiles-daemon && sudo systemctl enable --now power-profiles-daemon`) e abra o painel de novo. Se o TLP estiver instalado, os dois conflitam: fique com um só.
- **O botão UEFI reinicia normalmente, sem abrir o utilitário:** esse botão pede ao firmware (`systemctl reboot --firmware-setup`) que abra o utilitário de configuração UEFI no próximo boot; em máquinas antigas sem UEFI (BIOS legado) ou sem esse suporte do firmware, o `systemd` ignora o pedido e reinicia do jeito normal. Confira com `busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanRebootToFirmwareSetup` (`"yes"` = suportado).

## Estrutura

```
kortex/
├── shell.qml            ponto de entrada
├── services/            singletons: tema, animações, rede, brilho, clima, notificações…
├── widgets/             componentes reutilizáveis
├── fonts/               fonte dos ícones (Material Symbols) e licença
├── modules/bar          barra e seus popups
├── modules/launcher     lançador
├── modules/themes       seletor de temas e papéis de parede
├── modules/language     janela de teclado e idioma
├── modules/settings     janela de Configurações do Kortex (páginas de aparência, animações, barra, aplicativos, sessão, geral e sobre)
├── modules/network      editor de conexões e janela de senha do Wi‑Fi
├── modules/weather      janela da cidade do clima
├── modules/display      janela de teste da resolução, taxa e escala
├── modules/screenshot   menu e janela de salvar da captura de tela
├── modules/clickaway    camada que fecha os popups ao clicar fora
├── modules/notifications
├── modules/wallpaper
├── firefox/             CSS do Firefox (interface e páginas internas)
├── matugen/             modelo do Matugen (correspondência das cores Material com as do Kortex) e as cores fixas de cada modo
├── sddm/                tema da tela de login (SDDM)
├── scripts/             auxiliares em bash (inclui theme-apply.sh, icon-theme.sh, open-app.sh, apps-apply.sh, kitty-theme.sh, btop-theme.sh, terminal-apply.sh, firefox-setup.sh, firefox-theme.sh, gnome-setup.sh, gnome-theme.sh, matugen-generate.sh, screenshot.sh, sddm-setup.sh e sddm-colors.sh)
└── themes/              temas embutidos
```

## Licença

O Kortex é software livre, distribuído sob a **GNU General Public License, versão 3** (GPL-3.0); o texto completo está em [`LICENSE`](LICENSE). A fonte dos ícones (Material Symbols, do Google) tem licença própria, Apache-2.0, em `kortex/fonts/LICENSE-MaterialSymbols.txt`.
