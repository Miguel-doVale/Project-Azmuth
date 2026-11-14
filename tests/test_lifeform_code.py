import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
import core  # noqa: E402


class LifeformCodeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.orig = core.LIFEFORM_CODE_FILE
        core.LIFEFORM_CODE_FILE = Path(self.tmp.name) / "code.json"

    def tearDown(self):
        core.LIFEFORM_CODE_FILE = self.orig
        self.tmp.cleanup()

    def test_default_code_until_changed(self):
        self.assertTrue(core.lifeform_code_ok("1010"))
        self.assertFalse(core.lifeform_code_ok(""))
        self.assertFalse(core.lifeform_code_ok("1011"))

    def test_saved_code_replaces_default_and_is_not_stored_plain(self):
        core.LIFEFORM_CODE_FILE.write_text(json.dumps({"salt": "ab", "hash": core._code_hash("4242", "ab")}))
        self.assertTrue(core.lifeform_code_ok("4242"))
        self.assertFalse(core.lifeform_code_ok("1010"))
        self.assertNotIn("4242", core.LIFEFORM_CODE_FILE.read_text())


if __name__ == "__main__":
    unittest.main()
