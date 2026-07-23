---
name: "update-ticket-linear"
description: "Use when the user explicitly asks to update a Linear issue status (not docs/tickets markdown), including work in a matching linear worktree, acceptance-criteria evaluation, and safe cascade of blocked relations. Prefer explicit invocation with $update-ticket-linear. Requires Linear MCP (read+write)."
---

# Update a Linear Issue Status

Update a Linear issue's workflow state after evaluating acceptance criteria against the codebase. Prefer a matching `.worktrees/<issue_id>-<slug>/` checkout created by `$implement-ticket-linear … worktree`. Cascade blocked relations when safe. Do not commit git changes.

**This skill does not use `docs/tickets/`.** Linear is the source of truth.

If the user included an issue id or URL after `$update-ticket-linear`, use that issue. Empty args mean auto-detect from branch / worktree only.

## Prerequisites

1. Linear MCP must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp).
2. Read **and write** tools are required (get issue, list states, update issue, create comment when available).
3. If Linear MCP tools are missing, stop with a short setup hint. Do not invent API-key or CLI fallbacks.
4. Use the host's real Linear MCP tool names; discover schemas rather than inventing fields.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Auto mode: evaluate AC; set Done only when safe. |
| `<issue> <status>` | Explicit status (cktk alias or Linear state name). |
| (empty) | Auto-detect issue from branch / worktree, then auto status. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Normalize team keys to uppercase.

`<status>` may be a cktk alias (`done`, `in-progress`, `pending`, `blocked`, `deferred`) or an exact Linear workflow state name for the team.

Not accepted: multi-issue batches, title-only search, commit flags, empty “next assigned from Linear” mode.

## Phase 1: Parse & Resolve

1. Resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse args into `issue_ref` (optional) and `status_token` (optional → `auto`).
3. If no `issue_ref`, auto-detect:
   - Current branch `^linear-([A-Za-z]+-\d+)-` → issue id; `WORK_DIR=$CURRENT_ROOT`
   - Else registered `$MAIN_ROOT/.worktrees/*` whose branch matches `^linear-([A-Za-z]+-\d+)-` and has uncommitted changes or commits beyond base
   - 1 candidate → use it; 2+ → ask; 0 → stop and request an id
4. Normalize to `issue_id` (TEAM-NUM uppercase, or extract from URL).
5. Validate: unknown extra tokens → stop.

## Phase 2: Fetch Linear Issue

1. Fetch by `issue_id` via Linear MCP. Exact match only; stop if missing or ambiguous.
2. Capture title, description, state, team, labels/project/priority, relations (blocks / blocked-by), and checklist acceptance criteria in the body.
3. Derive `slug` from the title: lowercase, non-alphanumerics → `-`, collapse, trim, ~40 chars. Fallback: `issue`.
4. Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`. Branch: `linear-<issue_id>-<slug>`.

## Phase 3: Working Directory

If `WORK_DIR` not set by auto-detect:

1. Prefer `$CURRENT_ROOT` when branch is `linear-<issue_id>-*`.
2. Else prefer a registered worktree at `$MAIN_ROOT/.worktrees/<issue_id>-*` (exact slug path first).
3. Else `WORK_DIR=$CURRENT_ROOT`.

State in one sentence where evidence is gathered.

## Phase 4: Evaluate Acceptance Criteria

Skip if target is not `done` and not `auto`. Skip if all checklist items are checked or there is no checklist (treat as all met; note it).

1. Gather evidence from `WORK_DIR`: status, unstaged/staged diffs; if under `.worktrees/`, also `diff <base>...HEAD` (upstream → MAIN_ROOT HEAD → origin/main → main).
2. Evaluate each unchecked criterion: `met`, `unmet`, or `manual` (same rules as `$update-ticket`).
3. Status decision:
   - **Auto**: all met (or met+manual) → `done`; any unmet → report and **stop without Linear writes**
   - **Explicit done**: any unmet → confirm with user before proceeding
4. Report the per-criterion evaluation before writing Linear.

## Phase 5: Map Status → Linear State

1. List the issue team's workflow states via MCP.
2. Resolve target state:
   - Exact name match (case-insensitive) if provided
   - Else aliases:
     - `done` → completed-type / Done / Completed
     - `in-progress` → started-type / In Progress / Started
     - `pending` → unstarted-type preferring Todo, then Backlog
     - `blocked` → name contains Block; else stop and list states
     - `deferred` → Deferred / Canceled / Cancelled; else stop and list states
3. Ambiguous mapping → ask. Already at target → report and stop.

## Phase 6: Update Linear

1. Set the issue state to the resolved workflow state.
2. If target is done and AC was evaluated: when description updates are supported, check only `met` boxes; leave `unmet`/`manual` unchecked.
3. If AC was evaluated: post a short evaluation comment when comment tools exist.
4. Do not change assignee, priority, labels, project, or cycle unless the user explicitly asked.

## Phase 7: Cascade (completed only)

When the new state is completed-type:

1. Find issues this one **blocks**.
2. For each: if all blockers are completed **and** the dependent's state name clearly means blocked, move it to the team's pending-like default state.
3. If the dependent is not in a blocked-named state, report it as potentially ready but do not auto-move.
4. If cascade is ambiguous, report only — do not force.

## Phase 8: Summary

1. Issue id/title/URL, previous → new state
2. Whether evidence came from main checkout or a linear worktree
3. AC evaluation (if any), comment/description outcomes
4. Unblocked / ready issues list (annotate auto-moves)
5. Explicit note: **no git commit**
6. If completed in a matching linear worktree, give **manual land** instructions — `$merge-worktree` only understands markdown `TICKET-NNN` worktrees:

```bash
git checkout <base>
git merge linear-<issue_id>-<slug>
# or push + open PR from the worktree branch
```

## Safety Rules

- Require Linear MCP with write access; fail closed.
- Never commit; do not call `$commit-ticket`, `$commit-push-pr`, or `$update-ticket`.
- Do not use `docs/tickets/` as the ticket source.
- Do not create/archive/delete issues or reassign by default.
- Auto + unmet AC → no Linear writes.
- Explicit done + unmet AC → confirm first.
- Prefer matching linear worktrees for evidence when present.
- Missing MCP or unresolvable issue → stop.
