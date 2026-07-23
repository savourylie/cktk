# clarify-ticket — Design

**Date:** 2026-07-24
**Status:** Approved (design), pending implementation plan
**Author:** Calvin Ku (with Claude Code)

## Summary

A new cktk skill, `clarify-ticket`, the markdown-ticket twin of
`clarify-ticket-linear` (see
`docs/superpowers/specs/2026-07-23-clarify-ticket-linear-design.md`). It fetches
a ticket from `docs/tickets/`, runs a codebase-grounded clarity/risk analysis,
briefs the user, discusses the open items interactively, and ends with a
readiness summary.

It is **strictly advisory and read-only**: it never edits ticket files or
`INDEX.md`, never commits, and never touches Linear. Its only output is the
on-screen briefing and summary.

## Lifecycle placement

```
create-tickets → clarify-ticket → implement-ticket → review-ticket → update-ticket
```

The pre-implementation "understand & de-risk" step for the markdown-ticket
workflow, mirroring where `clarify-ticket-linear` sits in the Linear workflow.

## Identity & contract

- **Name:** `clarify-ticket`
- **Frontmatter:** `user-invocable: true`
- **Purpose:** read a `docs/tickets/` ticket → codebase-grounded clarity/risk
  analysis → briefing → interactive discussion → readiness summary.
- **Read-only guarantee:** never edits ticket files, `INDEX.md`, or any other
  repo file; never commits; never runs mutating/destructive shell commands.
- **Source of truth:** `docs/tickets/`. This skill has no Linear involvement
  and no MCP prerequisite — the only requirement is a git repo containing
  `docs/tickets/`.

## Parity deltas vs clarify-ticket-linear

Exactly four deliberate differences; everything else mirrors the Linear twin:

1. **Local files instead of Linear MCP** — the ticket file and `INDEX.md` are
   the source; no MCP prerequisite or setup hint.
2. **INDEX.md auto-detect fallback** — empty-argument detection has a third
   step the Linear twin lacks (chosen during design): list `pending` tickets
   from `INDEX.md` and let the user pick.
3. **Reverse-dependency grep instead of Linear relations** — "blocked by"
   comes from the ticket's `- Requires:` line; "blocks" comes from grepping
   other tickets' `Requires:` lines for `#NNN`.
4. **PRD/design-source cross-checking** — when present, `docs/PRD.md` and the
   design source are read and the ticket is checked against them (spec-conflict
   findings the Linear side cannot make).

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Clarify that ticket. Accept `TICKET-007`, `007`, `#7`, or `7`; normalize to a 3-digit zero-padded `NNN`. |
| *(empty)* | Auto-detect (below). |

No status token is accepted. Extra or unrecognized tokens → stop with an
unrecognized-arguments error.

### Auto-detect (empty arguments only)

1. **Current branch.** `git branch --show-current` matching
   `^ticket-(\d{3})-.+$` → use that `NNN`, set `WORK_DIR=$CURRENT_ROOT`,
   announce in one line.
2. **Registered ticket worktrees.** Inspect `git worktree list --porcelain`
   for paths under `$MAIN_ROOT/.worktrees/` whose branch matches
   `^ticket-(\d{3})-.+$`. 1 candidate → use it (set `WORK_DIR` to it);
   2+ → pick via `AskUserQuestion` (cap 4 options, rely on "Other");
   0 → continue.
3. **INDEX.md fallback.** Read `$MAIN_ROOT/docs/tickets/INDEX.md` and collect
   every ticket whose Status column contains `` `pending` `` (backtick-wrapped).
   1+ candidates → pick via `AskUserQuestion` (options labeled
   `TICKET-NNN — <title>`; if more than 4, list the 4 lowest ticket numbers —
   the natural next work — and rely on "Other"). 0 candidates → stop:
   `No ticket number was passed, the current branch isn't a ticket-NNN-<slug>
   branch, no ticket worktree exists, and no tickets are marked pending in
   INDEX.md. Please pass a ticket number (e.g., /clarify-ticket 007).`

## Phases

### Phase 1 — Parse & resolve handles
- Confirm a git repo; compute `MAIN_ROOT` and `CURRENT_ROOT` (same commands as
  the sibling skills).
- Parse `$ARGUMENTS`; normalize the ticket number or run auto-detect.
- Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match → stop
  (`TICKET-NNN not found in docs/tickets/`); multiple matches → stop
  (ambiguity). Slug = filename minus `NNN-` prefix and `.md` suffix.

### Phase 2 — Read the ticket (read-only)
Capture from the ticket file:
- Title (from the `# [TICKET-NNN] Title` header), full body
- `## Status` current value (context only)
- `## Acceptance Criteria` checklist lines (`- [ ]` / `- [x]`)
- `- Requires:` dependencies with their `✅` markers (blocked-by)
- Implementation Notes / Testing sections if present
- The ticket's row in `$MAIN_ROOT/docs/tickets/INDEX.md` (status, depends-on,
  notes)
- **Reverse dependencies:** grep all files in `$MAIN_ROOT/docs/tickets/` for
  `#NNN` on lines containing `Requires:` — these tickets are what this ticket
  blocks.
- Compute worktree handles: path `$MAIN_ROOT/.worktrees/NNN-<slug>`, branch
  `ticket-NNN-<slug>`.

