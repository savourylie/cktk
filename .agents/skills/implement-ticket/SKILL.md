---
name: "implement-ticket"
description: "Use when the user explicitly asks to implement one or more backlog tickets from docs/tickets. Each ticket is implemented on its own branch, and the run ends by offering to merge it, open a PR, or stay on the branch. Optionally pass a base branch or `worktree`; for one named ticket, a final `via codex`, `via claude`, or `via grok` clause delegates implementation only to that CLI before the invoking host independently validates and reviews it. Prefer explicit invocation with $implement-ticket."
---

# Implement Backlog Tickets

Work through the project's ticket tracker and implement the requested ticket or tickets end to end. Treat this as an explicit workflow skill because it writes code, runs checks, and may commit changes.

If the user included a ticket identifier after `$implement-ticket`, implement only that ticket. Otherwise work through the pending backlog in order until you hit a blocker or finish the remaining tickets.

## Portable interaction rules

This skill prompts the user at several points — when the working tree is dirty, when resuming without a discoverable base, and when landing the work. All of them follow these rules:

- Show every option with a stable number and a one-line description of what it does. A yes/no confirmation is the degenerate case: state the default explicitly (`[y/N]`) and treat anything but an explicit yes as that default.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name, using `$skill-name` syntax when suggesting a command.

## Argument grammar

Every invocation implements on a branch. The optional tokens choose where that branch lives and what it forks from:

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | New branch off the current HEAD, in the current checkout. |
| `<ticket> <base>` | New branch off `origin/<base>` (e.g. `dev`), in the current checkout. |
| `<ticket> worktree` | New branch off `origin/main`, inside an isolated worktree. |
| `<ticket> worktree <base>` | New branch off `origin/<base>`, inside an isolated worktree. |
| (no args) | Loop through the pending backlog, one branch per ticket (see Phase 8). |

For one explicitly named ticket, any valid row may end with the optional final
clause `via <executor>`, where `<executor>` is exactly `codex`, `claude`, or
`grok` (case-insensitive):

| Invocation | Meaning |
| --- | --- |
| `<ticket> via claude` | Keep normal branch setup, then delegate implementation to Claude Code CLI. |
| `<ticket> <base> via grok` | Fork from `<base>`, then delegate implementation to Grok Build CLI. |
| `<ticket> worktree [base] via codex` | Use the requested worktree, then delegate implementation to Codex CLI. |

Parse the `via` clause before deciding whether a trailing token is `worktree` or
a base branch:

1. Count case-insensitive `via` tokens. More than one is a duplicate clause and is an invocation error.
2. If no `via` appears, leave `executor` unset and preserve the native Codex workflow exactly, including no-argument backlog-loop mode.
3. If present, `via` must be the penultimate token and an explicit ticket must be present. Reject a missing executor, unknown executor, backlog-loop delegation, or any tokens after the executor.
4. Normalize the executor to lowercase, remove the final pair, then parse the remaining tokens with the existing grammar.

Do not reinterpret an invalid executor as a base branch. Stop with
`unsupported executor '<name>' (expected codex, claude, or grok)` before any
branch or worktree setup.

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode. Any other trailing token is read as a base branch and must resolve — check `git rev-parse --verify --quiet origin/<token>` then `git rev-parse --verify --quiet <token>`. If neither resolves, stop with "unrecognized argument '<token>' — did you mean 'worktree'? (no branch named '<token>' found locally or on origin)". Worktree mode only makes sense for a single named ticket; if the user provided no ticket id, ignore the `worktree` keyword (it has no ticket to attach to) and report that. A fourth token is an error.

## Phase 1: Set Up the Working Directory

Run this whether or not worktree mode is requested — both modes need the same handles.

1. Parse the argument string. Capture `ticket_id` (if any), `use_worktree` (bool), `base_token` (the trailing non-ticket, non-`worktree` token, if any), and `executor` (unset for native runs, otherwise the normalized final `via` target). Validate `base_token` as described in the argument grammar above.
2. Resolve the main repo root so the skill behaves the same when invoked from the main checkout or another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
3. Once a ticket is known — from the argument, or in backlog-loop mode from Phase 3's selection on this iteration:
   - Normalize to a 3-digit zero-padded `NNN`.
   - Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match → report and stop. Multiple matches → report and stop.
   - Slug = the filename minus the `NNN-` prefix and `.md` suffix.
   - Worktree path: `$MAIN_ROOT/.worktrees/NNN-<slug>`. Branch name: `ticket-NNN-<slug>`.
