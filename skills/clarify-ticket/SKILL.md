---
name: clarify-ticket
description: "Clarify a markdown ticket from docs/tickets/ before implementation. Use only when the request names docs/tickets/, a TICKET-NNN reference, or the clarify-ticket skill; do not use for Linear issue IDs or URLs. Read the ticket, validate it against the tracker and codebase, discuss ambiguities and risks, and produce a readiness summary. Strictly read-only: never edit tickets, INDEX.md, repo files, or git."
user-invocable: true
disable-model-invocation: true
argument-hint: "[ticket]"
---

**Invocation input:** `$ARGUMENTS`

# Clarify a Markdown Ticket (advisory, read-only)

Read one ticket from `docs/tickets/`, analyze it against the tracker and actual codebase, discuss unresolved details with the user, and end with a readiness summary. **Never** edit ticket files, `INDEX.md`, any other repo file, or git.

Use `docs/tickets/` as the source of truth. Do not use Linear. For a Linear issue, use the `clarify-ticket-linear` skill.

## Portable interaction rules

- Resolve the ticket reference from populated invocation input when available; otherwise use the ticket reference in the surrounding user request. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- When the user must select or confirm something, show every candidate with a stable ticket id and distinguishing label.
- Use the host's structured choice mechanism only when it is available and can represent the candidates clearly. Otherwise ask a concise numbered prose question and accept a ticket id or number.
- Never assume an option limit or an automatically supplied “Other” choice.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites and argument grammar

Require a git repository containing `docs/tickets/`. If it is missing, stop with a short hint that Linear issues use `clarify-ticket-linear`.

Accept one optional `<ticket>`:

| Input | Meaning |
| --- | --- |
| `TICKET-007`, `007`, `#7`, or `7` | Clarify that ticket; normalize to three-digit `NNN`. |
| Empty | Auto-detect a ticket, then clarify it. |

Reject status tokens, multi-ticket batches, write/commit flags, invalid ticket refs, and extra tokens.

## Phase 1: Resolve the Ticket and Code Context

1. Resolve repository roots:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse the invocation input or surrounding request. If a ticket ref exists, normalize it to `NNN`; otherwise auto-detect:
   - Current branch matching `^ticket-(\d{3})-.+$` → use its `NNN` and set `WORK_DIR=$CURRENT_ROOT`.
   - Otherwise inspect registered worktrees under `$MAIN_ROOT/.worktrees/` and collect branches matching `^ticket-(\d{3})-.+$`.
   - One worktree candidate → use it. Multiple candidates → apply the portable interaction rules.
   - No worktree candidate → read `INDEX.md` and collect rows whose Status column is exactly backtick-wrapped `pending`. One candidate → ask for confirmation; multiple → ask the user to select from the complete candidate list; none → stop and request a ticket number.
3. Resolve exactly one `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match or multiple matches → stop and report the problem. Derive `slug` from the filename.
4. If `WORK_DIR` is unset, choose code context in this order:
   - `$CURRENT_ROOT` when its branch matches `^ticket-NNN-.+$`.
   - The exact registered worktree `$MAIN_ROOT/.worktrees/NNN-<slug>`.
   - A unique registered worktree under `$MAIN_ROOT/.worktrees/` whose branch matches `^ticket-NNN-.+$`, even if its slug differs because the ticket was renamed.
   - If multiple matching worktrees remain, ask the user to choose using stable paths and branch names.
   - Otherwise use `$CURRENT_ROOT`.
5. Announce the resolved ticket and code context in one line.

## Phase 2: Read and Validate Tracker State

Read the ticket and capture:

- Title from `# [TICKET-NNN] Title` and the full body
- `## Status`
- `## Acceptance Criteria` checklist items
- `- Requires:` dependencies and `✅` markers
- Implementation Notes and Testing sections when present

Read the matching `INDEX.md` row and capture status, dependencies, and notes. Report these tracker-quality problems under **Details to confirm** and set readiness to at least `needs-clarification`:

- Missing, duplicate, or malformed INDEX row
- Ticket status or dependencies disagreeing with INDEX
- Missing/malformed title, status, acceptance criteria, or dependency sections

For each dependency, read its ticket and INDEX status. A dependency is satisfied when it has a `✅` marker or its INDEX status is `done`; report disagreement between those signals.

Find reverse dependencies by parsing only `Requires:` lines and matching the exact token `#NNN` followed by a non-digit or end of line. Never let `#007` match `#0070`.

## Phase 3: Read Project Context

All reads and code inspection run against `WORK_DIR`.

