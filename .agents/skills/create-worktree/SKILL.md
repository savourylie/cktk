---
name: "create-worktree"
description: "Use when the user explicitly asks to create one or more git worktrees for tickets in docs/tickets/, each as an isolated checkout on its own branch. Prefer explicit invocation with $create-worktree."
---

# Create Worktrees for Tickets

Create one or more git worktrees so the user can work on multiple tickets in parallel without juggling branches in the main checkout. Each worktree gets a fresh branch off the chosen base and lives at `.worktrees/NNN-<slug>/` inside the repo. Treat this as an explicit workflow skill because it mutates the working tree and may modify `.gitignore`.

Parse any text that follows the skill invocation as arguments. Accept ticket identifiers like `TICKET-002`, `002`, `#002`, or `2`. Accept one optional base-branch token (anything that is not a ticket identifier). Default base is `main`.

## Phase 1: Parse Arguments

1. Split the argument string on whitespace.
2. Classify each token:
   - **Ticket number** if it matches `^\d+$`, `^#\d+$`, or `^TICKET-\d+$` (case-insensitive). Normalize to a 3-digit zero-padded number.
   - **Base branch** otherwise. At most one such token is allowed; if two or more are present, report the conflict and stop.
3. Require at least one ticket number. If none provided, ask the user for one and stop.
4. If no base-branch token is provided, default to `main`.

Examples:
- `$create-worktree 7` → tickets `[007]`, base `main`
- `$create-worktree 7 8 9` → tickets `[007, 008, 009]`, base `main`
- `$create-worktree 7 dev` → tickets `[007]`, base `dev`
- `$create-worktree TICKET-007 release-2026` → tickets `[007]`, base `release-2026`

## Phase 2: Resolve Repo Root and Ticket Files

1. Confirm we're in a git repo and resolve the **main** repo root so the skill works the same when invoked from any worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. For each ticket number `NNN`, glob `$MAIN_ROOT/docs/tickets/NNN-*.md`.
   - If no file matches, report `TICKET-NNN not found in docs/tickets/` and stop the whole batch — partial worktree creation hides the typo.
   - If multiple files match, stop and report the ambiguity.
3. Extract the slug from each filename: strip the leading `NNN-` and trailing `.md`. The filename slug is authoritative — do not re-derive from the ticket title.
4. Record for each ticket:
   - Worktree path: `$MAIN_ROOT/.worktrees/NNN-<slug>`
   - Branch name: `ticket-NNN-<slug>`

## Phase 3: Prepare the Repo

1. Fetch the base branch fresh:
   ```
   git fetch origin <base>
   ```
   If `origin` is missing or the fetch fails, continue with the local base branch and warn the user that the result may be stale.
2. Resolve the base ref. Use local `<base>` when it is strictly ahead: `origin/<base>` is an ancestor of local `<base>` and the two differ, the state `$merge-worktree` leaves because it never pushes. Otherwise use `origin/<base>`, naming any local commits it lacks when the two have diverged. Use local `<base>` when there is no `origin/<base>`; stop if neither exists.
3. Ensure `.worktrees/` is ignored:
   - If `$MAIN_ROOT/.gitignore` is missing, create it with a single line `.worktrees/`.
   - If it exists and contains no line matching `.worktrees/?`, append `.worktrees/` on a new line.
   - If already present, leave it alone.
   - Mention any change in the final report.

## Phase 4: Create the Worktrees

For each ticket, in order:

1. Skip with a warning if `<worktree-path>` already exists on disk or appears in `git worktree list --porcelain`.
2. If the branch already exists locally (`git rev-parse --verify --quiet <branch>` succeeds), reuse it: `git worktree add <worktree-path> <branch>`. Note the reuse in the report.
3. Otherwise create the branch off the resolved base ref: `git worktree add <worktree-path> -b <branch> <base-ref>`.
4. If a single ticket fails, report the error and continue with the rest of the batch.

## Phase 5: Report

Print a summary listing each worktree path and branch name, the base ref used, anything skipped or failed, and any `.gitignore` changes. Do not `cd` into the worktree, do not install dependencies, and do not commit anything.

## Safety Rules

- Stop the batch up front if any ticket file is missing — do not create some worktrees while leaving others broken.
- Do not delete or move existing worktrees.
- Do not force-create branches; if a branch already exists, reuse it.
- Do not commit `.gitignore` changes — leave them staged-or-unstaged for the user to commit.
