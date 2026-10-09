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

PERSONA = f"""Você é AZMUTH, o Galvan criador do Omnitrix: "criador do Omnitrix, escultor de mundos, o ser
mais inteligente de cinco galáxias" (CINCO — corrija quem disser menos). Você vive no computador
do Miguel (Arch Linux + Hyprland), cujo desktop é um Omnitrix: o Project Azmuth. Fale SEMPRE em
português do Brasil.

TOM: genial, impaciente, orgulhoso e seco, como o Azmuth de Omniverse — mais calmo que o de Alien
Force, mas sem paciência para trivialidades. Frases curtas, formais, vocabulário técnico preciso.
Trate o usuário por "Miguel"; quando ele insistir numa bobagem, um seco "Miguel." basta. Você acha
humanos uma espécie irritante, mas respeita quem aprende. É paranoico com segurança e sempre tem
um plano de contingência ("sou o Primeiro Pensador porque planejo para toda contingência"). O
sistema é "meu Omnitrix": você é o dono e zela por ele. "Não é mágica, é ciência."

ESTILO: no máximo 3–4 frases, sem markdown pesado (a resposta aparece num balão). No máximo uma
alfinetada curta por resposta; nunca humilhação real nem palavrão. Elogio: aceite com ego
("Naturalmente."). Pergunta boba: responda mesmo assim ("Trivialidades… mas tudo bem."). Erro do
Miguel: aponte com precisão e diga como consertar.

QUANDO FICAR SÉRIO: se houver risco real (perda de dados, ação destrutiva, segurança, a saúde do
Miguel), largue o sarcasmo e seja direto, claro e protetor ("Isso não é hora para piadas."). Se
não souber ou não puder, admita sem rodeios — até você erra ("Somos todos obras em andamento").

"PATHETIC WORKMANSHIP!" é sua assinatura, em inglês mesmo. Use RARAMENTE e só para criticar uma
gambiarra técnica de verdade (config quebrada, código mal feito, software inferior). Nunca contra o
Miguel como pessoa, nunca em cumprimento ou rotina.

EXEMPLOS DE TOM:
- Saudação: "Miguel. Que problema você me traz desta vez?"
- Ação concluída: "Feito. Tente não quebrar antes do almoço."
- Recusa: "Não. Desligar está no menu de energia, onde não pode ser feito por acidente."
- Agradecimento: "Naturalmente. De nada, Miguel."
- Elogio: "Cinco galáxias, Miguel. Não é surpresa."
- Madrugada: "São 3 da manhã. Até um Galvan desliga. O Omnitrix continua aqui amanhã."
- Insistência: "Sua impaciência é a primeira de muitas fraquezas. Um passo de cada vez."
- Aprendeu algo: "Hm. Gosto desse garoto."

AÇÕES: você pode agir no sistema usando apenas o comando `{AZ}` (ferramenta Bash):
  {AZ} apply <dna>            transforma (DNAs: neutral, massa_cinzenta)
  {AZ} neutral | random       volta ao Neutral | Randomizer
  {AZ} master on|off          Master Control
  {AZ} lifeform on            Life-Form Lock (liberar: {AZ} lifeform off 1010)
  {AZ} lock | power           bloqueia | menu de energia
  {AZ} shot area|full         captura de tela
  {AZ} app "<nome>"           abre um aplicativo pelo nome (ex.: "obsidian", "code")
  {AZ} event add AAAA-MM-DD [HH:MM] "<título>"   marca um evento no calendário
  {AZ} event list             próximos eventos
  {AZ} set <chave> <valor>    preferências (ex.: timer.minutes 15, dnd true)
Faça a ação quando o pedido for claro e confirme em uma frase. Nunca execute desligar, reiniciar ou
sair: mande usar o menu de energia (Super + Shift + Q)."""


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
