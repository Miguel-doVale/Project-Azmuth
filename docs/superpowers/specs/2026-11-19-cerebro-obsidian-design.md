# Cérebro (segundo cérebro em Markdown) — design

Status: rascunho para aprovação do Miguel (2026-11-19). Parte 1 de 4 do projeto "Azmuth agente" (ver Escopo).

## 1. Intenção

Miguel quer que o Azmuth (Super+A) deixe de ser só uma conversa e vire um agente que organiza a vida dele: conhece a rice, a agenda, as pessoas, os estudos e as finanças, manda mensagem por ele, avisa sem ser chamado e, no futuro, liga. Hoje o Azmuth só recebe DNA, energia, eventos e janelas, e a conversa zera após 30 min. Ele não lembra de nada nem lê documentos pessoais (`src/azmuth_ai.py`, `docs/MANUAL.md`).

Esta parte entrega a **memória durável**: um cofre de notas Markdown ligadas por `[[links]]`, aberto no Obsidian, que o Claude Code deste terminal **e** o Azmuth leem (e escrevem). Notas curtas com cabeçalho de uma linha deixam o leitor abrir só o necessário, o que também economiza token.

Por que agora: o contexto da rice vive hoje em conversas longas e na memória do Claude; precisa estar num lugar que Miguel controla, possa editar e que ambos os leitores compartilhem.

## 2. Escopo do projeto maior (para ordenar)

1. **Cérebro** (este documento).
2. Ferramentas: agenda, WhatsApp, ERP, organizar arquivos (cada uma com nível de permissão).
3. Iniciativa: o Azmuth manda mensagem sem ser chamado (serviço em segundo plano + ilha).
   Canal no celular (pedido do Miguel, 2026-11-20): conversar com o Azmuth por um **bot do Telegram** (API oficial,
   grátis, conta separada; só responde ao usuário do Miguel). Modo finanças pelo celular: sim (decisão do Miguel,
   2026-11-20), com camada extra: comando explícito, código TOTP de 6 dígitos para abrir, sessão que expira em
   poucos minutos, só leitura/relatórios, respostas com valores que se apagam. Aviso aceito: bot do Telegram não
   tem criptografia de ponta a ponta (os servidores do Telegram veem o que aparecer no chat). Envio para
   amigos pelo WhatsApp é outra coisa: ação com confirmação (API não oficial arrisca banir o número dele).
4. Voz e ligação.
Ordem fixada pelo Miguel: 1 → 2 → 3 → 4. Esta spec cobre só a parte 1 mais os ganchos de segurança que as outras vão usar.

## 3. Metas, não-metas, anti-metas

Metas
- Vault com estrutura acordada, notas semeadas com o que o projeto e a conversa já sabem.
- Azmuth lê o vault: índice (`00-Mapa.md`) no contexto, abre notas sob demanda.
- Claude Code (esta sessão) lê o mesmo vault.
- Regra de acesso **por nota**, aplicada em código.
- "Modo finanças" isolado; fechamento mensal/anual a partir de valores já higienizados.
- Nada do vault entra no repositório nem em nuvem.

Não-metas (nesta parte)
- Enviar WhatsApp, ligar, mexer em arquivos, ERP: partes 2–4.
- Leitura automática de extrato (subprojeto próprio; ver 7).
- Entrevista completa de amigos/família: etapa de preenchimento, não código.

Anti-metas (falha mesmo funcionando)
- Qualquer dado do vault ir parar no GitHub ou em sincronização de nuvem.
- Dado de `acesso: financas` ou `identidade` alcançar uma sessão que tenha ferramenta de envio.
- Qualquer modelo que não seja o Claude ler o vault (nada de Ollama; decisão firme do Miguel).

## 4. Estrutura (decidida pelo Miguel)

```
Cérebro/
  00-Mapa.md
  Rice-Azmuth/
  Estudos/      Faculdade/ (Ligas: LADG, LARP, LASETE; Software-House: SEMISPE)  Cursos/
  Carreira/     Portfólio/  Currículo/  Histórico/ (DMG)
  Pessoas/      Amigos/  Família/  Relacionamentos/
  Vida/         Identidade/  rotina, planos, saúde
  Finanças/
  Projetos/
```
As ligas e a Software House ficam dentro de Faculdade (decisão dele). DMG vai em `Carreira/Histórico/` como história (encerrada). Pastas são livres para o Miguel reorganizar: a proteção não depende delas.

