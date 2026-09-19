---
name: "clarify-ticket-linear"
description: "Research how to implement a Linear issue, analyze requirements and risks, discuss material decisions with options, trade-offs, and a recommendation, then produce a readiness summary and implementation plan. Use for pre-implementation research or clarification, or clarify-ticket-linear. Not for local markdown tickets or a purpose-only explanation (explain-ticket). Read-only: never change tickets, repository files, or git."
---

# Clarify a Linear Issue (advisory, read-only)

Fetch one Linear issue, analyze its requirements and risks against relevant code when available, discuss unresolved details, and end with a readiness summary and implementation plan. Never modify Linear, files, or git. Do not use `docs/tickets/`.

Resolve the issue reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. Empty input first uses a single Linear issue established in the conversation, then branch/worktree auto-detection.

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

1. Show every candidate with a stable issue id and distinguishing path/label.
2. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
3. Never assume an option limit or implicit “Other” choice.
4. Accept an unambiguous issue id or path.

Refer to follow-up skills by name. Use host-native invocation syntax when known; otherwise show the plain skill name and arguments.

## Prerequisites

Require authenticated Linear MCP read tools; discover actual host schemas. Missing tools → stop with a setup hint. Never use HTTP, API-key, CLI, or browser fallbacks.

Accept one optional Linear id (`ENG-42`) or issue URL. Reject extra/status/write tokens, title-only search, and multi-issue batches.

## Phase 1: Resolve Issue Reference

1. Parse the issue ref, or reuse the single Linear issue established in the conversation; normalize before requiring git (`TEAM-NUMBER` uppercase; URL must contain a complete id).
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
2. Compare issue repo clues with origin URL, repo basename, manifests, referenced paths, project guidance, and an existing confirmation for this issue/repo. Reuse a prior confirmation unless the repo changed or new evidence contradicts it.
3. Clear match → code mode.
4. Clear mismatch or no useful clue → disclose it and ask whether to confirm this repo, provide another repo, or continue text-only. Make no code-grounded claims before confirmation.
5. Record mode as confirmed code, user-confirmed code, or text-only.

## Phase 4: Read Project Context

Skip in text-only mode. In `WORK_DIR`, read applicable root/scoped repository guidance (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or equivalent), then `docs/PRD.md` and the relevant design source when present (`docs/DESIGN.md` → `docs/design/DESIGN.md` → relevant `design-system/` files).

## Phase 5: Analyze

Frame the analysis with the four types of unknowns: known knowns (verify against code when available), known unknowns (turn into open questions), unknown knowns (elicit in discussion), unknown unknowns (hunt as blind spots).

Use read-only tools and safe read-only shell commands. Produce:

- **Details to confirm** — ambiguity, missing/untestable criteria, inconsistent comments/fields, and requirement/context conflicts.
- **Risks** — severity plus evidence:
  - Code mode: `path:line` for modules, patterns, prerequisites, migrations/compatibility, blast radius, and AC feasibility.
  - Text-only: no code claims; cite `issue description`, a numbered criterion, a dated/attributed comment, or a relation id.
- **Blind spots** — what the issue does not mention. Code mode: adjacent callers/dependents, ignored error and edge paths, migration/backfill/rollback implications, implicit conventions, and test surface, cited as `path:line`. Text-only mode: gaps in the issue text only (unspecified error handling, missing rollout/migration mention, undefined edge cases), citing Linear sources. Record "No blind spots found" when nothing surfaces.
- **Dependencies** — blocked-by relations with state name/type/satisfaction, issues blocked, and code prerequisites in code mode.
- **Open questions** — unanswered by the sources available in the selected mode.
- **Verdict**:
  - `ready` — well specified, risks understood, no unsatisfied/unknown blockers
  - `needs-clarification` — requirements/criteria prevent a confident start
  - `blocked` — unsatisfied/unknown blocker or hard prerequisite

Text-only mode may be specification-ready, but must state that code feasibility was not assessed.

## Phase 6: Briefing, Discussion, and Implementation Plan

Read and follow the [shared implementation discussion](../clarify-ticket/references/implementation-discussion.md).
Use the analysis above to present a concise briefing with the ticket identity,
analysis mode and confirmed code context when available, preliminary readiness,
proposed approach, and an ordered agenda of unresolved decisions and missing facts.

Discuss material decisions one at a time with viable options, their trade-offs,
and a recommendation. Ask calibration questions only when needed; skip settled
questions and do not ask the user to resolve facts available in the sources.
Finish with decisions, ordered implementation steps, acceptance checks, remaining
blockers, and the matching next step, all on screen. Apply this skill's readiness
rules to the final evidence; recommendations are not user decisions.

## Safety rules

- Linear read operations only: never update state, description, comments, criteria, assignee, labels, project, or other fields.
- Repository read-only: never edit files or git, commit, or run mutating/destructive commands.
- Do not use `docs/tickets/`.
- Do not call implementation, update, commit, or PR skills; only suggest them.
- Never guess missing tools, ambiguous issues, repo relevance, or blocker state.
