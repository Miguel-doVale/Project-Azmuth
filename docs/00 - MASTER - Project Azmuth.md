# 00 — MASTER · Project Azmuth

> **Documento-mestre do Project Azmuth.**
> Este arquivo é a fonte de verdade do projeto. Ele existe para que, mesmo
> sem nenhum histórico de conversa, qualquer pessoa (ou IA) consiga entender
> o projeto inteiro — filosofia, arquitetura, decisões técnicas, estado do
> código e próximos passos — sem perder nada do que já foi discutido.
>
> Autor/dono: **Miguel (Sun_Akuma)** — Eng. de Software, UNDB.
> Base: **Arch Linux + Hyprland (Wayland)**.
> Última revisão do documento: 2026-10-06 — motor completo (Master Control,
> HUD, Context Engine, Randomizer) + DNA Massa Cinzenta.

---

## 1. O que é o Project Azmuth

O **Project Azmuth** é uma implementação conceitual do **Omnitrix no nível de
sistema operacional**. A premissa central: o sistema operacional **não é
estático** — ele se **transforma** dinamicamente entre diferentes estados
funcionais e estéticos, chamados de **"DNAs"** (uma referência direta às
transformações de DNA alienígena do Omnitrix, da franquia Ben 10).

Cada transformação altera, em tempo real e sem reiniciar a sessão:

- Layout de janelas, gaps (espaçamentos), bordas, arredondamento e animações do Hyprland
- Paleta de cores (bordas de janela, waybar, rofi — tudo sincronizado)
- Papel de parede (wallpaper)
- Barra de status (waybar)
- Launcher / menu (rofi)
- Quais daemons/serviços rodam ou ficam desligados
- (meta futura) Um som de transformação, estilo o "bip" do relógio do Omnitrix

O nome "Azmuth" vem do personagem **Azmuth**, o cientista galvan criador do
Omnitrix no cânone de Ben 10 — ou seja, o projeto se posiciona como "a mente
por trás do dispositivo".

### Filosofia de design visual

A identidade visual busca remeter à **tecnologia galvaniana** — estética de
Ultra-T / Mecamorfo galvânico, circuitos neon, superfícies escuras com brilho.
O objetivo de longo prazo é que o **próprio Omnitrix seja a base visual do
sistema**: um wallpaper onde o símbolo do Omnitrix fica no centro, com o logo
do Arch Linux dentro dele representando o core principal (o estado Neutral), e
o HUD do Omnitrix "nascendo" literalmente desse símbolo — ativando,
desativando, girando e mostrando os aliens.

---

## 2. Histórico do projeto (como chegamos aqui)

- O projeto **começou no ChatGPT**, depois **migrou para o Gemini**.
- Chegou a avançar mais do que o documento de handover do Gemini reflete — havia
  um `core.py` funcional trocando entre dois DNAs, waybar estilizada, etc.
- Foi **abandonado** por ter ficado trabalhoso demais (e porque a ambição
  crescia mais rápido que o que de fato rodava).
- Foi **retomado** depois de assistir a um vídeo de rice no TikTok (do criador
  **@ilyamiro.dev**), que reacendeu a confiança de que a ideia é viável.
- **O disco foi formatado e nada do projeto antigo sobreviveu.** O Azmuth está
  sendo **reconstruído do zero — e desta vez do jeito certo**, com documentação
  e versionamento desde o primeiro arquivo.

### Lição aprendida (importante)

As duas "mortes" anteriores do projeto vieram da mesma causa: **ambição
crescendo antes de qualquer coisa rodar de verdade**. A estratégia desta
reconstrução é o oposto — fechar **um DNA completo** (o Massa Cinzenta) como
template validado, usá-lo no dia a dia, e só então replicar o padrão para os
outros. Nada de desenhar os 20 perfis no papel antes de ter 1 funcionando.

---

## 3. Arquitetura: Cores vs. DNAs

A distinção que organiza todo o sistema é a separação entre **Cores** (núcleos
de infraestrutura) e **DNAs** (perfis comportamentais de interface).

