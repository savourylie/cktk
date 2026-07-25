# Always-Branch and Landing Step for the Implement Twins — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `implement-ticket` and `implement-ticket-linear` create a branch on every invocation, and end by offering to merge the work, open a PR, commit only, or do nothing.

**Architecture:** Four SKILL.md documents change — the canonical Claude pair under `skills/` and the deliberately-divergent Codex pair under `.agents/skills/`. The Claude pair never commits before the new landing prompt; the Codex pair already commits and updates status itself, so its menu is shorter. A new `validate_implement_contract` in `scripts/check-codex-skills.sh` locks in the portable-interaction wording across all four. `.agent/skills/` is symlinks — nothing to do there.

**Tech Stack:** Markdown skill documents, Bash validator (`scripts/check-codex-skills.sh`), Ruby+YAML frontmatter checks already present in that script.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-25-implement-twins-branch-and-land-design.md`. Every task's requirements implicitly include it.
- Branch names are unchanged from what worktree mode already produces: `ticket-NNN-<slug>` (docs twin), `linear-<issue_id>-<slug>` (Linear twin). No other skill may need a new pattern to recognize them.
- **Line numbers in every `Files:` block refer to the file as it stands before that task begins.** Earlier steps within a task change the line count, so the quoted find-text is always the authority — locate edits by matching text, not by seeking a line number.
- Per `AGENTS.md`: the Claude tree (`skills/`) and Codex tree (`.agents/skills/`) are separate documents with host-native instructions. Never copy prose between them verbatim — the Codex copies are terser and use `$skill-name` invocation syntax.
- No SKILL.md may contain the literal string `AskUserQuestion` (the validator forbids it — prompts must be host-neutral).
- Every one of the four SKILL.md documents must contain the literals `Portable interaction` and `Never assume an option limit`.
- Option 1 (merge) never pushes and never touches a remote branch. `git branch -d`, never `-D`.
- The Linear twins never write Linear status; their only Linear write remains the opt-in as-built comment.
- Acceptance gate for every task: `./scripts/check-codex-skills.sh` exits 0.

---

### Task 1: Claude `implement-ticket` — branch phase and landing phase

**Files:**
- Modify: `skills/implement-ticket/SKILL.md` (frontmatter line 3; argument grammar lines 13-23; Phase 1 lines 25-56; Worktree Note line 149; closing paragraph line 164)

**Interfaces:**
- Produces: the canonical `## Portable interaction rules` block, the `## Phase 7: Land the Work` menu, and the four-option landing semantics. Tasks 2-4 restate adapted versions of these; Task 5 asserts two literals from the portable-interaction block.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" skills/implement-ticket/SKILL.md   # expect 0
grep -c "Land the Work" skills/implement-ticket/SKILL.md          # expect 0
grep -n "Do NOT commit changes" skills/implement-ticket/SKILL.md  # expect line 164
```

Expected: first two print `0`, the third prints a match on line 164.

- [ ] **Step 2: Update the frontmatter description**

Find (line 3):

```
description: "Implement a specific ticket from the ticket tracker with code review. Optional `worktree` keyword runs the implementation inside an isolated git worktree (auto-created via /create-worktree if it doesn't exist), so multiple tickets can be worked in parallel without juggling branches. Triggers on: /implement-ticket TICKET-NNN, /implement-ticket NNN worktree, /implement-ticket NNN worktree dev, implement TICKET-NNN, implement ticket NNN, implement ticket in a worktree, work on ticket in parallel"
```

Replace with:

```
description: "Implement a specific ticket from the ticket tracker on its own branch with code review, then offer to merge it, open a PR, commit only, or leave it. Optional `worktree` keyword runs the implementation inside an isolated git worktree (auto-created via /create-worktree if it doesn't exist), so multiple tickets can be worked in parallel. Triggers on: /implement-ticket TICKET-NNN, /implement-ticket NNN dev, /implement-ticket NNN worktree, /implement-ticket NNN worktree dev, implement TICKET-NNN, implement ticket NNN, implement ticket on a branch, implement ticket in a worktree, work on ticket in parallel"
```

- [ ] **Step 3: Insert the portable interaction rules block**

Find (lines 9-11, the intro before `## Argument grammar`):

```
You are a senior full-stack developer implementing a ticket. Follow this workflow precisely. Do not skip steps.

A ticket ID is required (e.g., `TICKET-001`, `001`, or `1`). If no argument is provided, inform the user that a ticket ID is required and stop.
```

Replace with:

````
You are a senior full-stack developer implementing a ticket. Follow this workflow precisely. Do not skip steps.

A ticket ID is required (e.g., `TICKET-001`, `001`, or `1`). If no argument is provided, inform the user that a ticket ID is required and stop.

## Portable interaction rules

This skill prompts the user twice — once if the working tree is dirty (Phase 1), and once to land the work (Phase 7). Both follow these rules:

- Show every option with a stable number and a one-line description of what it does.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.
````

- [ ] **Step 4: Replace the argument grammar**

Find (lines 13-23):

````
## Argument grammar

The skill accepts the existing single-arg form plus an optional `worktree` flag:

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Implement in the current checkout (default). |
| `<ticket> worktree` | Implement inside an isolated worktree off `origin/main`. |
| `<ticket> worktree <base>` | Implement inside a worktree off `origin/<base>` (e.g. `dev`). |

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode (not `wt`, not `--worktree`). A second token that is *not* `worktree` is a typo — stop and tell the user "unrecognized argument; pass `worktree` to use a worktree."
````

Replace with:

````
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
````

- [ ] **Step 5: Rewrite Phase 1 to resolve the base and create the branch**

Find (lines 25-56, the whole of Phase 1):

````
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
````

Replace with:

````
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
````

- [ ] **Step 6: Point the Worktree Note at the new landing phase**

Find (line 149):

```
- **Land:** `/merge-worktree NNN <base>` will merge the branch back, remove the worktree, and delete the local branch.
```

Replace with:

```
- **Land:** Phase 7 below offers to do this for you. If you decline, `/merge-worktree NNN <base>` will merge the branch back, remove the worktree, and delete the local branch whenever you're ready.
```

- [ ] **Step 7: Replace the closing "do not commit" paragraph with Phase 7 and Safety Rules**

Find (line 164, the final paragraph of the file):

```
**Do NOT commit changes, update ticket status, or invoke the `/update-ticket`, `/commit-ticket`, or `/commit-push-pr` skills.** The user will handle those steps separately. Appending `## As-Built Notes` to the ticket file (Phase 6) is the one intended ticket-file edit; status and checkboxes stay untouched. (In worktree mode the natural next step after manual testing is `/merge-worktree NNN <base>`.)
```

Replace with:

`````
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
`````

- [ ] **Step 8: Verify the edits landed (green)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" skills/implement-ticket/SKILL.md        # expect 1
grep -c "Never assume an option limit" skills/implement-ticket/SKILL.md # expect 1
grep -c "Phase 7: Land the Work" skills/implement-ticket/SKILL.md      # expect 1
grep -c "AskUserQuestion" skills/implement-ticket/SKILL.md             # expect 0
grep -c "Do NOT commit changes" skills/implement-ticket/SKILL.md       # expect 0
grep -c "branch -D" skills/implement-ticket/SKILL.md                   # expect 0
./scripts/check-codex-skills.sh
```

Expected: the counts above, and the script exits 0.

- [ ] **Step 9: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-ticket/SKILL.md
git commit -m "feat(implement-ticket): always branch, then offer merge/PR/commit/nothing

Every invocation now implements on ticket-NNN-<slug>: worktree mode already
did, and the current-checkout path now creates or reuses the branch instead
of writing onto whatever was checked out. A dirty tree warns and confirms
once before the branch is created.

The blanket no-commit rule is replaced by a Phase 7 landing prompt (merge /
PR / commit only / nothing, defaulting to nothing) plus an opt-in
update-ticket follow-up. The base slot is no longer gated behind the
worktree keyword; typos are caught by requiring the token to resolve as a
branch.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Claude `implement-ticket-linear` — branch phase and landing phase

**Files:**
- Modify: `skills/implement-ticket-linear/SKILL.md` (frontmatter line 3; argument grammar lines 21-36; Phase 1 lines 40-46; Phase 3 lines 81-96; Phase 8 line 166-167; Worktree Note lines 177-191; Safety Rules lines 197-204)

**Interfaces:**
- Consumes: the landing-menu semantics established in Task 1 (four options, default 4, option-2 preflight, `-d` not `-D`, never push).
- Differences from Task 1, both required by the spec: **no status follow-up** (Linear status is an external write), and **option 1 in worktree mode is performed inline** because `/merge-worktree` only understands markdown `TICKET-NNN` worktrees.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" skills/implement-ticket-linear/SKILL.md  # expect 0
grep -c "Land the Work" skills/implement-ticket-linear/SKILL.md         # expect 0
grep -n "Never\*\* commit" skills/implement-ticket-linear/SKILL.md      # expect a hit in Safety Rules
```

- [ ] **Step 2: Update the frontmatter description**

Find (line 3):

```
description: "Implement a Linear issue end to end with code review. Source of truth is Linear (not docs/tickets/). Optional `worktree` keyword runs inside an isolated git worktree. Triggers on: /implement-ticket-linear ENG-42, /implement-ticket-linear https://linear.app/.../issue/ENG-42/..., implement Linear issue ENG-42, implement Linear ticket worktree"
```

Replace with:

```
description: "Implement a Linear issue end to end on its own branch with code review, then offer to merge it, open a PR, commit only, or leave it. Source of truth is Linear (not docs/tickets/). Optional `worktree` keyword runs inside an isolated git worktree. Triggers on: /implement-ticket-linear ENG-42, /implement-ticket-linear ENG-42 dev, /implement-ticket-linear https://linear.app/.../issue/ENG-42/..., implement Linear issue ENG-42, implement Linear ticket worktree"
```

- [ ] **Step 3: Insert the portable interaction rules block**

Find (lines 13-19, the requirement line plus the Prerequisites heading and its items):

```
A Linear issue id or URL is required (e.g. `ENG-42` or a `linear.app` issue URL). If no argument is provided, inform the user and stop.

## Prerequisites
```

Replace with:

````
A Linear issue id or URL is required (e.g. `ENG-42` or a `linear.app` issue URL). If no argument is provided, inform the user and stop.

## Portable interaction rules

This skill prompts the user three times — once if the working tree is dirty (Phase 3), once to offer the as-built comment (Phase 8), and once to land the work (Phase 9). All three follow these rules:

- Show every option with a stable number and a one-line description of what it does.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites
````

- [ ] **Step 4: Replace the argument grammar**

Find (lines 21-36):

````
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
````

Replace with:

````
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
````

- [ ] **Step 5: Update the argument parsing in Phase 1**

Find (lines 40-46):

```
1. **Parse `$ARGUMENTS`.** Split on whitespace. Capture:
   - `issue_ref` (first token — required)
   - `use_worktree` (true iff the second token is `worktree`)
   - `base` (third token if present, otherwise `main` when `use_worktree` is true)
2. If there is no first token, stop: "A Linear issue id or URL is required (e.g. `ENG-42`)."
3. If a fourth token exists, stop with an unrecognized-arguments error.
4. If a second token exists and is not `worktree`, stop as described above.
```

Replace with:

```
1. **Parse `$ARGUMENTS`.** Split on whitespace. Capture:
   - `issue_ref` (first token — required)
   - `use_worktree` (true iff a token is exactly `worktree`, case-insensitive)
   - `base_token` (the trailing non-`worktree` token after the issue ref, if any)