4. Resolve `base` — the branch Phase 8 will offer to merge into:
   - Worktree mode: `base_token` if present, otherwise `main`.
   - Current checkout with a `base_token`: that token.
   - Current checkout without one, when the current branch is **not** `ticket-NNN-<slug>`: the current branch, from `git rev-parse --abbrev-ref HEAD`. If that returns `HEAD` (detached), stop and ask for an explicit base branch.
   - Current checkout without one, when the current branch already **is** `ticket-NNN-<slug>` (you are resuming): a branch cannot be its own base, and nothing on disk records what it forked from. Ask once, following the portable interaction rules, offering the plausible bases that actually exist locally or on `origin` (check `main`, `master`, `dev`, `develop`). Use the answer as `base`; if the user declines, record no base and mark Phase 8's option 1 unavailable rather than guessing. Without this rule, option 1 would merge the branch into itself — git reports "Already up to date" and exits 0, so the skill would claim a successful land while nothing reached the real base.
   - In backlog-loop mode, resolve `base` once at the start of the run and keep it for every ticket.
5. If `use_worktree` is true:
   - If the worktree path is registered in `git worktree list --porcelain`, reuse it. Allow uncommitted state inside (resuming work) but note it in the final summary.
   - Otherwise invoke `$create-worktree` and pass `<NNN> [base]` so it provisions the worktree, branch, and `.worktrees/` gitignore entry.
   - Set `WORK_DIR = <worktree-path>`. The branch already exists on it — skip step 8.
