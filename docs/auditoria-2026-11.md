# Auditoria do código, novembro de 2026

Revisão do Kortex depois da migração para o Hyprland em Lua (branch `hyprland-lua`, ainda sem commit) e dos 25 commits feitos desde a auditoria de outubro (`cd1ce35`): Gerenciador de Processos, Tailscale, agente Bluetooth, shader do papel de parede, animações, Firefox e GNOME. Cerca de 18,8 mil linhas de QML, bash, Python e Lua, mais o `arch-setup.sh`, o `install.sh` e o README.

Diferente da revisão anterior, esta foi feita na máquina do usuário, com Hyprland 0.57.0 e Quickshell 0.3.2 rodando. Isso permitiu checagens que o ambiente na nuvem não permite:

- `bash dev/verificar.sh` completo, inclusive o `Hyprland --verify-config` do `hyprland.lua` gerado e as 1296 combinações de animação: **Tudo certo**.
- `qmllint` com os tipos do Quickshell (uma cópia do shell com `qmldir` gerados), que acusa propriedade inexistente e nome indefinido.
- Testes ao vivo do `hyprctl eval` (erros, seletores, dispatchers) e do `--verify-config` com `user.lua` quebrado.
- Todas as janelas do Kortex abertas e fechadas pelo IPC, com o log da instância conferido depois.

## Avaliação geral

A migração para Lua está completa e funcionando. O Hyprland carrega o `hyprland.lua`, o `hyprctl configerrors` está vazio, não sobrou nenhuma chamada no formato antigo (`keyword`, `dispatch workspace 3`, `--batch`) e a cópia instalada é idêntica ao repositório. O código novo segue o padrão do resto do projeto: comentários que explicam o porquê, valores passados como argumentos e scripts defensivos.

Foram encontrados seis defeitos, nenhum grave. Dois vieram da migração (o `reload` sem `config-only` e a aplicação ao vivo frágil a erros) e um deixa lixo no disco a cada início do shell (`btop-theme.sh`). Há também pendências de repositório e alguns pontos de documentação desatualizados.

## O que já foi corrigido

Corrigidos na mesma sessão, com `bash dev/verificar.sh` em **Tudo certo** e testados ao vivo:

- Os seis defeitos (itens 1 a 6). O 1 ganhou uma checagem na fumaça (o tema do btop aplicado duas vezes não deixa temporário), e os 31 temporários que tinham sobrado foram apagados. O 3 usa o `HyprSync.guard()`, testado no Hyprland com duas instruções quebradas no meio: as duas voltaram como erro e as seguintes rodaram. O verificador também roda o Lua protegido de todas as animações no `dev/hl-mock.lua`. No 6, depois de um `hyprctl reload config-only`, a borda inativa continuou translúcida e o `HyprSync` refez os atalhos e as animações sem erro. O `hyprland.lua` da máquina recebeu o bloco de cores novo (com cópia `.bak`); numa instalação nova ele vem do `arch-setup.sh`.
- A conferência da versão do Hyprland (item 11), no `arch-setup.sh` e no `install.sh`.
- Toda a documentação desatualizada (itens 13 a 18).

Continuam pendentes os itens 7 a 10 e o 12, que dependem de uma decisão ou de um pacote.

## Defeitos

1. **`btop-theme.sh` deixa um arquivo temporário a cada aplicação sem mudança** (`kortex/scripts/btop-theme.sh:93`). Quando o tema gerado é igual ao `kortex.theme` que já existe, o temporário não é movido, mas o `trap - EXIT` desliga a limpeza mesmo assim. Como o tema é reaplicado a cada início do shell, os arquivos se acumulam: havia 31 `.kortex.XXXXXX` em `~/.config/btop/themes/`, de 16/10 a 03/11. Correção: apagar o temporário no ramo sem mudança (ou mover o `trap -` para dentro do `if`). A fumaça do `dev/verificar.sh` roda o script uma vez só; rodar duas vezes e conferir que não sobra `.kortex.*` pegaria o caso.

2. **`terminal-apply.sh` perdeu o `config-only`** (`kortex/scripts/terminal-apply.sh:55`). A migração trocou `hyprctl reload config-only` por `hyprctl reload`. O 0.57 ainda aceita a opção (`hyprctl` sem argumentos lista `reload [config-only]`), e sem ela ligar ou desligar o desfoque do terminal recarrega também os monitores, o que pode piscar a tela. Regressão da migração.

