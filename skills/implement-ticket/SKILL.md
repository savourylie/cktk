---
name: implement-ticket
description: "Implement a specific ticket from the ticket tracker on its own branch with code review, then offer to merge it, open a PR, commit only, or leave it. Optional `worktree` keyword runs the implementation inside an isolated git worktree (auto-created via /create-worktree if it doesn't exist), so multiple tickets can be worked in parallel. Triggers on: /implement-ticket TICKET-NNN, /implement-ticket NNN dev, /implement-ticket NNN worktree, /implement-ticket NNN worktree dev, implement TICKET-NNN, implement ticket NNN, implement ticket on a branch, implement ticket in a worktree, work on ticket in parallel"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a senior full-stack developer implementing a ticket. Follow this workflow precisely. Do not skip steps.

A ticket ID is required (e.g., `TICKET-001`, `001`, or `1`). If no argument is provided, inform the user that a ticket ID is required and stop.

## Portable interaction rules

This skill prompts the user twice — once if the working tree is dirty (Phase 1), and once to land the work (Phase 7). Both follow these rules:

- Show every option with a stable number and a one-line description of what it does.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Argument grammar

Every invocation implements on a branch. The optional tokens choose where that branch lives and what it forks from:

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | New branch off the current HEAD, in the current checkout. |
| `<ticket> <base>` | New branch off `origin/<base>` (e.g. `dev`), in the current checkout. |
| `<ticket> worktree` | New branch off `origin/main`, inside an isolated worktree. |
| `<ticket> worktree <base>` | New branch off `origin/<base>`, inside an isolated worktree. |

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode (not `wt`, not `--worktree`). Any other trailing token is read as a base branch and **must resolve** — check `git rev-parse --verify --quiet origin/<token>` then `git rev-parse --verify --quiet <token>`. If neither resolves, stop with:

```
unrecognized argument '<token>' — did you mean 'worktree'?
(no branch named '<token>' found locally or on origin)
```

That resolution check is what protects against typos like `worktre` now that the base slot is open. In the unlikely case that a repository has a real branch named `worktree`, the keyword wins. A fourth token is an error.

## Phase 1: Set Up the Working Directory and Branch

This phase runs whether or not worktree mode is requested, because both modes need the same things (main repo root, ticket file, slug, branch name, base).

1. **Parse `$ARGUMENTS`.** Capture:
   - `ticket_id`, normalized to a 3-digit zero-padded `NNN` (so `7`, `007`, `#7`, `TICKET-007` all become `007`).
   - `use_worktree` (bool — true iff a token is exactly `worktree`, case-insensitive).
   - `base_token` (the trailing non-ticket, non-`worktree` token, if any). Validate it as described in the argument grammar above.
