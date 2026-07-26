---
name: "implement-ticket-linear"
description: "Use when the user explicitly asks to implement a Linear issue (not docs/tickets markdown). The issue is implemented on its own branch, and the run ends by offering to merge it, open a PR, commit only, or leave it. A Todo issue is moved to In Progress before implementation starts; any other non-terminal status is reported first and then implemented anyway. Optionally pass a base branch, or `worktree` (with an optional base branch) to run inside an isolated git worktree. Prefer explicit invocation with $implement-ticket-linear. Requires Linear MCP."
---

# Implement a Linear Issue

Implement one Linear issue end to end: fetch it via Linear MCP, write the code, validate, and review. Treat this as an explicit workflow skill because it writes code and runs checks.

**This skill does not use `docs/tickets/`.** The Linear issue is the source of truth. It mutates Linear in exactly two places: the automatic Todo → In Progress transition in Phase 2, and a single opt-in as-built comment in Phase 7 — never assignee or label changes, and never a completion state. It commits git changes only when the user picks a landing option in Phase 8.

If the user included an issue id or URL after `$implement-ticket-linear`, implement that issue. Empty args are invalid — always require an id or URL.

## Portable interaction rules

This skill prompts the user at several points — when the working tree is dirty, when resuming without a discoverable base, when offering the as-built comment, and when landing the work. All of them follow these rules:

- Show every option with a stable number and a one-line description of what it does. A yes/no confirmation is the degenerate case: state the default explicitly (`[y/N]`) and treat anything but an explicit yes as that default.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name, using `$skill-name` syntax when suggesting a command.

## Prerequisites

1. Linear MCP must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp).
2. If Linear MCP tools are missing, stop with a short setup hint. Do not invent API-key or CLI fallbacks.
3. Use **read** Linear tools to fetch the issue and the team's workflow statuses (get/list/search issue, plus `list_issue_statuses`). Exactly two writes are permitted: the automatic Todo → In Progress transition in Phase 2 (`save_issue`, `state` field only) and the opt-in as-built comment in Phase 7, posted only after explicit user confirmation. Never call create/delete/assign, and never touch any other field on the issue.

## Argument grammar

Every invocation implements on a branch:

| Invocation | Meaning |
| --- | --- |
| `<issue>` | New branch off the current HEAD, in the current checkout. |
| `<issue> <base>` | New branch off `origin/<base>`, in the current checkout. |
| `<issue> worktree` | New branch off `origin/main`, inside an isolated worktree. |
| `<issue> worktree <base>` | New branch off `origin/<base>`, inside an isolated worktree. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Normalize team keys to uppercase. The `worktree` keyword is case-insensitive; only that exact word triggers worktree mode. Any other trailing token is read as a base branch and must resolve — check `git rev-parse --verify --quiet origin/<token>` then `git rev-parse --verify --quiet <token>`. If neither resolves, stop with "unrecognized argument '<token>' — did you mean 'worktree'? (no branch named '<token>' found locally or on origin)". A fourth token is an error.

Not accepted: title-only search, status flags, commit flags, multi-issue batches, empty “next assigned” mode.

## Phase 1: Parse & Resolve

1. Parse args: `issue_ref` (required), `use_worktree`, `base_token` (the trailing non-`worktree` token, if any — validate it resolves as a branch per the argument grammar).
2. Normalize to `issue_id`:
   - `TEAM-NUM` pattern → uppercase team key
   - URL → extract first `TEAM-NUM` path segment; fail if none