```
┌─────────────────────────────────────────────────────────────┐
│                     CAMADA DE CORES (OS)                      │
│                                                               │
│   ┌───────────────────────┐   ┌───────────────────────────┐  │
│   │       ARCH CORE        │   │        KALI CORE          │  │
│   │  base nativa, dev,     │   │  cibersegurança / pentest │  │
│   │  minimalista, diária   │   │  toolchain ofensivo/def.  │  │
│   └───────────┬───────────┘   └─────────────┬─────────────┘  │
└───────────────┼─────────────────────────────┼────────────────┘
                │                             │
                ▼                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    CAMADA DE DNAs (aliens)                    │
│   os 10 aliens clássicos, cada um com uma versão por Core     │
│   geridos por: src/core.py → Hyprland IPC + waybar + rofi +   │
│                               hyprpaper                       │
└─────────────────────────────────────────────────────────────┘
```

### 3.1. Os Cores (infraestrutura)

Cores **não são skins** — representam o ecossistema de pacotes, permissões e
serviços disponíveis.

**Arch Core (núcleo primário)**
- Fundação nativa rodando no hardware bare-metal (notebook Acer Aspire 5).
- Foco: minimalismo, desenvolvimento de software, estabilidade, baixo consumo.
- Não carrega daemons pesados de segurança por padrão.

**Kali Core (núcleo de cibersegurança)**
- Subsistema de ferramentas de auditoria e segurança ofensiva/defensiva.
- **Não substitui o Arch** — opera integrado, via toolchain BlackArch,
  namespaces de rede e/ou containers rootless isolados (Distrobox / Docker).
- Fornece o backend para interceptação/injeção de pacotes, wordlists, scanning,
  análise de payload, etc.

### 3.2. Os DNAs (perfis comportamentais)

Decisão fechada: usar **os 10 aliens clássicos do Omnitrix**, cada um com uma
versão sob o Arch Core e uma sob o Kali Core — **20 DNAs no total**.

Os 10 aliens:
**Massa Cinzenta, XLR8, Quatro Braços, Diamante, Besta, Fantasmático, Aquático,
Insectoide, Ultra-T, Chama.**

> **Princípio de design dos DNAs (importante):** em vez de inventar 20
> identidades do zero, define-se **1 habilidade canônica por alien** e
> pergunta-se "como essa habilidade se expressa quando o alvo é produtividade
> (Arch) vs. quando o alvo é segurança (Kali)?". Assim o trabalho de design é de
> 10 conceitos, não 20 — o segundo Core é uma reinterpretação, não uma criação
> nova.

**As funções específicas de cada alien ainda estão EM ABERTO** — é um dos
próximos pontos a fechar com calma. O que já existe é um rascunho de direção
(ver seção 4), não decisão final.

### 3.3. Nível "Ultimate" (inspirado no Omnify)

Durante a pesquisa, o Miguel descobriu uma extensão de VS Code chamada
**Omnify** (`rafayahmed.omnify`), que dá a cada workspace do VS Code um tema de
alien Ben 10. O que chamou atenção não foi o tema em si, mas o fato de ela ter
**três níveis de intensidade** por cima de cada alien:

- **Standby** (sutil) — linha de destaque brilhando, alien de fundo discreto
- **Active** (balanceado) — barra de título + status tintados
- **Ultimatrix** (total) — IDE inteiro tintado, alien animado

Isso inspirou a ideia de dar aos DNAs do Azmuth um **nível extra "Ultimate"** —
cada DNA poderia ter uma versão "normal" e uma versão "Ultimate"
(hipercarregada, visual exagerado), ativada por um gatilho separado. Encaixa no
cânone (as formas "Ultimate" existem no Ben 10: Ultimate Diamondhead, etc).
Status: **ideia aceita como direção, ainda não implementada.**

---

## 4. Matriz de DNAs (rascunho de direção — NÃO final)

> Esta tabela é um **ponto de partida para discussão**, não decisão fechada.
> A coluna "habilidade canônica" é o que ancora cada alien; as colunas Arch e
> Kali são interpretações dessa habilidade para cada Core.