2. If there is no first token, stop: "A Linear issue id or URL is required (e.g. `ENG-42`)."
3. If a fourth token exists, stop with an unrecognized-arguments error.
4. If `base_token` is present, validate that it resolves as a branch, as described in the argument grammar above. If it does not, stop with the "did you mean 'worktree'?" error.
```

- [ ] **Step 6: Rewrite Phase 3 to resolve the base and create the branch**

Find (lines 81-96, the whole of Phase 3):

````
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
````

Replace with:

````
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
````

- [ ] **Step 7: Correct the Phase 8 summary claims**

Find (lines 166-167):

```
5. Reminder that **Linear status was not changed** and **nothing was committed** (the only possible Linear write is the opt-in as-built comment below)
6. **Next step for Linear status:** when the user is ready to mark the issue done (or move it to another state), run `/update-ticket-linear <issue_id>` (optionally with an explicit status such as `done`). That skill evaluates acceptance criteria and writes back to Linear; this skill never changes Linear status (its only Linear write is the opt-in as-built comment).
```

Replace with:

```
5. Reminder that **Linear status was not changed** (the only possible Linear write is the opt-in as-built comment below), and that nothing is committed until the user picks an option in Phase 9
6. **Next step for Linear status:** when the user is ready to mark the issue done (or move it to another state), run `/update-ticket-linear <issue_id>` (optionally with an explicit status such as `done`). That skill evaluates acceptance criteria and writes back to Linear; this skill never changes Linear status (its only Linear write is the opt-in as-built comment). This skill does **not** offer to do it as part of landing — unlike the ticket file that `/implement-ticket` can update in-branch, Linear state is an external write and stays a separate, deliberate step.
```

- [ ] **Step 8: Replace the Worktree Note with Phase 9**

Find (lines 177-191, the Worktree Note through the closing of its bash block):

`````
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
`````

Replace with:

```
### Worktree Note (only when `use_worktree` was true)

- **Worktree:** `.worktrees/<issue_id>-<slug>/` (branch `linear-<issue_id>-<slug>`, base `<base>`)
- **Inspect:** `cd .worktrees/<issue_id>-<slug>`
- **Land:** Phase 9 below offers to do this for you. Note that `/merge-worktree` is for markdown `TICKET-NNN` worktrees and will **not** work for Linear branches, so Phase 9 performs the merge inline.

If the worktree was reused with pre-existing uncommitted changes, mention that here too.
```

- [ ] **Step 9: Add Phase 9 and rewrite the Safety Rules**

Find (lines 193-204, the Manual Testing Instructions section heading through the end of the file):

```
### Manual Testing Instructions

Step-by-step verification: prerequisites, commands, URLs, inputs, expected results, edge cases. If purely internal, say manual testing is N/A and what automated tests cover.

## Safety Rules

- **Never** change Linear status, assignee, labels, or any other field. The single permitted write is the opt-in as-built comment in Phase 8, and only after explicit user confirmation.
- **Never** commit, and do not invoke `/commit-ticket`, `/commit-push-pr`, `/update-ticket`, or `/update-ticket-linear` (status updates belong in a separate `/update-ticket-linear` invocation after implementation).
- Do not read or write `docs/tickets/` as the ticket source (optional project context elsewhere is fine).
- If unrelated dirty changes in `WORK_DIR` conflict with the issue, stop and ask instead of overwriting.
- In worktree mode, do not switch the user's main checkout branch and do not delete the worktree at the end.
- If Linear MCP is missing or the issue cannot be resolved uniquely, stop — do not invent requirements.
```

Replace with:

`````
### Manual Testing Instructions

Step-by-step verification: prerequisites, commands, URLs, inputs, expected results, edge cases. If purely internal, say manual testing is N/A and what automated tests cover.

## Phase 9: Land the Work

Ask exactly once, after the Phase 8 summary and manual testing instructions, so the user decides with the full picture in front of them. Follow the portable interaction rules.

Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, still show option 2 but mark it unavailable with the reason, and do not accept it.

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

`/merge-worktree` only understands markdown `TICKET-NNN` worktrees, so both modes merge inline:

a. Invoke `/commit-ticket` via the `Skill` tool. In worktree mode this runs in the pinned worktree cwd, so it commits on the issue branch.
b. From `$MAIN_ROOT`, switch to the base — it may exist only on the remote: `git -C "$MAIN_ROOT" switch <base>` if it exists locally, otherwise `git -C "$MAIN_ROOT" switch -c <base> origin/<base>`.
c. `git -C "$MAIN_ROOT" merge --no-ff -m "Merge linear-<issue_id>-<slug> into <base>" linear-<issue_id>-<slug>`.
d. On conflict: `git -C "$MAIN_ROOT" merge --abort`, report which files conflicted, leave the branch and worktree intact, and stop. Do not attempt resolution.
e. On success, in worktree mode only: `git -C "$MAIN_ROOT" worktree remove .worktrees/<issue_id>-<slug>`.
f. On success: `git -C "$MAIN_ROOT" branch -d linear-<issue_id>-<slug>`. Use `-d`, not `-D` — after a `--no-ff` merge the safe delete always succeeds, so a refusal is information worth surfacing rather than overriding.
g. **Never push.** Close the report with `git push` as the explicit next step.

### Option 2 — open a PR

Invoke `/commit-push-pr` via the `Skill` tool. It commits, pushes the issue branch, and opens the PR. Stay on the branch afterward; leave the worktree in place.

### Option 3 — commit only

Invoke `/commit-ticket` via the `Skill` tool and stay on the branch.

### Option 4 — nothing

Leave the changes uncommitted. Report the branch name and that `/commit-push-pr` or a manual merge can land it later.

## Safety Rules

