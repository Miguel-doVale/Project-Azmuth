#!/usr/bin/env python3
"""Extrato bancário → lançamentos higienizados no cérebro. Python comum, SEM IA.

Cada linha vira só {date, valor, categoria, banco}: a descrição (nomes de pessoas, lojas) nunca sai
deste script. As regras de categoria ficam no vault (Finanças/categorias.json, restrita); o formato de
cada banco (só nomes de colunas, sem dado pessoal) fica no projeto, em data/bank_formats.json, e
Finanças/bancos.json pode sobrescrever.
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
    """Ganha o termo MAIS ESPECÍFICO (mais comprido) que aparece na descrição; empate fica com a
    categoria que vem antes. Assim "Mundo de coisas" vence "mercadinho" sem depender da ordem."""
    plain = _plain(description)
    best, best_len = "Outros", 0
    for category, terms in rules.items():
        for term in terms:
            t = _plain(term).strip()
            if t and t in plain and len(t) > best_len:
                best, best_len = category, len(t)
    return best


def iter_rows(path: Path, mapping: dict):
    """(data, valor, descrição) de cada linha válida do extrato. A descrição só existe aqui dentro."""
    try:
        text = Path(path).read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:            # muitos bancos exportam em Latin-1/cp1252
        text = Path(path).read_bytes().decode("cp1252", errors="strict")
    lines = text.splitlines()
    start = mapping.get("header_starts")          # extrato com resumo antes da tabela (ex.: Mercado Pago)
    if start:
        idx = next((i for i, l in enumerate(lines) if l.startswith(start)), None)
        if idx is None:
            return
        lines = lines[idx:]
    cols = mapping.get("description", "")
    cols = cols if isinstance(cols, list) else [cols]       # PicPay: tipo + origem/destino
    for line in csv.DictReader(lines, delimiter=mapping.get("delimiter", ",")):
        try:
            date = parse_date(line[mapping["date"]])
            value = parse_amount(line[mapping["amount"]])
        except (KeyError, ValueError, TypeError):
            continue                          # linha de saldo/cabeçalho repetido: ignora
        yield date, value, " ".join(line.get(c, "") or "" for c in cols).strip()


def ingest_csv(path: Path, bank: str, mapping: dict, rules: dict) -> list[dict]:
    return [{"date": d, "valor": v, "categoria": categorize(desc, rules), "banco": bank}
            for d, v, desc in iter_rows(path, mapping)]


def money(value: Decimal, symbol: bool = True) -> str:
    q = f"{abs(value):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    sign = "-" if value < 0 else ""
    return f"{sign}R$ {q}" if symbol else f"{sign}{q}"


def read_ledger(vault: Path) -> list[dict]:
    rows = []
    base = Path(vault) / LEDGER_DIR
    by_name = {p.name: p for p in sorted(base.glob("lancamentos-*.md"))}          # formato antigo (raiz)
    by_name.update({p.name: p for p in sorted(base.glob("[0-9][0-9][0-9][0-9]/lancamentos-*.md"))})  # por ano ganha
    for p in [by_name[n] for n in sorted(by_name)]:
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
        year_dir = folder / month[:4]                  # Finanças/AAAA/lancamentos-AAAA-MM.md
        year_dir.mkdir(exist_ok=True)
        path = year_dir / f"lancamentos-{month}.md"
        legacy = folder / path.name
        tmp = path.with_name("." + path.name + ".tmp")
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, path)
        if legacy.exists():                            # arquivo do formato antigo (raiz): já foi incorporado
            legacy.unlink()
        written.append(path)
    return written


# o dinheiro do Miguel mudando de lugar (cofrinho, conta → conta, fatura): fora de entradas/saídas
INTERNAL = ("Entre contas", "Pagamento de fatura")


def _report(rows: list[dict], title: str) -> str:
    internal = [r for r in rows if r["categoria"] in INTERNAL]
    rows = [r for r in rows if r["categoria"] not in INTERNAL]
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
    if internal:
        lines += ["", "Fora das somas (dinheiro seu mudando de lugar):"]
        for cat in INTERNAL:
            moved = [r["valor"] for r in internal if r["categoria"] == cat]
            if moved:
                out = sum((-v for v in moved if v < 0), Decimal(0))
                inn = sum((v for v in moved if v > 0), Decimal(0))
                lines.append(f"- {cat}: saiu {money(out)}, voltou {money(inn)}")
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


CATEGORY_DEFAULTS = Path(__file__).resolve().parent.parent / "data/categories_default.json"
BANK_FORMATS = Path(__file__).resolve().parent.parent / "data/bank_formats.json"


def load_rules(vault: Path) -> dict:
    """As regras do vault (pessoais, ex.: o próprio nome em "Entre contas") vêm primeiro e ganham;
    as genéricas do projeto (lojas conhecidas, cofrinho…) completam, somando termos por categoria."""
    try:
        defaults = json.loads(CATEGORY_DEFAULTS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        defaults = {}
    rules: dict[str, list] = {}
    for source in (_json(vault, "categorias.json"), defaults):
        for cat, terms in source.items():
            if isinstance(terms, list):
                rules.setdefault(cat, [])
                rules[cat] += [t for t in terms if isinstance(t, str) and t not in rules[cat]]
    return rules


def load_banks(vault: Path) -> dict:
    """Formatos conhecidos (nomes de colunas, sem dado pessoal) vêm do projeto; Finanças/bancos.json
    no vault só sobrescreve ou acrescenta."""
    try:
        known = json.loads(BANK_FORMATS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        known = {}
    return {**known, **_json(vault, "bancos.json")}
