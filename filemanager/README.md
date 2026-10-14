# Dolphin · Project Azmuth

O Dolphin recebe a paleta do DNA ativo e uma interface discreta: abas visíveis,
caminho completo, controles de prévia/dois painéis e ações para projetos.

## Uso

- `Super+E`: abre o Dolphin no tema atual.
- `azmuth files projetos`: abre a pasta de projetos.
- `azmuth files azmuth`: abre o repositório.
- `azmuth files imagens`: abre Imagens.
- `azmuth files --split projetos downloads`: abre duas pastas lado a lado.
- Clique direito numa pasta → **Azmuth · ferramentas** → terminal ou VS Code.

A instalação mantém as preferências e favoritos existentes. Pastas lembram seu
modo de exibição: use detalhes para código e ícones/prévias para imagens.

## Atalhos do Dolphin

| Atalho | Ação |
|---|---|
| Ctrl+1 / Ctrl+2 / Ctrl+3 | Ícones / compacto / detalhes |
| F3 | Dividir a janela |
| F4 | Terminal integrado |
| F11 | Painel de informação e prévia |
| Ctrl+I | Filtrar a pasta atual |
| Ctrl+L | Digitar caminho |
| Ctrl+T / Ctrl+W | Abrir / fechar aba |
| Alt+↑ | Pasta anterior no caminho |
| Alt+. | Mostrar arquivos ocultos |

## Cores e limites

O `core.py` prepara o esquema e o stylesheet a cada transformação. O
`azmuth files` lê o DNA atual ao abrir uma nova instância. Janelas já abertas
mantêm a paleta carregada; feche e reabra para atualizar. Nenhuma janela é
encerrada automaticamente.

As configurações de cores ficam só no Dolphin. Os favoritos são os Lugares
compartilhados dos aplicativos KDE. O tema usa Qt/Fusion disponível no sistema;
não precisa instalar KDE Plasma, Kvantum ou outro gerenciador de arquivos.

## Arquivos

- `src/file_manager.py`: instalação, cores, favoritos e ações.
- `filemanager/dolphin.qss.tmpl`: aparência dos controles.
- `filemanager/dolphinui.rc`: barra de ferramentas.
- `filemanager/azmuth-tools.desktop.tmpl`: ações do botão direito.
- `~/.local/share/color-schemes/AzmuthActive.colors`: paleta gerada.
- `~/.local/state/azmuth/dolphin.qss`: stylesheet gerado.
- `~/.local/state/azmuth/file-manager.json`: registro do backup.

Instalar: `azmuth files --setup`.
Desfazer as alterações da configuração: `azmuth files --restore`.
O backup fica em `~/.config/azmuth-backup-dolphin-<data>` e é preservado.

## Referências

Configuração e recursos: https://docs.kde.org/trunk_kf6/en/dolphin/dolphin/configuring-dolphin.html
Ações locais: https://develop.kde.org/docs/apps/dolphin/service-menus/

## Cores e marcadores por pasta

Clique direito numa pasta → **Azmuth · ferramentas → Personalizar pasta · cores e runas**.
Escolha qualquer cor no seletor ou por #RRGGBB. Cada clique numa runa adiciona um marcador;
também pode adicionar letras, números e textos. Arraste, ajuste tamanho/cor, troque a ordem
das camadas ou deixe só a runa sem fundo. A lista não tem um limite fixo de marcadores.
**Aplicar** grava; **Restaurar ícone** recupera o ícone anterior, preservando a configuração
de visualização da pasta.

A personalização usa a pasta oculta `.azmuth-folder` e o campo Icon do `.directory`.
O caminho é relativo: ao mover/copiar a pasta junto com os arquivos ocultos, o ícone acompanha.
A configuração de ícones agora usa prévias de 64px e legendas mais compactas.
