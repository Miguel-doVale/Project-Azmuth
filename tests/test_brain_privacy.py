"""O cérebro é a vida pessoal do Miguel: nada dele pode cair no repositório."""
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
import brain  # noqa: E402
import core  # noqa: E402

TEXT_EXT = {".py", ".qml", ".js", ".lua", ".json", ".yaml", ".yml", ".sh", ".conf", ".tmpl", ".html", ".css", ".md", ".txt"}
SKIP_DIRS = {".git", ".venv", "__pycache__", "node_modules", ".superpowers", "docs", "tests"}


class BrainPrivacyTests(unittest.TestCase):
    def test_vault_is_outside_repo(self):
        with patch.dict(os.environ, {"AZMUTH_BRAIN": ""}):
            vault = brain.vault_path().resolve()
        self.assertNotIn(core.ROOT.resolve(), [vault, *vault.parents])

    def test_no_repo_file_contains_the_vault_path_literal(self):
        with patch.dict(os.environ, {"AZMUTH_BRAIN": ""}):
            literal = str(brain.vault_path())
        hits = []
        for p in ROOT.rglob("*"):
            rel = p.relative_to(ROOT)
            if any(part in SKIP_DIRS for part in rel.parts) or not p.is_file() or p.suffix not in TEXT_EXT:
                continue
            try:
                if literal in p.read_text(encoding="utf-8", errors="ignore"):
                    hits.append(rel.as_posix())
            except OSError:
                continue
        self.assertEqual(hits, [])

    def test_gitignore_blocks_vault_dirs_inside_repo(self):
        lines = {l.strip() for l in (ROOT / ".gitignore").read_text(encoding="utf-8").splitlines()}
        for needed in ["Cérebro/", "*.vault", ".obsidian/"]:
            self.assertIn(needed, lines)

    def test_restricted_note_outside_its_folder_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            vault = Path(tmp)
            (vault / "Pessoas").mkdir()
            (vault / "Pessoas/Bruno.md").write_text("---\nresumo: x\nacesso: identidade\n---\nx", encoding="utf-8")
            self.assertEqual(brain.placement_errors(vault), ["Pessoas/Bruno.md"])

    def test_statement_inbox_is_outside_vault_and_repo(self):
        inbox = brain.INBOX.resolve()
        self.assertNotIn(core.ROOT.resolve(), [inbox, *inbox.parents])


if __name__ == "__main__":
    unittest.main()
