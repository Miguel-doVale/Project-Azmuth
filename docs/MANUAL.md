# Manual do Project Azmuth

Guia de uso de tudo que existe na rice: atalhos, sistemas, comandos, arquivos e
como resolver problemas. O documento-mestre (`00 - MASTER - Project Azmuth.md`)
explica o *porquê* do projeto; este manual explica o *como usar*.

Última atualização: 2026-10-09.

---

## 1. Começo rápido

| Quero… | Faça |
|---|---|
| Trocar de alien (DNA) | `Super + Space` → ←/→ → Enter |
| Trocar direto | `Super + Numpad 1–0` (ou `Super + Alt + 1–0`) |
| Voltar ao Neutral | `Super + Esc` |
| Abrir um app | `Super + D` |
| Alternar janelas | `Alt + Tab` (segure o Alt) |
| Ver tudo que está aberto | `Super + Tab` |
| Configurar o Omnitrix | `Super + Shift + O` |
| Relógio, música, calendário | `Super + W` |
| Bloquear | `Super + M` |
| Desligar / reiniciar | `Super + Shift + Q` |
| Captura de área | `Super + Shift + S` |

---

## 2. Atalhos

### Omnitrix
| Atalho | Ação |
|---|---|
| `Super + Space` | Omnitrix HUD: ←/→ ou scroll giram, Enter transforma, 0–9 pula, Esc sai |
| `Super + Numpad 1–0` · `Super + Alt + 1–0` | Master Control: transforma direto no alien do slot |
| `Super + Esc` | Volta ao Neutral |
| `Super + Shift + R` | Randomizer (sorteia um DNA) |
| `Super + Y` | Aceita a sugestão do Context Engine |
| `Super + Shift + M` | Liga/desliga Master Control (troca automática, energia congelada) |
| `Super + Shift + O` | Central de Configuração |
| `Super + W` | Dashboard (relógio, DNA, música, calendário, notificações) |
| `Super + Alt + E` | Modo edição da área de trabalho (desktop canvas) |

### Apps e janelas
| Atalho | Ação |
|---|---|
| `Super + D` | Lançador: ←/→ app, ↑/↓ playlist, digitar busca, Ctrl+F favorita |
| `Alt + Tab` / `Alt + Shift + Tab` | Constelação: próxima/anterior janela (soltar Alt vai) |
| `Super + Tab` | Constelação exploração: arrastar gira, scroll zoom, WASD voa |
| `Super + '` | Terminal (kitty) |
| `Super + E` | Gerenciador de arquivos |
| `Super + Q` | Fechar janela (terminal/editor pede 2º toque em 1 s) |
| `Super + N` / `Super + Shift + N` | Minimizar / restaurar a última minimizada |
| `Super + F` / `Super + Shift + F` | Tela cheia / maximizar |
| `Super + Shift + Space` | Janela flutuante |
| `Super + P` · `Super + J` | Pseudo-tile · alternar divisão |
| `Super + ←↑→↓` | Mover o foco (no HUD: girar o disco) |
| `Super + 1–0` / `Super + Shift + 1–0` | Ir para workspace / mandar janela |
| `Super + scroll` | Workspace anterior/próximo |
| `Super + Z` / `Super + Shift + Z` | Área de rascunho (scratchpad) |
| `Super + arrastar (botão esq./dir.)` | Mover / redimensionar janela |

### Sistema
| Atalho | Ação |
|---|---|
| `Super + Shift + V` | Área de transferência: busca, filtros, Ctrl+P fixa, Del apaga |
| `Super + Shift + S` | Captura de área (vai direto para a seleção) |
| `Print` · `Super + Print` | Captura da tela inteira · da janela ativa |
| `Super + Alt + S` | Menu de captura (inclui gravação; repetir o atalho para) |
| `Super + M` | Bloquear (desbloqueio pelo Omnitrix) |
| `Super + Shift + Q` | Menu de energia |
| Teclas de mídia / brilho / volume | Funcionam normalmente |

---

## 3. Os sistemas

### DNAs
Um **DNA** é um estado completo do sistema: cores, gaps, layout, wallpaper,
tema do terminal, da barra, das notificações e da tela de bloqueio, apps e som.
Hoje existem **Neutral** (azul, Arch no core) e **Massa Cinzenta** (verde,
foco em código). Os outros 9 aliens aparecem bloqueados até ganharem um DNA.

