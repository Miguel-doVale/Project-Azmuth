import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
import window_rules  # noqa: E402


class WindowRulesTests(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        self.state = mock.patch.object(window_rules, "STATE", Path(self.tmp.name) / "window-rules.json")
        self.state.start()

    def tearDown(self):
        self.state.stop()
        self.tmp.cleanup()

    def test_rule_per_class(self):
        self.assertEqual(window_rules.rules(["google-chrome"]), [
            'hl.window_rule({ name = "azmuth-max-google-chrome", match = { class = "^(google-chrome)$" }, maximize = true })'])

    def test_regex_is_escaped(self):
        dolphin, weird = window_rules.rules(["org.kde.dolphin", "foo(bar"])
        self.assertIn('class = "^(org\\\\.kde\\\\.dolphin)$"', dolphin)
        self.assertIn('foo\\\\(bar', weird)
        self.assertIn('name = "azmuth-max-foo-bar"', weird)

    def test_apply_sends_each_rule(self):
        ok = mock.Mock(returncode=0, stdout="ok", stderr="")
        with mock.patch.object(window_rules, "classes", return_value=["a", "b"]), \
                mock.patch.object(window_rules.subprocess, "run", return_value=ok) as run:
            self.assertTrue(window_rules.apply()["ok"])
        self.assertEqual([c.args[0][:2] for c in run.call_args_list], [["hyprctl", "eval"]] * 2)

    def test_apply_reports_hyprland_error(self):
        bad = mock.Mock(returncode=0, stdout="error: unknown field", stderr="")
        with mock.patch.object(window_rules, "classes", return_value=["a"]), \
                mock.patch.object(window_rules.subprocess, "run", return_value=bad):
            result = window_rules.apply()
        self.assertFalse(result["ok"])
        self.assertIn("unknown field", result["error"])


class RemovedClassTests(unittest.TestCase):
    def test_removed_class_is_turned_off(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            ok = mock.Mock(returncode=0, stdout="ok", stderr="")
            state = Path(tmp) / "window-rules.json"
            with mock.patch.object(window_rules, "STATE", state), \
                    mock.patch.object(window_rules.subprocess, "run", return_value=ok) as run:
                with mock.patch.object(window_rules, "classes", return_value=["google-chrome", "obsidian"]):
                    window_rules.apply()
                run.reset_mock()
                with mock.patch.object(window_rules, "classes", return_value=["google-chrome"]):
                    window_rules.apply()
            sent = [c.args[0][2] for c in run.call_args_list]
            self.assertTrue(any("azmuth-max-obsidian" in r and "maximize = false" in r for r in sent))
            self.assertTrue(any("azmuth-max-google-chrome" in r and "maximize = true" in r for r in sent))


if __name__ == "__main__":
    unittest.main()
