"""Testes do controle de processos e das preferências de inicialização."""
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import task_manager as tm
import core


class ProcessTests(unittest.TestCase):
    def test_stat_with_parentheses_and_spaces(self):
        fields = ["S", "41"] + ["0"] * 20
        fields[11], fields[12], fields[16], fields[17] = "8", "5", "2", "3"
        fields[19], fields[20], fields[21] = "909", "8192", "2"
        p = tm.parse_stat("123 (nome (com) espaços) " + " ".join(fields))
        self.assertEqual(p["name"], "nome (com) espaços")
        self.assertEqual((p["ticks"], p["start"], p["threads"]), (13, 909, 3))
        self.assertEqual(p["rss"], 2 * tm.PAGE)

    def test_signals_and_stale_identity(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"],
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            p = tm.read_process(child.pid)
            with self.assertRaises(ValueError):
                tm.control_process(child.pid, p["start"] + 1, "kill")
            self.assertIsNone(child.poll())
            tm.control_process(child.pid, p["start"], "stop")
            deadline = time.monotonic() + 2
            while tm.read_process(child.pid)["state"] != "T" and time.monotonic() < deadline:
                time.sleep(.02)
            self.assertEqual(tm.read_process(child.pid)["state"], "T")
            tm.control_process(child.pid, p["start"], "cont")
            tm.control_process(child.pid, p["start"], "stop")
            deadline = time.monotonic() + 2
            while tm.read_process(child.pid)["state"] != "T" and time.monotonic() < deadline:
                time.sleep(.02)
            self.assertEqual(tm.read_process(child.pid)["state"], "T")
            tm.control_process(child.pid, p["start"], "term")
            child.wait(timeout=3)
            self.assertEqual(child.returncode, -signal.SIGTERM)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()

    def test_forced_signal_only_reaches_selected_child(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        try:
            p = tm.read_process(child.pid)
            tm.control_process(child.pid, p["start"], "kill")
            child.wait(timeout=3)
            self.assertEqual(child.returncode, -signal.SIGKILL)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()

    def test_protects_reader_and_session(self):
        p = tm.read_process(os.getpid())
        with self.assertRaises(ValueError):
            tm.control_process(p["pid"], p["start"], "kill")
        p.update(pid=555555, uid=tm.UID, name="Hyprland", exe="/usr/bin/Hyprland", argv=["Hyprland"])
        self.assertTrue(tm.protected_reason(p))
        p.update(name="editor", exe="/usr/bin/editor", uid=tm.UID + 1)
        self.assertTrue(tm.protected_reason(p))


class StartupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="azmuth-startup-test-")
        self.root = Path(self.temp.name)
        self.config = self.root / "config"
        self.system = self.root / "system"
        (self.system / "autostart").mkdir(parents=True)
        self.patches = [
            patch.object(tm, "CONFIG", self.config),
            patch.object(tm, "STATE", self.root / "state"),
            patch.dict(os.environ, {"XDG_CONFIG_DIRS": str(self.system), "XDG_CURRENT_DESKTOP": "Hyprland"}),
        ]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    def test_user_override_preserves_system_and_fields(self):
        original = "[Desktop Entry]\nType=Application\nName=Editor\nExec=/bin/true --preservar\nIcon=editor\nComment=Teste\n"
        source = self.system / "autostart/editor.desktop"
        source.write_text(original)
        tm.startup_toggle("xdg:editor.desktop", False)
        override = self.config / "autostart/editor.desktop"
        values = tm.read_desktop(override)
        self.assertEqual(source.read_text(), original)
        self.assertEqual(values["Hidden"], "true")
        self.assertEqual(values["Exec"], "/bin/true --preservar")
        self.assertFalse(tm.startup_records()[0]["enabled"])
        tm.startup_toggle("xdg:editor.desktop", True)
        self.assertTrue(tm.startup_records()[0]["enabled"])
        self.assertEqual(tm.read_desktop(override)["Comment"], "Teste")

    def test_desktop_scope_is_respected(self):
        (self.system / "autostart/other.desktop").write_text(
            "[Desktop Entry]\nType=Application\nName=Outro\nExec=/bin/true\nOnlyShowIn=KDE;\n")
        self.assertEqual(tm.startup_records(), [])

    def test_add_toggle_remove_roundtrip_and_symlink(self):
        source = self.root / "editor.desktop"
        source.write_text("[Desktop Entry]\nType=Application\nName=Editor de teste\nExec=/bin/true\nOnlyShowIn=KDE;\n")
        with patch.object(tm, "catalog", return_value=[{"id": "editor.desktop", "path": str(source), "name": "Editor de teste"}]):
            tm.startup_add("editor.desktop")
        rows = tm.startup_records()
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0]["enabled"])
        self.assertTrue(rows[0]["removable"])
        tm.startup_toggle(rows[0]["id"], False)
        tm.startup_remove(rows[0]["id"])
        self.assertEqual(tm.startup_records(), [])
        external = self.root / "externo.desktop"
        external.write_text("não alterar")
        (self.config / "autostart/link.desktop").symlink_to(external)
        with self.assertRaises(ValueError):
            tm.write_desktop(self.config / "autostart/link.desktop", {"Hidden": "true"})
        self.assertEqual(external.read_text(), "não alterar")

    def test_runner_launches_only_opted_in_apps_once_per_session(self):
        standard = self.system / "autostart/standard.desktop"
        standard.write_text("[Desktop Entry]\nType=Application\nName=Sessão\nExec=/bin/true\n")
        own = self.config / "autostart/own.desktop"
        own.parent.mkdir(parents=True)
        own.write_text("[Desktop Entry]\nType=Application\nName=Escolhido\nExec=/bin/true\nX-Azmuth-Managed=true\n")
        with patch.dict(os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "sessao-de-teste"}), \
             patch.object(tm.shutil, "which", return_value="/usr/bin/gio"), \
             patch.object(tm.subprocess, "run") as launch:
            launch.return_value.returncode = 0
            first = tm.startup_run()
            second = tm.startup_run()
        self.assertEqual(first["items"], [{"name": "Escolhido", "ok": True}])
        self.assertIn("já executada", second["message"])
        launch.assert_called_once()
        self.assertEqual(launch.call_args.args[0], ["/usr/bin/gio", "launch", str(own)])

    def test_enabling_one_dna_app_does_not_enable_every_app(self):
        rows = [{"id": "dna:test:a", "dna": "test", "command": "code"},
                {"id": "dna:test:b", "dna": "test", "command": "kitty"}]
        with patch.object(tm, "dna_records", return_value=rows), \
             patch.object(core, "read_settings", return_value={"dna": {"test": {"autostart_apps": False}}}), \
             patch.object(core, "set_setting") as save:
            tm.startup_toggle("dna:test:a", True)
        saved = dict(c.args for c in save.call_args_list)
        self.assertEqual(saved["dna.test.disabled_apps"], ["kitty"])
        self.assertTrue(saved["dna.test.autostart_apps"])

    def test_disabled_dna_app_is_not_launched(self):
        data = {"dna": {"id": "test"}, "apps": {"autostart": [{"cmd": "code"}, {"cmd": "kitty"}]}}
        with patch.object(core, "read_settings", return_value={"dna": {"test": {"disabled_apps": ["code"]}}}), \
             patch.object(core, "hypr_json", return_value=[]), \
             patch.object(core, "run") as run, \
             patch.object(core, "hypr_exec") as launch, \
             patch.object(core, "log"):
            run.return_value.returncode = 1
            core.apply_apps(data)
        launch.assert_called_once_with("kitty", None)


if __name__ == "__main__":
    unittest.main()
