# Linear Twins for the Worktree Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `create-worktree-linear` and `merge-worktree-linear` so Linear issues get the same isolated-worktree workflow `docs/tickets/` issues already have.

**Architecture:** Two new skills, each landing in all three trees at once — the canonical Claude document under `skills/`, a separately written Codex document under `.agents/skills/` with its `agents/openai.yaml`, and an Antigravity symlink under `.agent/skills/`. A skill that exists in only one tree fails the validator's generic loop, so a tree is not a task boundary; a skill is. A new `validate_worktree_linear_contract` in `scripts/check-codex-skills.sh` grows one block per task so every commit leaves the validator green. Four existing documents get cross-reference fixes only — no control flow changes anywhere.

**Tech Stack:** Markdown skill documents, Bash validator (`scripts/check-codex-skills.sh`), Ruby+YAML frontmatter checks already present in that script, git worktree plumbing.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-26-worktree-linear-twins-design.md`. Every task's requirements implicitly include it.
- **The naming contract is fixed and shared with two existing skills.** Worktrees live at `.worktrees/<issue_id>-<slug>`; branches are `linear-<issue_id>-<slug>`. `implement-ticket-linear:102` and `update-ticket-linear:91` compute the same handles, and `update-ticket-linear:100` discovers by the `<issue_id>-` prefix. Drift here surfaces as a silently missing worktree, not as an error.
- **Slug derivation is copied verbatim** from `implement-ticket-linear:95-100`: lowercase; every run of non-alphanumerics to a single `-`; strip leading and trailing `-`; truncate to ~40 characters preferring a cut at a hyphen; fall back to `issue` when empty.
- Per `AGENTS.md`: the Claude tree (`skills/`) and Codex tree (`.agents/skills/`) are separate documents. Never copy prose between them verbatim — the Codex copies are terser and use `$skill-name` invocation syntax. `.agent/skills/` is symlinks only.
- **Line numbers in every `Files:` block refer to the file as it stands before that task begins.** The quoted find-text is the authority — locate edits by matching text, not by seeking a line number.
- Neither new skill performs any Linear write. `create-worktree-linear` uses Linear MCP read tools only; `merge-worktree-linear` does not require Linear MCP at all.
- Neither new skill pushes, deletes a remote branch, opens a PR, or resolves a merge conflict.
- `git worktree remove` is never called with `--force` (spec §4a finding 4).
- Cleanup removes the worktree **before** deleting the branch (spec §4a finding 3).
- Acceptance gate for every task: `./scripts/check-codex-skills.sh` exits 0.

---

### Task 1: `create-worktree-linear` across all three trees

**Files:**
- Create: `skills/create-worktree-linear/SKILL.md`
- Create: `.agents/skills/create-worktree-linear/SKILL.md`
- Create: `.agents/skills/create-worktree-linear/agents/openai.yaml`
- Create: `.agent/skills/create-worktree-linear` (symlink)
- Modify: `scripts/check-codex-skills.sh` (add `forbid_write_call` helper after `forbid_stale_claim` at line ~120; add `validate_worktree_linear_contract`; add its call site beside `validate_implement_contract`)

**Interfaces:**
- Produces: the worktree path form `.worktrees/<issue_id>-<slug>`, the branch form `linear-<issue_id>-<slug>`, the trailing-token tiebreak, and the id-prefix matching rules. Task 2 restates adapted versions of all four; Task 3 references the skill by name.
- Produces: `validate_worktree_linear_contract` and `forbid_write_call` in the validator. Tasks 2 and 3 extend that function.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
ls skills/create-worktree-linear 2>&1            # expect: No such file or directory
grep -c "worktree_linear" scripts/check-codex-skills.sh   # expect 0
./scripts/check-codex-skills.sh | tail -1        # expect: Validated 31 skill(s) ...
```

Expected: the first two show the skill and validator block are absent; the third confirms the repo starts green.

- [ ] **Step 2: Write the Claude skill**

Create `skills/create-worktree-linear/SKILL.md`:

