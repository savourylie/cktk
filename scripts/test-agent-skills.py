#!/usr/bin/env python3
"""Exercise installation on isolated homes; never touch real agent settings."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts/agent-skills.py"
spec = importlib.util.spec_from_file_location("agent_skills", SCRIPT)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
CATALOG = json.loads((ROOT / "catalog.json").read_text())["skills"]
PORTABLE = [s["name"] for s in CATALOG if s.get("portable")]


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cktk-install-test-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name).resolve()
        self.home = self.directory / "home"

    def call(self, command="install", *arguments, expected=0):
        result = subprocess.run([sys.executable, str(SCRIPT), command, "--home", str(self.home), *map(str, arguments)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def receipt(self):
        return json.loads((self.home / ".local/share/cktk/install.json").read_text())

    def old_checkout(self):
        old = self.directory / "old-cktk"
        (old / ".claude-plugin").mkdir(parents=True)
        (old / "catalog.json").write_text('{"name":"cktk"}')
        (old / ".claude-plugin/plugin.json").write_text('{"name":"cktk"}')
        return old

    def test_portable_identity_resources_and_idempotence(self):
        self.call()
        first = self.receipt()
        for name in PORTABLE:
            source = ROOT / "skills" / name
            for destination in (self.home / ".agents/skills" / name, self.home / ".claude/skills" / name,
                                self.home / ".agent/skills" / name, ROOT / ".agents/skills" / name):
                self.assertEqual(destination.resolve(), source)
                self.assertTrue((destination / "agents/openai.yaml").is_file())
            self.assertFalse((self.home / ".codex/skills" / name).exists())
            self.assertFalse((self.home / ".config/opencode/skills" / name).exists())
        self.assertTrue((self.home / ".agents/skills/implement-ticket-linear/references/business-context.md").is_file())
        self.assertTrue((self.home / ".agents/skills/implement-ticket-linear/scripts/run-ticket-executor.sh").is_file())
        self.assertEqual((self.home / ".codex/skills/merge-worktree").resolve(), ROOT / ".agents/skills/merge-worktree")
        self.assertIn("Reconciled 0 path(s)", self.call())
        self.assertEqual(self.receipt(), first)
        self.call("doctor")

    def test_migrate_owned_old_links_and_preserve_private_skill(self):
        old = self.old_checkout()
        for tree in ("skills", ".agents/skills", ".agent/skills"):
            (old / tree).mkdir(parents=True)
            for name in PORTABLE:
                (old / tree / name).mkdir()
                (old / tree / name / "SKILL.md").write_text("old workflow")
        for destination, source in ((".codex/skills", ".agents/skills"), (".config/opencode/skills", "skills")):
            parent = self.home / destination
            parent.mkdir(parents=True)
            for name in PORTABLE:
                (parent / name).symlink_to(old / source / name)
        (self.home / ".agent").mkdir()
        (self.home / ".agent/skills").symlink_to(old / ".agent/skills")
        private = self.home / ".codex/skills/private-skill"
        private.mkdir()
        (private / "SKILL.md").write_text("personal content")
        self.call()
        self.call("doctor")
        self.assertEqual((private / "SKILL.md").read_text(), "personal content")
        self.assertEqual((self.home / ".agent/skills").resolve(), ROOT / ".agent/skills")
        self.assertEqual(self.call("source").strip(), str(ROOT))

    def test_same_name_copy_is_not_proof_of_ownership(self):
        destination = self.home / ".codex/skills/cktk-upgrade"
        destination.mkdir(parents=True)
        content = "---\nname: cktk-upgrade\n---\nMy own customized workflow.\n"
        (destination / "SKILL.md").write_text(content)
        self.assertIn("No installation paths were changed", self.call(expected=1))
        self.assertEqual((destination / "SKILL.md").read_text(), content)
        self.assertFalse((self.home / ".agents").exists())
        self.assertFalse((self.home / ".local/share/cktk/install.json").exists())

    def test_foreign_symlink_and_shell_helper_are_preserved(self):
        target = self.directory / "private"
        target.mkdir()
        destination = self.home / ".agents/skills/commit-ticket"
        destination.parent.mkdir(parents=True)
        destination.symlink_to(target)
        self.call(expected=1)
        self.assertEqual(destination.resolve(), target)
        destination.unlink()
        helper = self.home / ".local/bin/codex-handoff"
        helper.parent.mkdir(parents=True)
        helper.write_text("my script")
        self.call(expected=1)
        self.assertEqual(helper.read_text(), "my script")
        self.assertFalse((self.home / ".claude").exists())

    def test_identical_copy_is_backed_up(self):
        destination = self.home / ".codex/skills/cktk-upgrade"
        shutil.copytree(ROOT / ".agents/skills/cktk-upgrade", destination, symlinks=False)
        original = (destination / "SKILL.md").read_bytes()
        self.call()
        self.assertTrue(destination.is_symlink())
        copies = list((self.home / ".local/share/cktk").glob("copies-*/*/SKILL.md"))
        self.assertEqual(len(copies), 1)
        self.assertEqual(copies[0].read_bytes(), original)

    def test_doctor_detects_drift_and_installer_repairs_it(self):
        self.call()
        path = self.home / ".agents/skills/commit-ticket"
        path.unlink()
        self.assertIn("missing or different source", self.call("doctor", expected=1))
        self.call()
        self.call("doctor")
        duplicate = self.home / ".codex/skills/commit-ticket"
        duplicate.symlink_to(ROOT / "skills/commit-ticket")
        self.assertIn("duplicate skill entry", self.call("doctor", expected=1))
        self.call()
        self.assertFalse(duplicate.is_symlink())

    def test_identical_portable_copy_in_obsolete_directory_is_backed_up(self):
        destination = self.home / ".codex/skills/create-tickets"
        shutil.copytree(ROOT / "skills/create-tickets", destination, symlinks=False)
        original = (destination / "SKILL.md").read_bytes()
        self.call()
        self.assertFalse(destination.exists())
        copies = list((self.home / ".local/share/cktk").glob("copies-*/*/SKILL.md"))
        self.assertEqual([p.read_bytes() for p in copies], [original])
        self.call("doctor")

    def test_old_native_grok_and_shared_legacy_entries_are_diagnosed_and_removed(self):
        self.call()
        old = self.old_checkout()
        (old / "skills/cktk-upgrade").mkdir(parents=True)
        (old / "skills/cktk-upgrade/SKILL.md").write_text("old upgrade workflow")
        for directory in (".grok/skills", ".opencode/skills", ".agents/skills"):
            parent = self.home / directory
            parent.mkdir(parents=True, exist_ok=True)
            (parent / "cktk-upgrade").symlink_to(old / "skills/cktk-upgrade")
        self.assertIn("duplicate skill entry", self.call("doctor", expected=1))
        self.call()
        for directory in (".grok/skills", ".opencode/skills", ".agents/skills"):
            self.assertFalse((self.home / directory / "cktk-upgrade").is_symlink())
        self.call("doctor")

    def test_recorded_broken_link_can_be_repaired(self):
        self.call()
        path = self.home / ".agents/skills/commit-ticket"
        path.unlink()
        missing = self.directory / "removed-checkout/skills/commit-ticket"
        path.symlink_to(missing)
        receipt = self.receipt()
        receipt["links"][str(path)] = str(missing)
        (self.home / ".local/share/cktk/install.json").write_text(json.dumps(receipt))
        self.call()
        self.assertEqual(path.resolve(), ROOT / "skills/commit-ticket")

    def test_plugin_mode_and_return_to_linked(self):
        self.call()
        self.call("install", "--mode", "plugin")
        self.assertFalse((self.home / ".claude/skills/commit-ticket").exists())
        self.assertEqual(self.receipt()["mode"], "plugin")
        self.call("doctor")
        self.call()
        self.assertEqual(self.receipt()["mode"], "plugin")
        self.call("install", "--mode", "linked")
        self.assertTrue((self.home / ".claude/skills/commit-ticket").is_symlink())

    def test_missing_registered_source_does_not_fall_back(self):
        self.call()
        receipt = self.receipt()
        receipt["source_root"] = str(self.directory / "removed")
        (self.home / ".local/share/cktk/install.json").write_text(json.dumps(receipt))
        self.assertIn("registered checkout is unavailable", self.call("source", expected=1))
        self.assertEqual(self.call("source", "--source", ROOT).strip(), str(ROOT))

    def test_project_ignore_is_explicit_idempotent_and_scoped(self):
        project = self.directory / "project"
        project.mkdir()
        subprocess.run(["git", "init", "-q", str(project)], check=True)
        (project / ".gitignore").write_text("keep-this")
        self.call()
        self.assertEqual((project / ".gitignore").read_text(), "keep-this")
        self.call("install", "--project-root", project)
        self.call("install", "--project-root", project)
        self.assertEqual((project / ".gitignore").read_text(), "keep-this\n.ai/handoffs/\n.ai/interactions/\n")

    def test_runtime_inventory_cannot_silently_omit_portable_skills(self):
        def inventory(*args):
            return '{"skills":[]}' if args[0] == "grok" else '[]'
        with patch.object(installer.shutil, "which", return_value="/fixture/cli"), \
                patch.object(installer, "run", side_effect=inventory), contextlib.redirect_stdout(io.StringIO()):
            problems = installer.runtime_doctor(ROOT, CATALOG, "linked")
        for name in PORTABLE:
            self.assertTrue(any(f"Grok did not discover {name}" == p for p in problems))
            self.assertTrue(any(f"OpenCode did not discover {name}" == p for p in problems))

    def test_absent_clis_are_explicitly_unverified(self):
        output = io.StringIO()
        with patch.object(installer.shutil, "which", return_value=None), \
                patch.object(installer, "run") as command, contextlib.redirect_stdout(output):
            installer.runtime_doctor(ROOT, CATALOG, "linked")
            command.assert_not_called()
        self.assertIn("UNVERIFIED (CLI unavailable): claude, grok, opencode", output.getvalue())


class SkillChangesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cktk-changes-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve() / "cktk"
        self.root.mkdir()
        (self.root / ".claude-plugin").mkdir()
        (self.root / ".claude-plugin/plugin.json").write_text('{"name":"cktk"}\n')
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        for key, value in (("user.email", "test@example.com"), ("user.name", "test"),
                           ("commit.gpgsign", "false")):
            subprocess.run(["git", "-C", str(self.root), "config", key, value], check=True)
        self.write_catalog("1.0.0", ("alpha",))
        self.write_skill("alpha", "first")
        self.baseline = self.commit("initial")

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True,
                              capture_output=True, text=True).stdout.strip()

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def write_catalog(self, version, names, descriptions=None):
        descriptions = descriptions or {}
        skills = [{"name": name, "path": f".agent/skills/{name}",
                   "description": descriptions.get(name, name)} for name in names]
        payload = {"name": "cktk", "version": version, "skills": skills}
        (self.root / "catalog.json").write_text(json.dumps(payload, indent=2) + "\n")

    def write_skill(self, name, body):
        directory = self.root / "skills" / name
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "SKILL.md").write_text(body + "\n")

    def report(self, *arguments, expected=0):
        command = [sys.executable, str(SCRIPT), "changes", "--source", str(self.root), *arguments]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_changes_requires_from(self):
        self.assertIn("changes requires --from", self.report(expected=1))

    def test_unchanged_revision_has_no_skill_inventory_changes(self):
        output = self.report("--from", self.baseline)
        self.assertIn("No skill inventory changes.", output)
        self.assertNotIn("Skills added:", output)
        self.assertNotIn("Skills removed:", output)
        self.assertNotIn("Skills updated:", output)

    def test_reports_added_removed_updated_skills_and_other_files(self):
        self.write_skill("gamma", "soon gone")
        self.write_catalog("1.0.0", ("alpha", "gamma"))
        self.baseline = self.commit("add gamma")
        self.write_skill("alpha", "revised")
        self.write_skill("beta", "new")
        shutil.rmtree(self.root / "skills" / "gamma")
        self.write_catalog("1.1.0", ("alpha", "beta"))
        (self.root / "README.md").write_text("notes\n")
        self.commit("add beta, drop gamma, edit alpha")
        output = self.report("--from", self.baseline)
        self.assertIn("catalog 1.0.0 → 1.1.0", output)
        self.assertIn("Skills added:\n- beta", output)
        self.assertIn("Skills removed:\n- gamma", output)
        self.assertIn("Skills updated:\n- alpha", output)
        self.assertIn("Other changes:\n- README.md", output)
        self.assertIn("Commits:\n- ", output)

    def test_catalog_description_change_counts_as_updated(self):
        self.write_catalog("1.0.0", ("alpha",), {"alpha": "new purpose"})
        self.commit("reword alpha")
        output = self.report("--from", self.baseline)
        self.assertIn("Skills updated:\n- alpha", output)
        self.assertNotIn("Skills added:", output)

    def test_dirty_working_tree_is_marked_and_compared(self):
        self.write_skill("alpha", "uncommitted")
        output = self.report("--from", self.baseline)
        self.assertIn(" dirty", output)
        self.assertIn("Skills updated:\n- alpha", output)
        clean = self.report("--from", self.baseline, "--to", "HEAD")
        self.assertNotIn(" dirty", clean)
        self.assertIn("No skill inventory changes.", clean)


if __name__ == "__main__":
    unittest.main(verbosity=2)