### Energia do Omnitrix
- Transformado, a carga **descarrega** (padrão: 100 → 0% em 10 min).
- No Neutral, **recarrega** (padrão: 0 → 100% em 5 min).
- Abaixo do mínimo (padrão 20%) não dá para transformar.
- Em 0% destransforma sozinho, com bipes no último minuto.
- Master Control congela a carga. Tudo ajustável na Central → Omnitrix.
- Onde ver: cápsula da barra, Dashboard, anel OMNITRIX na área de trabalho.

### Context Engine
Observa o app em foco. Com VS Code/IDE aberto por 1,5 s, sugere o Massa
Cinzenta (notificação de 5 s; `Super + Y` aceita). Com Master Control ligado,
troca sozinho.

### Área de trabalho viva
O Omnitrix do centro é desenhado ao vivo: circuitos com pulsos de energia
(mais rápidos com a CPU alta), anel de energia, o Arch no core que **muta**
para a ampulheta ao transformar, e a silhueta do alien no centro. Clicar nele
abre o HUD. Em volta: relógio e anéis de CPU, RAM, temperatura e energia.
Desligável na Central.

### Barra (HUD galvânico)
Workspaces com os ícones dos apps, minimizados, janela ativa, bandeja,
volume (scroll ajusta), rede, CPU/RAM, bateria, energia. A cápsula central
mostra o DNA, o anel de energia e o tempo/carga. Clique no Omnitrix da barra:
HUD · direito: Randomizer · meio: Master Control.

### Lançador (`Super + D`)
O Omnitrix com apps no lugar dos aliens. As **playlists** (nome, runa, cor,
ordem e apps) são editadas na Central → Apps. Apps que não estão em nenhuma
playlist aparecem em **SEM PLAYLIST**.

### Constelação (`Alt + Tab` / `Super + Tab`)
Workspaces como nós num espaço 3D, janelas como miniaturas ao vivo.
Exploração: arrastar gira, scroll aproxima, **WASD** voa (Espaço/Ctrl sobe e
desce, Shift acelera), a mira + **E** entra, **R** volta.

### Bloqueio pelo Omnitrix (`Super + M`)
- O relógio fica parado. **←** e **→** dão um tranco no aro; **↑** aperta o core.
- A senha é a sequência de movimentos. Acertou, desbloqueia (sem Enter).
- Cada movimento aparece como uma runa Galvan sorteada.
- **Tab** troca para a senha do Arch (os caracteres também viram runas).
- 3 sequências erradas → só a senha.
- Gravar a sequência (num terminal seu): `azmuth lockseq set L R R U L R`
  (L = ←, R = →, U = ↑; mínimo 6).
- Testar sem travar: `azmuth lock --preview` (a prévia não confere a senha do Arch).
- A suspensão e o bloqueio por inatividade (10 min) usam a mesma tela.

### Alfabeto Galvan
24 runas próprias (Mente, Código, Rede, Som, Jogo, Trabalho, Sistema,
Estrela, Energia, Tempo, Visão, Dados, Fogo, Água, Cristal, Velocidade,
Força, Fantasma, Chave, Núcleo, Social, Mídia, Portal, Instinto). Usadas nas
playlists, menus e no bloqueio. Novas runas: editar `tools/gen_galvan.py` e
rodar `python3 tools/gen_galvan.py`.

### Central de Configuração (`Super + Shift + O`)
- **Omnitrix**: Master Control, sugestões, área viva, sons, Não perturbe, energia, apps por DNA, bloqueio.
- **Apps**: playlists do lançador (nome, runa, cor, ordem, apps; apps soltos em SEM PLAYLIST).
- **Wi-Fi**: liga/desliga, rede atual, lista com sinal, conectar com senha (via D-Bus), esquecer.
  O chip de rede da barra abre esta aba.
- **Som**: saída e microfone padrão, volume e mudo por dispositivo e por app, visualizador com o
  nível real do áudio. O chip de volume da barra abre esta aba (clique direito = mudo).
- **Área de trabalho**: área viva, widgets na tela (tamanho, remover), catálogo e **Editar na tela**.

### Desktop canvas
`Super + Alt + E` (ou Central → Área de trabalho → Editar na tela): arraste os widgets, scroll muda
o tamanho (50–200%), ✕ remove, guias puxam para o centro, a barra do topo adiciona do catálogo
(relógio, anéis, energia, DNA, música, calendário, barras do sistema). Esc ou Concluir sai.
Salvo em `~/.local/state/azmuth/desktop.json`.

