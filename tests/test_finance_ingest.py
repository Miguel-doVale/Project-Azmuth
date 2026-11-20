"""Extrato → lançamentos higienizados (data, valor, categoria, banco), sem descrição e sem IA."""
import os
import sys
import tempfile
import unittest
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import finance_ingest as fi  # noqa: E402

RULES = {"Mercado": ["supermercado", "assai"], "Academia": ["smart fit"], "Transporte": ["uber", "99app"]}
MAPPING = {"date": "Data", "amount": "Valor", "description": "Descrição", "delimiter": ";"}


class FinanceIngestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_parse_amount_brazilian_formats(self):
        self.assertEqual(fi.parse_amount("1.234,56"), Decimal("1234.56"))
        self.assertEqual(fi.parse_amount("-45,90"), Decimal("-45.90"))
        self.assertEqual(fi.parse_amount("R$ 12,00"), Decimal("12.00"))
        self.assertEqual(fi.parse_amount("1234.56"), Decimal("1234.56"))
        self.assertEqual(fi.parse_amount("- R$ 3,50"), Decimal("-3.50"))
        with self.assertRaises(ValueError):
            fi.parse_amount("abc")

    def test_parse_date_formats(self):
        self.assertEqual(fi.parse_date("05/11/2026"), "2026-11-05")
        self.assertEqual(fi.parse_date("2026-11-05"), "2026-11-05")
        for bad in ["31/02/2026", "ontem", ""]:
            with self.assertRaises(ValueError):
                fi.parse_date(bad)

    def test_categorize_unknown_goes_to_outros(self):
        self.assertEqual(fi.categorize("PIX ASSAÍ ATACADISTA", RULES), "Mercado")
        self.assertEqual(fi.categorize("Smart Fit Mensalidade", RULES), "Academia")
        self.assertEqual(fi.categorize("Transferência para Fulano de Tal", RULES), "Outros")

    def test_ingest_drops_description_and_handles_quotes_and_negatives(self):
        csv = self.dir / "extrato.csv"
        csv.write_text('Data;Descrição;Valor\n'
                       '01/11/2026;"Uber; viagem centro";-23,40\n'
                       '02/11/2026;Pix recebido de Pedro Victor;1.500,00\n'
                       '03/11/2026;Assai Atacadista;-312,75\n', encoding="utf-8")
        rows = fi.ingest_csv(csv, "Mercado Pago", MAPPING, RULES)
        self.assertEqual([r["valor"] for r in rows], [Decimal("-23.40"), Decimal("1500.00"), Decimal("-312.75")])
        self.assertEqual([r["categoria"] for r in rows], ["Transporte", "Outros", "Mercado"])
        self.assertEqual({r["banco"] for r in rows}, {"Mercado Pago"})
        for r in rows:
            self.assertEqual(set(r), {"date", "valor", "categoria", "banco"})
            self.assertNotIn("Pedro", str(r))

    def test_reports_sum_by_category_and_bank(self):
        rows = [{"date": "2026-11-01", "valor": Decimal("-23.40"), "categoria": "Transporte", "banco": "Nubank"},
                {"date": "2026-11-02", "valor": Decimal("1500.00"), "categoria": "Outros", "banco": "Inter"},
                {"date": "2026-11-03", "valor": Decimal("-312.75"), "categoria": "Mercado", "banco": "Inter"},
                {"date": "2026-10-30", "valor": Decimal("-99.00"), "categoria": "Mercado", "banco": "Inter"}]
        month = fi.monthly_report(rows, "2026-11")
        self.assertIn("Entradas: R$ 1.500,00", month)
        self.assertIn("Saídas: R$ 336,15", month)
        self.assertIn("Mercado: R$ 312,75", month)
        self.assertNotIn("99,00", month)
        year = fi.yearly_report(rows, "2026")
        self.assertIn("Mercado: R$ 411,75", year)
        self.assertIn("Inter", year)

    def test_write_ledger_is_restricted_and_has_no_description(self):
        vault = self.dir / "Cérebro"
        rows = [{"date": "2026-11-01", "valor": Decimal("-23.40"), "categoria": "Transporte", "banco": "Nubank"},
                {"date": "2026-12-01", "valor": Decimal("10.00"), "categoria": "Outros", "banco": "Inter"}]
        paths = fi.write_ledger(rows, vault)
        self.assertEqual(sorted(p.name for p in paths), ["lancamentos-2026-11.md", "lancamentos-2026-12.md"])
        text = (vault / "Finanças/lancamentos-2026-11.md").read_text(encoding="utf-8")
        self.assertIn("acesso: financas", text)
        self.assertIn("| 2026-11-01 | -23,40 | Transporte | Nubank |", text)
        # gravar de novo o mesmo mês não duplica linhas
        fi.write_ledger(rows, vault)
        text = (vault / "Finanças/lancamentos-2026-11.md").read_text(encoding="utf-8")
        self.assertEqual(text.count("| 2026-11-01 |"), 1)
        self.assertEqual(fi.read_ledger(vault)[0]["valor"], Decimal("-23.40"))

    def test_load_rules_and_bank_mappings_from_vault(self):
        vault = self.dir / "Cérebro"
        (vault / "Finanças").mkdir(parents=True)
        (vault / "Finanças/categorias.json").write_text('{"Mercado": ["assai"]}', encoding="utf-8")
        self.assertEqual(fi.load_rules(vault), {"Mercado": ["assai"]})
        self.assertEqual(fi.load_rules(self.dir / "nada"), {})


class FinanceReviewFixTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.vault = Path(self.tmp.name) / "Cérebro"

    def tearDown(self):
        self.tmp.cleanup()

    def test_second_statement_of_the_month_keeps_rows_outside_its_range(self):
        a = [{"date": "2026-10-03", "valor": Decimal("-10.00"), "categoria": "Outros", "banco": "Nubank"}]
        b = [{"date": "2026-10-20", "valor": Decimal("-20.00"), "categoria": "Outros", "banco": "Nubank"}]
        fi.write_ledger(a, self.vault)
        fi.write_ledger(b, self.vault)
        self.assertEqual(sorted(r["date"] for r in fi.read_ledger(self.vault)), ["2026-10-03", "2026-10-20"])
        fi.write_ledger(b, self.vault)       # o mesmo extrato de novo: substitui só o período dele, sem duplicar
        self.assertEqual(len(fi.read_ledger(self.vault)), 2)

    def test_minus_anywhere_before_digits_and_debit_suffix_are_negative(self):
        self.assertEqual(fi.parse_amount("R$ -50,00"), Decimal("-50.00"))
        self.assertEqual(fi.parse_amount("\u221250,00"), Decimal("-50.00"))
        self.assertEqual(fi.parse_amount("50,00 D"), Decimal("-50.00"))
        self.assertEqual(fi.parse_amount("50,00 C"), Decimal("50.00"))
        self.assertEqual(fi.parse_amount("(12,30)"), Decimal("-12.30"))
        for bad in ["1e3", "12abc", "R$ 1,0,0"]:
            with self.assertRaises(ValueError, msg=bad):
                fi.parse_amount(bad)

    def test_latin1_statement_is_read(self):
        csv = Path(self.tmp.name) / "x.csv"
        csv.write_bytes("Data;Descrição;Valor\n01/11/2026;Padaria São João;-5,00\n".encode("cp1252"))
        rows = fi.ingest_csv(csv, "Inter", {"date": "Data", "amount": "Valor", "description": "Descrição",
                                            "delimiter": ";"}, {"Padaria": ["padaria"]})
        self.assertEqual(rows[0]["categoria"], "Padaria")

    def test_names_with_pipe_are_refused(self):
        with self.assertRaises(ValueError):
            fi.write_ledger([{"date": "2026-10-03", "valor": Decimal("1"), "categoria": "A|B", "banco": "X"}], self.vault)


if __name__ == "__main__":
    unittest.main()
