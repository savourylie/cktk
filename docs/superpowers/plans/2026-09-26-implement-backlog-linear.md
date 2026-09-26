# implement-backlog-linear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a portable `implement-backlog-linear` skill that plans every Linear issue an agent can finish without a person and runs that plan to its human boundary under `/goal`, together with the worktree base-resolution fix it depends on.

**Architecture:** The skill's documents drive the host agent through Linear MCP reads, subagent dispatch, a serial merge queue, and parking. A standard-library Python planner, `backlog_graph.py`, owns every deterministic rule — scope, selection, readiness, locking, and status lines — so the model gathers facts and the script decides. Existing skills still do the per-issue work (`implement-ticket-linear`, `commit-ticket`, `merge-worktree-linear`, `update-ticket-linear`); the only change to them is that worktree creation prefers a local base that is strictly ahead of `origin/<base>`.

**Tech Stack:** Markdown skill documents; Python 3.9+ standard library for the planner and its `unittest` suite; Bash with Ruby YAML checks (`scripts/check-codex-skills.sh`); git.

**Spec:** `docs/superpowers/specs/2026-09-26-implement-backlog-linear-design.md` (commit `e7a2aa7`). Read it before starting; this plan argues from it.

## Before you start

The working tree carries the user's uncommitted prompt-audit edits (see `docs/audits/2026-09-25-prompt-audit.md`). They include the frontmatter `description` line of `skills/create-worktree/SKILL.md` and `skills/create-worktree-linear/SKILL.md`, which Task 1 also edits. Before Task 1:

1. Confirm with the user that the audit edits are committed on `main`, or otherwise settled.
2. On `feat/implement-backlog-linear`, rebase onto `main`: `git -C /Users/calvinku/FunProjects/cktk rebase main`.
3. Check that `git -C /Users/calvinku/FunProjects/cktk status --porcelain -- skills/create-worktree skills/create-worktree-linear` prints nothing.

If any step cannot be completed, stop and ask the user. Do not commit, stash, or discard their edits.

## Global Constraints

- Portable skill: one source under `skills/implement-backlog-linear/`; `.agents/skills/implement-backlog-linear` and `.agent/skills/implement-backlog-linear` are symlinks to `../../skills/implement-backlog-linear`.
- `SKILL.md` frontmatter has only `name` and `description` (at most 1024 characters); no `$ARGUMENTS`; every relative link resolves (`scripts/check-portable-skills.py`).
- `agents/openai.yaml` sets `policy.allow_implicit_invocation: false`.
- The planner uses the Python 3.9+ standard library only and never contacts Linear or the network.
- Gate labels are exactly `human-setup`, `human-acceptance`, and `human-blocked`, matched case-insensitively. Parking adds `human-blocked` with `addLabels`, never `labels`.
- Status lines, verbatim: `STATUS implement-backlog-linear RUN <run-id> · AI-ELIGIBLE <n> · DONE <n> · PARKED <n> · HUMAN-GATED <n> · BLOCKED <n>` and `STATUS implement-backlog-linear RUN <run-id> · HALTED · <reason>`.
- `/goal` line, verbatim apart from the run id: `/goal Run /implement-backlog-linear RUN: <run-id> until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"` (Codex writes `$implement-backlog-linear`).
- Run directory `$MAIN_ROOT/.worktrees/.cktk/runs/<run-id>/` holds `plan.json`, `snapshot.json`, `state.json`, and `results/`; the lock is `$MAIN_ROOT/.worktrees/.cktk/runs/ACTIVE`.
- Run id: `<TEAM>-<project slug, or team, or project>-<YYYYMMDD-HHMM>`, with `-2`, `-3`, … when that directory exists.
- Defaults: `PARALLEL` 3, `BASE` `main`.
- The new skill never pushes, opens a pull request, passes `--force` or `--no-verify`, or resets.
- Prose follows the 2026-09-25 prompt audit: directive sentences at normal volume, each reason given once; no "IRON LAW" or capitalized emphasis, no self-verification checklists, no scripted progress narration.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Identifiers typed in lowercase or with digits in the team key (`eng-10`, `A1B-3`), and numeric order (`ENG-9` before `ENG-10`): normalized to uppercase and ordered by number. Pinned by Task 2, `IdentifierTests`.
2. A dependency the connector reports only as `blocks` on the blocking issue: still an edge. Pinned by Task 2, `test_a_relation_recorded_only_as_blocks_is_still_an_edge`.
3. A non-ASCII project name such as `網站改版`, or two plans in the same minute: a valid, unique run id. Pinned by Task 2, `RunIdTests`.
4. A lock left by a crashed session: the same run takes it over, another run is refused with the lock's path, and an unreadable lock is never taken over. Pinned by Task 3, the lock tests.
5. A result file caught mid-write, or malformed: never read as a result; a malformed one is reported so the run retries. Pinned by Task 3, the wait tests.

---

### Task 1: Prefer a local base that is ahead of origin

The spec's §11 change. Today `create-worktree(-linear)` and `implement-ticket`'s workspace rule take `origin/<base>` even when local `<base>` holds landed but unpushed work, so a dependent issue's worktree misses its prerequisite.

**Files:**
- Modify: `scripts/check-codex-skills.sh` (new function before the `validate_clarify_contract` call list, and one new call)
- Modify: `skills/create-worktree-linear/SKILL.md:3` (description) and Phase 4 step 2 (`:106-109` before the audit rebase; locate by text)
- Modify: `skills/create-worktree/SKILL.md:3` (description) and Phase 3 step 2
- Modify: `.agents/skills/create-worktree-linear/SKILL.md` Phase 4 step 2
- Modify: `.agents/skills/create-worktree/SKILL.md` Phase 3 step 2
- Modify: `skills/implement-ticket/references/workspace.md` ("Resolve the base", third bullet)
- Modify: `README.md` (worktree caveat in "Local tickets", the `implement-ticket` and worktree usage comments, and one new paragraph under "Git and worktrees")

**Interfaces:**
- Produces: the rule text every later task relies on — a new worktree's base is local `<base>` when `origin/<base>` is an ancestor of it and the two differ.

- [ ] **Step 1: Add the failing contract check**

In `scripts/check-codex-skills.sh`, add this function directly above the call block at the end of the file — the run of bare `validate_*` lines that begins with `validate_clarify_contract` — so it is defined before it is called:

```bash
validate_worktree_base_contract() {
  local doc

  # A new worktree takes local <base> when it is strictly ahead of
  # origin/<base>: merge-worktree(-linear) lands work locally and never
  # pushes, and a dependent ticket's worktree must contain that work. Pin
  # the rule in every document that resolves a base, and keep the
  # superseded origin-first wording out.
  for doc in \
    "$claude_root/create-worktree/SKILL.md" \
    "$codex_root/create-worktree/SKILL.md" \
    "$claude_root/create-worktree-linear/SKILL.md" \
    "$codex_root/create-worktree-linear/SKILL.md" \
    "$claude_root/implement-ticket/references/workspace.md"; do
    require_literal "$doc" 'is an ancestor of local `<base>`'
    forbid_stale_claim "$doc" '(preferred — freshly fetched)'
    forbid_stale_claim "$doc" '`origin/<base>` → local `<base>`'
    forbid_stale_claim "$doc" 'prefer that ref'
    forbid_stale_claim "$doc" 'fetched fresh from origin'
  done

  forbid_stale_claim "$root/README.md" 'off origin/'
  forbid_stale_claim "$root/README.md" 'based on origin/'
  forbid_stale_claim "$root/README.md" 'which may not contain a local planning commit yet'
}
```

Then add `validate_worktree_base_contract` on its own line directly after the existing `validate_worktree_linear_contract` call.

- [ ] **Step 2: Run the check to see it fail**

Run: `bash /Users/calvinku/FunProjects/cktk/scripts/check-codex-skills.sh`
Expected: exit 1, with `must contain: is an ancestor of local` for all five documents and `contains a claim that is no longer true` lines for the old wording.

- [ ] **Step 3: Change the canonical create skills**

In `skills/create-worktree-linear/SKILL.md`, in the frontmatter `description`, replace `(defaults to main, fetched fresh from origin)` with `(defaults to main; uses origin's copy unless the local branch is ahead of it)`. Make the same replacement in `skills/create-worktree/SKILL.md`.

In `skills/create-worktree-linear/SKILL.md`, replace:

```markdown
2. Resolve the base reference in this order:
   - `origin/<base>` (preferred — freshly fetched).
   - Local `<base>` (fallback).
   - If neither exists, report `base branch '<base>' not found locally or on origin` and stop the batch before creating anything.
```

with:

```markdown
2. Resolve the base reference:
   - Local `<base>` when it is strictly ahead: `origin/<base>` is an ancestor of local `<base>` (`git merge-base --is-ancestor origin/<base> <base>` exits 0) and the two differ. `/merge-worktree-linear` leaves exactly this state, because it merges locally and never pushes, and a worktree for a dependent issue needs that work.
   - `origin/<base>` when local `<base>` is missing, equal, or behind.
   - `origin/<base>` when the two have diverged; name the local commits the worktree will not contain.
   - Local `<base>` when `origin/<base>` does not exist.
   - If neither exists, report `base branch '<base>' not found locally or on origin` and stop the batch before creating anything.
```

In `skills/create-worktree/SKILL.md`, replace the identical three-bullet block under `## Phase 3: Prepare the Repo`, step 2, with the same text, changing `/merge-worktree-linear` to `/merge-worktree` and "a dependent issue" to "a dependent ticket".

- [ ] **Step 4: Change the Codex create skills**

In `.agents/skills/create-worktree-linear/SKILL.md`, replace:

```markdown
2. Resolve the base ref: `origin/<base>` → local `<base>` → if neither exists, report and stop.
```

with:

```markdown
2. Resolve the base ref. Use local `<base>` when it is strictly ahead: `origin/<base>` is an ancestor of local `<base>` and the two differ, the state `$merge-worktree-linear` leaves because it never pushes. Otherwise use `origin/<base>`, naming any local commits it lacks when the two have diverged. Use local `<base>` when there is no `origin/<base>`; stop if neither exists.
```

In `.agents/skills/create-worktree/SKILL.md`, replace:

```markdown
2. Resolve the base reference in order: `origin/<base>` → local `<base>` → if neither exists, report and stop.
```

with the same new text, changing `$merge-worktree-linear` to `$merge-worktree`.

- [ ] **Step 5: Change the shared workspace rule**

In `skills/implement-ticket/references/workspace.md`, under `## Resolve the base`, replace the bullet:

```markdown
- Validate supplied base names and resolve the actual branch ref. For a requested base, fetch `origin/<base>` when available, prefer that ref, and fall back to a local base with a stale-source note if fetching is unavailable. If neither exists, ask instead of creating from a different ref.
```

with:

```markdown
- Validate supplied base names and resolve the actual branch ref. For a requested base, fetch `origin/<base>` when available. Use local `<base>` when it is strictly ahead — `origin/<base>` is an ancestor of local `<base>` and the two differ — because landed ticket work may not be pushed yet; otherwise use `origin/<base>`, noting any local commits it lacks when the two have diverged. Fall back to local `<base>` with a stale-source note if fetching is unavailable. If neither exists, ask instead of creating from a different ref. A worktree built on unpushed base commits carries them into any PR opened before the base is pushed.
```

- [ ] **Step 6: Change the README**

In `README.md`, under **Local tickets**, replace the sentence:

```markdown
For local ticket work in a new `worktree`, first ensure the planning files are committed **and included in the selected base**: the default is `origin/main`, which may not contain a local planning commit yet.
```

with:

```markdown
For local ticket work in a new `worktree`, first commit the planning files on `main`. A new worktree starts from local `main` when it is ahead of `origin/main`, so it includes that commit; a PR opened from the worktree then includes it too, unless `main` is pushed first.
```

In the usage block, replace these three lines:

```text
/implement-ticket 003 dev                    # Same, but branch off origin/dev
/implement-ticket 003 worktree               # Implement inside .worktrees/003-slug off origin/main
/implement-ticket 003 worktree dev           # Same, based on origin/dev (all variants also work for implement-ticket-linear)
```