3. Resolve main repo root:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```

## Phase 2: Fetch Linear Issue

1. Fetch by `issue_id` via Linear MCP. Exact match only; stop if missing or ambiguous.
2. Capture title, description, state, team key (the identifier prefix, e.g. `ENG`), labels/project/priority, relations, and any acceptance criteria in the body.
3. Derive `slug` from the title: lowercase, non-alphanumerics → `-`, collapse, trim, ~40 chars. Fallback slug: `issue`.
4. Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`. Branch: `linear-<issue_id>-<slug>`.
5. **Classify the state by type, not name.** Linear state names are workspace-configurable ("Todo" is only the default name for `unstarted`), so a literal match silently no-ops on a renamed workflow. Call `list_issue_statuses` for the team — each status returns a `type` (`triage` / `backlog` / `unstarted` / `started` / `completed` / `canceled`), name, id, and position — and look up the current state to get `state_type`. Keep the list; step 7 reuses it. If the call fails or the state is absent, fall back to names: `Todo` → `unstarted`, `Done`/`Completed` → `completed`, `Canceled`/`Cancelled`/`Duplicate` → `canceled`, anything else → unknown (takes the report-and-continue path).
6. **Terminal (`completed` / `canceled`):** report and stop unless the user explicitly asked to re-implement (then confirm once). Do not write to Linear on this path either way — reopening a closed issue is the user's decision, so a terminal issue is never moved to In Progress.
7. **Otherwise gate on Todo, before any branch exists or any code is written.** Before writing anything, confirm the run will proceed: if the captured relations show an **open blocker**, stop and report here rather than waiting for Phase 5 — a blocked issue must not be moved to In Progress for a run that Phase 5 would abort anyway.
   - **`state_type == unstarted`** → move it to In Progress first. Resolve the target from the step-5 list: a name matching `In Progress` case-insensitively, else the lowest-position `started` status, else none exists → skip the write, report "team `<key>` has no in-progress status; leaving `<state_name>` unchanged", and continue. Write with `save_issue` passing `id: <issue_id>` and `state: <status id>` — the **id**, not the name, since names are not unique across teams. No other field. Report one line: `ENG-42: Todo → In Progress`. If the write fails, do **not** stop: report the error verbatim, continue, and carry it into the Phase 7 summary.
   - **Any other non-terminal state** (`backlog`, `triage`, an already-`started` state like In Progress or In Review, or unknown) → report it and continue, writing nothing: `ENG-42 is in "In Review" (not Todo) — leaving the Linear status unchanged.` The report lands before Phase 3 branches and Phase 5 codes, so the user sees the unexpected state while nothing has happened. Then proceed normally — a non-Todo state is informational, not a refusal.
   - **If the run stops after a transition was written** (dirty-tree decline in Phase 3, detached HEAD, unresolvable base): say so and note that `<issue_id>` is now In Progress so the user can decide whether to move it back. Do **not** auto-revert — that is a third write, and it could clobber a concurrent Linear change.

## Phase 3: Working Directory and Branch

0. Resolve `base` — the branch Phase 8 will offer to merge into. Worktree mode: `base_token` if present, else `main`. Current checkout: `base_token` if present, else the current branch from `git rev-parse --abbrev-ref HEAD` — but if that current branch already **is** `linear-<issue_id>-<slug>` (you are resuming), a branch cannot be its own base and nothing on disk records what it forked from: ask once, per the portable interaction rules, offering the plausible bases that exist locally or on `origin`, and if the user declines, record no base and mark Phase 8's option 1 unavailable rather than guessing. Without this rule option 1 would merge the branch into itself — git reports "Already up to date" and exits 0, so the skill would claim a successful land while nothing reached the real base. If `git rev-parse --abbrev-ref HEAD` returns `HEAD` (detached), stop and ask for an explicit base branch.
1. If `use_worktree`:
   - Reuse an existing registered worktree at the path (dirty state is OK; note it later).
   - Else create inline — do **not** call `$create-worktree` (it requires markdown tickets):
     - Fetch `origin/<base>` when possible
     - Ensure `.worktrees/` is in `$MAIN_ROOT/.gitignore`
     - `git worktree add` with new or existing `linear-…` branch from the resolved base ref
   - `WORK_DIR =` worktree path. The branch already exists on it — skip step 4.
