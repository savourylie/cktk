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
          parent=None, blocked_by=(), blocks=(), local_work=False, title=None):
    return {"id": issue_id, "title": title or f"Title {issue_id}", "state_type": state,
            "labels": list(labels), "assignee": assignee, "project": project,
            "parent": parent, "blocked_by": list(blocked_by), "blocks": list(blocks),
            "local_work": local_work}


def snapshot(*issues, external=(), requested=None, bound=None):
    return {"team": {"id": "t-eng", "key": "ENG"}, "me": ME,
            "requested_project": requested, "binding_project": bound,
            "issues": list(issues), "external": list(external)}


def plan_for(*issues, **options):
    return graph.select(graph.load_snapshot(snapshot(*issues, **options)))


def epic_plan(epic_id, *issues, **options):
    data = snapshot(*issues, **options)
    data["requested_epic"] = {"id": epic_id}
    return graph.select(graph.load_snapshot(data))


def run_cli(*args, env=None):
    return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                          capture_output=True, text=True, timeout=60,
                          env={**os.environ, **(env or {})})


def planned(*issues, **options):
    """A plan as stored in plan.json, for next-step tests."""
    plan = plan_for(*issues, **options)
    plan.update({"run_id": "ENG-website-20260926-1430", "me": ME, "base": "main"})
    return plan


def state(issues, in_flight=(), external=None):
    """A state.json body; a bare string is a state type with no labels."""
    return {"issues": {k: (v if isinstance(v, dict) else {"state_type": v, "labels": []})
                       for k, v in issues.items()},
            "in_flight": list(in_flight), "external": external or {}}


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

    def test_duplicate_is_terminal_and_not_delivery(self):
        plan = plan_for(issue("ENG-1", state="duplicate"),
                        issue("ENG-2", blocked_by=["DATA-9"]),
                        issue("ENG-3", blocked_by=["ENG-1"]), issue("ENG-4"),
                        external=[{"id": "DATA-9", "state_type": "duplicate"}])
        self.assertEqual(plan["order"], ["ENG-4"])
        self.assertNotIn("ENG-1", plan["excluded"])
        self.assertEqual(plan["excluded"]["ENG-2"]["roots"], ["duplicate:DATA-9"])
        self.assertEqual(plan["excluded"]["ENG-3"]["roots"], ["duplicate:ENG-1"])

    def test_nothing_eligible(self):
        plan = plan_for(issue("ENG-1", labels=["human-setup"]))
        self.assertEqual(plan["status"], "nothing-eligible")
        self.assertEqual(plan["order"], [])


class EpicTests(unittest.TestCase):
    def test_an_epic_without_open_sub_issues_is_not_broken_down(self):
        plan = plan_for(issue("ENG-1", title="[Epic] Proactive calling"),
                        issue("ENG-2", blocked_by=["ENG-1"]), issue("ENG-3"))
        self.assertEqual(plan["excluded"]["ENG-1"], {"reason": "epic-not-broken-down"})
        self.assertEqual(plan["excluded"]["ENG-2"]["roots"], ["epic-not-broken-down:ENG-1"])
        self.assertEqual(plan["order"], ["ENG-3"])

    def test_an_epic_with_open_sub_issues_waits_for_them(self):
        plan = plan_for(issue("ENG-1", title="[EPIC] Memory layer"), issue("ENG-2", parent="ENG-1"))
        self.assertEqual(plan["layers"], [["ENG-2"], ["ENG-1"]])

    def test_the_epic_marker_must_lead_the_title(self):
        plan = plan_for(issue("ENG-1", title="  [epic] lowercase marker"),
                        issue("ENG-2", title="Split the [Epic] banner"))
        self.assertEqual(plan["excluded"]["ENG-1"], {"reason": "epic-not-broken-down"})
        self.assertEqual(plan["order"], ["ENG-2"])