with:

```text
/implement-ticket 003 dev                    # Same, but branch off dev
/implement-ticket 003 worktree               # Implement inside .worktrees/003-slug off main
/implement-ticket 003 worktree dev           # Same, based on dev (all variants also work for implement-ticket-linear)
```

Under `### Git and worktrees`, replace these four lines:

```text
/create-worktree 7                    # Worktree for ticket 007 off origin/main
/create-worktree 7 8 9 dev            # Several tickets at once, based on origin/dev
/create-worktree-linear ENG-42        # Worktree for Linear issue ENG-42 off origin/main
/create-worktree-linear ENG-42 ENG-43 dev   # Several issues at once, based on origin/dev
```

with:

```text
/create-worktree 7                    # Worktree for ticket 007 off main
/create-worktree 7 8 9 dev            # Several tickets at once, based on dev
/create-worktree-linear ENG-42        # Worktree for Linear issue ENG-42 off main
/create-worktree-linear ENG-42 ENG-43 dev   # Several issues at once, based on dev
```

Directly after that code block's closing fence, add this paragraph:

```markdown
A base comes from its freshly fetched `origin` copy unless the local branch is strictly ahead of it — for example after `merge-worktree` or `merge-worktree-linear` landed work without pushing. Then the local branch is used, so dependent tickets see that work.
```

- [ ] **Step 7: Run the check to see it pass**

Run: `bash /Users/calvinku/FunProjects/cktk/scripts/check-codex-skills.sh`
Expected: exit 0 and `Validated 41 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 8: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add scripts/check-codex-skills.sh skills/create-worktree-linear/SKILL.md skills/create-worktree/SKILL.md \
  .agents/skills/create-worktree-linear/SKILL.md .agents/skills/create-worktree/SKILL.md \
  skills/implement-ticket/references/workspace.md README.md
git commit -F - <<'EOF'
fix(worktrees): base new worktrees on a local branch that is ahead

merge-worktree and merge-worktree-linear land work locally and never
push, yet create-worktree, create-worktree-linear, and the implement
workspace rule always took the freshly fetched origin/<base>. A worktree
for a dependent ticket therefore started without its prerequisite, and
implement-ticket-linear stopped on a missing prerequisite.

Use local <base> when origin/<base> is its ancestor and the two differ;
keep origin/<base> when local is missing, equal, behind, or diverged, and
name the local commits a diverged base leaves out. The README examples
and the local-planning caveat now describe that rule.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 2: Planner — scope, selection, and the plan command

**Files:**
- Create: `skills/implement-backlog-linear/scripts/backlog_graph.py`
- Create: `scripts/test-backlog-graph.py`

**Interfaces:**
- Produces (Python, imported by the tests and extended by Task 3): `InputError`; `norm_id(value) -> str`; `id_key(issue_id) -> tuple`; `sort_ids(ids) -> list`; `label_set(labels) -> set`; `load_snapshot(data: dict) -> dict` with keys `team`, `me`, `requested_project`, `binding_project`, `issues` (id → issue dict), `external` (id → dict); `resolve_scope(snapshot) -> dict`; `classify(issue, me) -> dict | None`; `select(snapshot) -> dict` (plan fields `status`, `scope`, `order`, `layers`, `edges`, `excluded`, `titles`); `make_run_id(team_key, project, now, runs_dir) -> str`; `worktree_ids(porcelain, main_root) -> set`; `branch_ids(listing) -> set`; `landed_ids(subjects, base) -> set`; `landed_on(repo, base) -> set`; `local_work(repo, base) -> set`; `read_json(path)`; `write_json(path, data)`; `build_parser()`; `main(argv=None) -> int`.
- Produces (CLI): `backlog_graph.py plan --snapshot FILE --runs-dir DIR [--repo DIR] [--base BRANCH] [--parallel N] [--host NAME] [--now ISO] [--dry-run]`, printing the plan JSON with `schema`, `created_at`, `team`, `me`, `base`, `parallel`, `host`, `repo`, `run_id`, and `run_dir` added. Exit 2 on unusable input. A run directory is created only for `status: planned` without `--dry-run`.
- `excluded` values: `{"reason": "human-gate", "label": …}`, `{"reason": "someone-else"}`, `{"reason": "not-triaged"}`, `{"reason": "running-elsewhere"}`, `{"reason": "cycle", "via": […]}`, or `{"reason": "blocked", "via": […], "roots": ["<kind>:<ID>", …]}`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/test-backlog-graph.py`:

```python
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
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `python3 /Users/calvinku/FunProjects/cktk/scripts/test-backlog-graph.py`
Expected: FAIL immediately with `FileNotFoundError` for `skills/implement-backlog-linear/scripts/backlog_graph.py`.

- [ ] **Step 3: Write the planner**

Create `skills/implement-backlog-linear/scripts/backlog_graph.py` and make it executable (`chmod +x`):

```python
#!/usr/bin/env python3
"""Plan, schedule, and report implement-backlog-linear runs.

The skill gathers facts from Linear and git; this script applies the rules
that decide what a run may touch, so the same facts always produce the same
plan, ready list, and status line. Standard library only; it never contacts
Linear.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = 1
PARK_LABEL = "human-blocked"
GATE_LABELS = frozenset({"human-setup", "human-acceptance", PARK_LABEL})
OPEN_STATES = frozenset({"triage", "backlog", "unstarted", "started"})
TERMINAL_STATES = frozenset({"completed", "canceled"})
ISSUE_ID = re.compile(r"^([A-Za-z][A-Za-z0-9]*)-(\d+)$")
ID_PREFIX = re.compile(r"^([A-Za-z][A-Za-z0-9]*-\d+)-")
LANDED_SUBJECT = re.compile(r"^Merge linear-([A-Za-z][A-Za-z0-9]*-\d+)-\S* into (\S+)$")


class InputError(Exception):
    """A snapshot, state, plan, or repository the rules cannot use."""


def norm_id(value):
    match = ISSUE_ID.match(str(value).strip())
    if not match:
        raise InputError(f"not a Linear issue identifier: {value!r}")
    return f"{match.group(1).upper()}-{int(match.group(2))}"


def id_key(issue_id):
    team, number = issue_id.rsplit("-", 1)
    return (team, int(number))


def sort_ids(ids):
    return sorted(ids, key=id_key)


def label_set(labels):
    return {str(label).strip().lower() for label in labels or ()}


def project_of(value):
    if not value:
        return None
    if isinstance(value, dict):
        return {"id": str(value["id"]), "name": str(value.get("name") or "")}
    return {"id": str(value), "name": ""}


def load_snapshot(data):
    """Normalize a planning snapshot: uppercase ids, merged duplicates, both relation directions."""
    issues = {}
    reverse = []
    for raw in data.get("issues") or []:
        issue_id = norm_id(raw["id"])
        state = str(raw.get("state_type") or "").lower()
        if state not in OPEN_STATES | TERMINAL_STATES:
            raise InputError(f"{issue_id}: unknown state_type {raw.get('state_type')!r}")
        entry = issues.setdefault(issue_id, {
            "id": issue_id,
            "title": str(raw.get("title") or ""),
            "state_type": state,
            "labels": set(),
            "assignee": raw.get("assignee"),
            "project": project_of(raw.get("project")),
            "parent": norm_id(raw["parent"]) if raw.get("parent") else None,
            "blocked_by": set(),
            "local_work": bool(raw.get("local_work")),
        })
        entry["labels"] |= label_set(raw.get("labels"))
        entry["blocked_by"] |= {norm_id(b) for b in raw.get("blocked_by") or ()}
        reverse.extend((norm_id(b), issue_id) for b in raw.get("blocks") or ())
    for blocked, blocker in reverse:
        if blocked in issues:
            issues[blocked]["blocked_by"].add(blocker)
    external = {}
    for raw in data.get("external") or []:
        issue_id = norm_id(raw["id"])
        external[issue_id] = {"id": issue_id, "state_type": str(raw.get("state_type") or "").lower(),
                              "title": str(raw.get("title") or "")}
    team = data.get("team") or {}
    if not team.get("key"):
        raise InputError("snapshot team.key is required")
    return {
        "team": {"id": str(team.get("id") or ""), "key": str(team["key"]).upper()},
        "me": data.get("me"),
        "requested_project": project_of(data.get("requested_project")),
        "binding_project": project_of(data.get("binding_project")),
        "issues": issues,
        "external": external,
    }


def resolve_scope(snapshot):
    """Apply the one-project-one-repository rule to the snapshot's open issues."""
    issues = snapshot["issues"]
    open_ids = [i for i, v in issues.items() if v["state_type"] in OPEN_STATES]
    requested = snapshot["requested_project"]
    bound = snapshot["binding_project"]
    bound_id = bound["id"] if bound else None
    if requested:
        if bound_id and bound_id != requested["id"]:
            return {"status": "stop", "reason": "binding-mismatch", "project": requested, "bound": bound}
        ids = [i for i in open_ids if (issues[i]["project"] or {}).get("id") == requested["id"]]
        return {"status": "ok", "project": requested, "issue_ids": sort_ids(ids)}
    projects = {}
    for issue_id in open_ids:
        project = issues[issue_id]["project"]
        if project:
            projects.setdefault(project["id"], project)
    if len(projects) > 1:
        listed = sorted(projects.values(), key=lambda p: (p["name"], p["id"]))
        return {"status": "stop", "reason": "multiple-projects", "bound": bound,
                "projects": [dict(p, bound=p["id"] == bound_id) for p in listed]}
    if projects:
        project = next(iter(projects.values()))
        if bound_id and bound_id != project["id"]:
            return {"status": "stop", "reason": "binding-mismatch", "project": project, "bound": bound}
        return {"status": "ok", "project": project, "issue_ids": sort_ids(open_ids)}
    return {"status": "ok", "project": None, "issue_ids": sort_ids(open_ids)}


def classify(issue, me):
    """Return why an open in-scope issue is not a candidate, or None when it is one."""
    gates = issue["labels"] & GATE_LABELS
    if gates:
        label = PARK_LABEL if PARK_LABEL in gates else sorted(gates)[0]
        return {"reason": "human-gate", "label": label}
    if issue["assignee"] and issue["assignee"] != me:
        return {"reason": "someone-else"}
    if issue["state_type"] == "triage":
        return {"reason": "not-triaged"}
    if issue["state_type"] == "started" and not issue["local_work"]:
        return {"reason": "running-elsewhere"}
    return None


def state_of(issue_id, snapshot):
    if issue_id in snapshot["issues"]:
        return snapshot["issues"][issue_id]["state_type"]
    if issue_id in snapshot["external"]:
        return snapshot["external"][issue_id]["state_type"]
    return None


def topo_layers(nodes, blockers):
    """Kahn's algorithm in layers; returns (layers, nodes that never became free)."""
    remaining, done, layers = set(nodes), set(), []
    while remaining:
        layer = sort_ids(n for n in remaining if all(b in done for b in blockers[n]))
        if not layer:
            break
        layers.append(layer)
        done.update(layer)
        remaining.difference_update(layer)
    return layers, remaining


def on_cycle(node, blockers, allowed):
    stack, seen = list(blockers.get(node, ())), set()
    while stack:
        current = stack.pop()
        if current == node:
            return True
        if current in seen or current not in allowed:
            continue
        seen.add(current)
        stack.extend(blockers.get(current, ()))
    return False


def attach_roots(excluded, snapshot):
    """Name the underlying causes of every dependency exclusion as <kind>:<issue>."""
    memo = {}

    def roots(issue_id, trail):
        if issue_id in memo:
            return memo[issue_id]
        info = excluded[issue_id]
        if info["reason"] == "human-gate":
            found = {f"{info['label']}:{issue_id}"}
        elif info["reason"] != "blocked":
            found = {f"{info['reason']}:{issue_id}"}
        else:
            found = set()
            for blocker in info["via"]:
                if blocker in excluded:
                    if blocker not in trail:
                        found |= roots(blocker, trail | {issue_id})
                    continue
                state = state_of(blocker, snapshot)
                if state == "canceled":
                    found.add(f"canceled:{blocker}")
                elif state is None:
                    found.add(f"unknown:{blocker}")
                else:
                    found.add(f"outside-scope:{blocker}")
        memo[issue_id] = found
        return found

    for issue_id, info in excluded.items():
        if info["reason"] == "blocked":
            info["roots"] = sorted(roots(issue_id, frozenset()))


