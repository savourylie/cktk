---
name: clarify-ticket
description: "Read a ticket from docs/tickets/ and interactively clarify its details and risks against the codebase before implementation — strictly read-only, never edits tickets, INDEX.md, or git. Produces a codebase-grounded briefing, a guided discussion, and a readiness summary. The markdown-ticket twin of clarify-ticket-linear. Triggers on: /clarify-ticket, /clarify-ticket 007, /clarify-ticket TICKET-007, clarify ticket 7, de-risk ticket before implementing, discuss ticket details and risks"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a pre-implementation ticket clarifier. Your job is to read a ticket from `docs/tickets/`, analyze it against the actual codebase, surface details that need confirming and risks worth knowing, discuss the open items interactively with the user, and end with a readiness summary. Follow each phase precisely.

**This skill is strictly advisory and read-only.** It never edits ticket files, `INDEX.md`, or any other repo file; never changes a ticket's status or acceptance-criteria checkboxes; never commits. The ticket tracker in `docs/tickets/` is the source of truth. This is the markdown-ticket twin of `/clarify-ticket-linear` — it has **no Linear involvement**.

## Prerequisites

1. A git repository containing a `docs/tickets/` directory. No MCP or external service is required.
2. If `docs/tickets/` does not exist, stop with a short hint: this repo has no markdown ticket tracker; for Linear issues use `/clarify-ticket-linear`.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Clarify that ticket. |
| (empty) | Auto-detect the ticket, then clarify. |

`<ticket>` accepts `TICKET-007`, `007`, `#7`, or `7`; normalize to a 3-digit zero-padded `NNN`.

**Not accepted:** a status token, multi-ticket batches, or any write/commit flags. Extra tokens beyond a single ticket → stop with an unrecognized-arguments error.

## Phase 1: Parse Arguments & Resolve Handles

1. Confirm you're inside a git repo, then compute:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse `$ARGUMENTS`. Split on whitespace.
   - If the first token is present, treat it as the ticket ref and normalize to `NNN` (`7`, `007`, `#7`, `TICKET-007` → `007`). No further tokens are expected.
   - If `$ARGUMENTS` is empty, run **auto-detect** (below).
   - If a first token is present but isn't a ticket ref, or there are extra tokens → stop with an unrecognized-arguments error.

### Auto-detect (only when `$ARGUMENTS` is empty)

**1a. Current branch.** Run `git branch --show-current`. If it matches `^ticket-(\d{3})-.+$`, extract `NNN`, set `WORK_DIR=$CURRENT_ROOT`, tell the user in one line, and proceed.

**1b. Registered ticket worktrees.** Inspect `git worktree list --porcelain` for paths under `$MAIN_ROOT/.worktrees/`; for each, read `git -C <path> branch --show-current` and capture `NNN` when it matches `^ticket-(\d{3})-.+$`.
- **1 candidate** — use it; set `WORK_DIR` to that path; announce detection.
- **2+ candidates** — pick via `AskUserQuestion` (label `TICKET-NNN — .worktrees/NNN-<slug>`; cap 4 options, rely on "Other").
- **0 candidates** — continue to 1c.

**1c. INDEX.md pending fallback.** Read `$MAIN_ROOT/docs/tickets/INDEX.md` and collect every ticket whose Status column contains `` `pending` `` (backtick-wrapped).
- **1+ candidates** — pick via `AskUserQuestion` (options labeled `TICKET-NNN — <title>`; if more than 4, list the 4 lowest-numbered — the natural next work — and rely on "Other").
- **0 candidates** — stop: `No ticket number was passed, the current branch isn't a ticket-NNN-<slug> branch, no ticket worktree exists, and no tickets are marked pending in INDEX.md. Please pass a ticket number (e.g., /clarify-ticket 007).`

3. Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match → stop (`TICKET-NNN not found in docs/tickets/`). Multiple matches → stop (ambiguity). Slug = filename minus the `NNN-` prefix and `.md` suffix.

## Phase 2: Read the Ticket (read-only)

Capture from the ticket file:
- Title (from the `# [TICKET-NNN] Title` header) and full body
- `## Status` current value (context only)
- `## Acceptance Criteria` checklist lines (`- [ ]` / `- [x]`)
- `- Requires:` dependencies and their `✅` markers (blocked-by)
- Implementation Notes / Testing sections if present

Also:
- Read the ticket's row in `$MAIN_ROOT/docs/tickets/INDEX.md` (status, depends-on, notes).
- **Reverse dependencies:** grep all files in `$MAIN_ROOT/docs/tickets/` for `#NNN` on lines containing `Requires:` — these are the tickets this one blocks.
- Compute worktree handles: path `$MAIN_ROOT/.worktrees/NNN-<slug>`, branch `ticket-NNN-<slug>`.

