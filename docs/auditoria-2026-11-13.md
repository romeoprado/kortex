# Auditoria do código, 13 de novembro de 2026

Terceira revisão completa do Kortex, feita sobre a `main` depois do merge da migração para o Hyprland em Lua (`f7fd847`). Além de procurar erros e inconsistências, esta rodada pesquisou skills para as próximas sessões e outros shells feitos com o Quickshell, em busca de soluções para bordas, transparência, desfoque e animações.

Foi feita no ambiente da nuvem, sem Hyprland nem Quickshell. Tudo o que é QML foi conferido por leitura e por ferramentas, não rodando. A seção *O que precisa ser visto rodando* lista o que testar na máquina.

## Como foi feita

- Leitura dos 26 serviços, dos 30 widgets, dos 26 scripts, do `shell.qml` e de todos os módulos (barra, lançador, Configurações, temas, captura e gravação, rede, tela, processos, teclado e idioma, carrossel), do tema do SDDM, do `install.sh`, do `hyprland.lua` do `arch-setup.sh` e do README. As janelas grandes (Gerenciador de Processos, editor de rede, teclado e idioma, carrossel, painéis de energia, clima e Bluetooth, SDDM) ficaram para uma segunda passada, no dia 14, e foram lidas por inteiro. O `arch-setup.sh` também foi lido por inteiro na segunda passada.
- `bash dev/verificar.sh`, com o `lua` instalado para o `dev/hl-mock.lua`.
- Checagens mecânicas escritas para esta auditoria:
  - toda referência a um membro de serviço (`Theme.x`, `Settings.data.x`, `Icons.x`…) existe no serviço: nenhuma quebrada;
  - membros de serviço sem uso: nenhum além dos que servem de gatilho;
  - cada nome de ícone, inclusive os montados em tempo de execução (`battery_charging_60`…), foi passado pelo HarfBuzz na fonte empacotada: os 125 viram um glifo só;
  - as chaves do `settings.json` e a tabela do README batem;
  - o Lua que o `Motion.qml` e o `HyprSync.qml` geram (81 combinações de animação, as regras de camada e o desfoque ligado e desligado) foi extraído, rodado no Node e conferido no `hl-mock`.
- Leitura do código-fonte do Quickshell (`FileView` e `JsonAdapter`, da 0.2.0 à `master`) e do Hyprland (`hl.layer_rule` e a aplicação das regras de camada), para confirmar dois comportamentos em vez de supor.

## Avaliação geral

O código continua cuidadoso e coerente com as próprias regras. As duas auditorias anteriores limparam o que era superficial; o que apareceu agora é mais fundo. O principal achado é a causa real da armadilha nº 3 do `CLAUDE.md`, que estava descrita pelos sintomas e contornada caso a caso.

## Defeitos corrigidos

1. **Mudanças no `settings.json` se perdiam** (`services/Settings.qml`). O `FileView` grava em outra thread e, quando uma gravação termina, devolve ao `JsonAdapter` o conteúdo gravado. Uma segunda chave mudada antes do fim da primeira gravação faz o `FileView` esperar a primeira e reler dela o estado: a segunda chave volta ao valor antigo na memória até a gravação dela terminar. Uma terceira chave na mesma volta serializa esse estado incompleto. O resultado é exato: de N mudanças seguidas, sobrevivem a última, a antepenúltima e assim por diante. Duas mudanças terminam certas (por isso trocar de tema e de papel de parede funcionava), três perdem a do meio. `Theme.remove()` do tema em uso faz três ou quatro (lembrados, papel de parede, tema e papel de parede de novo): o tema apagado continuava gravado como o tema atual e o shell caía no Morello, com os outros programas já no tema novo. O `applyBatch` existia para contornar isso em dois lugares. Correção: `blockWrites: true`, que torna a gravação síncrona; cada uma devolve exatamente o que a memória já tem. O arquivo tem poucos kB e os controles só gravam quando o valor muda, então a espera não se nota. Evidência: leitura do `fileview.cpp` (`setData`, `saveAsync`, `cancelAsync`, `waitForJob`, `FileViewAdapter::onDataChanged`), igual da 0.2.0 à `master`. Não foi reproduzido rodando.

2. **Salvar de novo um tema do Matugen apagava o papel de parede** (`scripts/matugen-generate.sh`). Com um nome próprio, o script apagava `backgrounds/` e só depois copiava a imagem. Se o papel de parede em uso era o da pasta desse tema (o caso normal depois de aplicá-lo), a imagem era apagada antes da cópia e se perdia. Reproduzido com o Matugen falso da fumaça. A cópia agora vai antes para a pasta temporária, e a fumaça ganhou o caso.

