---
name: "update-ticket"
description: "Use when the user explicitly asks to update a ticket status, including work in a matching .worktrees checkout, cascade dependency markers, refresh docs/tickets/INDEX.md, and commit the ticket-document changes. Prefer explicit invocation with $update-ticket."
---

# Update Ticket Status

Update a ticket's status, cascade dependency state where needed, refresh `docs/tickets/INDEX.md`, and commit the documentation changes. If `$implement-ticket <ticket> worktree` put the implementation under `.worktrees/NNN-slug/`, evaluate and update that worktree so the ticket-status commit stays with the implementation branch.

Parse any text that follows the skill invocation as arguments. Accept ticket identifiers like `TICKET-002`, `002`, `#002`, or `2`. Accept statuses `done`, `in-progress`, `pending`, `blocked`, and `deferred`. If no status is provided, auto-evaluate acceptance criteria to decide between `done` and keeping the current status.

## Phase 1: Read State

1. Resolve `MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` and `CURRENT_ROOT=$(git rev-parse --show-toplevel)`.
2. Normalize the requested ticket number to a zero-padded 3-digit identifier. If no ticket number was provided, auto-detect in this order:
   - current branch matching `ticket-NNN-*`
   - registered worktrees under `$MAIN_ROOT/.worktrees/` whose branch matches `ticket-NNN-*` and has uncommitted changes or commits beyond the best available base
   - tickets marked `in-progress` in `$MAIN_ROOT/docs/tickets/INDEX.md`
   Ask the user only when auto-detection is ambiguous.
3. Validate the target status. If no status provided, record as `auto`.
4. Find the matching canonical ticket file under `$MAIN_ROOT/docs/tickets/` and derive the slug from the filename.
5. Select `WORK_DIR`:
   - If `$CURRENT_ROOT` is already the matching `ticket-NNN-*` checkout, use it.
   - Else if `$MAIN_ROOT/.worktrees/NNN-<slug>` exists or is registered in `git worktree list --porcelain`, use that worktree and tell the user it is being checked.
   - Otherwise use `$CURRENT_ROOT`.
6. Read `$WORK_DIR/docs/tickets/NNN-*.md` and `$WORK_DIR/docs/tickets/INDEX.md`.
7. If the ticket already has the requested status, report that and stop.
8. Parse the `## Acceptance Criteria` section — extract each criterion with its checked state.

## Phase 2: Evaluate Acceptance Criteria

Skip if target status is not `done` and not `auto`. Skip if all criteria are already checked or if there is no Acceptance Criteria section.

1. Gather evidence from `WORK_DIR`: run `git -C "$WORK_DIR" status --porcelain`, `git -C "$WORK_DIR" diff`, and `git -C "$WORK_DIR" diff --cached`. If `WORK_DIR` is under `.worktrees/`, also inspect committed branch work with `git -C "$WORK_DIR" diff <base>...HEAD`, choosing `<base>` from the branch upstream, `$MAIN_ROOT`'s current `HEAD`, `origin/main`, then `main` as available. Read the ticket's Description, Implementation Notes, and Testing sections. Read files referenced in the ticket or changed in any diff.
2. Evaluate each unchecked criterion against the codebase:
   - Search for evidence using grep, glob, and file reads under `WORK_DIR` (uncommitted changes, committed ticket-branch changes, and committed code).
   - For criteria referencing test/build commands, run the command and check the result.
   - For criteria requiring manual/visual verification, flag as `manual`.
   - Verdict per criterion: `met`, `unmet`, or `manual`.
3. Determine status:
   - **Auto mode**: all met (or met + manual) → `done`. Any unmet → report and **stop**.
   - **Explicit `done`**: any unmet → ask user to confirm before proceeding.
4. Report the per-criterion evaluation before proceeding.

## Phase 3: Update the Ticket File

1. Update the status line under `## Status` in the `WORK_DIR` ticket file.
2. If the target status is `done`, only check acceptance-criteria boxes for criteria evaluated as `met`. Leave `unmet` and `manual` criteria unchecked.

## Phase 4: Cascade Dependencies for `done`

If the target status is `done`:

1. Find every ticket under `$WORK_DIR/docs/tickets/` that references the completed ticket in a `Requires:` line.
2. Mark that dependency satisfied if it is not already marked.
3. If a dependent ticket now has all dependencies satisfied and is currently `blocked`, move it to `pending`.
4. Record every ticket that became unblocked so you can update the index and report it clearly.

## Phase 5: Refresh `INDEX.md`

Update `$WORK_DIR/docs/tickets/INDEX.md` in place:

1. Update the target ticket row status.
2. Mark satisfied single-ticket dependencies in "Depends On" columns.
3. Update any newly unblocked ticket rows.
4. Recount the summary table totals.
5. Refresh existing dependency graph markers already present in the file.
6. Update the "Last updated" date.

Preserve range dependencies such as `#012-#020` and preserve the word `All` where the file uses it.

## Phase 6: Verify

1. Re-read `$WORK_DIR/docs/tickets/INDEX.md`.
2. Check that the summary counts match the phase tables.
3. Check that no ticket is marked `pending` while still showing unmet dependencies.
4. Report the updated ticket and new status, whether the update happened in the main checkout or `.worktrees/NNN-<slug>`, the final status counts, and — if the target status was `done` — a `Tickets ready to work on (N)` bulleted list of every ticket whose Status in INDEX.md is `pending`. Sort by ticket number ascending and annotate newly-unblocked entries with `(newly unblocked)`. If no tickets are pending, say so explicitly. These are the tickets the user can pick up in parallel via `/create-worktree`.
5. If the target status was `done` and `WORK_DIR` is the matching ticket worktree, explain the next steps using the active Codex skills' preconditions: after this skill's documentation commit, any remaining implementation changes need a separate `$commit-ticket` in that worktree. Codex `$merge-worktree` requires both a clean ticket worktree and a clean main checkout; it does not auto-commit the implementation. Recommend `$merge-worktree NNN <base>` from `MAIN_ROOT` once those conditions hold, naming any main-checkout `.gitignore` change that still needs handling. Reuse a known base; if unknown, ask before merging rather than guessing. These are next-step suggestions, not authorization to commit code or merge within this update run.

## Phase 7: Commit

1. From `WORK_DIR`, stage only the ticket files and `docs/tickets/INDEX.md`.
2. From `WORK_DIR`, create one docs-focused commit message that reflects the status change, then commit the staged docs. If criteria were partially met but user forced done, note in the message: `docs: mark TICKET-NNN as done (X/Y criteria verified)`.

## Safety Rules

- If the ticket file or index is missing, stop and report the missing input.
- If a matching `.worktrees/NNN-<slug>` checkout exists, evaluate and update that checkout by default so docs and implementation land on the same branch.
- Do not modify unrelated docs.
- If the requested status is invalid, report the valid options and stop.
- If criteria evaluation cannot determine status, ask the user rather than guessing.
