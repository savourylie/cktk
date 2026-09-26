# Land issues through the merge queue

Only this session lands work, from `MAIN_ROOT`, one issue at a time and first come, first served, so the base never moves between an issue's sync and its landing. `RUN_DIR` is as in [execution](execution.md).

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

Read `update-ticket-linear`'s active host document, then invoke it for `<ISSUE>` in auto mode. Supply `WORK_DIR` as `MAIN_ROOT`, the base, the merge commit, and the result's checks and summary as completion evidence. State this run's policy for optional document follow-ups: follow a preference of `always`; for `ask`, consent is not given in this run, so save the prepared content as `$RUN_DIR/followups/<ISSUE>.md` for the final report; skip `never`.

- Marked Done: its dependents may now be ready.
- Not marked Done: [park](stopping.md#park-an-issue) the issue, stating that its code is already on the base. Its dependents stay blocked.

## 5. Continue

[Refresh the state](execution.md#refresh-the-state), dispatch newly ready issues, and take the next queued result.
