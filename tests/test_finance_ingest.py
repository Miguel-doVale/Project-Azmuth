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
        self.assertEqual(fi.load_rules(vault)["Mercado"], ["assai"])
        self.assertIn("Jantares", fi.load_rules(self.dir / "nada"))   # padrão do projeto


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


class MercadoPagoFormatTests(unittest.TestCase):
    def test_statement_with_summary_before_the_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / "mp.csv"
            f.write_text("INITIAL_BALANCE;CREDITS;DEBITS;FINAL_BALANCE\n0,82;4,01;-3,50;1,33\n\n"
                         "RELEASE_DATE;TRANSACTION_TYPE;REFERENCE_ID;TRANSACTION_NET_AMOUNT;PARTIAL_BALANCE\n"
                         "02-11-2026;Pagamento iFood;187435954400;-3,50;1,32\n"
                         "03-11-2026;Rendimentos;187435299298;1.200,00;1.201,32\n", encoding="utf-8")
            mapping = {"header_starts": "RELEASE_DATE", "date": "RELEASE_DATE", "amount": "TRANSACTION_NET_AMOUNT",
                       "description": "TRANSACTION_TYPE", "delimiter": ";"}
            rows = fi.ingest_csv(f, "Mercado Pago", mapping, {"Alimentação": ["ifood"]})
        self.assertEqual([(r["date"], r["valor"], r["categoria"]) for r in rows],
                         [("2026-11-02", Decimal("-3.50"), "Alimentação"), ("2026-11-03", Decimal("1200.00"), "Outros")])


class BankFormatTests(unittest.TestCase):
    def test_known_bank_formats_ship_with_the_project_and_vault_overrides(self):
        with tempfile.TemporaryDirectory() as tmp:
            vault = Path(tmp)
            banks = fi.load_banks(vault)
            self.assertEqual(banks["Nubank"]["delimiter"], ",")
            self.assertEqual(banks["Mercado Pago"]["header_starts"], "RELEASE_DATE")
            (vault / "Finanças").mkdir()
            (vault / "Finanças/bancos.json").write_text('{"Nubank": {"date": "D", "amount": "V", "delimiter": ";"}}',
                                                        encoding="utf-8")
            self.assertEqual(fi.load_banks(vault)["Nubank"]["delimiter"], ";")


class PicPayAndInternalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_picpay_signed_values_and_two_description_columns(self):
        f = self.dir / "picpay.csv"
        f.write_text('data,hora,tipo,"origem / destino",valor,"forma de pagamento"\n'
                     '2026-11-19,17:22,Pix recebido,Fulano de Tal,+R$ 4,00,\n'.replace("+R$ 4,00", '"+R$ 4,00"') +
                     '2026-11-18,18:47,Compra realizada,IFOOD *LOJA,"\u2212R$ 32,90",Com cart\u00e3o\n'
                     '2026-11-17,10:00,Dinheiro guardado,Cofrinho,"\u2212R$ 80,00",\n', encoding="utf-8")
        mapping = {"date": "data", "amount": "valor", "description": ["tipo", "origem / destino"], "delimiter": ","}
        rules = {"Entre contas": ["dinheiro guardado"], "Jantares": ["ifood"]}
        rows = fi.ingest_csv(f, "PicPay", mapping, rules)
        self.assertEqual([(r["valor"], r["categoria"]) for r in rows],
                         [(Decimal("4.00"), "Outros"), (Decimal("-32.90"), "Jantares"), (Decimal("-80.00"), "Entre contas")])

    def test_internal_moves_stay_out_of_income_and_spending(self):
        rows = [{"date": "2026-11-01", "valor": Decimal("-80.00"), "categoria": "Entre contas", "banco": "PicPay"},
                {"date": "2026-11-02", "valor": Decimal("80.00"), "categoria": "Entre contas", "banco": "PicPay"},
                {"date": "2026-11-03", "valor": Decimal("-10.00"), "categoria": "Jantares", "banco": "PicPay"}]
        rep = fi.monthly_report(rows, "2026-11")
        self.assertIn("Entradas: R$ 0,00", rep)
        self.assertIn("Saídas: R$ 10,00", rep)
        self.assertIn("Entre contas", rep)            # aparece, mas à parte
        self.assertNotIn("- Entre contas: R$ 80,00\n- Jantares", rep)

    def test_default_rules_ship_with_project_and_vault_extends(self):
        vault = self.dir / "Cérebro"
        (vault / "Finanças").mkdir(parents=True)
        (vault / "Finanças/categorias.json").write_text('{"Entre contas": ["Miguel Teste"], "Pets": ["petz"]}',
                                                       encoding="utf-8")
        rules = fi.load_rules(vault)
        self.assertEqual(list(rules)[0], "Entre contas")            # vem primeiro: ganha de Investimentos
        self.assertIn("dinheiro guardado", rules["Entre contas"])
        self.assertIn("Miguel Teste", rules["Entre contas"])
        self.assertIn("ifood", rules["Jantares"])
        self.assertEqual(rules["Pets"], ["petz"])


class MostSpecificRuleTests(unittest.TestCase):
    def test_longest_matching_term_wins_regardless_of_order(self):
        rules = {"Mercadinho": ["mercadinho"], "Compras": ["compra"], "Alimentação": ["mundo de coisas"]}
        self.assertEqual(fi.categorize("Compra realizada MERCADINHO MUNDO DE COISAS", rules), "Alimentação")
        self.assertEqual(fi.categorize("Compra realizada Mercadinho do Zé", rules), "Mercadinho")
        self.assertEqual(fi.categorize("Compra realizada Loja X", rules), "Compras")
        self.assertEqual(fi.categorize("Pix recebido", rules), "Outros")

    def test_tie_keeps_the_first_category(self):
        self.assertEqual(fi.categorize("abc", {"A": ["abc"], "B": ["abc"]}), "A")


if __name__ == "__main__":
    unittest.main()
