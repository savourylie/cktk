---
name: "clarify-ticket"
description: "Use only when the user explicitly asks to clarify or de-risk a markdown ticket from docs/tickets/, supplies a TICKET-NNN reference, or invokes clarify-ticket. Do not use for Linear issue ids or URLs. Read the ticket, validate tracker and code context, discuss ambiguities and risks, and produce a readiness summary. Strictly read-only: never edit tickets, INDEX.md, repo files, or git."
---

# Clarify a Markdown Ticket (advisory, read-only)

Read one ticket from `docs/tickets/`, analyze it against the tracker and actual codebase, discuss unresolved details, and end with a readiness summary. Never edit files or git. Use `clarify-ticket-linear` for Linear issues.

Resolve the ticket reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. Empty input means auto-detect.

## Portable interaction

When selection or confirmation is needed:

1. Show every candidate with a stable ticket id and distinguishing path/title.
2. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
3. Never assume an option limit or implicit “Other” choice.
4. Accept an unambiguous ticket id/number or path.

Refer to follow-up skills by name. Use host-native invocation syntax when known; otherwise show the plain skill name and arguments.

## Phase 1: Resolve Ticket and Code Context

1. Require a git repo with `docs/tickets/`, then resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Accept one optional ticket ref (`TICKET-007`, `007`, `#7`, or `7`) and normalize to three-digit `NNN`. Reject extra/status/write tokens.
3. With no ref, auto-detect:
   - Current `ticket-NNN-*` branch
   - Registered worktrees under `$MAIN_ROOT/.worktrees/` on `ticket-NNN-*` branches
   - INDEX rows with exact backtick-wrapped `pending` status
   - Confirm a single INDEX candidate; apply portable interaction for multiple candidates; stop if none
4. Resolve exactly one `$MAIN_ROOT/docs/tickets/NNN-*.md`; stop on zero/multiple matches and derive its slug.
5. Resolve `WORK_DIR` in order:
   - Current checkout on `ticket-NNN-*`
   - Exact registered `.worktrees/NNN-<slug>`
   - Unique registered worktree whose branch is `ticket-NNN-*`, allowing an old slug because the ticket was renamed
   - Ask if multiple matching worktrees remain
   - Otherwise current checkout
6. Announce ticket and code context.

## Phase 2: Read and Validate Tracker

Capture the ticket title/body, status, acceptance-criteria checkboxes, `Requires:` dependencies and `✅` markers, Implementation Notes, and Testing. Read its INDEX row.

Report missing/duplicate/malformed INDEX rows, ticket-vs-INDEX status/dependency mismatches, and missing/malformed required sections under **Details to confirm**; readiness is at least `needs-clarification`.

Read each dependency ticket and INDEX status. A dependency is satisfied when marked `✅` or its INDEX status is `done`; report disagreement between these signals.

Find reverse dependencies only on `Requires:` lines with an exact `#NNN` token followed by a non-digit or end of line. Never let `#007` match `#0070`.

## Phase 3: Read Project Context

Within `WORK_DIR`, read applicable root and scoped repository guidance (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or equivalent), then `docs/PRD.md` and the relevant design source when present (`docs/DESIGN.md` → `docs/design/DESIGN.md` → relevant `design-system/` files).

## Phase 4: Analyze

Use read-only exploration and safe read-only shell commands. Produce:

- **Details to confirm** — ambiguity, tracker inconsistency, missing/untestable criteria, and project-guidance/PRD/design conflicts.
- **Risks** — likely files/modules, divergent patterns, missing prerequisites, migrations/compatibility, blast radius, and AC feasibility. Tag severity and cite `path:line`.
- **Dependencies** — required tickets with marker/status/satisfaction, reverse dependencies, and code prerequisites.
- **Open questions** — what no available source answers.
- **Verdict**:
  - `ready` — well specified, tracker consistent, risks understood, no unmet dependencies
  - `needs-clarification` — unresolved requirements, untestable criteria, or tracker inconsistency
  - `blocked` — unsatisfied dependency or hard prerequisite

## Phase 5: Briefing and Discussion

Present a `Clarification Briefing — TICKET-NNN` with readiness, code context, the four analysis buckets, severity, and evidence. Then walk substantive open items one at a time using portable interaction; batch trivial confirmations. Record outcomes as **resolved here** or **still open**. Skip discussion if nothing is open.

## Phase 6: Readiness Summary

Present on screen only:

- Verdict (`ready to implement`, `needs author input`, or `blocked by …`)
- Resolved decisions
- Open questions for the author
- Key risks
- Suggested next step: use `implement-ticket NNN [worktree]`, or resolve blockers first

## Safety rules

- Strictly read-only: never edit tickets, INDEX, repo files, status/checklists, or git; never commit or run mutating/destructive commands.
- Do not use Linear.
- Do not call implementation, update, commit, PR, or worktree skills; only suggest them.
- Never guess missing or ambiguous ticket/tracker state.
- Disclose dirty unrelated changes when they make evidence ambiguous.
