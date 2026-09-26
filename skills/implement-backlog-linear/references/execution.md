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
- Claude Code: end the turn once the subagents are dispatched; each completion notification resumes the run. The spike of 2026-09-26 (Claude Code 2.1.283) found that background subagents do not use up goal checks.
- Another host: its blocking wait, or the bounded wait below.

The bounded wait returns when a result file appears, or exits 124 when its timeout passes; then refresh the state and wait again:

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" wait --results-dir "$RUN_DIR/results" --known "<results already handled, comma-separated>" --timeout 540
```

`--known` lists the result names already routed. Remove an issue's name when it is dispatched again, so its new result is seen.

## Route each result

Read `$RUN_DIR/results/<ISSUE>.json`. First [refresh the state](#refresh-the-state): if `next` now lists the issue under `removed`, leave its result and worktree as they are and report it, without landing it. Otherwise route it:

| Verdict | Next |
| --- | --- |
| `complete` | The [merge queue](merge-queue.md) |
| `incomplete` or `needs-decision` | [Park](stopping.md#park-an-issue) with the result's `blocker` |
| `failed`, or a malformed result | Rename the result to `<ISSUE>.json.failed` and dispatch once more, to the same worktree. If `<ISSUE>.json.failed` already exists, this is the second failure: park the issue |

When two consecutive results fail with the same environment error, such as the same dependency installation or service start failure, [halt](stopping.md#halt-the-run) instead: the problem is not in the issues.