def select(snapshot):
    """Compute the plan: scope, eligible issues in layers, and every exclusion with its reason."""
    scope = resolve_scope(snapshot)
    plan = {"status": "stop", "scope": {k: v for k, v in scope.items() if k != "issue_ids"},
            "order": [], "layers": [], "edges": {}, "excluded": {}, "titles": {}}
    if scope["status"] != "ok":
        return plan
    issues = snapshot["issues"]
    scope_ids = scope["issue_ids"]
    excluded, candidates = {}, []
    for issue_id in scope_ids:
        verdict = classify(issues[issue_id], snapshot["me"])
        if verdict:
            excluded[issue_id] = verdict
        else:
            candidates.append(issue_id)
    edges = {}
    for issue_id in candidates:
        children = {c for c in scope_ids if issues[c]["parent"] == issue_id}
        edges[issue_id] = issues[issue_id]["blocked_by"] | children
    eligible = set(candidates)
    changed = True
    while changed:
        changed = False
        for issue_id in sort_ids(eligible):
            unmet = [b for b in edges[issue_id]
                     if b not in eligible and state_of(b, snapshot) != "completed"]
            if unmet:
                eligible.discard(issue_id)
                excluded[issue_id] = {"reason": "blocked", "via": sort_ids(unmet)}
                changed = True
    in_plan = {i: sort_ids(b for b in edges[i] if b in eligible) for i in eligible}
    layers, stuck = topo_layers(eligible, in_plan)
    if stuck:
        cyclic = {i for i in stuck if on_cycle(i, in_plan, stuck)}
        for issue_id in sort_ids(stuck):
            if issue_id in cyclic:
                excluded[issue_id] = {"reason": "cycle", "via": [b for b in in_plan[issue_id] if b in cyclic]}
            else:
                excluded[issue_id] = {"reason": "blocked", "via": [b for b in in_plan[issue_id] if b in stuck]}
    attach_roots(excluded, snapshot)
    order = [i for layer in layers for i in layer]
    plan.update({
        "status": "planned" if order else "nothing-eligible",
        "order": order,
        "layers": layers,
        "edges": {i: in_plan[i] for i in order},
        "excluded": {i: excluded[i] for i in sort_ids(excluded)},
        "titles": {i: issues[i]["title"] for i in scope_ids},
    })
    return plan


def slugify(text, limit=24):
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    if len(slug) > limit:
        cut = slug[:limit]
        slug = cut.rsplit("-", 1)[0] if "-" in cut else cut
    return slug


def make_run_id(team_key, project, now, runs_dir):
    """<TEAM>-<project slug>-<YYYYMMDD-HHMM>, with -2, -3, … when that directory exists."""
    label = "team" if project is None else (slugify(project["name"]) or "project")
    base = f"{team_key}-{label}-{now.strftime('%Y%m%d-%H%M')}"
    candidate, suffix = base, 2
    while (Path(runs_dir) / candidate).exists():
        candidate, suffix = f"{base}-{suffix}", suffix + 1
    return candidate


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise InputError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def worktree_ids(porcelain, main_root):
    root = os.path.join(os.path.realpath(main_root), ".worktrees") + os.sep
    ids = set()
    for line in porcelain.splitlines():
        if not line.startswith("worktree "):
            continue
        path = os.path.realpath(line[len("worktree "):].strip())
        if path.startswith(root):
            match = ID_PREFIX.match(path[len(root):].split(os.sep, 1)[0])
            if match:
                ids.add(norm_id(match.group(1)))
    return ids


def branch_ids(listing):
    ids = set()
    for line in listing.splitlines():
        name = line.strip()
        if name.startswith("linear-"):
            match = ID_PREFIX.match(name[len("linear-"):])
            if match:
                ids.add(norm_id(match.group(1)))
    return ids


def landed_ids(subjects, base):
    ids = set()
    for line in subjects.splitlines():
        match = LANDED_SUBJECT.match(line.strip())
        if match and match.group(2) == base:
            ids.add(norm_id(match.group(1)))
    return ids


def landed_on(repo, base):
    """Issue ids whose `Merge linear-<ID>-… into <base>` commit is on the local base."""
    exists = subprocess.run(["git", "-C", str(repo), "rev-parse", "--verify", "--quiet", base],
                            capture_output=True)
    if exists.returncode != 0:
        return set()
    return landed_ids(git(repo, "log", base, "--merges", "--format=%s"), base)


def local_work(repo, base):
    """Issue ids with a registered worktree, a linear-* branch, or a landing merge on the base."""
    ids = worktree_ids(git(repo, "worktree", "list", "--porcelain"), repo)
    ids |= branch_ids(git(repo, "branch", "--list", "--format=%(refname:short)", "linear-*"))
    return ids | landed_on(repo, base)


def now_utc(text=None):
    if not text:
        return datetime.now(timezone.utc)
    value = datetime.fromisoformat(text.replace("Z", "+00:00"))
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise InputError(f"cannot read {path}: {error}") from error


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def cmd_plan(args):
    if args.parallel < 1:
        raise InputError("--parallel must be at least 1")
    raw = read_json(args.snapshot)
    snapshot = load_snapshot(raw)
    if args.repo:
        found = local_work(args.repo, args.base)
        for issue in snapshot["issues"].values():
            issue["local_work"] = issue["id"] in found
    plan = select(snapshot)
    now = now_utc(args.now)
    plan.update({
        "schema": SCHEMA,
        "created_at": now.isoformat(timespec="seconds"),
        "team": snapshot["team"],
        "me": snapshot["me"],
        "base": args.base,
        "parallel": args.parallel,
        "host": args.host,
        "repo": os.path.realpath(args.repo) if args.repo else None,
        "run_id": None,
        "run_dir": None,
    })
    if plan["status"] == "planned" and not args.dry_run:
        run_id = make_run_id(snapshot["team"]["key"], plan["scope"]["project"], now, args.runs_dir)
        run_dir = Path(args.runs_dir) / run_id
        plan["run_id"], plan["run_dir"] = run_id, str(run_dir)
        write_json(run_dir / "plan.json", plan)
        write_json(run_dir / "snapshot.json", raw)
        (run_dir / "results").mkdir(exist_ok=True)
    print(json.dumps(plan, ensure_ascii=False, indent=2))
    return 0


