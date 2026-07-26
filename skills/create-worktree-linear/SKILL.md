---
name: create-worktree-linear
description: "Create one or more git worktrees for Linear issues, each as an isolated checkout under .worktrees/ENG-42-slug/ on its own linear-ENG-42-slug branch. Source of truth is Linear, not docs/tickets/. Optionally pass a base branch as the last argument (defaults to main, fetched fresh from origin). Requires Linear MCP; makes no Linear writes. Triggers on: /create-worktree-linear, /create-worktree-linear ENG-42, create worktree for Linear issue, worktree this Linear issue, isolated branch for Linear ticket, parallel Linear issue work"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

Set up one or more git worktrees so **Linear** issues can be worked on in parallel without switching branches in the main checkout. Each worktree gets a fresh branch off the chosen base and lives at `.worktrees/<issue_id>-<slug>/` inside the repo.

This skill is the Linear counterpart of `/create-worktree`. It does **not** read `docs/tickets/*.md` — the Linear issue is the ticket.

It **never writes to Linear**. It reads each issue to derive a directory name and nothing else. In particular it does not move a Todo issue into an in-progress state: preparing a workspace is not starting work, and a multi-issue batch would fire one status write per issue. `/implement-ticket-linear` makes that transition when implementation actually starts.

## Prerequisites

