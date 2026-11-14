import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))
import shortcuts  # noqa: E402


class ShortcutSheetTests(unittest.TestCase):
    def test_capture_and_sheet_binds_exist(self):
        lua = (ROOT / "hypr/azmuth.lua").read_text()
        for bind in ('" + ALT + S"', '" + SHIFT + S"', '"Print"', '" + F1"', '" + KP_Divide"', '" + SHIFT + V"', '" + D"'):
            self.assertIn(bind, lua)

    def test_text_lists_every_section(self):
        out = shortcuts.text()
        for section, items in shortcuts.SHORTCUTS:
            self.assertIn(section.upper(), out)
            self.assertTrue(items)


class IslandShortcutTests(unittest.TestCase):
    def test_super_w_opens_island_panel(self):
        self.assertIn("Painel da ilha", shortcuts.text())
        self.assertNotIn("Dashboard", shortcuts.text())


if __name__ == "__main__":
    unittest.main()
