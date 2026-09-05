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


### Load the project bindings

Read `$MAIN_ROOT/.ai/cktk/project.json`. It records where this repository's project
lives; `skills/init-project/references/project-schema.md` is its normative
description.

- **Absent** → set `BINDINGS_AVAILABLE=false`, say once that project bindings are
  not configured and that `/init-project` creates them, and otherwise behave
  exactly as this skill did before Phases 8 and 9 existed.
- **`schema_version` higher than 1** → same, naming the version. Never guess at a
  newer shape.
- **Present and readable** → set `BINDINGS_AVAILABLE=true`.

**A missing or unreadable bindings file never blocks a status update.** Phases 2
through 7 do not consult it. Never interrogate the user for a binding mid-command —
that is the failure this contract exists to remove.

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
6. If current state already matches the explicit target (after mapping in Phase 5), report idempotent; **stop only when `BINDINGS_AVAILABLE=false`**, otherwise carry on to Phase 8 per the rule there. For `auto`, continue to evaluation.

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
4. If the issue is already in `target_state_name`, report the transition as
   idempotent. **Stop here only when `BINDINGS_AVAILABLE=false`**; otherwise skip
   Phases 6 and 7 and continue to Phase 8, which can still reconcile a Project
   Context that has drifted. A repeat invocation should converge the document
   rather than be a no-op.

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

## Phase 8: Sync the Linear Project Context

**Skip this phase entirely when** `BINDINGS_AVAILABLE=false`, or
`linear.project_context.enabled` is false, or its `status` is not `validated`, or
`preferences.sync_project_context` is `never`.

**A run that wrote no status still reaches this phase.** When the issue was already
in the target state, Phase 5 reports the transition as idempotent but does not end
the run: the question here simply changes from *what did this transition falsify?*
to *what does the document state about this issue, its blockers, or its milestones
that Linear now contradicts?* Everything else — the bounds, the anchor rules,
consent, and the obligation to leave ambiguity alone — is unchanged.

Without this, a sync could never be retried. The status write is one-way, so a run
whose patch was wrong, or whose consent was declined, would have no way back to
this phase through this command.

The Project Context is a **Linear Document**. The project *description* is a
different object, and writing to it is out of scope for this skill under every
circumstance.

### 8.1 Consent

Ask once, covering this phase and Phase 9 together, and **default to no**. Honor
`preferences.sync_project_context` when it is `always` or `never`; a team that
wants this always-on says so once in `init-project` rather than on every run.

Declining is not a failure. Skip the write and print in Phase 10 the exact patch
operations that were not applied, so they can be pasted or re-run later.

### 8.2 Decide what the transition falsified

Fetch the bound document by `document_id`. Consider **only** the sections named in
`state_sections`; everything outside them is out of bounds whatever it says.

Change only what this transition provably falsified:

- The issue's own line, where a state section mentions it.
- Statements the transition made untrue — an issue called "in progress", "next", or
  "not started" that is now Done; a "blocked by X" where X just closed; a dependent
  Phase 7 actually moved.
- Milestone completion **only where the section states a number in prose**, read
  from real Linear figures. Percentages move when issues are **added** to a
  milestone, not only when they complete, so a falling number usually means scope
  grew rather than work being lost. Where the prose explains a number, the
  explanation must stay true.

  **Check every stated figure in the section, not only the milestone this issue
  belongs to.** One status change can move several milestones, and a number that
  was already stale stays stale unless someone looks. In particular, **a figure you
  are using as part of an anchor is still a figure you must verify** — reading a
  number closely enough to match on it and then writing it back unchanged is the
  easiest way to leave a known-wrong number in place.

  **A changed figure can strand the sentence that explains it.** Prose beside a
  number often says why the number is what it is — "both fell because ten design
  tickets joined their denominators". Change the number and that explanation may
  stop explaining anything without ever becoming false: it may be dated, or true of
  a moment that has passed.

  **Do not rewrite it.** Reconstructing a rationale you did not witness is
  inventing content. **Name it in the summary instead**, quoting the sentence and
  the figure it no longer matches, and let a human decide. Silence is the only
  wrong answer: an unmentioned stranded explanation is how a document fills with
  prose that reads as current and is not.