`````markdown
---
name: create-worktree-linear
description: "Create one or more git worktrees for Linear issues, each as an isolated checkout under .worktrees/ENG-42-slug/ on its own linear-ENG-42-slug branch. Source of truth is Linear, not docs/tickets/. Optionally pass a base branch as the last argument (defaults to main, fetched fresh from origin). Requires Linear MCP; makes no Linear writes. Triggers on: /create-worktree-linear, /create-worktree-linear ENG-42, create worktree for Linear issue, worktree this Linear issue, isolated branch for Linear ticket, parallel Linear issue work"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

Set up one or more git worktrees so **Linear** issues can be worked on in parallel without switching branches in the main checkout. Each worktree gets a fresh branch off the chosen base and lives at `.worktrees/<issue_id>-<slug>/` inside the repo.

This skill is the Linear counterpart of `/create-worktree`. It does **not** read `docs/tickets/*.md` — the Linear issue is the ticket.

It **never writes to Linear**. It reads each issue to derive a directory name and nothing else. In particular it does not move a Todo issue into an in-progress state: preparing a workspace is not starting work, and a multi-issue batch would fire one status write per issue. `/implement-ticket-linear` makes that transition when implementation actually starts.

## Prerequisites

1. **Linear MCP** must be available and authenticated in the host agent (official server: `https://mcp.linear.app/mcp`, documented at https://linear.app/docs/mcp).
2. If no Linear MCP tools are available, stop and tell the user to configure Linear MCP. Do **not** invent API-key, CLI, or browser workarounds.
3. Use Linear MCP **read** tools only (get / list / search by identifier).

## Phase 1: Parse Arguments

Split `$ARGUMENTS` on whitespace. Classify each token:

- **Issue reference** — a Linear identifier matching `^[A-Za-z]+-\d+$` (case-insensitive; normalize the team key to uppercase, so `eng-42` → `ENG-42`), or a `linear.app` URL containing one (extract the first path segment matching `[A-Za-z]+-\d+`).
- **Base branch** — anything that does not match those forms. At most one base-branch token is allowed. If two or more are passed, report the conflict and stop.

If no issue references are provided, ask the user for at least one and stop. If no base-branch token is provided, default the base to `main`.

| Invocation | Issues | Base |
| --- | --- | --- |
| `/create-worktree-linear ENG-42` | ENG-42 | main |
| `/create-worktree-linear ENG-42 ENG-43` | ENG-42, ENG-43 | main |
| `/create-worktree-linear ENG-42 dev` | ENG-42 | dev |
| `/create-worktree-linear eng-42 ENG-43 release-2026` | ENG-42, ENG-43 | release-2026 |

### The trailing-token tiebreak

Unlike `TICKET-NNN`, the Linear identifier pattern collides with ordinary branch names: `release-2026`, `v2-1`, and `sprint-14` all parse as identifiers. Pattern classification runs first, and this tiebreak applies **only to the trailing token**, and **only after Phase 2 has already failed** to resolve it as an issue:

- If the trailing token does not resolve as a Linear issue but does resolve as a branch — check `git rev-parse --verify --quiet origin/<token>`, then `git rev-parse --verify --quiet <token>` — treat it as the base branch and say so in one line:

  ```
  'release-2026' is not a Linear issue but is a branch — using it as the base.
  ```

- If it resolves as neither, report `<token> not found in Linear` and stop the batch.

If a repository genuinely has a branch named `ENG-42` while issue ENG-42 also exists, the issue wins, and that branch cannot be named as a base here. Document the collision rather than adding disambiguation machinery.

## Phase 2: Resolve the Main Repo Root and Issues

1. Confirm we're inside a git repo. Resolve the **main** repo root so the skill behaves the same whether invoked from the main checkout or from another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
   All paths below are relative to `$MAIN_ROOT`.

2. Fetch each issue by identifier via Linear MCP, preferring an exact identifier match.
   - **Not found** → if it is the trailing token, apply the tiebreak above; otherwise report `<issue_id> not found in Linear` and **stop the whole batch**. Don't partially create worktrees: a typo in one id means the user wants to fix the input rather than skip ahead.
   - **Multiple matches** for a full identifier → report the ambiguity and stop.

3. Capture the **title** for each issue. Nothing else is needed.

4. Derive **slug** from the title, using exactly the rules `/implement-ticket-linear` uses — any drift breaks worktree reuse between the two skills:
   - Lowercase
   - Replace any run of non-alphanumeric characters with a single `-`
   - Strip leading/trailing `-`
   - Truncate to ~40 characters, preferring a cut at a hyphen
   - If the title yields an empty slug, use `issue` as the slug

5. Record per issue:
   - Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`
   - Branch name: `linear-<issue_id>-<slug>`

## Phase 3: Match Existing Work by Issue Id

A ticket filename is stable, so `/create-worktree` treats its slug as authoritative. A Linear title is editable, so today's slug may differ from the one in use when the worktree was created, and matching the exact path would create a **second** worktree for an issue that already has one. Match by id prefix instead.

For each issue, in order:

1. **Existing worktree?** Scan `git worktree list --porcelain` for a registered path matching `$MAIN_ROOT/.worktrees/<issue_id>-*`. If one exists, mark the issue `skip — worktree already exists at <path>` and move on to the next issue.

2. **Existing branch?** Otherwise list candidates:
   ```
   git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'
   ```
   The `--format` is required: plain `git branch --list` prefixes `+ ` for a branch checked out in another worktree and `* ` for the current branch, and those markers are not part of the name.
   - **Exactly one match** → reuse that branch. Strip the leading `linear-` from it; the remainder is the worktree directory name, so path and branch stay coherent (branch `linear-ENG-42-old-title` → worktree `.worktrees/ENG-42-old-title`). If that differs from the Phase 2 slug, note it in the report — the issue title changed since the branch was made.
   - **Two or more matches** → report the ambiguity, skip this issue, continue with the rest of the batch. This is a per-issue error, not a batch abort.
   - **None** → keep the Phase 2 handles and create fresh.

## Phase 4: Prepare the Repo

1. Fetch the base branch from `origin`:
   ```
   git fetch origin <base>
   ```
   If `origin` does not exist or the fetch fails (no remote, no network, no such ref), continue with the local base branch and tell the user the worktree may be based on a stale ref.

2. Resolve the base reference in this order:
   - `origin/<base>` (preferred — freshly fetched).
   - Local `<base>` (fallback).
   - If neither exists, report `base branch '<base>' not found locally or on origin` and stop the batch before creating anything.

3. Ensure `.worktrees/` is ignored by git so the parent checkout doesn't see the new worktrees as untracked files. Read `$MAIN_ROOT/.gitignore`:
   - If the file is missing, create it with a single line `.worktrees/`.
   - If the file exists but contains no line that matches `.worktrees/?` (allowing a trailing slash), append `.worktrees/` on a new line.
   - If a matching line is already present, leave the file alone.
   - Note any change in the final report so the modification isn't silent. **Do not commit it** — that is the user's call. `/merge-worktree-linear` recognizes this exact state and offers to commit it when it would otherwise block a merge.

## Phase 5: Create the Worktrees

Process issues in the order they were given. For each issue not already skipped by Phase 3:

1. If a branch was matched in Phase 3 step 2, attach to it:
   ```
   git worktree add <worktree-path> <branch>
   ```
   Note in the report that the branch was reused rather than created — the user may have started this work earlier and we don't want to silently rebase.

2. Otherwise create the branch from the resolved base ref:
   ```
   git worktree add <worktree-path> -b <branch> <base-ref>
   ```

3. If `git worktree add` fails for a single issue (e.g. a stale registration in `.git/worktrees/`), report the error and continue with the rest. One bad issue shouldn't abort a batch where the others would succeed.

## Phase 6: Report

Print a summary the user can act on directly:

```
Created 2 worktree(s) from origin/main:

  ENG-42  .worktrees/ENG-42-add-csv-export   branch: linear-ENG-42-add-csv-export
  ENG-43  .worktrees/ENG-43-fix-search       branch: linear-ENG-43-fix-search

Open one with:
  cd .worktrees/ENG-42-add-csv-export

Implement in it with:
  /implement-ticket-linear ENG-42 worktree

Land it later with:
  /merge-worktree-linear ENG-42
```

If any issues were skipped (worktree already exists, ambiguous branch match) or failed (git error), list them in their own section with the reason. If `.gitignore` was created or modified, mention it. If a reused branch's slug differs from the current issue title's slug, say so.

Do not `cd` into the new worktree, do not install dependencies, and do not commit anything. The user runs each worktree's setup themselves.

## Safety Rules

- **No Linear writes of any kind.** Never change state, assignee, labels, priority, or any other field, and never post a comment. Reading the issue is the only Linear interaction.
- Stop the batch up front if any issue id fails to resolve — do not create some worktrees while leaving others broken.
- Do not delete or move existing worktrees, and do not force-create branches; reuse a matching branch instead.
- Do not commit the `.gitignore` change.
- Do not switch the branch of the user's main checkout.
- If Linear MCP is missing or an issue cannot be resolved uniquely, stop — do not guess a directory name from the raw identifier.
`````

- [ ] **Step 3: Write the Codex skill**

Create `.agents/skills/create-worktree-linear/SKILL.md`:

`````markdown
---
name: "create-worktree-linear"
description: "Use when the user explicitly asks to create one or more git worktrees for Linear issues, each as an isolated checkout on its own branch. Requires Linear MCP and makes no Linear writes. Prefer explicit invocation with $create-worktree-linear."
---

# Create Worktrees for Linear Issues

Create one or more git worktrees so the user can work on multiple **Linear** issues in parallel without juggling branches in the main checkout. Each worktree gets a fresh branch off the chosen base and lives at `.worktrees/<issue_id>-<slug>/` inside the repo. Treat this as an explicit workflow skill because it mutates the working tree and may modify `.gitignore`.

This is the Linear counterpart of `$create-worktree`; it does not read `docs/tickets/`. It **never writes to Linear** — it reads each issue for its title and nothing else, and it does not move a Todo issue into an in-progress state. `$implement-ticket-linear` makes that transition when work actually starts.

## Prerequisites

Linear MCP must be available and authenticated (`https://mcp.linear.app/mcp`). If it is missing, stop and say so; do not invent API-key, CLI, or browser fallbacks. Read tools only.

## Phase 1: Parse Arguments

1. Split the argument string on whitespace.
2. Classify each token:
   - **Issue reference** if it matches `^[A-Za-z]+-\d+$` (case-insensitive; uppercase the team key) or is a `linear.app` URL containing such an identifier.
   - **Base branch** otherwise. At most one; two or more → report the conflict and stop.
3. Require at least one issue reference. If none, ask and stop.
4. Default the base to `main`.

Examples:
- `$create-worktree-linear ENG-42` → issues `[ENG-42]`, base `main`
- `$create-worktree-linear ENG-42 ENG-43 dev` → issues `[ENG-42, ENG-43]`, base `dev`

**Trailing-token tiebreak.** The Linear id pattern collides with branch names like `release-2026`. If the trailing token fails to resolve as a Linear issue but resolves as a branch (`git rev-parse --verify --quiet origin/<token>`, then `<token>`), treat it as the base and say so in one line. If it resolves as neither, stop. If a branch and an issue share a name, the issue wins.

## Phase 2: Resolve Repo Root and Issues

1. Confirm we're in a git repo and resolve the **main** repo root so the skill works the same from any worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. Fetch each issue by exact identifier via Linear MCP. Not found (and not the trailing token) or ambiguous → stop the whole batch; partial creation hides the typo.
3. Capture each title and derive the **slug** exactly as `$implement-ticket-linear` does: lowercase, runs of non-alphanumerics to a single `-`, trim leading/trailing `-`, truncate to ~40 characters preferring a hyphen cut, fall back to `issue`.
4. Record per issue:
   - Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`
   - Branch name: `linear-<issue_id>-<slug>`

## Phase 3: Match Existing Work by Issue Id

Linear titles are editable, so an exact-path check would create a second worktree for an issue that already has one. Match by id prefix:

1. A registered path under `$MAIN_ROOT/.worktrees/<issue_id>-*` in `git worktree list --porcelain` → skip with a warning.
2. Else `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`. Use `--format`; plain output prefixes `+ ` and `* ` markers that are not part of the name.
   - One match → reuse it; strip the leading `linear-` for the worktree directory name so path and branch agree. Note a slug difference in the report.
   - Two or more → report the ambiguity, skip this issue, continue the batch.
   - None → create fresh.

## Phase 4: Prepare the Repo

1. `git fetch origin <base>`. If `origin` is missing or the fetch fails, continue with the local base and warn that the result may be stale.
2. Resolve the base ref: `origin/<base>` → local `<base>` → if neither exists, report and stop.
3. Ensure `.worktrees/` is ignored: create `$MAIN_ROOT/.gitignore` with that line if missing, append it if absent, leave it alone if present. Mention any change in the report and do not commit it — `$merge-worktree-linear` detects this state and offers to commit it when it blocks a merge.

## Phase 5: Create the Worktrees

For each issue, in order:

1. Branch matched in Phase 3 → `git worktree add <worktree-path> <branch>`; note the reuse.
2. Otherwise → `git worktree add <worktree-path> -b <branch> <base-ref>`.
3. If one issue fails, report the error and continue with the rest of the batch.

## Phase 6: Report

List each worktree path and branch, the base ref used, anything skipped or failed, and any `.gitignore` change. Point the user at `$implement-ticket-linear <issue> worktree` to implement and `$merge-worktree-linear <issue>` to land. Do not `cd` into the worktree, do not install dependencies, and do not commit anything.

## Safety Rules

- No Linear writes of any kind — no state change, no comment, no field edit.
- Stop the batch up front if any issue id fails to resolve.
- Do not delete or move existing worktrees; reuse a matching branch rather than force-creating one.
- Do not commit the `.gitignore` change, and do not switch the main checkout's branch.
`````

- [ ] **Step 4: Write the Codex interface contract**

Create `.agents/skills/create-worktree-linear/agents/openai.yaml`:

```yaml
interface:
  display_name: "Create Worktree (Linear)"
  short_description: "Create git worktrees for one or more Linear issues"
  default_prompt: "Read the requested Linear issues with $create-worktree-linear, resolve a base branch (default main), and create a git worktree per issue under .worktrees/<issue_id>-<slug> on a linear-<issue_id>-<slug> branch, without writing anything back to Linear."

policy:
  allow_implicit_invocation: false
```

- [ ] **Step 5: Create the Antigravity symlink**

```bash
cd /Users/calvinku/FunProjects/cktk/.agent/skills
ln -s ../../skills/create-worktree-linear create-worktree-linear
cd /Users/calvinku/FunProjects/cktk
readlink .agent/skills/create-worktree-linear   # expect: ../../skills/create-worktree-linear
```

- [ ] **Step 6: Add the validator helper**

In `scripts/check-codex-skills.sh`, find (the `forbid_stale_claim` helper, ~line 116-125):

```bash
# Same mechanism as forbid_literal, different reason: the text is not
# host-specific, it is a superseded guarantee that must not creep back in.
forbid_stale_claim() {
  local file="$1"
  local text="$2"

  if grep -Fq -- "$text" "$file"; then
    fail "$file contains a claim that is no longer true: $text"
  fi
}
```

Append immediately after it:

```bash
# Same mechanism again, third reason: the text names a Linear write tool in a
# skill whose contract is read-only.
forbid_write_call() {
  local file="$1"
  local text="$2"

  if grep -Fq -- "$text" "$file"; then
    fail "$file must not call a Linear write tool: $text"
  fi
}
```

- [ ] **Step 7: Add the contract function**

In `scripts/check-codex-skills.sh`, find the end of `validate_implement_contract` and the call block that follows it:

```bash
validate_clarify_contract
validate_interact_contract
validate_implement_contract
```

Replace with:

```bash
validate_worktree_linear_contract() {
  local skill_md

  # The Linear worktree twins share one naming contract with
  # implement-ticket-linear and update-ticket-linear: worktrees at
  # .worktrees/<issue_id>-<slug>, branches at linear-<issue_id>-<slug>.
  # Discovery in all four skills keys on those exact forms, so drift here
  # surfaces as a silently missing worktree rather than as an error.
  for skill_md in \
    "$claude_root/create-worktree-linear/SKILL.md" \
    "$codex_root/create-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "linear-<issue_id>-<slug>"
    require_literal "$skill_md" ".worktrees/<issue_id>-<slug>"
  done

  # create-worktree-linear prepares a workspace, so it must never write to
  # Linear — including the Todo -> In Progress transition its implement
  # sibling performs. The forbidden literal is the write tool rather than the
  # name of that transition, which the skill legitimately mentions when
  # explaining which write it declines to make.
  for skill_md in \
    "$claude_root/create-worktree-linear/SKILL.md" \
    "$codex_root/create-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "never writes to Linear"
    forbid_write_call "$skill_md" "save_issue"
  done
}

validate_clarify_contract
validate_interact_contract
validate_implement_contract
validate_worktree_linear_contract
```

- [ ] **Step 8: Run the validator (green)**

```bash
cd /Users/calvinku/FunProjects/cktk
./scripts/check-codex-skills.sh
```

Expected: `Validated 32 skill(s) across Claude, Codex, and Antigravity.` and exit 0. If it reports a missing literal, the SKILL.md wording drifted from the contract — fix the document, not the assertion.

- [ ] **Step 9: Smoke-test the creation sequence against real git**

The document prescribes these commands verbatim, so run them once against a scratch repo. Confirm `--format` yields a bare branch name and that `worktree add -b` off a remote ref works:

```bash
SP=$(mktemp -d)
cd "$SP" && git init -q --bare origin.git && git init -q repo && cd repo
git config user.email t@t.t && git config user.name T
echo hi > README.md && git add -A && git commit -qm init
git remote add origin ../origin.git && git push -q -u origin main
git worktree add .worktrees/ENG-42-add-csv-export -b linear-ENG-42-add-csv-export origin/main
git branch --list --format='%(refname:short)' 'linear-ENG-42-*'
git worktree list --porcelain | grep -E "^worktree .*/\.worktrees/ENG-42-"
cd / && rm -rf "$SP"
```

Expected: the branch listing prints exactly `linear-ENG-42-add-csv-export` with no `+` or `*` marker, and the porcelain grep matches one line.

- [ ] **Step 10: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/create-worktree-linear .agents/skills/create-worktree-linear \
        .agent/skills/create-worktree-linear scripts/check-codex-skills.sh
git commit -m "feat(create-worktree-linear): add the Linear twin of create-worktree

Creates one worktree per Linear issue at .worktrees/<issue_id>-<slug> on a
linear-<issue_id>-<slug> branch, the handles implement-ticket-linear and
update-ticket-linear already compute and discover.

Two rules the docs twin does not need. Linear titles are editable, so
matching is by issue-id prefix rather than exact slug — an exact-path check
would create a second worktree for an issue that already has one. And the
Linear id pattern collides with branch names like release-2026, so the
trailing token falls back to a resolve-as-branch check once it has failed to
resolve as an issue.

No Linear write of any kind; the validator forbids the write tool by name.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `merge-worktree-linear` across all three trees

**Files:**
- Create: `skills/merge-worktree-linear/SKILL.md`
- Create: `.agents/skills/merge-worktree-linear/SKILL.md`
- Create: `.agents/skills/merge-worktree-linear/agents/openai.yaml`
- Create: `.agent/skills/merge-worktree-linear` (symlink)
- Modify: `scripts/check-codex-skills.sh` (extend `validate_worktree_linear_contract` from Task 1)

**Interfaces:**
- Consumes: the handles Task 1 produces — worktrees at `.worktrees/<issue_id>-<slug>`, branches `linear-<issue_id>-<slug>`, and the id-prefix discovery form `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`.
- Produces: the skill name `merge-worktree-linear`, which Task 3 cross-references from four existing documents.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
ls skills/merge-worktree-linear 2>&1                          # expect: No such file or directory
grep -c "merge-worktree-linear" scripts/check-codex-skills.sh # expect 0
./scripts/check-codex-skills.sh | tail -1                     # expect: Validated 32 skill(s) ...
```

