# Gerenciador de tarefas do Azmuth

Janela nativa Quickshell com a paleta do DNA ativo, processos do Linux,
telemetria e aplicativos de inicialização. Abre com **Ctrl + Shift + Esc**,
Central → Sistema, pelo lançador ou com `azmuth tasks`. Os indicadores de
CPU/RAM da barra abrem Desempenho.

## Uso

- **Processos**: busca por nome, PID, usuário ou comando; filtro por usuário;
  ordenação por nome, PID, CPU e RAM; detalhes e ações de encerrar, pausar,
  retomar ou forçar encerramento.
- **Desempenho**: CPU e núcleos lógicos, RAM, swap, temperatura, disco e rede.
- **Inicialização**: entradas XDG do login, aplicativos de cada DNA e
  componentes fixos da sessão. Adicione aplicativos instalados pelo seletor.

Pausar e encerrar exigem confirmação no painel. Processos de outros usuários
e componentes essenciais da sessão são somente leitura. A validação de
identidade usa PID e instante de criação, com envio de sinais pelo `pidfd`
do processo selecionado.

A leitura ocorre a cada 1,5 segundo, somente enquanto esta janela está
aberta e a coleta não está pausada. O histórico de até 90 segundos permanece
na memória. CPU por processo é normalizada pela capacidade total da
máquina; RAM é RSS e pode contar páginas compartilhadas em várias linhas.
Disco e rede mostram taxas de transferência, não porcentagens de ocupação.

Ctrl+F busca. Ctrl+R pausa/retoma ou atualiza Inicialização. Esc fecha o
seletor de apps, cancela a confirmação, limpa a seleção e fecha a janela.
O Protocolo de Scan marca as três abas visitadas e os nomes de processos
inspecionados durante esta abertura.

## Inicialização

As entradas padrão vêm de `$XDG_CONFIG_HOME/autostart` e dos diretórios de
`$XDG_CONFIG_DIRS` (normalmente `~/.config/autostart` e `/etc/xdg/autostart`).
Prevalece a configuração do usuário. Escopo do desktop, `Hidden`, `TryExec`
e `X-GNOME-Autostart-enabled` são respeitados.

Alterações criam uma configuração do usuário, sem escrever em `/etc`.
Arquivos do usuário modificados pela primeira vez recebem backup em
`~/.local/state/azmuth/startup-backups/`. Adicionar copia uma entrada de
aplicativo instalado; remover apaga apenas uma entrada criada pelo Azmuth,
sem remover o aplicativo. As escolhas do login valem na próxima sessão.

O hook Lua `hyprland.start` chama `azmuth tasks --autostart-run`. Esse
iniciador executa **somente entradas adicionadas ou alteradas explicitamente
pelo gerenciador**, marcadas com `X-Azmuth-Managed=true` ou
`X-Azmuth-Added=true`. Entradas XDG intocadas mostram seu estado para
consulta e continuam a cargo dos mecanismos da sessão. Uma marca por sessão
evita repetição; `gio launch` interpreta o arquivo `.desktop`, sem passar
o comando por um shell. Instalações com outro iniciador XDG devem escolher
um único mecanismo para executar essas entradas.

Aplicativos dos DNAs usam `dna.<id>.autostart_apps` e
`dna.<id>.disabled_apps` em `settings.json`; as escolhas valem na próxima
transformação. Habilitar um app de um DNA com autostart desligado mantém os
outros desabilitados. Componentes definidos no Lua aparecem separados,
para consulta.

## Implementação e verificação

- `shell.qml`: janela, páginas e IPC do gerenciador.
- `src/task_manager.py`: leitura de `/proc` e `/sys`, sinais e inicialização.
- `components/`: links para as cores e runas compartilhadas pela shell.
- `shell/SystemPanel.qml`: ponto de entrada na Central.

A janela tem seu próprio processo Quickshell; fechar o gerenciador encerra
o leitor sem reiniciar a barra ou a tela de bloqueio. São usadas as
ferramentas já presentes na rice: Python 3, Quickshell e `gio` (GLib).
O controle de processos exige Linux/Python com suporte a `pidfd`.

```bash
azmuth tasks
azmuth tasks --tab performance
azmuth tasks --tab startup
.venv/bin/python -B -m unittest discover -s tests -v
```

Os testes usam processos filhos e configurações temporárias para validar
identidade, sinais, proteção da sessão, entradas XDG e preferências por DNA.
Não encerram aplicativos do usuário nem mudam sua lista de inicialização.