- A last-synced marker, **only when `last_synced_marker` is not null**. Never
  invent one — adding an uninvited line to a shared document is exactly the kind of
  edit this phase's bounds exist to prevent.

**Prefer a carve-out to a replacement.** When a sentence is falsified only in part
— "A, B and C have not started" where only B is now done — amend it to preserve
what is still true: "…have not started, apart from B." Replacing the sentence with
a different characterisation drops the true remainder, so the document loses
information it had before the sync. Change the smallest span that makes the
sentence true again.

**Ambiguous effect means report and change nothing.** This phase has no obligation
to write. Reading the document and concluding that nothing was falsified is a
correct outcome, not a failure.

### 8.3 Write with `patch`

`save_document` with the `patch` parameter, never `content` — a whole-content
replace would rewrite sections this phase may not touch.

Three rules, all load-bearing:

- Every anchor must match the current content **exactly once**, and operations
  apply in order and **atomically**: one failing operation aborts the whole save,
  so a stale anchor leaves the document untouched rather than half-edited.
- **Never anchor on an issue identifier.** Linear stores inline mentions as
  `<issue id="…" href="…">TAI-5</issue>`, not as the text `TAI-5`, so an anchor
  taken from an identifier will not match. A plain-text identifier you write
  becomes mention markup after the save, so it will not match next time either.
  Draw anchors from ordinary prose. When replacement text must name an issue,
  write it as an explicit markdown link rather than a bare identifier: a link
  survives the save as a link, while bare text is converted to mention markup.
- At most 50 operations.

**Linear re-serializes the document on save.** A round trip normalizes malformed
markdown; bold markers spanning an inline mention have been observed to disappear.
Content survives, formatting may not. Note this in Phase 10 so a cosmetic diff is
not read as data loss.

### 8.4 When there is no Project Context

`project_context.enabled` false means this project keeps none. Do not create one
here and **do not write the project description instead**. Say so once and name
`/init-project`, which offers to create or migrate one.

## Phase 9: Record a cross-cutting decision in Notion

**Skip entirely when** Phase 8 was skipped for any reason, or
`notion.decision_log.status` is not `validated`, or `preferences.write_decision_log`
is `never`, **or no status was written in this run** — a sync-only pass settles no
decision, so there is nothing for it to record.

### 9.1 What qualifies

A decision settled while closing this issue whose reach exceeds the issue itself:
it changes what another issue must do, moves a product or governance boundary, or
settles something future versions inherit.

A decision local to this issue belongs in the issue. Never create a second live
task tracker in Notion, and never copy repository truth into prose that will drift.

### 9.2 The named-referent gate

Whether a decision is cross-cutting is your judgment, made fresh on every run with
different context each time. So it must be **falsifiable**: a decision qualifies
only if you can name the concrete thing it affects — another Linear issue
identifier, or a named product or governance boundary appearing in the Project
Context or in a bound requirements document.

**If you cannot name a referent, the decision is issue-local. Write nothing.**

Record the referent on the entry. This does not make the judgment correct; it makes
it checkable by a reader, which is the most that can honestly be offered here.

Stay conservative. A missed decision costs someone a moment's reading. Flagging
every routine close costs this feature its credibility, and then it gets switched
off — which costs every future decision.

### 9.3 At most one automatic entry per issue

**Never read the decision log to check for duplicates.** A real log runs to tens of
thousands of characters and reports no truncation warning, so nothing warns you
before you have spent the context; and issue identifiers appear throughout such a
log's prose, so a keyword search is unsound too — finding `TAI-48` somewhere does
not mean `TAI-48` has an entry.

Instead list this issue's comments and look for the literal prefix
`cktk:decision-logged`.

- **Present** → an entry already exists. Write nothing; draft into Phase 10 and
  name the existing entry's URL.
