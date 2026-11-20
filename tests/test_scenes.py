import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
import core  # noqa: E402
import scenes  # noqa: E402


class ScenesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def scene(self, sid, **extra):
        (self.dir / sid).mkdir()
        (self.dir / sid / "scene.json").write_text(json.dumps({"id": sid, "title": sid.upper(), "effects": [
            {"type": "estrelas", "nome": "Estrelas", "on": True, "color": "#fff"}], "mono": False, **extra}))
        (self.dir / sid / "preview.png").write_bytes(b"png")

    def test_lists_valid_scenes_after_circuitos(self):
        self.scene("boa")
        (self.dir / "quebrada").mkdir()
        (self.dir / "quebrada" / "scene.json").write_text("{nao é json")
        (self.dir / "_src").mkdir()
        out = scenes.list_scenes(self.dir)
        self.assertEqual([s["id"] for s in out], ["circuitos", "boa"])
        boa = out[1]
        self.assertEqual(boa["effects"], [{"type": "estrelas", "nome": "Estrelas", "on": True}])
        self.assertEqual(boa["preview"], str(self.dir / "boa" / "preview.png"))
        self.assertIsNone(boa["carousel"])

    def test_order_follows_build_config(self):
        self.scene("a")
        self.scene("b")
        (self.dir / "_build").mkdir()
        (self.dir / "_build" / "scenes.json").write_text(json.dumps({"b": {}, "a": {}}))
        self.assertEqual([s["id"] for s in scenes.list_scenes(self.dir)], ["circuitos", "b", "a"])

    def test_carousel_entry(self):
        self.scene("p1")
        (self.dir / "car").mkdir()
        (self.dir / "car" / "scene.json").write_text(json.dumps({"id": "car", "title": "Car", "carousel": ["p1"], "every": 6, "effects": []}))
        car = [s for s in scenes.list_scenes(self.dir) if s["id"] == "car"][0]
        self.assertEqual((car["carousel"], car["every"]), (["p1"], 6))

    def test_missing_dir_lists_only_circuitos(self):
        self.assertEqual([s["id"] for s in scenes.list_scenes(self.dir / "nada")], ["circuitos"])

    def test_cmd_fundo_rejects_unknown_scene(self):
        self.scene("boa")
        with mock.patch.object(core, "SCENES_DIR", self.dir), mock.patch.object(core, "cmd_set") as set_:
            with self.assertRaises(SystemExit):
                core.cmd_fundo(["nao-existe"])
            core.cmd_fundo(["boa"])
            set_.assert_called_once_with("desktop.scene", '"boa"')


if __name__ == "__main__":
    unittest.main()