## 5. Regra de acesso por nota

Toda nota começa com front matter:

```
---
resumo: <uma linha: do que se trata e quando ler>
acesso: aberto | financas | identidade
---
```
- `aberto`: lido em qualquer sessão.
- `financas`, `identidade`: só em sessão de modo restrito (6.2). Valores desconhecidos ou ausentes contam como o mais restritivo (`identidade`).
- Decisão minha: CPF fica em nota de `identidade`, fora das notas de finanças (Miguel aprovou a separação). Nome dos bancos, valores, categorias e chaves Pix (telefone, e-mail, CPF identificados só por tipo, o valor vem da nota de identidade) entram em `financas`. **Nunca** entram: número de conta, número de cartão, senhas (proibido pelo Miguel).

## 6. Como o Azmuth lê

6.1 Modo normal: contexto recebe `00-Mapa.md` (gerado: pasta, título, `resumo`, de notas abertas) e uma ferramenta `ler_nota(caminho)` que só abre notas `aberto` dentro do vault (sem `..`, sem links simbólicos para fora).

6.2 Modo finanças/identidade: sessão separada, escolhida pelo Miguel. Tem só ferramentas de leitura/cálculo sobre notas `financas` (e `identidade` quando pedido). Sem WhatsApp, ligação, web ou notas de Pessoas. Aplicado em código: uma sessão que abriu nota restrita fica "contaminada" e as ferramentas de envio (partes 2–4) ficam indisponíveis até ela terminar.

6.3 Escrita: o Azmuth pode propor nota nova ou edição; grava em `aberto` direto, e em restrito só no modo restrito. (Detalhe de confirmação: ver questões em aberto.)

6.4 Só o Claude. O caminho do Ollama (`assistant.provider`) não lê o vault.

## 7. Finanças (V1)

- Bancos: PicPay (crédito), Mercado Pago (geral), Nubank (academia), Inter (último caso), Itaú (último último caso). Uma nota por banco com a função e as chaves Pix por tipo.
- Entrada V1: **pasta vigiada**. Miguel exporta o extrato e salva numa pasta local; um script Python comum, **sem IA**, tira nomes e descrições, categoriza por regras e grava só data, valor, categoria, banco. O Claude vê apenas o resultado.
- Relatórios mensal e anual por categoria e banco, a partir dos valores gravados.
- Subprojeto posterior: automatizar a entrada. 1ª opção Open Finance via MeuPluggy (cobertura de Nubank, Inter, Itaú, Mercado Pago e PicPay em pessoa física aparece na tabela da Pluggy; plano gratuito citado com limite de 5 conexões; preço e escopo por banco **não confirmados**, e passa por empresa intermediária, risco a aceitar). 2ª opção: alertas por e-mail. Entrar com senha de banco por script está fora.

## 8. Privacidade

- Vault fora do repositório (ex.: `~/Cérebro`), sem sincronização. Pastas `.obsidian` dentro do repo do Azmuth entram no `.gitignore`; teste falha se algum caminho do vault aparecer no repo.
- Tudo que o Claude lê sai da máquina (servidores da Anthropic). A proteção reduz o que ele chega a ler; não elimina isso. Miguel foi avisado e aceitou.
- Mensagem recebida de fora (WhatsApp, e-mail, web) é entrada não confiável e nunca altera regras de acesso.

## 9. Preenchimento

1. Estrutura + `00-Mapa.md` + modelo de nota.
2. Semente automática: Rice-Azmuth (projeto, comandos, atalhos, decisões, armadilhas), destilada da conversa, do repositório e da memória, e não despejada crua; Estudos/Carreira/Projetos a partir das skills sincronizadas (ladg-*, professor, gd-mentor) e da memória.
3. Entrevista em blocos curtos: amigos (começando por Viktor/Pedro Victor, Pedro Brasil, Bruno; há muitos links entre eles), família, relacionamentos, rotina, planos. Miguel fala solto, o Claude transforma em notas.
4. Apagar as duas notas vazias atuais (`Vida.md`, `Finanças.md`) do vault de `~/Obsidian Vault`; reaproveitar o vault (decisão dele: "poderia até apagar").

## 10. Abordagens consideradas

