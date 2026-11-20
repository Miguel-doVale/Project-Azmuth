"""A transformação não pode travar a animação: o tema do Dolphin sai depois dela, em outro processo."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import core  # noqa: E402


class DeferredFileManagerTests(unittest.TestCase):
    def test_defer_spawns_detached_theme_command(self):
        path = core.resolve("massa_cinzenta")
        with patch.object(core, "spawn") as spawn:
            core.defer_file_manager(path)
        argv = spawn.call_args[0][0]
        self.assertEqual(argv[-2:], ["tema-arquivos", str(path)])   # caminho, não id: DNA fora de dna/ também serve
        self.assertEqual(argv[0], sys.executable)

    def test_theme_command_is_registered_and_applies_after_delay(self):
        self.assertIn("tema-arquivos", core.COMMANDS)
        path = str(core.resolve("neutral"))
        with patch.object(core, "apply_file_manager") as fm, patch.object(core.time, "sleep") as sleep, \
                patch.object(core, "read_state", return_value={"current": "neutral"}):
            core.COMMANDS["tema-arquivos"]([path])
        sleep.assert_called_once()
        self.assertGreaterEqual(sleep.call_args[0][0], 1.0)
        self.assertEqual(fm.call_args[0][0]["dna"]["id"], "neutral")

    def test_stale_theme_command_is_skipped_after_a_newer_transform(self):
        # duas transformações seguidas: o processo da primeira não pode pintar o Dolphin com o DNA velho
        path = str(core.resolve("neutral"))
        with patch.object(core, "apply_file_manager") as fm, patch.object(core.time, "sleep"), \
                patch.object(core, "read_state", return_value={"current": "massa_cinzenta"}):
            core.COMMANDS["tema-arquivos"]([path])
        fm.assert_not_called()

    def test_interactive_transform_defers_and_boot_applies_inline(self):
        src = Path(core.__file__).read_text(encoding="utf-8")
        body = src[src.index("def transform("):src.index("def ", src.index("def transform(") + 10)]
        self.assertIn("defer_file_manager", body)
        self.assertIn("apply_file_manager(data) if quiet", body)


if __name__ == "__main__":
    unittest.main()
