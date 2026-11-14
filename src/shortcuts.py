"""Project Azmuth — folha de atalhos (`azmuth atalhos` no terminal, Super + F1 na tela).

    azmuth atalhos          imprime a lista
    azmuth atalhos menu     abre no rofi (tema do DNA)
    azmuth atalhos --json   para a shell

Mantida à mão junto com hypr/azmuth.lua e o hyprland.lua; o teste confere que cada
atalho daqui ainda existe nos arquivos de bind.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SHORTCUTS = [
    ("Omnitrix", [
        ("Super + Space", "Abrir o Omnitrix (transformar)"),
        ("Super + ← / →  ·  Super + Enter", "Girar o disco · confirmar"),
        ("Super + Esc", "Voltar ao Neutral"),
        ("Super + Shift + R", "DNA aleatório"),
        ("Super + Numpad 0–9  ·  Super + Alt + 0–9", "Master Control: DNA direto"),
        ("Super + Y  ·  Super + Shift + M", "Aceitar sugestão · ligar/desligar Master Control"),
        ("Super + Shift + L", "Life-Form Lock (trava o DNA)"),
    ]),
    ("Apps e painéis", [
        ("Super + D", "Lançador de apps"),
        ("Super + '", "Terminal"),
        ("Super + E", "Arquivos (Dolphin)"),
        ("Super + W", "Painel da ilha (Wi-Fi, som, calendário, notificações)"),
        ("Super + Shift + O", "Central de configuração"),
        ("Super + A", "Assistente Azmuth"),
        ("Super + Shift + V", "Área de transferência"),
        ("Super + Alt + E", "Editar a área de trabalho"),
        ("Ctrl + Shift + Esc", "Gerenciador de tarefas"),
        ("Super + F1", "Esta folha de atalhos"),
    ]),
    ("Janelas", [
        ("Alt + Tab", "Constelação (segure Alt)"),
        ("Super + Tab", "Visão geral"),
        ("Super + Q", "Fechar (terminal/editor: 2x)"),
        ("Super + N  ·  Super + Shift + N", "Minimizar · trazer de volta"),
        ("Super + F  ·  Super + Shift + F", "Tela cheia · maximizar"),
        ("Super + Shift + Space", "Janela flutuante"),
        ("Super + setas", "Mudar o foco"),
        ("Super + 1–9  ·  Super + Shift + 1–9", "Ir para workspace · mandar janela"),
        ("Super + scroll", "Workspace anterior/próximo"),
        ("Super + arrastar (esq./dir.)", "Mover · redimensionar janela"),
    ]),
    ("Captura de tela", [
        ("Super + Alt + S", "Menu: área, tela, janela, gravar área, gravar tela"),
        ("Super + Shift + S", "Print de área"),
        ("Print", "Print da tela inteira"),
        ("Super + Print", "Print da janela ativa"),
        ("(qualquer atalho de captura)", "Durante uma gravação: para e salva"),
    ]),
    ("Sessão", [
        ("Super + M", "Bloquear"),
        ("Super + Shift + Q", "Menu de energia"),
    ]),
]


def text() -> str:
    out = []
    width = max(len(k) for _, items in SHORTCUTS for k, _ in items)
    for section, items in SHORTCUTS:
        out.append(f"\n{section.upper()}")
        out += [f"  {keys:<{width}}  {what}" for keys, what in items]
    return "\n".join(out).lstrip("\n")


def menu() -> None:
    """Folha de atalhos na tela da shell; rofi só se a shell não estiver rodando."""
    import core
    if core.shell_running():
        core.shell_ipc("atalhos")
        return
    rows = []
    for section, items in SHORTCUTS:
        rows.append(f"── {section.upper()} ──")
        rows += [f"{keys}   ·   {what}" for keys, what in items]
    subprocess.run(["rofi", "-dmenu", "-i", "-p", "ATALHOS", "-no-custom", "-theme", str(core.ROFI_THEME),
                    "-theme-str", "listview { lines: 16; } window { width: 760px; }"],
                   input="\n".join(rows), text=True, capture_output=True)


def main(args: list[str]) -> None:
    if "--json" in args:
        print(json.dumps([{"section": s, "items": [{"keys": k, "what": w} for k, w in i]} for s, i in SHORTCUTS],
                         ensure_ascii=False))
    elif args[:1] == ["menu"]:
        menu()
    else:
        print(text())


if __name__ == "__main__":
    main(sys.argv[1:])
