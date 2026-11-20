#!/usr/bin/env python3
"""Extrato bancário → lançamentos higienizados no cérebro. Python comum, SEM IA.

Cada linha vira só {date, valor, categoria, banco}: a descrição (nomes de pessoas, lojas) nunca sai
deste script. As regras de categoria e o formato de cada banco ficam no próprio vault, em notas
restritas: Finanças/categorias.json ({"Mercado": ["assai", ...]}) e Finanças/bancos.json
({"Nubank": {"date": "Data", "amount": "Valor", "description": "Descrição", "delimiter": ","}}).
Os formatos reais dos bancos entram quando o Miguel mandar um extrato de exemplo de cada.
"""

import csv
import datetime as dt
import json
import os
import re
import unicodedata
from decimal import Decimal, InvalidOperation
from pathlib import Path

LEDGER_DIR = "Finanças"
SAFE_NAME = re.compile(r"[\w .()&+-]{1,60}")
HEADER = "| data | valor | categoria | banco |\n|---|---|---|---|\n"


def _plain(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", str(text).lower()) if not unicodedata.combining(c))


def parse_amount(text: str) -> Decimal:
    raw = str(text).strip().replace("\u2212", "-")            # menos tipográfico
    if not re.fullmatch(r"[-+()R$\s\d.,]*\d[\d.,\s]*\)?\s*[DCdc]?", raw):
        raise ValueError(f"valor inválido: {text!r}")
    first = re.search(r"\d", raw).start()
    negative = "-" in raw[:first] or raw.rstrip(" )").endswith("-") or raw.startswith("(") \
        or raw.rstrip().upper().endswith("D")
    digits = re.sub(r"[^\d,.]", "", raw)
    if digits.count(",") > 1:
        raise ValueError(f"valor inválido: {text!r}")
    if "," in digits:                         # formato brasileiro: 1.234,56
        digits = digits.replace(".", "").replace(",", ".")
    elif digits.count(".") > 1:               # 1.234.567 sem centavos
        digits = digits.replace(".", "")
    try:
        value = Decimal(digits)
    except InvalidOperation:
        raise ValueError(f"valor inválido: {text!r}") from None
    return -value if negative else value


def parse_date(text: str) -> str:
    raw = str(text).strip()[:10]
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y"):
        try:
            return dt.datetime.strptime(raw, fmt).date().isoformat()
        except ValueError:
            continue
    raise ValueError(f"data inválida: {text!r}")


def categorize(description: str, rules: dict) -> str:
    plain = _plain(description)
    for category, terms in rules.items():
        if any(_plain(term) in plain for term in terms if str(term).strip()):
            return category
    return "Outros"


def ingest_csv(path: Path, bank: str, mapping: dict, rules: dict) -> list[dict]:
    try:
        text = Path(path).read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:            # muitos bancos exportam em Latin-1/cp1252
        text = Path(path).read_bytes().decode("cp1252", errors="strict")
    rows = []
    for line in csv.DictReader(text.splitlines(), delimiter=mapping.get("delimiter", ",")):
        try:
            date = parse_date(line[mapping["date"]])
            value = parse_amount(line[mapping["amount"]])
        except (KeyError, ValueError, TypeError):
            continue                          # linha de saldo/cabeçalho repetido: ignora
        category = categorize(line.get(mapping.get("description", ""), "") or "", rules)
        rows.append({"date": date, "valor": value, "categoria": category, "banco": bank})
    return rows


def money(value: Decimal, symbol: bool = True) -> str:
    q = f"{abs(value):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    sign = "-" if value < 0 else ""
    return f"{sign}R$ {q}" if symbol else f"{sign}{q}"


def read_ledger(vault: Path) -> list[dict]:
    rows = []
    for p in sorted((Path(vault) / LEDGER_DIR).glob("lancamentos-*.md")):
        for line in p.read_text(encoding="utf-8").splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) != 4 or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", cells[0]):
                continue
            rows.append({"date": cells[0], "valor": parse_amount(cells[1]), "categoria": cells[2], "banco": cells[3]})
    return rows


