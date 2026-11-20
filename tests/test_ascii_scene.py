import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import ascii_scene  # noqa: E402


class AsciiSceneTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.src = self.dir / "_src"
        self.src.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def img(self, name, size, color):
        Image.new("RGB", size, color).save(self.src / name)
        return name

    def test_grid_dimensions(self):
        g = ascii_scene.convert({"src": self.img("a.png", (200, 200), (200, 200, 200))}, self.src)
        self.assertEqual((g["cols"], g["rows"]), (307, 100))
        self.assertEqual(len(g["lum"]), 100)
        self.assertTrue(all(len(r) == 307 for r in g["lum"]))
        self.assertTrue(all(len(r) == 307 * 6 for r in g["col"]))

    def test_box_inside_screen(self):
        g = ascii_scene.convert({"src": self.img("a.png", (100, 200), (200, 200, 200)),
                                 "place": [1, .5], "focus": [1, .5]}, self.src)
        x, y, w, h = g["box"]
        self.assertEqual(x + w, 307)
        self.assertEqual(y, 0)

    def test_tile_mirror_fills_screen(self):
        g = ascii_scene.convert({"src": self.img("a.png", (100, 200), (230, 230, 230)), "tile": True,
                                 "place": [.2, .5], "focus": [.5, .5], "vig": 0}, self.src)
        x, y, w, h = g["box"]
        outside = [g["lum"][r][c] for r in range(100) for c in range(307) if not (x <= c < x + w)]
        self.assertTrue(outside)
        self.assertNotIn("0", outside)

    def test_tilefix_red_becomes_white(self):
        g = ascii_scene.convert({"src": self.img("a.png", (100, 200), (220, 20, 20)), "tile": True, "tilefix": "red",
                                 "place": [.2, .5], "focus": [.5, .5]}, self.src)
        x, y, w, h = g["box"]
        row = g["col"][50]
        self.assertEqual(row[(x + w + 5) * 6:(x + w + 6) * 6], "ecf0f6")
        inside = row[(x + w // 2) * 6:(x + w // 2 + 1) * 6]
        self.assertGreater(int(inside[0:2], 16), int(inside[2:4], 16))

    def test_layers_two_images(self):
        name = self.img("a.png", (400, 200), (200, 200, 200))
        cfg = {"src": name, "layers": [{"crop": [.5, 0, 1, 1], "focus": [1, .5], "place": [1, .5]},
                                       {"crop": [0, 0, .5, 1], "focus": [0, .5], "place": [0, .5]}]}
        g = ascii_scene.convert(cfg, self.src)
        x, y, w, h = g["box"]
        self.assertEqual(x + w, 307)

    def test_build_writes_scene_and_preview(self):
        cfg = {"src": self.img("a.png", (200, 200), (90, 200, 90)), "title": "Teste", "mono": True,
               "effects": [{"type": "estrelas", "nome": "Estrelas", "on": True}]}
        out = ascii_scene.build("teste", cfg, self.dir)
        scene = json.loads((out / "scene.json").read_text())
        self.assertEqual(scene["id"], "teste")
        self.assertIs(scene["mono"], True)
        self.assertEqual(scene["effects"][0]["type"], "estrelas")
        with Image.open(out / "preview.png") as im:
            self.assertEqual(im.size, (640, 360))
        self.assertFalse((out / "scene.js").exists())

    def test_carousel_scene(self):
        ascii_scene.build("p1", {"src": self.img("a.png", (50, 50), (200, 0, 0)), "title": "P1"}, self.dir)
        out = ascii_scene.build_carousel("posteres", "Pôsteres", ["p1", "p2"], 6, self.dir)
        scene = json.loads((out / "scene.json").read_text())
        self.assertEqual(scene["carousel"], ["p1", "p2"])
        self.assertEqual(scene["every"], 6)
        self.assertNotIn("lum", scene)
        self.assertTrue((out / "preview.png").exists())


if __name__ == "__main__":
    unittest.main()
