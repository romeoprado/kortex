# Histórico de versões

## Em desenvolvimento (depois da 0.3)

**Novidades**

- **Painéis translúcidos e com desfoque** (*Configurações › Aparência › Painéis*; `panelOpacity` e `panelBlur`). A opacidade abaixo de 100% deixa translúcido o fundo da barra, dos painéis, do lançador, das janelas, dos avisos e do aviso de volume e brilho, e o Hyprland desfoca o que fica por trás, como já fazia com o terminal. O padrão continua opaco. O Kortex manda a regra de camada ao vivo e a reaplica a cada recarga do Hyprland, sem gravar no `hyprland.lua`.
- **Teclado nas Configurações.** Os controles deslizantes aceitam as setas com o foco neles (Tab), os botões de aplicativo (*Configurações › Aplicativos*) recebem o foco e respondem a Espaço e Enter, como os outros botões, e a página rola sozinha até o controle que ganhou o foco.
- Nas Configurações, cada página surge subindo alguns pixels ao ser escolhida.

**Mudanças**

- **Animações desligadas desligam tudo.** Os realces de botões, interruptores e itens da barra, a troca de cor da barra e o esmaecer do papel de parede ignoravam a opção e a velocidade escolhida. Agora toda duração passa pelo `Motion`: a velocidade vale para tudo e, com as animações desligadas, as mudanças são imediatas (a troca do papel de parede, que antes ainda esmaecia, também). Só continuam os indicadores de carregamento e as contagens regressivas.
- O realce das linhas de lista (redes, fontes, dispositivos, pastas, processos) acompanha o raio dos cantos escolhido, como os botões. Com o raio em 0 ele ficava arredondado.
- Salvar as cores do Matugen com o nome de um tema que já existe passa a ser recusado, com aviso, como ao renomear. Antes o tema existente era sobrescrito em silêncio e perdia os papéis de parede.
- A temperatura no painel do clima acompanha o tamanho do texto escolhido, como o resto da interface.
- O seletor de fontes marca a fonte em uso quando nenhuma foi escolhida (antes marcava a fonte padrão mesmo que ela não estivesse instalada).
- `qs -c kortex ipc call settings open <página>` com uma página desconhecida abre a última vista. Antes abria a primeira, sem nenhuma marcada.

**Correções**

- **Mudanças no `settings.json` podiam se perder.** Quando três ou mais opções mudavam de uma vez, a do meio voltava ao valor antigo (a gravação é em outra thread e, ao terminar, devolvia o estado anterior à memória). O caso mais visível era excluir o tema em uso: o tema apagado continuava como o tema atual e o shell caía no Morello. A gravação passa a ser síncrona, e a causa está explicada em `docs/arquitetura.md`.
- **Salvar de novo um tema do Matugen apagava o papel de parede.** Se a imagem em uso era a da pasta do próprio tema, o script apagava a pasta antes de copiar a imagem, e ela se perdia. Agora a cópia vem antes.
- **O `install.sh` parava sem dizer nada quando o Hyprland não estava no `PATH`**, logo depois dos primeiros avisos e sem instalar. Agora avisa e continua. O `arch-setup.sh` tinha a mesma linha.
- **Clicar em outra rede durante uma conexão** fazia a segunda aparecer como "conectando" sem ser tentada, e o resultado da primeira era atribuído a ela (o perfil de uma rede nova com a senha errada podia ficar salvo). Agora o segundo pedido é recusado com um aviso até a conexão em andamento terminar.
- O registro de horários das notificações crescia sem limite enquanto o shell ficava aberto. Agora só guarda os dos avisos que ainda existem.
- Excluir dois temas em seguida, depressa, podia deixar a pasta do segundo no disco com as referências já apagadas.
- Uma cor com 4, 5 ou 7 dígitos no `colors.toml` de um tema (erro de digitação) virava uma cor quebrada. Agora a chave cai no valor padrão.
- README: o exemplo do `hyprland.lua` (seção 3) pintava a borda inativa opaca e ignorava o `hyprBorders`. Agora usa as bordas prontas do `hyprland-colors.lua`, como o instalador.

**Manutenção**

