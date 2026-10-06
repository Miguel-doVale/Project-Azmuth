# DNA Schema Spec — Project Azmuth

Este documento define o contrato de dados que todo arquivo `dna/<nome>.yaml`
deve seguir. O orquestrador (`src/core.py`) lê esse contrato para aplicar
o estado no sistema. Nenhum DNA deve ter uma chave fora deste schema sem
que este documento seja atualizado primeiro.

## Estrutura completa

```yaml
dna:
  id: string          # obrigatório — identificador único, snake_case, bate com o nome do arquivo
  name: string         # obrigatório — nome de exibição
  core: arch | kali     # obrigatório — a qual Core este DNA pertence
  description: string   # obrigatório — uma frase descrevendo o propósito

palette:
  primary: "#hex"        # obrigatório
  secondary: "#hex"       # obrigatório
  background: "#hex"      # obrigatório
  foreground: "#hex"      # obrigatório
  border_active: "#hex"   # obrigatório
  border_inactive: "#hex" # obrigatório

hyprland:
  gaps_in: int            # obrigatório
  gaps_out: int           # obrigatório
  border_size: int        # obrigatório
  rounding: int           # obrigatório
  animations_enabled: bool # obrigatório
  layout: dwindle | master # obrigatório

wallpaper:
  path: string            # obrigatório — relativo à raiz do projeto

bar:
  visible: bool            # opcional (padrão true) — false esconde a barra (DNA de foco total)

hud:
  art: string              # opcional — SVG/PNG do alien (relativo à raiz), exibido no centro
                           #   do Omnitrix HUD e no card do DNA. Composição circular.

rofi:
  theme: string            # obrigatório — caminho do .rasi relativo à raiz

sound:
  transform: string        # opcional — som tocado na transformação de entrada

apps:
  autostart:               # opcional — apps abertos ao entrar no DNA (só se ainda não estiverem abertos)
    - string                 # forma curta: comando; "aberto" = processo com esse nome existe
    - cmd: string            # forma completa: comando
      class: regex           #   opcional — "aberto" = existe janela com essa classe
      workspace: int         #   opcional — workspace onde a janela nasce

daemons:
  enable: [string]         # opcional — unidade systemd --user, ou comando (fallback)
  disable: [string]        # opcional — idem

context_engine:
  triggers:                # opcional — lista de gatilhos do Context Engine
    - match: string          # "class:<regex>" ou "title:<regex>" da janela em foco
      suggest: bool           # true = sugere no modo assistido; false = só age sob Master Control
      message: string         # opcional — título da notificação de sugestão
```

### Semântica de `daemons`

Cada item é procurado primeiro como unidade `systemctl --user`; se não existir,
é tratado como comando (ligar = executar se `pgrep -x` não achar; desligar =
`pkill -x`). **DNAs são autocontidos:** ao sair de um DNA, o que ele ligou é
desligado e o que ele desligou é religado — a não ser que o novo DNA reafirme
a mesma coisa.

### Arquivos derivados da `palette`

A palette é a fonte única de cor. O `core.py` gera a partir dela, a cada troca:
`~/.local/state/azmuth/theme.json` (lido pela barra/HUD/widgets em Quickshell),
`~/.config/rofi/azmuth.rasi` (variáveis + `rofi/base.rasi` + `rofi.theme`),
`~/.config/dunst/dunstrc` e `~/.config/hypr/hyprlock.conf`. Por isso
`rofi.theme` contém **só os ajustes específicos do DNA**.

> Histórico: até 2026-10-06 existia o campo obrigatório `waybar.style`; a waybar
> foi substituída pela barra em Quickshell e o campo virou `bar` (opcional).

## Regras

1. **`dna.id` é a chave de busca.** O `core.py` localiza o arquivo por
   `dna/<id>.yaml` — o `id` interno e o nome do arquivo devem ser idênticos.
2. **`dna.core` só aceita `arch` ou `kali`.** Um DNA nunca pertence aos dois
   ao mesmo tempo — se o mesmo alien existir nos dois Cores (ex: Diamante
   em Arch vs Diamante em Kali), são dois arquivos separados
   (`diamante.yaml` e `diamante_kali.yaml`, ou pasta separada por core —
   isso ainda será decidido quando chegarmos no segundo Core).
3. **Todo campo marcado obrigatório deve existir**, mesmo que com valor
   mínimo — o `core.py` não deve assumir default silencioso para esses
   campos; a ausência de um obrigatório é erro de configuração e deve
   falhar alto (ver seção "Validação" abaixo, a implementar).
4. **`apps.autostart` e `daemons` vazios são válidos** — significa que o
   DNA não força nada além do que já está rodando (caso do Neutral).
5. **`context_engine.triggers` vazio é o padrão** até o Context Engine
   ser implementado — nenhum DNA deve depender dele para funcionar sozinho.

## Validação (implementada)

O `core.py` valida o DNA inteiro **antes** de tocar no sistema — um DNA
inválido nunca deixa uma transformação pela metade. Além dos obrigatórios,
verifica: `dna.id` igual ao nome do arquivo; cores no formato `#rrggbb`;
inteiros e booleanos do bloco `hyprland`; `layout` em `dwindle|master`;
existência do arquivo de `rofi.theme`; `bar.visible` booleano; forma dos itens de
`apps.autostart`; `match` em todo trigger. (O wallpaper ausente só gera aviso.)

## Roster do Omnitrix (`dna/omnitrix.yaml`)

Não é um DNA: é o catálogo que liga cada alien a um slot do numpad (Master
Control) e ao disco do HUD. Um alien só é desbloqueado quando existe
`dna/<id>.yaml`; antes disso aparece como "DNA bloqueado".

## Histórico

- v0.1 — schema inicial, definido junto com `dna/neutral.yaml`.
