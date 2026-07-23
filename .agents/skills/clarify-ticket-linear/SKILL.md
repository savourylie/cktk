---
name: "clarify-ticket-linear"
description: "Use when the user explicitly asks to clarify or de-risk a Linear issue before implementing it (not docs/tickets markdown) — fetch the issue, analyze it against the codebase, surface details and risks, discuss interactively, and end with a readiness summary. Strictly read-only: never modifies Linear or git. Prefer explicit invocation with $clarify-ticket-linear. Requires Linear MCP (read-only)."
---

# Clarify a Linear Issue (advisory, read-only)

Fetch a Linear issue and interactively clarify its details and risks against the codebase before implementation. Produce a codebase-grounded briefing, discuss the open items with the user, and end with a readiness summary. **Never** modify Linear or git — this skill is strictly advisory.

**This skill does not use `docs/tickets/`.** Linear is the source of truth.

If the user included an issue id or URL after `$clarify-ticket-linear`, use that issue. Empty args mean auto-detect from branch / worktree only.

## Prerequisites

1. Linear MCP must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp).
2. Read-only tools suffice (get/search issue, list relations, get comments). No write tools are needed.
3. If Linear MCP tools are missing, stop with a short setup hint. Do not invent API-key or CLI fallbacks.
4. Use the host's real Linear MCP tool names; discover schemas rather than inventing fields. Team workflow states are not listed or mapped — the readiness verdict is this skill's own.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Clarify that issue. |
| (empty) | Auto-detect the issue from branch / worktree, then clarify. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Uppercase team keys. No status token; extra tokens → stop.

## Phase 1: Parse & Resolve

1. Resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse args into `issue_ref` (optional).
3. If no `issue_ref`, auto-detect:
   - Current branch `^linear-([A-Za-z]+-\d+)-` → issue id; `WORK_DIR=$CURRENT_ROOT`
   - Else a registered `$MAIN_ROOT/.worktrees/*` whose branch matches `^linear-([A-Za-z]+-\d+)-`
   - 1 candidate → use it; 2+ → ask; 0 → stop and request an id
4. Normalize to `issue_id` (TEAM-NUM uppercase, or extract from URL). Unknown extra tokens → stop.

## Phase 2: Fetch Linear Issue (read-only)

1. Fetch by `issue_id` via Linear MCP. Exact match only; stop if missing or ambiguous.
2. Capture title, description, current state (context only), team, labels/project/priority, relations (blocks / blocked-by + states), comments, and checklist acceptance criteria.
3. Derive `slug` (lowercase, non-alphanumerics → `-`, collapse, trim, ~40 chars; fallback `issue`).
4. Worktree handles: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`, branch `linear-<issue_id>-<slug>`.

## Phase 3: Code Context

1. Prefer `$CURRENT_ROOT` when its branch is `linear-<issue_id>-*`.
2. Else a registered worktree at `$MAIN_ROOT/.worktrees/<issue_id>-*`.
3. Else `WORK_DIR=$CURRENT_ROOT`. No usable repo → text-only mode (flag it).

## Phase 4: Codebase-Grounded Analysis

Read-only exploration only (grep/glob/read + safe read-only commands). Produce four buckets + a verdict:
- **Details to confirm** — ambiguities, underspecified requirements, missing/untestable acceptance criteria.
- **Risks** — files/modules touched, conflicting patterns, missing prerequisites, migration/breaking-change/blast-radius, acceptance-criteria feasibility. Tag each with severity (`high`/`medium`/`low`) + evidence (`path:line`).
- **Dependencies** — Linear relations (+ states) and code prerequisites.
- **Open questions** — what neither the ticket nor the code answers.
- **Verdict** — `ready` / `needs-clarification` / `blocked`.

## Phase 5: Briefing

Present the four buckets + verdict + code-context source on screen.

## Phase 6: Guided Discussion

Walk open items one topic at a time (AskUserQuestion / prose). Record each as resolved-here or still-open-for-author. Batch trivial confirmations.

## Phase 7: Readiness Summary (on-screen only)

Verdict, resolved decisions, open questions for the author, key risks to watch, and a suggested next step (`$implement-ticket-linear <issue>` or resolve blockers first). No writes anywhere.

## Safety Rules

- Require Linear MCP (read); fail closed. Missing/unresolvable issue → stop.
- Strictly read-only: never modify Linear (state/comment/description/AC), never edit files, never commit, never run mutating/destructive commands.
- Do not use `docs/tickets/` as the source.
- Do not call `$implement-ticket-linear`, `$update-ticket-linear`, `$commit-ticket`, or `$commit-push-pr` — only suggest them.
- Prefer matching linear worktrees for code context when present.