3. **Um erro no código ao vivo derruba o resto e não é tentado de novo** (`kortex/services/HyprSync.qml:70-120`). O `apply()` junta tudo num `hyprctl eval` só (atalhos, regras de camada, animações, bordas). No Lua, o primeiro erro interrompe o bloco: testado ao vivo, `error()` na segunda linha impediu a terceira (código de saída 7), e `hl.config` com chave desconhecida também lança erro. Além disso, `_osdBound`, `_animsSet` e `_bound` são marcados antes da resposta, então o que não foi aplicado só volta no próximo reload. Hoje o verificador garante que todo o Lua gerado é aceito pelo 0.57, mas uma versão futura que mude um nome de opção ou de estilo desligaria tudo que vem depois. Sugestão: envolver cada instrução num `pcall` dentro do próprio código mandado e devolver os erros juntos, ou marcar as flags só depois do `ok`.

4. **O aviso de migração aponta para a seção errada** (`kortex/services/HyprSync.qml:130`). Ele diz "veja a seção 2 do README", mas o texto sobre o `hyprland.lua` está na seção 3 (Integração com o Hyprland).

5. **Mensagem de falha do `tailscaled` nunca aparece** (`kortex/services/Tailscale.qml:184`). `root.friendly(startErr.text) || "Não foi possível iniciar o tailscaled."`: o `friendly()` sempre devolve texto (no mínimo "Não foi possível alterar o Tailscale."), então a alternativa nunca é usada e a mensagem fica genérica.

6. **`hyprBorders` desligado só vale até o próximo reload ou login.** O `theme-apply.sh` respeita a opção ao vivo, mas o `hyprland.lua` gerado sempre pinta as bordas com as cores do `hyprland-colors.lua`. Além disso, a borda inativa sai opaca no login (`colors.muted`) e translúcida (`aa`) depois de uma troca de tema ou de um reload, porque só o `theme-apply.sh` e o `HyprSync` acrescentam o alfa. Já era assim com o `hyprland.conf`; não é regressão. Correção simples: o `theme-apply.sh` gravar no `hyprland-colors.lua` a cor da borda inativa já com o alfa e um campo dizendo se as bordas seguem o tema, e o `hyprland.lua` usar esses dois. Aí o `_colorsLost` do `HyprSync` deixa de ser necessário.

## Pendências

7. **Dois commits do Firefox fora da `main`.** `origin/atualizacoes-pendentes` tem `1476fe1` ("o tema fica só na interface; os sites sempre com a aparência clara") e `4c49d01` ("interface legível com qualquer tema do Firefox e CSS atualizado nos perfis já configurados"), que não entraram no merge do PR #5 e não estão na `hyprland-lua` nem na cópia instalada. Mexem em `kortex-chrome.css`, `firefox-setup.sh`, `verificar.sh`, README e CHANGELOG. É preciso decidir se entram (num PR novo, sobre a `main`) ou se foram descartados de propósito.
8. **Branches que podem ser apagadas.** `origin/claude/serene-albattani-6kp7dy` já está na `main`; `origin/firefox-configura-sozinho` e `origin/gnome-gtk3-e-gtk4-puro` foram reaplicadas como `58b59db` e `8f8b2a0`.
9. **A migração está sem commit.** São 23 arquivos na `hyprland-lua`, contando o `dev/hl-mock.lua`, que nem está no git, e a correção do HyprMod no `arch-setup.sh` feita nesta sessão.
10. **Arquivos do formato antigo que ninguém mais lê.** Em `~/.local/state/kortex`: `monitors.conf` e `hyprland-terminal.conf`. Em `~/.config/hypr`: `hyprland.conf`, `user.conf` e `hyprland-gui.conf` (o HyprMod já migrou para o `.lua`). São inofensivos. O `hyprland-colors.conf` continua necessário, porque o `hyprlock` o lê.
11. **Nenhum instalador confere a versão do Hyprland.** O `arch-setup.sh` instala a do repositório (0.57), mas o `install.sh` e o `--no-hypr-config` podem cair num Hyprland anterior ao 0.55. Aí o problema só aparece depois, pelo aviso do `HyprSync`. Uma checagem de `Hyprland --version` com um aviso no fim resolveria.
12. **O `.qsb` do shader não pode ser conferido aqui.** O `qt6-shadertools` não está instalado, então o verificador pula a comparação com o `.frag`. Os dois vieram no mesmo commit (`0ee7f60`) e o `.qsb` contém os uniforms do `.frag`, mas só o `qsb` confirma que estão em dia.