- [ ] **Step 2: Write the Claude skill**

Create `skills/merge-worktree-linear/SKILL.md`:

`````markdown
---
name: merge-worktree-linear
description: "Merge one or more Linear issue worktrees back into their base branch, then remove the worktree directory and delete the local branch. The cleanup half of /create-worktree-linear. Detects already-merged branches (e.g. merged via GitHub PR) and just cleans up in that case. Auto-commits any uncommitted implementation code in the worktree before merging (interactive Y/n prompt, defaults to yes). Pass `no-cleanup` to keep the local branch. Does not require Linear MCP and writes nothing to Linear. Triggers on: /merge-worktree-linear, merge Linear worktree, land Linear issue branch, clean up worktree after Linear issue, done with Linear issue worktree"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

Close the loop on `/create-worktree-linear`. Merge each Linear issue's branch back into its base, then remove the worktree directory and delete the local branch. If a branch was already merged remotely (typical after a GitHub PR merge), detect that and skip straight to cleanup so we don't create a redundant merge commit.

This skill **does not require Linear MCP**, and it is the only `-linear` skill that does not. The worktree path, the branch name, and the issue id are all on disk, so cleanup should not fail because a network service is unreachable. If Linear MCP happens to be available it is used for exactly one optional thing — reading an issue title for commit-message context during auto-commit — and its absence is never an error. This skill never writes to Linear; use `/update-ticket-linear <issue>` for that.

## Phase 1: Parse Arguments

Use the same grammar as `/create-worktree-linear` so users don't have to learn two. Split `$ARGUMENTS` on whitespace and classify each token:

- **Issue reference** — matches `^[A-Za-z]+-\d+$` (case-insensitive; uppercase the team key), or a `linear.app` URL containing such an identifier.
- **`no-cleanup` flag** — matches `^no-cleanup$` (case-insensitive). When set, the local branch is preserved after merging (the worktree directory is still removed). Duplicates are ignored. Does **not** consume the base-branch slot.
- **Base branch** — anything else. At most one base-branch token. Two or more non-issue, non-flag tokens → report the conflict and stop.

If no issue references are provided, ask the user for at least one and stop. If no base-branch token is provided, default the base to `main`.

| Invocation | Issues | Base | no-cleanup |
| --- | --- | --- | --- |
| `/merge-worktree-linear ENG-42` | ENG-42 | main | no |
| `/merge-worktree-linear ENG-42 ENG-43` | ENG-42, ENG-43 | main | no |
| `/merge-worktree-linear ENG-42 dev` | ENG-42 | dev | no |
| `/merge-worktree-linear ENG-42 no-cleanup` | ENG-42 | main | yes |
| `/merge-worktree-linear ENG-42 dev no-cleanup` | ENG-42 | dev | yes |

### The trailing-token tiebreak

The Linear identifier pattern collides with branch names like `release-2026`. Because this skill needs no Linear MCP, the tiebreak is resolved entirely on disk: if a trailing id-looking token has **no** registered worktree under `.worktrees/<token>-*` and **no** branch matching `linear-<token>-*`, but does resolve as a branch (`git rev-parse --verify --quiet origin/<token>`, then `<token>`), treat it as the base and say so in one line. If it resolves as neither, report it as an issue with nothing to merge.

## Phase 2: Resolve the Main Repo Root and Handles

1. Confirm we're inside a git repo. Resolve the **main** repo root so the skill behaves the same whether invoked from the main checkout or from another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```

