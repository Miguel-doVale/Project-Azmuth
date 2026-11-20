# Cérebro — a memória do Azmuth

O cérebro é um **vault de notas Markdown** (abre no Obsidian) que o Azmuth (`Super + A`) e o
Claude do terminal leem. Fica **só neste PC**, em `~/Cérebro` (configurável com
`azmuth set brain.path "<pasta>"`), nunca no repositório nem em nuvem.
Spec: `docs/superpowers/specs/2026-11-19-cerebro-obsidian-design.md`.

## Estrutura

```
Cérebro/
  00-Mapa.md          índice gerado (não editar): o Azmuth recebe ele a cada mensagem
  Rice-Azmuth/        o projeto, comandos, decisões, armadilhas
  Estudos/            Faculdade/ (Ligas: LADG, LARP, LASETE · Software-House: SEMISPE) · Cursos/
  Carreira/           Portfólio/ · Currículo/ · Histórico/ (DMG)
  Pessoas/            Amigos/ · Família/ · Relacionamentos/
  Vida/               rotina, planos, saúde · Identidade/ (restrita)
  Finanças/           (restrita)
  Projetos/
  Azmuth/Aprendizados.md   correções e preferências ("não faz X", "prefiro Y")
```
As pastas são livres para reorganizar, **menos** `Finanças/` e `Vida/Identidade/`, onde moram as
notas restritas.

## Toda nota começa assim

```
---
resumo: uma linha: do que se trata e quando ler
acesso: aberto | financas | identidade
---
```
- Sem cabeçalho, ou com `acesso` desconhecido, a nota conta como **restrita** (`identidade`).
- Tudo dentro de `Finanças/` e `Vida/Identidade/` é restrito, mesmo que o cabeçalho diga `aberto`.
- Nunca entram no cérebro: número de conta, número de cartão, senhas.

## Quem lê o quê

| | Notas abertas | Finanças / Identidade |
|---|---|---|
| Azmuth normal (`Super + A`, `azmuth ask`) | lê e escreve | não |
| Modo finanças (`azmuth ask --restricted "…"`) | não | só lê + relatórios |
| Ollama | não | não |
| Claude do terminal | lê | **hoje ainda consegue**: a regra de pasta no Claude Code só entra quando o Miguel autorizar |

As duas sessões do Azmuth rodam isoladas das configurações do Claude Code do Miguel
(`--setting-sources project --permission-mode dontAsk`): qualquer comando fora da lista é negado,
inclusive colado atrás de um permitido (testado ao vivo). `Azmuth/Aprendizados.md` só o Miguel edita;
quando o Azmuth reescreve uma nota, a versão anterior vai para `.historico/` (oculta, fora do mapa).

O modo finanças é **outra sessão do Claude**: as únicas ferramentas dela são ler nota restrita e
gerar relatório. Não existe envio de mensagem, ação no PC nem internet nela. Texto de nota é sempre
tratado como dado, nunca como ordem.

## Extratos (finanças)

1. Exporte o extrato do app do banco em CSV.
2. Salve em `~/.local/share/azmuth/extratos/<Banco>/` (ex.: `…/extratos/Nubank/nov.csv`). Essa pasta
   fica **fora** do vault: o CSV cru tem nomes de pessoas e lojas.
3. Ao abrir o modo finanças (ou com `azmuth cerebro ingest`), um script **sem IA** lê o CSV, tira as
   descrições, categoriza por regras e grava só `data | valor | categoria | banco` em
   `Finanças/lancamentos-AAAA-MM.md`. O CSV vai para `<Banco>/processados/`.
4. Formato de cada banco (só nomes de colunas): `data/bank_formats.json` no projeto (Mercado Pago e
   Nubank e PicPay já cadastrados; `Finanças/bancos.json` sobrescreve). Regras de categoria genéricas em
   `data/categories_default.json`; as pessoais (ex.: o próprio nome para "Entre contas") em
   `Finanças/categorias.json`, que vêm primeiro e ganham. "Entre contas" e "Pagamento de fatura" ficam fora
   das somas de entradas e saídas. Regras novas: `azmuth cerebro ingest --refazer` recategoriza tudo.
   Banco sem formato cadastrado fica parado e o Azmuth avisa.

Relatórios: peça ao Azmuth no modo finanças ("como foi novembro?") ou `azmuth cerebro report 2026-11`.

## Comandos

| Comando | O que faz |
|---|---|
| `azmuth cerebro init` | Cria a estrutura (não sobrescreve nada) |
| `azmuth cerebro map` | Mostra o mapa (só notas abertas) |
| `azmuth cerebro check` | Acusa nota restrita fora de `Finanças/` e `Vida/Identidade/` |
| `azmuth cerebro read <nota>` · `write <nota> <conteúdo>` | Leitura/escrita do modo normal |
| `azmuth cerebro ingest` · `report <AAAA-MM\|AAAA>` | Extratos · relatório |
| `azmuth cerebro sem-categoria [--ano AAAA]` | O que caiu em "Outros", por pessoa/loja (mostra nomes: rode no seu terminal) |
| `azmuth cerebro regra "<termo>" <Categoria>` | Ensina uma regra pessoal; depois `ingest --refazer` |
| `azmuth ask --restricted "…"` | Conversa no modo finanças |

## Nascimento (ordem combinada)

1. `azmuth cerebro init` — estrutura vazia.
2. Semente: o Claude destila o projeto, as conversas e as skills em notas.
3. Importar o que o Claude Desktop e o Gemini sabem (exportação feita pelo Miguel, revisada antes).
4. Primeira conversa: o Azmuth se apresenta e entrevista o Miguel (amigos, família, rotina, planos).
5. Crescimento: correções vão para `Azmuth/Aprendizados.md`.
