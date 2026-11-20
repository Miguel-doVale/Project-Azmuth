# Galeria de fundos ASCII vivo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Levar a galeria de cenas ASCII vivo aprovada na prévia para o fundo de verdade da área de trabalho (LiveDesktop), com seletor na Central, efeitos por cena e o quadrinho como transformação.

**Architecture:** Um conversor em Python (`tools/ascii_scene.py`, porte do rascunho aprovado) gera `scene.json` + `preview.png` por cena em `~/.local/share/azmuth/scenes/<id>/` (fora do git). O core expõe a lista de cenas e guarda a escolha em `settings.json → desktop`. Na shell, `AsciiScene.qml` desenha a grade uma vez num Canvas base e redesenha só os efeitos (~10 quadros/s) num Canvas por cima; os brilhos (pulso/aura) são Canvas estáticos com MultiEffect e opacidade animada.

**Tech Stack:** Python 3 + Pillow (`.venv`), unittest; Quickshell 0.3.2 / Qt 6.12 (QML Canvas Context2D, MultiEffect, FileView, Process).

**Spec:** `docs/superpowers/specs/2026-11-14-galeria-ascii-design.md` (aprovado em 2026-11-15).
**Prévia aprovada (referência viva, fora do repo):** `~/.local/share/azmuth/scenes/galeria.html`; config de produção em `~/.local/share/azmuth/scenes/_build/scenes.json`; código da prévia em `~/.local/share/azmuth/scenes/_build/{prod.py,galeria.tpl.html}`. Os números, cores, caixas e contornos de cada cena já estão nessa config: o plano não os repete.

## Global Constraints

