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
