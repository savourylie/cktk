---
name: update-ticket-linear
description: "Update a Linear issue status after evaluating acceptance criteria against the codebase (including matching linear worktrees). Cascades blocked relations when safe. Requires Linear MCP. Triggers on: /update-ticket-linear, /update-ticket-linear ENG-42, /update-ticket-linear ENG-42 done, mark Linear issue done, update Linear status, close Linear ticket"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a Linear issue status manager. Your job is to evaluate acceptance criteria against the codebase (including work done in `.worktrees/` by `/implement-ticket-linear`), update the Linear issue state via Linear MCP, cascade unblocked relations when safe, and report clearly. Follow each phase precisely.

**This skill does not use `docs/tickets/`.** The Linear issue is the source of truth. It does **not** create a git commit.

## Prerequisites

1. **Linear MCP** must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp). Read **and write** tools are required (get/list/search issue, list workflow states, update issue, create comment as available).
2. If Linear MCP tools are missing, stop with a short setup hint. Do **not** invent API-key, CLI, or browser fallbacks.
3. Prefer the host's actual Linear MCP tool names (discover them; do not invent schema fields). Typical operations: get issue, list team states, update issue state/description, create comment, list related issues.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Auto mode: evaluate AC; set Done only when safe. |
| `<issue> <status>` | Explicit status (cktk alias or Linear state name). |
| (empty) | Auto-detect issue from branch / worktree, then auto status. |

`<issue>` is either:

- A Linear identifier `TEAM-NUMBER` (e.g. `ENG-42`, `CKTK-7`) — case-insensitive; normalize the team key to uppercase.
- A Linear issue URL containing that identifier (e.g. `https://linear.app/acme/issue/ENG-42/add-export`).

`<status>` may be:

- A cktk alias: `done`, `in-progress`, `pending`, `blocked`, `deferred`
- An exact Linear workflow state name for the issue's team (e.g. `In Progress`, `Todo`, `Canceled`)

If no status token is provided, record the target as `auto`.

**Not accepted:** multi-issue batches, free-text title search alone, git commit flags, assignee/priority rewrites as the primary action.

## Phase 1: Parse Arguments & Resolve Handles

1. **Resolve repo roots.** Confirm you're inside a git repo, then compute:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. **Parse `$ARGUMENTS`.** Split on whitespace.
   - If the first token looks like an issue id (`TEAM-NUM`) or a URL, treat it as `issue_ref`. Optional second token is `status_token`.
   - If `$ARGUMENTS` is empty, run **auto-detect** (steps 1a–1c) to resolve `issue_ref`, then continue with `status_token` absent (`auto`).
   - If a first token is present but is neither an issue id/URL nor empty, stop with an unrecognized-arguments error.
   - Extra tokens beyond issue + optional status → stop with unrecognized-arguments.

### Auto-detect (only when `$ARGUMENTS` is empty)

**1a. Current branch.** Run `git branch --show-current`. If it matches `^linear-([A-Za-z]+-[0-9]+)-`, extract the issue id, uppercase the team key, set `WORK_DIR=$CURRENT_ROOT`, tell the user in one line, and proceed.

**1b. Registered linear worktrees.** Inspect `git worktree list --porcelain` for paths under `$MAIN_ROOT/.worktrees/`. For each path:

- Read `git -C <path> branch --show-current`. If it matches `^linear-([A-Za-z]+-[0-9]+)-`, capture the issue id.
- Treat as a candidate when there is work to evaluate: non-empty `status --porcelain`, or commits beyond the best available base (upstream → `$MAIN_ROOT` HEAD → `origin/main` → `main`).

**1c. Resolve candidates.**

- **1 candidate** — use it; set `WORK_DIR` to that worktree path; announce detection.
- **2+ candidates** — use `AskUserQuestion` to pick (label with issue id + worktree path). Cap listed options at 4; rely on "Other" for the rest.
- **0 candidates** — stop: `No issue was passed, the current branch isn't a linear-<ISSUE>-* branch, and no matching linear worktree has detectable work. Please pass an issue id (e.g., /update-ticket-linear ENG-42).`

3. **Normalize `issue_id`:**
   - `^[A-Za-z]+-\d+$` → uppercase team key
   - URL → extract first `TEAM-NUM` path segment; fail if none