2. For each issue, discover its handles on disk by id prefix — the canonical forms are `.worktrees/<issue_id>-<slug>` and `linear-<issue_id>-<slug>`, as created by `/create-worktree-linear` and `/implement-ticket-linear`:
   - **Worktree:** scan `git worktree list --porcelain` for a registered path matching `$MAIN_ROOT/.worktrees/<issue_id>-*`.
   - **Branch:** `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`. The `--format` is required: plain `git branch --list` prefixes `+ ` for a branch checked out in another worktree and `* ` for the current branch, and those markers are not part of the name.
   - Two or more matches for either → report the ambiguity, skip this issue, continue with the rest.
   - Neither a worktree nor a branch → record "already cleaned up" and continue.

## Phase 3: Pre-flight Checks

These run once before touching any issue. If any of them fail, stop the entire batch — a clean refusal is much better than a half-applied state.

1. **CWD must not be inside a target worktree.** If the user's current working directory is inside any worktree we're about to remove, removing it would orphan their shell. Compare `git rev-parse --show-toplevel` against each target worktree path. If there's a match, refuse and tell the user to `cd "$MAIN_ROOT"` first.

2. **Main checkout must be clean, with one carve-out.** The merge lands on the main checkout's HEAD, so uncommitted changes there would be at risk. Run `git -C "$MAIN_ROOT" status --porcelain`.

   `/create-worktree-linear` deliberately leaves `.gitignore` uncommitted after adding `.worktrees/` to it, which trips this check on the first run in any repo that had not already ignored `.worktrees/` — a refusal naming a cause the user did not create. So when the **only** entry is `.gitignore` (porcelain ` M .gitignore` for a modified file, or `?? .gitignore` for a newly created one) **and** its only change is the added `.worktrees/` line (verify with `git -C "$MAIN_ROOT" diff -- .gitignore`, or by reading the new file), ask once:

   ```
   .gitignore has an uncommitted `.worktrees/` line, left by /create-worktree-linear.
   Commit it so the merge can proceed? [Y/n]
   ```

   Anything but an explicit no commits just that file:
   `git -C "$MAIN_ROOT" add .gitignore && git -C "$MAIN_ROOT" commit -m "chore: ignore .worktrees/"`. On an explicit no, refuse the batch as below.

   For any other dirty state — or `.gitignore` plus anything else — refuse and tell the user to commit, stash, or discard.

3. **Fetch the base.** Run `git -C "$MAIN_ROOT" fetch origin <base>`. If `origin` is missing or the fetch fails, continue with the local base branch and warn the user that the result may be merging against a stale base.

4. **Resolve the base ref.** Prefer `origin/<base>`; fall back to local `<base>`. If neither exists, report `base branch '<base>' not found locally or on origin` and stop.

5. **Switch the main checkout to the base branch and fast-forward it.**
   - If local `<base>` exists: `git -C "$MAIN_ROOT" switch <base>`.
   - If it doesn't (only `origin/<base>` was found): `git -C "$MAIN_ROOT" switch -c <base> origin/<base>`.
   - Then `git -C "$MAIN_ROOT" merge --ff-only origin/<base>` (skip if there is no `origin/<base>`). If the fast-forward fails because the local base has diverged from origin, abort and report — that needs human judgment, not a default decision.