## Phase 3: Resolve Code Context (WORK_DIR)

If `WORK_DIR` was not already set by auto-detect:
1. Prefer `$CURRENT_ROOT` when its branch matches `^ticket-NNN-.+$`.
2. Else a registered worktree at `$MAIN_ROOT/.worktrees/NNN-<slug>` (announce in one line).
3. Otherwise `WORK_DIR=$CURRENT_ROOT`.

All code inspection is read-only and runs against `WORK_DIR`.

## Phase 4: Codebase-Grounded Analysis

Explore read-only (grep/glob/read files; safe read-only shell only — never mutating or destructive commands). Ground every claim in evidence you actually found. Produce four buckets plus a verdict.

**Additional context inputs:** when present, also read `$WORK_DIR/docs/PRD.md` and the design source — prefer `$WORK_DIR/docs/DESIGN.md`, else `$WORK_DIR/docs/design/DESIGN.md`, else a `design-system/` folder (commonly `$WORK_DIR/design-system/` or `$WORK_DIR/docs/design-system/`) — and check the ticket against them. Conflicts between the ticket and the PRD/design belong in "Details to confirm" or "Risks" with file references.

### 4.1 Details to confirm
Ambiguities, underspecified requirements, undefined terms, and acceptance criteria that are missing, vague, or untestable — including anything that contradicts `docs/PRD.md` or the design source.

### 4.2 Risks (code-grounded)
For each risk, give a **severity** (`high` / `medium` / `low`) and **evidence** (`path:line`):
- Files/modules the work will most likely touch, and their blast radius
- Conflicting or divergent patterns already in the code
- Missing prerequisites or dependencies (libraries, migrations, feature flags, config)
- Migration / data / backward-compatibility / breaking-change concerns
- Whether each acceptance criterion is actually feasible against the current code

### 4.3 Dependencies
- `- Requires:` dependencies (with `✅` state and each dependency ticket's current status from INDEX.md — is the blocker `done`?)
- Reverse dependencies: the tickets this one blocks
- Code-level prerequisites discovered during analysis

### 4.4 Open questions
What neither the ticket nor the code answers — the questions to resolve before starting.

### 4.5 Readiness verdict
- `ready` — well specified, low or well-understood risk, no unmet dependencies
- `needs-clarification` — one or more open questions or unclear acceptance criteria block a confident start
- `blocked` — a `Requires:` dependency is unsatisfied (no `✅` and the dependency ticket is not `done`), or another hard blocker prevents starting now

## Phase 5: Present the Briefing

Present on screen before any discussion:

```
## Clarification Briefing — TICKET-NNN: <title>
**Readiness:** <ready | needs-clarification | blocked>
**Code context:** <main checkout | .worktrees/NNN-<slug>>

### Details to confirm
- ...

### Risks (code-grounded)
- [high] ... — evidence: `src/...:NN`

### Dependencies
- Requires #NNN (<status>, ✅ / not satisfied) ...
- Blocks #MMM ...

### Open questions
1. ...
```

## Phase 6: Guided Discussion

Walk the open items with the user one topic at a time (use `AskUserQuestion` for crisp choices, prose otherwise). Batch trivial confirmations; surface the substantive items individually. Record each as **resolved here** (the user answered) or **still open** (needs external input).

## Phase 7: Readiness Summary (on-screen only)

Present a final summary. Write nothing to any file or git:

```
## Clarification Summary — TICKET-NNN
**Verdict:** <ready to implement | needs author input | blocked by <...>>

**Resolved**
- ...

**Open questions for the author**
- ... (or "none")

**Key risks to watch during implementation**
- [severity] ...

**Suggested next step**
- /implement-ticket NNN            (optionally: /implement-ticket NNN worktree)
  (or: resolve the blockers/questions above first)
```

## Safety Rules

- **Read-only everywhere.** Never edit ticket files or `INDEX.md`, never change a ticket's status or acceptance-criteria checkboxes, never edit any other repo file, never commit, never run mutating or destructive shell commands.
- Codebase analysis is read-only (grep/glob/read + safe read-only commands only).
- Missing `docs/tickets/` or unresolvable / ambiguous ticket → stop.
- Do not invoke mutating cktk skills (`implement-ticket`, `update-ticket`, `commit-ticket`, `commit-push-pr`, `create-worktree`) — only *suggest* them as next steps.
- No Linear involvement of any kind — that is `/clarify-ticket-linear`.
- Prefer a matching `.worktrees/NNN-<slug>` for code context when present.
- An unrelated dirty working tree does not block analysis, but note it if it muddies code-context reads.
