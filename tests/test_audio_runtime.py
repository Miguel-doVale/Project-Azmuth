"""Testes do diagnóstico e da recuperação segura de áudio PipeWire."""
import contextlib
import io
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import call, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import audio_runtime as audio


ANALOG = "alsa_output.pci-0000_00_1f.3.analog-stereo"
DUMMY = {"default": "auto_null", "sinks": ["auto_null"]}
ANALOG_OK = {"default": ANALOG, "sinks": [ANALOG]}


class AudioRuntimeTests(unittest.TestCase):
    def test_recognizes_pipewire_dummy_sink_names(self):
        self.assertTrue(audio.is_dummy("auto_null"))
        self.assertTrue(audio.is_dummy("Dummy Output"))
        self.assertFalse(audio.is_dummy(ANALOG))

    def test_snapshot_reads_default_and_real_sinks(self):
        with patch.object(audio, "command", side_effect=[
            subprocess.CompletedProcess([], 0, "Server Name: PipeWire\nDefault Sink: auto_null\n", ""),
            subprocess.CompletedProcess([], 0, "403\tauto_null\tPipeWire\n54\t" + ANALOG + "\tPipeWire\n", ""),
        ]):
            self.assertEqual(audio.snapshot(), {"default": "auto_null", "sinks": ["auto_null", ANALOG]})

    def test_restore_does_not_restart_when_real_sink_is_default(self):
        with patch.object(audio, "snapshot", return_value=ANALOG_OK), \
             patch.object(audio, "command") as command, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(audio.restore(), 0)
        command.assert_not_called()

    def test_restore_restarts_and_pins_recovered_sink(self):
        with patch.object(audio, "snapshot", side_effect=[DUMMY, ANALOG_OK]), \
             patch.object(audio, "playback_holders", return_value=[]), \
             patch.object(audio, "command", return_value=subprocess.CompletedProcess([], 0, "", "")) as command, \
             patch.object(audio, "_move_streams", return_value=0), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(audio.restore(), 0)
        self.assertEqual(command.call_args_list, [
            call(audio.RESTART_SERVICES, timeout=20),
            call(["pactl", "set-default-sink", ANALOG]),
        ])

    def test_restore_selects_available_physical_sink_if_default_stays_dummy(self):
        state_with_physical_sink = {"default": "auto_null", "sinks": ["auto_null", ANALOG]}
        snapshots = [DUMMY, state_with_physical_sink, state_with_physical_sink, ANALOG_OK]
        ticks = [0, 0.5, 1.0, 1.5, 2.0, 2.5]
        with patch.object(audio, "snapshot", side_effect=snapshots), \
             patch.object(audio, "playback_holders", return_value=[]), \
             patch.object(audio, "command", return_value=subprocess.CompletedProcess([], 0, "", "")) as command, \
             patch.object(audio.time, "monotonic", side_effect=ticks), \
             patch.object(audio.time, "sleep"), \
             patch.object(audio, "_move_streams", return_value=0), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(audio.restore(), 0)
        self.assertIn(call(["pactl", "set-default-sink", ANALOG]), command.call_args_list)

    def test_restore_reports_exclusive_alsa_holder_without_restarting_services(self):
        output = io.StringIO()
        holder = [{"pid": 42, "name": "ridiculous-audio-helper"}]
        with patch.object(audio, "snapshot", return_value=DUMMY), \
             patch.object(audio, "playback_holders", return_value=holder), \
             patch.object(audio, "command") as command, \
             contextlib.redirect_stdout(output):
            self.assertEqual(audio.restore(), 1)
        command.assert_not_called()
        self.assertIn("ridiculous-audio-helper", output.getvalue())
        self.assertIn("soundBackend", output.getvalue())

    def test_audio_command_without_subcommand_runs_restore(self):
        with patch.object(audio, "restore", return_value=0) as restore, \
             contextlib.redirect_stdout(io.StringIO()):
            audio.main([])
        restore.assert_called_once_with()

    def test_status_returns_nonzero_for_dummy_and_zero_for_real_output(self):
        output = io.StringIO()
        with patch.object(audio, "snapshot", return_value=DUMMY), contextlib.redirect_stdout(output):
            self.assertEqual(audio.status(), 1)
        self.assertIn("Dummy Output", output.getvalue())
        with patch.object(audio, "snapshot", return_value=ANALOG_OK), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(audio.status(), 0)


if __name__ == "__main__":
    unittest.main()


class SwitchOnConnectTests(unittest.TestCase):
    """A troca de saída ao conectar é feita pela shell; aqui só: tirar o módulo antigo do PipeWire
    (ele também trocava para a saída virtual do EasyEffects) e fazer o EasyEffects seguir a saída padrão."""

    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.conf = self.dir / "90-azmuth-switch-on-connect.conf"
        self.eerc = self.dir / "easyeffectsrc"

    def tearDown(self):
        self.tmp.cleanup()

    def test_removes_legacy_pulse_module(self):
        self.conf.write_text(audio.SWITCH_TEXT)
        audio.switch_on_connect(True, conf_dir=self.dir, ee_conf=self.eerc)
        self.assertFalse(self.conf.exists())

    def test_keeps_a_file_that_is_not_ours(self):
        self.conf.write_text("pulse.cmd = [ ] # do usuário\n")
        audio.switch_on_connect(True, conf_dir=self.dir, ee_conf=self.eerc)
        self.assertTrue(self.conf.exists())

    def test_easyeffects_follows_default_output(self):
        self.eerc.write_text("[StreamOutputs]\noutputDevice=alsa_output.x\nplugins=equalizer#0\n")
        self.assertTrue(audio.switch_on_connect(True, conf_dir=self.dir, ee_conf=self.eerc))
        text = self.eerc.read_text()
        self.assertIn("useDefaultOutputDevice=true", text)
        self.assertIn("plugins=equalizer#0", text)
        self.assertFalse(audio.switch_on_connect(True, conf_dir=self.dir, ee_conf=self.eerc))