3. **Salvar por cima de um tema existente, sem aviso** (`Theme.saveDynamic`). Renomear recusa um nome em uso; salvar não conferia, e o tema existente perdia as cores e todos os papéis de parede (ou um embutido era escondido por um do usuário de mesmo nome). Agora recusa, com a mesma mensagem.

4. **O `install.sh` parava em silêncio sem o Hyprland no `PATH`.** A conferência de versão acrescentada em novembro é uma atribuição com pipeline sob `set -euo pipefail`: sem o `Hyprland`, o pipeline falha com 127 e o script encerra logo depois do primeiro aviso, sem instalar nada. Era a única verificação do `dev/verificar.sh` que falhava neste ambiente. O `arch-setup.sh` tem a mesma linha (lá o Hyprland acabou de ser instalado, mas ficou protegida também).

5. **Duas conexões de rede ao mesmo tempo** (`services/Network.qml`). `connect()` e `activate()` trocavam o comando de um `Process` em execução (armadilha nº 9). No painel da barra, clicar numa segunda rede durante a conexão da primeira mostrava a segunda como "conectando" sem tentá-la, e o resultado da primeira era lido como se fosse dela: o perfil de uma rede nova com a senha errada podia não ser apagado. Agora o pedido é recusado com um aviso, e a janela da senha trata a recusa.

6. **`Notifs.times` crescia sem limite.** Cada notificação e cada aviso do Kortex acrescentava uma entrada que nunca saía, e o mapa inteiro era copiado a cada chegada. Agora só ficam os horários dos avisos que ainda existem.

7. **Excluir dois temas em seguida** (`Theme.remove`). O `rm` em execução não aceitava o segundo comando: as referências do segundo tema eram apagadas e a pasta ficava. Agora espera o primeiro terminar.

8. **Cores com 4, 5 ou 7 dígitos** (`Theme.normalize`). A expressão aceitava de 3 a 8 dígitos, e `hex()` só trata 3, 6 e 8. Um erro de digitação virava uma cor inválida (ou com alfa, no caso de 4). Agora a chave cai no padrão.

## Inconsistências corrigidas

9. **"Animações desligadas" não desligava tudo.** O README e o `Settings.qml` prometem que `animations: false` desliga todas, e o `Motion` diz que a velocidade multiplica todas as durações. Mas 27 animações tinham a duração escrita direto (realces de botões, interruptores, itens da barra, cor da barra, áreas de trabalho) e o esmaecer do papel de parede (700 ms) ignorava as duas opções. `Motion.ms()` passou a devolver 0 com as animações desligadas (todos os usos existentes já tratavam o caso) e as 27 durações passam por ele. Ficaram de fora, de propósito, os indicadores de carregamento e as contagens regressivas.

10. **Realce de linha com raio fixo.** Quinze listas usavam `radius: 4`, enquanto os botões seguem `Theme.radiusSmall`. Com o raio dos cantos em 0, as linhas continuavam arredondadas. Agora seguem o tema (no padrão, o valor é o mesmo).

11. **README, seção 3.** O exemplo do `hyprland.lua` ainda pintava a borda inativa opaca (`colors.muted`) e ignorava o `hyprBorders`, o defeito 6 da auditoria anterior, corrigido no instalador e esquecido no manual.

12. **Seletor de fontes.** Sem fonte escolhida, marcava a fonte padrão pelo nome, mesmo que ela não estivesse instalada (e o nome da fonte dos títulos estava repetido na página). Agora marca a que o `Theme` realmente usa.

13. **`settings open <página>` com página desconhecida** abria a primeira página sem nenhuma marcada na lista. Agora abre a última vista.

14. **Acesso pelo teclado.** `PlainButton`, `Toggle` e `TileButton` recebem o foco e respondem a Espaço e Enter; o `AppChip` (Configurações › Aplicativos) e o `SliderBar` não. Agora os dois recebem o foco, e o controle deslizante anda com as setas.

15. **Temperatura do clima com tamanho fixo.** O painel do clima usava `font.pixelSize: 24`, o único tamanho de texto fora do `Theme`. Agora deriva do tamanho escolhido (`Theme.textTitle + 6`, o mesmo valor no padrão).

16. **Rolagem das Configurações pelo teclado.** O Tab chegava a um controle fora da área visível sem a página acompanhar. O editor de rede já fazia isso para os campos dele (`reveal`); a `SettingsPage` agora rola o mínimo necessário até o controle com o foco.

## Segunda passada (14 de novembro)