| Alien | Habilidade canônica | Arch Core (produtividade) | Kali Core (segurança) |
|---|---|---|---|
| **Massa Cinzenta** | Intelecto, gênio | Coding / deep work *(DNA-template, em construção)* | Engenharia reversa, análise estática de binário |
| **XLR8** | Velocidade | Sistema leve/rápido, troca de contexto instantânea | Varredura rápida (nmap agressivo, wordlists rápidas) |
| **Quatro Braços** | Força, multitarefa | Build pesado, compilação paralela, Docker | Brute-force paralelo (hashcat/john), scan em massa |
| **Insectoide** | Voo, múltiplos olhos | Visão geral de workspaces (overview) | Recon / OSINT — superfície exposta do alvo |
| **Diamante** | Cristal, blindagem | Hardening pessoal — backups, integridade, permissões | Blue Team — firewall, IDS, análise de tráfego |
| **Besta** | Sentidos primais | Foco zero-ruído — sem notificação, sem waybar | Monitoramento passivo por "instinto" (alertas sem dashboard) |
| **Fantasmático** | Intangibilidade, stealth | Privacidade pessoal — sem telemetria, navegação anônima | Red Team / OpSec — Tor, spoofing de MAC, evasão |
| **Aquático** | Outro habitat | Modo mídia/consumo — "mergulhar" em conteúdo | Deep packet inspection — Wireshark, captura |
| **Ultra-T** | Fundir com tecnologia | Automação / tooling — scripts, CI/CD, infra | Dev de exploit/payload — "upgradar" ferramentas |
| **Chama** | Poder bruto, fogo | Gaming / render pesado — potência crua | Exploração ativa — execução de exploit (Metasploit) |

**Único DNA com função 100% fechada hoje:** Massa Cinzenta (Arch) = ambiente de
desenvolvimento / foco profundo — verde galvânico, gaps compactos, VS Code +
Obsidian + terminais, Context Engine ativo.

**Estado Neutral:** é a base do Arch Core — uso diário, azul elétrico Galvan B
(`#38bdf8`), gaps moderados, waybar completa, animações fluidas. É o ponto de
partida e o estado "default" para onde o sistema volta.

---

## 5. Subsistemas do Omnitrix (mecanismos de controle)

### Master Control
Troca de DNA **instantânea, sem confirmação e sem telas intermediárias**.
- Gatilho: **Super + Numpad 1–0** (um atalho dedicado por alien — os 10 aliens
  batem exatamente com as 10 teclas do numpad). *Isto substitui a ideia antiga
  do Gemini de Super+F1–F6, que era limitada a 6 DNAs.* Funciona com NumLock
  ligado ou desligado. Alternativa para o AK820 (75%, sem numpad): **Super + Alt + 1–0**.
- Slot de alien ainda sem DNA → som de erro + notificação "DNA bloqueado".
- Status: **implementado** (`azmuth slot N`). Troca típica: ~130 ms no total,
  bordas/gaps mudam em ~50 ms; mais lento só quando o DNA precisa abrir apps.
- Também acionável por voz/terminal.
- O compositor aplica tudo via IPC, idealmente em < 100ms.

### Omnitrix HUD (seletor visual interativo)
Com **prévia visual e confirmação** (diferente do Master Control).
- **Super + Space** → ativa/mostra o disco do Omnitrix no centro da tela (sai o
  "core" para fora, com som; comportamento com tela cheia ainda a definir).
- **Super + seta esquerda/direita** → navega/gira entre os aliens.
- **Super + Enter** → confirma a seleção e executa a transformação.
- O scroll do mouse (Redragon M909-RGB) também gira o disco.
- Tecnologia: **decidido Quickshell/QML** (`hud/shell.qml`), com o `core.py`
  como cérebro. O HUD fica residente e invisível; abre por IPC
  (`qs -p hud ipc call hud toggle`). Mostra os 10 aliens + o Neutral (logo do
  Arch no core); aliens sem YAML aparecem bloqueados (cadeado, tremem ao
  confirmar). Na transformação, uma **onda de energia circular** sai do centro
  de todos os monitores (`hud flash`).
- Sem Quickshell instalado, `Super+Space` cai para um seletor equivalente em rofi.
- Status: **implementado.**

### Context Engine (auto-transformação assistida)
Daemon que observa o contexto (app em foco, eventos de hardware).
- **Modo assistido (padrão):** não troca sozinho. Emite notificação com timeout
  de 5s — ex: "Padrão de desenvolvimento detectado. Ativar Massa Cinzenta?
  [Super+Y aceita / Esc dispensa]".
- **Sob Master Control:** ganha permissão de troca automática imediata, com
  **Super+Esc** como rollback para o Neutral.
- Implementação (`src/context_engine.py`): escuta o socket2 do Hyprland; o app
  precisa ficar 1,5 s em foco (evita disparar no alt-tab); sugestão dispensada
  entra em cooldown de 10 min; troca manual é respeitada por 5 min. Aceitar:
  **Super+Y** ou clique na notificação. Dispensar: ignorar/fechar (Esc puro
  não foi usado para não roubar o Esc dos apps). Liga/desliga o Master Control:
  **Super+Shift+M** (ou clique do meio no chip da waybar). Também reaplica o
  wallpaper no hotplug de monitor. Log em `~/.local/state/azmuth/context.log`.

