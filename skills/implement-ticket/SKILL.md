---
name: implement-ticket
description: "Implement a specific ticket from the ticket tracker with code review. Optional `worktree` keyword runs the implementation inside an isolated git worktree (auto-created via /create-worktree if it doesn't exist), so multiple tickets can be worked in parallel without juggling branches. Triggers on: /implement-ticket TICKET-NNN, /implement-ticket NNN worktree, /implement-ticket NNN worktree dev, implement TICKET-NNN, implement ticket NNN, implement ticket in a worktree, work on ticket in parallel"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a senior full-stack developer implementing a ticket. Follow this workflow precisely. Do not skip steps.

A ticket ID is required (e.g., `TICKET-001`, `001`, or `1`). If no argument is provided, inform the user that a ticket ID is required and stop.

## Argument grammar

The skill accepts the existing single-arg form plus an optional `worktree` flag:

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Implement in the current checkout (default). |
| `<ticket> worktree` | Implement inside an isolated worktree off `origin/main`. |
| `<ticket> worktree <base>` | Implement inside a worktree off `origin/<base>` (e.g. `dev`). |

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode (not `wt`, not `--worktree`). A second token that is *not* `worktree` is a typo — stop and tell the user "unrecognized argument; pass `worktree` to use a worktree."

## Phase 1: Set Up the Working Directory

This phase is new. It runs whether or not worktree mode is requested, because both modes need to know the same things (main repo root, ticket file, slug).

1. **Parse `$ARGUMENTS`.** Capture:
   - `ticket_id`, normalized to a 3-digit zero-padded `NNN` (so `7`, `007`, `#7`, `TICKET-007` all become `007`).
   - `use_worktree` (bool — true iff the second token is `worktree`).
   - `base` (string — third token if present, otherwise `main`). Only meaningful when `use_worktree` is true.
2. **Resolve the main repo root** so this skill behaves the same whether invoked from the main checkout or another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
3. **Resolve the ticket file and slug.** Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`.
   - No match → report `TICKET-NNN not found in docs/tickets/` and stop.
   - Multiple matches → report the ambiguity and stop.
   - Slug = the filename minus the `NNN-` prefix and the `.md` suffix.
4. **Compute the worktree handles** (used only in worktree mode, but compute up front so the names are consistent):
   - Worktree path: `$MAIN_ROOT/.worktrees/NNN-<slug>`
   - Branch name: `ticket-NNN-<slug>`
5. **If `use_worktree` is true:**
   - If the worktree path is already registered (check `git worktree list --porcelain`), reuse it. If `git -C <worktree-path> status --porcelain` is non-empty, that's fine — the user is resuming work — but note "reused existing worktree (with uncommitted changes)" in the final summary so they're not surprised.
   - Otherwise invoke `/create-worktree` via the `Skill` tool. This is the same Skill-tool pattern this skill already uses to invoke `/review-ticket` later, so it's not a new mechanism:
     ```
     skill: "create-worktree"
     args: "<NNN> <base>"   # drop <base> if base is main
     ```
   - Set `WORK_DIR = <worktree-path>`.
6. **If `use_worktree` is false:** set `WORK_DIR = $MAIN_ROOT` (or the user's current `git rev-parse --show-toplevel` if they invoked the skill from a worktree on purpose — they may already have set up the environment they want).
7. **Pin the working directory.** Run `cd "$WORK_DIR"` as a single Bash command. The Bash tool's working directory persists between commands within this session, so every later Bash call — including those inside `/review-ticket` when invoked via the `Skill` tool — will see `WORK_DIR` as cwd. For Read/Edit/Write tools (which require absolute paths), prefix project paths with `$WORK_DIR` (e.g. `$WORK_DIR/docs/PRD.md`).
8. **Tell the user, in one sentence, where the work is happening** before doing any reading, e.g.:
   - "Implementing TICKET-007 in `.worktrees/007-add-export` (branch `ticket-007-add-export`, base `dev`)."
   - "Implementing TICKET-007 in the current checkout."

## Phase 2: Understand the Project

1. Read `$WORK_DIR/docs/PRD.md` thoroughly. Internalize the product requirements, user stories, acceptance criteria, and scope.
2. Read the project's design source thoroughly:
   - Prefer `$WORK_DIR/docs/DESIGN.md`.
   - If that is missing, use `$WORK_DIR/docs/design/DESIGN.md` if present.
   - If no `DESIGN.md` file exists, search for a folder named `design-system` (commonly `$WORK_DIR/design-system/` or `$WORK_DIR/docs/design-system/`) and use that as the design source.
   - If using a `design-system/` folder, read its README/index file first if present, then read the files relevant to architecture, component patterns, tokens, data models, API contracts, and implementation constraints.
3. Briefly summarize (to yourself) the key requirements and architectural decisions before moving on. This is your mental model for all implementation work.

## Phase 3: Load the Ticket

1. Read `$WORK_DIR/docs/tickets/INDEX.md` to see the current status of all tickets and understand dependencies.
2. The target ticket is the one identified in Phase 1. If its status is already `done`, inform the user and stop.
3. Read the full ticket file at `$WORK_DIR/docs/tickets/NNN-<slug>.md`.
4. Before writing any code, briefly state:
   - What you're implementing
   - Which files you expect to create or modify
   - Any edge cases or risks you see

## Phase 4: Implement the Ticket

1. Implement the ticket fully, following the project's design source and the requirements in the ticket. All edits land under `$WORK_DIR`.
2. Write clean, well-structured code. Follow existing project conventions (naming, file structure, patterns).
3. Include appropriate error handling, input validation, and edge case coverage.
4. If the ticket specifies tests, write them. If it doesn't but the project has a test suite, add tests for your changes anyway.
5. Make sure any new files are properly exported/imported and integrated with the rest of the codebase.
6. Prepare manual testing instructions for the implementation. Think about what a developer or QA tester would need to do to verify the feature works correctly by hand — specific commands to run, URLs to visit, inputs to provide, expected outputs to observe, and edge cases to try.

## Phase 5: Code Review

### 5a: Build Check

Run lint, type-check, and build commands from `package.json` (e.g., `npm run lint`, `npm run build`) — these run in `WORK_DIR` because the Bash cwd is pinned. Fix any errors until the build is clean.

### 5b: Automated Code Review

This step is mandatory — do not skip it. Invoke the `/review-ticket` skill using the `Skill` tool to review all uncommitted changes against the ticket requirements:

```
skill: "review-ticket"
```

`/review-ticket` reads the diff via `git status` / `git diff`, which run in the pinned Bash cwd, so it sees the worktree's changes (or the main checkout's, when not in worktree mode).

### 5c: Fix and Re-review

If the code review finds any issues:
1. Fix them immediately.
2. Re-run the build check (5a) until clean.
3. Re-invoke `/review-ticket` (5b) to verify fixes.
4. Repeat until both build and code review are clean.

Do not proceed to the next phase until the build passes cleanly AND the code review returns no P0 or P1 findings.

## Phase 6: As-Built Notes, Summary, and Manual Testing

### As-Built Notes (write to the ticket file)

Before presenting the summary, append an `## As-Built Notes` section to `$WORK_DIR/docs/tickets/NNN-<slug>.md`. If the section already exists from a previous session, add a new dated entry beneath the existing content instead of duplicating the heading:

```markdown
## As-Built Notes
> Appended by implement-ticket on YYYY-MM-DD.

### Deviations from spec
- <what differs from the ticket/design source and why> (or "None")

### Key decisions
- <decision made during implementation and its rationale>

### Follow-ups / tech debt
- <deferred item or concern> (or "None")
```

This is the only ticket-file edit this skill makes — never change `## Status`, acceptance-criteria checkboxes, or `INDEX.md`. Leave the edit uncommitted alongside the code changes so it lands in the same commit the user makes later. In worktree mode the append happens in the worktree's copy of `docs/tickets/` and merges back via `/merge-worktree`.

Present the following to the user:

### Implementation Summary
1. State which ticket was implemented (ID and title).
2. Briefly summarize what was built — key files created or modified, architectural decisions made.
3. Summarize the deviations recorded in `## As-Built Notes` (or state there were none).
4. Note any remaining concerns, tech debt, or follow-up items.

### Worktree Note (only when `use_worktree` was true)

Include a short block so the user knows where the work lives and how to land it:

- **Worktree:** `.worktrees/NNN-<slug>/` (branch `ticket-NNN-<slug>`, base `<base>`).
- **Inspect:** `cd .worktrees/NNN-<slug>` to test the implementation locally.
- **Land:** `/merge-worktree NNN <base>` will merge the branch back, remove the worktree, and delete the local branch.

If the worktree was reused with pre-existing uncommitted changes, mention that here too.

### Manual Testing Instructions
Provide clear, step-by-step instructions for how to manually verify the implementation works correctly. Include:
- Prerequisites (environment setup, dependencies, services that need to be running)
- Exact commands to run the application or relevant part of it
- Specific actions to take (URLs to visit, buttons to click, inputs to provide)
- Expected results for each action
- Edge cases worth testing manually
- If the ticket involves API changes, include example curl commands or request/response pairs

If the implementation is purely internal (e.g., a refactor with no user-facing changes), state that manual testing is not applicable and explain what the automated tests cover instead.

**Do NOT commit changes, update ticket status, or invoke the `/update-ticket`, `/commit-ticket`, or `/commit-push-pr` skills.** The user will handle those steps separately. Appending `## As-Built Notes` to the ticket file (Phase 6) is the one intended ticket-file edit; status and checkboxes stay untouched. (In worktree mode the natural next step after manual testing is `/merge-worktree NNN <base>`.)
