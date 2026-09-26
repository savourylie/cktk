#!/usr/bin/env python3
"""Exercise implement-backlog-linear's planner without Linear or a live model."""
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "skills/implement-backlog-linear/scripts/backlog_graph.py"
spec = importlib.util.spec_from_file_location("backlog_graph", SCRIPT)
graph = importlib.util.module_from_spec(spec)
spec.loader.exec_module(graph)

WEB = {"id": "p-web", "name": "Website"}
API = {"id": "p-api", "name": "API"}
ME = "user-me"
IDENT = ("-c", "user.email=test@example.com", "-c", "user.name=Test", "-c", "commit.gpgsign=false")


def issue(issue_id, state="backlog", labels=(), assignee=None, project=WEB,
          parent=None, blocked_by=(), blocks=(), local_work=False):
    return {"id": issue_id, "title": f"Title {issue_id}", "state_type": state,
            "labels": list(labels), "assignee": assignee, "project": project,
            "parent": parent, "blocked_by": list(blocked_by), "blocks": list(blocks),
            "local_work": local_work}


def snapshot(*issues, external=(), requested=None, bound=None):
    return {"team": {"id": "t-eng", "key": "ENG"}, "me": ME,
            "requested_project": requested, "binding_project": bound,
            "issues": list(issues), "external": list(external)}


def plan_for(*issues, **options):
    return graph.select(graph.load_snapshot(snapshot(*issues, **options)))


def run_cli(*args):
    return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                          capture_output=True, text=True, timeout=60)


class ScopeTests(unittest.TestCase):
    def test_requested_project_keeps_only_its_issues(self):
        plan = plan_for(issue("ENG-1"), issue("ENG-2", project=API), requested=WEB)
        self.assertEqual(plan["status"], "planned")
        self.assertEqual(plan["order"], ["ENG-1"])
        self.assertNotIn("ENG-2", plan["excluded"])

    def test_binding_to_another_project_stops(self):
        plan = plan_for(issue("ENG-1"), requested=WEB, bound=API)
        self.assertEqual(plan["status"], "stop")
        self.assertEqual(plan["scope"]["reason"], "binding-mismatch")

    def test_team_spanning_projects_stops_and_marks_the_bound_one(self):
        plan = plan_for(issue("ENG-1"), issue("ENG-2", project=API), bound=API)
        self.assertEqual(plan["scope"]["reason"], "multiple-projects")
        self.assertEqual([(p["name"], p["bound"]) for p in plan["scope"]["projects"]],
                         [("API", True), ("Website", False)])

    def test_single_project_team_includes_issues_without_a_project(self):
        plan = plan_for(issue("ENG-1"), issue("ENG-2", project=None))
        self.assertEqual(plan["scope"]["project"], WEB)
        self.assertEqual(plan["order"], ["ENG-1", "ENG-2"])

    def test_team_without_projects_plans_the_team(self):
        plan = plan_for(issue("ENG-1", project=None))
        self.assertIsNone(plan["scope"]["project"])
        self.assertEqual(plan["order"], ["ENG-1"])

    def test_binding_to_another_project_stops_without_a_request(self):
        plan = plan_for(issue("ENG-1"), bound=API)
        self.assertEqual(plan["scope"]["reason"], "binding-mismatch")


class ClassificationTests(unittest.TestCase):
    def test_each_row_of_the_classification_table(self):
        plan = plan_for(
            issue("ENG-1", labels=["Human-Setup"]),
            issue("ENG-2", labels=["human-acceptance", "human-blocked"]),
            issue("ENG-3", assignee="someone"),
            issue("ENG-4", state="triage"),
            issue("ENG-5", state="started"),
            issue("ENG-6", state="started", local_work=True),
            issue("ENG-7", state="unstarted", assignee=ME),
            issue("ENG-8"),
        )
        excluded = plan["excluded"]
        self.assertEqual(excluded["ENG-1"], {"reason": "human-gate", "label": "human-setup"})
        self.assertEqual(excluded["ENG-2"], {"reason": "human-gate", "label": "human-blocked"})
        self.assertEqual(excluded["ENG-3"], {"reason": "someone-else"})
        self.assertEqual(excluded["ENG-4"], {"reason": "not-triaged"})
        self.assertEqual(excluded["ENG-5"], {"reason": "running-elsewhere"})
        self.assertEqual(plan["order"], ["ENG-6", "ENG-7", "ENG-8"])

    def test_terminal_issues_in_the_snapshot_are_never_work(self):
        plan = plan_for(issue("ENG-1", state="completed"), issue("ENG-2", state="canceled"), issue("ENG-3"))
        self.assertEqual(plan["order"], ["ENG-3"])
        self.assertEqual(plan["excluded"], {})


