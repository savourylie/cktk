---
name: "clarify-ticket"
description: "Use when the user explicitly asks to clarify or de-risk a markdown ticket from docs/tickets/ before implementing it (not a Linear issue) — read the ticket, analyze it against the codebase, surface details and risks, discuss interactively, and end with a readiness summary. Strictly read-only: never edits tickets, INDEX.md, or git. Prefer explicit invocation with $clarify-ticket. The markdown-ticket twin of clarify-ticket-linear."
---

# Clarify a Ticket (advisory, read-only)

Read a ticket from `docs/tickets/` and interactively clarify its details and risks against the codebase before implementation. Produce a codebase-grounded briefing, discuss the open items with the user, and end with a readiness summary. **Never** edit tickets, `INDEX.md`, or git — this skill is strictly advisory.

**Source of truth is `docs/tickets/`.** No Linear, no MCP. For Linear issues use `$clarify-ticket-linear`.

If the user included a ticket number after `$clarify-ticket`, use it. Empty args mean auto-detect.

## Prerequisites

1. A git repo containing `docs/tickets/`. No MCP or external service required.
2. If `docs/tickets/` is missing, stop with a short hint (use `$clarify-ticket-linear` for Linear issues).

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Clarify that ticket. |
| (empty) | Auto-detect the ticket, then clarify. |

`<ticket>` is `TICKET-007`, `007`, `#7`, or `7`; normalize to 3-digit `NNN`. No status token; extra tokens → stop.

## Phase 1: Parse & Resolve

1. Resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse args into a ticket ref (normalize to `NNN`).
3. If no ticket ref, auto-detect:
   - Current branch `^ticket-(\d{3})-` → `NNN`; `WORK_DIR=$CURRENT_ROOT`
   - Else a registered `$MAIN_ROOT/.worktrees/*` whose branch matches `^ticket-(\d{3})-` (1 → use; 2+ → ask; 0 → next)
   - Else INDEX.md fallback: collect tickets marked `` `pending` ``; 1+ → ask (4 lowest-numbered + "Other"); 0 → stop and request a number
4. Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match → stop; multiple → stop. Slug = filename minus `NNN-` and `.md`. Extra tokens → stop.

## Phase 2: Read the Ticket (read-only)

Capture title, `## Status` (context only), body, `## Acceptance Criteria` checkboxes, `- Requires:` deps (+ `✅` markers), Implementation Notes / Testing. Also read the ticket's INDEX.md row, and grep `docs/tickets/` for `#NNN` on `Requires:` lines (reverse deps — the tickets this one blocks). Worktree handles: `$MAIN_ROOT/.worktrees/NNN-<slug>`, branch `ticket-NNN-<slug>`.

## Phase 3: Code Context

1. Prefer `$CURRENT_ROOT` when its branch is `ticket-NNN-*`.
2. Else a registered worktree at `$MAIN_ROOT/.worktrees/NNN-<slug>`.
3. Else `WORK_DIR=$CURRENT_ROOT`.

## Phase 4: Codebase-Grounded Analysis

Read-only exploration only (grep/glob/read + safe read-only commands). When present, also read `$WORK_DIR/docs/PRD.md` and the design source (`docs/DESIGN.md` → `docs/design/DESIGN.md` → `design-system/`) and check the ticket against them. Produce four buckets + a verdict:
- **Details to confirm** — ambiguities, underspecified requirements, missing/untestable acceptance criteria, ticket-vs-PRD/design conflicts.
- **Risks** — files/modules touched, conflicting patterns, missing prerequisites, migration/breaking-change/blast-radius, acceptance-criteria feasibility. Tag each with severity (`high`/`medium`/`low`) + evidence (`path:line`).
- **Dependencies** — `Requires:` deps (+ `✅` state and dependency status), reverse deps (tickets this one blocks), code prerequisites.
- **Open questions** — what neither the ticket nor the code answers.
- **Verdict** — `ready` / `needs-clarification` / `blocked` (an unsatisfied `Requires:` dep → `blocked`).

## Phase 5: Briefing

Present the four buckets + verdict + code-context source on screen.

## Phase 6: Guided Discussion

Walk open items one topic at a time (AskUserQuestion / prose). Record each as resolved-here or still-open. Batch trivial confirmations.

## Phase 7: Readiness Summary (on-screen only)

Verdict, resolved decisions, open questions for the author, key risks to watch, and a suggested next step (`$implement-ticket NNN`, optionally `worktree`, or resolve blockers first). No writes anywhere.

## Safety Rules

- Strictly read-only: never edit tickets / `INDEX.md`, never change status or acceptance-criteria checkboxes, never edit files, never commit, never run mutating/destructive commands.
- Missing `docs/tickets/` or unresolvable ticket → stop.
- Do not call `$implement-ticket`, `$update-ticket`, `$commit-ticket`, `$commit-push-pr`, or `$create-worktree` — only suggest them.
- No Linear involvement — that is `$clarify-ticket-linear`.
- Prefer matching ticket worktrees for code context when present.