### Randomizer (falha de transformação)
Inspirado no relógio clássico que às vezes "erra" o alien.
- **Super + Shift + R** → sorteio ponderado de DNA baseado em métricas atuais
  do sistema (também: clique direito no chip da waybar).
- Pesos: +2 por janela aberta que casa com os gatilhos do DNA; o Neutral ganha
  peso com a carga da CPU. Nunca sorteia o DNA atual. **Implementado.**

---

## 6. Hardware e ambiente

**Máquina:** notebook Acer Aspire 5.

**Displays (dois cenários que o sistema deve suportar):**
- **Dual monitor:** `HDMI-A-1` (1920x1080) fisicamente à **esquerda** em `0x0`;
  `eDP-1` (notebook, 1920x1080) à **direita** em `1920x0`.
- **Standalone:** só o `eDP-1` do notebook.
- Requisito: tolerar hotplug (conectar/desconectar monitor) sem quebrar
  workspaces da waybar nem coordenadas de renderização.

**Periféricos:**
- Mouse **Redragon M909-RGB** — scroll e botões laterais são gatilhos do HUD.
- Teclado **Ajazz AK820** (mecânico 75%), layout ABNT2 (`kb_layout = br`).

---

## 7. Stack técnica

- **OS:** Arch Linux (rolling).
- **Compositor:** Hyprland (Wayland).
- **Config do Hyprland:** **parser Lua** (`~/.config/hypr/hyprland.lua`) — NÃO o
  antigo hyprlang `.conf`. Desde o Hyprland 0.55 o hyprlang foi descontinuado em
  favor do Lua, que é mais rápido e integrado. Consequência prática: muito
  tutorial/ferramenta de terceiro ainda assume o `.conf` antigo e usa
  `hyprctl keyword`, que **não funciona** no parser Lua — a via correta para
  aplicar config por script é `hyprctl eval 'hl.config({...})'` e os
  dispatchers moram em `hl.dsp.*` (ex: `hl.dsp.window.move(...)`,
  com o namespace `window.`).
- **Core Engine:** Python 3 em `.venv` (dependência: `pyyaml`).
- **Wallpaper:** `hyprpaper` via IPC (`hyprctl hyprpaper preload` + `wallpaper`).
  Meta futura: `swww`/`mpvpaper` com transição animada (onda de energia
  circular saindo do centro na troca de DNA).
- **Barra:** waybar (CSS customizado, estética circuitos neon Galvan B `#38bdf8`).
- **Launcher:** rofi.
- **Clipboard:** `cliphist` + `wl-clipboard`.
- **Screenshots:** `grim` + `slurp`.
- **Áudio:** Pipewire + wireplumber (+ `pw-play` para sons de transformação).

### Decisão: Arch, não NixOS

Avaliou-se migrar para NixOS (visto no repo do ilyamiro). **Decisão: permanecer
no Arch.** Raciocínio: a customização impressionante daquele rice vem do
**Hyprland + Quickshell**, que são agnósticos de distro e rodam igual no Arch —
não vem do Nix. NixOS resolveria reprodutibilidade/rollback atômico (que o
projeto não precisa — é uma máquina só) ao custo de iteração mais lenta
(rebuild vs. `hyprctl reload`) e de uma linguagem nova (Nix) para aprender, o
que seria atrito contra o objetivo real (construir o Azmuth).

### Notas técnicas descobertas na reconstrução

- **hyprpaper 0.8:** `preload` não existe mais e `wallpaper ",path"` (todos os
  monitores) falha em silêncio — é preciso um `wallpaper "<monitor>,path"` por
  monitor. Por isso o `core.py` antigo nunca trocava o wallpaper de fato.
- **DPMS no Lua:** `hl.dsp.dpms({ action = "enable" | "disable" })`.
  `"on"`/`"off"` não são válidos (e apagaram a tela num teste).
- **Binds com função Lua** permitem que `Super+←/→` girem o HUD quando ele está
  aberto e movam o foco quando não (`hl.get_layers({ namespace = "azmuth-hud" })`).
- `hyprctl reload` reseta cores/gaps para o `hyprland.lua` → o evento
  `config.reloaded` roda `azmuth restore`.

### Decidido: Quickshell/QML para o HUD

