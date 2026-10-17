# Auditoria do código, outubro de 2026

Revisão completa do Kortex 0.2, feita depois do commit `cd1ce35`. Todos os arquivos foram lidos por inteiro: `shell.qml`, os 23 serviços, os 27 widgets, os 50 arquivos de `modules/`, os 23 scripts, o `arch-setup.sh`, o `install.sh`, os temas, o SDDM, o CSS do Firefox, o modelo do Matugen e o README. São cerca de 17 mil linhas de código.

Ferramentas usadas: `shellcheck` 0.11 (nível info), `qmlformat` e `qmllint` do Qt 6 (pelo PySide6) e uma fumaça dos scripts num HOME temporário. Esse conjunto virou o `dev/verificar.sh`, que repete tudo com um comando.

## Avaliação geral

O código está bem organizado e cuidadoso. A divisão entre serviços (estado e sistema), widgets (visual) e módulos (telas) é respeitada. Os comentários explicam o porquê das decisões, inclusive as que nasceram de defeitos (escala fracionária, recarga do Hyprland, gravação do `settings.json`). Os scripts são defensivos: conferem as cores antes de gravar, escrevem num temporário e trocam com `mv`, passam valores como argumentos e nunca executam nada que venha de um tema. A interface cuida de contraste (WCAG), foco pelo teclado e escala fracionária.

Não apareceu nenhum defeito grave. Os problemas encontrados eram de portabilidade, permissões, código sem uso e clareza.

## O que foi corrigido

**Defeito real**

- `scripts/icon-theme.sh pick` usava o `strtonum`, que só existe no gawk. Com outro awk (mawk, busybox), o nome do tema de ícones saía `-dark` em vez de, por exemplo, `Yaru-blue-dark`. No Arch o awk padrão é o gawk, então o efeito era só fora dele. A conversão de hexadecimal agora é awk POSIX. O resultado foi conferido contra uma implementação de referência em 300 cores aleatórias (nenhuma diferença) e bate com o `icons.theme` dos quatro temas embutidos que seguem o cálculo (Gilmour, Matugen, Morello e Van Halen; nos outros a variante foi escolhida à mão).

**Permissões**

- `icon-theme.sh` e `matugen-generate.sh` têm shebang, mas estavam sem `+x` (o README manda rodar o segundo). Agora são executáveis, como os outros scripts.
- 37 arquivos QML estavam marcados como executáveis, sem motivo. Todos passaram a 644.

**Código sem uso**

- 28 imports sem uso em 20 arquivos QML (`QtQuick.Layouts`, `Quickshell`, `Quickshell.Wayland`, `Quickshell.Hyprland` e `qs.services`). As janelas feitas com `OverlayPanel` importavam o Wayland e o Hyprland sem precisar, porque quem usa esses módulos é o próprio `OverlayPanel`.
- `Icons.font` e `Icons.tray`, dois nomes de ícone que nada usava.
- `Theme.currentTheme`, uma propriedade sem uso (o comentário que a acompanhava virou uma nota sobre `themeByName`).
- `Apps.currentTerminal()`, sem uso (a página de Aplicativos lê `Settings.data.terminal` direto).
- A cor `muted` da tela de login: o `sddm-colors.sh` a gravava no `theme.conf.user`, mas o `sddm/Main.qml` nunca a lia. Saiu do script, dos dois lugares que o chamam (`theme-apply.sh` e `sddm-setup.sh`) e do `theme.conf`. As outras nove cores foram conferidas uma a uma depois da renumeração dos argumentos.
- Duas variáveis locais sem uso em `firefox-common.sh`.
- No `arch-setup.sh`, os marcadores `# >>> extras` e `# <<< extras` e a definição condicional de `have()`, sobras de quando o bloco dos programas adicionais foi colado. `have()` agora fica com os outros utilitários.

**Clareza e boas práticas**

