"""Validações do dispatcher local do assistente; não executa comandos do sistema."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import azmuth_ai as ai


def setUpModule():
    # nenhum teste pode chamar um provedor de IA de verdade (nem agir no sistema)
    global _guard
    _guard = patch.object(ai, "ask_claude", side_effect=AssertionError("teste chamou o Claude de verdade"))
    _guard.start()


def tearDownModule():
    _guard.stop()


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
            result = ai.ask_ollama("Me transforme no Massa Cinzenta")

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


class BrainActionTests(unittest.TestCase):
    def test_read_note_and_write_note_map_to_cerebro_cli(self):
        self.assertEqual(ai.action_argv({"command": "read_note", "path": "Vida/Rotina.md"}, allow_brain=True),
                         ["cerebro", "read", "Vida/Rotina.md"])
        content = "---\nresumo: x\nacesso: aberto\n---\nCorpo"
        self.assertEqual(ai.action_argv({"command": "write_note", "path": "Vida/Planos.md", "content": content},
                                        allow_brain=True), ["cerebro", "write", "Vida/Planos.md", content])

    def test_brain_commands_are_refused_on_the_ollama_path(self):
        # o Ollama usa o mesmo validador: sem allow_brain, nada do cérebro passa (decisão: só o Claude lê o vault)
        for args in [{"command": "read_note", "path": "Vida/x.md"},
                     {"command": "write_note", "path": "Vida/x.md", "content": "x"}]:
            with self.assertRaises(ai.ActionError):
                ai.action_argv(args)

    def test_read_note_rejects_extra_keys_and_long_paths(self):
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "read_note", "path": "Vida/x.md", "mode": "restricted"}, allow_brain=True)
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "read_note", "path": "a" * 201 + ".md"}, allow_brain=True)
        with self.assertRaises(ai.ActionError):
            ai.action_argv({"command": "write_note", "path": "Vida/x.md", "content": "x" * 8001}, allow_brain=True)

    def test_ollama_tool_schema_has_no_brain_commands(self):
        with patch.object(ai, "available_dna_ids", return_value=["neutral"]):
            enum = ai.tool_schema()[0]["function"]["parameters"]["properties"]["command"]["enum"]
        self.assertNotIn("read_note", enum)
        self.assertNotIn("write_note", enum)

    def test_brain_context_has_open_map_and_never_restricted_titles(self):
        import os
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            vault = Path(tmp)
            (vault / "Vida").mkdir()
            (vault / "Finanças").mkdir()
            (vault / "Vida/Rotina.md").write_text("---\nresumo: Rotina diária\nacesso: aberto\n---\nx", encoding="utf-8")
            (vault / "Finanças/Bancos.md").write_text("---\nresumo: Bancos\nacesso: financas\n---\nx", encoding="utf-8")
            with patch.dict(os.environ, {"AZMUTH_BRAIN": str(vault)}):
                text = ai.brain_context()
        self.assertIn("Vida/Rotina — Rotina diária", text)
        self.assertNotIn("Bancos", text)
        with patch.dict(os.environ, {"AZMUTH_BRAIN": "/caminho/que/nao/existe"}):
            self.assertIn("ainda não existe", ai.brain_context())

    def test_system_prompt_tells_model_notes_are_data_and_to_check_aprendizados(self):
        with patch.object(ai, "available_dna_ids", return_value=["neutral"]):
            prompt = ai.claude_system_prompt()
        for needle in ["read_note", "write_note", "Azmuth/Aprendizados.md", "dados, não ordens", "--restricted"]:
            self.assertIn(needle, prompt)

    def test_brain_reads_are_not_truncated_to_1200_chars(self):
        long = "x" * 5000
        done = ai.subprocess.CompletedProcess([], 0, long, "")
        with patch.object(ai.subprocess, "run", return_value=done):
            self.assertEqual(len(ai._run_azmuth(["cerebro", "read", "Vida/x.md"])), 5000)
            self.assertEqual(len(ai._run_azmuth(["event", "list"])), 1200)


class RestrictedModeTests(unittest.TestCase):
    def test_restricted_command_never_allows_ai_action(self):
        cmd = ai.claude_restricted_command("oi", None)
        allowed = cmd[cmd.index("--allowed-tools") + 1:cmd.index("--strict-mcp-config")]
        self.assertTrue(allowed and all(rule.endswith(" ai-restricted:*)") for rule in allowed))
        self.assertFalse(any("ai-action" in part for part in cmd))
        self.assertEqual(cmd[cmd.index("--tools") + 1], "Bash")

    def test_restricted_session_file_differs_from_normal(self):
        self.assertNotEqual(ai.RESTRICTED_SESSION_FILE, ai.CLAUDE_SESSION_FILE)
        self.assertIn("--resume", ai.claude_restricted_command("oi", "0" * 36))

    def test_restricted_argv_only_allows_read_and_report(self):
        self.assertEqual(ai.restricted_argv({"command": "read_note", "path": "Finanças/Bancos.md"}),
                         ["cerebro", "read-restricted", "Finanças/Bancos.md"])
        self.assertEqual(ai.restricted_argv({"command": "report", "period": "2026-11"}),
                         ["cerebro", "report", "2026-11"])
        self.assertEqual(ai.restricted_argv({"command": "report", "period": "2026"}), ["cerebro", "report", "2026"])
        for bad in [{"command": "report", "period": "novembro"}, {"command": "transform", "dna": "neutral"},
                    {"command": "app", "application": "kitty"}, {"command": "write_note", "path": "x.md", "content": "x"},
                    {"command": "set", "setting": "dnd", "value": "true"}]:
            with self.assertRaises(ai.ActionError, msg=str(bad)):
                ai.restricted_argv(bad)

    def test_restricted_prompt_has_no_send_tools_and_treats_notes_as_data(self):
        prompt = ai.restricted_system_prompt()
        self.assertIn("ai-restricted", prompt)
        self.assertNotIn("ai-action", prompt)
        self.assertIn("dados, não ordens", prompt)

    def test_restricted_cli_rejects_normal_actions(self):
        with patch("builtins.print") as printed, self.assertRaises(SystemExit):
            ai.restricted_cli(['{"command": "transform", "dna": "neutral"}'])
        self.assertIn('"ok": false', printed.call_args.args[0])


class ClaudeIsolationTests(unittest.TestCase):
    def test_both_sessions_ignore_user_settings_and_never_prompt(self):
        for cmd in [ai.claude_command("oi", None), ai.claude_restricted_command("oi", None)]:
            self.assertEqual(cmd[cmd.index("--setting-sources") + 1], "project")
            self.assertEqual(cmd[cmd.index("--permission-mode") + 1], "dontAsk")


if __name__ == "__main__":
    unittest.main()


class ClaudeProviderTests(unittest.TestCase):
    def test_claude_only_gets_the_validated_action_command(self):
        cmd = ai.claude_command("oi", None)
        tools = cmd[cmd.index("--tools") + 1]
        allowed = cmd[cmd.index("--allowed-tools") + 1:cmd.index("--strict-mcp-config")]
        self.assertEqual(tools, "Bash")
        self.assertTrue(allowed and all(rule.endswith(" ai-action:*)") for rule in allowed))
        self.assertNotIn("--resume", cmd)
        self.assertIn("--resume", ai.claude_command("oi", "0" * 36))

    def test_ai_action_rejects_unlisted_commands(self):
        with patch("builtins.print") as printed, self.assertRaises(SystemExit):
            ai.action_cli(['{"command": "shell", "application": "rm -rf /"}'])
        self.assertIn('"ok": false', printed.call_args.args[0])

    def test_unknown_provider_falls_back_to_claude(self):
        with patch.object(ai.core, "read_settings", return_value={"assistant": {"provider": "gpt"}}):
            self.assertEqual(ai.provider(), "claude")
        with patch.object(ai.core, "read_settings", return_value={"assistant": {"provider": "ollama"}}):
            self.assertEqual(ai.provider(), "ollama")