class DependencyTests(unittest.TestCase):
    def test_a_gate_blocks_its_dependents_transitively(self):
        plan = plan_for(issue("ENG-1", labels=["human-acceptance"]),
                        issue("ENG-2", blocked_by=["ENG-1"]),
                        issue("ENG-3", blocked_by=["ENG-2"]),
                        issue("ENG-4"))
        self.assertEqual(plan["order"], ["ENG-4"])
        self.assertEqual(plan["excluded"]["ENG-3"],
                         {"reason": "blocked", "via": ["ENG-2"], "roots": ["human-acceptance:ENG-1"]})

    def test_a_relation_recorded_only_as_blocks_is_still_an_edge(self):
        plan = plan_for(issue("ENG-1", blocks=["ENG-2"]), issue("ENG-2"))
        self.assertEqual(plan["layers"], [["ENG-1"], ["ENG-2"]])
        self.assertEqual(plan["edges"]["ENG-2"], ["ENG-1"])

    def test_blockers_outside_the_open_scope(self):
        plan = plan_for(
            issue("ENG-1", blocked_by=["ENG-90"]),
            issue("ENG-2", blocked_by=["DATA-7"]),
            issue("ENG-3", blocked_by=["ENG-91"]),
            issue("ENG-4", blocked_by=["ENG-92"]),
            external=[{"id": "ENG-90", "state_type": "completed"},
                      {"id": "DATA-7", "state_type": "started"},
                      {"id": "ENG-91", "state_type": "canceled"}])
        self.assertEqual(plan["order"], ["ENG-1"])
        self.assertEqual(plan["excluded"]["ENG-2"]["roots"], ["outside-scope:DATA-7"])
        self.assertEqual(plan["excluded"]["ENG-3"]["roots"], ["canceled:ENG-91"])
        self.assertEqual(plan["excluded"]["ENG-4"]["roots"], ["unknown:ENG-92"])

    def test_an_open_issue_of_another_project_is_outside_the_scope(self):
        plan = plan_for(issue("ENG-1", blocked_by=["ENG-2"]), issue("ENG-2", project=API), requested=WEB)
        self.assertEqual(plan["excluded"]["ENG-1"]["roots"], ["outside-scope:ENG-2"])

    def test_a_parent_waits_for_its_sub_issues(self):
        plan = plan_for(issue("ENG-1"), issue("ENG-2", parent="ENG-1"), issue("ENG-3", parent="ENG-1"))
        self.assertEqual(plan["layers"], [["ENG-2", "ENG-3"], ["ENG-1"]])
        self.assertEqual(plan["edges"]["ENG-1"], ["ENG-2", "ENG-3"])

    def test_a_gated_sub_issue_keeps_its_parent_out(self):
        plan = plan_for(issue("ENG-1"), issue("ENG-2", parent="ENG-1", labels=["human-setup"]),
                        issue("ENG-3", parent="ENG-1"))
        self.assertEqual(plan["order"], ["ENG-3"])
        self.assertEqual(plan["excluded"]["ENG-1"]["roots"], ["human-setup:ENG-2"])

    def test_cycle_members_and_their_dependents(self):
        plan = plan_for(issue("ENG-1", blocked_by=["ENG-2"]), issue("ENG-2", blocked_by=["ENG-1"]),
                        issue("ENG-3", blocked_by=["ENG-1"]), issue("ENG-4"))
        self.assertEqual(plan["order"], ["ENG-4"])
        self.assertEqual(plan["excluded"]["ENG-1"], {"reason": "cycle", "via": ["ENG-2"]})
        self.assertEqual(plan["excluded"]["ENG-2"], {"reason": "cycle", "via": ["ENG-1"]})
        self.assertEqual(plan["excluded"]["ENG-3"]["roots"], ["cycle:ENG-1"])

    def test_nothing_eligible(self):
        plan = plan_for(issue("ENG-1", labels=["human-setup"]))
        self.assertEqual(plan["status"], "nothing-eligible")
        self.assertEqual(plan["order"], [])


class IdentifierTests(unittest.TestCase):
    def test_identifiers_are_normalized_and_ordered_numerically(self):
        plan = plan_for(issue("eng-10", blocked_by=["eng-9"]), issue("ENG-9"), issue("Eng-2"))
        self.assertEqual(plan["layers"], [["ENG-2", "ENG-9"], ["ENG-10"]])

    def test_team_keys_with_digits(self):
        plan = plan_for(issue("A1B-12"), issue("A1B-3"))
        self.assertEqual(plan["order"], ["A1B-3", "A1B-12"])

    def test_duplicate_entries_merge_their_relations(self):
        plan = plan_for(issue("ENG-3"), issue("ENG-1"), issue("ENG-3", blocked_by=["ENG-1"]))
        self.assertEqual(plan["edges"]["ENG-3"], ["ENG-1"])

    def test_malformed_identifier_is_an_input_error(self):
        with self.assertRaises(graph.InputError):
            graph.load_snapshot(snapshot(issue("not an id")))


