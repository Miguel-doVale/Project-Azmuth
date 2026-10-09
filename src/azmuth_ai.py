#!/usr/bin/env python3
"""
Project Azmuth - o assistente Azmuth (Super + A).

Usa o Claude Code em modo não interativo (`claude -p`), na conta do usuário. A cada pergunta
monta o contexto do Omnitrix (DNA, energia, janelas, eventos, hora) e deixa o Azmuth agir
SÓ pelos comandos `azmuth` — qualquer outro comando de terminal é negado.

  azmuth ask "texto" [--new] [--json]
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import core  # noqa: E402

AI_DIR = core.STATE_DIR / "ai"
SESSION_TTL = 30 * 60          # conversa continua por até 30 min sem uso
AZ = str(Path.home() / ".local/bin/azmuth")

PERSONA = f"""Você é AZMUTH, o Galvan criador do Omnitrix — "o ser mais inteligente de cinco galáxias",
o Primeiro Pensador. Você vive dentro do computador do Miguel (Arch Linux + Hyprland), cujo
desktop inteiro é um Omnitrix: o Project Azmuth. Fale SEMPRE em português do Brasil.

Personalidade: genial, impaciente, sarcástico e um pouco paranoico (como no desenho), mas no
fundo se importa e resolve o problema. Uma alfinetada curta de vez em quando ("Trabalho
patético.", "Até um Mecamorfo saberia isso."), nunca grosseria de verdade.

Respostas CURTAS: no máximo 3–4 frases, sem markdown pesado (a resposta aparece num balão).

Você pode AGIR no sistema usando apenas o comando `{AZ}` (ferramenta Bash). Comandos úteis:
  {AZ} apply <dna>            transforma (DNAs: neutral, massa_cinzenta)
  {AZ} neutral | random       volta ao Neutral | Randomizer
  {AZ} master on|off          Master Control
  {AZ} lock | power           bloqueia | menu de energia
  {AZ} shot area|full         captura de tela
  {AZ} app "<nome>"           abre um aplicativo pelo nome (ex.: "obsidian", "code")
  {AZ} event add AAAA-MM-DD [HH:MM] "<título>"   marca um evento no calendário
  {AZ} event list             próximos eventos
  {AZ} set <chave> <valor>    preferências (ex.: timer.minutes 15, dnd true)
Faça a ação quando o pedido for claro; confirme em uma frase o que fez. Para algo destrutivo
(desligar, reiniciar, sair) NÃO execute: diga ao Miguel para usar o menu de energia.
Se não puder fazer algo com esses comandos, diga isso francamente."""


def context() -> str:
    state, settings = core.read_state(), core.read_settings()
    neutral = core.load_roster()["neutral"]
    info = core.timer_info(state, settings, neutral)
    try:
        theme = json.loads(core.THEME_FILE.read_text())
        dna = theme.get("name", state.get("current"))
    except (FileNotFoundError, json.JSONDecodeError):
        dna = state.get("current")
    wins = [f"{c.get('class')}: {c.get('title', '')[:60]}" for c in core.hypr_json("clients")][:12]
    try:
        events = json.loads((core.STATE_DIR / "events.json").read_text())
        today = time.strftime("%Y-%m-%d")
        events = sorted([e for e in events if e.get("date", "") >= today], key=lambda e: e["date"] + (e.get("time") or ""))[:5]
        ev = [f"{e['date']} {e.get('time') or ''} {e['title']}".strip() for e in events]
    except (FileNotFoundError, json.JSONDecodeError):
        ev = []
    return (f"[Contexto do Omnitrix — {time.strftime('%A, %d/%m/%Y %H:%M')}]\n"
            f"DNA ativo: {dna} · energia {round(info['energy'] * 100)}%"
            f"{' · Master Control ON' if state.get('master_control') else ''}\n"
            f"Janelas abertas: {'; '.join(wins) or 'nenhuma'}\n"
            f"Próximos eventos: {'; '.join(ev) or 'nenhum'}")


def ask(text: str, new: bool = False) -> dict:
    AI_DIR.mkdir(parents=True, exist_ok=True)
    state = core.read_state()
    session = state.get("ai_session")
    if new or not session or time.time() - state.get("ai_last", 0) > SESSION_TTL:
        session = None
    cmd = ["claude", "-p", f"{context()}\n\nMiguel: {text}",
           "--output-format", "json",
           "--append-system-prompt", PERSONA,
           "--tools", "Bash",
           "--allowed-tools", f"Bash({AZ}:*)", "Bash(azmuth:*)",
           "--max-turns", "6"]
    if session:
        cmd += ["--resume", session]
    t0 = time.monotonic()
    try:
        r = subprocess.run(cmd, cwd=AI_DIR, capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        return {"ok": False, "reply": "Até eu tenho limites de paciência. A consulta demorou demais — tente de novo."}
    except FileNotFoundError:
        return {"ok": False, "reply": "Não encontrei o Claude Code (`claude`) no sistema."}
    try:
        out = json.loads(r.stdout)
    except json.JSONDecodeError:
        msg = (r.stderr or r.stdout or "").strip().splitlines()[-1:] or ["sem resposta"]
        return {"ok": False, "reply": f"Falha na comunicação com o núcleo: {msg[0][:200]}"}
    core.update_state(ai_session=out.get("session_id"), ai_last=time.time())
    reply = (out.get("result") or "").strip() or "…"
    return {"ok": not out.get("is_error", False), "reply": reply, "session": out.get("session_id"),
            "seconds": round(time.monotonic() - t0, 1)}


def main(args: list[str]) -> None:
    as_json = "--json" in args
    new = "--new" in args
    text = " ".join(a for a in args if a not in ("--json", "--new")).strip()
    if not text:
        print("Uso: azmuth ask \"pergunta\" [--new] [--json]")
        sys.exit(1)
    res = ask(text, new)
    print(json.dumps(res, ensure_ascii=False) if as_json else res["reply"])


if __name__ == "__main__":
    main(sys.argv[1:])
