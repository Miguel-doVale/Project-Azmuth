# Ilha do Omnitrix + Dock — design

Data: 2026-11-14 · Status: design aprovado no protótipo v3; documento aguardando revisão
Protótipo de referência (comportamento, visual e **tamanhos reais**, tela 1920×1080): `docs/design/prototipo-ilha-dock.html` (v3)
Rascunhos no Figma: https://www.figma.com/design/P2D0TGSHkA8aHqVAx3qYNV

## 1. Intenção

A barra de cima (`shell/Bar.qml`) ocupa uma faixa fixa da tela e atrapalha: as abas do meio do
navegador ficam inacessíveis embaixo dela e tudo parece pequeno. Ela vai sair e dar lugar a duas
peças que só aparecem quando chamadas:

- **Ilha do Omnitrix** no topo, no lugar do notch: quase escondida, desce quando o mouse chega e,
  com um clique, abre um painel tipo central de controle de celular.
- **Dock** no centro da borda de baixo, sempre recolhida: só os apps principais, o Omnitrix que
  abre a roda de apps e uma faixa de workspaces com os ícones do que está aberto em cada um.

Junto vem uma lista de apps que **abrem maximizados** (o navegador primeiro) para melhorar a
visibilidade, e a troca automática da saída de som quando um fone é conectado.

**Sucesso** = a tela inteira fica para os apps; o Miguel encontra tudo (DNA, hora, Wi-Fi, som,
calendário, música, configuração) a um movimento de mouse; a navegação entre workspaces continua
tão rápida quanto hoje, porque ele usa um app por workspace e se guia pelos ícones.

### Fora do escopo (projetos seguintes, nesta ordem combinada)
Wallpaper novo → artes → idioma Galvan → 9 aliens/DNAs → voz. Widgets da área de trabalho e o
calendário ligado ao ERP pessoal também são projetos à parte (aqui o calendário só **mostra** a
cor "fixo" quando existir esse tipo de evento).

### Antiobjetivos
- A ilha abrir sozinha quando o mouse só está passando pelas abas do navegador.
- Qualquer peça reservar espaço da tela (exclusive zone).
- Perder alguma função que a barra de hoje tem sem dar outro lugar a ela.

## 2. A ilha

Uma janela de camada (Quickshell `PanelWindow`, camada Overlay ou Top, `exclusiveZone: 0`,
namespace `azmuth-island`), ancorada no topo e centralizada. A **máscara de entrada** acompanha o
formato visível de cada fase — fora dela os cliques vão para os apps.

| Fase | Visual | Entra | Sai |
|---|---|---|---|
| 1 · repouso | Só a parte de baixo do Omnitrix (Ø 44 px, ~16 px visíveis), brilho inteiro, sem contorno | padrão sem app maximizado | — |
| 2 · mouse em cima | Ilha de 420×64 px: à esquerda nome do DNA (Orbitron Medium 12, espaçado) e energia; no meio o Omnitrix com **anel de energia** em volta; à direita hora e "SÁB 14 · 98%" | mouse no Omnitrix | mouse sai por 350 ms |
| 3 · painel | 728×458 px (seção 3) | clique na ilha (ou atalho) | clique fora, Esc, atalho de novo |
| fio | Linha de luz 140×3 px no topo | app maximizado/tela cheia no monitor | app sai de maximizado |

- Transições: largura, altura, posição e cantos animados juntos (~550 ms, curva "ease-out" forte,
  `cubic-bezier(.22,1,.36,1)` no protótipo); o conteúdo de cada fase aparece depois do formato.
- **Solta × colada** (`settings.json → island.detached`, padrão `true`): solta = pílula a ~8 px do
  topo, cantos todos arredondados, borda luminosa só no meio; colada = presa ao teto, cantos
  arredondados só embaixo, sem borda. Chave na Central. No repouso e no fio não há diferença.