4. **Record target status:**
   - No status token → `auto`
   - Known alias or freeform Linear state name → keep as provided (case preserved for freeform names; aliases lowercased)

## Phase 2: Fetch Linear Issue

1. Confirm Linear MCP write-capable tools are present. If not, stop with the setup hint.
2. Fetch the issue by `issue_id` (exact match). Missing or ambiguous → stop.
3. Capture:
   - Title, URL if known
   - Description / body (full text)
   - Current workflow state name + type if available
   - Team id/key (needed for state mapping)
   - Priority, labels, project, cycle (if present)
   - Relations: **blocks**, **blocked by**, related (if MCP returns them)
   - Acceptance criteria: checklist lines in the body (`- [ ]` / `- [x]`), or a clearly labeled Acceptance Criteria section
4. Derive **slug** from the title (same rules as `/implement-ticket-linear`):
   - Lowercase; non-alphanumerics → `-`; collapse; trim; ~40 chars; fallback `issue`
5. Compute worktree handles (always):
   - Path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`
   - Branch: `linear-<issue_id>-<slug>`
6. If current state already matches the explicit target (after mapping in Phase 5), report idempotent and **stop**. For `auto`, continue to evaluation.

## Phase 3: Resolve Working Directory

If `WORK_DIR` was not set by auto-detect:

1. Prefer `$CURRENT_ROOT` when its branch matches `^linear-<issue_id>-.+$`.
2. Else if `$MAIN_ROOT/.worktrees/<issue_id>-*` exists (exact slug path first, else any registered path starting with `$MAIN_ROOT/.worktrees/<issue_id>-`) and is a registered worktree, use it and tell the user in one line.
3. Otherwise `WORK_DIR=$CURRENT_ROOT`.

All evidence gathering runs against `WORK_DIR`.

## Phase 4: Evaluate Acceptance Criteria

**Skip this phase entirely if** the target status is not `done` and not `auto`.
**Skip if** all checklist criteria are already checked (`- [x]`).
**Skip if** the issue has no checklist / Acceptance Criteria section — treat as all met; log a note.

### 4.1 Gather evidence

1. `git -C "$WORK_DIR" status --porcelain`
2. `git -C "$WORK_DIR" diff` and `diff --cached`
3. If `WORK_DIR` is under `$MAIN_ROOT/.worktrees/`, also inspect `git -C "$WORK_DIR" diff <base>...HEAD` with base preference: upstream → `$MAIN_ROOT` HEAD → `origin/main` → `main`.
4. Read files referenced in the issue body or changed in any diff.

### 4.2 Evaluate each unchecked criterion

For each `- [ ]` line:

1. Search under `WORK_DIR` (grep/glob/reads) for evidence.
2. For test/build criteria, run the command and check exit code.
3. For manual/visual criteria, verdict `manual`.
4. Verdict: `met`, `unmet`, or `manual`.

### 4.3 Determine status

- **Auto mode:**
  - All `met` (or `met` + `manual`, none `unmet`) → target = `done`
  - Any `unmet` → report findings, **do not write Linear**, stop
- **Explicit `done` (alias or a completed-type state name):**
  - All `met` → proceed
  - Any `unmet` → present report and ask user to confirm. Decline → stop. Confirm → proceed with done
- **Other explicit statuses:** evaluation already skipped; proceed to mapping

### 4.4 Report evaluation

Present before writing Linear:

```
## Acceptance Criteria Evaluation — ISSUE-ID

**Result**: X/Y criteria met, Z require manual verification

