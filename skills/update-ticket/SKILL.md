---
name: update-ticket
description: "Update a ticket's status, including worktree-backed implementations, cascade dependencies, refresh INDEX.md, and commit. Triggers on: /update-ticket, update ticket, mark ticket done, change ticket status, ticket status"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a ticket status manager. Your job is to evaluate acceptance criteria, including work done in `.worktrees/` by `/implement-ticket <ticket> worktree`, update ticket statuses, cascade dependency changes, refresh the index, and commit. Follow each phase precisely.

## Phase 1: Parse Arguments & Read State

1. **Resolve repo roots.** Confirm you're inside a git repo, then compute:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
   Use `$MAIN_ROOT` to locate canonical ticket filenames and `.worktrees/`; use `WORK_DIR` (resolved below) for all evidence gathering, ticket edits, index edits, and commits.
2. **Parse `$ARGUMENTS`.** Split on whitespace.
   - If at least one token is present, treat the first token as the ticket number. Accept formats like `TICKET-002`, `002`, `#002`, or just `2`. Normalize to a 3-digit zero-padded number (e.g., `002`). Skip auto-detect and continue at step 3.
   - If `$ARGUMENTS` is empty, run the **auto-detect** sub-steps below (1a → 1f) to resolve the ticket number, then continue at step 3.

### Auto-detect (only when `$ARGUMENTS` is empty)

**1a. Try the current branch name.** Run `git branch --show-current`. If the output matches `^ticket-(\d{3})-.+$`, extract the captured NNN, set `WORK_DIR=$CURRENT_ROOT`, tell the user in one line (`Detected TICKET-NNN from current branch \`ticket-NNN-<slug>\`.`), and proceed to step 3 with that NNN. Do not prompt — the worktree convention makes this unambiguous.

**1b. Check `.worktrees/` for ticket work.** If the current branch name didn't match, inspect registered worktrees under `$MAIN_ROOT/.worktrees/`:
- Read `git worktree list --porcelain` and keep entries whose path starts with `$MAIN_ROOT/.worktrees/`.
- For each path, run `git -C <path> branch --show-current`. If it matches `^ticket-(\d{3})-.+$`, capture the NNN.
- Treat the worktree as an update candidate when it has work to evaluate: `git -C <path> status --porcelain` is non-empty, or the branch has commits beyond the best available base. For committed-work detection, prefer the branch's upstream if one exists; otherwise compare against `$MAIN_ROOT`'s current `HEAD`, then `origin/main`, then `main` using `git merge-base`. If base comparison cannot be resolved, keep the candidate but mark its evidence as unknown rather than discarding it.

**1c. Resolve `.worktrees/` candidates.**
- **1 candidate** — Use that ticket number and set `WORK_DIR=<worktree-path>`. Tell the user in one line (`Detected TICKET-NNN from .worktrees/NNN-<slug>.`).
- **2+ candidates** — Use `AskUserQuestion` to let the user pick. Question: `Multiple ticket worktrees have work. Which one should be updated?`. Options: one per candidate, labeled `TICKET-NNN — .worktrees/NNN-<slug>`. If there are more than 4 candidates, list the 4 with the highest ticket numbers and rely on the auto-provided "Other" option for the rest. Set `WORK_DIR` to the selected path.
- **0 candidates** — Continue to 1d.

**1d. Fall back to INDEX.md `in-progress` tickets.** If branch and worktree detection didn't resolve a ticket, read `$MAIN_ROOT/docs/tickets/INDEX.md` and collect every ticket whose Status column contains `` `in-progress` `` (case-sensitive, backtick-wrapped). For each match, capture the `#NNN` reference on that row and the ticket title.

**1e. Resolve the `in-progress` candidate set.**
- **0 candidates** — Report: `No ticket number was passed, the current branch isn't a \`ticket-NNN-<slug>\` branch, no matching ticket worktree has detectable work, and no tickets are marked \`in-progress\` in INDEX.md. Please pass a ticket number (e.g., \`/update-ticket 007\`).` Then **stop**.
- **1 candidate** — Use `AskUserQuestion` to confirm: question `Update TICKET-NNN (currently \`in-progress\`)?`, options `Yes, update TICKET-NNN` and `No, stop`. If the user picks "No, stop", **stop**. Otherwise proceed to step 3 with that NNN.
- **2+ candidates** — Use `AskUserQuestion` to let the user pick. Question: `Multiple tickets are \`in-progress\`. Which one should be updated?`. Options: one per candidate, labeled `TICKET-NNN — <title>`. If there are more than 4 candidates (the `AskUserQuestion` cap), list the 4 with the highest ticket numbers and rely on the auto-provided "Other" option for the rest. Use the selected NNN.