2. Else `WORK_DIR = $MAIN_ROOT` (or current toplevel if already on a purposeful worktree).
3. `cd "$WORK_DIR"` once. Prefix absolute file tools with `$WORK_DIR`.
4. Create or reuse `linear-<issue_id>-<slug>` (current checkout only). Never implement onto whatever branch happened to be checked out:
   - Already on it → reuse and report "resuming".
   - Exists but not checked out → `git switch linear-<issue_id>-<slug>`, report the reuse, do not rebase.
   - Otherwise: if `git status --porcelain` is non-empty, list the files, warn they will be carried onto the branch and may land in the commit, and ask "Continue? [y/N]" — anything but an explicit yes stops before the branch is created. Then `git switch -c linear-<issue_id>-<slug> origin/<base>` when a `base_token` was given (fetch first; fall back to local `<base>`; stop if neither ref exists), otherwise `git switch -c linear-<issue_id>-<slug>`. If the switch fails because local changes would be overwritten, report git's error and stop.
5. State in one sentence which branch you are on and where work is happening.

## Phase 4: Project Context (soft)

1. Read `$WORK_DIR/docs/PRD.md` if present.
2. Read design source if present (`docs/DESIGN.md`, `docs/design/DESIGN.md`, or a `design-system/` folder).
3. Missing PRD/design is non-fatal — Linear body is primary.
4. Skim `AGENTS.md` / `CLAUDE.md` / package manifests when present.

## Phase 5: Implement

1. State plan: issue id/title, current Linear state (including the Todo → In Progress transition if Phase 2 made one, or the failure if it tried and could not), files to touch, risks, acceptance criteria. If Linear shows an open blocker relation, stop and report.
2. Implement fully under `$WORK_DIR` against the issue and design context.
3. Follow project conventions; add tests when the repo has a suite or the issue implies testable behavior.

## Phase 6: Validate

1. Run lint, type-check, test, and build commands for the repo (cwd is `$WORK_DIR`).
2. Fix regressions introduced by the work.
3. Review pass against `$review-ticket` guidelines:
   - Prefer invoking `$review-ticket <issue_id>` when available — its Linear mode fetches the issue and checks acceptance-criteria alignment
   - Or read `../review-ticket/references/review-guidelines.md` and review only the ticket diff
   - Treat Linear title + description + AC as the requirements
4. Fix findings and re-check until build is clean and no P0/P1 remain.

## Phase 7: Summary (nothing committed yet; Linear write only by opt-in)

Stop after a clear summary:

1. Issue id, title, what changed
2. Deviations and follow-ups
3. **Linear writes this run**, in one line — whichever applies: "moved `<issue_id>` Todo → In Progress at the start of this run", or "left `<issue_id>` in `<state_name>` (not Todo) — status unchanged", or the Phase 2 status-write failure if one occurred. Then note that **no completion status was set** and **nothing is committed** until the user picks an option in Phase 8
4. Manual testing steps
5. **Next step for Linear status:** when ready to mark the issue done (or move it), run `$update-ticket-linear <issue_id>` (optionally with an explicit status such as `done`). That skill evaluates acceptance criteria and writes back to Linear. This skill only ever moves an issue *into* progress at the start of a run; it never sets a completion state.
6. **As-built comment (opt-in):** ask exactly once — "Post this as-built summary as a comment on <issue_id>? (y/N)", default no. Only an explicit yes posts one comment (deviations from spec and why, key decisions, follow-ups/tech debt; "None" where empty) via the Linear MCP comment tool. Besides the Phase 2 start transition, never change any other Linear field.
7. If worktree mode: path, branch, and base. Note that `$merge-worktree` only understands markdown `TICKET-NNN` worktrees, so Phase 8 merges inline; `$merge-worktree-linear <issue_id>` is the standalone way to land it later.

## Phase 8: Land the Work

Ask exactly once, after the Phase 7 summary, following the portable interaction rules.