- [x] Criterion A — verified: found in `src/...`
- [ ] Criterion B — UNMET: ...
- [ ] Criterion C — MANUAL: ...
```

## Phase 5: Map Status → Linear Workflow State

1. List workflow states for the issue's team via Linear MCP.
2. Resolve `target_state_name`:
   - If the user passed an exact state name that matches a team state (case-insensitive), use that state.
   - Else map aliases:
     | Alias | Prefer |
     | --- | --- |
     | `done` | First state with type completed / name Done or Completed |
     | `in-progress` | First state with type started / name In Progress or Started |
     | `pending` | First unstarted-type state preferring Todo, then Backlog, then Unstarted |
     | `blocked` | State whose name contains Block (case-insensitive); if none, stop and list states |
     | `deferred` | State matching Deferred, Canceled, or Cancelled; if none, stop and list states |
3. If mapping is ambiguous (multiple equally good matches), list candidates and ask.
4. If the issue is already in `target_state_name`, report and **stop** (idempotent).

## Phase 6: Update Linear

1. **Update issue state** to `target_state_name` via Linear MCP.
2. **Description checkboxes** (only when target is done and Phase 4 ran): if the MCP can update description, check only criteria evaluated as `met` (`- [ ]` → `- [x]`). Leave `unmet` and `manual` unchecked. If description update is unsupported, skip and note it.
3. **Comment** (when Phase 4 ran): post a concise comment with the evaluation summary and the state change. If comment tools are missing, skip and note it — state update still counts as success.
4. Do **not** change assignee, priority, labels, project, or cycle unless the user explicitly asked in this invocation.

## Phase 7: Cascade Dependencies (done only)

Skip unless the resolved target is a completed-type state (`done` alias or equivalent).

1. From relations, collect issues **blocked by** the completed issue (this issue **blocks** them).
2. For each dependent:
   a. Fetch its blockers and current state.
   b. If **all** blockers are now completed **and** the dependent's state name clearly indicates blocked (name contains `Block`), move it to the team's default pending-like state (`pending` alias mapping from Phase 5).
   c. If the dependent is not in a blocked-named state, **do not** auto-move — only report it as potentially ready.
   d. If cascade mapping is unsafe/ambiguous for a dependent, report only; do not force.
3. Record every issue actually moved for the summary.

## Phase 8: Summary

Report:

1. Issue id, title, URL if known
2. Previous state → new state
3. Whether evaluation used main checkout or `.worktrees/<issue_id>-<slug>`
4. Acceptance criteria evaluation (if run)
5. Comment / description-checkbox outcomes
6. **Issues ready / unblocked** (when completed):
   - Bulleted list of dependents that are now free of open blockers
   - Annotate ones that were auto-moved with `(moved to <state>)`
   - If none, say so
7. **Next step for this issue** when `WORK_DIR` is a matching linear worktree or branch and the target was completed. Which of the two variants you print depends on whether the worktree still exists on disk — scan `git worktree list --porcelain` for a registered path under `$MAIN_ROOT/.worktrees/<issue_id>-`:

   **Worktree exists** — `/merge-worktree-linear` can land it:

   ```
   ## Next step
   Linear status is updated. Land the branch with:

   /merge-worktree-linear <issue_id>

   It merges into main by default — pass a base branch as a second argument to
   target another. It auto-commits whatever is still uncommitted in the worktree
   before merging, so you do not need to commit first. Or do it by hand:

   git checkout <base>
   git merge linear-<issue_id>-<slug>
   # or: push the branch and open a PR
   ```

   **Branch only, no worktree** — print the manual commands and do **not** name `/merge-worktree-linear`:

   ```
   ## Next step
   Linear status is updated. Land the branch by hand:

   git checkout <base>
   git merge linear-<issue_id>-<slug>
   # or: push the branch and open a PR
   ```

   **Being on branch `linear-<issue_id>-<slug>` is not sufficient on its own.** `/implement-ticket-linear` creates that branch on every run, including current-checkout mode where no worktree is ever created, so the branch-only case is the common one rather than an edge. `/merge-worktree-linear`'s auto-commit carve-out covers worktrees only; in current-checkout mode the implementation is still sitting uncommitted in the main checkout — and `/update-ticket-linear` never commits — which is precisely the state that skill refuses to run in. Naming it there would point the user at a skill that cannot serve them.

8. Explicit note: **no git commit was created**.

## Safety Rules

- **Always** require Linear MCP; never invent Linear HTTP/API workarounds.
- **Never** commit git changes; do not invoke `/commit-ticket`, `/commit-push-pr`, or `/update-ticket`.
- Do not read or write `docs/tickets/` as the ticket source.
- Do not create, archive, or delete Linear issues.
- Do not reassign or retarget project/cycle/priority unless the user asked.
- Auto mode with unmet AC → no Linear writes.
- Explicit done with unmet AC → confirm first.
- Prefer matching `.worktrees/<issue_id>-*` for evidence when present.
- If unrelated dirty changes make evaluation impossible, stop and ask.
- Missing / unresolvable issue → stop.
