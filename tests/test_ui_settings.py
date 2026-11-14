import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
import core  # noqa: E402


class UiSettingsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.patches = [
            mock.patch.object(core, "SETTINGS_FILE", base / "settings.json"),
            mock.patch.object(core, "STATE_DIR", base),
            mock.patch.object(core, "THEME_FILE", base / "theme.json"),
            mock.patch.object(core, "shell_running", lambda: False),
        ]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in self.patches:
            p.stop()
        self.tmp.cleanup()

    def test_defaults_present(self):
        s = core.read_settings()
        self.assertIs(s["island"]["detached"], True)
        self.assertEqual(s["dock"]["pinned"][0], "google-chrome")
        self.assertEqual(s["windows"]["maximize"], ["google-chrome"])
        self.assertIs(s["audio_auto_switch"], True)

    def test_validate_accepts_and_normalizes(self):
        self.assertIs(core.validate_setting("island.detached", False), False)
        self.assertEqual(core.validate_setting("dock.pinned", ["spotify", "spotify", "obsidian"]), ["spotify", "obsidian"])
        self.assertEqual(core.validate_setting("windows.maximize", [" google-chrome "]), ["google-chrome"])
        self.assertIs(core.validate_setting("audio_auto_switch", False), False)
        self.assertEqual(core.validate_setting("timer.minutes", 15), 15)   # outros caminhos passam direto

    def test_validate_rejects(self):
        for path, value in [("island.detached", "sim"), ("dock.pinned", "spotify"), ("windows.maximize", [""]),
                            ("dock.pinned", [f"app{i}" for i in range(21)]), ("audio_auto_switch", 1)]:
            with self.subTest(path=path, value=value):
                with self.assertRaises(ValueError):
                    core.validate_setting(path, value)

    def test_theme_exports_island_and_dock(self):
        core.write_theme(core.load_dna(core.resolve("neutral")))
        theme = json.loads(core.THEME_FILE.read_text())
        self.assertIs(theme["island"]["detached"], True)
        self.assertEqual(theme["dock"]["pinned"][-1], "obsidian")
        self.assertIs(theme["audio_auto_switch"], True)


if __name__ == "__main__":
    unittest.main()
