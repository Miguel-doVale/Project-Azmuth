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

waybar:
  style: string            # obrigatório — caminho do CSS relativo à raiz

rofi:
  theme: string            # obrigatório — caminho do .rasi relativo à raiz

sound:
  transform: string        # opcional — som tocado na transformação de entrada

apps:
  autostart: [string]      # opcional — comandos a executar ao entrar no DNA

daemons:
  enable: [string]         # opcional — nomes de serviço systemd a ligar
  disable: [string]        # opcional — nomes de serviço systemd a desligar

context_engine:
  triggers:                # opcional — lista de gatilhos automáticos
    - match: string          # ex: app em foco, ou evento de hardware
      suggest: bool           # true = pergunta antes (modo assistido)
```

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

## Validação (a implementar)

O `core.py` deve validar um DNA contra este schema antes de aplicá-lo,
rejeitando arquivos com campos obrigatórios ausentes ou tipos errados,
em vez de falhar silenciosamente no meio da transformação.

## Histórico

- v0.1 — schema inicial, definido junto com `dna/neutral.yaml`.