1. **Linear MCP** must be available and authenticated in the host agent (official server: `https://mcp.linear.app/mcp`, documented at https://linear.app/docs/mcp).
2. If no Linear MCP tools are available, stop and tell the user to configure Linear MCP. Do **not** invent API-key, CLI, or browser workarounds.
3. Use Linear MCP **read** tools only (get / list / search by identifier).

## Phase 1: Parse Arguments

Split `$ARGUMENTS` on whitespace. Classify each token:

- **Issue reference** — a Linear identifier matching `^[A-Za-z]+-\d+$` (case-insensitive; normalize the team key to uppercase, so `eng-42` → `ENG-42`), or a `linear.app` URL containing one (extract the first path segment matching `[A-Za-z]+-\d+`).
- **Base branch** — anything that does not match those forms. At most one base-branch token is allowed. If two or more are passed, report the conflict and stop.

If no issue references are provided, ask the user for at least one and stop. If no base-branch token is provided, default the base to `main`.

| Invocation | Issues | Base |
| --- | --- | --- |
| `/create-worktree-linear ENG-42` | ENG-42 | main |
| `/create-worktree-linear ENG-42 ENG-43` | ENG-42, ENG-43 | main |
| `/create-worktree-linear ENG-42 dev` | ENG-42 | dev |
| `/create-worktree-linear eng-42 ENG-43 release-2026` | ENG-42, ENG-43 | release-2026 |

### The trailing-token tiebreak

Unlike `TICKET-NNN`, the Linear identifier pattern collides with ordinary branch names: `release-2026`, `v2-1`, and `sprint-14` all parse as identifiers. Pattern classification runs first, and this tiebreak applies **only to the trailing token**, and **only after Phase 2 has already failed** to resolve it as an issue:

- If the trailing token does not resolve as a Linear issue but does resolve as a branch — check `git rev-parse --verify --quiet origin/<token>`, then `git rev-parse --verify --quiet <token>` — treat it as the base branch and say so in one line:

  ```
  'release-2026' is not a Linear issue but is a branch — using it as the base.
  ```

- If it resolves as neither, report `<token> not found in Linear` and stop the batch.

If a repository genuinely has a branch named `ENG-42` while issue ENG-42 also exists, the issue wins, and that branch cannot be named as a base here. Document the collision rather than adding disambiguation machinery.

## Phase 2: Resolve the Main Repo Root and Issues

1. Confirm we're inside a git repo. Resolve the **main** repo root so the skill behaves the same whether invoked from the main checkout or from another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
   All paths below are relative to `$MAIN_ROOT`.

2. Fetch each issue by identifier via Linear MCP, preferring an exact identifier match.
   - **Not found** → if it is the trailing token, apply the tiebreak above; otherwise report `<issue_id> not found in Linear` and **stop the whole batch**. Don't partially create worktrees: a typo in one id means the user wants to fix the input rather than skip ahead.
   - **Multiple matches** for a full identifier → report the ambiguity and stop.

3. Capture the **title** for each issue. Nothing else is needed.

4. Derive **slug** from the title, using exactly the rules `/implement-ticket-linear` uses — any drift breaks worktree reuse between the two skills:
   - Lowercase
   - Replace any run of non-alphanumeric characters with a single `-`
   - Strip leading/trailing `-`
   - Truncate to ~40 characters, preferring a cut at a hyphen
   - If the title yields an empty slug, use `issue` as the slug

5. Record per issue:
   - Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`
   - Branch name: `linear-<issue_id>-<slug>`

## Phase 3: Match Existing Work by Issue Id

A ticket filename is stable, so `/create-worktree` treats its slug as authoritative. A Linear title is editable, so today's slug may differ from the one in use when the worktree was created, and matching the exact path would create a **second** worktree for an issue that already has one. Match by id prefix instead.

For each issue, in order:

1. **Existing worktree?** Scan `git worktree list --porcelain` for a registered path matching `$MAIN_ROOT/.worktrees/<issue_id>-*`. If one exists, mark the issue `skip — worktree already exists at <path>` and move on to the next issue.

2. **Existing branch?** Otherwise list candidates:
   ```
   git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'
   ```
   The `--format` is required: plain `git branch --list` prefixes `+ ` for a branch checked out in another worktree and `* ` for the current branch, and those markers are not part of the name.
   - **Exactly one match** → reuse that branch. Strip the leading `linear-` from it; the remainder is the worktree directory name, so path and branch stay coherent (branch `linear-ENG-42-old-title` → worktree `.worktrees/ENG-42-old-title`). If that differs from the Phase 2 slug, note it in the report — the issue title changed since the branch was made.
   - **Two or more matches** → report the ambiguity, skip this issue, continue with the rest of the batch. This is a per-issue error, not a batch abort.
   - **None** → keep the Phase 2 handles and create fresh.

## Phase 4: Prepare the Repo

1. Fetch the base branch from `origin`:
   ```
   git fetch origin <base>
   ```
   If `origin` does not exist or the fetch fails (no remote, no network, no such ref), continue with the local base branch and tell the user the worktree may be based on a stale ref.

2. Resolve the base reference in this order:
   - `origin/<base>` (preferred — freshly fetched).
   - Local `<base>` (fallback).
   - If neither exists, report `base branch '<base>' not found locally or on origin` and stop the batch before creating anything.

3. Ensure `.worktrees/` is ignored by git so the parent checkout doesn't see the new worktrees as untracked files. Read `$MAIN_ROOT/.gitignore`:
   - If the file is missing, create it with a single line `.worktrees/`.
   - If the file exists but contains no line that matches `.worktrees/?` (allowing a trailing slash), append `.worktrees/` on a new line.
   - If a matching line is already present, leave the file alone.
   - Note any change in the final report so the modification isn't silent. **Do not commit it** — that is the user's call. `/merge-worktree-linear` recognizes this exact state and offers to commit it when it would otherwise block a merge.

## Phase 5: Create the Worktrees

Process issues in the order they were given. For each issue not already skipped by Phase 3:

1. If a branch was matched in Phase 3 step 2, attach to it:
   ```
   git worktree add <worktree-path> <branch>
   ```
   Note in the report that the branch was reused rather than created — the user may have started this work earlier and we don't want to silently rebase.

2. Otherwise create the branch from the resolved base ref:
   ```
   git worktree add <worktree-path> -b <branch> <base-ref>
   ```

3. If `git worktree add` fails for a single issue (e.g. a stale registration in `.git/worktrees/`), report the error and continue with the rest. One bad issue shouldn't abort a batch where the others would succeed.

## Phase 6: Report

Print a summary the user can act on directly:

```
Created 2 worktree(s) from origin/main:

  ENG-42  .worktrees/ENG-42-add-csv-export   branch: linear-ENG-42-add-csv-export
  ENG-43  .worktrees/ENG-43-fix-search       branch: linear-ENG-43-fix-search

Open one with:
  cd .worktrees/ENG-42-add-csv-export

Implement in it with:
  /implement-ticket-linear ENG-42 worktree

Land it later with:
  /merge-worktree-linear ENG-42
```

If any issues were skipped (worktree already exists, ambiguous branch match) or failed (git error), list them in their own section with the reason. If `.gitignore` was created or modified, mention it. If a reused branch's slug differs from the current issue title's slug, say so.

Do not `cd` into the new worktree, do not install dependencies, and do not commit anything. The user runs each worktree's setup themselves.

## Safety Rules

- **No Linear writes of any kind.** Never change state, assignee, labels, priority, or any other field, and never post a comment. Reading the issue is the only Linear interaction.
- Stop the batch up front if any issue id fails to resolve — do not create some worktrees while leaving others broken.
- Do not delete or move existing worktrees, and do not force-create branches; reuse a matching branch instead.
- Do not commit the `.gitignore` change.
- Do not switch the branch of the user's main checkout.
- If Linear MCP is missing or an issue cannot be resolved uniquely, stop — do not guess a directory name from the raw identifier.
