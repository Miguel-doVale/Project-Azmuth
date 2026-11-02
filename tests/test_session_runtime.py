"""Regressões de detecção da shell, prévia e recuperação das notificações."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import core
import session_runtime as session


class ShellTests(unittest.TestCase):
    def test_running_shell_is_identified_by_its_ipc(self):
        with patch.object(core.shutil, "which", return_value="/usr/bin/qs"), \
             patch.object(core, "run", return_value=subprocess.CompletedProcess([], 0, "target hud\n  function lock(): void\n")) as run:
            self.assertTrue(core.shell_running())
        self.assertEqual(run.call_args.args[0], ["qs", "-p", str(core.SHELL_DIR), "ipc", "show"])

    def test_other_config_or_unresponsive_shell_is_not_accepted(self):
        with patch.object(core.shutil, "which", return_value="/usr/bin/qs"), \
             patch.object(core, "run", return_value=subprocess.CompletedProcess([], 0, "target manager\n")):
            self.assertFalse(core.shell_running())
        with patch.object(core.shutil, "which", return_value="/usr/bin/qs"), \
             patch.object(core, "run", side_effect=subprocess.TimeoutExpired("qs", 2)):
            self.assertFalse(core.shell_running())

    def test_preview_never_launches_a_real_fallback_lock(self):
        with patch.object(core, "shell_running", return_value=False), \
             patch.object(core, "spawn") as spawn, patch.object(core, "log"):
            core.cmd_lock(["--preview"])
        spawn.assert_not_called()

    def test_preview_is_routed_to_native_interface(self):
        with patch.object(core, "shell_running", return_value=True), \
             patch.object(core, "shell_ipc") as ipc, patch.object(core, "spawn") as spawn:
            core.cmd_lock(["--preview"])
        ipc.assert_called_once_with("lockPreview")
        spawn.assert_not_called()

    def test_dunst_is_released_only_when_native_interface_is_ready(self):
        dunst = {"pid": 10, "process": "dunst", "name": "dunst", "uid": os.getuid()}
        native = {"pid": 20, "process": "qs", "name": "Quickshell", "uid": os.getuid()}
        with patch.object(core, "shell_running", return_value=True), \
             patch.object(session, "notification_info", side_effect=[dunst,native,native]), \
             patch.object(session, "main_instances", return_value=[{"pid":20}]), \
             patch.object(session, "command") as command:
            self.assertTrue(session.reclaim_notifications()["ok"])
        command.assert_called_once_with(["systemctl", "--user", "stop", "dunst.service"])
        with patch.object(core, "shell_running", return_value=False), \
             patch.object(session, "command") as command:
            self.assertFalse(session.reclaim_notifications()["ok"])
        command.assert_not_called()


    def test_doctor_reports_bad_dna_without_aborting_other_checks(self):
        with tempfile.TemporaryDirectory(prefix="azmuth-doctor-test-") as temp:
            base = Path(temp)
            (base / "invalid.yaml").write_text("invalid")
            for name in ["desktop.json", "playlists.json", "events.json", "theme.json"]:
                (base / name).write_text("{}")
            with patch.object(core, "DNA_DIR", base), patch.object(core, "STATE_DIR", base), \
                 patch.object(core, "load_dna", side_effect=SystemExit("DNA inválido")), \
                 patch.object(core, "shell_running", return_value=False), \
                 patch.object(session, "main_instances", return_value=[]), \
                 patch.object(session, "own_processes", return_value=[]), \
                 patch.object(session, "notification_info", return_value={"pid":0,"name":""}), \
                 patch.object(session, "command", return_value=subprocess.CompletedProcess([],0,"","")):
                report = session.diagnose()
        self.assertFalse(report["ok"])
        dna = next(row for row in report["checks"] if row["name"] == "DNAs e artes")
        self.assertFalse(dna["ok"])
        self.assertIn("DNA inválido", dna["detail"])
        self.assertTrue(any(row["name"] == "theme.json" for row in report["checks"]))


if __name__ == "__main__":
    unittest.main()