def build_parser():
    parser = argparse.ArgumentParser(prog="backlog_graph.py",
                                     description="Plan, schedule, and report implement-backlog-linear runs.")
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan", help="select the issues a run may take")
    plan.add_argument("--snapshot", required=True)
    plan.add_argument("--runs-dir", required=True)
    plan.add_argument("--repo")
    plan.add_argument("--base", default="main")
    plan.add_argument("--parallel", type=int, default=3)
    plan.add_argument("--host", default="unknown")
    plan.add_argument("--now", help="ISO-8601 time; defaults to the current time")
    plan.add_argument("--dry-run", action="store_true", help="print the plan without creating a run directory")
    plan.set_defaults(handler=cmd_plan)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.handler(args)
    except (InputError, KeyError, TypeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `python3 /Users/calvinku/FunProjects/cktk/scripts/test-backlog-graph.py -v`
Expected: every test `ok`; final line `OK`.

- [ ] **Step 5: Commit**

The new `skills/implement-backlog-linear/` directory has no `SKILL.md` yet, so `scripts/check-codex-skills.sh` fails until Task 5; do not run it here.

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-backlog-linear/scripts/backlog_graph.py scripts/test-backlog-graph.py
git commit -F - <<'EOF'
feat(implement-backlog-linear): add the backlog planner

A backlog run is only as safe as its plan, and the plan's rules — one
project per repository, human-gate labels, blockers that must be done or
also planned, parents waiting for their sub-issues, cycles — are exactly
where a model reasoning over dozens of issues can slip.

backlog_graph.py applies them deterministically to a snapshot the skill
gathers from Linear: it resolves the scope, classifies every open issue,
removes issues whose blockers cannot be met, orders the rest in
topological layers, and records every exclusion with its root cause. With
--repo it detects work an earlier run left behind, and it writes the run
directory that execution will read. Standard library only; it never
contacts Linear.

Validation: python3 scripts/test-backlog-graph.py

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 3: Planner — readiness, waiting, locking, and status lines

**Files:**
- Modify: `skills/implement-backlog-linear/scripts/backlog_graph.py`
- Modify: `scripts/test-backlog-graph.py`

**Interfaces:**
- Consumes: Task 2's `norm_id`, `sort_ids`, `label_set`, `GATE_LABELS`, `PARK_LABEL`, `landed_on`, `read_json`, `write_json`, `InputError`, `build_parser`.
- Produces (Python): `next_step(plan, state, landed=frozenset()) -> dict` with keys `ready`, `in_flight`, `landed_not_done`, `done`, `parked`, `removed`, `counts`, `status_line`; `count_status(plan, active, done, parked, removed) -> dict`; `status_line(run_id, counts) -> str`; `halted_line(run_id, reason) -> str`; `scan_results(results_dir, known) -> (new, malformed)`.
- Produces (CLI): `next --plan FILE --state FILE [--repo DIR]`; `halted --plan FILE --reason TEXT`; `wait --results-dir DIR [--known A,B] [--timeout S] [--interval S]` (exit 0 with `{"new": […], "malformed": […]}`, exit 124 with `"timed_out": true`); `lock --runs-dir DIR --run-id ID [--host NAME]` and `unlock --runs-dir DIR --run-id ID` (exit 3 with `{"locked_by": …, "lock": path}` when another run holds it).
- `state.json` shape: `{"issues": {ID: {"state_type", "labels", "assignee", "blocked_by"?}}, "external": {ID: {"state_type"}}, "in_flight": [ID, …]}`.
- `removed` reasons: `human-gate` (with `label`), `canceled`, `someone-else`, `new-blocker` (with `via`), `blocked` (with `via`), `stuck` (with `via`).
- `counts`: `AI-ELIGIBLE` = planned issues still active; `DONE` = planned issues completed; `PARKED` = issues carrying `human-blocked`, planned or excluded; `HUMAN-GATED` = issues gated by `human-setup` or `human-acceptance`; `BLOCKED` = every other in-scope issue the run is not taking.

- [ ] **Step 1: Write the failing tests**

In `scripts/test-backlog-graph.py`, add these helpers after `run_cli`:

```python
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
```

Add these test classes above `if __name__ == "__main__":`:

```python
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
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `python3 /Users/calvinku/FunProjects/cktk/scripts/test-backlog-graph.py`
Expected: FAIL — `AttributeError: module 'backlog_graph' has no attribute 'next_step'` in `NextStepTests`, and `invalid choice: 'wait'` (exit 2) in `CommandTests`.

- [ ] **Step 3: Add the execution helpers**

In `backlog_graph.py`, add `import time` to the imports, add this constant after `LANDED_SUBJECT`:

```python
COUNT_KEYS = ("AI-ELIGIBLE", "DONE", "PARKED", "HUMAN-GATED", "BLOCKED")
```

Add these functions directly above `def build_parser():`:

```python
def next_step(plan, state, landed=frozenset()):
    """Decide what a run does next from its plan and fresh Linear state."""
    me = plan.get("me")
    order = plan["order"]
    planned = set(order)
    current = {norm_id(k): v for k, v in (state.get("issues") or {}).items()}
    external = {norm_id(k): v for k, v in (state.get("external") or {}).items()}
    in_flight = {norm_id(i) for i in state.get("in_flight") or ()}
    blockers = {i: set(plan["edges"].get(i, ())) for i in order}
    done, parked, removed = [], [], {}
    for issue_id in order:
        info = current.get(issue_id)
        if info is None:
            raise InputError(f"state is missing planned issue {issue_id}")
        labels = label_set(info.get("labels"))
        state_type = str(info.get("state_type") or "").lower()
        if state_type == "completed":
            done.append(issue_id)
        elif PARK_LABEL in labels:
            parked.append(issue_id)
        elif labels & GATE_LABELS:
            removed[issue_id] = {"reason": "human-gate", "label": sorted(labels & GATE_LABELS)[0]}
        elif state_type == "canceled":
            removed[issue_id] = {"reason": "canceled"}
        elif info.get("assignee") and info["assignee"] != me:
            removed[issue_id] = {"reason": "someone-else"}
        else:
            new = []
            for blocker in info.get("blocked_by") or ():
                blocker = norm_id(blocker)
                if blocker in planned:
                    blockers[issue_id].add(blocker)
                elif (external.get(blocker) or current.get(blocker) or {}).get("state_type") != "completed":
                    new.append(blocker)
            if new:
                removed[issue_id] = {"reason": "new-blocker", "via": sort_ids(new)}
    finished = set(done)
    out = set(parked) | set(removed)
    changed = True
    while changed:
        changed = False
        for issue_id in order:
            if issue_id in finished or issue_id in out:
                continue
            via = sort_ids(b for b in blockers[issue_id] if b in out)
            if via:
                removed[issue_id] = {"reason": "blocked", "via": via}
                out.add(issue_id)
                changed = True
    active = [i for i in order if i not in finished and i not in out]
    landed_not_done = [i for i in active if i in landed]
    ready = [i for i in active
             if i not in in_flight and i not in landed and all(b in finished for b in blockers[i])]
    if active and not ready and not landed_not_done and not in_flight.intersection(active):
        for issue_id in active:
            removed[issue_id] = {"reason": "stuck",
                                 "via": sort_ids(b for b in blockers[issue_id] if b not in finished)}
        active = []
    counts = count_status(plan, active, done, parked, removed)
    return {
        "ready": ready,
        "in_flight": [i for i in active if i in in_flight],
        "landed_not_done": landed_not_done,
        "done": done,
        "parked": parked,
        "removed": {i: removed[i] for i in sort_ids(removed)},
        "counts": counts,
        "status_line": status_line(plan["run_id"], counts),
    }


def count_status(plan, active, done, parked, removed):
    excluded = plan["excluded"]
    parked_all = set(parked) | {i for i, v in excluded.items()
                                if v["reason"] == "human-gate" and v["label"] == PARK_LABEL}
    gated_all = {i for i, v in excluded.items()
                 if v["reason"] == "human-gate" and v["label"] != PARK_LABEL}
    gated_all |= {i for i, v in removed.items() if v["reason"] == "human-gate"}
    others = (set(excluded) | set(removed)) - parked_all - gated_all
    return {"AI-ELIGIBLE": len(active), "DONE": len(done), "PARKED": len(parked_all),
            "HUMAN-GATED": len(gated_all), "BLOCKED": len(others)}


def status_line(run_id, counts):
    parts = " · ".join(f"{key} {counts[key]}" for key in COUNT_KEYS)
    return f"STATUS implement-backlog-linear RUN {run_id} · {parts}"


def halted_line(run_id, reason):
    return f"STATUS implement-backlog-linear RUN {run_id} · HALTED · {' '.join(reason.split())}"


def cmd_next(args):
    plan = read_json(args.plan)
    state = read_json(args.state)
    landed = frozenset(landed_on(args.repo, plan["base"])) if args.repo else frozenset()
    print(json.dumps(next_step(plan, state, landed), ensure_ascii=False, indent=2))
    return 0


def cmd_halted(args):
    print(halted_line(read_json(args.plan)["run_id"], args.reason))
    return 0


def scan_results(results_dir, known):
    new, malformed = [], []
    for path in sorted(Path(results_dir).glob("*.json")):
        name = path.name[: -len(".json")]
        if name in known:
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            malformed.append(name)
            continue
        new.append(name)
    return new, malformed


def cmd_wait(args):
    known = {part.strip() for part in args.known.split(",") if part.strip()}
    deadline = time.monotonic() + args.timeout
    while True:
        new, malformed = scan_results(args.results_dir, known)
        if new or malformed:
            print(json.dumps({"new": new, "malformed": malformed}))
            return 0
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            print(json.dumps({"new": [], "malformed": [], "timed_out": True}))
            return 124
        time.sleep(min(args.interval, remaining))


def read_lock(lock):
    try:
        return json.loads(lock.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"run_id": None, "unreadable": True}


def cmd_lock(args):
    lock = Path(args.runs_dir) / "ACTIVE"
    if lock.exists():
        holder = read_lock(lock)
        if holder.get("run_id") != args.run_id:
            print(json.dumps({"locked_by": holder, "lock": str(lock)}))
            return 3
    write_json(lock, {"run_id": args.run_id, "host": args.host,
                      "taken_at": datetime.now(timezone.utc).isoformat(timespec="seconds")})
    print(json.dumps({"lock": str(lock), "run_id": args.run_id}))
    return 0


def cmd_unlock(args):
    lock = Path(args.runs_dir) / "ACTIVE"
    if not lock.exists():
        print(json.dumps({"released": False}))
        return 0
    holder = read_lock(lock)
    if holder.get("run_id") != args.run_id:
        print(json.dumps({"locked_by": holder, "lock": str(lock)}))
        return 3
    lock.unlink()
    print(json.dumps({"released": True}))
    return 0
```

In `build_parser()`, add these parsers directly before `return parser`:

```python
    step = sub.add_parser("next", help="decide what a run does next")
    step.add_argument("--plan", required=True)
    step.add_argument("--state", required=True)
    step.add_argument("--repo")
    step.set_defaults(handler=cmd_next)

    halted = sub.add_parser("halted", help="print the halted status line")
    halted.add_argument("--plan", required=True)
    halted.add_argument("--reason", required=True)
    halted.set_defaults(handler=cmd_halted)

    wait = sub.add_parser("wait", help="block until a new result file appears")
    wait.add_argument("--results-dir", required=True)
    wait.add_argument("--known", default="")
    wait.add_argument("--timeout", type=float, default=540.0)
    wait.add_argument("--interval", type=float, default=5.0)
    wait.set_defaults(handler=cmd_wait)

    for name, handler in (("lock", cmd_lock), ("unlock", cmd_unlock)):
        command = sub.add_parser(name, help=f"{name} the repository's active run")
        command.add_argument("--runs-dir", required=True)
        command.add_argument("--run-id", required=True)
        if name == "lock":
            command.add_argument("--host", default="unknown")
        command.set_defaults(handler=handler)
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `python3 /Users/calvinku/FunProjects/cktk/scripts/test-backlog-graph.py -v`
Expected: every test `ok`; final line `OK`.

- [ ] **Step 5: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-backlog-linear/scripts/backlog_graph.py scripts/test-backlog-graph.py
git commit -F - <<'EOF'
feat(implement-backlog-linear): decide readiness, waiting, and locking

Execution must re-derive progress from Linear and git every round so a
run can resume after compaction, a halt, or a new session, and /goal
needs a status line it can check.

next computes the ready issues, those merged but not yet Done, and the
issues that leave the plan — newly gated, canceled, reassigned, given an
unfinished blocker, blocked by a parked issue, or stuck — and prints the
fixed STATUS line; halted prints its HALTED form. wait blocks until a new
result file appears, never reading a half-written one. lock and unlock
keep a single active run per repository, letting a run resume its own
lock while refusing another's.

Validation: python3 scripts/test-backlog-graph.py

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 4: Settle how Claude Code waits for subagents under `/goal`

The spec's §13 spike. It needs a live Claude Code run and possibly the user. The result decides one paragraph of `execution.md` in Task 6.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-26-implement-backlog-linear-design.md` (§6 "Waiting", Risks)

**Interfaces:**
- Consumes: `backlog_graph.py wait` (Task 3).
- Produces: Outcome A, B, or C, with the date and `claude --version`, for Task 6.

- [ ] **Step 1: Prepare a throwaway directory**

```sh
SPIKE="$(mktemp -d "${TMPDIR:-/tmp}/cktk-goal-spike.XXXXXX")"
mkdir -p "$SPIKE/results"
claude --version
echo "$SPIKE"
```

Record the version and the directory.

- [ ] **Step 2: Probe waiting by notification**

`--dangerously-skip-permissions` is acceptable only because the directory is throwaway and the prompt is fixed:

```sh
cd "$SPIKE" && claude -p --dangerously-skip-permissions --output-format stream-json --verbose \
  '/goal Launch two background subagents at once. Each runs python3 -c "import time; time.sleep(150)" and then writes its letter to results/a.json or results/b.json in this directory as {"done": true}. Do not do their work yourself. The goal is met when both files exist and you have said so.' \
  > "$SPIKE/notify.jsonl" 2>&1; echo "exit $?"
grep -o 'Goal[^"\\]*' "$SPIKE/notify.jsonl" | sort | uniq -c
ls "$SPIKE/results"
```

Classify the result:

- **Outcome A**: both files exist, a `Goal achieved` line appears, and no `Goal paused · goal checks kept finding it unmet this turn` line appears. Skip to Step 4.
- **Probe the foreground wait**: the pause line appears, or the run ended before both files existed. Go to Step 3.
- **Inconclusive**: `/goal` was refused (for example `only available in trusted workspaces`), or no goal lines appear. Ask the user to repeat the probe interactively: `cd "$SPIKE" && claude`, accept the trust dialog, paste the quoted `/goal …` text, and report whether `Goal not yet met… continuing` repeats while waiting, whether the pause line appears, and whether the goal ends as achieved. Classify their report the same way.

- [ ] **Step 3: Probe the bounded foreground wait (only when Step 2 did not give Outcome A)**

```sh
CKTK=/Users/calvinku/FunProjects/cktk
rm -f "$SPIKE"/results/*.json
cd "$SPIKE" && claude -p --dangerously-skip-permissions --output-format stream-json --verbose \
  "/goal Launch two background subagents at once. Each runs python3 -c \"import time; time.sleep(150)\" and then writes its letter to results/a.json or results/b.json in this directory as {\"done\": true}. Do not do their work yourself. While they run, do not end your turn: wait in the foreground with python3 $CKTK/skills/implement-backlog-linear/scripts/backlog_graph.py wait --results-dir $SPIKE/results --known <files already seen, comma-separated> --timeout 540, repeating after each exit 124. The goal is met when both files exist and you have said so." \
  > "$SPIKE/wait.jsonl" 2>&1; echo "exit $?"
grep -o 'Goal[^"\\]*' "$SPIKE/wait.jsonl" | sort | uniq -c
ls "$SPIKE/results"
```

- **Outcome B**: both files exist, the goal is achieved, and no pause line appears.
- **Outcome C**: the harness refuses the foreground wait, or the pause line still appears. Use the interactive fallback from Step 2 if this probe is inconclusive.

- [ ] **Step 4: Record the result in the spec**

In `docs/superpowers/specs/2026-09-26-implement-backlog-linear-design.md`, §6, directly after the paragraph that starts `**Waiting.**`, add (filling in the observed values):

```markdown
**Spike result (<YYYY-MM-DD>, Claude Code <version>):** Outcome <A, B, or C>. <One or two sentences: which goal lines appeared, whether both results arrived, and whether the pause line appeared.> `references/execution.md` uses the matching Claude Code waiting paragraph.
```

In `## Risks`, replace `- **Waiting in Claude Code** (§6) stays unresolved until the spike.` with:

```markdown
- **Waiting in Claude Code** (§6) was settled by the spike. A later Claude Code release can change goal-check behavior; if a run's goal pauses unexpectedly after an upgrade, repeat the spike.
```

- [ ] **Step 5: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add docs/superpowers/specs/2026-09-26-implement-backlog-linear-design.md
git commit -F - <<'EOF'
docs(implement-backlog-linear): record how Claude Code waits under /goal

<One paragraph: the outcome, the evidence, and the version it was
observed on.>

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

Replace the angle-bracketed paragraph with the actual outcome before committing.

---

### Task 5: Planning mode — skill entry, planning reference, and repository integration

**Files:**
- Create: `skills/implement-backlog-linear/SKILL.md`
- Create: `skills/implement-backlog-linear/references/planning.md`
- Create: `skills/implement-backlog-linear/agents/openai.yaml`
- Create: symlink `.agents/skills/implement-backlog-linear` → `../../skills/implement-backlog-linear`
- Create: symlink `.agent/skills/implement-backlog-linear` → `../../skills/implement-backlog-linear`
- Modify: `catalog.json` (new entry after `implement-ticket-linear`)
- Modify: `README.md` (one row in the "Tickets and planning" table)
- Modify: `scripts/check-codex-skills.sh` (new `validate_backlog_contract`, and its call)

**Interfaces:**
- Consumes: `backlog_graph.py plan` (Task 2), its JSON fields `status`, `scope`, `layers`, `edges`, `excluded`, `titles`, `run_id`, `run_dir`.
- Produces: `SKILL.md` sections `## Modes` and `## Shared rules`, which Task 6 extends; the variables `MAIN_ROOT` and `$SKILL_DIR`; the anchors of `planning.md`.

- [ ] **Step 1: Add the failing contract check**

In `scripts/check-codex-skills.sh`, add this function directly after `validate_worktree_base_contract` (the function Task 1 added above the call block), and add a bare `validate_backlog_contract` call line after the `validate_worktree_base_contract` call line:

```bash
validate_backlog_contract() {
  local skill_dir="$claude_root/implement-backlog-linear"
  local skill_md="$skill_dir/SKILL.md"
  local planning="$skill_dir/references/planning.md"

  # One portable source plans and runs a Linear backlog. Pin what makes a
  # plan safe to confirm: the script that owns the rules, the read-only
  # planning contract, and the exact /goal line the status line satisfies.
  require_literal "$skill_md" "(references/planning.md)"
  require_literal "$skill_md" "scripts/backlog_graph.py"
  require_literal "$skill_md" "human-blocked"
  forbid_literal "$skill_md" "AskUserQuestion"

  require_literal "$planning" "Planning is read-only"
  require_literal "$planning" "includeRelations"
  require_literal "$planning" 'until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"'
  require_literal "$planning" "Do not start execution from a planning run"

  require_literal "$root/catalog.json" '"name": "implement-backlog-linear"'
  require_literal "$root/README.md" '`implement-backlog-linear`'
}
```

- [ ] **Step 2: Run the check to see it fail**

Run: `bash /Users/calvinku/FunProjects/cktk/scripts/check-codex-skills.sh`
Expected: exit 1, including `missing Claude SKILL.md` and `missing Codex skill directory for implement-backlog-linear` (the directory exists since Task 2) and the missing-literal errors.

- [ ] **Step 3: Write `SKILL.md`**

Create `skills/implement-backlog-linear/SKILL.md`:

````markdown
---
name: implement-backlog-linear
description: "Plan and run every Linear issue an agent can finish without a person, for one team or project. Selects issues without human-setup or human-acceptance labels whose blockers are done or also selected, implements them in parallel worktrees through implement-ticket-linear, lands each on the base through a serial merge queue, marks it Done, and parks work that needs a person. A read-only plan comes first; execution runs from the /goal line it prints. Requires Linear MCP. Use for implement-backlog-linear or requests to work through a Linear backlog automatically."
---

# Run a Linear Backlog to Its Human Boundary

Work through every issue in one Linear scope that an agent can finish without a person, and stop where people are needed. `implement-ticket-linear` still does each issue's work; this skill selects the issues, schedules them, lands them, and reports. The user's `human-setup` and `human-acceptance` labels mark work that needs a person, and this skill adds `human-blocked` to work it could not finish.

Use the available authenticated Linear MCP tools and their actual schemas. Without issue reads, report that blocker; do not invent an API-key, CLI, or browser fallback.

## Modes

Accept keyed arguments, case-insensitive, with or without a space after the colon. Quoted values may contain spaces.

| Input | Meaning |
| --- | --- |
| `TEAM: <key/name/id>` | Linear team; optional only when a validated `.ai/cktk/project.json` supplies it |
| `PROJECT: <name/id/URL>` | Linear project. One project is one repository |
| `PARALLEL: <n>` | Implementation subagents at once; default 3 |
| `BASE: <branch>` | Branch that issues land on; default `main` |
| `RUN: <run-id>` | Execute a confirmed plan; takes no other input |

Without `RUN:`, plan: read [planning](references/planning.md). Planning is read-only and ends with a `/goal` line; pasting that line is the user's confirmation and starts execution.

```text
implement-backlog-linear TEAM: ENG PROJECT: "Website"
implement-backlog-linear                          # the bound team and project
implement-backlog-linear TEAM: ENG PARALLEL: 1
```

## Shared rules

- Resolve `MAIN_ROOT` from the absolute common git directory and verify it with `git worktree list --porcelain`. Select the directory explicitly on every shell call, and use absolute paths for file tools.
- `$SKILL_DIR` is this skill's real directory, resolved through installation symlinks. Run `$SKILL_DIR/scripts/backlog_graph.py` from there, never from the target project. It owns scope, selection, readiness, locking, and status lines; use its output instead of recomputing them.
- Run directories live under `$MAIN_ROOT/.worktrees/.cktk/runs/`. They are local and never staged.
- Before calling another skill, read its active host document for refusals, side effects, and argument modes, and pass the work directory, branch, issue, and authorized scope explicitly, as in `implement-ticket`'s [calls across skills](../implement-ticket/references/workspace.md#calls-across-skills).
- Answer in the user's language. Status lines and the `/goal` line keep their fixed English tokens.
````

- [ ] **Step 4: Write `references/planning.md`**

Create `skills/implement-backlog-linear/references/planning.md`:

````markdown
# Plan a backlog run

Planning is read-only: it makes no Linear writes and no commits. Its only write is a run directory under `$MAIN_ROOT/.worktrees/.cktk/runs/`, which git ignores.

## Resolve the scope

Read applicable repository instructions. If `.ai/cktk/project.json` exists, read the [project bindings contract](../../init-project/references/project-schema.md), and use its Linear team and project only when their status is `validated` or `read-only`.

- `TEAM` without `PROJECT`: plan the whole team. Pass a bound project to the planner only so that a scope stop can mark it.
- Neither: use the bound team and project. Without a usable binding, ask for the team.
- `PROJECT`: resolve it in Linear and confirm the team takes part in it.

Resolve the invoking Linear user (the `me` user) for the assignment check.

## Gather the snapshot

1. List the scope's open issues with one `list_issues` call per state type — `triage`, `backlog`, `unstarted`, and `started` — filtered by the team and, when given, the project. Follow every page. Request `id`, `title`, `statusType`, `labels`, `assigneeId`, `project`, and `parentId`.
2. For each listed issue, call `get_issue` with `includeRelations: true`, and record the identifiers it is blocked by and the identifiers it blocks.
3. For each referenced identifier that is not in the list, call `get_issue` once and record its state type. Completed blockers inside the scope are among them.
4. Write `$MAIN_ROOT/.worktrees/.cktk/runs/snapshot-input.json` in this shape:

```json
{
  "team": {"id": "<team id>", "key": "ENG"},
  "me": "<user id>",
  "requested_project": {"id": "<project id>", "name": "Website"},
  "binding_project": {"id": "<project id>", "name": "Website"},
  "issues": [
    {
      "id": "ENG-12",
      "title": "Add CSV export",
      "state_type": "backlog",
      "labels": ["frontend"],
      "assignee": null,
      "project": {"id": "<project id>", "name": "Website"},
      "parent": null,
      "blocked_by": ["ENG-10"],
      "blocks": ["ENG-13"]
    }
  ],
  "external": [
    {"id": "ENG-10", "state_type": "completed", "title": "Export service"}
  ]
}
```

Use `null` for an absent `requested_project`, `binding_project`, `assignee`, `project`, or `parent`. State types are Linear's: `triage`, `backlog`, `unstarted`, `started`, `completed`, and `canceled`.

## Run the planner

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" plan \
  --snapshot "$MAIN_ROOT/.worktrees/.cktk/runs/snapshot-input.json" \
  --runs-dir "$MAIN_ROOT/.worktrees/.cktk/runs" \
  --repo "$MAIN_ROOT" --base "<base>" --parallel <n> --host "<host>"
```

`<host>` is the invoking runtime, such as `claude` or `codex`. With `--repo`, the planner finds local work — registered `.worktrees/<ID>-*` worktrees, `linear-<ID>-*` branches, and `Merge linear-<ID>-…` commits on the base — so that an issue an earlier run left started can resume.

The output's `status` decides what follows:

- `stop`: report `binding-mismatch` (this repository is bound to a different project) or `multiple-projects` (list the projects and mark the bound one), and ask for `PROJECT:`. No run directory exists.
- `nothing-eligible`: report the exclusions, grouped as below. There is no run and no `/goal` line.
- `planned`: present the plan. `run_dir` holds `plan.json` and `snapshot.json`.

## Present the plan

In the user's language, show:

- the run id, the scope, and the result of the binding check;
- `PARALLEL`, recommending 1 when repository instructions show tests that share a port, database, or other fixed resource;
- `layers`: each issue with its title and its in-plan blockers from `edges`. Layers are for reading; execution starts an issue as soon as its blockers land;
- `excluded`, grouped by reason, with the blocking path for dependency exclusions, such as `ENG-24 ← ENG-23 ← ENG-20`;
- the preparatory writes execution may make: committing `.worktrees/` to `.gitignore` on the base when the line is missing, and creating the team label `human-blocked` when it is missing;
- that execution merges into the local base and never pushes, so Done will mean "merged into local `<base>`".

| Planner reason | Group |
| --- | --- |
| `human-gate` | Human gate, by `label`: `human-setup`, `human-acceptance`, or `human-blocked` (parked by an earlier run) |
| `someone-else` | Assigned to someone else |
| `not-triaged` | Still in triage |
| `running-elsewhere` | Started, with no work in this repository |
| `cycle` | Dependency cycle |
| `blocked` | Blocked. `roots` names each cause as `<kind>:<issue>`: a gate label, `outside-scope`, `canceled` (cancellation is not delivery, so a person decides whether the relation still holds), `cycle`, `unknown`, or one of the reasons above |

End with the `/goal` line. Localize its words but keep the quoted tokens, and use the host's explicit skill syntax — `/implement-backlog-linear` in Claude Code, `$implement-backlog-linear` in Codex:

```text
/goal Run /implement-backlog-linear RUN: <run-id> until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"
```

Pasting that line is the user's confirmation. Do not start execution from a planning run.
````

- [ ] **Step 5: Add the Codex metadata, tree links, catalog entry, and README row**

Create `skills/implement-backlog-linear/agents/openai.yaml`:

```yaml
interface:
  display_name: "Implement Backlog (Linear)"
  short_description: "Plan and run a Linear backlog up to human-gated work"
  default_prompt: "Use $implement-backlog-linear to plan the Linear issues an agent can finish without a person, then, after the user pastes the printed /goal line, implement them in parallel worktrees, land each on the base, update Linear, and park work that needs a person."

policy:
  allow_implicit_invocation: false
```

Create the links:

```bash
cd /Users/calvinku/FunProjects/cktk
ln -s ../../skills/implement-backlog-linear .agents/skills/implement-backlog-linear
ln -s ../../skills/implement-backlog-linear .agent/skills/implement-backlog-linear
```

In `catalog.json`, insert this entry directly after the `implement-ticket-linear` entry (keep the surrounding commas valid):

```json
    {
      "name": "implement-backlog-linear",
      "path": ".agent/skills/implement-backlog-linear",
      "description": "Plan every Linear issue in a team or project that an agent can finish without a person, then implement them in parallel worktrees through implement-ticket-linear, land each on the base through a serial merge queue, mark it Done, and park work that needs a person — a read-only plan first, execution driven by /goal (requires Linear MCP)",
      "portable": true
    },
```

In `README.md`, in the "Tickets and planning" table, add this row directly after the `implement-ticket` · `implement-ticket-linear` row:

```markdown
| `implement-backlog-linear` | Plan every Linear issue in a team or project that an agent can finish without a person — no `human-setup` or `human-acceptance` label, every blocker done or also planned — then implement them in parallel worktrees, land each on the base, and mark it Done | Two steps: a read-only plan, then execution from the `/goal` line it prints. Parks what it cannot finish with `human-blocked`; never pushes. Requires Linear MCP |
```

- [ ] **Step 6: Run the checks to see them pass**

Run:

```sh
cd /Users/calvinku/FunProjects/cktk
bash scripts/check-codex-skills.sh
python3 scripts/check-portable-skills.py
python3 scripts/test-agent-skills.py
python3 scripts/test-backlog-graph.py
```

Expected: `Validated 42 skill(s) across Claude, Codex, and Antigravity.`; `Validated 11 portable skill(s) from one source each.`; both test suites `OK`.

- [ ] **Step 7: Check the planning behavior with a fresh reader**

Dispatch one fresh subagent with this prompt, and compare each answer with the expected one:

```text
Read /Users/calvinku/FunProjects/cktk/skills/implement-backlog-linear/SKILL.md and its references/planning.md. For each scenario, say what the skill tells you to do next, and cite the file and section. Do not use any tools other than reading those files.

1. The user runs the skill with TEAM: ENG and no PROJECT. The team's open issues belong to two projects, and .ai/cktk/project.json binds this repository to one of them.
2. The planner returns status "planned".
3. The user asks you to start implementing right after seeing the plan, without pasting anything.
4. A planned issue's blocker is a canceled issue.
```

Expected: (1) a scope stop: list both projects, mark the bound one, ask for `PROJECT:`, no run directory; (2) present the run id, scope, parallelism, layers, grouped exclusions, the two preparatory writes, the no-push note, and end with the `/goal` line; (3) do not start execution from a planning run — the pasted `/goal` line is the confirmation; (4) it is excluded as `blocked` with a `canceled:<ID>` root, because cancellation is not delivery. Fix any document a mismatch points to, then rerun Step 6.

- [ ] **Step 8: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-backlog-linear/SKILL.md skills/implement-backlog-linear/references/planning.md \
  skills/implement-backlog-linear/agents/openai.yaml .agents/skills/implement-backlog-linear \
  .agent/skills/implement-backlog-linear catalog.json README.md scripts/check-codex-skills.sh
git commit -F - <<'EOF'
feat(implement-backlog-linear): plan a Linear backlog run

Add the portable implement-backlog-linear skill with its planning mode.
It gathers a team's or project's open issues and their relations from
Linear, lets backlog_graph.py select what an agent can finish without a
person, and presents the plan: layered issues, every exclusion grouped by
cause, the writes execution may make, and the exact /goal line whose
pasting confirms the plan. Planning makes no Linear writes and no commits.

Register the skill in all three trees, the catalog, and the README, and
pin its planning contract in check-codex-skills.sh.

Validation: check-codex-skills.sh, check-portable-skills.py,
test-agent-skills.py, test-backlog-graph.py

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 6: Execution mode — pre-flight, subagents, merge queue, parking, and reporting

**Files:**
- Create: `skills/implement-backlog-linear/references/execution.md`
- Create: `skills/implement-backlog-linear/references/subagent-briefs.md`
- Create: `skills/implement-backlog-linear/references/merge-queue.md`
- Create: `skills/implement-backlog-linear/references/stopping.md`
- Modify: `skills/implement-backlog-linear/SKILL.md` (`## Modes` and `## Shared rules`)
- Modify: `scripts/check-codex-skills.sh` (`validate_backlog_contract`)

**Interfaces:**
- Consumes: `backlog_graph.py next`, `halted`, `wait`, `lock`, `unlock`, `plan --dry-run` (Tasks 2–3); the Task 4 outcome; `SKILL.md` from Task 5.
- Produces: the anchors other references link to — `execution.md#refresh-the-state`, `execution.md#wait-for-results`, `merge-queue.md#3-land`, `merge-queue.md#4-update-linear`, `stopping.md#park-an-issue`, `stopping.md#halt-the-run`, `stopping.md#finish`.

- [ ] **Step 1: Extend the failing contract check**

In `validate_backlog_contract`, add these lines before its closing `}`:

```bash
  local execution="$skill_dir/references/execution.md"
  local queue="$skill_dir/references/merge-queue.md"
  local stopping="$skill_dir/references/stopping.md"
  local briefs="$skill_dir/references/subagent-briefs.md"
  local reference

  # Execution: every reference is reachable from the entry point, landing
  # goes through the existing merge and update skills, parking can never
  # overwrite labels, and subagents never wait on a person.
  for reference in execution.md merge-queue.md stopping.md subagent-briefs.md; do
    require_literal "$skill_md" "(references/$reference)"
  done
  require_literal "$skill_md" "authorization boundary"
  require_literal "$execution" 'backlog_graph.py" lock'
  require_literal "$execution" "wait_agent"
  require_literal "$queue" "merge-worktree-linear"
  require_literal "$queue" "update-ticket-linear"
  require_literal "$queue" "Never reset"
  require_literal "$stopping" 'addLabels: ["human-blocked"]'
  require_literal "$stopping" 'Never send `labels`'
  require_literal "$stopping" "/goal resume"
  require_literal "$briefs" "<ISSUE> worktree <BASE>"
  require_literal "$briefs" "never wait for an answer"
```

- [ ] **Step 2: Run the check to see it fail**

Run: `bash /Users/calvinku/FunProjects/cktk/scripts/check-codex-skills.sh`
Expected: exit 1, with `must contain` errors for `SKILL.md` and the four missing references (reported as missing files).

- [ ] **Step 3: Extend `SKILL.md`**

In `skills/implement-backlog-linear/SKILL.md`, directly after the paragraph beginning "Without `RUN:`, plan:", add:

```markdown
With `RUN:`, execute a confirmed plan: read [execution](references/execution.md), then [merge queue](references/merge-queue.md) and [stopping](references/stopping.md) as results reach them. Subagents receive the [subagent briefs](references/subagent-briefs.md).
```

Add this line at the end of the `text` example block, before its closing fence:

```text
implement-backlog-linear RUN: ENG-website-20260926-1430
```

Append these bullets to `## Shared rules`:

```markdown
- The confirmed plan is the authorization boundary: execution may shrink it and never grows it. `RUN:` authorizes, for planned issues only, the preparatory `.gitignore` commit and label creation the plan names, implementation and commits in issue worktrees, merges into the base, Linear updates through `update-ticket-linear`, and parking. It does not authorize pushing, pull requests, or optional document follow-ups whose preference is `ask`.
- Only this skill adds `human-blocked`, and only through an append-only label operation.
```

- [ ] **Step 4: Write `references/execution.md`**

Create the file with this content. Replace `<CLAUDE CODE WAITING>` with the text for the Task 4 outcome, filling in the date and version recorded there.

Outcome A:

```text
end the turn once the subagents are dispatched; each completion notification resumes the run. The spike of <date> (Claude Code <version>) found that background subagents do not use up goal checks.
```

Outcome B:

```text
do not end the turn while subagents run: each ended turn is a goal check, and repeated unmet checks within one turn pause the goal (spike of <date>, Claude Code <version>). Run the bounded wait below in the foreground, again after each exit 124.
```

Outcome C:

```text
subagents cannot be awaited without pausing the goal (spike of <date>, Claude Code <version>). Run with `PARALLEL` 1 and implement each issue in this session through `implement-ticket-linear`, in plan order, under the implementation brief's limits.
```

````markdown
# Execute a confirmed run

`RUN: <run-id>` both starts and resumes a run: it derives progress from Linear and git every time. Below, `RUNS` is `$MAIN_ROOT/.worktrees/.cktk/runs`, `RUN_DIR` is `$RUNS/<run-id>`, and `<host>` is the invoking runtime.

## Pre-flight

At every start and resume, from `MAIN_ROOT`:

1. Load `$RUN_DIR/plan.json`. If it is missing, or its `repo` is not this `MAIN_ROOT`, [halt](stopping.md#halt-the-run).
2. Take the lock:

   ```sh
   python3 "$SKILL_DIR/scripts/backlog_graph.py" lock --runs-dir "$RUNS" --run-id <run-id> --host <host>
   ```

   Exit 3 means another run holds `$RUNS/ACTIVE`: halt and name that file, which the user removes if that session is gone. A lock that names this run is a resume, and the command takes it over.
3. [Refresh the state](#refresh-the-state). Issues it reports as removed leave the plan; nothing is ever added.
4. The main checkout must be on the base and clean. Switch a clean checkout on another branch to the base, and say so. Any other change halts the run, except one state that step 6 repairs: `.gitignore` lacks the `.worktrees/` line or carries it as its only uncommitted change, and the only other entry is an untracked `.worktrees/`.
5. When `origin` exists, fetch `origin/<base>`. Fast-forward a local base that is behind; halt if the two have diverged.
6. If the committed `.gitignore` on the base lacks `.worktrees/`, add that line, then commit only that file with the message `chore: ignore .worktrees/`. Do this before any worktree exists; otherwise every subagent's worktree setup edits the same file.
7. Make sure the team has the label `human-blocked`. If it is missing, create it as a team label with the current label tool, such as `save_issue_label`.
8. Find the host's subagent facility. Without one, run with `PARALLEL` 1 and implement each issue in this session, in plan order, under the implementation brief's limits.

## Refresh the state

Before each dispatch round and after each landing, read the plan's issues fresh: `list_issues` for the scope once per open state type, plus `completed` and `canceled` filtered to `updatedAt` on or after the plan's `created_at`; then `get_issue` for any planned issue still missing. For each issue about to be dispatched, also read its relations with `get_issue` and `includeRelations: true`. Write `$RUN_DIR/state.json`:

```json
{
  "issues": {
    "ENG-12": {"state_type": "started", "labels": [], "assignee": "<user id>", "blocked_by": ["ENG-10"]}
  },
  "external": {"DATA-7": {"state_type": "completed"}},
  "in_flight": ["ENG-15"]
}
```

`in_flight` lists issues dispatched or waiting in the merge queue. `blocked_by` is needed only for issues whose relations were just read, and `external` gives the state type of any blocker outside the plan that they name. Then run:

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" next --plan "$RUN_DIR/plan.json" --state "$RUN_DIR/state.json" --repo "$MAIN_ROOT"
```

Act on its output:

- `ready`: issues to dispatch, in plan order.
- `landed_not_done`: merged but not yet Done; continue each at [update Linear](merge-queue.md#4-update-linear).
- `removed`: issues that left the plan — newly gated, canceled, reassigned, given a new unfinished blocker, blocked by a parked or removed issue, or `stuck` because nothing could make them ready. Report them; do not touch them.
- `status_line`: the run's progress. Start every message that ends a turn with it. When it shows `AI-ELIGIBLE 0`, [finish](stopping.md#finish).

## Dispatch

Keep up to `PARALLEL` subagents busy, one issue each, and fill a free slot as soon as an issue is ready. Use the implementation brief in [subagent briefs](subagent-briefs.md).

Before dispatching a ready issue, look for `$RUN_DIR/results/<ISSUE>.json` from an earlier session: a `complete` result whose commits are on the issue's branch goes straight to the [merge queue](merge-queue.md), and counts as in flight. A started issue with a worktree or branch but no usable result is dispatched again; `implement-ticket-linear` continues its existing work.

Do not request a host-managed worktree or isolation mode for a subagent: the brief creates the repository's own worktree.

## Wait for results

Wait in the way that keeps the host's `/goal` alive:

- Codex: `wait_agent` on the running subagents.
- Claude Code: <CLAUDE CODE WAITING>
- Another host: its blocking wait, or the bounded wait below.

The bounded wait returns when a result file appears, or exits 124 when its timeout passes; then refresh the state and wait again:

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" wait --results-dir "$RUN_DIR/results" --known "<results already handled, comma-separated>" --timeout 540
```

## Route each result

Read `$RUN_DIR/results/<ISSUE>.json`:

| Verdict | Next |
| --- | --- |
| `complete` | The [merge queue](merge-queue.md) |
| `incomplete` or `needs-decision` | [Park](stopping.md#park-an-issue) with the result's `blocker` |
| `failed`, or a malformed result | Dispatch once more, to the same worktree; a second failure parks the issue |

When two consecutive results fail with the same environment error, such as the same dependency installation or service start failure, [halt](stopping.md#halt-the-run) instead: the problem is not in the issues.
````

- [ ] **Step 5: Write `references/subagent-briefs.md`**

````markdown
# Subagent briefs

Fill every `<placeholder>`, then give the brief to a fresh subagent through the host's facility, such as the Agent tool in Claude Code or `spawn_agent` in Codex. `<CKTK_ROOT>` is the cktk checkout that contains this skill, resolved through installation symlinks. Paste the result-file section below into each brief where it says so.

## Result file

Finish by writing `<RUN_DIR>/results/<NAME>.json` — first as `<NAME>.json.tmp`, then renamed, so a half-written file is never read — and return exactly the same JSON as your final message:

```json
{
  "issue": "ENG-12",
  "verdict": "complete",
  "branch": "linear-ENG-12-add-csv-export",
  "worktree": "/abs/path/.worktrees/ENG-12-add-csv-export",
  "commits": ["<sha>"],
  "checks": [{"command": "npm test", "result": "pass"}],
  "business_summary": "One or two sentences on what this now lets users do.",
  "blocker": null
}
```

`verdict` is one of:

- `complete`: acceptance is met and the work is committed. `commits` may be empty when nothing needed to change, as for a parent its sub-issues already delivered.
- `incomplete`: work remains; `blocker` explains why.
- `needs-decision`: a person must choose; `blocker.options` lists the choices and their consequences.
- `failed`: the run itself broke, such as a tool error.

A `blocker` has `kind` (`decision`, `environment`, `defect`, or `prerequisite`), `question`, `evidence`, `options`, and `suggestion`.

## Implementation brief

```text
You are implementing one Linear issue in an unattended backlog run. Nobody is watching this run, so never wait for an answer.

Issue: <ISSUE>
Run: <RUN_ID>, run directory <RUN_DIR>
Main repository: <MAIN_ROOT>
Base: <BASE>
Skill: read <CKTK_ROOT>/skills/implement-ticket-linear/SKILL.md and follow it.

1. Run implement-ticket-linear with the arguments "<ISSUE> worktree <BASE>". It creates or reuses <MAIN_ROOT>/.worktrees/<ISSUE>-<slug> on the branch linear-<ISSUE>-<slug>. Work only in that worktree.
2. You are authorized to commit this issue's changes in that worktree through commit-ticket, and to make the start transition implement-ticket-linear performs. You are not authorized to merge, push, open a pull request, change any other Linear state, post comments, or change labels.
3. Where implement-ticket-linear says to stop and ask the user — a business contradiction, a missing decision, missing required acceptance — stop without waiting, and put the question, the evidence, and the options in the result.
4. <NAME> is <ISSUE>.

<result-file section>
```

## Repair brief

```text
You are repairing one issue branch so that it merges cleanly into <BASE> in an unattended backlog run. Nobody is watching this run, so never wait for an answer.

Issue: <ISSUE>
Worktree: <WORKTREE>, branch <BRANCH>
State: <BASE> is being merged into the branch; <the conflicted files, or "merged; these checks fail: …">
This issue's intent: <one paragraph from the issue and its result summary>
Landed issues touching the same files: <ISSUE — intent>, one per line
Checks to pass: <commands>

1. Work only in <WORKTREE>. Resolve the merge so that every issue's intended behavior survives, then run the checks.
2. If the issues require incompatible behavior, do not choose between them. Run git merge --abort if the merge is unfinished, and return needs-decision with both behaviors and their consequences.
3. On success, commit the merge in the worktree. Never reset, rebase, force, or discard commits.
4. <NAME> is <ISSUE>.repair.

<result-file section>
```
````

- [ ] **Step 6: Write `references/merge-queue.md`**

````markdown
# Land issues through the merge queue

Only this session lands work, from `MAIN_ROOT`, one issue at a time and first come, first served, so the base never moves between an issue's sync and its landing.

## 1. Sync

In the issue's worktree, merge the local base into the issue branch:

```sh
git -C "<worktree>" merge --no-edit "<base>"
```

- Already up to date: the subagent's checks stand. Go to [land](#3-land).
- Merged cleanly: rerun the result's checks and the repository's required checks in the worktree. If they pass, go to [land](#3-land).
- A conflict, or failing checks: [repair](#2-repair-once).

## 2. Repair once

List the issues this run landed that touch each conflicting or failing file:

```sh
git -C "$MAIN_ROOT" log --first-parent --merges --since="<plan created_at>" --format=%s "<base>" -- "<file>"
```

Each `Merge linear-<ID>-… into <base>` subject names one. Dispatch the repair brief from [subagent briefs](subagent-briefs.md) with those issues' intents, and wait for `<ISSUE>.repair.json` as in [execution](execution.md#wait-for-results).

- `complete`: rerun the checks yourself; if they pass, go to [land](#3-land).
- Anything else, or failing checks: [park](stopping.md#park-an-issue) the issue. Run `git -C "<worktree>" merge --abort` if a merge is still unfinished; a committed repair attempt stays, and the parking comment names it. Never reset.

## 3. Land

Read `merge-worktree-linear`'s active host document, then invoke it from `MAIN_ROOT` with `<ISSUE> <base>`. Its preconditions hold here — this session is outside the worktree, the main checkout is clean, and the worktree's work is committed — so it raises no prompt. It merges with `--no-ff`, removes the worktree, and deletes the local branch. An issue with nothing to land is reported as already merged, and still goes on to the Linear update.

If it refuses, or reports a conflict, something moved the base or changed the main checkout during the run: [halt](stopping.md#halt-the-run).

## 4. Update Linear

Read `update-ticket-linear`'s active host document, then invoke it for `<ISSUE>` in auto mode. Supply `WORK_DIR` as `MAIN_ROOT`, the base, the merge commit, and the result's checks and summary as completion evidence. State this run's policy for optional document follow-ups: follow a preference of `always`; for `ask`, consent is not given in this run, so keep the prepared content for the final report; skip `never`.

- Marked Done: its dependents may now be ready.
- Not marked Done: [park](stopping.md#park-an-issue) the issue, stating that its code is already on the base. Its dependents stay blocked.

## 5. Continue

[Refresh the state](execution.md#refresh-the-state), dispatch newly ready issues, and take the next queued result.
````

- [ ] **Step 7: Write `references/stopping.md`**

````markdown
# Park, halt, and finish

`RUNS` and `RUN_DIR` are as in [execution](execution.md).

## Park an issue

Park an issue when its result is `incomplete` or `needs-decision`, when its repair fails, when `update-ticket-linear` will not mark it Done, or when it fails twice.

1. Add the label with an append-only operation: `save_issue` with `addLabels: ["human-blocked"]`. Never send `labels`, which replaces the issue's whole label set.
2. Read the issue's comments. Unless this run's parking comment is already there, post one comment in the structure `implement-ticket`'s [delivery](../../implement-ticket/references/delivery.md) uses for an incomplete result:
   - the remaining problem, and how it limits the intended workflow;
   - the obstacle and its evidence;
   - a concrete resolution; for a decision, the options and the consequence of each;
   - where the work is: the worktree and branch, or "already merged into `<base>`";
   - that removing `human-blocked` lets the next plan take the issue again.
3. Leave the workflow state, worktree, and branch as they are, and [refresh the state](execution.md#refresh-the-state): the planner removes the issue's planned dependents from this run.

## Halt the run

Halt when a condition affects every issue:

- the main checkout changes, or cannot return to the base;
- the base diverges from `origin/<base>`, including a fast-forward refusal inside `merge-worktree-linear`;
- Linear reads or writes fail for access reasons;
- the plan is missing, belongs to another repository, or another run holds the lock;
- two consecutive results fail with the same environment error.

Dispatch nothing new, and let running subagents finish; their work stays in their worktrees for the next run. Release the lock unless another run holds it:

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" unlock --runs-dir "$RUNS" --run-id <run-id>
```

Start the report with the halted status line, then give the cause and what the user should fix, and end with the same `/goal` line so the run can resume:

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" halted --plan "$RUN_DIR/plan.json" --reason "<short reason>"
```

| Stop | Decided by | Goal state | Resume |
| --- | --- | --- | --- |
| Halt | This skill: continuing is unsafe | Ended, through its `HALTED` branch | Fix the cause, then paste the same `/goal` line, in either host |
| Goal pause | The host: usage limit, goal-check cap, API error, check timeout | Still set, paused | Claude Code: send a message. Codex: `/goal resume` |

## Finish

When the status line shows `AI-ELIGIBLE 0`, release the lock and write the final report. Start it with the status line; then, in the user's language, cover:

- the issues completed in this run, each with one line of business meaning from its result;
- parked issues, with the obstacle, where the work is, and the recommended resolution;
- human-gated issues, and the issues blocked by them or by parked issues;
- optional document follow-ups skipped because their preference is `ask`, with the prepared content;
- issues that became eligible outside the plan: gather a fresh snapshot, run the planner with `--dry-run`, and list issues in its `order` that this plan does not contain, suggesting a new plan;
- how many commits the base is ahead of `origin/<base>`, and that this run did not push.
````

- [ ] **Step 8: Run the checks to see them pass**

```sh
cd /Users/calvinku/FunProjects/cktk
bash scripts/check-codex-skills.sh
python3 scripts/check-portable-skills.py
python3 scripts/test-backlog-graph.py
```

Expected: `Validated 42 skill(s) …`, `Validated 11 portable skill(s) …`, and `OK`.

- [ ] **Step 9: Check the execution behavior with a fresh reader**

Dispatch one fresh subagent with this prompt, and compare each answer with the expected one:

```text
Read /Users/calvinku/FunProjects/cktk/skills/implement-backlog-linear/SKILL.md and every file in its references/ directory. For each scenario during a RUN, say what the skill tells you to do next, and cite the file and section. Do not use any tools other than reading those files.

1. A subagent's result has verdict needs-decision.
2. merge-worktree-linear refuses because the fast-forward from origin failed: the local base has diverged.
3. update-ticket-linear prepares a Project Context update, and the binding's preference is "ask".
4. Three subagents are running, and no other issue is ready. You are in Claude Code.
5. A planned issue gains the human-acceptance label during the run.
6. A result file for ENG-12 exists but does not parse as JSON; it is the first failure for ENG-12.
7. The status line shows AI-ELIGIBLE 0.
```

Expected: (1) park — `addLabels: ["human-blocked"]`, one comment with the options and consequences, state and worktree untouched, then refresh so its dependents leave the run; (2) halt — dispatch nothing new, let subagents finish, release the lock, report with the halted status line and the same `/goal` line; (3) do not ask — consent is not given in this run; keep the prepared content for the final report; (4) the Task 4 outcome's waiting paragraph; (5) the refresh removes it and its dependents; report them and do not touch them; (6) dispatch once more to the same worktree; a second failure parks it; (7) finish — release the lock and write the final report, including the dry-run check for newly eligible issues and the unpushed commit count. Fix any document a mismatch points to, then rerun Step 8.

- [ ] **Step 10: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-backlog-linear scripts/check-codex-skills.sh
git commit -F - <<'EOF'
feat(implement-backlog-linear): execute a confirmed backlog run

Add RUN mode. Pre-flight takes the repository's run lock, re-reads the
plan's issues, requires a clean main checkout on the base, commits the
.worktrees/ ignore line before any worktree exists, and ensures the
human-blocked label. Subagents implement ready issues through
implement-ticket-linear in their own worktrees and report a fixed result
file without ever waiting on a person. A serial merge queue syncs each
branch with the base, repairs a conflict once, lands it through
merge-worktree-linear, and marks it Done through update-ticket-linear, so
Done always means merged. Work that needs a person is parked with an
append-only label and a comment; conditions that affect every issue halt
the run with a status line /goal can end on.

Validation: check-codex-skills.sh, check-portable-skills.py,
test-backlog-graph.py, and a fresh-reader scenario check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 7: Document the backlog run in the README

**Files:**
- Modify: `README.md` ("Linear issues" walkthrough, the batch sentence in "Inputs and variants", the portable-skill sentence, and "Validation")
- Modify: `scripts/check-codex-skills.sh` (`validate_backlog_contract`)

**Interfaces:**
- Consumes: the `/goal` line and invocation forms from Tasks 5–6.

- [ ] **Step 1: Extend the failing contract check**

Add to `validate_backlog_contract`, before its closing `}`:

```bash
  # The README walks through the two-step run and names the planner's tests.
  require_literal "$root/README.md" "**A whole Linear backlog**"
  require_literal "$root/README.md" 'until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"'
  require_literal "$root/README.md" "python3 scripts/test-backlog-graph.py"
```

Run: `bash /Users/calvinku/FunProjects/cktk/scripts/check-codex-skills.sh`
Expected: exit 1 with three `README.md must contain` errors.

- [ ] **Step 2: Add the walkthrough**

In `README.md`, directly after the paragraph that follows the **Linear issues** code block (it starts `Linear assigns the issue ID`), add:

````markdown
**A whole Linear backlog**

```text
$implement-backlog-linear TEAM: ENG PROJECT: "Account Platform"
/goal Run $implement-backlog-linear RUN: ENG-account-platform-20260926-1430 until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"
```

The first command only plans. It selects every issue without a `human-setup` or `human-acceptance` label whose blockers are done or also selected — a parent once its sub-issues are — and shows why each other issue was left out. Pasting the `/goal` line it prints confirms the plan and starts the run: subagents implement ready issues in their own worktrees through `implement-ticket-linear`, one serial merge queue lands each issue on the local base, and `update-ticket-linear` marks it Done, which unblocks the next issues. An issue the run cannot finish gets the `human-blocked` label and a comment explaining what a person needs to do; removing the label lets the next plan take it again. The run never pushes. If it halts, fix the reported cause and paste the same `/goal` line again.
````

- [ ] **Step 3: Update the batch, portable-set, and validation sentences**

In `README.md`, replace:

```markdown
A missing ticket ID may be resolved from unambiguous conversation or branch context; it never starts the entire backlog. Batches require an explicit scope.
```

with:

```markdown
A missing ticket ID may be resolved from unambiguous conversation or branch context; it never starts the entire backlog. Batches require an explicit scope; `implement-backlog-linear` is the explicit way to work through a Linear backlog.
```

Replace:

```markdown
The eight ticket lifecycle skills (`create-tickets`, `create-tickets-linear`, both `implement-ticket` variants, `commit-ticket`, `commit-push-pr`, and both `update-ticket` variants), plus the `product-manager` conversation mode, have one agent-neutral source under `skills/`.
```

with:

```markdown
The ticket lifecycle skills `create-tickets`, `create-tickets-linear`, `explain-ticket`, both `implement-ticket` variants, `implement-backlog-linear`, `commit-ticket`, `commit-push-pr`, and both `update-ticket` variants, plus the `product-manager` conversation mode, have one agent-neutral source under `skills/`.
```

(`explain-ticket` is already portable in `catalog.json`; the sentence had omitted it.)

Replace:

```markdown
Installer changes use `python3 scripts/test-agent-skills.py` with isolated homes.
```

with:

```markdown
Installer changes use `python3 scripts/test-agent-skills.py` with isolated homes. Run `python3 scripts/test-backlog-graph.py` when changing the backlog planner.
```

- [ ] **Step 4: Run the checks to see them pass**

Run: `bash /Users/calvinku/FunProjects/cktk/scripts/check-codex-skills.sh`
Expected: exit 0, `Validated 42 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 5: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add README.md scripts/check-codex-skills.sh
git commit -F - <<'EOF'
docs(readme): walk through a Linear backlog run

Show the two-step implement-backlog-linear flow — a read-only plan, then
the /goal line that confirms and runs it — with what happens to issues
that need a person and how to resume a halted run. Point batch requests
at the new skill, list it with the other portable lifecycle skills
(adding the omitted explain-ticket), and name the planner's test suite.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 8: Read-only planning run against a real Linear project

This task needs the user and a live Linear MCP connection. It verifies planning on real data; it writes nothing to Linear.

**Files:**
- Modify (only if the run exposes a defect): `skills/implement-backlog-linear/scripts/backlog_graph.py`, `scripts/test-backlog-graph.py`, `skills/implement-backlog-linear/references/planning.md`

- [ ] **Step 1: Choose the target with the user**

Ask the user for a repository and its Linear team and project, ideally one with `human-setup` or `human-acceptance` issues, blocking relations, and at least one parent issue.

- [ ] **Step 2: Record the starting state**

```sh
git -C "<repo>" rev-parse HEAD
git -C "<repo>" status --porcelain
```

- [ ] **Step 3: Run the planning mode from this branch**

In a session opened in `<repo>`, give the agent:

```text
Read /Users/calvinku/FunProjects/cktk/skills/implement-backlog-linear/SKILL.md and follow it with: TEAM: <team> PROJECT: "<project>"
```

This reads the branch's skill directly, so no reinstall is needed.

Expected: either a scope stop that names the reason, or a plan with a run id, layers, grouped exclusions, the preparatory writes, the no-push note, and the `/goal` line.

- [ ] **Step 4: Confirm it wrote nothing**

```sh
git -C "<repo>" rev-parse HEAD
git -C "<repo>" status --porcelain
```

Expected: the same HEAD. Status is unchanged, except `?? .worktrees/` when the repository did not ignore `.worktrees/` yet — the state execution's pre-flight repairs. Open two or three listed issues in Linear and confirm their history shows no change from this session.

- [ ] **Step 5: Review the plan with the user**

For every excluded issue, the user confirms the reason matches their understanding; for every planned issue, the user confirms an agent may do it. For each disagreement:

- a selection rule is wrong: add a failing test to `scripts/test-backlog-graph.py` that reproduces it, fix `backlog_graph.py`, and run `python3 scripts/test-backlog-graph.py`;
- the snapshot missed or misread data: fix the gathering steps in `planning.md`, and rerun `bash scripts/check-codex-skills.sh`.

Rerun Steps 3–4 after each fix.

- [ ] **Step 6: Commit any fixes**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-backlog-linear scripts/test-backlog-graph.py
git commit -F - <<'EOF'
fix(implement-backlog-linear): <what the real-project planning run exposed>

<The observed plan, the expected plan, and the rule or gathering step
that differed.>

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

Replace the angle-bracketed lines with the actual finding. Skip this step when the run exposed nothing.

---

### Task 9: End-to-end rehearsal in Claude Code and Codex

This task creates Linear data and runs real merges in a throwaway repository. Get the user's explicit go-ahead first, and let them choose the Linear team.

**Files:**
- Modify (only if the rehearsal exposes a defect): the files it points to, with a test first for any planner defect.

- [ ] **Step 1: Create the throwaway repository with an origin**

```sh
REHEARSAL="$(mktemp -d "${TMPDIR:-/tmp}/cktk-backlog-rehearsal.XXXXXX")"
git init -q --bare -b main "$REHEARSAL/origin.git"
git clone -q "$REHEARSAL/origin.git" "$REHEARSAL/repo"
cd "$REHEARSAL/repo"
cat > AGENTS.md <<'EOF'
# Rehearsal project
Python 3 standard library only. Run `python3 -m unittest` before committing.
EOF
cat > greetings.py <<'EOF'
GREETINGS = {
    "en": "Hello",
}


def greet(language="en"):
    return GREETINGS[language]
EOF
cat > test_greetings.py <<'EOF'
import unittest

from greetings import greet


class GreetTests(unittest.TestCase):
    def test_english(self):
        self.assertEqual(greet(), "Hello")


if __name__ == "__main__":
    unittest.main()
EOF
git add . && git -c user.email=test@example.com -c user.name=Test commit -qm "Initial rehearsal project"
git push -q origin main
```

- [ ] **Step 2: Create the rehearsal issues**

With the user's go-ahead, create a Linear project named `cktk backlog rehearsal A` in their chosen team, with these issues and native relations:

| Handle | Title | Setup |
| --- | --- | --- |
| R1 | Add a farewell function | none |
| R2 | Add a shout helper that uppercases any greeting | none |
| R3 | Let greet() take a name ("Hello, Ada") | blocked by R1 |
| R4 | Localization | parent of R5 and R6 |
| R5 | Add Spanish to GREETINGS | sub-issue of R4 |
| R6 | Add French to GREETINGS | sub-issue of R4; edits the same dictionary as R5, so their merge conflicts |
| R7 | Configure the production greeting API key | label `human-setup` |
| R8 | Call the greeting API | blocked by R7 |
| R9 | Choose the greeting tone | description requires every greeting to be formal, which contradicts the rule added to `AGENTS.md` below — a business contradiction the run must park |

Each description states its acceptance criteria as observable `python3 -m unittest` behavior. Before planning, add the rule R9 contradicts:

```sh
cd "$REHEARSAL/repo"
printf 'Greetings are always casual.\n' >> AGENTS.md
git -c user.email=test@example.com -c user.name=Test commit -qam "Record the greeting tone rule"
git push -q origin main
```

- [ ] **Step 3: Plan and run in Claude Code**

In Claude Code, in `$REHEARSAL/repo`:

```text
Read /Users/calvinku/FunProjects/cktk/skills/implement-backlog-linear/SKILL.md and follow it with: PROJECT: "cktk backlog rehearsal A" TEAM: <team>
```

Expected plan: layers `[R1, R2, R5, R6, R9]`, `[R3, R4]`; excluded `R7` (`human-gate`, `human-setup`) and `R8` (`blocked`, root `human-setup:R7`). Paste the printed `/goal` line.

- [ ] **Step 4: Check the Claude Code outcome**

```sh
cd "$REHEARSAL/repo"
git log --first-parent --oneline main
git -C "$REHEARSAL/origin.git" log --oneline main
git worktree list
python3 -m unittest
```

Expected:

- the final status line reads `AI-ELIGIBLE 0 · DONE 6 · PARKED 1 · HUMAN-GATED 1 · BLOCKED 1` when the R5/R6 conflict is repaired, or `AI-ELIGIBLE 0 · DONE 4 · PARKED 2 · HUMAN-GATED 1 · BLOCKED 2` when one of them is parked, because R4 then leaves the run;
- `main` has one `Merge linear-<ID>-… into main` commit for each of R1, R2, R3, R5, and R6, and none for R4 (nothing to land) or R9;
- `origin.git` still has only the initial and AGENTS.md commits;
- R5 and R6 were landed by repairing their conflict once, or one of them is parked with a comment naming the conflict;
- R9 has `human-blocked`, one comment laying out the formal-versus-casual decision, and a retained worktree;
- R7 and R8 are untouched in Linear; the unit tests pass on `main`.

- [ ] **Step 5: Repeat in Codex**

Create `cktk backlog rehearsal B` with the same issues, and a fresh repository from Step 1. Run the same two steps in Codex (use `$implement-backlog-linear` in the pasted line) and check the same outcomes.

- [ ] **Step 6: Fix what the rehearsal exposed**

For each deviation, write a failing test first when the planner is at fault, fix the document or script, rerun the checks from Task 6 Step 8, and commit with a message naming the rehearsal finding.

- [ ] **Step 7: Clean up with the user**

Ask the user before archiving or deleting the two rehearsal projects and their issues in Linear. Then remove the throwaway directories: `rm -rf "$REHEARSAL"` for each rehearsal, and `rm -rf "$SPIKE"` from Task 4.