### Notificações
Saem de baixo da cápsula da barra. Clique abre o app; × fecha; botões de ação
quando o app oferece; o mouse em cima pausa. Histórico no Dashboard (4 + ver
mais). Não perturbe na Central.

### Área de transferência (`Super + Shift + V`)
Busca, prévia completa, filtros (Tudo, Texto, Links, Cores, Imagens,
Fixados), amostra de cores `#hex`, miniaturas, **Ctrl+P** fixa, **Del**
apaga, **Apagar tudo** (2 cliques; fixados ficam).

### Capturas
Área vai para a área de transferência, salva em `~/Pictures/Screenshots` e
notifica com miniatura (Abrir / Pasta). Gravações em `~/Videos/Recordings`.

### Menu de energia (`Super + Shift + Q`)
Bloquear e Suspender são imediatos; Sair, Reiniciar e Desligar têm contagem
de 3 s cancelável com Esc. Atalhos: 1–5 ou B S E R D.

### Terminal
Cores do DNA (mudam ao vivo), prompt `⧗ DNA usuário pasta`, banner com o
Omnitrix em ASCII, botão direito cola.

### Login (SDDM)
Tema Omnitrix. Instalar/atualizar: `bash sddm/install.sh` (pede sudo);
remover: `bash sddm/install.sh --remove`.

---

## 4. Linha de comando (`azmuth`)

| Comando | O que faz |
|---|---|
| `azmuth apply <dna>` | Transforma no DNA (ex.: `massa_cinzenta`) |
| `azmuth slot <0-9>` · `neutral` · `random` | Master Control · Neutral · Randomizer |
| `azmuth accept` · `master on/off/toggle` | Aceita sugestão · Master Control |
| `azmuth hud` · `power` · `lock [--preview]` | Abre HUD · energia · bloqueio |
| `azmuth lockseq set … / clear / status` | Sequência do bloqueio |
| `azmuth shot area/full/window/menu` | Capturas |
| `azmuth set <chave> <valor>` · `settings` | Preferências (ex.: `timer.minutes 15`) |
| `azmuth current [--json/--name]` · `roster` | DNA ativo · catálogo |
| `azmuth restore` · `wallpaper` · `install` | Reaplicar · wallpaper · links das configs |

---

## 5. Onde as coisas moram

| Caminho | Conteúdo |
|---|---|
| `~/Documents/Coding/Project Azmuth/` | O projeto (git) |
| `dna/*.yaml` | Os DNAs · `dna/omnitrix.yaml` = slots do numpad |
| `src/core.py` · `src/context_engine.py` | Motor (CLI) · daemon de contexto e energia |
| `shell/` | Tudo visual (Quickshell): barra, HUD, lançador, Central… |
| `hypr/azmuth.lua` | Atalhos e autostart do Azmuth |
| `assets/` | Sons, wallpapers, arte dos aliens |
| `tools/` | Geradores: sons, wallpapers, logo ASCII, runas |
| `~/.local/state/azmuth/` | Estado: DNA atual, preferências, playlists, logs |
| `~/.local/state/azmuth/*.log` | `context.log`, `shell.log` |

---

## 6. Criar um DNA novo

1. Copie `dna/massa_cinzenta.yaml` para `dna/<id>.yaml` e ajuste.
2. Crie `rofi/<id>.rasi` (pode ficar vazio).
3. Wallpaper: `.venv/bin/python tools/gen_wallpapers.py dna/<id>.yaml`.
4. Arte (opcional): SVG em `assets/art/` e `hud.art` no YAML.
5. Pronto: o alien desbloqueia no HUD e no numpad.

---

## 7. Problemas

| Sintoma | Solução |
|---|---|
| Barra/HUD sumiram | `pkill -x qs; qs -p ~/Documents/Coding/"Project Azmuth"/shell &` |
| Tela preta do nada | Mexa o mouse; senão `hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'` |
| Senha do Arch recusada várias vezes | O faillock trava após 3 erros por 10 min; espere |
| Tela travada e a shell caiu | `Ctrl+Alt+F3`, entre, rode `qs -p ~/Documents/Coding/"Project Azmuth"/shell ipc call hud lock` (ou reinicie a shell), volte com `Ctrl+Alt+F1`/`F2` e desbloqueie |
| Algo estranho depois de `hyprctl reload` | `azmuth restore` |
| Ver o que aconteceu | `~/.local/state/azmuth/context.log` e `shell.log` |