**Before any repo-level git operation in this phase, run `cd "$MAIN_ROOT"`.** The Bash cwd has been pinned to `$WORK_DIR` since the setup phase, and every option below acts on the repository as a whole — merging into the base, delegating to another skill, or removing the very worktree the cwd points at. Operating from inside a worktree here causes silent wrong answers, not loud errors.

Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, show option 2 as unavailable with the reason and do not accept it. If no base was recorded — a resume where the user declined to name one — show option 1 as unavailable for that reason and do not accept it; options 2 and 3 (and 4 where present) need no base.

````
<issue_id> implemented on linear-<issue_id>-<slug> (base: <base>).
How do you want to land it?

  1  Merge into <base> locally  (commit → merge --no-ff → delete branch)
  2  Open a PR                  ($commit-push-pr)
  3  Commit only                (stay on the branch)
  4  Nothing                    (leave changes uncommitted)  [default]
````

An ambiguous, empty, or unanswered response is option 4. Never re-ask. None of these options writes to Linear.

**Option 1 — merge into `<base>`.** Both modes merge inline: `$merge-worktree` only understands markdown tickets, and `$merge-worktree-linear` refuses a dirty main checkout — exactly the state current-checkout mode is in before the commit:

- Invoke `$commit-ticket` (in worktree mode the pinned cwd puts the commit on the issue branch).
- From `$MAIN_ROOT`: `git -C "$MAIN_ROOT" switch <base>` if the base exists locally, otherwise `git -C "$MAIN_ROOT" switch -c <base> origin/<base>`.
- `git -C "$MAIN_ROOT" merge --no-ff -m "Merge linear-<issue_id>-<slug> into <base>" linear-<issue_id>-<slug>`.
- On conflict: `git -C "$MAIN_ROOT" merge --abort`, report the conflicted files, leave branch and worktree intact, stop.
- On success: in worktree mode `git -C "$MAIN_ROOT" worktree remove .worktrees/<issue_id>-<slug>` — safe now that the cwd already returned to `$MAIN_ROOT` above; removing it beforehand would leave every later command failing with `fatal: Unable to read current working directory`. Then `git -C "$MAIN_ROOT" branch -d linear-<issue_id>-<slug>`. Use `-d`, not `-D` — after a `--no-ff` merge the safe delete succeeds unless the branch is checked out elsewhere; if the delete is refused, report the refusal rather than escalating to `-D`.
- Never push. Close with `git push` as the next step.

**Option 2 — open a PR:** invoke `$commit-push-pr`; stay on the branch and leave the worktree in place. Note that `$commit-push-pr` opens the PR against the repository's default branch; if `<base>` is not that branch, retarget the PR afterwards or use option 1 instead.

**Option 3 — commit only:** invoke `$commit-ticket`; stay on the branch.

**Option 4 — nothing:** leave the changes uncommitted; report the branch name and that `$commit-push-pr` or a manual merge can land it later.

## Safety Rules

- Exactly two Linear writes are permitted: the Todo → In Progress transition in Phase 2 step 7 (automatic, only from an `unstarted` state, `state` field only) and the opt-in as-built comment in Phase 7 after explicit user confirmation. Never change assignee, labels, priority, project, or any other field; never set a completion or canceled state; never reopen a terminal issue. Nothing in Phase 8 writes to Linear.
- No commit, merge, push, or branch deletion before Phase 8, and then only per the user's explicit choice. Never force-push, and never delete or overwrite a remote branch. Never call `$update-ticket` or `$update-ticket-linear` — *completion* status belongs in a separate `$update-ticket-linear` invocation after implementation.
- Do not use `docs/tickets/` as the ticket source.
- If dirty unrelated changes conflict with the issue, stop and ask.
- In worktree mode, do not switch the main checkout branch or delete the worktree except as part of an explicitly chosen Phase 8 option 1.
- Missing Linear MCP or unresolvable issue → stop.