- **Never** change Linear status, assignee, labels, or any other field. The single permitted write is the opt-in as-built comment in Phase 8, and only after explicit user confirmation. Nothing in Phase 9 writes to Linear.
- No commit, merge, push, or branch deletion happens before Phase 9, and then only per the user's explicit choice. Never force-push, and never delete or overwrite a remote branch. Never invoke `/update-ticket` or `/update-ticket-linear` — Linear status stays a separate, deliberate step.
- Do not read or write `docs/tickets/` as the ticket source (optional project context elsewhere is fine).
- If unrelated dirty changes in `WORK_DIR` conflict with the issue, stop and ask instead of overwriting.
- In worktree mode, do not switch the user's main checkout branch or remove the worktree except as part of an explicitly chosen Phase 9 option 1.
- If Linear MCP is missing or the issue cannot be resolved uniquely, stop — do not invent requirements.
`````

- [ ] **Step 10: Verify the edits landed (green)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" skills/implement-ticket-linear/SKILL.md         # expect 1
grep -c "Never assume an option limit" skills/implement-ticket-linear/SKILL.md # expect 1
grep -c "Phase 9: Land the Work" skills/implement-ticket-linear/SKILL.md       # expect 1
grep -c "AskUserQuestion" skills/implement-ticket-linear/SKILL.md              # expect 0
grep -c "branch -D" skills/implement-ticket-linear/SKILL.md                    # expect 0
grep -c "update-ticket-linear" skills/implement-ticket-linear/SKILL.md         # expect 2 — grep -c counts lines, not occurrences; both are reminders/prohibitions, never an invocation
./scripts/check-codex-skills.sh
```

Expected: the counts above, and the script exits 0.

- [ ] **Step 11: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-ticket-linear/SKILL.md
git commit -m "feat(implement-ticket-linear): always branch, then offer merge/PR/commit/nothing

Mirrors the implement-ticket change: every invocation implements on
linear-<ID>-<slug>, and a Phase 9 landing prompt offers merge / PR /
commit only / nothing, defaulting to nothing.

Two deliberate differences from the docs twin: no status follow-up, since
Linear state is an external write that stays a separate update-ticket-linear
step; and option 1 merges inline in both modes, since merge-worktree only
understands markdown TICKET-NNN worktrees.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Codex `implement-ticket` — branch phase, landing phase, and loop rule

**Files:**
- Modify: `.agents/skills/implement-ticket/SKILL.md` (frontmatter line 3; argument grammar lines 12-23; Phase 1 lines 25-45; Phase 8 lines 112-115; Safety Rules lines 117-123)

**Interfaces:**
- Consumes: the branch and landing semantics from Task 1.
- Differences, all required by the tree divergence recorded in `docs/superpowers/plans/2026-07-24-unknowns-methodology.md`: this document **already commits** (Phase 6) and **already updates status** (Phase 7), so its menu is three options with no commit-only and no status follow-up. It also has a **no-argument backlog loop** the Claude copy lacks, which needs its own branching rule.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" .agents/skills/implement-ticket/SKILL.md  # expect 0
grep -c "Land the Work" .agents/skills/implement-ticket/SKILL.md         # expect 0
```

- [ ] **Step 2: Update the frontmatter description**

Find (line 3):

```
description: "Use when the user explicitly asks to implement one or more backlog tickets from docs/tickets. Optionally pass `worktree` after the ticket id (with an optional base branch) to run the implementation inside an isolated git worktree, auto-creating it via $create-worktree if it doesn't exist. Prefer explicit invocation with $implement-ticket."
```

Replace with:

```
description: "Use when the user explicitly asks to implement one or more backlog tickets from docs/tickets. Each ticket is implemented on its own branch, and the run ends by offering to merge it, open a PR, or stay on the branch. Optionally pass a base branch, or `worktree` (with an optional base branch) to run the implementation inside an isolated git worktree, auto-creating it via $create-worktree if it doesn't exist. Prefer explicit invocation with $implement-ticket."
```

- [ ] **Step 3: Insert the portable interaction rules block and replace the argument grammar**

Find (lines 12-23):

````
## Argument grammar

When a single ticket is named, the user can also opt into worktree mode:

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Implement that ticket in the current checkout. |
| `<ticket> worktree` | Implement inside an isolated worktree off `origin/main`. |
| `<ticket> worktree <base>` | Implement inside a worktree off `origin/<base>` (e.g. `dev`). |
| (no args) | Loop through the pending backlog in the current checkout. |

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode. A second token that is not `worktree` is a typo — stop and tell the user "unrecognized argument; pass `worktree` to use a worktree." Worktree mode only makes sense for a single named ticket; if the user provided no ticket id, ignore the `worktree` keyword (it has no ticket to attach to) and report that.
````

Replace with:

````
## Portable interaction rules

This skill prompts the user twice — once if the working tree is dirty (Phase 1), and once to land the work (Phase 8). Both follow these rules:

- Show every option with a stable number and a one-line description of what it does.
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

The `worktree` keyword is case-insensitive; only this exact word triggers worktree mode. Any other trailing token is read as a base branch and must resolve — check `git rev-parse --verify --quiet origin/<token>` then `git rev-parse --verify --quiet <token>`. If neither resolves, stop with "unrecognized argument '<token>' — did you mean 'worktree'? (no branch named '<token>' found locally or on origin)". Worktree mode only makes sense for a single named ticket; if the user provided no ticket id, ignore the `worktree` keyword (it has no ticket to attach to) and report that.
````

- [ ] **Step 4: Rewrite Phase 1 to resolve the base and create the branch**

Find (lines 27-45, the body of Phase 1):

````
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
````

Replace with:

````
Run this whether or not worktree mode is requested — both modes need the same handles.

1. Parse the argument string. Capture `ticket_id` (if any), `use_worktree` (bool), and `base_token` (the trailing non-ticket, non-`worktree` token, if any). Validate `base_token` as described in the argument grammar above.
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
   - Current checkout without one, when the current branch is **not** a `ticket-NNN-<slug>` branch: the current branch, from `git rev-parse --abbrev-ref HEAD`. If that returns `HEAD` (detached), stop and ask for an explicit base branch.
   - Current checkout without one, when the current branch already **is** the `ticket-NNN-<slug>` branch for this ticket (you are resuming): a branch cannot be its own base, and nothing on disk records what it forked from. Ask once, following the portable interaction rules, offering the plausible bases that actually exist locally or on `origin` (check `main`, `master`, `dev`, `develop`). Use the answer as `base`; if the user declines, record no base and mark Phase 8's option 1 unavailable rather than guessing. Without this rule, option 1 would merge the branch into itself — git reports "Already up to date" and exits 0, so the skill would claim a successful land while nothing reached the real base.
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
````

- [ ] **Step 5: Replace Phase 8 with the loop rule plus the landing prompt**

Find (lines 112-115, the whole of Phase 8):

```
## Phase 8: Loop or Stop

