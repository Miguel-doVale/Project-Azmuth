# Diagnóstico da sessão — 16 de outubro de 2026

A interface do Azmuth voltou a funcionar após corrigir a detecção da shell e
recuperar o serviço de notificações. A checagem geral registrou **38 verificações
aprovadas**. As preferências de widgets, playlists, calendário, aplicativos e
bloqueio foram comparadas antes e depois e permaneceram iguais.

## O que foi encontrado

- A shell estava aberta com `qs -n -d -p .../shell`, mas `shell_running()` procurava
  literalmente `qs -p .../shell` no comando do processo. Essa diferença fazia os
  comandos de bloqueio, energia e HUD considerarem a interface ausente.
- O Dunst havia assumido `org.freedesktop.Notifications`. O Quickshell registrou
  que não conseguia ser o servidor porque outro já possuía esse nome.
- Context Engine, Hypridle, Hyprpaper, histórico de clipboard, rede e áudio
  continuavam ativos. O tema SDDM também estava instalado e selecionado.
- O log da shell anterior termina às 17:12:44; o Dunst iniciou às 17:12:49.
  Isso é compatível com o encerramento da interface seguido da ativação da
  reserva. Não foi encontrado registro de crash, coredump ou OOM que explique
  o motivo inicial. A causa exata desse encerramento permanece indeterminada.

## Correções

A interface agora é reconhecida pelo IPC da própria configuração, independentemente
da ordem dos argumentos usados para abri-la. A prévia do bloqueio nunca chama uma
trava real como alternativa. Ao iniciar, a shell recupera as notificações do Dunst
quando ele pertence ao mesmo usuário; outros servidores não são encerrados.

**`azmuth send`** (equivalente a `azmuth start`) recupera os componentes ausentes,
reaplica o DNA salvo e recupera as notificações. O comando pode ser repetido sem
abrir outra shell ou outro Context Engine. A entrada da sessão usa o mesmo caminho
com `--login`, incluindo os aplicativos de login configurados. A recuperação manual
não reinicia esses aplicativos.

**`azmuth doctor`** e **`azmuth doctor --json`** conferem o estado dos componentes.
O serviço SDDM não foi reiniciado durante o trabalho.

## Cobertura da checagem geral

| Área | Verificação |
| --- | --- |
| Interface e notificações | IPC, instância única, entrega de popup temático e servidor correto |
| HUD e DNAs | Catálogo, navegação, transformação real em Massa Cinzenta e retorno ao DNA anterior, sem abrir apps |
| Lançador | Abertura, catálogo e playlists carregadas |
| Dashboard e widgets | Abertura, dados carregados e modo de edição do canvas |
| Central | As sete abas, preferências carregadas, redes detectadas, dispositivos e saída padrão de áudio |
| Clipboard | Histórico carregado, incluindo entradas com imagem; conteúdo não alterado |
| Calendário | Eventos existentes carregados na interface; dados preservados |
| Bloqueio | Prévia nativa, relógio, DNA e disco; ausência de bloqueio real durante o teste |
| SDDM | Tema instalado igual ao do projeto e greeter em modo de teste |
| Arquivos | Dolphin aberto numa pasta temporária; cor, múltiplos marcadores e restauração do ícone |
| Terminal | Janela temporária com tema, integração do prompt e Fastfetch |
| Gerenciador de tarefas | Janela, processos e métricas reais e leitura da inicialização |
| Energia e sessão | Menu aberto sem executar ações; sessão e preferências conferidas ao final |

Testes automatizados complementam a checagem: sinais enviados apenas a processos
filhos de teste, identidade do PID, proteção da sessão, autostart em diretórios
temporários, preferências por DNA, detecção por IPC e prévia sem bloqueio real.

## Limites

A autenticação por PAM e SDDM não foi exercitada com senha. Não foram executados
suspensão, desligamento, reinicialização, troca de rede ou mudanças nos dispositivos
de áudio. Os painéis foram consultados sem interromper a sessão.

A interface do assistente abriu, mas nenhuma pergunta foi enviada ao provedor.
A implementação atual continua vinculada ao Claude Code; a futura integração com
Gemini e a disponibilidade da conta não fazem parte desta validação.