6. **Worktree dirty-state scan + auto-commit.** The natural flow is `/implement-ticket-linear ENG-42 worktree` → `/update-ticket-linear ENG-42` → `/merge-worktree-linear ENG-42`, and neither of those commits implementation code. Rather than refuse, detect it up front and offer to commit.

   For each target issue whose worktree exists on disk, run `git -C "<worktree_path>" status --porcelain`. If non-empty, record the issue plus counts of modified / added / deleted / untracked files derived from the porcelain codes (`M` / `A` / `D` / `??`).

   If the dirty list is empty, proceed to Phase 4. Otherwise present it in a single batched message and wait:

   ```
   Found uncommitted changes in 2 worktree(s):

     ENG-42  3 modified, 1 untracked   (.worktrees/ENG-42-add-csv-export)
     ENG-43  1 modified                (.worktrees/ENG-43-fix-search)

   Auto-commit each before merging? [Y/n]
   ```

   - **If yes** (default): for each dirty worktree, in order:
     1. Gather commit-message context. If Linear MCP is available, read the issue title; otherwise use the branch slug. Never fail because MCP is absent.
     2. Inspect the changes: `git -C "<worktree_path>" diff HEAD`, plus `git -C "<worktree_path>" status --porcelain` for untracked files.
     3. Generate a single conventional-style commit message reflecting the changes — subject ≤72 chars, referencing the issue as `<issue_id>`. Let the diff drive the message.
     4. Stage and commit: `git -C "<worktree_path>" add -A` then `git -C "<worktree_path>" commit -m "<message>"`.
     5. **If the commit fails** (e.g. a pre-commit hook blocks it), do **not** retry with `--no-verify`. Mark this issue with an error and continue with the next dirty worktree — Phase 4 step 2 then skips its merge because the worktree is still dirty.
     6. Tag issues committed here so Phase 5 can label them `auto-committed`.
   - **If no**: leave those worktrees alone. Phase 4 step 2's defensive dirty check skips them.

## Phase 4: Per-Issue Merge and Cleanup

Process issues in the order given. Each is independent — one failure should not stop the others.

For each `(issue_id, worktree_path, branch)`:

1. **Already cleaned up?** If neither the worktree path exists (registered in `git worktree list --porcelain`) nor the branch exists, record "already cleaned up" and continue.

2. **Worktree clean?** Defensive guard — by Phase 3 step 6 it should be. If the worktree exists and `git -C "<worktree_path>" status --porcelain` is still non-empty, skip with `uncommitted changes in <worktree_path> — auto-commit was declined or failed` and continue. Never silently lose uncommitted work.

3. **Already merged upstream?** Run `git -C "$MAIN_ROOT" merge-base --is-ancestor <branch> <base-ref>`. Exit code 0 means the branch is already in the base — the typical post-PR-merge state. Skip the merge and go to step 5.

4. **Merge the branch into the base.** From the main checkout:
   ```
   git -C "$MAIN_ROOT" merge --no-ff -m "Merge <branch> into <base>" <branch>
   ```
   `--no-ff` always produces a recognizable merge commit so the issue's work can be reverted as a single unit later.
   - **On conflict:** `git -C "$MAIN_ROOT" merge --abort` to clean up the half-merged state, record which files conflicted, skip cleanup for this issue, and continue with the next.
   - **On other failure:** record the error, skip cleanup for this issue, continue.

5. **Cleanup.** Remove the worktree **before** deleting the branch — `git branch -d/-D` refuses with `cannot delete branch '<branch>' used by worktree at '<path>'` while it is still checked out there.
   - `git -C "$MAIN_ROOT" worktree remove <worktree_path>` — removes the directory and unregisters it. If it fails because the worktree is missing on disk but still registered, run `git -C "$MAIN_ROOT" worktree prune` and retry once.
   - If it fails with `contains modified or untracked files`, **do not pass `--force`** — report it and retain the worktree. Ignored build output such as `node_modules/` does not trigger this; only modified or untracked files do, which means auto-commit was declined or partially failed and there is real work to preserve.
   - If the `no-cleanup` flag was passed, stop here: leave the local branch and record `branch retained (no-cleanup)`.
   - Otherwise: `git -C "$MAIN_ROOT" branch -D <branch>`. Force-delete is intentional and safe here — this step is reached only when the merge is confirmed, either by step 3's `--is-ancestor` check or step 4's successful `merge --no-ff`, so the branch's content is in the base. It is required for the common GitHub squash-/rebase-merge case, where the branch tip is no longer a strict ancestor of the merged base and `git branch -d` refuses.
   - If `branch -D` still fails (unexpected — e.g. another worktree references the branch), record the failure and continue.

## Phase 5: Report

Print a summary the user can scan at a glance:

```
Merged 4 worktree(s) into dev:

  ENG-42  auto-committed + merged + cleaned up
  ENG-43  merged + cleaned up
  ENG-44  already merged upstream — cleaned up
  ENG-45  merged + worktree removed — branch retained (no-cleanup)
  ENG-46  SKIPPED — uncommitted changes in .worktrees/ENG-46-fix-search (auto-commit declined or failed)
  ENG-47  CONFLICT — files: src/foo.ts, src/bar.ts (worktree retained)

main checkout is now on: dev (<short-hash>)

Linear status is not updated by this skill — run /update-ticket-linear ENG-42 done when ready.
```

Group entries by outcome (auto-committed-and-merged, merged-and-cleaned, already-merged-and-cleaned, branch-retained-by-flag, skipped, conflict, error) so the user immediately sees what needs follow-up. Issues whose changes were auto-committed in Phase 3 get the `auto-committed` prefix so those commits can be audited afterwards. The `branch retained (no-cleanup)` label is informational — the user asked for it.

Do not push to origin, and do not delete the remote branch. The only commits this skill ever creates are the merge commits in Phase 4, the user-confirmed auto-commits in Phase 3 step 6, and the user-confirmed `.gitignore` commit in Phase 3 step 2.

## Safety Rules

- **Never writes to Linear**, and never requires Linear MCP. Marking an issue done stays a deliberate, separate `/update-ticket-linear` step.
- Never push, never delete a remote branch, never open a PR.
- Never pass `--force` to `git worktree remove`, and never `--no-verify` to a commit.
- Never resolve a merge conflict — abort, report, and retain the worktree.
- Refuse the batch when the cwd is inside a target worktree, or when the main checkout is dirty beyond the `.gitignore` carve-out.
- Do not touch `docs/tickets/` — that is `/merge-worktree`'s domain.
`````

- [ ] **Step 3: Write the Codex skill**

Create `.agents/skills/merge-worktree-linear/SKILL.md`:

`````markdown
---
name: "merge-worktree-linear"
description: "Use when the user explicitly asks to merge one or more Linear issue worktrees back into their base branch and clean them up. Does not require Linear MCP and writes nothing to Linear. Prefer explicit invocation with $merge-worktree-linear."
---

# Merge Linear Issue Worktrees

Close the loop on `$create-worktree-linear`: merge each Linear issue's branch into its base, then remove the worktree and delete the local branch. Already-merged branches (typical after a GitHub PR merge) are detected and only cleaned up. Treat this as an explicit workflow skill because it merges, removes directories, and deletes branches.

This skill **does not require Linear MCP** — the worktree, the branch, and the issue id are all on disk, so cleanup must not fail because a service is unreachable. If MCP is present it is used only to read an issue title for commit-message context; its absence is never an error. It never writes to Linear; that is `$update-ticket-linear`'s job.

## Phase 1: Parse Arguments

1. Split on whitespace and classify:
   - **Issue reference** if it matches `^[A-Za-z]+-\d+$` (case-insensitive; uppercase the team key) or is a `linear.app` URL containing one.
   - **`no-cleanup` flag** if it matches `^no-cleanup$` (case-insensitive). Preserves the local branch; the worktree directory is still removed. Does not consume the base slot.
   - **Base branch** otherwise. At most one; two or more → report the conflict and stop.
2. Require at least one issue reference. Default the base to `main`.

Examples:
- `$merge-worktree-linear ENG-42` → issues `[ENG-42]`, base `main`
- `$merge-worktree-linear ENG-42 dev no-cleanup` → issues `[ENG-42]`, base `dev`, branch retained

**Trailing-token tiebreak, resolved on disk.** If a trailing id-looking token has no worktree under `.worktrees/<token>-*` and no branch matching `linear-<token>-*`, but resolves as a branch, treat it as the base and say so. Otherwise report it as an issue with nothing to merge.