6. If `use_worktree` is false: set `WORK_DIR = $MAIN_ROOT` (or the user's `git rev-parse --show-toplevel` if they invoked the skill from a worktree on purpose).
7. `cd "$WORK_DIR"` once via Bash. The Bash cwd persists between commands within this session, so every later step — including any sub-skill invocation that runs `git status` or `git diff` — operates against `WORK_DIR`. For tools that need absolute file paths, prefix with `$WORK_DIR`.
8. Create or reuse the ticket branch (current-checkout mode only). Never implement onto whatever branch happened to be checked out:
   - Already on `ticket-NNN-<slug>` → reuse it and report "resuming".
   - The branch exists but is not checked out → `git switch ticket-NNN-<slug>` and report that it was reused. Do not rebase it.
   - Otherwise:
     - Run `git status --porcelain`. If non-empty, list the files, warn that they will be carried onto `ticket-NNN-<slug>` and may land in the ticket commit, and ask "Continue? [y/N]". Anything other than an explicit yes stops before any branch is created.
     - With a `base_token`: `git fetch origin <base>` (warn and continue on failure), then `git switch -c ticket-NNN-<slug> origin/<base>`, falling back to local `<base>`. If neither ref exists, stop.
     - Without one: `git switch -c ticket-NNN-<slug>`.
     - If `git switch -c` fails because local changes would be overwritten, report git's error and stop. Do not force, stash, or discard.
   - In backlog-loop mode this step runs once per ticket, always forking from the current HEAD so each ticket stacks on the one before it and dependent tickets still compile.
9. State in one short sentence which mode is active, which branch you are on, and where work is happening before you start reading project files.

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
6. In backlog-loop mode, run Phase 1 step 3 (resolve `NNN`, slug, and branch name) and Phase 1 step 8 (create `ticket-NNN-<slug>` from the current HEAD) for the ticket you just selected, before continuing to Phase 4. This applies to the first ticket of the run as well as to every later one.

## Phase 4: Implement

### Native Codex path (no `via` clause)

When `executor` is unset, preserve the existing behavior:

1. State what you are about to implement, which files you expect to touch, and the main risks.
2. Implement the ticket fully against the ticket requirements and the project's design source. All edits land under `$WORK_DIR`.
3. Follow project conventions and add tests whenever the repo has a test suite or the ticket implies testable behavior.
4. Handle edge cases and integration details before moving on.

### Delegated path (`via <executor>`)

When `executor` is set, the target CLI performs implementation only. The invoking host remains responsible for the ticket-specific review, build verification, remediation, As-Built Notes, status work, and the final landing choice.

1. Set `current_host` from the runtime: `codex` in Codex or `grok` in Grok Build. Do not infer it from installed commands. If the runtime cannot be mapped to the release allowlist, stop. If `executor == current_host`, stop with `executor '<name>' is the current host; omit via to use native implementation`.
2. Locate this Codex skill's bundled `scripts/run-ticket-executor.sh` and store its absolute path as `ADAPTER`. Resolve it from the skill directory, not from the target project; never run a project-local file with the same name.
3. Create `$WORK_DIR/.ai/cktk/delegation/` and a unique run stem such as `TICKET-NNN-<UTC timestamp>-<shell pid>`. Use the file-editing tool to write `<stem>.input.md` with:
   - ticket id, title, full requirements, and acceptance criteria;
   - absolute ticket, PRD, and chosen design-source paths;
   - `$WORK_DIR`, expected files/areas, project conventions, risks, and relevant test commands;
   - a note that the adapter adds the authoritative implementation-only boundary.

   Do not include credentials, connector tokens, hidden reasoning, or ticket-status instructions. Use `<stem>.json` for the outcome record. Preserve `.ai/cktk/delegation/` on failure or timeout, exclude it from source review, and never stage these diagnostics.
4. Invoke the adapter exactly once:

   ```bash
   bash "$ADAPTER" \
     --host "$current_host" \
     --executor "$executor" \
     --work-dir "$WORK_DIR" \
     --task-file "$WORK_DIR/.ai/cktk/delegation/<stem>.input.md" \
     --record-file "$WORK_DIR/.ai/cktk/delegation/<stem>.json" \
     --timeout-seconds 1800
   ```

   `run-ticket-executor.sh` owns executor validation, CLI discovery and version checking, final task-package construction, fixed non-interactive invocation, bounded waiting, output capture, no-change detection, and the atomic record. Never replace it with `eval`, free-form shell text, or an automatic retry.
5. On a non-zero exit, report the adapter error plus `$WORK_DIR` and the record path when it exists, then stop. Do not commit, discard, reset, retry, land, or delete the worktree. When a record exists, read its `status` instead of inferring the cause from the numeric exit because raw target exit codes are preserved. `no_changes` means no new reviewable implementation, `forbidden_git_state` means the target changed the pinned branch or HEAD, and `git_inspection_failed` means the adapter could not safely verify Git state.
6. On exit `0`, independently inspect source state while excluding the preserved diagnostics:

   ```bash
   git status --porcelain=v1 --untracked-files=all -- . \
     ':(exclude).ai/cktk/delegation/**'
   ```

   Empty output is a safe stop: report `no reviewable implementation was produced`, the worktree, and the record path. Otherwise continue to Phase 5 and require the delegated-path ticket review described there. Never trust the executor's final response as verification.

The generated task package must say the target agent **must not commit, push, merge, delete a worktree, or change ticket status**. Codex retains all lifecycle authority after implementation.

## Phase 5: Validate

1. Run the relevant lint, type-check, test, and build commands for the repo. The Bash cwd is pinned to `$WORK_DIR`, so these run against the worktree's checkout when worktree mode is active.
2. Fix every regression introduced by the ticket.
3. Perform a review pass against the same rubric used by the review workflow:
   - Delegated path: invoke `$review-ticket NNN` so the review opens the ticket and checks its acceptance criteria. Passing the ticket id is mandatory; generic diff review is not ticket-specific review.
   - Native path: read `../review-ticket/references/review-guidelines.md`.
   - In both paths, review only the diff introduced by the ticket and look for correctness issues, missing acceptance criteria, risky edge cases, and regressions.
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
5. Commit the status and index changes, separately from Phase 6's code commit:
   ```
   git add docs/tickets/
   git commit -m "docs: mark TICKET-NNN as <status>"
   ```
   Use `docs: mark TICKET-NNN as done, unblock TICKET-XXX` when the update cascaded to other tickets. This keeps the ticket metadata in its own commit and leaves the tree clean for Phase 8.

## Phase 8: Loop, then Land

**Loop first.** If the user named a specific ticket, go straight to the landing prompt below. Otherwise continue with the next pending ticket by re-entering the workflow in this order: **Phase 3** to pick it, then **Phase 1 step 3** to resolve its `NNN`, slug, and branch name, then **Phase 1 step 8** to create `ticket-NNN-<slug>` from the current HEAD — which is the previous ticket's branch, so the work stacks and dependent tickets still compile — and only then **Phase 4** onward. Repeat until all tickets are done or you hit a real blocker. Track every branch you create during the run. The backlog loop only runs in the non-worktree path; looping across worktrees is out of scope for one invocation.

**Then land, once per run.** Phases 6 and 7 already committed the code and the ticket status, so this prompt is only about where those commits go. Ask exactly once, following the portable interaction rules.

**Before any repo-level git operation in this phase, run `cd "$MAIN_ROOT"`.** The Bash cwd has been pinned to `$WORK_DIR` since the setup phase, and every option below acts on the repository as a whole — merging into the base, delegating to another skill, or removing the very worktree the cwd points at. Operating from inside a worktree here causes silent wrong answers, not loud errors.

Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, still show option 2 but mark it unavailable with the reason, and do not accept it. If no base was recorded — a resume where the user declined to name one — show option 1 as unavailable for that reason and do not accept it; options 2 and 3 (and 4 where present) need no base.

````
TICKET-NNN implemented on ticket-NNN-<slug> (base: <base>).
How do you want to land it?

  1  Merge into <base> locally  (merge --no-ff → delete branch)
  2  Open a PR                  ($commit-push-pr)
  3  Stay on the branch         [default]
````

In backlog-loop mode, name every ticket and branch from the run in the prompt instead of just one. An ambiguous, empty, or unanswered response is option 3. Never re-ask.

**Option 1 — merge into `<base>`:**

- Worktree mode: `cd "$MAIN_ROOT"` first — `$merge-worktree` refuses to run when the cwd is inside a target worktree. It also requires the main checkout to be clean, and this skill is usually what dirtied it: `$create-worktree`, invoked in Phase 1, appends `.worktrees/` to `$MAIN_ROOT/.gitignore` without committing. On the first worktree run in a repo that had not already ignored `.worktrees/`, that one line makes the merge refuse. So before delegating, run `git -C "$MAIN_ROOT" status --porcelain`; if non-empty, list the files and ask once, defaulting to yes (matching `$merge-worktree`'s own auto-commit convention): "Commit them first? [Y/n]". On yes, commit exactly those files — `chore: ignore .worktrees/` when the `.gitignore` line is all there is. On no, report that `$merge-worktree` will refuse and stop without delegating. Then invoke `$merge-worktree` with `<NNN> <base>`. It merges, removes the worktree, and deletes the local branch. If it still refuses, report its refusal verbatim rather than working around it.
- Current checkout: `git switch <base>` if the base exists locally, otherwise `git switch -c <base> origin/<base>`. Then `git merge --no-ff -m "Merge ticket-NNN-<slug> into <base>" ticket-NNN-<slug>`.
- In backlog-loop mode, merge only the **last** branch of the run. Because each ticket forked from the previous HEAD, that branch already contains every earlier ticket's commits. Then delete every branch created during the run, oldest first.
- On conflict: `git merge --abort`, report which files conflicted, leave the branches intact, and stop. Do not attempt resolution.
- On success: `git branch -d <branch>` for each branch to delete. Use `-d`, not `-D` — after a `--no-ff` merge the safe delete succeeds unless the branch is checked out elsewhere — if the delete is refused, report the refusal rather than escalating to `-D`.
- Never push. Close the report with `git push` as the explicit next step.

**Option 2 — open a PR:** invoke `$commit-push-pr`. It pushes the branch and opens the PR. Stay on the branch. In backlog-loop mode this opens one PR for the final stacked branch. Note that `$commit-push-pr` opens the PR against the repository's default branch; if `<base>` is not that branch, retarget the PR afterwards or use option 1 instead.

**Option 3 — stay on the branch:** report each branch name, the base, and that `$commit-push-pr` or `$merge-worktree NNN [base]` can land the work later.

## Safety Rules

- If `docs/PRD.md`, the project's design source (`docs/DESIGN.md`, `docs/design/DESIGN.md`, or a folder named `design-system`), or the ticket tracker files are missing, stop and report the missing inputs.
- If a dependency is unresolved, do not implement a blocked ticket out of order.
- If unrelated user changes conflict with the ticket, stop and ask how to proceed instead of overwriting them.
- Merge, push, and branch deletion happen only per the user's explicit Phase 8 choice. Never force-push, and never delete or overwrite a remote branch.
- In worktree mode, do not switch the user's main checkout to another branch and do not delete the worktree except as part of an explicitly chosen Phase 8 option 1 — otherwise leave both alone so the user can inspect the work and run `$merge-worktree` deliberately.