def write_ledger(rows: list[dict], vault: Path | None = None) -> list[Path]:
    """Um arquivo por mês. Um extrato substitui, daquele banco, só as linhas do PERÍODO que ele cobre
    (da 1ª à última data dele): reimportar não duplica, compras iguais no mesmo dia ficam, e dois
    extratos do mesmo mês (semanas, conta + cartão em datas diferentes) não se apagam."""
    for r in rows:
        if not SAFE_NAME.fullmatch(r["banco"]) or not SAFE_NAME.fullmatch(r["categoria"]):
            raise ValueError(f"nome inválido em banco/categoria: {r['banco']!r}/{r['categoria']!r}")
    if vault is None:
        import brain
        vault = brain.vault_path()
    folder = Path(vault) / LEDGER_DIR
    folder.mkdir(parents=True, exist_ok=True)
    existing = read_ledger(vault)
    by_month: dict[str, list[dict]] = {}
    for r in rows:
        by_month.setdefault(r["date"][:7], []).append(r)
    written = []
    span = {}
    for r in rows:
        lo, hi = span.get(r["banco"], (r["date"], r["date"]))
        span[r["banco"]] = (min(lo, r["date"]), max(hi, r["date"]))

    def covered(r):
        lo_hi = span.get(r["banco"])
        return bool(lo_hi) and lo_hi[0] <= r["date"] <= lo_hi[1]

    for month, new in sorted(by_month.items()):
        keep = [r for r in existing if r["date"][:7] == month and not covered(r)]
        merged = sorted(keep + new, key=lambda r: (r["date"], r["banco"]))
        body = "".join(f"| {r['date']} | {money(r['valor'], symbol=False)} | {r['categoria']} | {r['banco']} |\n"
                       for r in merged)
        text = (f"---\nresumo: Lançamentos de {month} (gerado do extrato, sem descrições)\nacesso: financas\n---\n"
                f"# Lançamentos {month}\n\n{HEADER}{body}")
        path = folder / f"lancamentos-{month}.md"
        tmp = path.with_name("." + path.name + ".tmp")
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, path)
        written.append(path)
    return written


def _report(rows: list[dict], title: str) -> str:
    income = sum((r["valor"] for r in rows if r["valor"] > 0), Decimal(0))
    spent = sum((-r["valor"] for r in rows if r["valor"] < 0), Decimal(0))
    cats: dict[str, Decimal] = {}
    banks: dict[str, Decimal] = {}
    for r in rows:
        if r["valor"] < 0:
            cats[r["categoria"]] = cats.get(r["categoria"], Decimal(0)) - r["valor"]
        banks[r["banco"]] = banks.get(r["banco"], Decimal(0)) + r["valor"]
    lines = [title, f"Entradas: {money(income)}", f"Saídas: {money(spent)}", f"Saldo: {money(income - spent)}",
             "", "Saídas por categoria:"]
    lines += [f"- {c}: {money(v)}" for c, v in sorted(cats.items(), key=lambda kv: -kv[1])]
    lines += ["", "Movimento por banco:"] + [f"- {b}: {money(v)}" for b, v in sorted(banks.items())]
    return "\n".join(lines)


def monthly_report(rows: list[dict], month: str) -> str:
    return _report([r for r in rows if r["date"][:7] == month], f"Relatório de {month}")


def yearly_report(rows: list[dict], year: str) -> str:
    return _report([r for r in rows if r["date"][:4] == year], f"Relatório de {year}")


def _json(vault: Path, name: str) -> dict:
    try:
        data = json.loads((Path(vault) / LEDGER_DIR / name).read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def load_rules(vault: Path) -> dict:
    return _json(vault, "categorias.json")


def load_banks(vault: Path) -> dict:
    return _json(vault, "bancos.json")