1. Read applicable repository guidance before analysis:
   - Root `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or equivalent host/project instruction files when present
   - More deeply scoped instruction files when they apply to likely affected paths
2. Read `$WORK_DIR/docs/PRD.md` when present.
3. Read the relevant design source when present, in order:
   - `docs/DESIGN.md`
   - `docs/design/DESIGN.md`
   - Relevant files in `design-system/` or `docs/design-system/`
4. Treat conflicts with tracker state, project guidance, PRD, or design as details to confirm or risks with file evidence.

## Phase 4: Codebase-Grounded Analysis

Explore with read-only tools and safe read-only shell commands. Ground every claim in evidence actually found. Produce five buckets plus a verdict.

Frame the analysis with the four types of unknowns:

- **Known knowns** — what the ticket states; verify these against the code.
- **Known unknowns** — gaps the ticket admits; turn each into an open question.
- **Unknown knowns** — details obvious to the user but unwritten; elicit these in the guided discussion.
- **Unknown unknowns** — factors nobody has considered; hunt these in the Blind spots bucket.

### Details to confirm

List ambiguities, undefined terms, tracker inconsistencies, missing or untestable acceptance criteria, and requirement conflicts. Explain why each matters.

### Risks

Tag every risk `high`, `medium`, or `low` and cite `path:line` evidence:

- Likely files/modules and blast radius
- Divergent implementation patterns
- Missing libraries, migrations, flags, configuration, or prerequisites
- Data, compatibility, or breaking-change concerns
- Feasibility of each acceptance criterion

### Blind spots

Deliberately hunt what the ticket does not mention. Check each category against the actual code; report a finding with `path:line` evidence or move on:

- Adjacent code paths that call, render, or depend on the areas this ticket changes
- Error and edge paths the ticket ignores (failures, empty states, concurrency, permissions)
- Data-shape changes with migration, backfill, or rollback implications
- Implicit conventions the ticket silently assumes (project guidance or dominant code patterns)
- Test surface: existing tests that will break, or coverage the ticket does not request

If no category produces a finding, record "No blind spots found" — never silently omit the bucket.

### Dependencies

List:

- `Requires:` dependencies with marker state, INDEX status, and satisfaction result
- Reverse dependencies (tickets this ticket blocks)
- Code-level prerequisites

### Open questions

List only questions that the ticket, tracker, project guidance, requirements/design, and code do not answer.

### Readiness verdict

- `ready` — well specified, risks understood, tracker consistent, and no unmet dependencies
- `needs-clarification` — unresolved ambiguity, untestable criteria, or tracker inconsistency prevents a confident start
- `blocked` — an unsatisfied dependency, missing prerequisite, or other hard blocker prevents starting

## Phase 5: Present the Briefing

Present before discussion:

```
## Clarification Briefing — TICKET-NNN: <title>
**Readiness:** <ready | needs-clarification | blocked>
**Code context:** <main checkout | registered worktree path>

### Details to confirm
- ...

### Risks (code-grounded)
- [high] ... — evidence: `src/...:NN`

### Blind spots
- <category>: ... — evidence: `src/...:NN` (or "No blind spots found")

### Dependencies
- Requires #NNN (<status>, <satisfied | unsatisfied | inconsistent>) ...
- Blocks #MMM ...

### Open questions
1. ...
```

## Phase 6: Guided Discussion

Open with two calibration questions, asked one at a time before the open items:

1. **Unknown knowns** — "What's obvious to you about this ticket that isn't written down?" Fold answers into resolved details, risks, or blind spots.
2. **Experience calibration** — "How familiar are you with this area of the code?" Scale later explanations to the answer: more background when familiarity is low, terser confirmation when high.

Then walk substantive open items one topic at a time using the portable interaction rules. Batch trivial confirmations. Record each outcome as:

- **Resolved here** — capture the user's decision.
- **Still open** — retain it for the ticket author or another external source.

If there are no open items beyond the two calibration questions, proceed directly to the summary after asking them.

## Phase 7: Readiness Summary

Present on screen only:

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
- Use implement-ticket with NNN [worktree], or resolve the blockers/questions first.
```

## Safety rules

- Stay read-only everywhere: no file edits, status/checkbox changes, commits, mutating shell commands, or destructive commands.
- Do not invoke `implement-ticket`, `update-ticket`, `commit-ticket`, `commit-push-pr`, or `create-worktree`; only suggest a next step.
- Do not use Linear.
- Missing or ambiguous ticket/tracker state must never be guessed.
- An unrelated dirty working tree does not block analysis, but disclose it when it makes evidence ambiguous.