class EpicScopeTests(unittest.TestCase):
    def test_an_epic_scope_is_its_descendants_and_the_epic(self):
        plan = epic_plan("ENG-1",
                         issue("ENG-1", title="[Epic] Memory"),
                         issue("ENG-2", parent="ENG-1"),
                         issue("ENG-3", parent="ENG-2"),
                         issue("ENG-9"))
        self.assertEqual(plan["layers"], [["ENG-3"], ["ENG-2"], ["ENG-1"]])
        self.assertNotIn("ENG-9", plan["excluded"])
        self.assertEqual(plan["scope"]["epic"], "ENG-1")

    def test_descendants_are_reached_through_a_finished_sub_issue(self):
        plan = epic_plan("ENG-1",
                         issue("ENG-1", title="[Epic] Memory"),
                         issue("ENG-2", state="completed", parent="ENG-1"),
                         issue("ENG-3", parent="ENG-2"), issue("ENG-9"))
        self.assertEqual(plan["layers"], [["ENG-3"], ["ENG-1"]])

    def test_other_projects_and_outside_blockers_stay_out(self):
        plan = epic_plan("ENG-1",
                         issue("ENG-1", title="[Epic] Memory"),
                         issue("ENG-2", parent="ENG-1", blocked_by=["ENG-9"]),
                         issue("ENG-4", parent="ENG-1", project=API),
                         issue("ENG-5", parent="ENG-1"),
                         issue("ENG-9"))
        self.assertEqual(plan["order"], ["ENG-5"])
        self.assertEqual(plan["excluded"]["ENG-2"]["roots"], ["outside-scope:ENG-9"])
        self.assertEqual(plan["excluded"]["ENG-1"],
                         {"reason": "blocked", "via": ["ENG-2", "ENG-4"],
                          "roots": ["outside-scope:ENG-4", "outside-scope:ENG-9"]})
        self.assertNotIn("ENG-4", plan["excluded"])

    def test_descendants_in_other_teams_stay_out(self):
        plan = epic_plan("ENG-1",
                         issue("ENG-1", title="[Epic] Memory"),
                         issue("ENG-2", parent="ENG-1"),
                         issue("OPS-3", parent="ENG-1"))
        self.assertEqual(plan["order"], ["ENG-2"])
        self.assertEqual(plan["excluded"]["ENG-1"]["roots"], ["outside-scope:OPS-3"])
        self.assertNotIn("OPS-3", plan["excluded"])

    def test_sub_issues_known_only_by_reference_hold_the_epic(self):
        epic = issue("ENG-1", title="[Epic] Memory")
        epic["sub_issues"] = ["OPS-4"]
        plan = epic_plan("ENG-1", epic, issue("ENG-2", parent="ENG-1"),
                         external=[{"id": "OPS-4", "state_type": "started"}])
        self.assertEqual(plan["order"], ["ENG-2"])
        self.assertEqual(plan["excluded"]["ENG-1"]["roots"], ["outside-scope:OPS-4"])

    def test_mismatches_and_missing_epics_stop(self):
        for options, reason in (({"requested": API}, "epic-project-mismatch"), ({"bound": API}, "binding-mismatch")):
            plan = epic_plan("ENG-1", issue("ENG-1", title="[Epic] X"), issue("ENG-2", parent="ENG-1"), **options)
            self.assertEqual((plan["status"], plan["scope"]["reason"]), ("stop", reason))
        self.assertEqual(epic_plan("ENG-7", issue("ENG-1"))["scope"]["reason"], "epic-not-found")
        self.assertEqual(epic_plan("ENG-1", issue("ENG-1", state="completed"))["scope"]["reason"], "epic-closed")
        self.assertEqual(epic_plan("OPS-1", issue("OPS-1", title="[Epic] X"))["scope"]["reason"], "epic-team-mismatch")


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
                         "--now", "2026-09-26T14:30:00Z", "--host", "claude", env={"TZ": "UTC"})
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["run_id"], "ENG-website-20260926-1430")
        run_dir = self.runs / "ENG-website-20260926-1430"
        stored = json.loads((run_dir / "plan.json").read_text(encoding="utf-8"))
        self.assertEqual(stored["order"], ["ENG-1", "ENG-2"])
        self.assertEqual(stored["host"], "claude")
        self.assertTrue((run_dir / "snapshot.json").is_file())
        self.assertTrue((run_dir / "results").is_dir())

    def test_epic_run_ids_name_the_epic(self):
        data = snapshot(issue("ENG-1", title="[Epic] X"), issue("ENG-2", parent="ENG-1"))
        data["requested_epic"] = {"id": "eng-1"}
        result = run_cli("plan", "--snapshot", self.write_snapshot(data), "--runs-dir", self.runs,
                         "--now", "2026-09-26T14:30:00Z", env={"TZ": "UTC"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["run_id"], "ENG-1-20260926-1430")

    def test_run_ids_use_local_time(self):
        path = self.write_snapshot(snapshot(issue("ENG-1"), requested=WEB))
        result = run_cli("plan", "--snapshot", path, "--runs-dir", self.runs,
                         "--now", "2026-09-26T16:13:00Z", env={"TZ": "Asia/Taipei"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["run_id"], "ENG-website-20260927-0013")

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
        self.assertEqual(output["order"], ["ENG-5"])
        self.assertEqual(output["excluded"]["ENG-6"], {"reason": "running-elsewhere"})
        self.assertEqual(output["excluded"]["ENG-7"], {"reason": "running-elsewhere"})
        self.assertEqual(output["repo"], os.path.realpath(repo))
        tip = subprocess.run(["git", "-C", str(repo), "rev-parse", "main"], capture_output=True, text=True).stdout.strip()
        self.assertEqual(output["base_sha"], tip)

    def test_next_counts_only_landings_after_the_plan(self):
        repo = self.dir / "repo"

        def git(*args):
            subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True)

        def land(branch):
            git("switch", "-q", "-c", branch)
            git(*IDENT, "commit", "-q", "--allow-empty", "-m", "work")
            git("switch", "-q", "main")
            git(*IDENT, "merge", "-q", "--no-ff", "-m", f"Merge {branch} into main", branch)
            git("branch", "-q", "-D", branch)

        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
        git(*IDENT, "commit", "-q", "--allow-empty", "-m", "init")
        land("linear-ENG-1-reopened-after-an-earlier-landing")
        path = self.write_snapshot(snapshot(issue("ENG-1", state="unstarted"), issue("ENG-2")))
        result = run_cli("plan", "--snapshot", path, "--runs-dir", self.runs, "--repo", repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        land("linear-ENG-2-landed-by-this-run")
        state_path = self.dir / "state.json"
        state_path.write_text(json.dumps(state({"ENG-1": "unstarted", "ENG-2": "started"})), encoding="utf-8")
        step = run_cli("next", "--plan", Path(plan["run_dir"]) / "plan.json", "--state", state_path, "--repo", repo)
        self.assertEqual(step.returncode, 0, step.stderr)
        output = json.loads(step.stdout)
        self.assertEqual(output["landed_not_done"], ["ENG-2"])
        self.assertEqual(output["ready"], ["ENG-1"])

    def test_dispatched_markers_count_as_in_flight(self):
        path = self.write_snapshot(snapshot(issue("ENG-1"), issue("ENG-2"), requested=WEB))
        plan = json.loads(run_cli("plan", "--snapshot", path, "--runs-dir", self.runs).stdout)
        run_dir = Path(plan["run_dir"])
        (run_dir / "dispatched").mkdir()
        (run_dir / "dispatched" / "ENG-1").write_text("", encoding="utf-8")
        state_path = self.dir / "state.json"
        state_path.write_text(json.dumps(state({"ENG-1": "started", "ENG-2": "backlog"})), encoding="utf-8")
        result = run_cli("next", "--plan", run_dir / "plan.json", "--state", state_path)
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["in_flight"], ["ENG-1"])
        self.assertEqual(output["ready"], ["ENG-2"])


class NextStepTests(unittest.TestCase):
    def setUp(self):
        # ENG-1 → ENG-2 → ENG-3 is a chain, ENG-4 stands alone, ENG-9 is gated at plan time.
        self.plan = planned(issue("ENG-1"), issue("ENG-2", blocked_by=["ENG-1"]),
                            issue("ENG-3", blocked_by=["ENG-2"]), issue("ENG-4"),
                            issue("ENG-9", labels=["human-setup"]))

    def test_ready_follows_completed_blockers(self):
        step = graph.next_step(self.plan, state({"ENG-1": "backlog", "ENG-2": "backlog",
                                                 "ENG-3": "backlog", "ENG-4": "backlog"}))
        self.assertEqual(step["ready"], ["ENG-1", "ENG-4"])
        step = graph.next_step(self.plan, state({"ENG-1": "completed", "ENG-2": "backlog",
                                                 "ENG-3": "backlog", "ENG-4": "started"},
                                                in_flight=["ENG-4"]))
        self.assertEqual(step["ready"], ["ENG-2"])
        self.assertEqual(step["in_flight"], ["ENG-4"])
        self.assertEqual(step["done"], ["ENG-1"])

    def test_a_parked_issue_takes_its_dependents_out(self):
        step = graph.next_step(self.plan, state({
            "ENG-1": {"state_type": "started", "labels": ["human-blocked"]},
            "ENG-2": "backlog", "ENG-3": "backlog", "ENG-4": "completed"}))
        self.assertEqual(step["parked"], ["ENG-1"])
        self.assertEqual(step["removed"]["ENG-2"], {"reason": "blocked", "via": ["ENG-1"]})
        self.assertEqual(step["removed"]["ENG-3"], {"reason": "blocked", "via": ["ENG-2"]})
        self.assertEqual(step["counts"]["AI-ELIGIBLE"], 0)

    def test_new_gates_cancellation_and_reassignment_shrink_the_plan(self):
        step = graph.next_step(self.plan, state({
            "ENG-1": {"state_type": "backlog", "labels": ["human-acceptance"]},
            "ENG-2": "backlog", "ENG-3": "backlog",
            "ENG-4": {"state_type": "backlog", "labels": [], "assignee": "someone"}}))
        self.assertEqual(step["removed"]["ENG-1"], {"reason": "human-gate", "label": "human-acceptance"})
        self.assertEqual(step["removed"]["ENG-4"], {"reason": "someone-else"})
        self.assertEqual(step["ready"], [])
        step = graph.next_step(self.plan, state({"ENG-1": "canceled", "ENG-2": "backlog",
                                                 "ENG-3": "backlog", "ENG-4": "backlog"}))
        self.assertEqual(step["removed"]["ENG-1"], {"reason": "canceled"})
        self.assertEqual(step["removed"]["ENG-2"], {"reason": "blocked", "via": ["ENG-1"]})

    def test_a_planned_issue_marked_duplicate_leaves_the_plan(self):
        step = graph.next_step(self.plan, state({"ENG-1": "duplicate", "ENG-2": "backlog",
                                                 "ENG-3": "backlog", "ENG-4": "backlog"}))
        self.assertEqual(step["removed"]["ENG-1"], {"reason": "duplicate"})
        self.assertEqual(step["removed"]["ENG-2"], {"reason": "blocked", "via": ["ENG-1"]})

    def test_completion_elsewhere_counts_as_done(self):
        step = graph.next_step(self.plan, state({"ENG-1": "completed", "ENG-2": "completed",
                                                 "ENG-3": "backlog", "ENG-4": "completed"}))
        self.assertEqual(step["ready"], ["ENG-3"])
        self.assertEqual(step["counts"]["DONE"], 3)

    def test_landed_but_not_done_resumes_at_the_linear_update(self):
        step = graph.next_step(self.plan, state({"ENG-1": "started", "ENG-2": "backlog",
                                                 "ENG-3": "backlog", "ENG-4": "backlog"}),
                               landed=frozenset({"ENG-1"}))
        self.assertEqual(step["landed_not_done"], ["ENG-1"])
        self.assertEqual(step["ready"], ["ENG-4"])

    def test_a_new_unfinished_blocker_outside_the_plan_removes_the_issue(self):
        step = graph.next_step(self.plan, state(
            {"ENG-1": "backlog", "ENG-2": "backlog", "ENG-3": "backlog",
             "ENG-4": {"state_type": "backlog", "labels": [], "blocked_by": ["DATA-7", "OPS-1"]}},
            external={"DATA-7": {"state_type": "started"}, "OPS-1": {"state_type": "completed"}}))
        self.assertEqual(step["removed"]["ENG-4"], {"reason": "new-blocker", "via": ["DATA-7"]})

    def test_a_run_that_cannot_progress_ends_as_stuck(self):
        step = graph.next_step(self.plan, state({
            "ENG-1": {"state_type": "backlog", "labels": [], "blocked_by": ["ENG-3"]},
            "ENG-2": "backlog", "ENG-3": "backlog", "ENG-4": "completed"}))
        self.assertEqual(step["ready"], [])
        self.assertEqual(step["removed"]["ENG-1"], {"reason": "stuck", "via": ["ENG-3"]})
        self.assertEqual(step["counts"]["AI-ELIGIBLE"], 0)

    def test_status_lines(self):
        step = graph.next_step(self.plan, state({
            "ENG-1": "completed", "ENG-2": "backlog", "ENG-3": "backlog",
            "ENG-4": {"state_type": "started", "labels": ["human-blocked"]}}))
        self.assertEqual(step["status_line"],
                         "STATUS implement-backlog-linear RUN ENG-website-20260926-1430 · "
                         "AI-ELIGIBLE 2 · DONE 1 · PARKED 1 · HUMAN-GATED 1 · BLOCKED 0")
        self.assertEqual(graph.halted_line("ENG-website-20260926-1430", "base diverged\nfrom origin/main"),
                         "STATUS implement-backlog-linear RUN ENG-website-20260926-1430 · "
                         "HALTED · base diverged from origin/main")

    def test_a_missing_planned_issue_is_an_input_error(self):
        with self.assertRaises(graph.InputError):
            graph.next_step(self.plan, state({"ENG-1": "backlog"}))


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cktk-backlog-test-")
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name).resolve()

    def test_wait_reports_new_results_and_ignores_partial_writes(self):
        results = self.dir / "results"
        results.mkdir()
        (results / "ENG-1.json").write_text('{"verdict": "complete"}', encoding="utf-8")
        (results / "ENG-2.json.tmp").write_text('{"verdi', encoding="utf-8")
        (results / "ENG-3.json").write_text('{"verdi', encoding="utf-8")
        (results / "ENG-9.json").write_text("{}", encoding="utf-8")
        result = run_cli("wait", "--results-dir", results, "--known", "ENG-9",
                         "--timeout", "5", "--interval", "0.1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"new": ["ENG-1"], "malformed": ["ENG-3"]})

    def test_wait_times_out_when_only_known_results_exist(self):
        results = self.dir / "results"
        results.mkdir()
        (results / "ENG-1.json").write_text("{}", encoding="utf-8")
        result = run_cli("wait", "--results-dir", results, "--known", "ENG-1",
                         "--timeout", "0.3", "--interval", "0.1")
        self.assertEqual(result.returncode, 124)
        self.assertTrue(json.loads(result.stdout)["timed_out"])

    def test_a_lock_is_taken_over_by_its_own_run_and_refused_to_others(self):
        runs = self.dir / "runs"
        self.assertEqual(run_cli("lock", "--runs-dir", runs, "--run-id", "RUN-A", "--host", "claude").returncode, 0)
        self.assertEqual(run_cli("lock", "--runs-dir", runs, "--run-id", "RUN-A", "--host", "codex").returncode, 0)
        refused = run_cli("lock", "--runs-dir", runs, "--run-id", "RUN-B")
        self.assertEqual(refused.returncode, 3)
        self.assertEqual(json.loads(refused.stdout)["lock"], str(runs / "ACTIVE"))
        self.assertEqual(run_cli("unlock", "--runs-dir", runs, "--run-id", "RUN-B").returncode, 3)
        self.assertEqual(run_cli("unlock", "--runs-dir", runs, "--run-id", "RUN-A").returncode, 0)
        self.assertFalse((runs / "ACTIVE").exists())

    def test_an_unreadable_lock_is_never_taken_over(self):
        runs = self.dir / "runs"
        runs.mkdir()
        (runs / "ACTIVE").write_text("{", encoding="utf-8")
        self.assertEqual(run_cli("lock", "--runs-dir", runs, "--run-id", "RUN-A").returncode, 3)

    def test_next_and_halted_commands(self):
        plan_path = self.dir / "plan.json"
        plan_path.write_text(json.dumps(planned(issue("ENG-1"))), encoding="utf-8")
        state_path = self.dir / "state.json"
        state_path.write_text(json.dumps(state({"ENG-1": "backlog"})), encoding="utf-8")
        result = run_cli("next", "--plan", plan_path, "--state", state_path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["ready"], ["ENG-1"])
        result = run_cli("halted", "--plan", plan_path, "--reason", "Linear access failed")
        self.assertEqual(result.stdout.strip(),
                         "STATUS implement-backlog-linear RUN ENG-website-20260926-1430 · "
                         "HALTED · Linear access failed")


class InputValidationTests(unittest.TestCase):
    def test_label_objects_are_read_by_name(self):
        plan = plan_for(issue("ENG-1", labels=[{"id": "l1", "name": "Human-Setup"}]), issue("ENG-2"))
        self.assertEqual(plan["excluded"]["ENG-1"], {"reason": "human-gate", "label": "human-setup"})
        self.assertEqual(plan["order"], ["ENG-2"])

    def test_unreadable_labels_are_an_input_error(self):
        with self.assertRaises(graph.InputError):
            graph.load_snapshot(snapshot(issue("ENG-1", labels=[42])))

    def test_me_must_be_a_real_user_id(self):
        for me in (None, "", "me", "ME"):
            data = snapshot(issue("ENG-1"))
            data["me"] = me
            with self.assertRaises(graph.InputError):
                graph.load_snapshot(data)

    def test_state_entries_must_carry_labels(self):
        with self.assertRaises(graph.InputError):
            graph.next_step(planned(issue("ENG-1")), {"issues": {"ENG-1": {"state_type": "started"}}})

    def test_parked_label_objects_are_recognized_during_a_run(self):
        plan = planned(issue("ENG-1"), issue("ENG-2", blocked_by=["ENG-1"]))
        step = graph.next_step(plan, state({
            "ENG-1": {"state_type": "started", "labels": [{"name": "human-blocked"}]},
            "ENG-2": "backlog"}))
        self.assertEqual(step["parked"], ["ENG-1"])
        self.assertEqual(step["removed"]["ENG-2"], {"reason": "blocked", "via": ["ENG-1"]})


class SubIssueTests(unittest.TestCase):
    def test_an_open_sub_issue_outside_the_scope_blocks_its_parent(self):
        parent = issue("ENG-1")
        parent["sub_issues"] = ["OPS-4"]
        plan = plan_for(parent, issue("ENG-2"), external=[{"id": "OPS-4", "state_type": "started"}])
        self.assertEqual(plan["excluded"]["ENG-1"]["roots"], ["outside-scope:OPS-4"])
        self.assertEqual(plan["order"], ["ENG-2"])

    def test_an_epic_whose_sub_issues_are_all_done_is_verified(self):
        epic = issue("ENG-1", title="[Epic] Memory layer")
        epic["sub_issues"] = ["ENG-8"]
        plan = plan_for(epic, external=[{"id": "ENG-8", "state_type": "completed"}])
        self.assertEqual(plan["order"], ["ENG-1"])

    def test_a_finished_sub_issue_with_open_children_still_holds_its_parent(self):
        parent = issue("ENG-1")
        parent["sub_issues"] = ["ENG-2"]
        plan = plan_for(parent, issue("ENG-3", parent="ENG-2"),
                        external=[{"id": "ENG-2", "state_type": "completed"}])
        self.assertEqual(plan["layers"], [["ENG-3"], ["ENG-1"]])

    def test_a_canceled_sub_issue_does_not_hold_its_parent(self):
        parent = issue("ENG-1")
        parent["sub_issues"] = ["ENG-9"]
        plan = plan_for(parent, external=[{"id": "ENG-9", "state_type": "canceled"}])
        self.assertEqual(plan["order"], ["ENG-1"])

    def test_an_epic_with_no_sub_issues_at_all_is_not_broken_down(self):
        epic = issue("ENG-1", title="[Epic] Calling")
        epic["sub_issues"] = []
        plan = plan_for(epic)
        self.assertEqual(plan["excluded"]["ENG-1"], {"reason": "epic-not-broken-down"})


if __name__ == "__main__":
    unittest.main()
