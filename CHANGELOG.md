# Histórico de versões

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
