---
name: "clarify-ticket-linear"
description: "Use only when the user explicitly asks to clarify or de-risk a Linear issue, supplies a TEAM-NUMBER id or linear.app issue URL, or invokes clarify-ticket-linear. Do not use for docs/tickets/ or TICKET-NNN markdown tickets. Fetch through read-only Linear MCP tools, analyze against relevant code when available, discuss ambiguities and risks, and produce a readiness summary. Never modify Linear, repo files, or git."
---

# Clarify a Linear Issue (advisory, read-only)

Fetch one Linear issue, analyze its requirements and risks against relevant code when available, discuss unresolved details, and end with a readiness summary. Never modify Linear, files, or git. Do not use `docs/tickets/`.

Resolve the issue reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. Empty input means branch/worktree auto-detection.

## Portable interaction

When selection or confirmation is needed:

1. Show every candidate with a stable issue id and distinguishing path/label.
2. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
3. Never assume an option limit or implicit “Other” choice.
4. Accept an unambiguous issue id or path.

Refer to follow-up skills by name. Use host-native invocation syntax when known; otherwise show the plain skill name and arguments.

## Prerequisites

Require authenticated Linear MCP read tools; discover actual host schemas. Missing tools → stop with a setup hint. Never use HTTP, API-key, CLI, or browser fallbacks.

Accept one optional Linear id (`ENG-42`) or issue URL. Reject extra/status/write tokens, title-only search, and multi-issue batches.

## Phase 1: Resolve Issue Reference

1. Parse and normalize the issue ref before requiring git (`TEAM-NUMBER` uppercase; URL must contain a complete id).
2. Probe git:
   - Success → set `REPO_AVAILABLE=true`, compute `MAIN_ROOT` from absolute git-common-dir and `CURRENT_ROOT` from show-toplevel.
   - Failure → set `REPO_AVAILABLE=false` and run no more git commands.
3. If no issue ref:
   - No repo → stop and request an id/URL.
   - Otherwise inspect the current branch, then registered `$MAIN_ROOT/.worktrees/`, for `linear-TEAM-NUMBER-*`.
   - Use one candidate, ask portably among multiple, or stop if none.

## Phase 2: Fetch Linear Issue

1. Fetch the exact normalized id through Linear MCP read tools; stop if missing/ambiguous.
2. If an old id resolves to a new canonical id, use and disclose the canonical id.
3. Capture title, URL, full description, state name/type, team metadata, relations, comments, acceptance criteria, and repo/path/project clues.
4. Fetch blocker state type separately when needed and possible.
5. Blocker satisfaction:
   - `completed` type → satisfied
   - Any other known type → unsatisfied while the blocked-by relation exists
   - Missing/unknown type → unresolved and blocking until confirmed
6. Derive a lowercase kebab slug from the title, about 40 characters; fallback `issue`.

## Phase 3: Resolve and Validate Code Context

No repo → `ANALYSIS_MODE=text-only`.

With a repo:

1. Prefer an auto-selected worktree, current `linear-<issue_id>-*` checkout, exact issue worktree, unique registered `.worktrees/<issue_id>-*`, then current checkout.
2. Compare issue repo clues with origin URL, repo basename, manifests, referenced paths, and project guidance.
3. Clear match → code mode.
4. Clear mismatch or no useful clue → disclose it and ask whether to confirm this repo, provide another repo, or continue text-only. Make no code-grounded claims before confirmation.
5. Record mode as confirmed code, user-confirmed code, or text-only.

## Phase 4: Read Project Context

Skip in text-only mode. In `WORK_DIR`, read applicable root/scoped repository guidance (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or equivalent), then `docs/PRD.md` and the relevant design source when present (`docs/DESIGN.md` → `docs/design/DESIGN.md` → relevant `design-system/` files).

## Phase 5: Analyze

Use read-only tools and safe read-only shell commands. Produce:

- **Details to confirm** — ambiguity, missing/untestable criteria, inconsistent comments/fields, and requirement/context conflicts.
- **Risks** — severity plus evidence:
  - Code mode: `path:line` for modules, patterns, prerequisites, migrations/compatibility, blast radius, and AC feasibility.
  - Text-only: no code claims; cite `issue description`, a numbered criterion, a dated/attributed comment, or a relation id.
- **Dependencies** — blocked-by relations with state name/type/satisfaction, issues blocked, and code prerequisites in code mode.
- **Open questions** — unanswered by the sources available in the selected mode.
- **Verdict**:
  - `ready` — well specified, risks understood, no unsatisfied/unknown blockers
  - `needs-clarification` — requirements/criteria prevent a confident start
  - `blocked` — unsatisfied/unknown blocker or hard prerequisite

Text-only mode may be specification-ready, but must state that code feasibility was not assessed.

## Phase 6: Briefing and Discussion

Present a `Clarification Briefing — <ISSUE-ID>` with readiness, analysis mode, four analysis buckets, severity, and source-specific evidence. Then walk substantive open items one at a time using portable interaction; batch trivial confirmations. Record outcomes as **resolved here** or **still open**. Skip discussion if nothing is open.

## Phase 7: Readiness Summary

Present on screen only:

- Verdict (`ready to implement`, `needs author input`, or `blocked by …`)
- Analysis mode
- Resolved decisions
- Open questions for the author
- Key risks
- Suggested next step: use `implement-ticket-linear <ISSUE-ID>`, or resolve blockers first

## Safety rules

- Linear read operations only: never update state, description, comments, criteria, assignee, labels, project, or other fields.
- Repository read-only: never edit files or git, commit, or run mutating/destructive commands.
- Do not use `docs/tickets/`.
- Do not call implementation, update, commit, or PR skills; only suggest them.
- Never guess missing tools, ambiguous issues, repo relevance, or blocker state.