- Auditoria completa do código (relatório em `docs/auditoria-2026-11-13.md`), com a pesquisa de skills e de outros shells feitos com o Quickshell.
- `dev/verificar.sh`: confere a regra de desfoque no Lua gerado, o tema do Matugen salvo duas vezes e o `install.sh` sem o Hyprland; roda o Lua do `Motion.qml` e do `HyprSync.qml` na imitação da API mesmo sem o Hyprland instalado.
- `dev/verificar.sh` não fica mais parado esperando o teclado quando o `lua` está instalado (o teste do `user.lua` gerado lia a entrada padrão em vez do arquivo).
- `CLAUDE.md` e `docs/arquitetura.md`: a causa da perda de valores no `settings.json`, o fundo translúcido, a regra de camada com nome e a convenção das durações.

## 0.3 — 2026-11-03

**Novidades**

- **Animações novas.** O aviso de volume, brilho, Caps Lock e Num Lock surge como uma gota, abre em pílula e pulsa a cada passo. A marca da área de trabalho atual desliza entre as áreas e se estica no caminho. Os avisos ganham uma barrinha de contagem regressiva, que pausa com o mouse por cima. O lançador abre em cascata. A busca de redes, a procura de atualizações, a conexão ao Wi‑Fi e o clima mostram indicadores de carregamento (faixa, anel e esqueleto). Ideias adaptadas do [dhrruvsharma/shell](https://github.com/dhrruvsharma/shell) (GPL-3.0).
- **Troca do papel de parede com efeito** (`wallpaperTransition`, em *Configurações › Animações*): círculo, íris (o padrão), tinta, ladrilhos, varredura ou falha, desenhados por um shader (`kortex/shaders/`), ou o esmaecer de antes. `dev/verificar.sh` confere se o `.qsb` compilado está em dia com o `.frag`.
- **Pareamento Bluetooth pelo painel.** O Kortex agora tem um agente de pareamento (`scripts/bt-agent.py`, que precisa de `python-dbus` e `python-gobject`). Sem ele, o bluetoothd recusava mouses e fones com `No agent available`. Mouses e fones que você manda parear pelo painel são aceitos sozinhos; quando o dispositivo mostra um código, o painel abre para conferir e aceitar, e num teclado ele mostra o código para digitar. Um pedido que você não iniciou abre o painel e só é aceito com o seu clique. Se o pareamento falha, o dispositivo mostra *Falha ao parear* e deixa de ser marcado como confiável.
- **Gerenciador de Processos** (`CTRL+SHIFT+Esc`, o botão *Processos* no painel Recursos ou `qs -c kortex ipc call processes toggle`). Mostra o que está rodando na sessão agrupado por aplicativo, com a CPU e a memória de cada grupo e os totais da máquina. Busca por nome, comando ou PID, ordena pelas colunas e funciona pelo teclado. *Encerrar* pede confirmação e, se o programa não fechar em 3 s, vira *Forçar*. O instalador acrescenta o atalho ao `hyprland.lua`.
- **Tailscale no painel de rede.** Com o Tailscale instalado, uma seção mostra o estado, liga e desliga a conexão e lista os dispositivos da tailnet com o IP, que um clique copia. Sem o `--operator`, o Kortex pede a senha pelo polkit; o instalador passa a sugerir `sudo tailscale up --operator=$USER`.

**Mudanças**

- **Configuração do Hyprland em Lua.** O Hyprland 0.57 deixou de ler o `hyprland.conf`, e o Kortex passa a usar o `hyprland.lua` (Hyprland 0.55 ou mais novo). O `arch-setup.sh` grava o `hyprland.lua` com os mesmos atalhos, regras e aparência de antes e o `user.lua` para as suas personalizações (o conteúdo do `user.conf` vai junto, comentado, para você reescrever). O que o shell aplica ao vivo (animações, atalhos das áreas 6 a 10, Caps Lock e Num Lock, bordas, cantos, teclado, tela e as cores do tema) usa o `hyprctl eval`, e os arquivos de estado lidos pelo Hyprland viram `hyprland-colors.lua`, `monitors.lua` e `hyprland-terminal.lua`. Para migrar, rode o `arch-setup.sh` de novo e saia e entre na sessão; a resolução confirmada no widget de tela é convertida sozinha, e o `hypridle.conf` criado pelo instalador é corrigido. Os ajustes do HyprMod (`hyprland-gui.lua`) continuam carregados depois da reinstalação. Enquanto o Hyprland ainda usar o `hyprland.conf`, o Kortex avisa. O `hyprlock` continua no formato de antes e lê o `hyprland-colors.conf`.

**Correções**

- O Firefox não acompanhava o tema numa instalação nova: o `arch-setup.sh` rodava o `firefox-setup.sh` antes de existir um perfil (ele só nasce na primeira abertura do Firefox), e o `firefox-theme.sh` ignora perfis não configurados. Agora o `theme-apply.sh` roda `firefox-setup.sh --auto`, que configura o perfil padrão na próxima troca de tema ou no próximo início do shell. Um perfil desligado com `firefox-setup.sh --remove` fica anotado em `~/.local/state/kortex/firefox-off` e não é religado.
- Apps GTK3 (Visualizador de Documentos, Discos) e GTK4 sem libadwaita (Controle de Volume) não acompanhavam o tema, porque o Kortex só gravava as cores do libadwaita e os temas embutidos do GTK usam cores fixas. Agora o `gnome-setup.sh` também configura `~/.config/gtk-3.0`, e o `gnome-theme.sh` escolhe o tema GTK `adw-gtk3-dark` ou `adw-gtk3` (pacote `adw-gtk-theme`, que o `arch-setup.sh` passa a instalar), que lê as mesmas cores. O `gtk-theme` anterior fica guardado para o `--remove`. Quem já usava a integração precisa rodar `gnome-setup.sh` de novo.
- Na barra flutuante, os cantos arredondados ficavam pretos por alguns quadros ao passar o mouse nos itens (visto com NVIDIA e escala 1,25×). A camada da barra chegava ao Hyprland como opaca e ele não redesenhava o papel de parede sob os cantos. A altura da barra também passa a cair em pixels físicos inteiros.
- O botão direito também esquece um dispositivo que ficou confiável sem chegar a parear.
- A escolha automática do tema de ícones pelo acento (`scripts/icon-theme.sh pick`) dependia do gawk; com outro awk, o nome saía quebrado. Agora funciona com qualquer awk.
- `icon-theme.sh` e `matugen-generate.sh` voltam a ser executáveis, como os outros scripts.
- O tema do btop deixava um arquivo temporário (`~/.config/btop/themes/.kortex.*`) cada vez que era reaplicado sem mudança, o que acontece a cada início do shell. Pode apagar os que sobraram.
- As bordas das janelas saíam com a inativa opaca no login e depois de um `hyprctl reload`, e translúcida depois de uma troca de tema; com `hyprBorders` desligado, o login voltava a pintá-las com o tema. Agora o `hyprland-colors.lua` traz as bordas prontas e se elas seguem o tema, e o `hyprland.lua` as usa (rode o `arch-setup.sh` de novo para o `hyprland.lua` novo).
- Uma instrução recusada pelo Hyprland no que o Kortex aplica ao vivo (atalhos, animações, regras das camadas) não leva mais junto as que vêm depois: cada uma roda protegida, e os erros aparecem juntos no `qs -c kortex log`.
- Ligar ou desligar o desfoque do terminal recarregava também os monitores; volta a recarregar só a configuração.
- *Restaurar padrões* também volta o relógio de 24 horas, que fica na página Barra.
- O aviso de que o Hyprland ainda usa o `hyprland.conf` apontava para a seção errada do README, e a falha ao iniciar o `tailscaled` mostrava uma mensagem genérica.

**Manutenção**

- Revisão depois da migração para o Lua, feita com o Hyprland e o Quickshell rodando (relatório em `docs/auditoria-2026-11.md`), com a documentação de arquitetura, a estrutura e as dependências do README atualizadas.
- Revisão completa do código (relatório em `docs/auditoria-2026-10.md`): imports, ícones e funções sem uso removidos, a cor `muted` que ia para a tela de login sem ser lida, comentários atualizados e cabeçalho nos arquivos que não tinham. Os arquivos QML deixam de ser executáveis.
- Documentação para desenvolvimento (`CLAUDE.md` e `docs/`) e `dev/verificar.sh`, que confere scripts, QML e permissões sem precisar do Hyprland.
- README: o diagnóstico do Matugen usa o modo de prévia do `matugen-generate.sh`, que não grava nada.
- Janela de rede: o campo da máscara deixa de ter o id `mask`, que escondia a propriedade `mask` da janela.
- `dev/verificar.sh` confere o `hyprland.lua` do instalador e o Lua que o shell gera, com o `dev/hl-mock.lua` e, havendo Hyprland, o `Hyprland --verify-config`.
- `dev/verificar.sh` usa o `qmlformat` e o `qmllint` do Qt 6 mesmo com os do Qt 5 no `PATH` (eles acusavam erro de sintaxe em `?.`, espalhamento e funções com tipo), mostra as mensagens do Qt que iam para o journald e confere a sintaxe dos scripts em Python.

## 0.2 — 2026-10-07

**Novidades**

- **Gravação de tela** (`SHIFT+Print`): tela inteira, janela ou área, com o som do sistema e o microfone; a barra mostra o tempo gravado e um clique nele para. A janela *Salvar Gravação* escolhe nome, formato (MP4 ou MKV) e pasta. Usa o `gpu-screen-recorder`.
- **Captura de tela** (`Print`): tela inteira, janela ou área, sem o cursor e sem a marcação da seleção na imagem; a janela *Salvar Captura* escolhe nome, formato (PNG ou JPEG) e pasta.
- **Barra flutuante** (*Configurações › Barra › Estilo*): centralizada, solta da borda, só da largura do conteúdo, numa fileira só, com o raio e a borda dos painéis (a borda pode ser desligada) e as áreas de trabalho em bolinhas.
- **Reordenar a barra**: segure um item por meio segundo e arraste; *Restaurar ordem padrão* desfaz.
- **Novos itens da barra**: **Mídia** (o que está tocando, com painel de capa, andamento e controles), **Bandeja** (ícones dos programas) e **Atualizações** (pacotes com versão nova, pelo `checkupdates`).
- **Animações** próprias para janelas, áreas de trabalho, painéis da barra e avisos, com a aba *Configurações › Animações* (liga/desliga, intensidade, velocidade e estilos).
- **Rede**: o painel mostra os dados recebidos e enviados na sessão da conexão em uso.
- **btop** acompanha o tema.
- **Instalador**: Calculadora, Discos, HyprMod, Visualizador de Imagens e Controle de Volume abrem como janelas flutuantes.

**Mudanças**

- A borda da barra flutuante, dos painéis e dos avisos é igual à das janelas do Hyprland: o acento do tema como está no `colors.toml` e a espessura contada em pixels lógicos.
- Sessão e Energia: o nome da ação ou do modo aparece numa etiqueta à direita do título, sem faixa vazia sob os botões.
- Tamanho do texto: Pequeno 12, Normal 13 (o novo padrão) e Grande 14. A altura da barra é fixa em 30 px.
- Contraste mínimo garantido (WCAG) para o texto apagado, as cores de aviso, os contornos e o texto sobre o acento; `Tab` percorre os controles das janelas do Kortex.

**Correções**

- O papel de parede desenhado pelo Kortex saía borrado com escala fracionária ou HiDPI (a 1,6×, ele era decodificado em 1600 × 1000 num painel de 2560 × 1600).
- A roda do mouse e o touchpad na barra: um deslizar no touchpad mudava o volume, o brilho ou a área de trabalho várias vezes; agora cada passo equivale a um dente da roda.
- Depois de um `hyprctl reload`, a borda das janelas inativas voltava opaca; o Kortex reaplica as cores do tema.
- O texto de uma notificação podia trazer `<img>` com endereço da internet, que o Kortex baixaria; essas imagens são ignoradas.
- Clicar numa ação de notificação fechava duas vezes o cartão já destruído (aviso no log).
- Inverter a ordem dos layouts de teclado disparava um erro do Hyprland.
- Borda 0 px deixava uma franja da cor da borda nos cantos arredondados.
- Textos que ainda falavam em instalar temas por URL (recurso removido na 0.1); confirmação de exclusão e marca do estilo do Matugen com a cor de texto certa sobre o vermelho e o acento.
- README: o Quickshell vem dos repositórios oficiais (`sudo pacman -S quickshell`); o `install.sh` passou a sugerir esse pacote.

## 0.1 — 2026-09-27

Primeira versão publicada.