- If the user named a specific ticket, stop after Phase 7. When worktree mode was active, mention the worktree path and the `$merge-worktree NNN [base]` command so the user knows the natural next step to land the work.
- Otherwise continue with the next pending ticket until all tickets are done or you hit a real blocker. The backlog loop only runs in the non-worktree path — looping across worktrees is out of scope for one invocation.
```

Replace with:

`````
## Phase 8: Loop, then Land

**Loop first.** If the user named a specific ticket, go straight to the landing prompt below. Otherwise continue with the next pending ticket by re-entering the workflow in this order: **Phase 3** to pick it, then **Phase 1 step 3** to resolve its `NNN`, slug, and branch name, then **Phase 1 step 8** to create `ticket-NNN-<slug>` from the current HEAD — which is the previous ticket's branch, so the work stacks and dependent tickets still compile — and only then **Phase 4** onward. Repeat until all tickets are done or you hit a real blocker. Track every branch you create during the run. The backlog loop only runs in the non-worktree path; looping across worktrees is out of scope for one invocation.

**Then land, once per run.** Phases 6 and 7 already committed the code and the ticket status, so this prompt is only about where those commits go. Ask exactly once, following the portable interaction rules.

Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, still show option 2 but mark it unavailable with the reason, and do not accept it.

````
TICKET-NNN implemented on ticket-NNN-<slug> (base: <base>).
How do you want to land it?

  1  Merge into <base> locally  (merge --no-ff → delete branch)
  2  Open a PR                  ($commit-push-pr)
  3  Stay on the branch         [default]
````

In backlog-loop mode, name every ticket and branch from the run in the prompt instead of just one. An ambiguous, empty, or unanswered response is option 3. Never re-ask.

**Option 1 — merge into `<base>`:**

- Worktree mode: invoke `$merge-worktree` with `<NNN> <base>`. It merges, removes the worktree, and deletes the local branch.
- Current checkout: `git switch <base>` if the base exists locally, otherwise `git switch -c <base> origin/<base>`. Then `git merge --no-ff -m "Merge ticket-NNN-<slug> into <base>" ticket-NNN-<slug>`.
- In backlog-loop mode, merge only the **last** branch of the run. Because each ticket forked from the previous HEAD, that branch already contains every earlier ticket's commits. Then delete every branch created during the run, oldest first.
- On conflict: `git merge --abort`, report which files conflicted, leave the branches intact, and stop. Do not attempt resolution.
- On success: `git branch -d <branch>` for each branch to delete. Use `-d`, not `-D` — after a `--no-ff` merge the safe delete always succeeds, so a refusal is worth surfacing.
- Never push. Close the report with `git push` as the explicit next step.

**Option 2 — open a PR:** invoke `$commit-push-pr`. It pushes the branch and opens the PR. Stay on the branch. In backlog-loop mode this opens one PR for the final stacked branch.

**Option 3 — stay on the branch:** report each branch name, the base, and that `$commit-push-pr` or `$merge-worktree NNN [base]` can land the work later.
`````

- [ ] **Step 6: Update the Safety Rules**

Find (lines 122-123, the last two bullets of Safety Rules):

```
- If unrelated user changes conflict with the ticket, stop and ask how to proceed instead of overwriting them.
- In worktree mode, do not switch the user's main checkout to another branch and do not delete the worktree at the end — leave both alone so the user can inspect the work and run `$merge-worktree` deliberately.
```

Replace with:

```
- If unrelated user changes conflict with the ticket, stop and ask how to proceed instead of overwriting them.
- Merge, push, and branch deletion happen only per the user's explicit Phase 8 choice. Never force-push, and never delete or overwrite a remote branch.
- In worktree mode, do not switch the user's main checkout to another branch and do not delete the worktree except as part of an explicitly chosen Phase 8 option 1 — otherwise leave both alone so the user can inspect the work and run `$merge-worktree` deliberately.
```

- [ ] **Step 7: Verify the edits landed (green)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" .agents/skills/implement-ticket/SKILL.md         # expect 1
grep -c "Never assume an option limit" .agents/skills/implement-ticket/SKILL.md # expect 1
grep -c "Loop, then Land" .agents/skills/implement-ticket/SKILL.md              # expect 1
grep -c "AskUserQuestion" .agents/skills/implement-ticket/SKILL.md              # expect 0
grep -c "branch -D" .agents/skills/implement-ticket/SKILL.md                    # expect 0
./scripts/check-codex-skills.sh
```

- [ ] **Step 8: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add .agents/skills/implement-ticket/SKILL.md
git commit -m "feat(implement-ticket): always branch and offer landing (Codex tree)

Same guaranteed branch and landing prompt as the Claude copy, adapted to
this document's divergent behavior: it already commits (Phase 6) and
updates status (Phase 7), so the menu is merge / PR / stay on branch with
no commit-only option and no status follow-up.

The backlog loop gives each ticket its own branch forked from HEAD so
dependent tickets stack and still compile, then asks the landing question
once for the whole run — merging the final branch lands them all.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Codex `implement-ticket-linear` — branch phase and landing phase

**Files:**
- Modify: `.agents/skills/implement-ticket-linear/SKILL.md` (frontmatter line 3; intro line 10; argument grammar lines 20-30; Phase 1 line 34; Phase 3 lines 51-62; Phase 7 lines 93 and 97-103; Safety Rules lines 107-112)

