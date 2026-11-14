import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
from docker_guard import decide  # noqa: E402


class DockerGuardTests(unittest.TestCase):
    def test_warns_then_stops_once_per_discharge(self):
        self.assertEqual(decide(15, True, False, False), "")
        self.assertEqual(decide(10, True, False, False), "warn")
        self.assertEqual(decide(9, True, True, False), "")
        self.assertEqual(decide(7, True, True, False), "stop")
        self.assertEqual(decide(5, True, True, True), "")

    def test_jumping_straight_below_stop_still_stops(self):
        self.assertEqual(decide(6, True, False, False), "stop")

    def test_charger_rearms(self):
        self.assertEqual(decide(6, False, True, True), "reset")
        self.assertEqual(decide(50, False, False, False), "")


if __name__ == "__main__":
    unittest.main()