## Phase 2: Resolve Repo Root and Handles

1. `MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`
2. Per issue, discover by id prefix — the canonical forms created by `$create-worktree-linear` and `$implement-ticket-linear` are `.worktrees/<issue_id>-<slug>` and `linear-<issue_id>-<slug>`:
   - Worktree: a registered path under `$MAIN_ROOT/.worktrees/<issue_id>-*` in `git worktree list --porcelain`.
   - Branch: `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`. `--format` is required; plain output carries `+ ` / `* ` markers that are not part of the name.
   - Two or more matches → report, skip that issue, continue. Neither → "already cleaned up".

## Phase 3: Pre-flight (once, whole batch)

1. **Refuse if the cwd is inside a target worktree** — removing it would orphan the shell. Tell the user to `cd "$MAIN_ROOT"`.
2. **Main checkout must be clean**, with one carve-out: `$create-worktree-linear` leaves `.gitignore` uncommitted after adding `.worktrees/`. When that file is the only dirty entry (` M .gitignore` or `?? .gitignore`) and its only change is that line, ask once — "Commit it so the merge can proceed? [Y/n]" — and on anything but an explicit no, commit just that file. Any other dirty state refuses.
3. `git -C "$MAIN_ROOT" fetch origin <base>`; on failure warn and continue with the local base.
4. Resolve the base ref: `origin/<base>` → local `<base>` → stop if neither.
5. Switch the main checkout to the base (`switch`, or `switch -c <base> origin/<base>`) and `merge --ff-only origin/<base>`. A diverged local base aborts the batch.
6. **Dirty-worktree scan.** For each target worktree, `git -C <path> status --porcelain`. Present all dirty worktrees in one batched message with modified/added/deleted/untracked counts and ask "Auto-commit each before merging? [Y/n]", default yes. On yes: read the issue title via MCP if available (else use the branch slug), inspect `diff HEAD`, then `add -A` and commit with a conventional message referencing the issue id. A failed commit is never retried with `--no-verify` — mark the issue and move on. On no, leave them; Phase 4 skips them.

## Phase 4: Per-Issue Merge and Cleanup

Independent per issue:

1. Neither worktree nor branch → "already cleaned up".
2. Worktree still dirty → skip with a reason; never lose uncommitted work.
3. `git -C "$MAIN_ROOT" merge-base --is-ancestor <branch> <base-ref>` exits 0 → already merged; go to step 5.
4. `git -C "$MAIN_ROOT" merge --no-ff -m "Merge <branch> into <base>" <branch>`. On conflict: `merge --abort`, report the files, retain the worktree, continue. On other failure: record and continue.
5. Cleanup, worktree first — `branch -d/-D` refuses while the branch is checked out in a worktree:
   - `git -C "$MAIN_ROOT" worktree remove <path>`; if it fails because the directory is gone but still registered, `worktree prune` and retry once.
   - If it fails with `contains modified or untracked files`, do **not** use `--force`: report and retain. Ignored build output does not trigger this, so the message means real work is present.
   - `no-cleanup` → stop here and record `branch retained (no-cleanup)`.
   - Else `git -C "$MAIN_ROOT" branch -D <branch>`. `-D` is required for GitHub squash-merges, where the tip is not an ancestor of the base; it is safe because this step is reached only after a confirmed merge.

## Phase 5: Report

Group by outcome (auto-committed+merged, merged+cleaned, already-merged+cleaned, branch-retained, skipped, conflict, error), name the base and the main checkout's new HEAD, and close with: Linear status is not updated by this skill — run `$update-ticket-linear <issue> done` when ready.

## Safety Rules

- No Linear writes, and no Linear MCP requirement.
- Never push, never delete a remote branch, never resolve a conflict.
- Never `--force` a `worktree remove`; never `--no-verify` a commit.
- Do not touch `docs/tickets/` — that is `$merge-worktree`'s domain.
`````

- [ ] **Step 4: Write the Codex interface contract**

Create `.agents/skills/merge-worktree-linear/agents/openai.yaml`:

```yaml
interface:
  display_name: "Merge Worktree (Linear)"
  short_description: "Merge and clean up Linear issue worktrees"
  default_prompt: "With $merge-worktree-linear, merge each requested Linear issue's linear-<issue_id>-<slug> branch into its base, then remove the worktree and delete the local branch, without pushing or writing anything to Linear."

policy:
  allow_implicit_invocation: false
```

- [ ] **Step 5: Create the Antigravity symlink**

```bash
cd /Users/calvinku/FunProjects/cktk/.agent/skills
ln -s ../../skills/merge-worktree-linear merge-worktree-linear
cd /Users/calvinku/FunProjects/cktk
readlink .agent/skills/merge-worktree-linear   # expect: ../../skills/merge-worktree-linear
```

- [ ] **Step 6: Extend the contract function**

In `scripts/check-codex-skills.sh`, inside `validate_worktree_linear_contract`, find the naming-contract loop:

```bash
  for skill_md in \
    "$claude_root/create-worktree-linear/SKILL.md" \
    "$codex_root/create-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "linear-<issue_id>-<slug>"
    require_literal "$skill_md" ".worktrees/<issue_id>-<slug>"
  done
```

Replace with:

```bash
  for skill_md in \
    "$claude_root/create-worktree-linear/SKILL.md" \
    "$codex_root/create-worktree-linear/SKILL.md" \
    "$claude_root/merge-worktree-linear/SKILL.md" \
    "$codex_root/merge-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "linear-<issue_id>-<slug>"
    require_literal "$skill_md" ".worktrees/<issue_id>-<slug>"
  done
```

Then find the closing brace of `validate_worktree_linear_contract`:

```bash
    require_literal "$skill_md" "never writes to Linear"
    forbid_write_call "$skill_md" "save_issue"
  done
}
```

Replace with:

```bash
    require_literal "$skill_md" "never writes to Linear"
    forbid_write_call "$skill_md" "save_issue"
  done

  # merge-worktree-linear deliberately works without Linear MCP: the worktree,
  # the branch, and the issue id are all on disk, so cleanup must not fail
  # because a service is unreachable. This is the only -linear skill with no
  # MCP prerequisite, which makes it the easiest one to "fix" by mistake.
  for skill_md in \
    "$claude_root/merge-worktree-linear/SKILL.md" \
    "$codex_root/merge-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "does not require Linear MCP"
  done
}
```

- [ ] **Step 7: Run the validator (green)**

```bash
cd /Users/calvinku/FunProjects/cktk
./scripts/check-codex-skills.sh
```

Expected: `Validated 33 skill(s) across Claude, Codex, and Antigravity.` and exit 0.

- [ ] **Step 8: Smoke-test the merge and cleanup sequence against real git**

The document prescribes these verbatim. Confirm the squash-merge case needs `-D`, that removal ordering matters, and that ignored files do not block removal:

```bash
SP=$(mktemp -d)
cd "$SP" && git init -q repo && cd repo
git config user.email t@t.t && git config user.name T
printf '.worktrees/\nnode_modules/\n' > .gitignore
echo hi > README.md && git add -A && git commit -qm init
git worktree add -q .worktrees/ENG-42-demo -b linear-ENG-42-demo HEAD
cd .worktrees/ENG-42-demo && echo x > x.ts && git add -A && git commit -qm "feat: x"
mkdir -p node_modules && echo junk > node_modules/j.txt
cd "$SP/repo"
git merge -q --squash linear-ENG-42-demo && git commit -qm "feat: x (squashed)"
git merge-base --is-ancestor linear-ENG-42-demo HEAD && echo "ancestor" || echo "NOT ancestor -> -D required"
git branch -d linear-ENG-42-demo 2>&1 | head -1
git worktree remove .worktrees/ENG-42-demo && echo "removed despite node_modules"
git branch -D linear-ENG-42-demo && echo "branch deleted after worktree removal"
cd / && rm -rf "$SP"
```

Expected: `NOT ancestor -> -D required`; the `branch -d` attempt prints `error: cannot delete branch ... used by worktree at ...`; removal succeeds despite the ignored `node_modules/`; the final `-D` succeeds only after the worktree is gone.

- [ ] **Step 9: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/merge-worktree-linear .agents/skills/merge-worktree-linear \
        .agent/skills/merge-worktree-linear scripts/check-codex-skills.sh
git commit -m "feat(merge-worktree-linear): add the cleanup half for Linear worktrees

Merges each linear-<issue_id>-<slug> branch into its base, removes the
worktree, and deletes the branch, with the same already-merged detection and
auto-commit prompt merge-worktree uses for docs tickets.

Deliberately requires no Linear MCP: the worktree, the branch, and the issue
id are all on disk, so cleanup cannot fail on transport. MCP, when present,
only supplies an issue title for commit-message context.

Two behaviors verified against real git rather than assumed. A squash-merged
branch is not an ancestor of its base, so -D is required where -d refuses;
and worktree removal must precede branch deletion, since git refuses to
delete a branch checked out in a worktree. Removal is never forced —
node_modules-style ignored output does not block it, so that error always
means unsaved work.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Fix the six stale cross-references

**Files:**
- Modify: `skills/implement-ticket-linear/SKILL.md:275` (Worktree Note) and `:305` (Phase 9 option 1)
- Modify: `.agents/skills/implement-ticket-linear/SKILL.md:120` and `:142`
- Modify: `skills/update-ticket-linear/SKILL.md:203` (Phase 8 Next step)
- Modify: `.agents/skills/update-ticket-linear/SKILL.md:114`
- Modify: `scripts/check-codex-skills.sh` (extend `validate_worktree_linear_contract`)

**Interfaces:**
- Consumes: the skill name `merge-worktree-linear` from Task 2.
- Produces: nothing new. No control flow changes — `implement-ticket-linear` keeps merging inline, per spec decision 2.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -rn "merge-worktree" skills/implement-ticket-linear/SKILL.md skills/update-ticket-linear/SKILL.md \
  .agents/skills/implement-ticket-linear/SKILL.md .agents/skills/update-ticket-linear/SKILL.md
```