- **Absent** → eligible, subject to the Phase 8.1 consent.

An entry a human wrote by hand carries no marker, so you may propose a duplicate of
one. The consent prompt and the Phase 10 report are what keep that visible.

### 9.4 Pre-write check

Re-fetch the log immediately before writing and compare its live shape against the
binding. For a database that means `properties` **and** `property_types` — a rename
is caught by the names, a retype only by the types.

Any mismatch → draft into Phase 10, name the failed precondition, write nothing.

### 9.5 The write

Append-only, and only these calls:

- **Database log** — `notion-create-pages` with a `data_source_id` parent.
- **Page log** — `notion-update-page` with `command: "insert_content"` and
  `position` taken from `append_position`, at `entry_heading_level`.

`update_content` and `replace_content` are **forbidden by name**. Never edit an
existing entry, and never one a human wrote.

The entry carries what was decided, the named referent, a backlink to this issue,
the key `cktk:<ISSUE-ID>:<slug>`, and attribution to this workflow rather than to a
person.

### 9.6 Then mark the issue

**Only after the Notion write returns successfully**, post a comment on the issue:

```
cktk:decision-logged <ISSUE-ID> → <notion entry url>
```

If that comment fails, say so prominently in Phase 10 with the entry's URL: the
entry exists and its marker does not, so a later run could duplicate it unless
someone intervenes.

**A failed Notion write never fails the status update.** Phase 6 has already
succeeded; report the failure and carry on.

## Phase 10: Summary

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

9. **Project Context sync** (Phase 8), whenever bindings were available:
   - What changed, section by section, showing each patch operation's before and
     after
   - What was deliberately left alone that a reader might have expected to change
   - Anything whose effect was ambiguous, and therefore untouched
   - **Any explanation stranded by a figure you changed** — quote the sentence and
     say which number it no longer matches
   - When a save occurred, the re-serialization note: Linear normalizes markdown on
     save, so a cosmetic diff is not data loss
   - When the phase was skipped or consent declined: why, plus **the exact patch
     operations that were not applied**, so they can be pasted or re-run

10. **Notion decision log** (Phase 9), whenever bindings were available:
    - What was written and where, with a link, and the named referent that
      qualified it
    - When nothing was written, which of these applied: no decision qualified; a
      `cktk:decision-logged` marker already existed (name the existing entry); a
      precondition failed (name it); consent was declined. In the last three cases,
      print the drafted entry
    - **Prominently, if the Notion write succeeded but the marker comment failed:**
      the entry's URL and the fact that a later run could duplicate it until
      someone intervenes

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

### Project Context and Notion writes

- **The Linear project description is never written by this skill**, under any
  circumstance. The Project Context is a Linear **Document**; they are different
  objects. `/init-project` owns creating or migrating one.
- **Only the sections named in `state_sections` may be edited**, and only where
  this transition provably falsified something in them. Purpose, methodology,
  guardrails, invariants, and architecture contracts appear in a Project Context
  for navigation; editing them from here would put two sources into conflict.
- **Never edit Notion-owned or repository-owned content from Linear.** A section
  carrying repository paths or Notion links is not a sync target even if it is
  listed; report and skip it.
- Use `save_document` with `patch` only — never `content`, which would replace
  sections this skill may not touch. Never anchor on an issue identifier.
- **Never invent a last-synced marker** where `last_synced_marker` is null.
- The Notion write is **append-only**: `notion-create-pages`, or
  `notion-update-page` with `command: "insert_content"`. **`update_content` and
  `replace_content` are forbidden.** Never edit an existing entry, and never one a
  human wrote.
- **Never read the decision log to detect duplicates.** Use the
  `cktk:decision-logged` marker on the Linear issue.
- **At most one automatic decision-log entry per issue**, ever.
- **No automatic write against a binding that is not `validated`**, or whose
  `preferences` entry is `never`.
- **A failed Project Context or Notion write never fails the status update.**
  Phase 6 has already succeeded; report and carry on.
- Ambiguous effect → report and change nothing. Neither phase is obliged to write.
