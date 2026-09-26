---
name: create-worktree
description: "Create one or more git worktrees for tickets from docs/tickets/, each as an isolated checkout under .worktrees/NNN-slug/ on its own branch. Optionally pass a base branch as the last argument (defaults to main; uses origin's copy unless the local branch is ahead of it). Use when the user wants an isolated checkout for a local ticket, or to work on several tickets in parallel."
user-invocable: true
---

**Argument:** `$ARGUMENTS`

Set up one or more git worktrees so tickets can be worked on in parallel without switching branches in the main checkout. Each worktree gets a fresh branch off the chosen base and lives at `.worktrees/NNN-<slug>/` inside the repo.

## Phase 1: Parse Arguments

Split `$ARGUMENTS` on whitespace. Classify each token:

- **Ticket number** — matches `^\d+$`, `^#\d+$`, or `^TICKET-\d+$` (case-insensitive). Normalize to a 3-digit zero-padded number (e.g., `7` → `007`, `TICKET-12` → `012`).
- **Base branch** — anything that does not match a ticket pattern. At most one base-branch token is allowed. If two or more non-ticket tokens are passed, report the conflict and stop.

If no ticket numbers are provided, ask the user for at least one and stop. If no base-branch token is provided, default the base to `main`.

Examples:

| Invocation | Tickets | Base |
| --- | --- | --- |
| `/create-worktree 7` | 007 | main |
| `/create-worktree 7 8 9` | 007, 008, 009 | main |
| `/create-worktree 7 dev` | 007 | dev |
| `/create-worktree 7 8 dev` | 007, 008 | dev |
| `/create-worktree TICKET-007 release-2026` | 007 | release-2026 |

## Phase 2: Resolve the Main Repo Root and Tickets

1. Confirm we're inside a git repo. Resolve the **main** repo root so the skill behaves the same whether invoked from the main checkout or from another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
   All paths below are relative to `$MAIN_ROOT`.

2. For each ticket number `NNN`, glob `$MAIN_ROOT/docs/tickets/NNN-*.md`.
   - If no file matches, report `TICKET-NNN not found in docs/tickets/` and stop the whole batch — don't partially create worktrees, since a typo in one number means the user wants to fix the input rather than skip ahead.
   - If multiple files match (shouldn't happen with proper numbering), report the ambiguity and stop.

3. Extract the slug from each filename: strip the leading `NNN-` and the trailing `.md`. Example: `007-add-export-feature.md` → slug `add-export-feature`. The filename's slug is authoritative — don't try to re-derive one from the ticket title.

4. Record per-ticket:
   - Worktree path: `$MAIN_ROOT/.worktrees/NNN-<slug>`
   - Branch name: `ticket-NNN-<slug>`

## Phase 3: Prepare the Repo

1. Fetch the base branch from `origin`:
   ```
   git fetch origin <base>
   ```
   If `origin` does not exist or the fetch fails (no remote, no network, no such ref), continue with the local base branch and tell the user the worktree may be based on a stale ref.

2. Resolve the base reference:
   - Local `<base>` when it is strictly ahead: `origin/<base>` is an ancestor of local `<base>` (`git merge-base --is-ancestor origin/<base> <base>` exits 0) and the two differ. `/merge-worktree` leaves exactly this state, because it merges locally and never pushes, and a worktree for a dependent ticket needs that work.
   - `origin/<base>` when local `<base>` is missing, equal, or behind.
   - `origin/<base>` when the two have diverged; name the local commits the worktree will not contain.
   - Local `<base>` when `origin/<base>` does not exist.
   - If neither exists, report `base branch '<base>' not found locally or on origin` and stop the batch before creating anything.

3. Ensure `.worktrees/` is ignored by git so the parent checkout doesn't see the new worktrees as untracked files. Read `$MAIN_ROOT/.gitignore`:
   - If the file is missing, create it with a single line `.worktrees/`.
   - If the file exists but contains no line that matches `.worktrees/?` (allowing a trailing slash), append `.worktrees/` on a new line.
   - If a matching line is already present, leave the file alone.
   - Note any change in the final report so the modification isn't silent.

## Phase 4: Create the Worktrees

Process tickets in the order they were given. For each ticket:

1. If the worktree path already exists on disk, or already appears in `git worktree list --porcelain`, skip with a warning (`worktree already exists at <path>`) and continue with the next ticket.

2. If the branch already exists locally (`git rev-parse --verify --quiet <branch>` succeeds):
   - Reuse the existing branch: `git worktree add <worktree-path> <branch>`.
   - Note in the report that the branch was reused rather than created — the user may have started this work earlier and we don't want to silently rebase.

3. Otherwise create the branch from the resolved base ref:
   - `git worktree add <worktree-path> -b <branch> <base-ref>`

4. If the `git worktree add` command fails for a single ticket (e.g., a stale registration in `.git/worktrees/`), report the error and continue with the rest. One bad ticket shouldn't abort a batch where the others would succeed.

## Phase 5: Report

Print a summary the user can act on directly:

```
Created 2 worktree(s) from origin/main:

  TICKET-007  .worktrees/007-add-export-feature   branch: ticket-007-add-export-feature
  TICKET-008  .worktrees/008-fix-search           branch: ticket-008-fix-search

Open one with:
  cd .worktrees/007-add-export-feature
```

If any worktrees were skipped (already exist) or failed (git error), list them in their own section with the reason. If `.gitignore` was created or modified, mention it.

Do not `cd` into the new worktree, do not install dependencies, and do not commit anything. The user runs each worktree's setup themselves.
