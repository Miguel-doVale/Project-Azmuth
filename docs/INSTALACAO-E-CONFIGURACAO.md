# Instalação, arquitetura e configuração

O Project Azmuth é uma rice para Arch Linux e Hyprland. Este guia explica como a sessão é conectada, onde cada recurso mora, quais dados ele salva e como adaptar a instalação para outra máquina.

Leia também o [manual de uso](MANUAL.md), a [especificação de DNA](DNA_Schema_Spec.md), a documentação do [Dolphin](../filemanager/README.md) e do [gerenciador de tarefas](../taskmanager/README.md).

**Atualizado em 17 de outubro de 2026.**

## Estado e compatibilidade

O projeto é mantido para Arch Linux, Wayland e Hyprland. A configuração de atalhos usa a API Lua hl.* do Hyprland; ela não é um arquivo tradicional de binds para copiar para qualquer compositor. A interface visual é uma aplicação Quickshell em QML.

O ambiente de referência desta revisão usa Hyprland 0.56.2, Quickshell 0.3.2 e Python 3.14.8. O repositório não fixa versões mínimas para todas as dependências; atualizações do Arch ou do Quickshell podem exigir ajustes. Consulte os [utilitários Lua do Hyprland](https://wiki.hypr.land/configuring/core/advanced-configuration/lua-utilities/) e a [documentação do Quickshell](https://quickshell.org/docs/).

Hoje, Neutral e Massa Cinzenta têm arquivos de DNA aplicáveis. Os outros aliens do catálogo ainda aparecem bloqueados. A gramática Galvan segue em desenvolvimento. O assistente usa Ollama local, com base inicial de Ben 10 e ações limitadas a comandos validados do Azmuth; não requer API, assinatura ou acesso aos documentos pessoais.

## Como as peças se conectam

O DNA YAML é a fonte de identidade, cores e comportamento. O motor Python valida o perfil e aplica seus efeitos aos programas do sistema. A shell QML exibe a interface e grava as preferências que a pessoa altera pela Central.

**Fluxo:** Hyprland Lua (atalhos e início da sessão) → <code>bin/azmuth</code> → <code>src/core.py</code> → <code>dna/*.yaml</code> e configurações geradas. O hook também inicia <code>src/session_runtime.py</code>, que sobe Quickshell e os serviços necessários. A shell lê e grava dados em <code>~/.local/state/azmuth/</code>. <code>src/context_engine.py</code> acompanha regras e eventos; <code>src/task_manager.py</code> fornece processos e métricas.

| Camada | Entrada principal | Responsabilidade |
| --- | --- | --- |
| Integração da sessão | <code>hypr/azmuth.lua</code> | Atalhos, eventos de janela e chamada de recuperação ao iniciar Hyprland. |
| Comando | <code>bin/azmuth</code> | Resolve o caminho real do repositório e chama o Python do ambiente virtual <code>.venv</code>. |
| Motor | <code>src/core.py</code> | Lê e valida DNAs, aplica transformações, guarda estado e oferece a CLI. |
| Interface | <code>shell/shell.qml</code> e <code>shell/*.qml</code> | Barra, Omnitrix, Central, widgets, bloqueio, notificações e painéis Quickshell. |
| Sessão | <code>src/session_runtime.py</code> | Inicia componentes ausentes, recupera notificações e oferece <code>azmuth doctor</code>. |
| Áudio | <code>src/audio_runtime.py</code> | Recupera Dummy Output, lista portas físicas e controla EQ PipeWire/EasyEffects. |
| Contexto | <code>src/context_engine.py</code> | Reage ao foco de janelas, acompanha eventos, energia, downloads e failsafe. |
| Arquivos | <code>src/file_manager.py</code>, <code>src/folder_style.py</code> | Prepara o tema Dolphin e cria ícones personalizados para pastas. |
| Tarefas | <code>src/task_manager.py</code>, <code>taskmanager/</code> | Lê processos e métricas e administra inicialização pela interface. |
| Dados | <code>~/.local/state/azmuth/</code> | Preferências, estado e conteúdo criado pela pessoa usuária. |

## Mapa de funcionalidades

| Recurso | Implementação | Integração e dados |
| --- | --- | --- |
| Omnitrix e seleção de DNA | <code>shell/OmnitrixDial.qml</code>, <code>shell/shell.qml</code>, <code>src/core.py</code> | <code>Super + Space</code> chama a shell por IPC. O catálogo fica em <code>dna/omnitrix.yaml</code>; a transformação chama <code>azmuth apply</code>. |
| Perfis e transformação | <code>dna/*.yaml</code>, <code>src/core.py</code> | O motor valida o YAML e aplica Hyprland, wallpaper, Rofi, Dunst, Hyprlock, Kitty e Dolphin. DNA ativo e energia ficam no estado Azmuth. |
| Barra e bandeja | <code>shell/Bar.qml</code>, <code>shell/SysStats.qml</code> | Quickshell cria uma barra por monitor; lê tema ativo, workspaces, janelas, rede, PipeWire, bateria e bandeja. |
| Desktop animado e widgets | <code>shell/LiveDesktop.qml</code>, <code>shell/Widgets.qml</code>, <code>shell/DeskWidget.qml</code>, <code>shell/DeskLayout.qml</code> | O desktop animado lê DNA e métricas. Posição, escala e catálogo ficam em <code>desktop.json</code>. |
| Lançador e playlists | <code>shell/Launcher.qml</code>, <code>shell/Playlists.qml</code> | Catálogo vem dos arquivos <code>.desktop</code>. Playlists, runas, cores, ordem e aplicativos ficam em <code>playlists.json</code>. |
| Constelação | <code>shell/Constellation.qml</code>, <code>hypr/azmuth.lua</code> | Usa janelas e workspaces do Hyprland; <code>Alt + Tab</code> alterna e <code>Super + Tab</code> abre navegação. |
| Calendário e lembretes | <code>shell/CalendarPanel.qml</code>, <code>shell/QuickEvent.qml</code>, <code>shell/Events.qml</code>, <code>src/context_engine.py</code> | Eventos ficam em <code>events.json</code>; lembretes dependem do Context Engine. |
| Central | <code>shell/ConfigCenter.qml</code> e <code>shell/*Panel.qml</code> | <code>Super + Shift + O</code> abre Omnitrix, Apps, Wi-Fi, Som, Área de trabalho, Calendário e Sistema. |
| Wi-Fi | <code>shell/WifiPanel.qml</code> | Usa Networking do Quickshell e NetworkManager. Conexões e credenciais são geridas pelo serviço do sistema. |
| Som | <code>shell/SoundPanel.qml</code>, <code>src/audio_runtime.py</code> | Seleciona dispositivos e rotas físicas, controla apps; EQ de 10 bandas integrado pelo EasyEffects. |
| Área de transferência | <code>shell/Clipboard.qml</code> | <code>wl-paste --watch cliphist store</code> captura itens; cache de miniaturas e fixados ficam separados. |
| Notificações | <code>shell/Notifications.qml</code>, <code>dunst/dunstrc.tmpl</code> | Quickshell fornece servidor e histórico. Dunst é alternativa e recebe paleta derivada do DNA. |
| Bloqueio | <code>shell/Lock.qml</code>, <code>shell/LockFace.qml</code>, <code>hypr/hyprlock.conf.tmpl</code> | A tela principal usa bloqueio Quickshell e PAM. Hyprlock é alternativa quando a shell está indisponível. |
| Energia e failsafe | <code>shell/Energy.qml</code>, <code>shell/PowerMenu.qml</code>, <code>src/core.py</code>, <code>src/context_engine.py</code> | O motor calcula descarga/recarga; o Context Engine vigia bateria e temperatura. |
| Capturas e gravação | <code>src/core.py</code>, função <code>cmd_shot</code> | Usa Slurp, Grim, wf-recorder e wl-clipboard; salva em <code>~/Pictures/Screenshots</code> e <code>~/Videos/Recordings</code>. |
| Gerenciador de tarefas | <code>src/task_manager.py</code>, <code>taskmanager/</code>, <code>shell/SystemPanel.qml</code> | <code>Ctrl + Shift + Esc</code> abre processos, desempenho e inicialização. Lê <code>/proc</code>/<code>/sys</code> e usa XDG autostart. |
| Dolphin | <code>src/file_manager.py</code>, <code>src/folder_style.py</code>, <code>filemanager/</code> | Tema opcional. Cada pasta personalizada guarda estilo em <code>.azmuth-folder/</code> e o ícone em <code>.directory</code>. |
| Terminal e prompt | <code>terminal/kitty.conf</code>, <code>terminal/kitty-colors.tmpl</code>, <code>terminal/azmuth.bash</code>, <code>terminal/fastfetch.jsonc</code> | <code>azmuth install</code> liga arquivos do projeto à configuração do usuário; a transformação gera a paleta Kitty. |
| Login SDDM | <code>sddm/</code> | Tema opcional instalado separadamente com privilégios administrativos; não é a tela de bloqueio. |
| Context Engine | <code>src/context_engine.py</code> e <code>context_engine</code> nos DNAs | Observa classe/título da janela em foco. Sugere transformações; Master Control permite aplicação automática. |
| Assistente local | <code>src/azmuth_ai.py</code>, <code>shell/Assistant.qml</code>, <code>data/ben10_knowledge.md</code> | Usa a API HTTP local do Ollama. Inclui uma base de Ben 10, histórico temporário e ferramentas validadas para comandos Azmuth; não lê documentos pessoais. |
| Runas | <code>shell/Galvan.js</code>, <code>shell/Glyph.qml</code>, <code>tools/gen_galvan.py</code> | O conjunto visual de 24 runas é compartilhado pela interface. A linguagem e o tradutor estão em desenvolvimento. |
| Recuperação | <code>src/session_runtime.py</code> | <code>azmuth send</code>/<code>azmuth start</code> recuperam componentes ausentes; <code>azmuth doctor</code> mostra o diagnóstico. |

## Dependências

### Base necessária

A lista instala os componentes usados diretamente pelo projeto. Se o computador já usa outro serviço de rede ou áudio, não instale um segundo gerenciador concorrente; adapte a integração ao serviço em uso.

    sudo pacman -S --needed git hyprland quickshell python python-pip \
      hyprpaper hypridle kitty fastfetch cliphist wl-clipboard grim slurp \
      wf-recorder dolphin rofi networkmanager pipewire wireplumber \
      pipewire-pulse libnotify glib2

Crie um ambiente virtual na raiz e instale PyYAML nele. O executável <code>bin/azmuth</code> usa exatamente esse ambiente:

    python -m venv .venv
    .venv/bin/python -m pip install PyYAML

O gerenciador de tarefas precisa de Linux/Python com suporte a pidfd para controlar processos. CPU, memória, disco, rede e temperatura são lidos em <code>/proc</code> e <code>/sys</code>; alguns sensores podem não existir em todo hardware.

| Componente | Necessário para |
| --- | --- |
| Quickshell com Core/QML, Io, Widgets, Hyprland, Wayland, Networking, PipeWire, System Tray, UPower, MPRIS, Notifications e PAM | Shell, barra, rede, som, mídia, bandeja, bateria, notificações e bloqueio. |
| NetworkManager e <code>nmcli</code> | Lista e conexão de redes. O serviço do sistema precisa estar ativo; algumas configurações também exigem um agente Polkit na sessão. |
| PipeWire, WirePlumber e <code>wpctl</code> | Áudio, dispositivos e volume. |
| <code>wl-clipboard</code> e <code>cliphist</code> | Histórico, fixados e integração da área de transferência. |
| <code>grim</code>, <code>slurp</code>, <code>wf-recorder</code> | Capturas e gravações. |
| <code>gio</code>, <code>systemctl</code>, <code>busctl</code>, <code>notify-send</code>, <code>pw-play</code> | Inicialização, sessão, notificações e sons. <code>gio</code> vem de GLib e <code>notify-send</code> de libnotify. |
| Rofi | Seletor de reserva do Omnitrix e menu de energia quando Quickshell não está disponível. |
| Hyprlock e Dunst | Alternativas de bloqueio e notificação. A tela principal usa Quickshell. |
| Dolphin | Explorador e personalização de pastas. |
| Kitty e Fastfetch | Terminal, prompt, cores e banner. |
| Orbitron, Rajdhani, JetBrainsMono Nerd Font e Font Awesome 7 Free | Tipografia e ícones. JetBrainsMono Nerd Font e Font Awesome estão nos pacotes <code>ttf-jetbrains-mono-nerd</code> e <code>otf-font-awesome</code>; Orbitron e Rajdhani podem ser instaladas em <code>~/.local/share/fonts</code>. |
| EasyEffects 8.2.8 ou mais recente | Equalizador integrado na Central; instalação opcional. O servidor local precisa estar ativo. |
| Ollama e um modelo local | Somente o assistente Azmuth; instalação opcional. |
| SDDM | Somente o tema opcional de login. |
| Pillow e NumPy | Somente os geradores de arte/som em <code>tools/</code>. |

Para executar esses geradores pelo ambiente virtual:

    .venv/bin/python -m pip install Pillow numpy

Hyprlock e Dunst são alternativas opcionais. Para habilitar esses caminhos de reserva:

    sudo pacman -S --needed hyprlock dunst

Orbitron e Rajdhani estão disponíveis no [Google Fonts: Orbitron](https://fonts.google.com/specimen/Orbitron) e [Google Fonts: Rajdhani](https://fonts.google.com/specimen/Rajdhani). Para instalar as outras fontes e o utilitário de cache:

    sudo pacman -S --needed ttf-jetbrains-mono-nerd otf-font-awesome fontconfig

Instale os arquivos Orbitron e Rajdhani em <code>~/.local/share/fonts</code> e atualize o cache:

    fc-cache -f

O projeto usa módulos do Quickshell que precisam estar disponíveis na compilação instalada. Consulte [os pacotes do Quickshell no Arch](https://archlinux.org/packages/extra/x86_64/quickshell/) e a [lista de módulos oficiais](https://quickshell.org/docs/v0.2.1/types/).

### Serviços

A aba Wi-Fi precisa do NetworkManager. Se ele for seu único gerenciador de rede:

    sudo systemctl enable --now NetworkManager

O som precisa de PipeWire e WirePlumber ativos na sessão do usuário. Em uma instalação que já usa PipeWire, não crie serviços ou autostarts duplicados.

### Assistente local (Ollama)

O assistente é opcional e roda inferência na própria máquina. No Arch, instale o pacote oficial, inicie o serviço e baixe o modelo padrão:

    sudo pacman -S --needed ollama
    sudo systemctl enable --now ollama.service
    ollama pull qwen3.5:4b

O Qwen 3.5 4B ocupa aproximadamente 3,3–4,0 GB no catálogo do Ollama e oferece suporte a ferramentas. O Azmuth usa a API de chat e chamadas de ferramentas do Ollama em <code>127.0.0.1:11434</code>, sem enviar prompts a um serviço remoto. O projeto limita o contexto do modelo a 8.192 tokens para esta integração. Em CPU, as respostas podem levar alguns minutos, conforme o hardware e o tamanho do contexto; a interface mostra o estado de espera e recebe a resposta completa ao final. Fontes: [pacote Ollama no Arch](https://archlinux.org/packages/extra/x86_64/ollama/), [modelo Qwen 3.5](https://ollama.com/library/qwen3.5), [API de chat](https://docs.ollama.com/api/chat) e [tool calling](https://docs.ollama.com/capabilities/tool-calling).

Valide serviço e modelo antes de abrir o assistente:

    azmuth ask --status
    azmuth ask "Quem criou o Omnitrix?"

Para usar outra variante, baixe-a com <code>ollama pull</code> e ajuste <code>DEFAULT_MODEL</code> em <code>src/azmuth_ai.py</code>. O histórico guarda até seis trocas e deixa de ser carregado após 30 minutos sem uso; o arquivo fica em <code>~/.local/state/azmuth/ai/ollama-history.json</code> e pode ser removido manualmente. O contexto inclui o estado do Azmuth, eventos e títulos/classes das janelas abertas; não há indexação nem leitura de documentos pessoais. A base de Ben 10 está em <code>data/ben10_knowledge.md</code>.

As ações ficam em uma allowlist no código. O modelo não recebe shell: pedidos são convertidos em argumentos validados para comandos Azmuth. Ele pode abrir o menu de energia ou bloquear a tela se isso for pedido; não pode selecionar suspender, sair, reiniciar ou desligar, liberar o Life-Form Lock ou disparar capturas. Use os atalhos do sistema para capturas.

## Instalação em outra máquina

### 1. Clone no caminho esperado

Alguns atalhos e o prompt Bash partem de <code>~/Documents/Coding/Project Azmuth</code>. Use esse caminho para aproveitar os padrões sem edição:

    mkdir -p "$HOME/Documents/Coding"
    git clone https://github.com/Miguel-doVale/Project-Azmuth.git "$HOME/Documents/Coding/Project Azmuth"
    cd "$HOME/Documents/Coding/Project Azmuth"

Se escolher outro diretório, ajuste os caminhos fixos explicados em [Adaptar para outra pasta](#adaptar-para-outra-pasta).

### 2. Prepare Python

Na raiz:

    python -m venv .venv
    .venv/bin/python -m pip install PyYAML
    .venv/bin/python src/core.py roster

O último comando lista DNAs sem transformar o desktop.

### 3. Instale os links do usuário

    .venv/bin/python src/core.py install

O comando cria diretórios e liga os seguintes arquivos:

| Alvo | Fonte |
| --- | --- |
| <code>~/.local/bin/azmuth</code> | <code>bin/azmuth</code> |
| <code>~/.config/hypr/azmuth.lua</code> | <code>hypr/azmuth.lua</code> |
| <code>~/.config/hypr/hypridle.conf</code> | <code>hypr/hypridle.conf</code> |
| <code>~/.config/kitty/kitty.conf</code> | <code>terminal/kitty.conf</code> |
| <code>~/.config/fastfetch/config.jsonc</code> | <code>terminal/fastfetch.jsonc</code> |
| <code>~/.config/fastfetch/omnitrix.txt</code> | <code>terminal/omnitrix.txt</code> |

Também registra o aplicativo do gerenciador de tarefas e acrescenta o prompt ao <code>.bashrc</code>. Se um alvo já existe, o instalador o renomeia para <code>&lt;nome&gt;.pre-azmuth</code> antes de criar o link. Confira os backups se uma configuração não carregar. O instalador não instala pacotes, não edita o arquivo principal do Hyprland nem instala SDDM.

Garanta que <code>~/.local/bin</code> esteja no <code>PATH</code>. Abra um terminal novo ou atualize o shell depois da instalação.

### 4. Carregue a integração Lua

O Hyprland deve carregar uma configuração Lua que exponha a API <code>hl.*</code>. No arquivo principal, normalmente <code>~/.config/hypr/hyprland.lua</code>, adicione uma única vez:

    require("azmuth")

Não adicione um segundo autostart para a shell: o evento <code>hyprland.start</code> já chama <code>azmuth start --login</code>. Resolva binds duplicados e barras/notificadores concorrentes na configuração existente.

Saia da sessão e entre novamente. Para iniciar/recuperar manualmente dentro do Hyprland:

    azmuth start
    azmuth doctor

<code>azmuth start --login</code> também executa uma vez os aplicativos de login escolhidos no gerenciador. <code>azmuth send</code> é o alias de recuperação manual e não reabre esses aplicativos.

### 5. Integrações opcionais

**Dolphin**

    azmuth files --setup
    azmuth files --restore

O setup guarda um backup; restore recupera a configuração integrada. O backup é preservado. Veja [Dolphin](../filemanager/README.md) para as ações e o editor de pastas.

**SDDM**

Se quiser usar o tema e SDDM ainda não estiver instalado:

    sudo pacman -S --needed sddm

    bash sddm/install.sh

O script usa sudo para copiar o tema para <code>/usr/share/sddm/themes/azmuth</code> e selecionar <code>Current=azmuth</code> em <code>/etc/sddm.conf.d/azmuth.conf</code>. A mudança vale no próximo login. Reiniciar SDDM encerra a sessão gráfica atual.

Remover a configuração do tema:

    bash sddm/install.sh --remove

## Configurar a rice

### Central de Configuração

Abra com <code>Super + Shift + O</code>. As abas gravam dados nos arquivos do usuário; não é necessário alterar QML para as opções que a interface expõe.

| Aba | Ajustes | Persistência |
| --- | --- | --- |
| Omnitrix | Master Control, sugestões, desktop vivo, sons, notificações de transformação, Não perturbe, energia, sequência do bloqueio e apps por DNA | <code>settings.json</code>; Master Control em <code>state.json</code>; sequência em <code>lockseq.json</code>. |
| Apps | Criar, apagar, renomear e ordenar playlists; runa/cor; aplicativos; apps sem playlist | <code>playlists.json</code>. |
| Wi-Fi | Estado, redes, conexão e configuração avançada | NetworkManager. |
| Som | Dispositivos de entrada/saída, volume e fluxos | PipeWire/WirePlumber. |
| Área de trabalho | Desktop vivo, widgets, imagens e disposição | <code>settings.json</code> e <code>desktop.json</code>. |
| Calendário | Eventos, horários, cores e lembretes | <code>events.json</code>. Clique num dia do widget para criar evento rápido. |
| Sistema | Métricas, processos, desempenho e inicialização | Sistema, XDG autostart e preferências por DNA. |

### Preferências gerais

A Central grava em <code>~/.local/state/azmuth/settings.json</code>. Os padrões ficam em <code>DEFAULT_SETTINGS</code> dentro de <code>src/core.py</code>; o arquivo do usuário contém apenas substituições.

| Chave | Padrão | Efeito |
| --- | --- | --- |
| <code>sounds</code> | <code>true</code> | Sons emitidos pelo motor Python. |
| <code>notifications</code> | <code>true</code> | Notificações ao transformar. |
| <code>dnd</code> | <code>false</code> | Oculta popups comuns do Azmuth e preserva o histórico. |
| <code>live_desktop</code> | <code>true</code> | Exibe o desktop animado. |
| <code>context_engine</code> | <code>true</code> | Permite sugestões e transformações pelas regras. |
| <code>timer.enabled</code> | <code>true</code> | Liga energia, descarga e recarga. |
| <code>timer.minutes</code> | <code>10</code> | Minutos de descarga de 100% a 0%. |
| <code>timer.recharge_minutes</code> | <code>5</code> | Minutos de recarga de 0% a 100% no Neutral. |
| <code>timer.min_percent</code> | <code>20</code> | Carga mínima normal para transformar. |
| <code>dna.&lt;id&gt;.autostart_apps</code> | <code>true</code> | Permite abrir os apps definidos naquele DNA. |
| <code>dna.&lt;id&gt;.disabled_apps</code> | <code>[]</code> | Comandos individuais desativados no gerenciador. |

<code>azmuth set</code> recebe o valor como JSON:

    azmuth set timer.minutes 15
    azmuth set timer.enabled false
    azmuth set dnd true
    azmuth set dna.massa_cinzenta.autostart_apps false

A Central limita os controles de energia ao intervalo mostrado. Ao editar JSON ou usar a CLI, preserve tipos booleanos, números e texto.

### Estado e dados do usuário

Por padrão, os dados ficam em <code>~/.local/state/azmuth/</code>. A interface QML usa esse caminho diretamente. Embora partes do motor Python respeitem <code>XDG_STATE_HOME</code>, esta versão pressupõe o diretório padrão para manter shell e motor sincronizados.

| Arquivo | Conteúdo | Origem |
| --- | --- | --- |
| <code>state.json</code> | DNA atual/anterior, energia, Master Control, Life-Form Lock e sessões. | Gerado/atualizado por <code>src/core.py</code>. |
| <code>settings.json</code> | Preferências e apps habilitados por DNA. | Central e <code>azmuth set</code>. |
| <code>theme.json</code> | Paleta e valores calculados lidos pela shell. | Gerado; não edite manualmente. |
| <code>events.json</code> | Data, hora, cor e lembretes dos eventos. | Central/Calendário. |
| <code>playlists.json</code> | Playlists, ordem e IDs de aplicativos. | Central/Apps. |
| <code>desktop.json</code> | Tipo, posição e escala dos widgets. | Central/editor do desktop. |
| <code>lockseq.json</code> | Salt, tamanho e hash da sequência. | <code>azmuth lockseq</code>. |
| <code>clip-pins.json</code> | Itens fixados no clipboard. | <code>shell/Clipboard.qml</code>. |
| <code>tasks-request.json</code> | Pedido temporário de abertura de aba do gerenciador. | Gerado pela CLI. |
| <code>kitty-colors.conf</code> | Tema atual do Kitty. | Gerado na transformação. |
| <code>dolphin.qss</code>, <code>file-manager.json</code> | Tema e registro do backup Dolphin. | <code>src/file_manager.py</code>. |

O histórico cliphist também usa <code>~/.cache/azmuth/clip</code> para prévias. Ele pode conter conteúdo copiado anteriormente; limpe itens sensíveis pela interface quando não quiser mantê-los.

### DNA: aparência e comportamento

Os perfis ficam em <code>dna/&lt;id&gt;.yaml</code>. Neutral e Massa Cinzenta são exemplos. A validação completa está na [especificação de DNA](DNA_Schema_Spec.md).

| Campo | Efeito | Regra |
| --- | --- | --- |
| <code>dna.id</code>, <code>dna.name</code>, <code>dna.description</code> | Identidade do DNA. | O id é igual ao nome do arquivo sem .yaml. |
| <code>dna.core</code> | Marcador de sistema. | O validador aceita arch/kali; a experiência atual é para Arch. |
| <code>palette.*</code> | Cores de interface e arquivos derivados. | Cada valor deve ser #RRGGBB. |
| <code>hyprland.*</code> | Gaps, borda, arredondamento, animações e layout. | Layout dwindle ou master. |
| <code>wallpaper.path</code> | Wallpaper em cada monitor. | Caminho relativo à raiz do projeto; ausente gera aviso. |
| <code>bar.visible</code> | Barra visível/oculta. | Opcional; padrão true. |
| <code>hud.art</code> | Arte do alien no Omnitrix. | Opcional; caminho relativo à raiz. |
| <code>rofi.theme</code> | Regras específicas para Rofi. | Obrigatório e existente; paleta é gerada pelo motor. |
| <code>sound.transform</code> | Som ao entrar no DNA. | Opcional; caminho relativo à raiz. |
| <code>apps.autostart</code> | Apps abertos ao transformar. | Strings ou objetos com cmd, class e workspace. |
| <code>daemons.enable/disable</code> | Unidade systemd --user ou comando. | Opcional; o motor reverte os estados que controlou. |
| <code>context_engine.triggers</code> | Condições de classe/título da janela. | Formato class:REGEX ou title:REGEX. |

Exemplo de regra de contexto e aplicativo:

    apps:
      autostart:
        - { cmd: "kitty", class: "^(kitty)$", workspace: 1 }

    context_engine:
      triggers:
        - match: "class:^(code|Code|code-oss)$"
          suggest: true
          message: "Ambiente de desenvolvimento detectado"

Para criar um DNA:

1. Duplique <code>dna/neutral.yaml</code> como <code>dna/&lt;novo_id&gt;.yaml</code>.
2. Use o mesmo identificador em <code>dna.id</code> e no nome do arquivo.
3. Escolha paleta, wallpaper, arte e tema Rofi. Caminhos de assets são relativos à raiz.
4. Adicione um slot em <code>dna/omnitrix.yaml</code>. Sem YAML correspondente, o alien permanece bloqueado.
5. Rode <code>azmuth doctor</code> para conferir estrutura e assets. <code>azmuth apply &lt;novo_id&gt;</code> aplica de verdade e altera a sessão.
6. Ajuste templates e QML se o DNA exigir elementos além da paleta.

Ao transformar, <code>src/core.py</code> valida antes de alterar. Aplica propriedades do Hyprland por <code>hyprctl eval</code>, wallpaper por Hyprpaper, gera temas de Rofi/Dunst/Hyprlock/Kitty/Dolphin, administra daemons definidos e inicia apps. A shell recebe o novo <code>theme.json</code> por IPC.

### Onde alterar partes visuais e comportamentais

| Quero mudar… | Edite… | Aplicação |
| --- | --- | --- |
| Atalhos e comportamento de janelas | <code>hypr/azmuth.lua</code> | Recarregue/reinicie a sessão Hyprland. |
| Inatividade, bloqueio e desligamento da tela | <code>hypr/hypridle.conf</code> | Recarregue Hypridle ou entre novamente. |
| Estrutura, animação ou interação de painel | QML correspondente em <code>shell/</code> | Reinicie/recarregue Quickshell. |
| Componentes e tokens visuais | <code>shell/Colors.qml</code>, <code>shell/UiButton.qml</code>, <code>shell/UiToggle.qml</code>, <code>shell/UiSlider.qml</code>, <code>shell/UiSection.qml</code> | Alteração visual da shell. |
| Runas | <code>shell/Galvan.js</code> e <code>tools/gen_galvan.py</code> | Atualize fonte e consumidores em conjunto. |
| Arte/wallpaper | <code>assets/art/</code>, <code>assets/wallpapers/</code> | Referencie pelo DNA. |
| Sons | <code>assets/sounds/</code> | Referencie no DNA ou no componente correspondente. |
| Kitty | <code>terminal/kitty.conf</code>, <code>terminal/kitty-colors.tmpl</code> | Cores dinâmicas são regeneradas ao transformar. |
| Prompt/banner | <code>terminal/azmuth.bash</code>, <code>terminal/fastfetch.jsonc</code> | Bash carrega pelo .bashrc. |
| Dolphin | <code>filemanager/dolphin.qss.tmpl</code>, <code>filemanager/dolphinui.rc</code> | Rode setup e abra nova janela. |
| Login | <code>sddm/azmuth/</code> | Instalação manual pelo script SDDM. |
| Regras contextuais | <code>src/context_engine.py</code> e campos dos DNAs | Reinicie o Context Engine após mudar seu código. |
| Provedor, modelo, contexto e allowlist do assistente | <code>src/azmuth_ai.py</code> | Ollama em <code>127.0.0.1:11434</code>; altere <code>DEFAULT_MODEL</code> para escolher o modelo. A função <code>action_argv</code> valida cada ação permitida. |
| Conhecimento inicial de Ben 10 | <code>data/ben10_knowledge.md</code> | Resumo estático incluído no prompt local; pode ser expandido sem varrer arquivos pessoais. |

<code>theme.json</code>, <code>kitty-colors.conf</code>, <code>~/.config/rofi/azmuth.rasi</code>, <code>~/.config/dunst/dunstrc</code> e <code>~/.config/hypr/hyprlock.conf</code> são saídas geradas. Edite a fonte do projeto, pois uma transformação pode sobrescrevê-las.

### Launcher, widgets e calendário

**Playlists.** Edite pela Central → Apps. Na primeira execução, categorias dos arquivos .desktop criam playlists iniciais. Alterações seguintes são salvas no usuário. Apps que não aparecem em playlist ficam em “Sem playlist”. A identificação usa IDs .desktop, não o nome visual.

**Widgets.** Central → Área de trabalho adiciona relógio, anéis do sistema, energia, DNA ativo, música, calendário, barras do sistema e imagem. <code>Super + Alt + E</code> abre o editor. Posição e escala persistem em <code>desktop.json</code>. Uma imagem selecionada fica associada ao caminho local do arquivo.

A lista de diretórios de imagem e a pasta de wallpapers do projeto ficam em <code>shell/DesktopPanel.qml</code>. A lista atual inclui Imagens, Capturas, Downloads e <code>~/Documents/Coding/Project Azmuth/assets/wallpapers</code>.

**Calendário.** Clique em um dia do widget para evento rápido. A Central permite editar data, hora, cor e lembrete. Lembretes dependem do Context Engine ativo. Eventos de dia inteiro usam o horário definido no código do motor.

### Aplicativos de inicialização

Central → Sistema abre o gerenciador. A lista reúne arquivos XDG em <code>~/.config/autostart</code> e diretórios de <code>XDG_CONFIG_DIRS</code>, apps de cada DNA controlados por <code>dna.&lt;id&gt;.autostart_apps</code>/<code>dna.&lt;id&gt;.disabled_apps</code> e componentes fixos de sessão para diagnóstico.

O gerenciador cria cópias de usuário para entradas alteradas, guarda backups em <code>~/.local/state/azmuth/startup-backups/</code> e só remove entradas que ele próprio adicionou. Apps gerenciados pelo Azmuth são iniciados no login com <code>gio launch</code>; uma marca por sessão evita duplicação. Veja o [guia do gerenciador de tarefas](../taskmanager/README.md).

### Bloqueio e autenticação

<code>Super + M</code> bloqueia a sessão pelo Quickshell. A sequência é opcional e configurada no terminal:

    azmuth lockseq set L L R U R L R L
    azmuth lockseq status
    azmuth lockseq clear

L é esquerda, R direita e U pressiona o core. São necessários pelo menos seis movimentos. <code>lockseq.json</code> guarda salt, tamanho e hash, não a sequência em texto puro. Após três sequências erradas, resta a autenticação normal. <code>Tab</code> muda para a senha do sistema via PAM. Teste antes de bloquear:

    azmuth lock --preview

A sequência é um modo de entrada visual e não substitui PAM. SDDM é outro programa e tem instalação separada.

### Dolphin e ícones de pasta

Instale o tema com <code>azmuth files --setup</code>. Para reverter a integração, rode <code>azmuth files --restore</code>; o backup é preservado.

Para personalizar uma pasta: botão direito → **Azmuth · ferramentas → Personalizar pasta · cores e runas**. A cor base e cada marcador podem ter cores próprias. Marcadores aceitam runas Galvan ou texto, podem ser arrastados, redimensionados e ordenados em camadas. A configuração fica dentro da pasta em <code>.azmuth-folder/</code>; o campo Icon de <code>.directory</code> usa caminho relativo para acompanhar cópias que incluam arquivos ocultos. O editor tem a opção “Restaurar ícone”.

Veja também [filemanager/README.md](../filemanager/README.md).

## Comandos e recuperação

| Comando | Ação |
| --- | --- |
| <code>azmuth send</code> | Recupera shell, serviços, notificações e DNA salvo; alias de start. |
| <code>azmuth start --login</code> | Início idempotente e execução única dos apps de login Azmuth. |
| <code>azmuth doctor</code> | Diagnostica processos, IPC, notificações, configuração e dados. |
| <code>azmuth doctor --json</code> | Mesmo diagnóstico em JSON. |
| <code>azmuth audio</code> | Recupera a saída PipeWire quando o destino padrão vira Dummy Output. |
| <code>azmuth audio status</code> | Consulta o destino padrão sem reiniciar serviços. |
| <code>azmuth audio inventory --json</code> | Lista saídas, microfones e portas detectadas pelo PipeWire. |
| <code>azmuth audio route output|input DEVICE PORT</code> | Muda a rota física da saída ou entrada selecionada. |
| <code>azmuth audio eq enable</code> | Cria o preset Azmuth e ativa o EQ no EasyEffects. |
| <code>azmuth audio eq gain INDEX DB</code> | Ajusta uma banda (índice 0–9; ganho −12 a +12 dB). |
| <code>azmuth audio eq preset flat|bass|voice|treble</code> | Aplica uma curva inicial no equalizador. |
| <code>azmuth roster</code> | Lista slots e DNAs disponíveis. |
| <code>azmuth current --name</code> | Exibe DNA ativo. |
| <code>azmuth apply &lt;id&gt;</code> | Aplica DNA e altera a sessão atual. |
| <code>azmuth neutral</code> | Retorna ao Neutral. |
| <code>azmuth random</code> | Sorteia DNA disponível, ponderando gatilhos e carga. |
| <code>azmuth master on/off/toggle</code> | Liga ou desliga Master Control. |
| <code>azmuth set &lt;chave&gt; &lt;valor&gt;</code> | Persiste preferência; valor em JSON. |
| <code>azmuth event add AAAA-MM-DD [HH:MM] Título</code> | Cria evento. |
| <code>azmuth event list</code> | Lista próximos eventos. |
| <code>azmuth files --setup</code> | Instala a integração Dolphin com backup. |
| <code>azmuth files --restore</code> | Restaura a integração Dolphin. |
| <code>azmuth tasks --tab processes/performance/startup</code> | Abre uma aba do gerenciador. |
| <code>azmuth ask --status</code> | Verifica se Ollama responde e se o modelo escolhido está instalado. |
| <code>azmuth ask "pergunta"</code> | Conversa com o assistente pelo modelo local. |

<code>azmuth audio</code> só age quando a saída padrão está ausente ou é Dummy. Primeiro procura processos que abriram diretamente um PCM ALSA; se encontrar algum, informa o aplicativo para você fechá-lo ou configurá-lo para PipeWire. Sem bloqueadores, reinicia os serviços PipeWire/WirePlumber da sessão, aguarda uma saída física, define essa saída como padrão e redireciona fluxos ativos. Se o áudio já estiver normal, não reinicia nada. O microfone não é alterado. <code>azmuth audio status</code> consulta o estado atual. A Central lista as portas que PipeWire publica; rotas indisponíveis ficam visíveis, mas sem ação. Para equalização, instale <code>easyeffects</code> (Arch: <code>sudo pacman -S --needed easyeffects</code>) e mantenha a saída física como destino padrão. O painel usa o servidor local do EasyEffects 8.2.8 ou mais recente. As curvas plana, graves, voz e brilho, sliders por banda e controles avançados ficam na aba Equalizador. Se a integração não conectar, habilite o servidor local nas preferências do EasyEffects.

Execute os comandos do Azmuth dentro da sessão Hyprland. A recuperação da rice também precisa do caminho correto do repositório e do ambiente <code>.venv</code>.

## Adaptar para outra pasta

Se não clonar em <code>~/Documents/Coding/Project Azmuth</code>, edite estes caminhos antes de rodar <code>azmuth install</code>:

1. Em <code>hypr/azmuth.lua</code>, altere <code>PROJECT</code> para a pasta real; ela aponta para <code>shell/</code>.
2. Em <code>src/core.py</code>, atualize <code>BASHRC_LINE</code> para carregar <code>terminal/azmuth.bash</code> do novo local.
3. Em <code>shell/DesktopPanel.qml</code>, atualize a pasta “WALLPAPERS AZMUTH” do seletor de imagens.
4. Em <code>src/file_manager.py</code>, o atalho “projetos” aponta para <code>~/Documents/Coding</code>; ajuste se quiser outro diretório.

O motor descobre a raiz pelo próprio arquivo e os assets são relativos a ela. A maioria dos dados usa <code>$HOME</code>; não altere esses caminhos sem necessidade.

## Cópia de segurança e remoção

Preserve repositório e dados pessoais separadamente. O repositório contém código, assets e perfis padrão; <code>~/.local/state/azmuth/</code> contém estado e escolhas; <code>~/.config/autostart/</code> contém mudanças de inicialização. Personalizações de pasta ficam dentro das próprias pastas.

O instalador principal não tem desinstalador automático. Para voltar uma configuração, confira o link em <code>~/.config</code>, remova o link criado pelo Azmuth e restaure o arquivo <code>.pre-azmuth</code> correspondente. Verifique o conteúdo antes de sobrescrever uma configuração atual. Para Dolphin use <code>azmuth files --restore</code>; para SDDM use <code>bash sddm/install.sh --remove</code>.

## Problemas comuns

| Sintoma | O que conferir |
| --- | --- |
| <code>azmuth</code> não encontrado | Confira o link <code>~/.local/bin/azmuth</code>, o <code>PATH</code> e abra outro terminal. |
| Falha ao achar Python | Confira se <code>.venv/bin/python</code> existe e se PyYAML foi instalado nesse ambiente. |
| Barra/HUD não aparece | Rode <code>azmuth doctor</code>; confira Quickshell e <code>PROJECT</code> em <code>hypr/azmuth.lua</code>; depois <code>azmuth send</code>. |
| <code>hl</code> ou <code>require("azmuth")</code> falha | A integração exige configuração Lua e API Lua do Hyprland; confira <code>hyprctl configerrors</code>. |
| Wi-Fi vazio | Confira NetworkManager e se outro gerenciador não disputa o dispositivo. |
| Som caiu em Dummy Output | Rode <code>azmuth audio</code>. Se ele apontar um app usando ALSA diretamente, feche-o ou mude-o para PipeWire; depois confira <code>azmuth audio status</code>. |
| Sem notificações | Rode <code>azmuth send</code> e confira o dono D-Bus de <code>org.freedesktop.Notifications</code>. |
| Wallpaper não muda | Confira Hyprpaper e o caminho definido no DNA. |
| Calendário não avisa | Confira se Context Engine está ativo e valide data/hora/lembrete. |
| Assistente não responde | Rode <code>azmuth ask --status</code>; confira <code>systemctl status ollama</code> e instale o modelo com <code>ollama pull qwen3.5:4b</code>. O comando <code>azmuth doctor</code> não verifica o serviço de IA. |

Comandos úteis:

    azmuth doctor
    azmuth doctor --json
    azmuth audio
    azmuth audio status
    azmuth send
    hyprctl configerrors
    wpctl status
    nmcli general status

## Manter a documentação junto com a rice

Quando uma alteração muda uso ou instalação, atualize a documentação correspondente no mesmo conjunto de mudanças:

1. Atalho ou fluxo novo: atualize <code>README.md</code>, <code>docs/MANUAL.md</code> e <code>docs/manual.html</code>.
2. Configuração nova: inclua aqui localização, padrão, tipos/limites, efeito, quando passa a valer e restauração.
3. Campo de DNA novo/alterado: atualize <code>docs/DNA_Schema_Spec.md</code> e os exemplos.
4. Recurso com instruções próprias: atualize <code>filemanager/README.md</code> ou <code>taskmanager/README.md</code>.
5. Dependência, integração ou serviço novo: atualize dependências, instalação e diagnóstico deste guia.

O README apresenta o projeto, o manual ensina a usar e este guia explica como instalar, configurar e adaptar cada parte.