2. **Resolve the main repo root** so this skill behaves the same whether invoked from the main checkout or another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
3. **Resolve the ticket file and slug.** Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`.
   - No match → report `TICKET-NNN not found in docs/tickets/` and stop.
   - Multiple matches → report the ambiguity and stop.
   - Slug = the filename minus the `NNN-` prefix and the `.md` suffix.
4. **Compute the handles.** Both modes use the same branch name, so `/update-ticket`, `/merge-worktree`, and `/quiz-ticket` recognize the work either way:
   - Branch name: `ticket-NNN-<slug>`
   - Worktree path: `$MAIN_ROOT/.worktrees/NNN-<slug>` (worktree mode only)
5. **Resolve `base`** — the branch Phase 7 will offer to merge into:
   - Worktree mode: `base_token` if present, otherwise `main`.
   - Current checkout with a `base_token`: that token.
   - Current checkout without one, when the current branch is **not** `ticket-NNN-<slug>`: the current branch, from `git rev-parse --abbrev-ref HEAD`. If that returns `HEAD` (detached), stop and ask the user to pass an explicit base branch — there is no merge target to record.
   - Current checkout without one, when the current branch already **is** `ticket-NNN-<slug>` (you are resuming): a branch cannot be its own base, and nothing on disk records what it forked from. Ask once, following the portable interaction rules, offering the plausible bases that actually exist locally or on `origin` (check `main`, `master`, `dev`, `develop`):

     ```
     Resuming on ticket-NNN-<slug>. I can't tell which branch it forked from.
     Which branch should Phase 7 offer to merge into?
       1  main
       2  dev
       3  other (name it)
     ```

     Use the answer as `base`. If the user declines to answer, record no base and mark Phase 7's option 1 unavailable rather than guessing — options 2, 3, and 4 need no base. Without this branch of the rule, `base` would be the ticket branch itself and option 1 would merge it into itself: git reports "Already up to date" and exits 0, so the skill would claim a successful land while nothing reached the real base.
6. **If `use_worktree` is true:**
   - If the worktree path is already registered (check `git worktree list --porcelain`), reuse it. If `git -C <worktree-path> status --porcelain` is non-empty, that's fine — the user is resuming work — but note "reused existing worktree (with uncommitted changes)" in the final summary so they're not surprised.
   - Otherwise invoke `/create-worktree` via the `Skill` tool. This is the same Skill-tool pattern this skill already uses to invoke `/review-ticket` later, so it's not a new mechanism:
     ```
     skill: "create-worktree"
     args: "<NNN> <base>"   # drop <base> if base is main
     ```
   - Set `WORK_DIR = <worktree-path>`. The branch already exists on it — skip step 9.
7. **If `use_worktree` is false:** set `WORK_DIR = $MAIN_ROOT` (or the user's current `git rev-parse --show-toplevel` if they invoked the skill from a worktree on purpose — they may already have set up the environment they want).
8. **Pin the working directory.** Run `cd "$WORK_DIR"` as a single Bash command. The Bash tool's working directory persists between commands within this session, so every later Bash call — including those inside `/review-ticket` when invoked via the `Skill` tool — will see `WORK_DIR` as cwd. For Read/Edit/Write tools (which require absolute paths), prefix project paths with `$WORK_DIR` (e.g. `$WORK_DIR/docs/PRD.md`).
9. **Create or reuse the ticket branch** (current-checkout mode only — worktree mode got its branch in step 6). Never implement onto whatever branch happened to be checked out:
   - Already on `ticket-NNN-<slug>` → reuse it and report "resuming on `ticket-NNN-<slug>`".
   - The branch exists but is not checked out (`git rev-parse --verify --quiet ticket-NNN-<slug>` succeeds) → `git switch ticket-NNN-<slug>` and report "reusing existing branch". Do not rebase it onto anything.
   - Otherwise:
     a. Run `git status --porcelain`. If it is non-empty, list the files and ask once, defaulting to no:

        ```
        Working tree has N uncommitted file(s):
          <porcelain lines>

        These will be carried onto ticket-NNN-<slug> and may land in the ticket commit.

        Continue? [y/N]
        ```

        Anything other than an explicit yes stops the skill before any branch is created. This prompt exists because `git switch -c` carries uncommitted changes onto the new branch, where Phase 7 would otherwise sweep unrelated work into the ticket commit.
     b. With a `base_token`: `git fetch origin <base>` (on failure, warn that the base may be stale and continue), then `git switch -c ticket-NNN-<slug> origin/<base>`, falling back to local `<base>` if `origin/<base>` does not exist. If neither exists, stop.
     c. Without one: `git switch -c ticket-NNN-<slug>`.
     d. If the `git switch -c` fails because local changes would be overwritten by the target base, report git's error and stop. Do not force, stash, or discard.
10. **Tell the user, in one sentence, where the work is happening** before doing any reading, e.g.:
   - "Implementing TICKET-007 in `.worktrees/007-add-export` (branch `ticket-007-add-export`, base `dev`)."
   - "Implementing TICKET-007 on branch `ticket-007-add-export` (base `dev`)."

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

This is the only ticket-file edit this skill makes on its own — never change `## Status`, acceptance-criteria checkboxes, or `INDEX.md` directly. Those are changed only by `/update-ticket`, and only when the user opts into the status follow-up in Phase 7. Leave the as-built edit uncommitted alongside the code changes so it lands in whichever commit Phase 7 produces. In worktree mode the append happens in the worktree's copy of `docs/tickets/` and merges back via `/merge-worktree`.

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
- **Land:** Phase 7 below offers to do this for you. If you decline, `/merge-worktree NNN <base>` will merge the branch back, remove the worktree, and delete the local branch whenever you're ready.

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