- **Fio e zona de ativação:** com app maximizado, a ilha vira o fio e só abre se o mouse
  **encostar no topo** (faixa de 2–3 px × ~220 px) e ficar parado **~300 ms**. O mesmo atraso não
  existe no repouso normal.
- Estados que hoje aparecem no Omnitrix da barra continuam no Omnitrix da ilha: cor do core
  (amarelo = scan, azul = recalibração), runa Chave do Life-Form Lock, energia do timer.
- Paleta e fontes saem do DNA ativo (`Colors`), como o resto da shell.

## 3. O painel (fase 3) — uma página só, compacto

728×458 px. De cima para baixo:
1. **Cabeçalho:** à esquerda o **retrato do DNA ativo** (48 px, cantos arredondados; arte do alien
   do DNA, campo `art` do tema; sem arte → o Omnitrix), nome do DNA, "troca em N min" e a barra de
   energia; no centro o Omnitrix da ilha; à direita hora, data por extenso e uma linha discreta
   "98% · CPU 10% · RAM 46% · 52°".
2. **Botões rápidos (4, compactos):** Wi-Fi, Bluetooth, Não perturbe, Life-Form. Clique liga/desliga;
   a segunda linha mostra o estado.
3. **Controles:** Som (barra + % + botão da saída atual "Fone USB ▾") e Brilho. **Rolar o mouse** em
   cima de qualquer um muda o valor em passos de 5%.
   - O botão da saída abre uma **cascata retangular baixa** logo abaixo, duas colunas (SAÍDA e
     ENTRADA), ✓ na atual; escolher troca na hora e fecha.
4. **Linha do meio (196 px):**
   - **Música (quadrado 196 px)**, widget de celular: capa como fundo, nome, artista, barra de tempo
     **clicável/arrastável** (atual e total), anterior · play/pause · próximo. Fonte: MPRIS (player
     ativo; Spotify primeiro). Sem player: "nada tocando".
   - **Calendário** do mês, compacto: hoje destacado; ponto azul = evento, amarelo = fixo.
   - **Notificações** (ocupa o resto): as mais recentes primeiro, com ícone do app, título, texto
     em uma linha e tempo; ✕ dispensa uma, "limpar" dispensa todas; rola se houver muitas.
     Fonte: o histórico que o `Notifications.qml` já guarda.
5. **Rodapé (40 px):** botão **CENTRAL** (destacado, abre a Central de configuração) · área
   **"2º plano"** com os ícones da bandeja (clique abre o menu do app: "Abrir", "Sair"…; EasyEffects
   e nm-applet ficam escondidos porque o Azmuth já cobre os dois) · à direita, botões de ícone:
   Captura, Atalhos, Bloquear, Energia.

`Super+W` abre a ilha direto no painel. O **Dashboard sai** (tudo dele está no painel).

## 4. A dock

Janela de camada no fundo, centralizada, `exclusiveZone: 0`, namespace `azmuth-dock`.

- **Sempre recolhida.** Visível só o **risquinho de workspaces**: um segmento por workspace
  ocupado (o atual aceso, os outros mais fracos). Área de ativação = o próprio risquinho
  (~150×12 px). Encostou → a dock sobe; saiu da dock por 450 ms → desce.
- **Conteúdo** (ícones de 48 px): Omnitrix à esquerda (abre a roda de apps do `Super+D`), separador, apps fixos:
  Chrome, Dolphin, Spotify, Docker, Claude, VS Code, Obsidian (lista em
  `settings.json → dock.pinned`, ids de `.desktop`, editável depois na Central → Apps).
  Ícone real do tema; ponto embaixo = aberto; traço comprido + brilho = em foco.
- **Faixa de workspaces** (aparece junto, logo acima da dock): uma pílula por workspace ocupado
  com o número e os ícones dos apps abertos nele; o atual destacado; clique troca.

## 5. Apps maximizados

