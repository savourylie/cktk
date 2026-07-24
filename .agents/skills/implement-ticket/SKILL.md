---
name: "implement-ticket"
description: "Use when the user explicitly asks to implement one or more backlog tickets from docs/tickets. Optionally pass `worktree` after the ticket id (with an optional base branch) to run the implementation inside an isolated git worktree, auto-creating it via $create-worktree if it doesn't exist. Prefer explicit invocation with $implement-ticket."
---

# Implement Backlog Tickets

Work through the project's ticket tracker and implement the requested ticket or tickets end to end. Treat this as an explicit workflow skill because it writes code, runs checks, and may commit changes.

If the user included a ticket identifier after `$implement-ticket`, implement only that ticket. Otherwise work through the pending backlog in order until you hit a blocker or finish the remaining tickets.

## Argument grammar

When a single ticket is named, the user can also opt into worktree mode:

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Implement that ticket in the current checkout. |
| `<ticket> worktree` | Implement inside an isolated worktree off `origin/main`. |
| `<ticket> worktree <base>` | Implement inside a worktree off `origin/<base>` (e.g. `dev`). |
| (no args) | Loop through the pending backlog in the current checkout. |

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode. A second token that is not `worktree` is a typo — stop and tell the user "unrecognized argument; pass `worktree` to use a worktree." Worktree mode only makes sense for a single named ticket; if the user provided no ticket id, ignore the `worktree` keyword (it has no ticket to attach to) and report that.

## Phase 1: Set Up the Working Directory

Run this whether or not worktree mode is requested — both modes need the same handles.

1. Parse the argument string. Capture `ticket_id` (if any), `use_worktree` (bool), and `base` (default `main`, only meaningful when `use_worktree` is true).
2. Resolve the main repo root so the skill behaves the same when invoked from the main checkout or another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
3. If a single ticket id was provided:
   - Normalize to a 3-digit zero-padded `NNN`.
   - Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match → report and stop. Multiple matches → report and stop.
   - Slug = the filename minus the `NNN-` prefix and `.md` suffix.
   - Worktree path: `$MAIN_ROOT/.worktrees/NNN-<slug>`. Branch name: `ticket-NNN-<slug>`.
4. If `use_worktree` is true:
   - If the worktree path is registered in `git worktree list --porcelain`, reuse it. Allow uncommitted state inside (resuming work) but note it in the final summary.
   - Otherwise invoke `$create-worktree` and pass `<NNN> [base]` so it provisions the worktree, branch, and `.worktrees/` gitignore entry.
   - Set `WORK_DIR = <worktree-path>`.
5. If `use_worktree` is false: set `WORK_DIR = $MAIN_ROOT` (or the user's `git rev-parse --show-toplevel` if they invoked the skill from a worktree on purpose).
6. `cd "$WORK_DIR"` once via Bash. The Bash cwd persists between commands within this session, so every later step — including any sub-skill invocation that runs `git status` or `git diff` — operates against `WORK_DIR`. For tools that need absolute file paths, prefix with `$WORK_DIR`.
7. State in one short sentence which mode is active and where work is happening before you start reading project files.

## Phase 2: Understand the Project

1. Read `$WORK_DIR/docs/PRD.md`.
2. Read the project's design source:
   - Prefer `$WORK_DIR/docs/DESIGN.md`.
   - If that is missing, use `$WORK_DIR/docs/design/DESIGN.md` if present.
   - If no `DESIGN.md` file exists, search for a folder named `design-system` (commonly `$WORK_DIR/design-system/` or `$WORK_DIR/docs/design-system/`) and use that as the design source.
   - If using a `design-system/` folder, read its README/index file first if present, then read the files relevant to architecture, component patterns, tokens, data models, API contracts, and implementation constraints.
3. Build a working mental model of the product requirements, architecture, constraints, and acceptance criteria before changing code.

## Phase 3: Pick the Ticket

1. Read `$WORK_DIR/docs/tickets/INDEX.md`.
2. If the user named a ticket, select it even if it is out of order.
3. Otherwise pick the next ticket that is not done, respecting ordering and dependencies.
4. Read the full ticket file before you start coding.
5. If the selected ticket is already done, report that and stop.

## Phase 4: Implement

1. State what you are about to implement, which files you expect to touch, and the main risks.
2. Implement the ticket fully against the ticket requirements and the project's design source. All edits land under `$WORK_DIR`.
3. Follow project conventions and add tests whenever the repo has a test suite or the ticket implies testable behavior.
4. Handle edge cases and integration details before moving on.

## Phase 5: Validate

1. Run the relevant lint, type-check, test, and build commands for the repo. The Bash cwd is pinned to `$WORK_DIR`, so these run against the worktree's checkout when worktree mode is active.
2. Fix every regression introduced by the ticket.
3. Perform a review pass against the same rubric used by the review workflow:
   - read `../review-ticket/references/review-guidelines.md`
   - review only the diff introduced by the ticket
   - look for correctness issues, missing acceptance criteria, risky edge cases, and regressions
4. If the review pass finds issues, fix them and rerun the checks.

## Phase 6: Commit

1. Append an `## As-Built Notes` section to `$WORK_DIR/docs/tickets/NNN-*.md` before staging — a dated entry with deviations from spec and why, key decisions, and follow-ups/tech debt (write "None" where a bucket is empty; if the section already exists, add a new dated entry beneath it). Do not change `## Status` or acceptance checkboxes here — Phase 7 owns those.
2. Stage the files for the ticket, including the ticket file with its As-Built Notes (in `$WORK_DIR`, on the ticket branch when in worktree mode).
3. Create one commit with a clear conventional message such as:

```text
feat(TICKET-ID): short summary

- key change
- key change
```

4. Do not mix unrelated changes into the ticket commit.

## Phase 7: Update Ticket Status Directly

Perform the ticket status update yourself instead of delegating to another skill. Operate inside `$WORK_DIR` — when worktree mode is active the status updates land on the ticket branch and merge back cleanly when the user later runs `$merge-worktree`.

1. Update the ticket file status under `## Status`.
2. If marking the ticket done, check all acceptance criteria in that ticket file.
3. Refresh `docs/tickets/INDEX.md`:
   - update the target ticket row
   - mark satisfied single-ticket dependencies
   - update any newly unblocked tickets from `blocked` to `pending`
   - refresh summary counts
   - refresh any existing dependency graph markers already present in the file
   - update the "Last updated" date
4. Verify the index is internally consistent before you finish.

## Phase 8: Loop or Stop

- If the user named a specific ticket, stop after Phase 7. When worktree mode was active, mention the worktree path and the `$merge-worktree NNN [base]` command so the user knows the natural next step to land the work.
- Otherwise continue with the next pending ticket until all tickets are done or you hit a real blocker. The backlog loop only runs in the non-worktree path — looping across worktrees is out of scope for one invocation.

## Safety Rules

- If `docs/PRD.md`, the project's design source (`docs/DESIGN.md`, `docs/design/DESIGN.md`, or a folder named `design-system`), or the ticket tracker files are missing, stop and report the missing inputs.
- If a dependency is unresolved, do not implement a blocked ticket out of order.
- If unrelated user changes conflict with the ticket, stop and ask how to proceed instead of overwriting them.
- In worktree mode, do not switch the user's main checkout to another branch and do not delete the worktree at the end — leave both alone so the user can inspect the work and run `$merge-worktree` deliberately.
