# clarify-ticket-linear — Design

**Date:** 2026-07-23
**Status:** Approved (design), pending implementation plan
**Author:** Calvin Ku (with Claude Code)

## Summary

A new cktk skill, `clarify-ticket-linear`, that fetches a Linear issue, runs a
codebase-grounded clarity/risk analysis, briefs the user, discusses the open
items interactively, and ends with a readiness summary. It is the
pre-implementation "understand & de-risk" step in the ticket lifecycle.

It is **strictly advisory and read-only**: it never modifies the Linear issue
and never touches the repo or git. Its only output is the on-screen briefing and
summary.

## Lifecycle placement

```
create-tickets → clarify-ticket-linear → implement-ticket-linear → review-ticket → update-ticket-linear
```

`clarify-ticket-linear` is the "understand & de-risk before building" step. It
mirrors the naming and structure of the existing Linear-backed skills
(`implement-ticket-linear`, `update-ticket-linear`).

## Identity & contract

- **Name:** `clarify-ticket-linear`
- **Frontmatter:** `user-invocable: true`
- **Purpose:** fetch a Linear issue → codebase-grounded clarity/risk analysis →
  briefing → interactive discussion → readiness summary.
- **Read-only guarantee:** never changes the Linear issue (no state, comment,
  description, or acceptance-criteria edits); never edits repo files; never
  commits. Both Linear and the codebase are read-only.
- **Source of truth:** the Linear issue. Does not use `docs/tickets/`.

## Prerequisites

1. **Linear MCP** must be available and authenticated (official:
   `https://mcp.linear.app/mcp`). **Read-only tools suffice** — get/search
   issue, list relations, get comments. No write tools are needed, which
   reinforces the advisory-only contract. (Team workflow states are not listed
   or mapped — the readiness verdict is the skill's own, independent of Linear
   states.)
2. If Linear MCP tools are missing, stop with a short setup hint. Do **not**
   invent API-key, CLI, or browser fallbacks (consistent with the other
   `-linear` skills).
3. Prefer the host's actual Linear MCP tool names; discover schemas rather than
   inventing fields.

## Argument grammar

Reuses `update-ticket-linear`'s resolver.

| Invocation | Meaning |
| --- | --- |
| `<issue>` | A Linear identifier `TEAM-NUM` (e.g. `ENG-42`, case-insensitive; team key uppercased) or a Linear issue URL containing that identifier. |
| *(empty)* | Auto-detect from the current branch `^linear-<issue>-` or a matching `.worktrees/` linear worktree. 2+ candidates → `AskUserQuestion`. 0 candidates → stop and ask for an id. |

No status token is accepted. Extra or unrecognized tokens → stop with an
unrecognized-arguments error.

## Phases (architecture + data flow)

### Phase 1 — Parse & resolve handles
- Confirm a git repo; compute `MAIN_ROOT` and `CURRENT_ROOT` (same commands as
  `update-ticket-linear`).
- Parse `$ARGUMENTS`: issue ref, or empty → auto-detect (branch match
  `^linear-([A-Za-z]+-[0-9]+)-`, then registered `.worktrees/` linear worktrees).
- Normalize the issue id (uppercase team key; extract from URL).

### Phase 2 — Fetch issue (read-only)
Fetch and capture:
- Title, URL, description/body (full text)
- Current workflow state (name + type)
- Team id/key, priority, labels, project, cycle
- Relations: **blocks**, **blocked by**, related (+ their states where returned)
- Comments
- Acceptance criteria: checklist lines (`- [ ]` / `- [x]`) or a labeled
  Acceptance Criteria section
- Derive **slug** from the title (same rules as the other `-linear` skills) and
  compute worktree handles (`$MAIN_ROOT/.worktrees/<issue>-<slug>`,
  `linear-<issue>-<slug>`) to locate code context.

### Phase 3 — Resolve code context (`WORK_DIR`)
- Prefer `CURRENT_ROOT` when its branch matches `^linear-<issue>-.+$`.
- Else a matching `.worktrees/<issue>-*` registered worktree.
- Else the main checkout.
- If there is no usable repo context, run in **text-only mode** and flag it
  clearly in the briefing.