A leitura das janelas que tinham ficado só nas checagens mecânicas não achou defeito novo nelas. Achou um erro desta própria auditoria: a troca de `radius: 4` por `Theme.radiusSmall` (item 10) foi feita por padrão de texto e pegou também o ponto verde de 8 px que marca a conexão ativa no editor de rede, que é um círculo e não um realce de linha. Com o raio dos cantos em 0 ele viraria um quadrado. Voltou a ser círculo (`radius: width / 2`), e as outras 15 trocas foram conferidas uma a uma: todas são realces de linha.

A `main` recebeu o PR #7 (aviso do `user.conf` no instalador) nesse intervalo. Foi juntada ao branch sem conflito, com o `dev/verificar.sh` em **Tudo certo**.

O teste que esse PR acrescentou ao verificador tinha um defeito que só aparece com o `lua` instalado: `lua -e 'assert(loadfile(arg[1]))' arquivo` põe o arquivo no `arg[0]`, o `arg[1]` fica vazio e o `loadfile` passa a ler a entrada padrão. Com a entrada vazia o teste passava (porque o `lua` executa o arquivo em seguida), mas num terminal o `dev/verificar.sh` ficava parado esperando alguém digitar. Aqui ele travou por dez minutos numa das execuções. O código do teste agora vai pela entrada padrão e o arquivo é o `arg[1]`, sem executar o `user.lua`. Na sua máquina isso não aparecia, provavelmente porque o `lua` não está instalado e o teste era pulado.

## Pesquisa: skills

As skills disponíveis nesta sessão que ajudam no Kortex, pelo plugin `qt-development-skills`:

- `qt-qml`: regras de QML (bindings, layouts, delegates, animações, desempenho). Foi a base da revisão. Dela vieram dois pontos aplicados: animar `opacity` e `transform` em vez de geometria, e dar um caminho de "menos movimento" que troque a animação por mudança imediata.
- `qt-ui-design`: princípios de interface, movimento (entrar desacelerando, sair acelerando, de 100 a 150 ms para o que é pequeno, nunca mais de 500 ms), teclado e contraste. Dela vieram o acesso pelo teclado do item 14 e a conferência das durações.
- `qt-qml-review` e `qt-qml-profiler`: revisão com linter e análise de desempenho com o `qmlprofiler`. O profiler só serve na sua máquina, com o shell rodando.

Fora do catálogo, valem a leitura (não foram instaladas):

- **Omarchy, `agents/skills/shell-dev.md`** (basecamp/omarchy): como manter o estado em dia sem laços de consulta, com os serviços nativos do Quickshell (`UPower`, `Pipewire`, `Networking`), `FileView` com `watchChanges` e um aviso pelo IPC de quem muda o estado. O Kortex ainda consulta o `nmcli` a cada 8 s e o brilho a cada 5 s; é o próximo ganho de eficiência.
- **`quickshell`** (LeonardoMor/dotfiles, publicada no LobeHub): padrões do Caelestia. Curvas e durações como tokens, `PersistentProperties` para o estado sobreviver à recarga, contagem de referências para só consultar o sistema com alguém olhando (o Kortex já faz isso com `Popups.current`).
- **`qml-dial-in`** (heytcass/claudeos): o ciclo editar, recarregar, capturar a tela com o `grim` e revisar, para ajustes visuais feitos por um agente dentro da sessão do Hyprland. É o que falta aqui na nuvem, e a forma mais direta de afinar animações com você olhando.

## Pesquisa: outros shells

Foram vistos o Caelestia, o Noctalia, o DankMaterialShell e o illogical-impulse (end-4), mais a documentação do Hyprland e o código do Quickshell.

- **Desfoque.** Nenhum deles desfoca no Qt: todos pedem ao compositor, com uma regra de camada (`blur`, `ignore_alpha` em torno de 0,5 e `blur_popups`). O Noctalia documenta exatamente isso para o Hyprland em Lua. O Kortex não tinha nada parecido: os painéis eram sempre opacos. Entrou como opção (ver abaixo).
- **Transparência.** O Caelestia e o Noctalia têm uma opacidade única para as superfícies, aplicada só ao fundo, com o conteúdo opaco. Foi o modelo seguido (`Theme.surface`).
- **Animações.** O Caelestia usa as curvas do Material 3 (*emphasized*, *emphasized decelerate*, *emphasized accelerate*, *standard* e as *expressive*) com durações em tokens. As curvas do `Motion` já eram essas três; o que faltava era a disciplina de passar tudo por um lugar só (item 9). O Noctalia desliga as animações de camada do Hyprland para as próprias superfícies, porque as duas juntas rasgam um painel reaberto durante o fechamento; o Kortex já separa (janelas pelo Hyprland, painéis e avisos pelo Qt, com `no_anim`).
- **Bordas.** Os outros usam borda fina ou nenhuma e apostam em sombra e elevação. O Kortex segue a borda das janelas do Hyprland, desenhada na grade de pixels, que é o ponto forte dele em escala fracionária. Não mudou. Sombra exigiria margem em volta de cada janela de painel e não foi feita.
- **Do Quickshell.** `HyprlandWindow.visibleMask` deixa dizer ao Hyprland qual parte de uma janela tem conteúdo, o que barateia o desfoque em janelas grandes e quase todas transparentes, como as `OverlayPanel` de tela cheia. Fica como próximo passo, se o desfoque pesar.