class RunIdTests(unittest.TestCase):
    def test_run_ids_slug_the_project_and_stay_unique(self):
        now = datetime(2026, 9, 26, 14, 30, tzinfo=timezone.utc)
        with tempfile.TemporaryDirectory() as runs:
            self.assertEqual(graph.make_run_id("ENG", {"id": "p", "name": "Account Platform"}, now, runs),
                             "ENG-account-platform-20260926-1430")
            self.assertEqual(graph.make_run_id("ENG", {"id": "p", "name": "網站改版"}, now, runs),
                             "ENG-project-20260926-1430")
            self.assertEqual(graph.make_run_id("ENG", None, now, runs), "ENG-team-20260926-1430")
            Path(runs, "ENG-team-20260926-1430").mkdir()
            self.assertEqual(graph.make_run_id("ENG", None, now, runs), "ENG-team-20260926-1430-2")


class LocalWorkParsingTests(unittest.TestCase):
    def test_worktrees_branches_and_landing_merges(self):
        root = os.path.realpath(tempfile.gettempdir())
        porcelain = (f"worktree {root}/repo\nHEAD abc\nbranch refs/heads/main\n\n"
                     f"worktree {root}/repo/.worktrees/ENG-12-add-csv\nHEAD def\n"
                     "branch refs/heads/linear-ENG-12-add-csv\n\n"
                     f"worktree {root}/elsewhere/ENG-99-other\nHEAD 123\n")
        self.assertEqual(graph.worktree_ids(porcelain, f"{root}/repo"), {"ENG-12"})
        self.assertEqual(graph.branch_ids("main\nlinear-ENG-5-fix\nlinear-eng-6-x\nfeature\n"),
                         {"ENG-5", "ENG-6"})
        subjects = "Merge linear-ENG-7-bar into main\nMerge linear-ENG-8-baz into dev\nMerge branch 'x'\n"
        self.assertEqual(graph.landed_ids(subjects, "main"), {"ENG-7"})


class PlanCommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cktk-backlog-test-")
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name).resolve()
        self.runs = self.dir / "runs"

    def write_snapshot(self, data):
        path = self.dir / "snapshot.json"
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        return path

    def test_a_planned_run_writes_its_directory(self):
        path = self.write_snapshot(snapshot(issue("ENG-1"), issue("ENG-2", blocked_by=["ENG-1"]), requested=WEB))
        result = run_cli("plan", "--snapshot", path, "--runs-dir", self.runs,
                         "--now", "2026-09-26T14:30:00Z", "--host", "claude")
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["run_id"], "ENG-website-20260926-1430")
        run_dir = self.runs / "ENG-website-20260926-1430"
        stored = json.loads((run_dir / "plan.json").read_text(encoding="utf-8"))
        self.assertEqual(stored["order"], ["ENG-1", "ENG-2"])
        self.assertEqual(stored["host"], "claude")
        self.assertTrue((run_dir / "snapshot.json").is_file())
        self.assertTrue((run_dir / "results").is_dir())

    def test_stop_nothing_eligible_and_dry_run_create_no_directory(self):
        for data in (snapshot(issue("ENG-1"), issue("ENG-2", project=API)),
                     snapshot(issue("ENG-1", labels=["human-setup"]))):
            result = run_cli("plan", "--snapshot", self.write_snapshot(data), "--runs-dir", self.runs)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIsNone(json.loads(result.stdout)["run_dir"])
        result = run_cli("plan", "--snapshot", self.write_snapshot(snapshot(issue("ENG-1"))),
                         "--runs-dir", self.runs, "--dry-run")
        self.assertEqual(json.loads(result.stdout)["status"], "planned")
        self.assertFalse(self.runs.exists())

    def test_unusable_input_exits_2(self):
        bad = self.dir / "bad.json"
        bad.write_text("{", encoding="utf-8")
        self.assertEqual(run_cli("plan", "--snapshot", bad, "--runs-dir", self.runs).returncode, 2)
        result = run_cli("plan", "--snapshot", self.write_snapshot(snapshot(issue("ENG-1"))),
                         "--runs-dir", self.runs, "--parallel", "0")
        self.assertEqual(result.returncode, 2)

    def test_repo_local_work_lets_a_started_issue_resume(self):
        repo = self.dir / "repo"

        def git(*args):
            subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True)

        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
        git(*IDENT, "commit", "-q", "--allow-empty", "-m", "init")
        git("branch", "linear-ENG-5-resume-me")
        git("switch", "-q", "-c", "linear-ENG-7-landed")
        git(*IDENT, "commit", "-q", "--allow-empty", "-m", "work")
        git("switch", "-q", "main")
        git(*IDENT, "merge", "-q", "--no-ff", "-m", "Merge linear-ENG-7-landed into main", "linear-ENG-7-landed")
        git("branch", "-q", "-D", "linear-ENG-7-landed")
        path = self.write_snapshot(snapshot(issue("ENG-5", state="started"), issue("ENG-6", state="started"),
                                            issue("ENG-7", state="started")))
        result = run_cli("plan", "--snapshot", path, "--runs-dir", self.runs, "--repo", repo, "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["order"], ["ENG-5", "ENG-7"])
        self.assertEqual(output["excluded"]["ENG-6"], {"reason": "running-elsewhere"})
        self.assertEqual(output["repo"], os.path.realpath(repo))


if __name__ == "__main__":
    unittest.main()