### Phase 4 — Codebase-grounded analysis
Read-only exploration (grep/glob/read + safe read-only commands only — never
mutating or destructive). Produces four buckets plus a verdict:

- **Details to confirm** — ambiguities, underspecified requirements, undefined
  terms, missing or untestable acceptance criteria.
- **Risks (grounded)** — files/modules the work will touch, conflicting
  patterns, missing prerequisites, migration/data/breaking-change/blast-radius
  concerns, and whether the acceptance criteria are feasible against the real
  code. Each risk tagged with **severity + evidence** (`path:line`).
- **Dependencies** — Linear relations (blocked-by / blocks + their states) and
  code-level prerequisites.
- **Open questions** — what neither the ticket nor the code answers; candidates
  to take back to the ticket author.
- **Readiness verdict** — `ready` / `needs-clarification` / `blocked`.

### Phase 5 — Briefing
Present the four buckets + verdict on screen, e.g.:

```
## Clarification Briefing — ENG-42: <title>
**Readiness:** needs-clarification

### Details to confirm
- ...

### Risks (code-grounded)
- [high] ... — evidence: `src/foo.ts:120`

### Dependencies
- blocked by ENG-40 (In Progress)

### Open questions
1. ...
```

### Phase 6 — Guided discussion
Walk the open items one topic at a time (via `AskUserQuestion` or prose).
Record each as **resolved-here** (the user answered) or **still-open-for-author**
(needs external input). Batch trivial confirmations; surface the substantive
ones for real discussion.

### Phase 7 — Readiness summary (on-screen only)
```
## Clarification Summary — ENG-42
**Verdict:** ready to implement / needs author input / blocked by <...>
**Resolved:** ...
**Open questions for the author:** ...
**Key risks to watch during implementation:** ...
**Suggested next step:** /implement-ticket-linear ENG-42  (or resolve blockers first)
```
No writes anywhere — Linear, files, and git are untouched.

## Error handling & safety

- Always require Linear MCP read tools; never invent HTTP/API/CLI/browser
  fallbacks.
- **Read-only everywhere:** no Linear mutations (state, comment, description,
  AC), no file edits, no commits, no mutating/destructive shell commands.
- Missing / unresolvable / ambiguous issue → stop.
- No usable repo context → text-only mode, clearly flagged.
- Do not invoke mutating cktk skills (`implement-ticket-linear`,
  `update-ticket-linear`, `commit-ticket`, …) — only *suggest* them as next
  steps.
- An unrelated dirty working tree does not block analysis (reads only), but note
  it if it muddies code-context reads.

## Packaging (verified against `update-ticket-linear`)

- `skills/clarify-ticket-linear/SKILL.md` — canonical (full, `user-invocable: true`).
- `.agent/skills/clarify-ticket-linear` → **symlink** to
  `../../skills/clarify-ticket-linear`.
- `.agents/skills/clarify-ticket-linear/SKILL.md` — condensed multi-agent
  variant (uses the `$clarify-ticket-linear` invocation convention).
- `.agents/skills/clarify-ticket-linear/agents/openai.yaml` — Codex/OpenAI
  variant config.
- Register in `catalog.json`, `.claude-plugin/plugin.json`, and `README.md`.

## Validation

No code ships, so validation is:
- A manual dry-run against a real `ENG-*` issue confirming: correct fetch,
  read-only behavior (zero writes to Linear or git), a sensible codebase-grounded
  briefing, a real interactive discussion, and a clean readiness summary.
- Auto-detect verified from a `linear-<issue>-*` branch and from a matching
  `.worktrees/` worktree.
- `scripts/check-codex-skills.sh` (and any other skill validators) pass for the
  new skill.

## Out of scope (YAGNI)

- Writing back to Linear (description edits, AC changes, risk comments) — this
  was explicitly deferred; `clarify-ticket-linear` stays advisory. A future
  `refine-ticket-linear` could own write-back.
- Saving a local prep-note file for `implement-ticket-linear` to consume — also
  deferred; the summary is on-screen only.
- Any `docs/tickets/` (markdown) support — this skill is Linear-only.