- Ids que escondiam propriedades: `left` em `KeyboardPage.qml` (todo `Item` tem a âncora `left`) virou `activeColumn`, e `input` em `Field.qml` (o mesmo nome do alias público) virou `textInput`. O alias `input`, que outros arquivos usam, não mudou.
- Expressões com vírgula (`void a.font, b.font`) em `EnergyIndicator.qml` e `PowerIndicator.qml` viraram instruções separadas.
- Um comentário de `Keyboard.qml` descrevia o catálogo de layouts, mas estava em cima da função das traduções. Foi para o lugar certo.
- Comentários de `OverlayPanel.qml`, `Popups.qml` e `ClickAway.qml` listavam só quatro janelas; hoje o mesmo mecanismo serve a onze.
- Em `BarButton.qml`, um `TextMetrics` estava no meio das declarações de propriedade e foi para junto dos outros filhos.
- Cabeçalho novo em 14 arquivos QML que não diziam o que eram (os indicadores da barra, o calendário, as abas do seletor de temas, `PlainButton` e `Toggle`), com os cliques e as teclas que cada um aceita.
- Linhas em branco duplicadas em cinco arquivos.
- `screenshot.sh` roda com `set -u` e não inicializava `hw_nx` (nunca falhava, porque só é lida quando foi definida, mas ficou explícito).
- `disk-stats.sh`: `ls | head` virou um glob, com a mesma ordem e sem abrir processos. `matugen-generate.sh`: `A && B || C` virou um `if`. Aspas e diretivas do shellcheck nos demais. O `shellcheck` passa sem nenhum aviso, inclusive os informativos.

**Documentação**

- `CLAUDE.md` (regras, armadilhas e receitas), `docs/arquitetura.md` e este relatório.
- `dev/verificar.sh`, com as verificações que rodam sem Hyprland.
- README: o diagnóstico do Matugen passou a usar o modo de prévia do `matugen-generate.sh` (com `-` no lugar da pasta), que não grava nada. Antes, a dica regravava o tema `matugen` do usuário. Seção nova *Desenvolvimento* apontando para estes arquivos.

Nenhuma dessas mudanças altera o comportamento visível do shell, exceto o nome do tema de ícones fora do gawk e o README.

## Pontos de atenção que ficaram como estão

1. **Senha do Wi-Fi na linha de comando.** `Network.connect()` roda `nmcli device wifi connect <rede> password <senha>` e `saveConnection()` passa `802-11-wireless-security.psk <senha>`. Enquanto o comando roda (até 30 s), a senha aparece em `/proc/<pid>/cmdline` para qualquer usuário da máquina. Num computador de uma pessoa só o risco é baixo. A correção seria entregar a senha pela entrada padrão (`nmcli --ask`, com `stdinEnabled` e `write()` no `Process`) ou por um arquivo temporário com permissão 600 (`passwd-file`), e isso precisa ser testado numa máquina real antes de entrar.
2. **Comandos vindos das configurações.** `lockCommand` e `audioApp` rodam com `sh -c` (`Settings.shell`), e o lançador executa o que vem depois de `>`. É de propósito: o `settings.json` é do próprio usuário.
3. **Gancho do tema.** `~/.config/kortex/hooks/theme-set` é executado a cada troca de tema, se for executável. Também de propósito, e só o usuário escreve ali.
4. **Pequenas duplicações.** `clock()` é igual em `Media.qml` e `ScreenRecord.qml`. A leitura das pastas de atalho é igual em `Screenshot.qml` e `ScreenRecord.qml`. As listas de ações de sessão existem em `PowerIndicator.qml` e `PowerPage.qml`, e os itens da barra em `Settings.barDefaultLayout` e `BarPage.items`. Juntar exigiria um módulo de utilidades para pouco código; vale fazer se uma delas crescer.
5. **Cores padrão repetidas.** O Morello aparece em seis lugares (lista no `CLAUDE.md`).
6. **`hyprland.conf` gerado.** Usa `layout = master` e configura também o bloco `dwindle`, que não tem efeito nesse layout. É inofensivo e deixa a troca de layout pronta.
7. **README longo.** Algumas entradas da seção 4 são parágrafos muito grandes. Dividir em subtópicos ajudaria quem lê, mas ficou fora desta revisão para não misturar conteúdo com organização.
8. **Limites da verificação automática.** O `qmllint` não conhece os tipos do Quickshell, então não acusa propriedade inexistente nem binding quebrado nesses tipos. Toda mudança em QML ainda precisa ser vista rodando (`qs -c kortex log`).

## Conferências feitas

- `Language._generateScript`: o código do idioma chega ao `pkexec` só depois de passar por uma expressão regular estrita (`^[a-z]{2,3}_[A-Z]{2}\.UTF-8(@…)?$`).
- `Theme.remove()` só apaga pastas dentro das pastas de temas do Kortex (`canRemove`), e `removeWallpaper()` usa a Lixeira e só aceita arquivos das pastas conhecidas.
- O corpo das notificações tem as tags `<img>` removidas antes de ir para o `StyledText`, para um aviso não fazer o shell baixar nada.
- `Keyboard`, `Monitors` e `HyprSync` reaplicam o que é deles depois de um `hyprctl reload`.