## Phase 7: Land the Work

Ask exactly once, after the summary and manual testing instructions above, so the user decides with the full picture in front of them. Follow the portable interaction rules.

Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, still show option 2 but mark it unavailable with the reason, and do not accept it.

````
TICKET-NNN implemented on ticket-NNN-<slug> (base: <base>).
How do you want to land it?

  1  Merge into <base> locally  (commit → merge --no-ff → delete branch)
  2  Open a PR                  (invokes /commit-push-pr)
  3  Commit only                (stay on the branch, decide later)
  4  Nothing                    (leave changes uncommitted)  [default]
````

An ambiguous, empty, or unanswered response is option 4. Never re-ask.

### Status follow-up (options 1, 2, and 3 only)

Ask one follow-up, defaulting to no:

````
Also mark TICKET-NNN done? [y/N]
````

On an explicit yes, invoke `/update-ticket` via the `Skill` tool with args `NNN done` **before** the code commit below. It stages only `docs/tickets/`, so its commit stays separate from the code commit, and both land on the ticket branch — inside the merge for option 1, inside the PR for option 2. Anything other than an explicit yes skips it without re-asking.

### Option 1 — merge into `<base>`

- **Worktree mode:** invoke `/merge-worktree` via the `Skill` tool with args `NNN <base>`. It auto-commits the implementation, merges, removes the worktree, and deletes the local branch — no separate commit step is needed here.
- **Current checkout:**
  a. Invoke `/commit-ticket` via the `Skill` tool.
  b. Switch to the base — it may exist only on the remote: `git switch <base>` if it exists locally, otherwise `git switch -c <base> origin/<base>`.
  c. `git merge --no-ff -m "Merge ticket-NNN-<slug> into <base>" ticket-NNN-<slug>`.
  d. On conflict: `git merge --abort`, report which files conflicted, leave the branch intact, and stop. Do not attempt resolution.
  e. On success: `git branch -d ticket-NNN-<slug>`. Use `-d`, not `-D` — after a `--no-ff` merge the safe delete always succeeds, so a refusal is information worth surfacing rather than overriding.
- **Never push.** Close the report with `git push` as the explicit next step.

### Option 2 — open a PR

Invoke `/commit-push-pr` via the `Skill` tool. It commits, pushes the ticket branch, and opens the PR. Stay on the branch afterward. In worktree mode it runs in the pinned worktree cwd, so it pushes the worktree's branch; a later `/merge-worktree NNN` will detect the already-merged branch and only clean up.

### Option 3 — commit only

Invoke `/commit-ticket` via the `Skill` tool and stay on the branch.

### Option 4 — nothing

Leave the changes uncommitted. Report the branch name and how to land later: `/commit-push-pr`, or `/merge-worktree NNN <base>` in worktree mode.

## Safety Rules

- No commit, merge, push, or branch deletion happens before Phase 7, and then only per the user's explicit choice. Never force-push, and never delete or overwrite a remote branch.
- Appending `## As-Built Notes` to the ticket file (Phase 6) is the one ticket-file edit this skill makes on its own. `## Status` and acceptance-criteria checkboxes are only ever changed by `/update-ticket`, and only when the user opts into the status follow-up.
- In worktree mode, do not switch the user's main checkout branch yourself and do not delete the worktree — option 1 delegates both to `/merge-worktree`.
- If unrelated dirty changes conflict with the ticket, stop and ask instead of overwriting.
