---
name: implement-ticket-linear
description: "Implement a Linear issue end to end on its own branch with code review, then offer to merge it, open a PR, commit only, or leave it. Source of truth is Linear (not docs/tickets/). Moves a Todo issue to In Progress before implementing, and reports the status before doing anything when the issue is in any other state. Optional `worktree` keyword runs inside an isolated git worktree. Triggers on: /implement-ticket-linear ENG-42, /implement-ticket-linear ENG-42 dev, /implement-ticket-linear https://linear.app/.../issue/ENG-42/..., implement Linear issue ENG-42, implement Linear ticket worktree"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a senior full-stack developer implementing a **Linear** issue. Follow this workflow precisely. Do not skip steps.

This skill is the Linear counterpart of `/implement-ticket`. It does **not** read or write `docs/tickets/*.md`. The issue body in Linear is the ticket.

A Linear issue id or URL is required (e.g. `ENG-42` or a `linear.app` issue URL). If no argument is provided, inform the user and stop.

## Portable interaction rules

This skill prompts the user at several points — when the working tree is dirty, when resuming without a discoverable base, when offering the as-built comment, and when landing the work. All of them follow these rules:

- Show every option with a stable number and a one-line description of what it does. A yes/no confirmation is the degenerate case: state the default explicitly (`[y/N]`) and treat anything but an explicit yes as that default.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites

1. **Linear MCP** must be available and authenticated in the host agent (official server: `https://mcp.linear.app/mcp`, documented at https://linear.app/docs/mcp).
2. If no Linear MCP tools are available, stop and tell the user to configure Linear MCP. Do **not** invent API-key, CLI, or browser workarounds in this skill.
3. Use Linear MCP **read** tools to fetch the issue and the team's workflow statuses (get / list / search by identifier, plus the status-listing tool). Exactly **two writes** are permitted and no others:
   - the automatic Todo → In Progress transition in Phase 2 (issue-saving tool, `state` field only), and
   - the opt-in as-built comment in Phase 8, posted only after the user explicitly confirms.

   **Do not** call create, delete, or assign tools, and do not touch any field on the issue other than `state` in that one transition.

## Argument grammar

Every invocation implements on a branch. The optional tokens choose where that branch lives and what it forks from:

| Invocation | Meaning |
| --- | --- |
| `<issue>` | New branch off the current HEAD, in the current checkout. |
| `<issue> <base>` | New branch off `origin/<base>` (e.g. `dev`), in the current checkout. |
| `<issue> worktree` | New branch off `origin/main`, inside an isolated worktree. |
| `<issue> worktree <base>` | New branch off `origin/<base>`, inside an isolated worktree. |

`<issue>` is either:

- A Linear identifier `TEAM-NUMBER` (e.g. `ENG-42`, `CKTK-7`) — case-insensitive; normalize the team key to uppercase.
- A Linear issue URL containing that identifier (e.g. `https://linear.app/acme/issue/ENG-42/add-export`).

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode (not `wt`, not `--worktree`). Any other trailing token is read as a base branch and **must resolve** — check `git rev-parse --verify --quiet origin/<token>` then `git rev-parse --verify --quiet <token>`. If neither resolves, stop with:

```
unrecognized argument '<token>' — did you mean 'worktree'?
(no branch named '<token>' found locally or on origin)
```

That resolution check is what protects against typos like `worktre` now that the base slot is open. In the unlikely case that a repository has a real branch named `worktree`, the keyword wins.

**Not accepted:** free-text titles alone, status flags, commit flags, multi-issue lists, empty args meaning “next assigned.”

## Phase 1: Parse Arguments & Resolve Handles

1. **Parse `$ARGUMENTS`.** Split on whitespace. Capture:
   - `issue_ref` (first token — required)
   - `use_worktree` (true iff a token is exactly `worktree`, case-insensitive)
   - `base_token` (the trailing non-`worktree` token after the issue ref, if any)
2. If there is no first token, stop: "A Linear issue id or URL is required (e.g. `ENG-42`)."
3. If a fourth token exists, stop with an unrecognized-arguments error.
4. If `base_token` is present, validate that it resolves as a branch, as described in the argument grammar above. If it does not, stop with the "did you mean 'worktree'?" error.
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
   - Team key or id — the identifier prefix (`ENG` in `ENG-42`) if the fetch does not return it outright. Steps 8–10 need it to list the team's statuses.
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
8. **Classify the current state by type, not by name.** Linear state *names* are workspace-configurable — "Todo" is only the default name for the `unstarted` state, and teams rename states and add their own — so a literal string match silently does nothing on a renamed workflow:
   - Call the status-listing tool for the issue's team (`list_issue_statuses` with `team` set to the captured team key or id). Each status comes back with a `type` — one of `triage`, `backlog`, `unstarted`, `started`, `completed`, `canceled` — plus a name, id, and position. Keep the whole list; step 10 reuses it.
   - Look the issue's current state up in that list to get `state_type`.
   - If the listing call fails, or the current state is somehow absent from it, fall back to literal names: `Todo` → `unstarted`; `Done` / `Completed` → `completed`; `Canceled` / `Cancelled` / `Duplicate` → `canceled`; anything else → unknown, which takes the "report and continue" path in step 10.

9. **Terminal states stop the run.** If `state_type` is `completed` or `canceled`, inform the user of the status and **stop** unless they explicitly asked to re-implement — in that case ask once before continuing. Do **not** write to Linear on this path in either case: reopening a closed issue is the user's decision, not a side effect of this skill, so a terminal issue never gets moved to In Progress even when the user opts to re-implement.

10. **Otherwise, gate on Todo — this is the last step before any branch is created or any code is written.**

    Before writing anything, confirm this run is actually going to proceed: if the relations captured in step 5 show an **open blocker**, stop and report here rather than waiting for Phase 5 to do it. A blocked issue must not be moved to In Progress for a run that Phase 5 would abort anyway.

    **If `state_type` is `unstarted` (the "Todo" case): move the issue to In Progress first.** Resolve the target status from the team's status list captured in step 8, in this order:

    a. a status whose name matches `In Progress` case-insensitively; else
    b. the `started`-type status with the lowest position (teams often have several — `In Progress`, `In Review` — and the lowest position is the one work enters first); else
    c. no `started`-type status exists → skip the write, report "team `<key>` has no in-progress status; leaving `<state_name>` unchanged", and continue to Phase 3.

    Write it with the issue-saving tool, passing the resolved status **id** rather than its name — names are not unique across teams, and an id cannot resolve to the wrong state: `save_issue` with `id: <issue_id>` and `state: <status id>`. Set no other field on the issue. Then report the transition in one line, e.g. `ENG-42: Todo → In Progress`.

    If the write fails (permission, transport, or validation error), do **not** stop the run. Report the error verbatim, continue to Phase 3, and carry the failure into the Phase 8 summary so a silently unmoved issue does not go unnoticed.

    **If `state_type` is anything else non-terminal — `backlog`, `triage`, an already-`started` state such as In Progress or In Review, or unknown — report the status and continue, writing nothing.** For example:

    ```
    ENG-42 is in "In Review" (not Todo) — leaving the Linear status unchanged.
    ```

    The report comes before Phase 3 creates a branch and before Phase 6 writes code, so the user learns the issue was not where they expected while nothing has happened yet. Then proceed normally — a non-Todo state is informational here, not a refusal. If the user wants a hard stop on some of these states instead, that is a per-state policy decision they should make explicitly; do not invent one.

    **If the run stops after a transition was written** — the dirty-tree decline in Phase 3, a detached HEAD, an unresolvable base — say so explicitly and note that `<issue_id>` is now In Progress, so the user can decide whether to move it back. Do **not** auto-revert: that would be a second write outside the two this skill is allowed, and it could clobber a state change made concurrently in Linear.

## Phase 3: Set Up the Working Directory and Branch

0. **Resolve `base`** — the branch Phase 9 will offer to merge into:
   - Worktree mode: `base_token` if present, otherwise `main`.
   - Current checkout with a `base_token`: that token.
   - Current checkout without one, when the current branch is **not** `linear-<issue_id>-<slug>`: the current branch, from `git rev-parse --abbrev-ref HEAD`. If that returns `HEAD` (detached), stop and ask the user to pass an explicit base branch — there is no merge target to record.
   - Current checkout without one, when the current branch already **is** `linear-<issue_id>-<slug>` (you are resuming): a branch cannot be its own base, and nothing on disk records what it forked from. Ask once, following the portable interaction rules, offering the plausible bases that actually exist locally or on `origin` (check `main`, `master`, `dev`, `develop`):

     ```
     Resuming on linear-<issue_id>-<slug>. I can't tell which branch it forked from.
     Which branch should Phase 9 offer to merge into?
       1  main
       2  dev
       3  other (name it)
     ```

     Use the answer as `base`. If the user declines to answer, record no base and mark Phase 9's option 1 unavailable rather than guessing — options 2, 3, and 4 need no base. Without this branch of the rule, `base` would be the issue branch itself and option 1 would merge it into itself: git reports "Already up to date" and exits 0, so the skill would claim a successful land while nothing reached the real base.
1. **If `use_worktree` is true:**
   - If the worktree path is already registered (`git worktree list --porcelain`), reuse it. Uncommitted changes are fine (resume) — note "reused existing worktree (with uncommitted changes)" in the final summary if dirty.
   - Otherwise create it inline (do **not** call `/create-worktree` — that skill requires `docs/tickets/`):
     a. `git fetch origin <base>` when possible; on failure continue with the local base and warn.
     b. Resolve base ref: prefer `origin/<base>`, else local `<base>`. If neither exists, stop.
     c. Ensure `$MAIN_ROOT/.gitignore` ignores `.worktrees/` (create or append the line if missing).
     d. If branch `linear-<issue_id>-<slug>` already exists locally, `git worktree add <path> <branch>`.
     e. Else `git worktree add <path> -b <branch> <base-ref>`.
   - Set `WORK_DIR = <worktree-path>`. The branch already exists on it — skip step 4.
2. **If `use_worktree` is false:** set `WORK_DIR = $MAIN_ROOT` (or the user's current `git rev-parse --show-toplevel` if they already invoked the skill from a worktree on purpose).
3. `cd "$WORK_DIR"` once via Bash so later shell commands (including those inside `/review-ticket`) run against `WORK_DIR`. For Read/Edit/Write tools that need absolute paths, prefix with `$WORK_DIR`.
4. **Create or reuse the issue branch** (current-checkout mode only — worktree mode got its branch in step 1). Never implement onto whatever branch happened to be checked out:
   - Already on `linear-<issue_id>-<slug>` → reuse it and report "resuming on `linear-<issue_id>-<slug>`".
   - The branch exists but is not checked out (`git rev-parse --verify --quiet linear-<issue_id>-<slug>` succeeds) → `git switch linear-<issue_id>-<slug>` and report "reusing existing branch". Do not rebase it onto anything.
   - Otherwise:
     a. Run `git status --porcelain`. If it is non-empty, list the files and ask once, defaulting to no:

        ```
        Working tree has N uncommitted file(s):
          <porcelain lines>

        These will be carried onto linear-<issue_id>-<slug> and may land in the issue commit.

        Continue? [y/N]
        ```

        Anything other than an explicit yes stops the skill before any branch is created.
     b. With a `base_token`: `git fetch origin <base>` (on failure, warn and continue), then `git switch -c linear-<issue_id>-<slug> origin/<base>`, falling back to local `<base>` if `origin/<base>` does not exist. If neither exists, stop.
     c. Without one: `git switch -c linear-<issue_id>-<slug>`.
     d. If the `git switch -c` fails because local changes would be overwritten, report git's error and stop. Do not force, stash, or discard.
5. Tell the user in one sentence where work is happening, e.g.:
   - "Implementing ENG-42 in `.worktrees/ENG-42-add-export` (branch `linear-ENG-42-add-export`, base `dev`)."
   - "Implementing ENG-42 on branch `linear-ENG-42-add-export` (base `dev`)."

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
- Current Linear state, and the Todo → In Progress transition if Phase 2 made one (or the failure if it tried and could not)
- What you are implementing (from Linear description)
- Acceptance criteria you will verify
- Files you expect to create or modify
- Edge cases / risks
- Any Linear relations that look like blockers (if blocked by an open issue, stop and report rather than implementing out of order — Phase 2 step 10 should already have caught this before any status write; re-check here in case a blocker surfaced only now)

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
5. **Linear writes this run** — state whichever applies, in one line:
   - "moved `<issue_id>` Todo → In Progress at the start of this run", or
   - "left `<issue_id>` in `<state_name>` (not Todo) — status unchanged", or
   - the status-write failure from Phase 2 step 10, if one occurred.

   Then note that **no completion status was set** — this skill never marks an issue Done — and that nothing is committed until the user picks an option in Phase 9.
6. **Next step for Linear status:** when the user is ready to mark the issue done (or move it to another state), run `/update-ticket-linear <issue_id>` (optionally with an explicit status such as `done`). That skill evaluates acceptance criteria and writes back to Linear. This skill only ever moves an issue *into* progress at the start of a run; it never sets a completion state, and does **not** offer to do so as part of landing — unlike the ticket file that `/implement-ticket` can update in-branch, marking work done is an external write and stays a separate, deliberate step.

### As-Built Comment (opt-in Linear write)

After presenting the summary, ask exactly once, as its own question: "Post this as-built summary as a comment on <issue_id>? (y/N)". Default is no.

- Only an explicit yes posts the comment; any other answer (no, silence, ambiguity) skips it without re-asking.
- On yes, post one comment via the Linear MCP comment-creation tool containing: deviations from the issue spec and why, key decisions made during implementation, and follow-ups/tech debt (write "None" where a bucket is empty).
- Besides the Phase 2 start transition, this is the only Linear write this skill may perform — never change assignee, labels, priority, or any other field, and never set a completion state.

### Worktree Note (only when `use_worktree` was true)

- **Worktree:** `.worktrees/<issue_id>-<slug>/` (branch `linear-<issue_id>-<slug>`, base `<base>`)
- **Inspect:** `cd .worktrees/<issue_id>-<slug>`
- **Land:** Phase 9 below offers to do this for you. `/merge-worktree` is for markdown `TICKET-NNN` worktrees and will **not** work for Linear branches, so Phase 9 performs the merge inline. If you pick option 4 now, `/merge-worktree-linear <issue_id>` lands it later as a standalone step.

If the worktree was reused with pre-existing uncommitted changes, mention that here too.

### Manual Testing Instructions

Step-by-step verification: prerequisites, commands, URLs, inputs, expected results, edge cases. If purely internal, say manual testing is N/A and what automated tests cover.

## Phase 9: Land the Work

Ask exactly once, after the Phase 8 summary and manual testing instructions, so the user decides with the full picture in front of them. Follow the portable interaction rules.

**Before any repo-level git operation in this phase, run `cd "$MAIN_ROOT"`.** The Bash cwd has been pinned to `$WORK_DIR` since the setup phase, and every option below acts on the repository as a whole — merging into the base, delegating to another skill, or removing the very worktree the cwd points at. Operating from inside a worktree here causes silent wrong answers, not loud errors.

Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, still show option 2 but mark it unavailable with the reason, and do not accept it. If no base was recorded — a resume where the user declined to name one — show option 1 as unavailable for that reason and do not accept it; options 2 and 3 (and 4 where present) need no base.

````
<issue_id> implemented on linear-<issue_id>-<slug> (base: <base>).
How do you want to land it?

  1  Merge into <base> locally  (commit → merge --no-ff → delete branch)
  2  Open a PR                  (invokes /commit-push-pr)
  3  Commit only                (stay on the branch, decide later)
  4  Nothing                    (leave changes uncommitted)  [default]
````

An ambiguous, empty, or unanswered response is option 4. Never re-ask. None of these options writes to Linear.

### Option 1 — merge into `<base>`

`/merge-worktree` only understands markdown `TICKET-NNN` worktrees, so both modes merge inline. (`/merge-worktree-linear` does understand Linear worktrees, but it is a standalone cleanup command that refuses to run from inside the worktree this phase is pinned to — so it stays the user's later choice, not a delegation target here.)

a. Invoke `/commit-ticket` via the `Skill` tool. In worktree mode this runs in the pinned worktree cwd, so it commits on the issue branch.
b. From `$MAIN_ROOT`, switch to the base — it may exist only on the remote: `git -C "$MAIN_ROOT" switch <base>` if it exists locally, otherwise `git -C "$MAIN_ROOT" switch -c <base> origin/<base>`.
c. `git -C "$MAIN_ROOT" merge --no-ff -m "Merge linear-<issue_id>-<slug> into <base>" linear-<issue_id>-<slug>`.
d. On conflict: `git -C "$MAIN_ROOT" merge --abort`, report which files conflicted, leave the branch and worktree intact, and stop. Do not attempt resolution.
e. On success, in worktree mode only: `git -C "$MAIN_ROOT" worktree remove .worktrees/<issue_id>-<slug>` — safe to run now that this phase's opening `cd "$MAIN_ROOT"` already moved the shell out of it; removing it while it was still the cwd would leave every later command failing with `fatal: Unable to read current working directory`.
f. On success: `git -C "$MAIN_ROOT" branch -d linear-<issue_id>-<slug>`. Use `-d`, not `-D` — after a `--no-ff` merge the safe delete succeeds unless the branch is checked out elsewhere — if the delete is refused, report the refusal rather than escalating to `-D`.
g. **Never push.** Close the report with `git push` as the explicit next step.

### Option 2 — open a PR

Invoke `/commit-push-pr` via the `Skill` tool. It commits, pushes the issue branch, and opens the PR. Stay on the branch afterward; leave the worktree in place. Note that `/commit-push-pr` opens the PR against the repository's default branch; if `<base>` is not that branch, retarget the PR afterwards or use option 1 instead.

### Option 3 — commit only

Invoke `/commit-ticket` via the `Skill` tool and stay on the branch.

### Option 4 — nothing

Leave the changes uncommitted. Report the branch name and that `/commit-push-pr` or a manual merge can land it later.

## Safety Rules

- **Exactly two Linear writes are permitted:** the Todo → In Progress transition in Phase 2 step 10 (automatic, only from an `unstarted` state, `state` field only), and the opt-in as-built comment in Phase 8 (only after explicit user confirmation). Never change assignee, labels, priority, project, or any other field; never set a completion or canceled state; never reopen a terminal issue. Nothing in Phase 9 writes to Linear.
- No commit, merge, push, or branch deletion happens before Phase 9, and then only per the user's explicit choice. Never force-push, and never delete or overwrite a remote branch. Never invoke `/update-ticket` or `/update-ticket-linear` — setting a *completion* status stays a separate, deliberate step.
- Do not read or write `docs/tickets/` as the ticket source (optional project context elsewhere is fine).
- If unrelated dirty changes in `WORK_DIR` conflict with the issue, stop and ask instead of overwriting.
- In worktree mode, do not switch the user's main checkout branch or remove the worktree except as part of an explicitly chosen Phase 9 option 1.
- If Linear MCP is missing or the issue cannot be resolved uniquely, stop — do not invent requirements.