- Base Markdown ligada (escolhida): legível, editável, Claude lê nativamente, o Obsidian mostra grafo/canvas.
- Banco de dados/vetores: mais "inteligente" para busca, mas opaco, difícil de editar e exige modelo de embeddings (proibido fora do Claude). Descartada.
- Tudo no contexto: simples, mas gasta token e expõe tudo sempre. Descartada.
Proteção financeira: cofre só local (descartado: nenhum modelo local), dados higienizados + sessão isolada (escolhido), tudo aberto (descartado).

## 11. Deixado ao construtor

Formato exato do `00-Mapa.md` e do gerador; nome da ferramenta e do pacote; como o modo restrito é aberto (comando ou aba); implementação do filtro de caminhos; regras de categoria do script de extrato; formato dos relatórios.

## 12. Decisões minhas após a revisão (marcadas para o Miguel conferir)

- Leitura/escrita só por **novos comandos de `ai-action`** (`read_note`, `write_note`), com o validador atual; o Read nativo do Claude no vault fica proibido (burlaria o filtro por nota).
- **Modo restrito = outra sessão do Claude**: session id próprio, `--allowed-tools` próprio (só leitura/cálculo de notas restritas, sem `ai-action` de envio) e prompt próprio. Contaminação por sessão separada, e não por flag. v1: entrada por `azmuth ask --restricted`; botão no Super+A fica para depois.
- **Escrita v1**: só em notas `aberto`, por `write_note`; o código valida caminho dentro do vault e front matter, e **nunca permite baixar o `acesso` de uma nota existente**; o modelo não escolhe `acesso: aberto` para conteúdo novo que mencione banco, CPF ou valores (o validador recusa palavras-chave financeiras). Sem confirmação em notas abertas. Escrita em notas restritas: fora do v1.
- **Finanças**: o script grava um arquivo de dados dentro do vault (`Finanças/`, `acesso: financas`); descrição desconhecida vai para "Outros", sem texto original. Gatilho: comando manual e na abertura do modo restrito. Formato (CSV/OFX/PDF) por banco: **o Miguel manda um extrato de exemplo de cada** antes dessa etapa.
- **`00-Mapa.md`**: gerado na mudança de arquivos, com teto de tamanho e colapso por pasta quando passar do teto.
- **Local do vault**: `~/Cérebro`, configurável. Começa do zero; as duas notas do `~/Obsidian Vault` são apagadas. O preenchimento (semente e entrevista) é trabalho de conteúdo com o Claude, fora dos critérios de código.
- **Teste de vazamento**: confere arquivos rastreáveis e `.gitignore`, e procura o caminho literal do vault no conteúdo do repo.

## 13. Decisão do Miguel: o Claude Code do terminal e as notas restritas

Aprovado em 2026-11-19: o Claude Code deste terminal **não lê** notas `financas` nem `identidade`; só o modo restrito do Azmuth lê. Como regra de permissão do Claude Code só enxerga caminhos, e não o front matter, as notas restritas moram sempre em duas pastas fixas (`Finanças/` e `Vida/Identidade/`), e um teste confere que toda nota restrita está numa delas. A regra de negação no `settings.json` do Claude Code é um passo do plano que **só se aplica com o OK do Miguel**.

## 14. Fontes de conhecimento e "nascimento" do Azmuth

Não há treinamento de modelo. O Azmuth é o Claude com persona, ferramentas e o vault. Ele "aprende" só escrevendo e lendo notas. Nascimento, em ordem:
1. Persona atual + vault vazio com estrutura.
2. Semente automática (projeto, conversa, skills sincronizadas, memória).
3. Importação da memória que o Miguel tem fora daqui (Claude Desktop e o Gemini/Antigravity), **sempre de ida só para o vault**, por exportação ou colagem feita por ele e revisada antes de entrar (skill `import-memory`). Não há ponte ao vivo entre modelos: o que o Gemini sabe é dado pessoal e não passa a ser lido por outro modelo de forma contínua (decisão de privacidade: nada de dado do vault em outro modelo).
4. Primeira conversa guiada: o Azmuth se apresenta e entrevista o Miguel em blocos curtos (amigos, família, rotina, planos), gravando notas `aberto`.
5. Crescimento: nota `Azmuth/Aprendizados.md`, onde o Miguel corrige ("não faz X", "prefiro Y") e o Azmuth consulta antes de agir.
