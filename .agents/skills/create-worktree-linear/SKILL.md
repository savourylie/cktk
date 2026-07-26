---
name: "create-worktree-linear"
description: "Use when the user explicitly asks to create one or more git worktrees for Linear issues, each as an isolated checkout on its own branch. Requires Linear MCP and makes no Linear writes. Prefer explicit invocation with $create-worktree-linear."
---

# Create Worktrees for Linear Issues

Create one or more git worktrees so the user can work on multiple **Linear** issues in parallel without juggling branches in the main checkout. Each worktree gets a fresh branch off the chosen base and lives at `.worktrees/<issue_id>-<slug>/` inside the repo. Treat this as an explicit workflow skill because it mutates the working tree and may modify `.gitignore`.

This is the Linear counterpart of `$create-worktree`; it does not read `docs/tickets/`. It **never writes to Linear** — it reads each issue for its title and nothing else, and it does not move a Todo issue into an in-progress state. `$implement-ticket-linear` makes that transition when work actually starts.

## Prerequisites

Linear MCP must be available and authenticated (`https://mcp.linear.app/mcp`). If it is missing, stop and say so; do not invent API-key, CLI, or browser fallbacks. Read tools only.

## Phase 1: Parse Arguments

1. Split the argument string on whitespace.
2. Classify each token:
   - **Issue reference** if it matches `^[A-Za-z]+-\d+$` (case-insensitive; uppercase the team key) or is a `linear.app` URL containing such an identifier.
   - **Base branch** otherwise. At most one; two or more → report the conflict and stop.
3. Require at least one issue reference. If none, ask and stop.
4. Default the base to `main`.

Examples:
- `$create-worktree-linear ENG-42` → issues `[ENG-42]`, base `main`
- `$create-worktree-linear ENG-42 ENG-43 dev` → issues `[ENG-42, ENG-43]`, base `dev`

**Trailing-token tiebreak.** The Linear id pattern collides with branch names like `release-2026`. If the trailing token fails to resolve as a Linear issue but resolves as a branch (`git rev-parse --verify --quiet origin/<token>`, then `<token>`), treat it as the base and say so in one line. If it resolves as neither, stop. If a branch and an issue share a name, the issue wins.

## Phase 2: Resolve Repo Root and Issues

1. Confirm we're in a git repo and resolve the **main** repo root so the skill works the same from any worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. Fetch each issue by exact identifier via Linear MCP. Not found (and not the trailing token) or ambiguous → stop the whole batch; partial creation hides the typo.
3. Capture each title and derive the **slug** exactly as `$implement-ticket-linear` does: lowercase, runs of non-alphanumerics to a single `-`, trim leading/trailing `-`, truncate to ~40 characters preferring a hyphen cut, fall back to `issue`.
4. Record per issue:
   - Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`
   - Branch name: `linear-<issue_id>-<slug>`

## Phase 3: Match Existing Work by Issue Id

Linear titles are editable, so an exact-path check would create a second worktree for an issue that already has one. Match by id prefix:

1. A registered path under `$MAIN_ROOT/.worktrees/<issue_id>-*` in `git worktree list --porcelain` → skip with a warning.
2. Else `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`. Use `--format`; plain output prefixes `+ ` and `* ` markers that are not part of the name.
   - One match → reuse it; strip the leading `linear-` for the worktree directory name so path and branch agree. Note a slug difference in the report.
   - Two or more → report the ambiguity, skip this issue, continue the batch.
   - None → create fresh.

## Phase 4: Prepare the Repo

1. `git fetch origin <base>`. If `origin` is missing or the fetch fails, continue with the local base and warn that the result may be stale.
2. Resolve the base ref: `origin/<base>` → local `<base>` → if neither exists, report and stop.
3. Ensure `.worktrees/` is ignored: create `$MAIN_ROOT/.gitignore` with that line if missing, append it if absent, leave it alone if present. Mention any change in the report and do not commit it — `$merge-worktree-linear` detects this state and offers to commit it when it blocks a merge.

## Phase 5: Create the Worktrees

For each issue, in order:

1. Branch matched in Phase 3 → `git worktree add <worktree-path> <branch>`; note the reuse.
2. Otherwise → `git worktree add <worktree-path> -b <branch> <base-ref>`.
3. If one issue fails, report the error and continue with the rest of the batch.

## Phase 6: Report

List each worktree path and branch, the base ref used, anything skipped or failed, and any `.gitignore` change. Point the user at `$implement-ticket-linear <issue> worktree` to implement and `$merge-worktree-linear <issue>` to land. Do not `cd` into the worktree, do not install dependencies, and do not commit anything.

## Safety Rules

- No Linear writes of any kind — no state change, no comment, no field edit.
- Stop the batch up front if any issue id fails to resolve.
- Do not delete or move existing worktrees; reuse a matching branch rather than force-creating one.
- Do not commit the `.gitignore` change, and do not switch the main checkout's branch.