**Interfaces:**
- Consumes: the landing semantics from Task 2 (inline merge in both modes, no status follow-up) and the Codex tone from Task 3.
- Note: unlike the Codex docs twin, this document does **not** commit today, so its menu keeps all four options, matching Task 2.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" .agents/skills/implement-ticket-linear/SKILL.md  # expect 0
grep -c "Land the Work" .agents/skills/implement-ticket-linear/SKILL.md         # expect 0
```

- [ ] **Step 2: Update the frontmatter description**

Find (line 3):

```
description: "Use when the user explicitly asks to implement a Linear issue (not docs/tickets markdown). Optionally pass `worktree` after the issue id (with an optional base branch) to run inside an isolated git worktree. Prefer explicit invocation with $implement-ticket-linear. Requires Linear MCP."
```

Replace with:

```
description: "Use when the user explicitly asks to implement a Linear issue (not docs/tickets markdown). The issue is implemented on its own branch, and the run ends by offering to merge it, open a PR, commit only, or leave it. Optionally pass a base branch, or `worktree` (with an optional base branch) to run inside an isolated git worktree. Prefer explicit invocation with $implement-ticket-linear. Requires Linear MCP."
```

- [ ] **Step 3: Correct the intro's no-commit claim and add the portable interaction rules**

Find (lines 10-12):

```
**This skill does not use `docs/tickets/`.** The Linear issue is the source of truth. It also does **not** commit git changes and does **not** mutate Linear except for a single opt-in as-built comment (see Phase 7) — never status, assignee, or label changes.

If the user included an issue id or URL after `$implement-ticket-linear`, implement that issue. Empty args are invalid — always require an id or URL.
```

Replace with:

```
**This skill does not use `docs/tickets/`.** The Linear issue is the source of truth. It does **not** mutate Linear except for a single opt-in as-built comment (see Phase 7) — never status, assignee, or label changes. It commits git changes only when the user picks a landing option in Phase 8.

If the user included an issue id or URL after `$implement-ticket-linear`, implement that issue. Empty args are invalid — always require an id or URL.

## Portable interaction rules

This skill prompts the user three times — once if the working tree is dirty (Phase 3), once to offer the as-built comment (Phase 7), and once to land the work (Phase 8). All three follow these rules:

- Show every option with a stable number and a one-line description of what it does.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name, using `$skill-name` syntax when suggesting a command.
```

- [ ] **Step 4: Replace the argument grammar**

Find (lines 20-28):

```
## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Implement that Linear issue in the current checkout. |
| `<issue> worktree` | Isolated worktree off `origin/main`. |
| `<issue> worktree <base>` | Isolated worktree off `origin/<base>`. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Normalize team keys to uppercase. The `worktree` keyword is case-insensitive; only that exact word triggers worktree mode. A second non-`worktree` token is a typo — stop and say so.
```

Replace with:

```
## Argument grammar

Every invocation implements on a branch:

| Invocation | Meaning |
| --- | --- |
| `<issue>` | New branch off the current HEAD, in the current checkout. |
| `<issue> <base>` | New branch off `origin/<base>`, in the current checkout. |
| `<issue> worktree` | New branch off `origin/main`, inside an isolated worktree. |
| `<issue> worktree <base>` | New branch off `origin/<base>`, inside an isolated worktree. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Normalize team keys to uppercase. The `worktree` keyword is case-insensitive; only that exact word triggers worktree mode. Any other trailing token is read as a base branch and must resolve — check `git rev-parse --verify --quiet origin/<token>` then `git rev-parse --verify --quiet <token>`. If neither resolves, stop with "unrecognized argument '<token>' — did you mean 'worktree'? (no branch named '<token>' found locally or on origin)".
```

- [ ] **Step 5: Update the argument parsing in Phase 1**

Find (line 34):

```
1. Parse args: `issue_ref` (required), `use_worktree`, `base` (default `main` when worktree mode).
```

Replace with:

```
1. Parse args: `issue_ref` (required), `use_worktree`, `base_token` (the trailing non-`worktree` token, if any — validate it resolves as a branch per the argument grammar).
```

- [ ] **Step 6: Rewrite Phase 3 to resolve the base and create the branch**

Find (lines 51-62, the whole of Phase 3):

```
## Phase 3: Working Directory

1. If `use_worktree`:
   - Reuse an existing registered worktree at the path (dirty state is OK; note it later).
   - Else create inline — do **not** call `$create-worktree` (it requires markdown tickets):
     - Fetch `origin/<base>` when possible
     - Ensure `.worktrees/` is in `$MAIN_ROOT/.gitignore`
     - `git worktree add` with new or existing `linear-…` branch from the resolved base ref
   - `WORK_DIR =` worktree path
2. Else `WORK_DIR = $MAIN_ROOT` (or current toplevel if already on a purposeful worktree).
3. `cd "$WORK_DIR"` once. Prefix absolute file tools with `$WORK_DIR`.
4. State in one sentence where work is happening.
```

Replace with:

```
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
```

- [ ] **Step 7: Correct the Phase 7 summary claim and replace the manual-land block with Phase 8**

Find (line 93):

```
3. Explicit note: **no git commit**, **Linear status unchanged**
```

Replace with:

```
3. Explicit note: **Linear status unchanged**, and **nothing committed** until the user picks an option in Phase 8
```

Then find (lines 97-103, item 7 and its bash block):

`````
7. If worktree mode: path, branch, base, and **manual land** instructions — `$merge-worktree` only understands markdown `TICKET-NNN` worktrees:

```bash
git checkout <base>
git merge linear-<issue_id>-<slug>
# or push + open PR from the worktree branch
```
`````

Replace with:

`````
7. If worktree mode: path, branch, and base. Note that `$merge-worktree` only understands markdown `TICKET-NNN` worktrees, so Phase 8 merges inline.

## Phase 8: Land the Work

Ask exactly once, after the Phase 7 summary, following the portable interaction rules. Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, show option 2 as unavailable with the reason and do not accept it.

