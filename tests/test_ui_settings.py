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

    def test_desktop_defaults(self):
        d = core.read_settings()["desktop"]
        self.assertEqual(d["scene"], "circuitos")
        self.assertNotIn("comic", d)   # transformação em quadrinho removida a pedido do Miguel (2026-11-20)
        self.assertEqual((d["effects"], d["color"], d["every"]), ({}, {}, {}))

    def test_desktop_validation(self):
        self.assertEqual(core.validate_setting("desktop.scene", " portal-verde "), "portal-verde")
        self.assertEqual(core.validate_setting("desktop.effects.portal-verde", [True, False]), [True, False])
        self.assertEqual(core.validate_setting("desktop.color.him", "dna"), "dna")
        self.assertEqual(core.validate_setting("desktop.every.posteres", 9), 9)
        for path, bad in [("desktop.scene", ""), ("desktop.scene", 3), ("desktop.effects.x", [1]),
                          ("desktop.effects.x", [True] * 17), ("desktop.color.x", "azul"),
                          ("desktop.every.x", 7), ("desktop.every.x", True), ("desktop.comic", False)]:
            with self.assertRaises(ValueError, msg=f"{path}={bad!r}"):
                core.validate_setting(path, bad)

    def test_theme_exports_desktop(self):
        core.set_setting("desktop.scene", "him")
        with mock.patch.object(core, "read_state", lambda: {}), \
             mock.patch.object(core, "load_roster", lambda: {"neutral": "neutral"}), \
             mock.patch.object(core, "timer_info", lambda *a: {}):
            core.write_theme({"dna": {"id": "x", "name": "X", "description": ""}, "palette": {"primary": "#38bdf8"},
                              "wallpaper": {"path": "a.png"}, "hud": {}})
        theme = json.loads(core.THEME_FILE.read_text())
        self.assertEqual(theme["desktop"]["scene"], "him")
        self.assertTrue(theme["scenes_dir"].endswith("azmuth/scenes"))

    def test_concurrent_set_setting_keeps_every_key(self):
        """Vários `azmuth set` ao mesmo tempo (cliques rápidos na Central) não podem perder chaves."""
        import threading
        errors = []

        def write(i):
            try:
                core.set_setting(f"desktop.effects.cena{i}", [True, i % 2 == 0])
            except Exception as exc:  # noqa: BLE001
                errors.append(exc)

        for _round in range(5):
            threads = [threading.Thread(target=write, args=(i,)) for i in range(12)]
            for t in threads:
                t.start()
            for t in threads:
                t.join()
        self.assertEqual(errors, [])
        saved = core.read_settings()["desktop"]["effects"]
        self.assertEqual(sorted(saved), sorted(f"cena{i}" for i in range(12)))

    def test_concurrent_set_and_theme_write_stay_consistent(self):
        """`azmuth set` = set_setting + write_theme: em paralelo, nenhum falha e o theme.json (lido pela shell)
        termina com TODAS as chaves, igual ao settings.json."""
        import threading
        errors = []
        dna = {"dna": {"id": "x", "name": "X", "description": ""}, "palette": {"primary": "#38bdf8"},
               "wallpaper": {"path": "a.png"}, "hud": {}}

        def run(i):
            try:
                core.set_setting(f"desktop.effects.cena{i}", [True, i % 2 == 0])
                core.write_theme(dna)
            except Exception as exc:  # noqa: BLE001
                errors.append(repr(exc))

        with mock.patch.object(core, "read_state", lambda: {}), \
             mock.patch.object(core, "load_roster", lambda: {"neutral": "neutral"}), \
             mock.patch.object(core, "timer_info", lambda *a: {}):
            for _round in range(6):
                threads = [threading.Thread(target=run, args=(i,)) for i in range(12)]
                for t in threads:
                    t.start()
                for t in threads:
                    t.join()
        self.assertEqual(errors, [])
        theme = json.loads(core.THEME_FILE.read_text())
        self.assertEqual(sorted(theme["desktop"]["effects"]), sorted(f"cena{i}" for i in range(12)))
        self.assertEqual(theme["desktop"], core.read_settings()["desktop"])

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