## Melhorias aplicadas

- **Painéis translúcidos e com desfoque**, opcionais (`panelOpacity`, de 60 a 100, padrão 100; `panelBlur`). Detalhes em `docs/arquitetura.md`. A regra de camada tem nome e é atualizada no lugar: o código do Hyprland (`hlLayerRule`) reaproveita a regra de mesmo nome, acrescenta os efeitos (vale o último valor de cada um) e agenda a reaplicação nas camadas abertas, então ligar e desligar vale na hora.
- **Troca de página nas Configurações** com entrada suave. (Fazer os botões afundarem ao clique, como os blocos, foi testado e descartado: a escala encolhe também a área de clique, e soltar na beirada de um botão largo deixaria de contar.)
- **`dev/verificar.sh`** confere a regra de desfoque, o tema salvo duas vezes e roda o Lua gerado na imitação da API mesmo sem o Hyprland.

## O que precisa ser visto rodando

Nada disto pôde ser aberto aqui. Depois de instalar, rode `qs -c kortex kill; qs -c kortex` e confira o `qs -c kortex log`.

1. **O shell abre sem erro** e as Configurações gravam: mude duas ou três opções, feche e abra de novo. É o teste do `blockWrites`.
2. **Excluir o tema em uso** (um tema salvo do Matugen, por exemplo): o shell deve ir para outro tema e continuar nele depois de reiniciar.
3. **Opacidade dos painéis** em 85%, com o desfoque ligado e desligado: barra inteira e flutuante, um painel da barra, o lançador, as Configurações, um aviso e o OSD. `hyprctl configerrors` deve ficar vazio. Se o desfoque dos painéis da barra não acompanhar, o ponto é o `blur_popups`.
4. **Animações desligadas**: nada deve se mover além dos indicadores de carregamento. Ligadas na velocidade *Lenta*: os realces dos botões ficam mais lentos também.
5. **Teclado nas Configurações**: Tab chega aos controles deslizantes e aos botões de aplicativo; as setas mudam o valor; a página rola sozinha quando o foco vai para um controle fora da área visível (teste na página Aparência, que é a mais comprida).
6. **`bash dev/verificar.sh`** na máquina, que roda o `Hyprland --verify-config` no Lua gerado (inclusive a regra `kortex-blur`).

## Pendências

- **`arch-setup.sh`**: foi lido por inteiro, sem achados além da linha da versão do Hyprland (defeito 4), mas só pode ser exercitado de verdade num Arch limpo. Os trechos `[ teste ] && comando` no fim de um bloco, que costumam derrubar scripts com `set -e`, foram testados e não encerram o instalador.
- **Leitura inicial do `settings.json` é assíncrona.** Os serviços nascem com os padrões e recebem os valores salvos logo depois. Funciona, mas uma gravação feita antes de a leitura terminar sobrescreveria o arquivo com os padrões. Hoje nada grava tão cedo. Tornar a leitura síncrona mudaria quem depende do sinal de mudança ao iniciar (a luz noturna, por exemplo) e precisa de teste na máquina.
- **Consultas periódicas** (`nmcli` a cada 8 s, brilho a cada 5 s, bateria a cada 10 s) poderiam virar eventos, como sugere a skill do Omarchy.
- **`visibleMask`** nas janelas `OverlayPanel`, se o desfoque pesar em telas grandes.
- Continuam valendo as pendências 7 a 10 e 12 da auditoria de 3 de novembro (commits do Firefox fora da `main`, branches antigas, arquivos do formato antigo, o `.qsb` sem conferência) e os pontos de outubro (senha do Wi-Fi na linha de comando do `nmcli`, pequenas duplicações). O `qsb` do PySide6 não vem no pacote `PySide6-Essentials`, então o `.qsb` também não pôde ser conferido aqui.