Expected: six matches, none of which mention `merge-worktree-linear`.

- [ ] **Step 2: Fix the Claude `implement-ticket-linear` worktree note**

Find (line 275):

```
- **Land:** Phase 9 below offers to do this for you. Note that `/merge-worktree` is for markdown `TICKET-NNN` worktrees and will **not** work for Linear branches, so Phase 9 performs the merge inline.
```

Replace with:

```
- **Land:** Phase 9 below offers to do this for you. `/merge-worktree` is for markdown `TICKET-NNN` worktrees and will **not** work for Linear branches, so Phase 9 performs the merge inline. If you pick option 4 now, `/merge-worktree-linear <issue_id>` lands it later as a standalone step.
```

- [ ] **Step 3: Fix the Claude `implement-ticket-linear` option 1 justification**

Find (line 305):

```
`/merge-worktree` only understands markdown `TICKET-NNN` worktrees, so both modes merge inline:
```

Replace with:

```
`/merge-worktree` only understands markdown `TICKET-NNN` worktrees, so both modes merge inline. (`/merge-worktree-linear` does understand Linear worktrees, but it is a standalone cleanup command that refuses to run from inside the worktree this phase is pinned to — so it stays the user's later choice, not a delegation target here.)
```

- [ ] **Step 4: Fix the Claude `update-ticket-linear` next step**

Find (lines 199-208):

````
7. **Next step for this issue** when `WORK_DIR` is a matching linear worktree or branch and the target was completed:

```
## Next step
Linear status is updated. Land the branch manually — $merge-worktree only understands markdown TICKET-NNN worktrees:

git checkout <base>
git merge linear-<issue_id>-<slug>
# or: push the branch and open a PR
```
````

Replace with:

````
7. **Next step for this issue** when `WORK_DIR` is a matching linear worktree or branch and the target was completed:

```
## Next step
Linear status is updated. Land the branch with:

/merge-worktree-linear <issue_id>

It merges into main by default — pass a base branch as a second argument to
target another. Or do it by hand:

git checkout <base>
git merge linear-<issue_id>-<slug>
# or: push the branch and open a PR
```
````

- [ ] **Step 5: Fix the Codex `implement-ticket-linear` references**

Find (line 120):

```
7. If worktree mode: path, branch, and base. Note that `$merge-worktree` only understands markdown `TICKET-NNN` worktrees, so Phase 8 merges inline.
```

Replace with:

```
7. If worktree mode: path, branch, and base. Note that `$merge-worktree` only understands markdown `TICKET-NNN` worktrees, so Phase 8 merges inline; `$merge-worktree-linear <issue_id>` is the standalone way to land it later.
```

Find (line 142):

```
**Option 1 — merge into `<base>`.** Both modes merge inline, since `$merge-worktree` only understands markdown tickets:
```

Replace with:

```
**Option 1 — merge into `<base>`.** Both modes merge inline, since `$merge-worktree` only understands markdown tickets and `$merge-worktree-linear` refuses to run from inside the worktree this phase is pinned to:
```

- [ ] **Step 6: Fix the Codex `update-ticket-linear` reference**

Find (line 114):

```
6. If completed in a matching linear worktree, give **manual land** instructions — `$merge-worktree` only understands markdown `TICKET-NNN` worktrees:
```

Replace with:

```
6. If completed in a matching linear worktree, point at `$merge-worktree-linear <issue_id>` to land it (base defaults to main; pass another as a second argument), and give the manual `git checkout <base>` / `git merge linear-<issue_id>-<slug>` fallback — `$merge-worktree` itself only understands markdown `TICKET-NNN` worktrees:
```

- [ ] **Step 7: Pin the cross-reference in the validator**

In `scripts/check-codex-skills.sh`, find the closing brace of `validate_worktree_linear_contract`:

```bash
  for skill_md in \
    "$claude_root/merge-worktree-linear/SKILL.md" \
    "$codex_root/merge-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "does not require Linear MCP"
  done
}
```

Replace with:

```bash
  for skill_md in \
    "$claude_root/merge-worktree-linear/SKILL.md" \
    "$codex_root/merge-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "does not require Linear MCP"
  done

  # Both Linear skills that produce a linear-<issue_id>-<slug> branch used to
  # tell the user it could only be landed by hand. Keep the pointer to the
  # cleanup twin from rotting back to that advice.
  for skill_md in \
    "$claude_root/implement-ticket-linear/SKILL.md" \
    "$codex_root/implement-ticket-linear/SKILL.md" \
    "$claude_root/update-ticket-linear/SKILL.md" \
    "$codex_root/update-ticket-linear/SKILL.md"; do
    require_literal "$skill_md" "merge-worktree-linear"
  done
}
```

- [ ] **Step 8: Run the validator (green)**

```bash
cd /Users/calvinku/FunProjects/cktk
./scripts/check-codex-skills.sh
grep -c "Land the branch manually" skills/update-ticket-linear/SKILL.md   # expect 0
```

Expected: `Validated 33 skill(s) ...`, exit 0, and the stale phrase gone.

- [ ] **Step 9: Verify no control flow changed**

```bash
cd /Users/calvinku/FunProjects/cktk
git diff --stat
git diff skills/implement-ticket-linear/SKILL.md | grep -E "^[+-]" | grep -vE "^(\+\+\+|---)" | wc -l
```

Expected: exactly four files changed; the `implement-ticket-linear` diff is 4 lines (two removed, two added). If more, an edit strayed beyond a cross-reference.

- [ ] **Step 10: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add skills/implement-ticket-linear/SKILL.md skills/update-ticket-linear/SKILL.md \
        .agents/skills/implement-ticket-linear/SKILL.md .agents/skills/update-ticket-linear/SKILL.md \
        scripts/check-codex-skills.sh
git commit -m "docs(linear-skills): point at merge-worktree-linear for landing