`settings.json → windows.maximize` (lista de classes; padrão `["google-chrome"]`): esses apps abrem
**maximizados** (modo maximizado do Hyprland, não tela cheia). Com app maximizado ou em tela cheia
no monitor, a ilha vira fio. Regras geradas no `azmuth.lua` a partir da configuração.

## 6. Saída de som automática

Conectar fone com fio, USB ou Bluetooth torna o aparelho a saída padrão na hora (sem ir na Central).
Instalado pelo `azmuth install` (configuração do PipeWire/WirePlumber) e documentado; desligável.

## 7. O que sai e o que muda

- `shell/Dashboard.qml` sai; `Super+W` passa a abrir o painel da ilha.

- `shell/Bar.qml` deixa de ser carregado (mantido no repo até a ilha estar estável; depois sai).
- DNA com `bar.visible: false` → a ilha continua igual (o Omnitrix é a identidade do sistema) e a dock não aparece.
- Atalhos novos/alterados entram na folha `Super+/` e no manual.

## 8. Testes

- Python (unittest): leitura/validação de `island.detached`, `dock.pinned`, `windows.maximize`;
  geração das regras de maximizar.
- Shell: `qs` sem erros no log; prints no workspace 9 vazio de cada fase (repouso, mouse, painel,
  fio) e da dock aberta/fechada; testes manuais do Miguel para o atraso do fio e a rolagem.

## 9. Abordagens consideradas

- **Figma primeiro → protótipo HTML (escolhida para o design):** o Figma serviu para os primeiros
  rascunhos, mas o plano Starter estourou o limite de chamadas; o protótipo HTML mostra a animação,
  que é o centro da ideia.
- **Implementação na shell atual (escolhida):** Quickshell/QML, reaproveitando `Colors`, `Glyph`,
  os painéis da Central e o MPRIS do Dashboard. Alternativas descartadas: manter a barra e só
  escondê-la (não resolve as abas nem a sobreposição) e usar waybar/nwg-dock (fora do visual Omnitrix
  e sem a ilha).

## 10. Calls do Claude (o Miguel pode mudar)

- Ilha solta como padrão.
- Atraso de 300 ms só no modo fio; 350 ms para recolher a fase 2; 450 ms para a dock descer.
- Faixa de workspaces mostra só workspaces ocupados (mais o atual).
- Apps abertos que não estão fixos aparecem na dock **junto dos fixos, sem separador** (como no
  Windows), depois deles; somem ao fechar. (Decidido pelo Miguel.)
- Janelas minimizadas (`Super+N`) continuam com o ícone na dock; clicar restaura.
- Clique num app da dock, como no Windows: fechado → abre; aberto sem foco → foca (vai ao
  workspace dele); já em foco → minimiza. Várias janelas do mesmo app: foca a mais recente.
- Com mais de um monitor, ilha e dock aparecem no monitor em foco.

## 11. Decisões do Miguel (rodadas do protótipo)

- Repouso: só a pontinha do Omnitrix; desce e abre pros lados.
- Fase 2: interior, fonte (Orbitron fina) e cor da versão B; solta ou colada vira chave na Central.
- Painel: uma página só, **pequeno** (não ocupar a tela), com notificações e o alien na primeira vista.
- Música como widget quadrado de celular, com barra de tempo arrastável.
- Dock sempre retrátil, ativação pequena; workspaces fora da dock, com ícones dos apps; Omnitrix à
  esquerda; fixos: Chrome, Dolphin, Spotify, Docker, Claude, VS Code, Obsidian; abertos não fixos
  entram junto, sem separador.
- Bandeja: dentro do painel ("2º plano"); hoje os cliques nela não fazem nada (bug a corrigir).

## 12. Itens que entram junto no plano (pequenos, já combinados)

- Gerenciador de tarefas → aba Inicialização passa a listar também os **serviços de usuário do
  systemd** que sobem com a sessão (ex.: Docker Desktop), com o mesmo liga/desliga.
- (Feito em 2026-11-14) Docker Desktop não sobe mais no login; gerenciador de tarefas abre flutuante.
