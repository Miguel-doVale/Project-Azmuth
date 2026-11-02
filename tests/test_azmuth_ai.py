"""Validações do dispatcher local do assistente; não executa comandos do sistema."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import azmuth_ai as ai


class ActionAllowlistTests(unittest.TestCase):
    def test_lore_separates_azmuth_from_bens_grey_matter_form(self):
        lore = (Path(__file__).resolve().parents[1] / "data/ben10_knowledge.md").read_text(encoding="utf-8")
        self.assertIn("Massa Cinzenta (Grey Matter) é Ben transformado em Galvan", lore)
        self.assertIn("não é uma invenção criada por ele", lore)

    def test_transformation_accepts_only_an_installed_profile(self):
        with patch.object(ai, "available_dna_ids", return_value=["neutral", "massa_cinzenta"]):
            self.assertEqual(ai.action_argv({"command": "transform", "dna": "massa_cinzenta"}),
                             ["apply", "massa_cinzenta"])
            with self.assertRaises(ai.ActionError):
                ai.action_argv({"command": "transform", "dna": "heatblast"})

    def test_arbitrary_commands_and_unlock_are_rejected(self):
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "shell", "application": "rm -rf /"})
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "lifeform", "code": "1010", "mode": "off"})

    def test_capture_command_is_not_exposed_to_the_assistant(self):
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "screenshot", "mode": "full"})

    def test_preferences_are_whitelisted_and_bounded(self):
        self.assertEqual(ai.action_argv({"command": "set", "setting": "timer.minutes", "value": "15"}),
                         ["set", "timer.minutes", "15"])
        self.assertEqual(ai.action_argv({"command": "set", "setting": "dnd", "value": "true"}),
                         ["set", "dnd", "true"])
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "set", "setting": "startup.command", "value": "anything"})
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "set", "setting": "timer.minutes", "value": "999"})

    def test_event_arguments_are_structured_and_shell_free(self):
        self.assertEqual(ai.action_argv({
            "command": "event_add", "date": "2026-11-02", "time": "09:30", "title": "Consulta médica"
        }), ["event", "add", "2026-11-02", "09:30", "Consulta médica"])
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "event_add", "date": "2026-02-31", "title": "Inválido"})

    def test_model_tool_call_round_trip_uses_only_the_validated_command(self):
        tool_response = {
            "message": {
                "role": "assistant",
                "content": "",
                "tool_calls": [{
                    "function": {
                        "name": "azmuth_action",
                        "arguments": {"command": "transform", "dna": "massa_cinzenta"},
                    }
                }],
            }
        }
        final_response = {"message": {"role": "assistant", "content": "Transformação concluída."}}
        with patch.object(ai, "available_dna_ids", return_value=["neutral", "massa_cinzenta"]), \
             patch.object(ai, "_load_history", return_value=[]), \
             patch.object(ai, "_save_history") as save_history, \
             patch.object(ai, "system_prompt", return_value="persona"), \
             patch.object(ai, "context", return_value="contexto"), \
             patch.object(ai, "_ollama_chat", side_effect=[tool_response, final_response]) as chat, \
             patch.object(ai, "_run_azmuth", return_value="[OK]") as run:
            result = ai.ask("Me transforme no Massa Cinzenta")

        self.assertTrue(result["ok"])
        self.assertEqual(result["reply"], "Transformação concluída.")
        run.assert_called_once_with(["apply", "massa_cinzenta"])
        tool_messages = [m for m in chat.call_args_list[1].args[0] if m["role"] == "tool"]
        self.assertEqual(len(tool_messages), 1)
        self.assertIn("[OK]", tool_messages[0]["content"])
        save_history.assert_called_once()

    def test_cli_is_invoked_as_an_argument_array_without_shell(self):
        with patch.object(ai.subprocess, "run", return_value=ai.subprocess.CompletedProcess([], 0, "ok", "")) as run:
            self.assertEqual(ai._run_azmuth(["app", "obsidian"]), "ok")
        self.assertEqual(run.call_args.args[0], [ai.AZ, "app", "obsidian"])
        self.assertNotIn("shell", run.call_args.kwargs)


if __name__ == "__main__":
    unittest.main()