Six references across four documents told the user a linear-* branch could
only be landed by hand, or by the inline merge in implement-ticket-linear's
landing phase. That was true until this branch; now there is a command.

No control flow changes. implement-ticket-linear keeps merging inline
deliberately: merge-worktree-linear refuses to run from inside the worktree
that phase pins its cwd to, which is the delegation defect AGENTS.md rule 6
already documents. The notes now say why rather than implying no twin exists.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Register both skills in the repo metadata

**Files:**
- Modify: `README.md` (skills table ~line 48-49; `.agents/skills/` listing ~line 138-139; install loop ~line 186; usage examples ~line 241-248)
- Modify: `catalog.json` (after the `merge-worktree` entry, ~line 76)

**Interfaces:**
- Consumes: both skill names and their argument grammars from Tasks 1 and 2.
- Produces: nothing other tasks depend on. This is the last task.

- [ ] **Step 1: Verify the current state (red)**

```bash
cd /Users/calvinku/FunProjects/cktk
grep -c "create-worktree-linear" README.md catalog.json   # expect 0 and 0
```

- [ ] **Step 2: Add both rows to the README skills table**

Find (lines 48-49):

```
| `create-worktree` | Create git worktrees for one or more tickets under `.worktrees/NNN-slug/`, each on its own branch off a chosen base | |
| `merge-worktree` | Merge ticket worktree branches back into their base, then remove the worktree and delete the local branch | Cleanup half of `create-worktree` |
```

Replace with:

```
| `create-worktree` · `create-worktree-linear` | Create git worktrees for one or more tickets under `.worktrees/NNN-slug/` or Linear issues under `.worktrees/ENG-42-slug/`, each on its own branch off a chosen base | Linear twin requires Linear MCP and makes no Linear writes — not even the Todo → In Progress transition `implement-ticket-linear` performs |
| `merge-worktree` · `merge-worktree-linear` | Merge ticket or Linear issue worktree branches back into their base, then remove the worktree and delete the local branch | Cleanup halves of the two create skills. The Linear twin is the one `-linear` skill that needs no Linear MCP — everything it reads is on disk |
```

- [ ] **Step 3: Add both to the `.agents/skills/` listing**

Find (lines 138-139):

```
.agents/skills/create-worktree
.agents/skills/merge-worktree
```

Replace with:

```
.agents/skills/create-worktree
.agents/skills/create-worktree-linear
.agents/skills/merge-worktree
.agents/skills/merge-worktree-linear
```

- [ ] **Step 4: Add both to the install loop**

Find (line 186), the `for s in ...` list, and replace the segment `create-worktree merge-worktree` with:

```
create-worktree create-worktree-linear merge-worktree merge-worktree-linear
```

The full line after the edit:

```bash
for s in create-tickets implement-ticket clarify-ticket clarify-ticket-linear implement-ticket-linear review-ticket update-ticket update-ticket-linear quiz-ticket quiz-ticket-linear commit-ticket commit-push-pr create-worktree create-worktree-linear merge-worktree merge-worktree-linear feature-catalog cktk-upgrade codex-handoff grok-handoff opencode-handoff takeover interact-html readme-builder design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign cinematic-design-system gen-image-codex gen-image-agy; do
```

- [ ] **Step 5: Add usage examples**

Find (lines 243-249):

````
```text
/commit-ticket                     # Commit current changes
/commit-push-pr                    # Commit, push, and open a PR
/create-worktree 7                 # Worktree for ticket 007 off origin/main
/create-worktree 7 8 9 dev         # Several tickets at once, based on origin/dev
/merge-worktree 7                  # Merge ticket 007 back, remove worktree, delete branch (same multi-ticket and base args)
```
````

Replace with:

````
```text
/commit-ticket                        # Commit current changes
/commit-push-pr                       # Commit, push, and open a PR
/create-worktree 7                    # Worktree for ticket 007 off origin/main
/create-worktree 7 8 9 dev            # Several tickets at once, based on origin/dev
/merge-worktree 7                     # Merge ticket 007 back, remove worktree, delete branch (same multi-ticket and base args)
/create-worktree-linear ENG-42        # Worktree for Linear issue ENG-42 off origin/main
/create-worktree-linear ENG-42 ENG-43 dev   # Several issues at once, based on origin/dev
/merge-worktree-linear ENG-42         # Merge ENG-42 back, remove worktree, delete branch
/merge-worktree-linear ENG-42 no-cleanup    # Merge and remove the worktree, but keep the branch
```
````

- [ ] **Step 6: Add both catalog entries**

In `catalog.json`, find the `merge-worktree` entry (lines 72-76):

```json
    {
      "name": "merge-worktree",
      "path": ".agent/skills/merge-worktree",
      "description": "Merge ticket worktrees back into their base branch, then remove the worktree and delete the local branch"
    },
```

Replace with:

```json
    {
      "name": "merge-worktree",
      "path": ".agent/skills/merge-worktree",
      "description": "Merge ticket worktrees back into their base branch, then remove the worktree and delete the local branch"
    },
    {
      "name": "create-worktree-linear",
      "path": ".agent/skills/create-worktree-linear",
      "description": "Create git worktrees for one or more Linear issues, each on its own branch under .worktrees/<issue_id>-<slug> (requires Linear MCP, makes no Linear writes; Linear twin of create-worktree)"
    },
    {
      "name": "merge-worktree-linear",
      "path": ".agent/skills/merge-worktree-linear",
      "description": "Merge Linear issue worktrees back into their base branch, then remove the worktree and delete the local branch (no Linear MCP required; Linear twin of merge-worktree)"
    },
```

- [ ] **Step 7: Verify the metadata**

```bash
cd /Users/calvinku/FunProjects/cktk
python3 -c "import json;d=json.load(open('catalog.json'));print(len(d['skills']),'entries');print([s['name'] for s in d['skills'] if 'worktree' in s['name']])"
grep -c "create-worktree-linear\|merge-worktree-linear" README.md
./scripts/check-codex-skills.sh
```

Expected: catalog parses, lists all four worktree skills; README has 8 or more matches; validator exits 0.

- [ ] **Step 8: Confirm every tree agrees on the skill set**

```bash
cd /Users/calvinku/FunProjects/cktk
diff <(ls skills) <(ls .agents/skills) && diff <(ls skills) <(ls .agent/skills) && echo "three trees agree"
```

Expected: `three trees agree`.

- [ ] **Step 9: Commit**

```bash
cd /Users/calvinku/FunProjects/cktk
git add README.md catalog.json
git commit -m "docs(readme,catalog): register the Linear worktree twins

Adds create-worktree-linear and merge-worktree-linear to the skills table,
the Codex install listing, the Antigravity install loop, the usage examples,
and the catalog. Plugin keywords are untouched — neither existing worktree
skill appears there.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Verification

After Task 4, the whole change is verifiable without a Linear workspace:

```bash
cd /Users/calvinku/FunProjects/cktk
./scripts/check-codex-skills.sh                          # 33 skills, exit 0
diff <(ls skills) <(ls .agents/skills)                   # no output
diff <(ls skills) <(ls .agent/skills)                    # no output
grep -rn "merge-worktree-linear" skills/ .agents/skills/ | wc -l   # >= 8
```

What still needs a live Linear workspace, and should be exercised by hand once:

1. `/create-worktree-linear ENG-42` creates `.worktrees/ENG-42-<slug>` on `linear-ENG-42-<slug>`, then `/implement-ticket-linear ENG-42 worktree` reuses it rather than creating a second worktree.
2. A batch with one bad id (`/create-worktree-linear ENG-42 ENG-999999`) creates nothing.
3. `/create-worktree-linear ENG-42 release-2026` treats `release-2026` as the base, given such a branch exists.
4. `/merge-worktree-linear ENG-42` on a fresh clone offers the `.gitignore` commit, merges, removes the worktree, and deletes the branch — with Linear MCP disconnected.
