---
name: implement-ticket-linear
description: "Implement a Linear issue end to end with code review. Source of truth is Linear (not docs/tickets/). Optional `worktree` keyword runs inside an isolated git worktree. Triggers on: /implement-ticket-linear ENG-42, /implement-ticket-linear https://linear.app/.../issue/ENG-42/..., implement Linear issue ENG-42, implement Linear ticket worktree"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a senior full-stack developer implementing a **Linear** issue. Follow this workflow precisely. Do not skip steps.

This skill is the Linear counterpart of `/implement-ticket`. It does **not** read or write `docs/tickets/*.md`. The issue body in Linear is the ticket.

A Linear issue id or URL is required (e.g. `ENG-42` or a `linear.app` issue URL). If no argument is provided, inform the user and stop.

## Prerequisites

1. **Linear MCP** must be available and authenticated in the host agent (official server: `https://mcp.linear.app/mcp`, documented at https://linear.app/docs/mcp).
2. If no Linear MCP tools are available, stop and tell the user to configure Linear MCP. Do **not** invent API-key, CLI, or browser workarounds in this skill.
3. Prefer Linear MCP tools that **read** a single issue (get / list / search by identifier). **Do not** call update, create, delete, or assign tools. The **only** permitted write is the single opt-in as-built comment in Phase 8, posted only after the user explicitly confirms.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Implement in the current checkout (default). |
| `<issue> worktree` | Implement inside an isolated worktree off `origin/main`. |
| `<issue> worktree <base>` | Implement inside a worktree off `origin/<base>` (e.g. `dev`). |

`<issue>` is either:

- A Linear identifier `TEAM-NUMBER` (e.g. `ENG-42`, `CKTK-7`) — case-insensitive; normalize the team key to uppercase.
- A Linear issue URL containing that identifier (e.g. `https://linear.app/acme/issue/ENG-42/add-export`).

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode (not `wt`, not `--worktree`). A second token that is *not* `worktree` is a typo — stop and tell the user "unrecognized argument; pass `worktree` to use a worktree."

**Not accepted:** free-text titles alone, status flags, commit flags, multi-issue lists, empty args meaning “next assigned.”

## Phase 1: Parse Arguments & Resolve Handles

1. **Parse `$ARGUMENTS`.** Split on whitespace. Capture:
   - `issue_ref` (first token — required)
   - `use_worktree` (true iff the second token is `worktree`)
   - `base` (third token if present, otherwise `main` when `use_worktree` is true)
2. If there is no first token, stop: "A Linear issue id or URL is required (e.g. `ENG-42`)."
3. If a fourth token exists, stop with an unrecognized-arguments error.
4. If a second token exists and is not `worktree`, stop as described above.
5. **Normalize the issue id:**
   - If `issue_ref` matches `^[A-Za-z]+-\d+$`, uppercase the team key (`eng-42` → `ENG-42`). Set `issue_id` to that value.
   - Else if it looks like a URL (`http://` or `https://`), extract the first path segment matching `TEAM-NUM` (regex `[A-Za-z]+-\d+`). Uppercase the team key. If none found, stop: "Could not extract a Linear issue id from the URL."
   - Else stop: "Unrecognized issue reference. Pass a Linear id like `ENG-42` or a Linear issue URL."
6. **Resolve the main repo root** so the skill behaves the same from a worktree or main checkout:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```

## Phase 2: Load the Linear Issue

1. Confirm Linear MCP tools are present. If not, stop with the setup hint above.
2. Fetch the issue by `issue_id` via Linear MCP (search/list/get as available). Prefer an exact identifier match.
3. If the issue is not found, report and stop.
4. If multiple issues match (should be rare for a full id), report the ambiguity and stop — do not guess.
5. Capture for the rest of the workflow:
   - Title
   - Description / body (full text)
   - Status / state name
   - Priority, labels, project, cycle (if present)
   - Assignee (if present)
   - Blocking / blocked-by / related relations (if the MCP returns them)
   - Acceptance criteria if they appear as checklists in the body, or as structured fields
6. Derive **slug** from the title:
   - Lowercase
   - Replace any run of non-alphanumeric characters with a single `-`
   - Strip leading/trailing `-`
   - Truncate to ~40 characters, preferring a cut at a hyphen
   - If the title yields an empty slug, use `issue` as the slug
7. Compute worktree handles (always, even if not using worktree mode):
   - Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>` (e.g. `.worktrees/ENG-42-add-export`)
   - Branch name: `linear-<issue_id>-<slug>` (e.g. `linear-ENG-42-add-export`)
8. If the Linear state is clearly terminal (e.g. Done, Completed, Canceled, Cancelled, Duplicate), inform the user of the status and **stop** unless they explicitly asked to re-implement — in that case ask once before continuing. Still do not write to Linear.

## Phase 3: Set Up the Working Directory

1. **If `use_worktree` is true:**
   - If the worktree path is already registered (`git worktree list --porcelain`), reuse it. Uncommitted changes are fine (resume) — note "reused existing worktree (with uncommitted changes)" in the final summary if dirty.
   - Otherwise create it inline (do **not** call `/create-worktree` — that skill requires `docs/tickets/`):
     a. `git fetch origin <base>` when possible; on failure continue with the local base and warn.
     b. Resolve base ref: prefer `origin/<base>`, else local `<base>`. If neither exists, stop.
     c. Ensure `$MAIN_ROOT/.gitignore` ignores `.worktrees/` (create or append the line if missing).
     d. If branch `linear-<issue_id>-<slug>` already exists locally, `git worktree add <path> <branch>`.
     e. Else `git worktree add <path> -b <branch> <base-ref>`.
   - Set `WORK_DIR = <worktree-path>`.
2. **If `use_worktree` is false:** set `WORK_DIR = $MAIN_ROOT` (or the user's current `git rev-parse --show-toplevel` if they already invoked the skill from a worktree on purpose).
3. `cd "$WORK_DIR"` once via Bash so later shell commands (including those inside `/review-ticket`) run against `WORK_DIR`. For Read/Edit/Write tools that need absolute paths, prefix with `$WORK_DIR`.
4. Tell the user in one sentence where work is happening, e.g.:
   - "Implementing ENG-42 in `.worktrees/ENG-42-add-export` (branch `linear-ENG-42-add-export`, base `dev`)."
   - "Implementing ENG-42 in the current checkout."

## Phase 4: Understand Project Context (soft)

Linear is the ticket source of truth. Project docs are optional context:

1. If `$WORK_DIR/docs/PRD.md` exists, read it.
2. Design source if present:
   - Prefer `$WORK_DIR/docs/DESIGN.md`
   - Else `$WORK_DIR/docs/design/DESIGN.md`
   - Else a folder named `design-system` under `$WORK_DIR` or `$WORK_DIR/docs/`
3. If PRD/design are missing, continue — do not stop. Use the Linear issue body as the primary requirements.
4. Also skim `CLAUDE.md` / `AGENTS.md` / package manifests at `$WORK_DIR` when present for stack conventions.

## Phase 5: Plan Before Coding

Before writing code, briefly state:

- Issue id + title
- What you are implementing (from Linear description)
- Acceptance criteria you will verify
- Files you expect to create or modify
- Edge cases / risks
- Any Linear relations that look like blockers (if blocked by an open issue, stop and report rather than implementing out of order)

## Phase 6: Implement

1. Implement fully against the Linear issue and any project design context. All edits land under `$WORK_DIR`.
2. Follow existing project conventions (naming, structure, patterns).
3. Include error handling, validation, and edge-case coverage appropriate to the change.
4. If the issue mentions tests, write them. If the project has a test suite, add tests for the change even when the issue does not list them.
5. Integrate new files with existing exports/imports and wiring.
6. Prepare manual testing instructions as you go.

## Phase 7: Code Review

### 7a: Build Check

Run lint, type-check, test, and build commands appropriate to the repo (from `package.json`, `pyproject.toml`, etc.). Fix until clean.

### 7b: Automated Code Review

Mandatory. Invoke `/review-ticket` via the `Skill` tool:

```
skill: "review-ticket"
args: "<issue_id>"
```

`/review-ticket <issue_id>` runs in its Linear mode: it fetches the issue via Linear MCP and reviews the uncommitted diff against the issue's title, description, and acceptance criteria. The diff is read via git in the pinned cwd, so it sees the worktree or main checkout correctly.

### 7c: Fix and Re-review

If review finds issues:

1. Fix them
2. Re-run build/tests (7a)
3. Re-invoke `/review-ticket <issue_id>`
4. Repeat until build is clean and review has no P0/P1 findings

## Phase 8: Summary and Manual Testing

Present:

### Implementation Summary

1. Issue id, title, and Linear URL if known
2. What was built — key files, decisions
3. Deviations from the issue or design sources, and why
4. Remaining concerns or follow-ups
5. Reminder that **Linear status was not changed** and **nothing was committed** (the only possible Linear write is the opt-in as-built comment below)
6. **Next step for Linear status:** when the user is ready to mark the issue done (or move it to another state), run `/update-ticket-linear <issue_id>` (optionally with an explicit status such as `done`). That skill evaluates acceptance criteria and writes back to Linear; this skill never changes Linear status (its only Linear write is the opt-in as-built comment).

### As-Built Comment (opt-in Linear write)

After presenting the summary, ask exactly once, as its own question: "Post this as-built summary as a comment on <issue_id>? (y/N)". Default is no.

- Only an explicit yes posts the comment; any other answer (no, silence, ambiguity) skips it without re-asking.
- On yes, post one comment via the Linear MCP comment-creation tool containing: deviations from the issue spec and why, key decisions made during implementation, and follow-ups/tech debt (write "None" where a bucket is empty).
- This is the only Linear write this skill may ever perform — never change status, assignee, labels, or any other field.

### Worktree Note (only when `use_worktree` was true)

- **Worktree:** `.worktrees/<issue_id>-<slug>/` (branch `linear-<issue_id>-<slug>`, base `<base>`)
- **Inspect:** `cd .worktrees/<issue_id>-<slug>`
- **Land:** `$merge-worktree` is for markdown `TICKET-NNN` worktrees and will **not** work for Linear branches. Land manually, for example:

```bash
# From MAIN_ROOT, after reviewing the branch:
git checkout <base>
git merge linear-<issue_id>-<slug>
# or: push the branch and open a PR
git -C .worktrees/<issue_id>-<slug> push -u origin HEAD
```

Then remove the worktree when done: `git worktree remove .worktrees/<issue_id>-<slug>` (and delete the local branch if desired).

### Manual Testing Instructions

Step-by-step verification: prerequisites, commands, URLs, inputs, expected results, edge cases. If purely internal, say manual testing is N/A and what automated tests cover.

## Safety Rules

- **Never** change Linear status, assignee, labels, or any other field. The single permitted write is the opt-in as-built comment in Phase 8, and only after explicit user confirmation.
- **Never** commit, and do not invoke `/commit-ticket`, `/commit-push-pr`, `/update-ticket`, or `/update-ticket-linear` (status updates belong in a separate `/update-ticket-linear` invocation after implementation).
- Do not read or write `docs/tickets/` as the ticket source (optional project context elsewhere is fine).
- If unrelated dirty changes in `WORK_DIR` conflict with the issue, stop and ask instead of overwriting.
- In worktree mode, do not switch the user's main checkout branch and do not delete the worktree at the end.
- If Linear MCP is missing or the issue cannot be resolved uniquely, stop — do not invent requirements.