**1f. Continue.** Once a ticket number is resolved (and confirmed where required), continue with step 3 below.

3. If a second argument is provided, use it as the target status. Valid statuses: `done`, `in-progress`, `pending`, `blocked`, `deferred`. If no status argument is provided, record the target as `auto` — the skill will evaluate acceptance criteria to determine whether `done` is appropriate.
4. If an explicit status argument is invalid, inform the user of valid options and **stop**.
5. Glob for `$MAIN_ROOT/docs/tickets/NNN-*.md` (where NNN is the zero-padded number). If no file is found, report an error and **stop**. Extract `slug` from the filename.
6. If `WORK_DIR` was not set by auto-detection, resolve it now:
   - Compute `worktree_path=$MAIN_ROOT/.worktrees/NNN-<slug>`.
   - If `$CURRENT_ROOT` is already on a branch matching the selected ticket (`^ticket-<NNN>-.+$`), set `WORK_DIR=$CURRENT_ROOT`.
   - Else if `worktree_path` appears in `git worktree list --porcelain` or `git -C "$worktree_path" rev-parse --show-toplevel` succeeds, set `WORK_DIR=$worktree_path` and tell the user in one line (`Found .worktrees/NNN-<slug>; checking that worktree for TICKET-NNN evidence.`).
   - Otherwise set `WORK_DIR=$CURRENT_ROOT`.
7. Glob for `$WORK_DIR/docs/tickets/NNN-*.md`. If no file is found there, fall back to the `$MAIN_ROOT` ticket file only if `WORK_DIR=$MAIN_ROOT`; otherwise report that the selected worktree is missing the ticket file and **stop**.
8. Read the matched ticket file from `WORK_DIR`.
9. Check the current status under `## Status`. If it already matches the target status (and target is not `auto`), inform the user (e.g., "TICKET-002 is already `done`") and **stop**. This ensures idempotency.
10. Read `$WORK_DIR/docs/tickets/INDEX.md`.
11. Parse the `## Acceptance Criteria` section from the ticket file. Extract each criterion line (`- [ ]` or `- [x]`) into a list with its text and current checked state.

## Phase 2: Evaluate Acceptance Criteria

**Skip this phase entirely if** the target status is not `done` and not `auto`.
**Skip this phase entirely if** all acceptance criteria are already checked (`- [x]`).
**Skip this phase entirely if** the ticket has no `## Acceptance Criteria` section (treat as all met; log a note).

### 2.1 Gather Evidence