### Phase 3 — Resolve code context (WORK_DIR)
If not already set by auto-detect:
1. Prefer `$CURRENT_ROOT` when its branch matches `^ticket-NNN-.+$`.
2. Else a registered worktree at `$MAIN_ROOT/.worktrees/NNN-<slug>` (announce
   in one line).
3. Otherwise `WORK_DIR=$CURRENT_ROOT`.

There is no text-only mode: tickets live inside the repo by definition. All
code inspection is read-only and runs against `WORK_DIR`.

### Phase 4 — Codebase-grounded analysis
Read-only exploration (grep/glob/read + safe read-only shell only). Same four
buckets + verdict as the Linear twin:

- **Details to confirm** — ambiguities, underspecified requirements, undefined
  terms, missing/vague/untestable acceptance criteria.
- **Risks (code-grounded)** — files/modules the work will touch, conflicting
  patterns, missing prerequisites, migration/data/breaking-change/blast-radius
  concerns, acceptance-criteria feasibility. Severity (`high`/`medium`/`low`)
  + evidence (`path:line`) on each.
- **Dependencies** — `Requires:` deps (with ✅ state and each dep ticket's
  current status), reverse deps (tickets this one blocks), and code-level
  prerequisites.
- **Open questions** — what neither the ticket nor the code answers.
- **Readiness verdict** — `ready` / `needs-clarification` / `blocked`.
  Unsatisfied `Requires` deps (no `✅` and the dep ticket is not `done`)
  weigh toward `blocked`.

**Additional context inputs (markdown-side delta):** when present, read
`$WORK_DIR/docs/PRD.md` and the design source — `docs/DESIGN.md`, else
`docs/design/DESIGN.md`, else a `design-system/` folder (same lookup order as
`implement-ticket`) — and check the ticket against them. Conflicts between the
ticket and PRD/design are Details-to-confirm or Risk findings with file
references.

### Phase 5 — Present the briefing
Same template as the Linear twin:

```
## Clarification Briefing — TICKET-NNN: <title>
**Readiness:** <ready | needs-clarification | blocked>
**Code context:** <main checkout | .worktrees/NNN-<slug>>

### Details to confirm
- ...

### Risks (code-grounded)
- [high] ... — evidence: `src/...:NN`

### Dependencies
- Requires #NNN (<status>, ✅/not satisfied) ...
- Blocks #MMM ...

### Open questions
1. ...
```

### Phase 6 — Guided discussion
One topic at a time (`AskUserQuestion` for crisp choices, prose otherwise).
Record each item as **resolved here** or **still open**. Batch trivial
confirmations; keep it efficient.

### Phase 7 — Readiness summary (on-screen only)

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

No writes anywhere.

## Error handling & safety

- Missing `docs/tickets/` or unresolvable/ambiguous ticket → stop.
- **Read-only everywhere:** no ticket-file or `INDEX.md` edits, no status
  changes, no AC checkbox changes, no commits, no mutating/destructive shell.
- Do not invoke mutating cktk skills (`implement-ticket`, `update-ticket`,
  `commit-ticket`, `commit-push-pr`, `create-worktree`) — only *suggest* them
  as next steps.
- No Linear involvement of any kind (that is `clarify-ticket-linear`).
- An unrelated dirty working tree does not block analysis, but note it if it
  muddies code-context reads.

## Packaging (mirrors clarify-ticket-linear)

- `skills/clarify-ticket/SKILL.md` — canonical (full, `user-invocable: true`).
- `.agent/skills/clarify-ticket` → **symlink** to `../../skills/clarify-ticket`.
- `.agents/skills/clarify-ticket/SKILL.md` — condensed multi-agent variant
  (uses the `$clarify-ticket` invocation convention).
- `.agents/skills/clarify-ticket/agents/openai.yaml` — Codex variant config
  (`allow_implicit_invocation: false`).
- Register in `catalog.json`, `.claude-plugin/plugin.json` keywords, and
  `README.md`.
- **Placement rule:** `clarify-ticket` goes **immediately before
  `clarify-ticket-linear`** in every ordered list, keeping each base/`-linear`
  pair adjacent (`… implement-ticket, clarify-ticket, clarify-ticket-linear,
  implement-ticket-linear …`).
- README installer-count wording bumps from "twenty-three" to "twenty-four".

## Validation

- `scripts/check-codex-skills.sh` passes (28 skills after this change) and
  both JSON files stay valid.
- Behavioral dry-run — runnable locally (no external service): in a repo with
  `docs/tickets/` (or a scratch fixture), run `/clarify-ticket NNN` and
  confirm: correct ticket read, a briefing with the four buckets + verdict +
  code-context line, a real interactive discussion, a clean summary, and zero
  writes (`git status --porcelain` empty; ticket file and INDEX.md unchanged).
- Auto-detect verified from a `ticket-NNN-<slug>` branch, from a matching
  worktree, and via the INDEX.md pending fallback.

## Out of scope (YAGNI)

- Editing tickets (AC changes, status updates, INDEX refresh) — that is
  `update-ticket`'s job, post-implementation.
- Any Linear support — that is `clarify-ticket-linear`.
- Saving a local prep-note file for `implement-ticket` to consume — the
  summary is on-screen only, matching the Linear twin's deliberate choice.
