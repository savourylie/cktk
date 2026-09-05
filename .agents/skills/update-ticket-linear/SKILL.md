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
4. Normalize to `issue_id` (TEAM-NUM uppercase, or extract from URL). If the issue
   already holds the target state, report idempotent and stop **only when
   `BINDINGS_AVAILABLE=false`**; otherwise skip Phases 6 and 7 and continue to
   Phase 8, so a repeat invocation converges the Project Context instead of being a
   no-op.
5. Validate: unknown extra tokens → stop.
6. Read `$MAIN_ROOT/.ai/cktk/project.json` — the project bindings, described
   normatively in `init-project`'s `references/project-schema.md`. Absent, or a
   `schema_version` above 1 → set `BINDINGS_AVAILABLE=false`, say so once, name
   `$init-project`, and behave exactly as this skill did before Phases 8 and 9
   existed. **A missing bindings file never blocks a status update, and you never
   interrogate the user for a binding mid-command.**

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

## Phase 8: Sync the Linear Project Context

Skip entirely when `BINDINGS_AVAILABLE=false`, `linear.project_context.enabled` is
false, its `status` is not `validated`, or `preferences.sync_project_context` is
`never`.

**A run that wrote no status still reaches this phase.** When the issue was already
in the target state, report the transition as idempotent, skip Phases 6 and 7, and
continue here — the question becomes *what does the document state about this
issue, its blockers, or its milestones that Linear now contradicts?* Without this a
sync could never be retried: the status write is one-way, so a run whose patch was
wrong or whose consent was declined would have no way back.

The Project Context is a Linear **Document**. The project *description* is a
different object and this skill never writes it.

**Consent:** ask once, covering this phase and Phase 9, defaulting to no. Honor
`preferences.sync_project_context` when it is `always` or `never`. Declining is not
a failure — skip the write and print the unapplied patch operations in the summary.

**Scope:** only the sections named in `state_sections`, and within them only what
this transition provably falsified — the issue's own line, statements it made
untrue ("in progress" now Done, "blocked by X" where X just closed, a dependent
Phase 7 moved), a milestone number stated in prose (read the real figure from
Linear; a falling percentage usually means issues were added, not that work was
lost), and a last-synced marker **only where `last_synced_marker` is not null**.
Never invent one.

**Check every figure the section states, not only this issue's milestone** — one
status change can move several, and a figure you use as part of an anchor is still
a figure you must verify. Reading a number closely enough to match on it and then
writing it back unchanged is the easiest way to leave a known-wrong number in
place.

**Prefer a carve-out to a replacement.** "A, B and C have not started" where only B
is done becomes "…have not started, apart from B" — replacing the sentence with a
different characterisation drops the true remainder and the document loses
information it had before the sync.

**Ambiguous effect means report and change nothing** — this phase is never obliged
to write.

**Write:** `save_document` with `patch`, never `content`. Every anchor must match
exactly once, operations apply atomically so a stale anchor aborts the whole save
cleanly, and at most 50 apply. **Never anchor on an issue identifier** — Linear
stores mentions as `<issue id="…" href="…">TAI-5</issue>` markup, so such an anchor
will not match, and one you write will not match next run either. Linear
re-serializes on save; note in the summary that a cosmetic diff is not data loss.

If `project_context.enabled` is false, do not create one and do not write the
description instead. Name `$init-project`.

## Phase 9: Record a cross-cutting decision in Notion

Skip when Phase 8 was skipped for any reason, `notion.decision_log.status` is not
`validated`, `preferences.write_decision_log` is `never`, or **no status was written
in this run** — a sync-only pass settles no decision.

**Qualifies:** a decision settled while closing this issue whose reach exceeds it —
it changes what another issue must do, moves a product or governance boundary, or
settles something future versions inherit. Issue-local decisions stay in the issue.
Never build a second task tracker in Notion.

**Named-referent gate:** the decision qualifies only if you can name the concrete
thing it affects — another issue identifier, or a named boundary appearing in the
Project Context or a bound requirements document. **No referent, no write.** Record
the referent on the entry. Stay conservative: a missed decision costs a moment's
reading, while flagging every routine close costs the feature its credibility.

**Duplicates:** **never read the decision log to check.** A real log runs to tens of
thousands of characters with no truncation warning, and issue identifiers appear
throughout its prose, so neither a scan nor a keyword search is sound. List the
issue's comments and look for the literal prefix `cktk:decision-logged`. Present →
write nothing and draft into the summary, naming the existing entry. Absent →
eligible, subject to consent.

**Pre-write:** re-fetch the log and compare its live shape against the binding —
for a database, `properties` **and** `property_types`, since a rename shows in the
names and a retype only in the types. Any mismatch → draft, name the failed
precondition, write nothing.

**Write, append-only:** `notion-create-pages` for a database log, or
`notion-update-page` with `command: "insert_content"` at `append_position` for a
page. **`update_content` and `replace_content` are forbidden.** The entry carries
the decision, the referent, a backlink, the key `cktk:<ISSUE-ID>:<slug>`, and
attribution to the workflow rather than a person.

**Then mark the issue** — only after the Notion write returns — with a comment
`cktk:decision-logged <ISSUE-ID> → <url>`. If that comment fails, report it
prominently with the entry URL: a later run could duplicate it.

**A failed Notion write never fails the status update.**

## Phase 10: Summary

1. Issue id/title/URL, previous → new state
2. Whether evidence came from main checkout or a linear worktree
3. AC evaluation (if any), comment/description outcomes
4. Unblocked / ready issues list (annotate auto-moves)
5. Explicit note: **no git commit**
6. **Project Context sync:** what changed section by section with before/after,
   what was deliberately left alone, what was ambiguous and therefore untouched,
   the re-serialization note when a save occurred, and — when skipped or declined —
   why, plus the exact unapplied patch operations
7. **Notion decision log:** what was written and where with a link and its named
   referent; or why nothing was (no decision qualified, a marker already existed,
   a precondition failed, consent declined) with the drafted entry printed. If the
   Notion write succeeded but the marker comment failed, say so prominently with
   the entry URL
8. If completed in a matching linear worktree, point at `$merge-worktree-linear <issue_id>` to land it (base defaults to main; pass another as a second argument), and give the manual `git checkout <base>` / `git merge linear-<issue_id>-<slug>` fallback — `$merge-worktree` itself only understands markdown `TICKET-NNN` worktrees:

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
- **Never write the Linear project description.** The Project Context is a
  Document; they are different objects. `$init-project` owns creating or migrating
  one.
- Edit only the sections in `state_sections`, only where this transition provably
  falsified something. Purpose, methodology, guardrails, invariants, and
  architecture contracts are quoted for navigation — editing them here would put
  two sources into conflict.
- **Never edit Notion-owned or repository-owned content from Linear.** A listed
  section carrying repository paths or Notion links is not a sync target; report
  and skip it.
- `save_document` with `patch` only, never `content`. Never anchor on an issue
  identifier. Never invent a last-synced marker.
- Notion writes are **append-only**: `notion-create-pages`, or `notion-update-page`
  with `insert_content`. **`update_content` and `replace_content` are forbidden.**
  Never edit an existing entry, and never one a human wrote.
- Never read the decision log to detect duplicates; use the `cktk:decision-logged`
  marker on the issue. **At most one automatic entry per issue, ever.**
- No automatic write against a binding that is not `validated`, or whose
  `preferences` entry is `never`.
- **A failed Project Context or Notion write never fails the status update.**
- Ambiguous effect → report and change nothing.