1. Run `git -C "$WORK_DIR" status --porcelain` to identify uncommitted changes.
2. Run `git -C "$WORK_DIR" diff` and `git -C "$WORK_DIR" diff --cached` to get uncommitted diffs.
3. If `WORK_DIR` is under `$MAIN_ROOT/.worktrees/`, also gather committed ticket work: compare `HEAD` against the best available base (upstream first, then `$MAIN_ROOT`'s current `HEAD`, then `origin/main`, then `main`) and inspect `git -C "$WORK_DIR" diff <base>...HEAD`. This catches implementations that `/implement-ticket <ticket> worktree` already committed.
4. Read the ticket's Description, Implementation Notes, and Testing sections for context on what was built and where.
5. Identify files referenced in the ticket or changed in any diff. Read their full content from `WORK_DIR` for context.

### 2.2 Evaluate Each Unchecked Criterion

For each criterion that is currently unchecked (`- [ ]`):

1. Read the criterion text and understand what it requires.
2. Search the codebase for evidence that the criterion is satisfied:
   - Use grep, glob, and file reads under `WORK_DIR` to find referenced constructs (components, routes, functions, configurations, etc.).
   - Check uncommitted changes, committed ticket-branch changes, and already-committed code in `WORK_DIR`.
3. For criteria that reference test execution or build commands (e.g., "tests pass", "build succeeds"), run the referenced command and check the exit code.
4. For criteria that require manual or visual verification (e.g., "navigate to", "visually verify", "responsive layout"), flag as `manual` — do not auto-evaluate.
5. Assign a verdict: `met`, `unmet`, or `manual`.

### 2.3 Determine Status

- **Auto mode** (no explicit status was provided):
  - If all criteria are `met` (or `met` + `manual` with none `unmet`): set target status to `done` and proceed.
  - If any criteria are `unmet`: report findings, do NOT change the ticket status, and **stop**.
- **Explicit `done`** (user explicitly requested `done`):
  - If all criteria are `met`: proceed normally.
  - If any criteria are `unmet`: present the evaluation report and ask the user to confirm. If the user confirms, proceed with `done`. If the user declines, **stop**.

### 2.4 Report Evaluation

Present the evaluation to the user before proceeding:

```
## Acceptance Criteria Evaluation — TICKET-NNN

**Result**: X/Y criteria met, Z require manual verification

- [x] Criterion A — verified: found in `src/components/Foo.tsx`
- [ ] Criterion B — UNMET: no matching implementation found
- [ ] Criterion C — MANUAL: requires visual verification
```

## Phase 3: Update Target Ticket File

1. Edit the `WORK_DIR` ticket file's status line (the backtick-wrapped status under `## Status`) to the new status.
   - Example: change `` `pending` `` to `` `done` ``
2. If the target status is `done`:
   - Only check acceptance-criteria boxes (`- [ ]` → `- [x]`) for criteria that were evaluated as `met` in Phase 2. Leave `unmet` and `manual` criteria unchecked.

## Phase 4: Cascade Dependencies (only when target status = `done`)

Skip this phase entirely if the target status is NOT `done`.

1. Grep all files in `$WORK_DIR/docs/tickets/` for `#NNN` (where NNN is the ticket number) appearing in lines that contain `Requires:`.
2. For each dependent ticket file found:
   a. Read the file.
   b. On the `- Requires:` line, find `#NNN` and append ` ✅` after it — but ONLY if ` ✅` is not already there. Be careful not to double-append.
   c. Check if ALL dependencies listed on the `- Requires:` line now have ` ✅` after them.
   d. If ALL dependencies are satisfied AND the ticket's current status is `blocked`:
      - Change its status to `pending`.
      - Record this ticket number and name for reporting in Phase 6.
   e. Preserve any sub-bullet context lines below the `- Requires:` line (lines starting with `  -`). Do not modify them.

## Phase 5: Update INDEX.md

Read `$WORK_DIR/docs/tickets/INDEX.md` again (it may have been read in Phase 1, but re-read for accuracy).

Make the following updates:

### 5.1 Target Ticket Row
- Find the row for the target ticket in the phase tables and update its Status column to the new status (backtick-wrapped, e.g., `` `done` ``).
- If marking as `done`, add a brief note in the Notes column if empty.

### 5.2 Depends On Columns
- In ALL rows across all phase tables, find any occurrence of `#NNN` (the completed ticket) in the "Depends On" column.
- Append ` ✅` after `#NNN` if not already present.
- Do NOT modify range references like `#012–#020` — only modify individual `#NNN` references.
- Do NOT modify the word "All" in depends-on columns.

### 5.3 Newly Unblocked Tickets
- For any ticket that was changed from `blocked` to `pending` in Phase 4:
  - Update its Status column from `` `blocked` `` to `` `pending` `` in INDEX.md.
  - Add "Unblocked" (or a more descriptive note like "Unblocked — [dep] now done") to its Notes column.

### 5.4 Summary Count Table
- Recount ALL ticket statuses from the phase tables (not from the old summary).
- Update the count for each status row in the Summary table at the top.
- The statuses to count are: `done`, `in-progress`, `pending`, `blocked`, `deferred`.

### 5.5 Dependency Graph
- Update the status marker next to the target ticket:
  - `done` → `✅ DONE`
  - `in-progress` → `🔧 IN PROGRESS`
  - `pending` → `📋 PENDING`
  - `blocked` → `🚫 BLOCKED`
  - `deferred` → `⏸️ DEFERRED`
- Also update markers for any tickets that were unblocked in Phase 4.
- Only update markers where they already exist in the graph — do not add new ones to tickets that don't have them.

### 5.6 Last Updated Date
- Update the "Last updated" line to today's date.

## Phase 6: Verify

1. Re-read `$WORK_DIR/docs/tickets/INDEX.md`.
2. Cross-check: count the statuses in each phase table and compare to the Summary table counts. If they don't match, fix them.
3. Sanity check: ensure no ticket is listed as `pending` in INDEX.md while having unmet dependencies (i.e., dependencies without ` ✅`).
4. **If the target status was `done`**, scan every phase table in INDEX.md and collect each row whose Status is `` `pending` ``. For each row, capture the ticket number and title, and note whether it appears in the Phase 4 "newly unblocked" list. Sort by ticket number ascending.
5. Report to the user:
   - Which ticket was updated and to what status, and whether updates were made in the main checkout or `.worktrees/NNN-<slug>`.
   - **Tickets ready to work on** (only when the target status was `done`): a bulleted list of every `pending` ticket gathered in step 4. Annotate newly-unblocked entries with `(newly unblocked)` at the end of the line. Include the count in the section header. If zero tickets are pending, say so explicitly (e.g., `No tickets are currently ready — all remaining work is blocked, in-progress, or done.`). Format:

     ```
     ## Tickets ready to work on (N)
     - TICKET-NNN — Title
     - TICKET-NNN — Title (newly unblocked)
     ```

     These are the tickets you can pick up in parallel via `/create-worktree`.
   - **Next step for this ticket** (only when the target status was `done` AND the worktree `$MAIN_ROOT/.worktrees/NNN-<slug>` actually exists on disk): tell the user the next step is `/merge-worktree NNN` (append the non-default base branch if one is known; otherwise omit it and let `/merge-worktree` default to `main`). Explicitly note that `/merge-worktree` will auto-commit any remaining uncommitted implementation code in the worktree before merging, so the user does NOT need to run `/commit-ticket` or `git commit` first. Format:

     ```
     ## Next step
     Run `/merge-worktree NNN` to land this ticket. It will auto-commit any uncommitted implementation code in the worktree before merging into <base> — you do not need to commit first.
     ```

     Skip this bullet entirely if that worktree does not exist, or if the target status wasn't `done`. **Being on branch `ticket-NNN-<slug>` is not sufficient on its own.** `/implement-ticket` now creates that branch on every invocation, including in the main checkout where there is no worktree to merge — suggesting `/merge-worktree` there would send the user at a worktree that does not exist, and would contradict `/implement-ticket`'s own landing phase, which offers to land the work itself.
   - Summary of current status counts.

## Phase 7: Commit

1. Stage all modified ticket files and INDEX.md from `WORK_DIR`:
   ```
   git -C "$WORK_DIR" add docs/tickets/
   ```
2. Craft a commit message based on what changed:
   - If only the target ticket changed: `docs: mark TICKET-NNN as <status>`
   - If tickets were also unblocked: `docs: mark TICKET-NNN as done, unblock TICKET-XXX [, TICKET-YYY]`
   - If criteria were partially met but user forced done: `docs: mark TICKET-NNN as done (X/Y criteria verified)`
   - For non-done statuses: `docs: update TICKET-NNN status to <status>`
3. Commit the changes from `WORK_DIR`.

## Edge Case Reminders

- **Already at target status**: Phase 1 catches this — inform and stop.
- **Ticket not found**: Phase 1 catches this — error and stop.
- **No Acceptance Criteria section**: Skip evaluation, treat as all met, log a note.
- **All criteria already checked**: Skip evaluation, proceed directly.
- **Mixed checked/unchecked criteria**: Only evaluate the unchecked ones. Already-checked criteria are assumed previously verified.
- **Test command fails or times out**: Mark the criterion as `unmet` and report the error.
- **No git changes (clean working tree)**: Fine — evaluation checks repo state, not just the diff.
- **Worktree implementation**: If `.worktrees/NNN-<slug>` exists for the ticket, evaluate and update that worktree by default so the ticket-status commit lands on the same branch as the implementation.
- **Range deps** (`#012–#020`): Don't modify ranges in INDEX.md Depends On columns.
- **"All" dependency** (ticket 022): Only unblock when genuinely all other tickets are done. Check each one.
- **Non-done statuses**: Skip Phase 2 and Phase 4 entirely — no evaluation, no cascading, just update the target ticket and INDEX.
