---
name: "merge-worktree-linear"
description: "Use when the user explicitly asks to merge one or more Linear issue worktrees back into their base branch and clean them up. Does not require Linear MCP and writes nothing to Linear. Prefer explicit invocation with $merge-worktree-linear."
---

# Merge Linear Issue Worktrees

Close the loop on `$create-worktree-linear`: merge each Linear issue's branch into its base, then remove the worktree and delete the local branch. Already-merged branches (typical after a GitHub PR merge) are detected and only cleaned up. Treat this as an explicit workflow skill because it merges, removes directories, and deletes branches.

This skill **does not require Linear MCP** — the worktree, the branch, and the issue id are all on disk, so cleanup must not fail because a service is unreachable. If MCP is present it is used only to read an issue title for commit-message context; its absence is never an error. It never writes to Linear; that is `$update-ticket-linear`'s job.

## Phase 1: Parse Arguments

1. Split on whitespace and classify:
   - **Issue reference** if it matches `^[A-Za-z]+-\d+$` (case-insensitive; uppercase the team key) or is a `linear.app` URL containing one.
   - **`no-cleanup` flag** if it matches `^no-cleanup$` (case-insensitive). Preserves the local branch; the worktree directory is still removed. Does not consume the base slot.
   - **Base branch** otherwise. At most one; two or more → report the conflict and stop.
2. Require at least one issue reference. Default the base to `main`.

Examples:
- `$merge-worktree-linear ENG-42` → issues `[ENG-42]`, base `main`
- `$merge-worktree-linear ENG-42 dev no-cleanup` → issues `[ENG-42]`, base `dev`, branch retained

**Trailing-token tiebreak, resolved on disk.** If a trailing id-looking token has no worktree under `.worktrees/<token>-*` and no branch matching `linear-<token>-*`, but resolves as a branch, treat it as the base and say so. Otherwise report it as an issue with nothing to merge.

## Phase 2: Resolve Repo Root and Handles

1. `MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`
2. Per issue, discover by id prefix — the canonical forms created by `$create-worktree-linear` and `$implement-ticket-linear` are `.worktrees/<issue_id>-<slug>` and `linear-<issue_id>-<slug>`:
   - Worktree: a registered path under `$MAIN_ROOT/.worktrees/<issue_id>-*` in `git worktree list --porcelain`.
   - Branch: `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`. `--format` is required; plain output carries `+ ` / `* ` markers that are not part of the name.
   - Two or more matches → report, skip that issue, continue. Neither → "already cleaned up".

## Phase 3: Pre-flight (once, whole batch)

1. **Refuse if the cwd is inside a target worktree** — removing it would orphan the shell. Tell the user to `cd "$MAIN_ROOT"`.
2. **Main checkout must be clean**, with one carve-out: `$create-worktree-linear` leaves `.gitignore` uncommitted after adding `.worktrees/`. When that file is the only dirty entry (` M .gitignore` or `?? .gitignore`) and its only change is that line, ask once — "Commit it so the merge can proceed? [Y/n]" — and on anything but an explicit no, commit just that file. Any other dirty state refuses.
3. `git -C "$MAIN_ROOT" fetch origin <base>`; on failure warn and continue with the local base.
4. Resolve the base ref: `origin/<base>` → local `<base>` → stop if neither.
5. Switch the main checkout to the base (`switch`, or `switch -c <base> origin/<base>`) and `merge --ff-only origin/<base>`. A diverged local base aborts the batch.
6. **Dirty-worktree scan.** For each target worktree, `git -C <path> status --porcelain`. Present all dirty worktrees in one batched message with modified/added/deleted/untracked counts and ask "Auto-commit each before merging? [Y/n]", default yes. On yes: read the issue title via MCP if available (else use the branch slug), inspect `diff HEAD`, then `add -A` and commit with a conventional message referencing the issue id. A failed commit is never retried with `--no-verify` — mark the issue and move on. On no, leave them; Phase 4 skips them.

## Phase 4: Per-Issue Merge and Cleanup

Independent per issue:

1. Neither worktree nor branch → "already cleaned up".
2. Worktree still dirty → skip with a reason; never lose uncommitted work.
3. `git -C "$MAIN_ROOT" merge-base --is-ancestor <branch> <base-ref>` exits 0 → already merged; go to step 5.
4. `git -C "$MAIN_ROOT" merge --no-ff -m "Merge <branch> into <base>" <branch>`. On conflict: `merge --abort`, report the files, retain the worktree, continue. On other failure: record and continue.
5. Cleanup, worktree first — `branch -d/-D` refuses while the branch is checked out in a worktree:
   - `git -C "$MAIN_ROOT" worktree remove <path>`; if it fails because the directory is gone but still registered, `worktree prune` and retry once.
   - If it fails with `contains modified or untracked files`, do **not** use `--force`: report and retain. Ignored build output does not trigger this, so the message means real work is present.
   - `no-cleanup` → stop here and record `branch retained (no-cleanup)`.
   - Else `git -C "$MAIN_ROOT" branch -D <branch>`. `-D` is required for GitHub squash-merges, where the tip is not an ancestor of the base; it is safe because this step is reached only after a confirmed merge.

## Phase 5: Report

Group by outcome (auto-committed+merged, merged+cleaned, already-merged+cleaned, branch-retained, skipped, conflict, error), name the base and the main checkout's new HEAD, and close with: Linear status is not updated by this skill — run `$update-ticket-linear <issue> done` when ready.

## Safety Rules

- No Linear writes, and no Linear MCP requirement.
- Never push, never delete a remote branch, never open a PR, never resolve a conflict.
- Never `--force` a `worktree remove`; never `--no-verify` a commit.
- Do not touch `docs/tickets/` — that is `$merge-worktree`'s domain.