````
<issue_id> implemented on linear-<issue_id>-<slug> (base: <base>).
How do you want to land it?

  1  Merge into <base> locally  (commit → merge --no-ff → delete branch)
  2  Open a PR                  ($commit-push-pr)
  3  Commit only                (stay on the branch)
  4  Nothing                    (leave changes uncommitted)  [default]
````

An ambiguous, empty, or unanswered response is option 4. Never re-ask. None of these options writes to Linear.

**Option 1 — merge into `<base>`.** Both modes merge inline, since `$merge-worktree` only understands markdown tickets:

- Invoke `$commit-ticket` (in worktree mode the pinned cwd puts the commit on the issue branch).
- From `$MAIN_ROOT`: `git switch <base>` if the base exists locally, otherwise `git switch -c <base> origin/<base>`.
- `git merge --no-ff -m "Merge linear-<issue_id>-<slug> into <base>" linear-<issue_id>-<slug>`.
- On conflict: `git merge --abort`, report the conflicted files, leave branch and worktree intact, stop.
- On success: in worktree mode `git worktree remove .worktrees/<issue_id>-<slug>`, then `git branch -d linear-<issue_id>-<slug>`. Use `-d`, not `-D`.
- Never push. Close with `git push` as the next step.

**Option 2 — open a PR:** invoke `$commit-push-pr`; stay on the branch and leave the worktree in place.

**Option 3 — commit only:** invoke `$commit-ticket`; stay on the branch.

**Option 4 — nothing:** leave the changes uncommitted; report the branch name and that `$commit-push-pr` or a manual merge can land it later.
`````

- [ ] **Step 8: Update the Safety Rules**

Find (lines 107-112, the whole Safety Rules list):

```
- Never mutate Linear except the single opt-in as-built comment after explicit user confirmation; never change status, assignee, labels, or any other field.
- Never commit; do not call `$commit-ticket`, `$commit-push-pr`, `$update-ticket`, or `$update-ticket-linear` (status updates belong in a separate `$update-ticket-linear` invocation after implementation).
- Do not use `docs/tickets/` as the ticket source.
- If dirty unrelated changes conflict with the issue, stop and ask.
- In worktree mode, do not switch the main checkout branch or delete the worktree at the end.
- Missing Linear MCP or unresolvable issue → stop.
```

Replace with:

```
- Never mutate Linear except the single opt-in as-built comment after explicit user confirmation; never change status, assignee, labels, or any other field. Nothing in Phase 8 writes to Linear.
- No commit, merge, push, or branch deletion before Phase 8, and then only per the user's explicit choice. Never force-push, and never delete or overwrite a remote branch. Never call `$update-ticket` or `$update-ticket-linear` — status updates belong in a separate `$update-ticket-linear` invocation after implementation.
- Do not use `docs/tickets/` as the ticket source.
- If dirty unrelated changes conflict with the issue, stop and ask.
- In worktree mode, do not switch the main checkout branch or delete the worktree except as part of an explicitly chosen Phase 8 option 1.
- Missing Linear MCP or unresolvable issue → stop.
```

- [ ] **Step 9: Verify the edits landed (green)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "Portable interaction" .agents/skills/implement-ticket-linear/SKILL.md         # expect 1
grep -c "Never assume an option limit" .agents/skills/implement-ticket-linear/SKILL.md # expect 1
grep -c "Phase 8: Land the Work" .agents/skills/implement-ticket-linear/SKILL.md       # expect 1
grep -c "AskUserQuestion" .agents/skills/implement-ticket-linear/SKILL.md              # expect 0
grep -c "branch -D" .agents/skills/implement-ticket-linear/SKILL.md                    # expect 0
./scripts/check-codex-skills.sh
```

- [ ] **Step 10: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add .agents/skills/implement-ticket-linear/SKILL.md
git commit -m "feat(implement-ticket-linear): always branch and offer landing (Codex tree)

Mirrors the Claude copy: every invocation implements on
linear-<ID>-<slug>, and a Phase 8 landing prompt offers merge / PR /
commit only / nothing, defaulting to nothing. Unlike the Codex docs twin
this document did not commit before, so it keeps all four options.

Option 1 merges inline in both modes because merge-worktree only
understands markdown TICKET-NNN worktrees. Linear status is still never
written.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Lock the portable-interaction contract in the validator

**Files:**
- Modify: `scripts/check-codex-skills.sh` (add `validate_implement_contract` after `validate_interact_contract`, which currently ends near line 330; add the call beside line 336)

**Interfaces:**
- Consumes: the literals `Portable interaction` and `Never assume an option limit` written by Tasks 1-4, and the absence of `AskUserQuestion` in all four.
- Reuses existing helpers: `claude_root`, `codex_root` (script lines 6-7), `require_literal` (line 108), `forbid_literal` (line 117).

- [ ] **Step 1: Add the validator function**

Find the line that calls the existing validators near the bottom of the script:

```bash
validate_clarify_contract
validate_interact_contract
```

Insert this function definition **above** that block (immediately after the closing `}` of `validate_interact_contract`), then add the new call:

```bash
validate_implement_contract() {
  local skill
  local skill_md

  # The implement twins gained user-facing prompts (the dirty-tree confirm and
  # the landing menu), so they follow the portable-interaction contract. Unlike
  # the clarify/quiz entry points they must stay model-invocable — their
  # "Triggers on:" lists are the point — so no explicit-only or
  # disable-model-invocation requirements here.
  for skill in implement-ticket implement-ticket-linear; do
    for skill_md in "$claude_root/$skill/SKILL.md" "$codex_root/$skill/SKILL.md"; do
      require_literal "$skill_md" "Portable interaction"
      require_literal "$skill_md" "Never assume an option limit"
      forbid_literal "$skill_md" "AskUserQuestion"
    done
  done
}

validate_clarify_contract
validate_interact_contract
validate_implement_contract
```

- [ ] **Step 2: Run the script and verify it passes**

