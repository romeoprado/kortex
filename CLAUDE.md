# Kortex: guia para sessões de desenvolvimento

Shell para o Hyprland escrito em QML sobre o [Quickshell](https://quickshell.org), com scripts em bash para o que fica fora dele. Tudo em português do Brasil: interface, comentários, README, CHANGELOG e mensagens de commit. Versão atual: **0.3**.

Leia também `docs/arquitetura.md` (como as peças conversam) e, para o histórico das revisões, `docs/auditoria-2026-10.md`, `docs/auditoria-2026-11.md` e `docs/auditoria-2026-11-13.md` (esta com o que ficou pendente e o que precisa ser visto rodando). O `README.md` é o manual do usuário e a referência das opções do `settings.json` (seção 5).

## Mapa do repositório

```
arch-setup.sh        instalador completo para um Arch limpo (pacotes, serviços, hyprland.lua, SDDM)
install.sh           instalação mínima: copia kortex/ para ~/.config/quickshell/kortex
README.md            manual (cópia idêntica em kortex/README.md, que vai para a pasta instalada)
CHANGELOG.md         histórico de versões
dev/verificar.sh     verificações que rodam sem Hyprland (ver abaixo)
dev/hl-mock.lua      imitação da API hl do Hyprland, para rodar o hyprland.lua gerado fora dele
docs/                documentação de desenvolvimento
kortex/              o shell em si, o que é copiado para ~/.config/quickshell/kortex
  shell.qml          ponto de entrada: instancia tudo e define os atalhos IPC
  services/          singletons (estado, leitura do sistema, processos)
  widgets/           componentes visuais reutilizáveis
  modules/<área>/    barra, janelas e painéis (módulos qs.modules.<área>)
  scripts/           auxiliares em bash chamados pelo shell e pelo hyprland.lua, e o bt-agent.py
                     (agente de pareamento Bluetooth, em Python com python-dbus e python-gobject)
  themes/            temas embutidos (colors.toml + icons.theme)
  matugen/           modelo do Matugen e cores fixas de cada modo
  sddm/  firefox/    tema da tela de login e CSS do Firefox
  shaders/           shaders (.frag) e o .qsb compilado; recompile com o comando do cabeçalho do .frag
  fonts/             Material Symbols (os ícones), com a licença
```

Os imports `qs.services`, `qs.widgets` e `qs.modules.bar` são criados pelo Quickshell a partir das pastas; não existe `qmldir` no repositório.

## Limites do ambiente na nuvem

Aqui não há Hyprland, Quickshell, Wayland, NetworkManager nem PipeWire, então **não dá para abrir o shell nem ver a interface**. O que dá para fazer é ler, editar, rodar os scripts num HOME falso e checar a sintaxe. Depois de uma mudança, peça ao usuário para testar na máquina dele:

```bash
qs -c kortex            # inicia (o Quickshell recarrega sozinho ao salvar um arquivo)
qs -c kortex log        # log da instância em execução: erros de QML aparecem aqui
qs -c kortex kill; qs -c kortex   # reinício completo (necessário para fontes e arquivos novos)
```

## Como verificar uma mudança

```bash
bash dev/verificar.sh               # tudo
bash dev/verificar.sh --so-scripts  # só bash -n, shellcheck e a fumaça dos scripts
bash dev/verificar.sh --so-qml      # só sintaxe QML e qmllint
```

O script confere a cópia do README, as permissões (scripts com `+x`, QML sem), `bash -n` e `shellcheck` (nível info) em todos os scripts, a sintaxe de todos os QML (`qmlformat`), o `qmllint` (só imports sem uso, expressões com vírgula, ids que escondem propriedades e erros, porque os tipos do Quickshell não existem aqui) e uma fumaça dos scripts num HOME temporário (inclusive o `install.sh` sem o Hyprland no `PATH`). As ferramentas do QML precisam ser do Qt 6: ele procura primeiro em `/usr/lib/qt6/bin` e ignora as do Qt 5 que o `qt5-declarative` põe em `/usr/bin`. Sem as ferramentas no sistema, ele instala `shellcheck-py` e `PySide6-Essentials` num venv em `~/.cache/kortex-dev`. Deve terminar com `Tudo certo.` antes de cada commit.

O que ele **não** pega: erros de tipo, propriedades inexistentes, bindings quebrados e qualquer coisa que dependa do Quickshell. Para isso, releia o diff com cuidado e peça o teste com `qs -c kortex log`.

## Convenções

- **Texto.** Interface e documentação em pt-BR. Preferência do usuário para tudo que for escrito (docs, commits, comentários novos, respostas): **sem travessão** (exceto em diálogos) e com dois-pontos e ponto e vírgula usados com moderação. Números com vírgula decimal (`Theme.decimal(v, 1)`) e reticências como um caractere só (`…`).
- **Commits.** Uma linha no formato `Área: o que mudou`, como no histórico (`Barra flutuante: clicar ao lado da barra também fecha os painéis`).
- **Comentários.** Densos e explicativos, em português, dizendo o porquê (o código diz o quê). Todo arquivo QML começa com um comentário de cabeçalho dizendo o que ele é e quais cliques e teclas aceita; todo script começa com o uso (`#   script.sh <args>`) e os códigos de saída.
- **Animações.** Toda duração passa por `Motion.ms(base)`, que aplica a velocidade escolhida e devolve 0 com as animações desligadas; nunca um número solto em `duration:`. As exceções são os indicadores de carregamento (`Spinner`, `LoadingBar`, `Skeleton`) e as contagens regressivas, que são informação. Curvas e deslocamentos também vêm de `Motion` (`curveOut`, `curveIn`, `curveStd`, `pick()`).
- **QML.** Ordem dentro de um objeto: `id`, propriedades, sinais, funções, propriedades herdadas, handlers e, por fim, os filhos. `id: root` no objeto raiz. Cores, fontes e tamanhos sempre de `Theme` (`Theme.textBody`, `Theme.radius`, `Theme.accent`…), ícones sempre de `Icons` desenhados com o widget `Icon`. O fundo de um painel, de uma janela ou de um aviso é `Theme.surface` (o padrão do `GradientFrame`), que fica translúcido com a opacidade dos painéis; `Theme.bg` fica para o que está dentro deles. O realce de uma linha de lista usa `Theme.radiusSmall`.
- **Permissões.** Scripts em `kortex/scripts` com `+x` (exceto `firefox-common.sh`, que é só `source`); arquivos QML sem `+x`.
- **Versão.** Fica em `README.md` (linha 3, e na cópia em `kortex/README.md`), em `modules/settings/AboutPage.qml` e no título da seção do `CHANGELOG.md`.

## Armadilhas conhecidas

1. **Popups da barra não recebem teclado.** `PopupWindow` não ganha o foco do teclado no Wayland. Qualquer campo de texto vai numa janela própria feita com `widgets/OverlayPanel.qml` (ver `docs/arquitetura.md`).
2. **`HyprlandFocusGrab` não serve para "clicar fora fecha".** Os popups da barra usam a camada `modules/clickaway/ClickAway.qml`; as janelas `OverlayPanel` ocupam a tela toda e tratam o clique no próprio fundo.
3. **O `FileView` do `settings.json` precisa do `blockWrites: true`.** Sem ele a gravação é assíncrona: uma segunda chave mudada antes de a primeira gravação terminar faz o `FileView` reler o estado da primeira (a segunda chave volta ao valor antigo na memória por um instante), e uma terceira chave na mesma volta grava esse estado incompleto. De três mudanças seguidas, a do meio se perdia. Com o `blockWrites` (em `services/Settings.qml`), várias chaves seguidas são seguras. O `Settings.applyBatch([[chave, valor], …])` continua existindo para o que precisa esperar outra coisa (a pasta de um tema mudar de nome) e para espalhar uma restauração completa. Não tire o `blockWrites` nem crie outro `FileView` com `JsonAdapter` sem ele.
4. **Mapas e listas do `Settings.data` não podem ser mudados no lugar.** Faça uma cópia e reatribua (`Object.assign({}, …)`, `concat`, `filter`), senão nada é gravado. `Settings.setFlag(mapa, chave, valor)` faz isso para `barItems` e `powerActions`.
5. **Escala fracionária (1.25×, 1.6×) borra bordas.** Tamanhos de janela passam por `Theme.snapUp(px, devicePixelRatio)`, posições de camada caem em pixel físico inteiro e bordas são desenhadas com `GradientBorder`/`GradientFrame`, nunca com `Rectangle.border`.
6. **`hyprctl reload` apaga tudo que foi aplicado com `hyprctl eval`.** `services/HyprSync.qml` e `services/Keyboard.qml` reaplicam no evento `configreloaded`. Qualquer ajuste novo ao vivo precisa entrar num deles.
7. **Nada de um tema é executado.** Só se leem `colors.toml`, o nome em `icons.theme` e as imagens de `backgrounds/`. Mantenha assim.
8. **Valores do usuário nunca entram concatenados num comando de shell.** Passe como argumentos: `["sh", "-c", 'cmd "$1"', "sh", valor]`. As exceções são conscientes e documentadas: `Settings.shell()` para comandos que o próprio usuário escreve (`lockCommand`, `audioApp`) e o `>` do lançador.
9. **`Process` em execução não pode ser religado.** O padrão é `if (!proc.running) proc.running = true`, com uma flag `_again` quando um pedido chega durante a execução. O `stderr` pode terminar depois do `onExited`: o `Network.qml` espera 120 ms antes de ler.
10. **Delegates recebem cópias de objetos JS.** Compare por conteúdo ou chave, não por identidade (`Keyboard.labelOf`, `Notifs.removeToast`).
11. **Dentro de `onThemeChanged`, use `Theme.themeByName(Settings.data.theme)`.** Uma propriedade derivada ainda teria o tema anterior nesse momento.
12. **Ids com nome de propriedade de `Item` escondem a propriedade** (`left`, `right`, `top`, `width`…, ou o mesmo nome de um `alias`). O qmllint acusa (`id-shadows-member`).
13. **O Kitty não tem `-e`.** Para abrir um comando no terminal, use `Settings.runInTerminal([...])`, que passa por `scripts/term.sh`.
14. **As cores padrão (Morello) estão repetidas** em `services/Theme.qml`, `sddm/theme.conf`, `sddm/Main.qml`, no `hyprland.lua` e no `hyprlock.conf` que o `arch-setup.sh` grava e no README (seção 6). Mudar o tema padrão é mudar todos.
15. **Uma regra de camada com nome é atualizada no lugar.** Mandar `hl.layer_rule` de novo com o mesmo `name` reaproveita a regra e acrescenta os efeitos (vale o último valor de cada um), e o Hyprland reaplica as regras às camadas já abertas. É assim que o desfoque dos painéis liga e desliga ao vivo (`HyprSync._blurRule`). Para regras fixas, mande uma vez só (`_animsSet`).
16. **Senhas de Wi-Fi vão na linha de comando do `nmcli`** (`connect … password X`, `modify … psk X`) e ficam visíveis em `/proc` enquanto o comando roda. Limitação conhecida, registrada na auditoria.
17. **O Hyprland é configurado em Lua** (Hyprland 0.55 ou mais novo). Ao vivo, mande código pelo `hyprctl eval` (resposta `ok` ou o erro) e dispatchers na sintaxe `hl.dsp.*`; o `keyword` e o `dispatch workspace 3` antigos não existem mais. Texto que entra nesse código passa por `HyprSync.lua(s)`, e um bloco com várias instruções vai pelo `HyprSync.guard()` (um erro de Lua interrompe o resto do bloco; uma opção desconhecida no `hl.config` não interrompe, só vira erro de configuração). A referência da API está em `/usr/share/hypr/stubs/hl.meta.lua` e no `/usr/share/hypr/hyprland.lua` de exemplo; `Hyprland --verify-config -c arquivo.lua` confere um arquivo sem mexer na sessão. O `hyprlock.conf` e o `hypridle.conf` continuam no formato antigo.

## Receitas

**Nova opção no `settings.json`.** Declare a propriedade no `JsonAdapter` de `services/Settings.qml`, com o padrão e um comentário. Se for de aparência, animação ou barra, inclua em `Settings.resetAppearance()`. Ponha o controle numa página de `modules/settings/` (um `SettingRow` com `Toggle`, `Segmented`, `SliderBar` ou `Stepper`) e documente na tabela da seção 5 do README.

**Novo item da barra.** Crie `modules/bar/XIndicator.qml` a partir de `BarButton`, com `required property string screenName` (e `present: false` quando não houver o que mostrar). Acrescente o id ao grupo certo de `Settings.barDefaultLayout`, ao mapa `components` e a um `Component` em `modules/bar/Bar.qml`, à lista `items` de `modules/settings/BarPage.qml` e às seções 4 e 5 do README. Um painel do item é um `BarPopup` dentro do botão, com `popupId` único, aberto por `Popups.toggle(id, screenName)`.

**Nova janela com teclado.** Crie o arquivo em `modules/<área>/` como `LazyLoader { active: Popups.xOpen; OverlayPanel { layerNamespace: "kortex-x" … } }`. Em `services/Popups.qml`, a flag, a função `openX()` e a linha em `_closeOverlays()`. Instancie em `shell.qml` e acrescente o namespace (sem o prefixo) a `HyprSync._windows`, que alimenta a regra `popin` (a janela cresce do centro) e a regra de desfoque dos painéis.

**Novo atalho IPC.** Um `IpcHandler` em `shell.qml`, na lista comentada do topo do bloco e no README (seção 3 ou 4).

**Novo ícone.** Uma propriedade em `services/Icons.qml` com o nome do catálogo do Material Symbols (fonts.google.com/icons). A fonte já está em `fonts/`.

**Novo tema embutido.** Uma pasta em `kortex/themes/<nome>/` com `colors.toml` (formato no README, seção 4) e `icons.theme` (uma variante do Yaru; vazio, ela é escolhida pelo acento). Acrescente o nome à lista de temas do README e à contagem esperada em `dev/verificar.sh` (`list-themes: 8 temas`).

**Novo script.** Em `kortex/scripts/`, com shebang, cabeçalho de uso e códigos de saída e `chmod +x`. O shell chama com `["bash", Settings.scripts + "/x.sh", …]`. Se ele grava arquivos, acrescente uma checagem na fumaça de `dev/verificar.sh` e use variáveis de teste como as que já existem (`KORTEX_GNOME_NO_GSETTINGS`, `KORTEX_SDDM_THEME_DIR`, `KORTEX_SDDM_ROOT`).

**Fechar uma versão.** Troque a versão nos lugares listados em *Convenções*, escreva a seção no `CHANGELOG.md` (Novidades, Mudanças, Correções), copie o README para `kortex/README.md` e rode `bash dev/verificar.sh`.