O shell **serpantinum** (de @ilyamiro.dev) é feito em **Quickshell + QML** e é
portável (não depende de Nix). Quickshell foi feito exatamente para
widgets/overlays em Wayland (layer-shell nativo, IPC do Hyprland de fábrica).
Por isso, cogita-se usar Quickshell/QML para a **camada visual** do Omnitrix HUD
e widgets, **mantendo o `core.py` em Python como cérebro** da lógica dos DNAs.
**Decidido e implementado** (2026-10-06).

---

## 8. Estrutura do repositório

```
~/Documents/Coding/Project Azmuth/
├── .venv/                       # Python (pyyaml; pillow/numpy só p/ tools)
├── assets/
│   ├── sounds/                  # transform, neutral, hud_open, tick, error (.wav)
│   └── wallpapers/              # neutral.png (arte Arch), massa_cinzenta.png (gerado)
├── bin/azmuth                   # CLI → ~/.local/bin/azmuth
├── dna/
│   ├── omnitrix.yaml            # roster: aliens ↔ slots do numpad
│   ├── neutral.yaml             # estado base (Arch Core)
│   └── massa_cinzenta.yaml      # DNA-template
├── docs/                        # este documento + DNA_Schema_Spec.md
├── dunst/dunstrc.tmpl           # notificações (cores do DNA)
├── hud/shell.qml                # Omnitrix HUD (Quickshell)
├── hypr/
│   ├── azmuth.lua               # atalhos + autostart → require("azmuth")
│   ├── hyprlock.conf.tmpl       # tela de bloqueio (cores + wallpaper do DNA)
│   └── hypridle.conf            # bloqueio/tela por inatividade
├── rofi/                        # base.rasi + ajustes por DNA
├── src/
│   ├── core.py                  # orquestrador + CLI
│   └── context_engine.py        # daemon de contexto
├── tools/                       # gen_sounds.py, gen_wallpapers.py
└── waybar/                      # config.jsonc, base.css + ajustes por DNA
```

`azmuth install` cria os symlinks: `~/.local/bin/azmuth`,
`~/.config/waybar/config.jsonc`, `~/.config/hypr/azmuth.lua` e
`~/.config/hypr/hypridle.conf`. Estado em `~/.local/state/azmuth/state.json`.

---

## 9. Contrato de dados — o schema de DNA

Todo arquivo `dna/<nome>.yaml` segue o schema formal (documentado em
`docs/DNA_Schema_Spec.md`). Estrutura resumida:

```yaml
dna:
  id: string            # único, snake_case, igual ao nome do arquivo
  name: string
  core: arch | kali      # a qual Core pertence
  description: string

palette:                 # cores que alimentam Hyprland + waybar + rofi
  primary / secondary / background / foreground /
  border_active / border_inactive: "#hex"

hyprland:
  gaps_in / gaps_out / border_size / rounding: int
  animations_enabled: bool
  layout: dwindle | master

wallpaper: { path: string }     # relativo à raiz do projeto
waybar:    { style: string }    # caminho do CSS
rofi:      { theme: string }    # caminho do .rasi
sound:     { transform: string }# opcional — som de transição

apps:    { autostart: [string] }          # opcional
daemons: { enable: [string], disable: [string] }  # opcional
context_engine: { triggers: [...] }        # opcional
```

**Regras-chave:**
1. `dna.id` é a chave de busca — igual ao nome do arquivo.
2. `dna.core` só aceita `arch` ou `kali`; o mesmo alien nos dois Cores são dois
   arquivos separados.
3. Campos obrigatórios ausentes = erro de config → o `core.py` deve falhar alto,
   nunca assumir default silencioso.
4. `apps`/`daemons` vazios são válidos (o Neutral não força nada).
5. `context_engine.triggers` vazio é o padrão até o Context Engine existir.

---

## 10. Estado atual do código (ponto de retomada)

**Funcionando (2026-10-06):**

- ✅ `core.py` completo: valida o DNA inteiro antes de mexer em qualquer coisa e
  aplica Hyprland (gaps, borda em gradiente, sombra, rounding, layout,
  animações), wallpaper em todos os monitores, waybar, rofi, dunst, hyprlock,
  daemons (autocontidos por DNA), apps e som. Estado persistido; `restore` no
  boot e após `hyprctl reload`.
- ✅ DNAs: **Neutral** (azul Galvan B) e **Massa Cinzenta** (verde galvânico,
  gaps 2/4, layout master, abre VS Code + kitty no ws 1 e Obsidian no ws 2,
  sugerido quando um editor/IDE fica em foco).