```bash
cd /Users/calvinku/FunProjects/cktk
./scripts/check-codex-skills.sh
echo "exit=$?"
```

Expected: `exit=0` and the closing "Validated N skill(s)…" line.

- [ ] **Step 3: Prove the new check can actually fail**

A check that never fails is not a check. Temporarily break one file, confirm the failure, then restore it:

```bash
cd /Users/calvinku/FunProjects/cktk
cp skills/implement-ticket/SKILL.md /tmp/implement-ticket-backup.md
sed -i '' 's/Never assume an option limit/Never assume a limit/' skills/implement-ticket/SKILL.md
./scripts/check-codex-skills.sh; echo "exit=$?"
```

Expected: an `ERROR: … must contain: Never assume an option limit` line and `exit=1`.

Restore and re-verify:

```bash
cd /Users/calvinku/FunProjects/cktk
cp /tmp/implement-ticket-backup.md skills/implement-ticket/SKILL.md
rm /tmp/implement-ticket-backup.md
git diff --stat skills/implement-ticket/SKILL.md   # expect no output
./scripts/check-codex-skills.sh; echo "exit=$?"    # expect exit=0
```

- [ ] **Step 4: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add scripts/check-codex-skills.sh
git commit -m "test(validator): enforce portable-interaction contract for implement twins

The implement twins now prompt the user (dirty-tree confirm, landing menu),
so all four documents must carry the portable-interaction wording and must
not name a host-specific tool.

Deliberately does not reuse validate_clarify_contract: that function also
requires disable-model-invocation, which would break the Triggers-on model
invocation both implement twins depend on. Same carve-out reasoning as
validate_interact_contract.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Update README and catalog

**Files:**
- Modify: `README.md` (skills table row at line 37; usage examples at lines 219-222)
- Modify: `catalog.json` (descriptions at lines 15 and 30)

**Interfaces:**
- Consumes: the final behavior from Tasks 1-4. Nothing consumes this task.

- [ ] **Step 1: Update the README skills table row**

Find (line 37):

```
| `implement-ticket` · `implement-ticket-linear` | Implement a ticket end to end with code review and manual testing instructions; optional `worktree` keyword for isolated parallel work | docs twin appends as-built notes to the ticket file; the Linear twin's only Linear write is an opt-in as-built comment posted after explicit confirmation |
```

Replace with:

```
| `implement-ticket` · `implement-ticket-linear` | Implement a ticket end to end on its own branch with code review and manual testing instructions, then offer to merge it, open a PR, commit only, or leave it; optional `worktree` keyword for isolated parallel work | docs twin appends as-built notes to the ticket file and can run `update-ticket` as part of landing; the Linear twin's only Linear write is an opt-in as-built comment posted after explicit confirmation |
```

- [ ] **Step 2: Update the README usage examples**

Find (lines 219-222):

```
/implement-ticket 003                        # Implement a ticket (also accepts TICKET-003)
/implement-ticket 003 worktree               # Implement inside .worktrees/003-slug off origin/main
/implement-ticket 003 worktree dev           # Same, based on origin/dev (worktree variants also work for implement-ticket-linear)
/implement-ticket-linear ENG-42              # Implement a Linear issue (requires Linear MCP)
```

Replace with:

```
/implement-ticket 003                        # Implement on branch ticket-003-slug off the current HEAD
/implement-ticket 003 dev                    # Same, but branch off origin/dev
/implement-ticket 003 worktree               # Implement inside .worktrees/003-slug off origin/main
/implement-ticket 003 worktree dev           # Same, based on origin/dev (all variants also work for implement-ticket-linear)
/implement-ticket-linear ENG-42              # Implement a Linear issue (requires Linear MCP)
```

- [ ] **Step 3: Update the catalog descriptions**

Find (line 15):

```
      "description": "Implement a specific ticket with code review, optionally in an isolated worktree (docs/tickets twin of implement-ticket-linear)"
```

Replace with:

```
      "description": "Implement a specific ticket on its own branch with code review, then offer to merge, open a PR, or leave it; optionally in an isolated worktree (docs/tickets twin of implement-ticket-linear)"
```

Find (line 30):

```
      "description": "Implement a Linear issue with code review, optionally in an isolated worktree (requires Linear MCP; Linear twin of implement-ticket)"
```

Replace with:

```
      "description": "Implement a Linear issue on its own branch with code review, then offer to merge, open a PR, or leave it; optionally in an isolated worktree (requires Linear MCP; Linear twin of implement-ticket)"
```

- [ ] **Step 4: Verify**

```bash
cd /Users/calvinku/FunProjects/cktk
python3 -c "import json; json.load(open('catalog.json')); print('catalog.json parses')"
grep -c "on its own branch" README.md catalog.json   # expect 1 and 2
./scripts/check-codex-skills.sh; echo "exit=$?"      # expect exit=0
```

- [ ] **Step 5: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add README.md catalog.json
git commit -m "docs: describe always-branch and landing step for the implement twins

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Final verification

After all six tasks:

```bash
cd /Users/calvinku/FunProjects/cktk
./scripts/check-codex-skills.sh; echo "exit=$?"

# All four documents carry the contract:
grep -lc "Portable interaction" \
  skills/implement-ticket/SKILL.md \
  skills/implement-ticket-linear/SKILL.md \
  .agents/skills/implement-ticket/SKILL.md \
  .agents/skills/implement-ticket-linear/SKILL.md

# No document still claims it never commits:
grep -rn "Do NOT commit changes\|Never\*\* commit\|does \*\*not\*\* commit" \
  skills/implement-ticket*/SKILL.md .agents/skills/implement-ticket*/SKILL.md   # expect no output

# No document uses force-delete:
grep -rn "branch -D" skills/implement-ticket*/SKILL.md .agents/skills/implement-ticket*/SKILL.md  # expect no output

git log --oneline -6
```

Expected: `exit=0`, four `1` counts, no output from the two negative greps, six new commits.