- Grade: **100 linhas × 307 colunas** (célula 0.58 de largura/altura), brilho em base36 (`0..z` = 0..1), cor `rrggbb` por célula — exatamente o formato de `_build/prod.py`.
- Rampa: `" .'`^,:;Il!i><~+_-?][}{1)(|tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"`. Cor da foto na tela: `k = max(1.15, 110 / max(r,g,b,1))`, cada canal `min(255, c*k)`. Modo branco: `rgba(230,236,245, .25 + l*.75)`.
- Efeitos a **~10–11 quadros/s** (intervalo 90 ms); camada base desenhada uma vez por cena/tamanho/modo de cor.
- Omnitrix central intocado: raio = 27% da altura, desenhado por cima da cena (é o do LiveDesktop).
- Imagens de terceiros e cenas **só** em `~/.local/share/azmuth/scenes/` — nunca no repositório. No repo: conversor, template da prévia, renderizador, testes.
- Cor `"dna"`/`"foto"` de um efeito e modo branco usam `theme.primary` (cor do DNA ativo).
- "Área de trabalho viva" desligada → cena parada (base sem efeitos).
- Escala da shell: usar o tamanho real da janela; nunca `screen.devicePixelRatio`.
- QML: nomes de propriedade começam em minúscula. Depois de mudar IPC, reiniciar a shell inteira.
- Prints só no workspace 9 vazio, conferido logo antes de cada `grim`. Não commitar: o Miguel faz os commits (os passos "Commit" abaixo viram "parar e avisar o que mudou").
- Testes: `.venv/bin/python -m unittest discover -s tests -q`.

## Review Focus

1. **Cena apagada ou corrompida** (pasta removida, `scene.json` inválido, id salvo que não existe mais): o fundo cai nos circuitos, sem tela preta e sem erro em loop no log.
2. **Troca rápida de cena/DNA/tamanho de tela** (HDMI liga/desliga, escala muda): sem vazar Canvas antigos, sem base desenhada no tamanho errado.
3. **CPU em repouso** com a cena mais pesada (portal: 2 redemoinhos + flutuar; galáxia: redemoinho + 3 planetas): a shell não pode subir mais que alguns % — os efeitos param quando a área de trabalho está coberta por janela maximizada/tela cheia.
4. **Lista de efeitos salva com tamanho diferente** da lista da cena (cena reconvertida com efeito novo): usa o padrão da cena para os índices que faltam.
5. **Carrossel** com uma das cenas faltando: pula a que falta; com zero cenas válidas, cai nos circuitos.

---

### Task 1: Conversor `tools/ascii_scene.py`

**Files:**
- Create: `tools/ascii_scene.py` (porte de `_build/prod.py` + `_build/sheet.py`)
- Create: `tools/ascii_gallery.html` (cópia de `_build/galeria.tpl.html`; continua sendo a prévia de curadoria)
- Test: `tests/test_ascii_scene.py`

**Interfaces:**
- Produces:
  - `convert(cfg: dict, src_dir: Path) -> dict` → `{"cols":307,"rows":100,"box":[x,y,w,h],"lum":[str*100],"col":[str*100]}`
  - `build(sid: str, cfg: dict, scenes_dir: Path) -> Path` grava `<scenes_dir>/<sid>/scene.json` (`id,title,source,effects,mono` + grade) e `preview.png` (640×360). Não grava `scene.js`.
  - `build_carousel(sid: str, title: str, ids: list[str], every: int, scenes_dir: Path) -> Path` grava `scene.json` = `{"id","title","carousel": ids, "every": every, "effects": []}` e copia o `preview.png` da primeira.
  - `gallery(cfg_path: Path, scenes_dir: Path) -> Path` gera `galeria.html` (prévia com `scene.js` gerados só para ela).
  - CLI: `ascii_scene.py build <config.json> [ids…]`, `ascii_scene.py gallery <config.json>`; config padrão `~/.local/share/azmuth/scenes/_build/scenes.json`; fontes em `<scenes_dir>/_src/`. Uma entrada da config com `"carousel": [...]` vira `build_carousel`.

- [ ] **Step 1: Write the failing tests** (imagens sintéticas geradas no teste com Pillow em `tempfile`):
  - `test_grid_dimensions`: `len(lum)==100`, cada linha 307 chars, cada linha de `col` 307×6 chars.
  - `test_box_inside_screen`: imagem 100×200 com `place=(1,.5), focus=(1,.5)` → `box[0]+box[2] == 307`, `box[1] == 0`.
  - `test_tile_mirror_fills_screen`: com `tile=True`, nenhuma célula fora da imagem fica com brilho `0` quando a imagem é toda clara.
  - `test_tilefix_red_becomes_white`: imagem vermelha pura, `tile=True, tilefix="red"` → células fora da caixa têm cor `ecf0f6`, dentro continuam vermelhas.
  - `test_layers_two_images`: duas camadas (`crop` esquerda/direita) → a caixa retornada é a da primeira camada.
  - `test_build_writes_scene_and_preview`: `scene.json` válido com `mono` e `effects` repassados; `preview.png` 640×360.
  - `test_carousel_scene`: `scene.json` com `carousel`, sem `lum`.
- [ ] **Step 2: Run** `.venv/bin/python -m unittest tests.test_ascii_scene -q` — Expected: FAIL (`ModuleNotFoundError: ascii_scene`).
- [ ] **Step 3: Implement** — porte fiel de `_build/prod.py` (`load`, `value`, `cover`, `place_layer`, `mirror`, `convert`, `render`), com `SCENES`/`src_dir` como parâmetro; `render` só para `preview.png` (Omnitrix desenhado na prévia, como hoje). Fonte da prévia: JetBrainsMono Nerd Font Mono Bold, com fallback para `ImageFont.load_default()` se não existir.
- [ ] **Step 4: Run** os testes — Expected: PASS; suíte inteira verde.
- [ ] **Step 5:** Avisar o Miguel do que mudou (ele commita).

### Task 2: Core — lista de cenas e preferência `desktop`

**Files:**
- Modify: `src/core.py` (DEFAULT_SETTINGS, `validate_setting`, `write_theme`, COMMANDS)
- Test: `tests/test_ui_settings.py`, `tests/test_scenes.py`

**Interfaces:**
- Produces:
  - `DEFAULT_SETTINGS["desktop"] = {"scene": "circuitos", "effects": {}, "color": {}, "every": {}, "comic": True}`
  - `SCENES_DIR = Path(os.environ.get("XDG_DATA_HOME", HOME/".local/share")) / "azmuth/scenes"`
  - `list_scenes(scenes_dir=SCENES_DIR) -> list[dict]` → `[{"id","title","effects":[{"type","nome","on"}],"mono":bool,"carousel":[...]|None,"every":int|None,"preview":"<abs path>"}]`, ordenado pela ordem da `_build/scenes.json` quando existir (senão por título); pula pastas sem `scene.json` válido e as que começam com `_`. Sempre inclui primeiro `{"id":"circuitos","title":"Circuitos (atual)"}`.
  - `validate_setting`: `desktop.scene` (texto não vazio), `desktop.comic` (bool), `desktop.effects.<id>` (lista de bool, máx. 16), `desktop.color.<id>` (`"foto"` ou `"dna"`), `desktop.every.<id>` (int em `{4,6,9,15,30,60}`).
  - `write_theme` exporta `"desktop": settings["desktop"]` e `"scenes_dir": str(SCENES_DIR)`.
  - Comando `azmuth fundo [--json]` (lista) e `azmuth fundo <id>` (= `set desktop.scene`; id desconhecido → `[ERRO]`).

- [ ] **Step 1: Write the failing tests:** default presente; cada validação aceita/recusa (ex.: `desktop.every.posteres = 7` → ValueError; `desktop.color.x = "azul"` → ValueError); `list_scenes` com pasta temporária contendo uma cena válida, uma com JSON quebrado e `_src` → retorna `circuitos` + a válida; `write_theme` contém `desktop`.
- [ ] **Step 2: Run** — Expected: FAIL (`KeyError: 'desktop'`).
- [ ] **Step 3: Implement** as assinaturas acima. `cmd_set` já chama `write_theme` (a shell recebe a mudança pelo `theme.json`).
- [ ] **Step 4: Run** suíte — Expected: PASS.
- [ ] **Step 5:** Avisar o que mudou.

### Task 3: Renderizador `AsciiScene.qml` + biblioteca de efeitos

**Files:**
- Create: `shell/AsciiScene.qml` (Item: carrega cena, Canvas base, Canvas de efeitos, camadas de brilho, carrossel)
- Create: `shell/AsciiFx.js` (`.pragma library`; porte dos efeitos de `_build/galeria.tpl.html`)

**Interfaces:**
- Consumes: `theme.desktop`, `theme.scenes_dir`, `theme.primary` (Task 2).
- Produces: `AsciiScene { sceneId: string; scenesDir: string; dna: color; animate: bool; effectsOn: var (lista de bool ou null); mono: var (bool ou null); every: int; readonly property bool ready; signal failed() }`.
- `AsciiFx.js`: `decode(scene) -> {L: Float32Array, C: Uint8Array}`; `draw(type, ctx, st, e, k, t)` para os tipos `vento, matrix, redemoinho, flutuar, girar, scan, estrelas, cometas, planeta, orbita, bolhas, faiscas, chuva, neve, raios, rastro, glitch, letreiro, vulto`; `glowCells(st, e) -> [[x,y,l,rgb]]` para `pulso` e `aura`; `maskOf(st, e)` (poly/flood).

Decisões (rulings da tradução Canvas web → QML Context2D):
- **Sem `drawImage` de um Canvas para outro** (não é confiável no QML): efeitos que deslocam a base (`vento`, `glitch`, `scan`, `vulto`, `redemoinho`, `flutuar`, `girar`) **redesenham as células** a partir de `L/C` com `drawCell` (fundo `#050607` + caractere), no Canvas de efeitos.
- **Sem `ctx.filter`:** pulso/aura viram um Canvas próprio por efeito (desenhado uma vez com `glowCells`), envolto em `MultiEffect { blurEnabled; blur: 0.6; blurMax: 32 }`, com `opacity` animada por `SequentialAnimation` (aura 1.4 rad/s, pulso 2.2 rad/s, faixa .2–1).
- Canvas: `renderStrategy: Canvas.Threaded`, `renderTarget: Canvas.FramebufferObject`; base repinta só em `onWidthChanged/onHeightChanged`, troca de cena ou de modo de cor.
- Ordem de desenho = `order` da prévia; a metade da frente de `orbita` é desenhada num terceiro Canvas **acima do Omnitrix** (exposto como `frontLayer`, que o LiveDesktop coloca por cima do símbolo).
- Fonte: `"JetBrainsMono Nerd Font Mono"` bold, `pixelSize = ch*0.95`.
- Carrossel: troca a cada `every` s com o "burst" de glitch (5 quadros); ids faltando são pulados; nenhum válido → `failed()`.
- Erro ao ler/parsear a cena → `failed()` uma vez (sem tentar de novo até `sceneId` mudar).

- [ ] **Step 1:** Página de teste do porte: rodar `AsciiFx.js` no Node contra `portal-verde/scene.json` e `alienx-galaxia/scene.json` com um `ctx` falso que conta chamadas — `node tools/fx_smoke.js` (criar) — Expected: cada tipo de efeito das duas cenas desenha > 0 células em 3 quadros, sem exceção.
- [ ] **Step 2:** Implementar `AsciiFx.js` até o smoke passar.
- [ ] **Step 3:** Implementar `AsciiScene.qml`. Verificação: `qs -p shell` com uma janela de teste temporária não é necessária — o teste real é na Task 4.
- [ ] **Step 4:** Avisar o que mudou.

### Task 4: LiveDesktop mostra a cena

**Files:**
- Modify: `shell/LiveDesktop.qml` (fundo: cena no lugar dos circuitos; `frontLayer` acima do símbolo)

**Interfaces:**
- Consumes: `AsciiScene` (Task 3), `theme.desktop` (Task 2).

- Regras: `desktop.scene == "circuitos"` ou `failed()` → circuitos atuais (inalterados). Senão `AsciiScene` cobre a janela; o brilho radial e o Omnitrix continuam por cima. `animate = theme.live !== false && !coberto`, onde `coberto` = há janela em tela cheia ou maximizada no workspace ativo desse monitor (via `Hyprland.toplevels`/`activeWorkspace`). `effectsOn`/`mono`/`every` vêm de `theme.desktop.effects[id]`, `.color[id] === "dna"`, `.every[id]`.
- [ ] **Step 1:** Implementar; `azmuth fundo portal-verde`.
- [ ] **Step 2: Verificar** — log da shell sem `Failed|caused by|ReferenceError`; print no workspace 9 vazio de: `portal-verde`, `alienx-galaxia`, `be-invincible`, `posteres`, `circuitos`; nas cores Neutral e Massa Cinzenta (`azmuth apply` ida e volta). Expected: igual à prévia; Omnitrix por cima; órbita do Alien X passa na frente do símbolo.
- [ ] **Step 3: CPU** — `pidstat -p $(pgrep -x qs) 5 6` com a cena do portal, área de trabalho visível; depois com uma janela maximizada. Expected: com janela cobrindo, igual ao baseline dos circuitos (±1%); visível, poucos % (anotar os números para o Miguel).
- [ ] **Step 4:** `azmuth fundo cena-que-nao-existe` recusado; apagar temporariamente uma pasta de cena ativa (renomear e voltar) → circuitos, sem loop no log.
- [ ] **Step 5:** Avisar o que mudou.

### Task 5: Galeria na Central (seção FUNDO)

**Files:**
- Modify: `shell/DesktopPanel.qml` (seção `FUNDO` acima de "DESKTOP CANVAS")

- Dados: `Process` com `azmuth fundo --json` ao abrir a aba.
- Grade de miniaturas (`preview.png`, 3 por linha, borda na cor do DNA na ativa); clicar → `dp.setPref("desktop.scene", id)`.
- Abaixo da grade, para a cena ativa: um `UiToggle` por efeito (`nome`), gravando a lista inteira em `desktop.effects.<id>`; botão "Cores da foto / Branco + cor do DNA" (`desktop.color.<id>`); se carrossel, seletor de tempo 4/6/9/15/30/60 s (`desktop.every.<id>`); `UiToggle` "Transformação em quadrinho" (`desktop.comic`).
- [ ] **Step 1:** Implementar.
- [ ] **Step 2: Verificar** — abrir a Central → Área de trabalho; trocar cena, desligar um efeito, trocar cor e tempo do carrossel; `cat ~/.local/state/azmuth/settings.json` mostra os valores; o fundo muda na hora; print no workspace 9.
- [ ] **Step 3:** Avisar o que mudou.

### Task 6: Quadrinho como transformação

**Files:**
- Modify: `shell/shell.qml` (janela `flashWin`)
- Create: `shell/ComicFlash.qml`

- Com `theme.desktop.comic` ligado, `flash(color)` mostra `ComicFlash` por ~1 s em vez da onda: linhas de ação saindo do centro (Omnitrix), retícula (pontos), moldura de nanquim e onomatopeia sorteada de `["FLASH!", "VWOOM!", "KRAK!", "ZZZAP!"]` em Orbitron Black, tudo na cor do novo DNA (mesmo visual do quadrinho de `docs/design/prototipo-wallpaper.html`). Desligado → onda atual, intacta.
- [ ] **Step 1:** Implementar.
- [ ] **Step 2: Verificar** — `qs ipc call … flash "#4ade80"` (ou `azmuth apply <dna>`) com o toggle ligado e desligado; capturar um quadro no workspace 9; log limpo.
- [ ] **Step 3:** Avisar o que mudou.

### Task 7: Produção da leva aprovada + documentação

**Files:**
- Modify (local, fora do repo): `~/.local/share/azmuth/scenes/_build/scenes.json` — entra a entrada `posteres` com `"carousel"` e `"every": 6`.
- Modify: `docs/MANUAL.md`, `docs/manual.html`, `README.md`, MASTER roadmap; `.gitignore` não precisa (as cenas estão fora do repo).

- Leva aprovada pelo Miguel (2026-11-15): invencivel-multidao, ben-rv, mark-costas, portal-verde, him, pixel-espaco, be-invincible, flash-zoom, lanterna-martelo, lanterna-planeta, alien-cromado (em dúvida, entra), cristal-espada, alienx-luz, alienx-faces, maos-wireframe, skull-colosso, ben-mascaras (em revisão), bigchill-sombra, upgrade, heatblast-chuva, gargula-chuva, xlr8-tanque, ghostfreak (título "Ultra-T"), alienx-anel, alienx-explosao, alienx-galaxia, bigchill-neve, posteres (carrossel dos pôsteres I–X). Fora: mark-cidade, lanterna-nebulosa, heatblast-gwen, xlr8-azul.
- [ ] **Step 1:** `.venv/bin/python tools/ascii_scene.py build` (config padrão) e `… gallery`. Expected: 27 cenas + carrossel + 10 pôsteres; `azmuth fundo --json` lista todas.
- [ ] **Step 2:** Manual: seção "Fundo da área de trabalho" (galeria na Central, `azmuth fundo`, como o Claude produz novas cenas com `tools/ascii_scene.py`, onde ficam os arquivos).
- [ ] **Step 3:** Suíte verde; avisar o que mudou.

---

## Self-review

- Spec 2.1 (formato) → T1; 2.2 (onde ficam) → T1/T7; 2.3 (produção) → T1/T7; 2.4 + 2.4.1 (efeitos, composição, carrossel, modo de cor) → T1/T3/T5; 2.5 (galeria na Central) → T5; 2.6 (renderização, viva desligada = parada) → T3/T4; 2.7 (quadrinho) → T6; 5 (testes, CPU, prints) → T1/T2/T4.
- Nomes consistentes: `desktop.scene/effects/color/every/comic`, `list_scenes`, `AsciiScene`, `AsciiFx.draw`.
- Fora deste plano (spec, "fora do escopo"): fundo-história do Ben; máscaras girando de verdade na 19.
