---
name: "clarify-ticket"
description: "Research how to implement a local docs/tickets/ ticket, analyze requirements and risks, discuss material decisions with options, trade-offs, and a recommendation, then produce a readiness summary and implementation plan. Use for pre-implementation research or clarification, or clarify-ticket. Not for Linear issues or a purpose-only explanation (explain-ticket). Read-only: never change tickets, repository files, or git."
---

# Clarify a Markdown Ticket (advisory, read-only)

Read one ticket from `docs/tickets/`, analyze it against the tracker and actual codebase, discuss unresolved details, and end with a readiness summary and implementation plan. Never edit files or git. Use `clarify-ticket-linear` for Linear issues.

Resolve the ticket reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. Empty input first uses a single local ticket established in the conversation, then auto-detection.

## Continue an established ticket

Reuse the same ticket's explanation, decisions, constraints, and audience
preferences already established in the conversation, including an earlier
`explain-ticket` result. Resolve a missing reference from that context before
branch/worktree discovery. If several tickets remain plausible, ask which one;
do not silently choose a branch over the conversation. An explicit reference
wins. A reference for the other source belongs to the matching twin.
Refresh evidence that could affect readiness rather than repeating the whole
explanation or asking resolved questions again. A purpose-only explanation
belongs to `explain-ticket`; this workflow researches implementation choices.

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
2. Use an explicit ticket ref or the single local ticket established in the conversation. Accept one optional ticket ref (`TICKET-007`, `007`, `#7`, or `7`) and normalize to three-digit `NNN`. Reject extra/status/write tokens.
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

Frame the analysis with the four types of unknowns: known knowns (verify against code), known unknowns (turn into open questions), unknown knowns (elicit in discussion), unknown unknowns (hunt as blind spots).

Use read-only exploration and safe read-only shell commands. Produce:

- **Details to confirm** — ambiguity, tracker inconsistency, missing/untestable criteria, and project-guidance/PRD/design conflicts.
- **Risks** — likely files/modules, divergent patterns, missing prerequisites, migrations/compatibility, blast radius, and AC feasibility. Tag severity and cite `path:line`.
- **Blind spots** — what the ticket does not mention: adjacent callers/dependents, ignored error and edge paths, migration/backfill/rollback implications, implicit conventions from project guidance or dominant patterns, and test surface. Cite `path:line`, or record "No blind spots found".
- **Dependencies** — required tickets with marker/status/satisfaction, reverse dependencies, and code prerequisites.
- **Open questions** — what no available source answers.
- **Verdict**:
  - `ready` — well specified, tracker consistent, risks understood, no unmet dependencies
  - `needs-clarification` — unresolved requirements, untestable criteria, or tracker inconsistency
  - `blocked` — unsatisfied dependency or hard prerequisite

## Phase 5: Briefing, Discussion, and Implementation Plan

Read and follow the [shared implementation discussion](references/implementation-discussion.md).
Use the analysis above to present a concise briefing with the ticket identity,
selected code context, preliminary readiness, proposed approach, and an
ordered agenda of unresolved decisions and missing facts.

Discuss material decisions one at a time with viable options, their trade-offs,
and a recommendation. Ask calibration questions only when needed; skip settled
questions and do not ask the user to resolve facts available in the sources.
Finish with decisions, ordered implementation steps, acceptance checks, remaining
blockers, and the matching next step, all on screen. Apply this skill's readiness
rules to the final evidence; recommendations are not user decisions.

## Safety rules

- Strictly read-only: never edit tickets, INDEX, repo files, status/checklists, or git; never commit or run mutating/destructive commands.
- Do not use Linear.
- Do not call implementation, update, commit, PR, or worktree skills; only suggest them.
- Never guess missing or ambiguous ticket/tracker state.
- Disclose dirty unrelated changes when they make evidence ambiguous.