- ✅ Master Control, Omnitrix HUD, Context Engine, Randomizer, rollback.
- ✅ Waybar Galvan: chip do DNA ativo (clique = HUD, direito = Randomizer,
  meio = Master Control; pulsa com Master Control ligado), taskbar, energia.
- ✅ Sons procedurais do relógio e wallpaper procedural do Massa Cinzenta.
- ✅ Qualidade de vida: **minimizar** (Super+N → `special:minimized`;
  Super+Shift+N ou clique na taskbar restaura), **Super+M bloqueia** (hyprlock
  temático do DNA) em vez de fazer logout, menu de energia (Super+Shift+Q),
  hypridle (bloqueia em 10 min, apaga a tela em 12), fontes maiores.

### Atalhos

| Atalho | Ação |
|---|---|
| Super + Space | Omnitrix HUD (←/→/scroll gira, Enter transforma, 0–9 pula, Esc sai) |
| Super + Numpad 1–0 / Super + Alt + 1–0 | Master Control: transforma direto |
| Super + Esc | Volta ao Neutral |
| Super + Shift + R | Randomizer |
| Super + Y | Aceita sugestão do Context Engine |
| Super + Shift + M | Liga/desliga Master Control (troca automática) |
| Super + D | Menu de apps (rofi) |
| Super + N / Super + Shift + N | Minimizar / restaurar |
| Super + M | Bloquear tela |
| Super + Shift + Q | Menu de energia |

### Uso pela linha de comando

```bash
azmuth apply massa_cinzenta   # ou: python src/core.py dna/massa_cinzenta.yaml
azmuth slot 1 | neutral | random | accept | master toggle | hud toggle
azmuth current | roster       # estado / catálogo
```

### Criar um novo DNA (receita)

1. Copiar `dna/massa_cinzenta.yaml` → `dna/<id>.yaml`, ajustar palette/hyprland/apps/triggers.
2. Criar `waybar/<id>.css` e `rofi/<id>.rasi` (podem ficar vazios — a paleta já tematiza).
3. `.venv/bin/python tools/gen_wallpapers.py dna/<id>.yaml` (ou pôr uma arte própria).
4. Pronto: o alien desbloqueia sozinho no HUD e no numpad.

## 11. Roadmap / próximos passos

**Imediato**
- [x] `neutral.png` validado ponta a ponta (é um WebP com extensão .png — o hyprpaper aceita).
- [x] `core.py` recarrega waybar, rofi, dunst e hyprlock na transição.
- [x] Tema rofi Galvan por paleta (menu, clipboard, energia e fallback do HUD).
- [ ] Alt-tab ainda é o hyprswitch (não tematizado pelo DNA).
- [ ] Tematizar a tela de login (SDDM) — precisa de sudo.

**Curto prazo**
- [x] Massa Cinzenta fechado como template (paleta, gaps, apps, gatilhos).
- [ ] Usar Neutral + Massa Cinzenta no dia a dia antes de criar mais DNAs ← **AGORA**.

**Médio prazo**
- [ ] Definir a função concreta de cada um dos 10 aliens (tabela da seção 4).
- [x] Master Control (Super + Numpad).
- [x] Quickshell/QML decidido; Omnitrix HUD implementado.
- [x] Context Engine (modo assistido + Master Control) e Randomizer.

**Longo prazo**
- [ ] Segundo Core (Kali) e as 10 reinterpretações de DNA.
- [ ] Nível "Ultimate" por DNA (inspirado no Omnify).
- [ ] Wallpaper animado (swww/mpvpaper) com a onda de energia na transição.
- [ ] Arte própria: símbolo do Omnitrix + logo do Arch no core + design dos
      aliens (a ser feito mais pra frente).

---

## 12. Glossário rápido

- **DNA** — um estado/perfil do sistema (visual + comportamento + daemons).
  Nome inspirado nas transformações do Omnitrix.
- **Core** — camada de infraestrutura (Arch = diário/dev; Kali = segurança).
  Um Core pode hospedar vários DNAs.
- **Neutral** — o DNA base do Arch Core, estado default de uso diário.
- **Master Control** — modo de troca instantânea de DNA, sem confirmação.
- **Context Engine** — daemon que sugere/aplica DNA conforme o contexto de uso.
- **Randomizer** — sorteia um DNA aleatório (homenagem à "falha" do relógio).
- **Omnitrix HUD** — o disco circular interativo de seleção de DNA.
- **Ultimate** — nível de intensidade extra de um DNA (inspirado no Omnify).
- **core.py** — o orquestrador em Python que lê um DNA e aplica no sistema.