## Documentação desatualizada

13. `docs/arquitetura.md`: faltam os serviços `Processes` e `Tailscale`, os scripts `brightness.sh` e `processes.sh` e o alvo IPC `processes`.
14. README, seção *Estrutura*: falta `modules/processes` (Gerenciador de Processos).
15. README, seção 1: falta o `wl-clipboard`, usado para copiar os endereços do Tailscale (o `arch-setup.sh` já o instala).
16. `gnome-setup.sh --remove` responde "apps GTK4 e Editor de Texto voltam ao padrão", mas desde o `8f8b2a0` também desfaz o GTK3.
17. "Restaurar padrões" (Configurações › Geral) promete desfazer a barra, mas não volta o `use24h`, que fica na página Barra.
18. `Icons.palette` não é usado em lugar nenhum.

## Pontos de outubro que continuam como estão

A senha do Wi-Fi na linha de comando do `nmcli` (`Network.qml:281` e `:383`), o `clock()` repetido em `Media.qml` e `ScreenRecord.qml` e o bloco `dwindle` no `hyprland.lua`, que não tem efeito com `layout = "master"`. Nada mudou neles.

## Conferências que não acharam problema

- **Tipos do QML.** Com os `.qmltypes` do Quickshell, o `qmllint` deu 416 avisos. Todos foram conferidos: os de tipo são falsos positivos (`QuickshellScreenInfo` e `PopupAnchor` aparecem como opacos no módulo `_Window`, e o resto vem de `Loader.item`, `itemAt()` e propriedades anexas do `PathView`). Os 349 `[unqualified]` são ids do componente de fora usados dentro de delegates, ou nomes que o SDDM injeta (`config`, `keyboard`, `index`). Nenhum nome indefinido.
- **Execução.** As sete páginas das Configurações, o lançador, o seletor de temas e de papéis de parede, o Gerenciador de Processos, as janelas de teclado e idioma, o menu de captura e o OSD abriram e fecharam sem erro de QML no log. No fim só ficaram as camadas da barra e do papel de parede.
- **Animações das camadas.** Todo `layerNamespace` do Kortex cai numa regra do `HyprSync._layerRules`.
- **Configurações.** As chaves do `settings.json` lidas, gravadas e documentadas batem.
- **Scripts e IPC.** Todo script chamado existe, nenhum script fica sem uso, e os alvos IPC do `shell.qml` estão no README.
- **Erros no `user.lua`.** O Hyprland 0.57 mostra o erro mesmo dentro do `pcall(require, "user")` (testado com erro de sintaxe, de execução e de chave). `pcall(dofile, …)` de um arquivo ausente não gera erro. O comentário do `hyprland.lua` está certo.
- **Sintaxe nova no Hyprland.** Os dispatchers `hl.dsp.focus({ window = "pid:N" })` e `{ workspace = "emptym" }` são aceitos, e o `hypridle.conf` migrado usa o `hl.dsp.dpms` certo (o `dispatch dpms on` antigo é recusado).
- **Processos.** O `processes.sh` separa o nome do processo pelo último `)` e mede a CPU contra os jiffies totais. O agrupamento por dono não entra em laço, e os processos essenciais ficam sem botão de encerrar, tanto pelo mouse quanto pelo `Delete`.
- **Bluetooth.** O agente pede confirmação para pareamentos que você não iniciou, recusa o pedido anterior em vez de deixá-lo preso e se registra de novo quando o `bluetoothd` reinicia. Limitação: dispositivos antigos com PIN fixo (`0000`) não conseguem parear, porque o PIN é sorteado.
- **Créditos.** Os arquivos com ideias adaptadas do dhrruvsharma/shell dizem de onde vieram, como o README promete.
