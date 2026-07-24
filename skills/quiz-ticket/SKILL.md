---
name: quiz-ticket
description: "Quiz your understanding of an implemented docs/tickets/ ticket, or generate a stakeholder explainer with `explain`. Use only when the request names docs/tickets/, a TICKET-NNN reference, or the quiz-ticket skill; do not use for Linear issue IDs or URLs. Reads the ticket and its implementation diff, then asks understanding-check questions one at a time and corrects misconceptions with file:line evidence. Read-only: never edits tickets, INDEX.md, or git; writes a file only when the user asks to save the explainer."
user-invocable: true
disable-model-invocation: true
argument-hint: "[ticket] [explain]"
---

**Invocation input:** `$ARGUMENTS`

# Quiz an Implemented Ticket (advisory, read-only)

Verify the user's understanding of what was actually built for one `docs/tickets/` ticket, or produce a stakeholder explainer. Agent-implemented code the user has not internalized is a blind spot waiting to bite; this skill turns the implementation's unknowns back into known knowns. The quiz hunts the user's unknown unknowns (behavior they never considered), surfaces unknown knowns (things they would recognize but could not state), and answers known unknowns with `path:line` evidence.

Use `docs/tickets/` as the source of truth. Do not use Linear. For a Linear issue, use the `quiz-ticket-linear` skill.

## Portable interaction rules

- Resolve the ticket reference from populated invocation input when available; otherwise use the ticket reference in the surrounding user request. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- Ask questions one at a time and wait for the answer before continuing.
- When the user must select or confirm something, show every candidate with a stable ticket id and distinguishing label.
- Use the host's structured choice mechanism only when it is available and can represent the candidates clearly. Otherwise ask a concise numbered prose question and accept a ticket id or number.
- Never assume an option limit or an automatically supplied "Other" choice.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites and argument grammar

Require a git repository containing `docs/tickets/`. If it is missing, stop with a short hint that Linear issues use `quiz-ticket-linear`.

Accept one optional `<ticket>` plus one optional mode token:

| Input | Meaning |
| --- | --- |
| `TICKET-007`, `007`, `#7`, or `7` | Quiz that ticket; normalize to three-digit `NNN`. |
| `<ticket> explain` | Produce a stakeholder explainer instead of a quiz. |
| Empty | Auto-detect a recently implemented ticket, then quiz it. |

`explain` is case-insensitive and must be the last token. Reject status tokens, multi-ticket batches, write/commit flags, invalid refs, and extra tokens.

## Phase 1: Resolve the Ticket

1. Resolve the repository root:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. Parse the invocation input or surrounding request. If a ticket ref exists, normalize it to `NNN`; otherwise auto-detect:
   - Current branch matching `^ticket-(\d{3})-.+$` → use its `NNN`.
   - Otherwise registered worktrees under `$MAIN_ROOT/.worktrees/` with branches matching `^ticket-(\d{3})-.+$`.
   - Otherwise `INDEX.md` rows whose status is `in-progress` or `done`, most recently touched first (judge by `git log` mentions of the ticket file).
   - One candidate → ask for confirmation; multiple → apply the portable interaction rules; none → stop and request a ticket number.
3. Resolve exactly one `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match or multiple matches → stop and report the problem. Derive `slug` from the filename.

## Phase 2: Read Ticket and Project Context

1. Read the full ticket file, including its `## As-Built Notes` section when present — deviations documented there are prime quiz material — and any `## References` section.
2. Read the ticket's `INDEX.md` row. If the status is `pending`, warn that the ticket appears unimplemented and ask whether to continue anyway.
3. Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent) to calibrate terminology to the project's conventions.

## Phase 3: Locate and Study the Implementation

1. Locate the implementation diff, in order:
   - A registered worktree `$MAIN_ROOT/.worktrees/NNN-*` (branch `ticket-NNN-*`): diff that branch against its merge base with its base branch.
   - A local branch `ticket-NNN-*`: the same merge-base diff.
   - Commits whose messages reference `TICKET-NNN` or the ticket filename: their combined diff.
   - Otherwise ask the user where the implementation lives (a branch, a commit range, or current uncommitted changes); also accept "use the current state of the files the ticket names."
2. Read the diff AND the full current content of each changed file — questions must reflect the code as it exists, not just the delta.
3. Note behaviors worth probing: non-obvious decisions, edge-case handling, integration points, and anything `## As-Built Notes` flags as a deviation.

## Phase 4: Quiz Mode (default)

Build 5–8 questions mixing three kinds:

- **Why** — design decisions and trade-offs ("Why does the export run in a worker instead of the request handler?")
- **Behavior** — what the code does in a specific scenario ("What happens when the list is empty?")
- **Where** — which code handles a responsibility ("Where is the retry limit enforced?")

Rules:

- Ask the questions one at a time using the portable interaction rules; wait for each answer before continuing.
- After each answer, confirm or correct with `path:line` evidence. Coach, don't grade — no scores, no letter grades.
- Prioritize questions about deviations recorded in `## As-Built Notes` and code the user is least likely to have read.
- Stop early if the user asks to stop; go deeper on a topic when they ask.

Close with an understanding summary, on screen only:

```
## Understanding Summary — TICKET-NNN
**Solid** — areas the user explained correctly
**Gaps** — misconceptions corrected, each with the relevant `path:line`
**Worth rereading** — files or functions to review
```

## Phase 5: Explain Mode (`explain` argument)

Skip the quiz. Produce a stakeholder-facing explainer in chat:

```
## Explainer — TICKET-NNN: <title>
**What changed** — plain-language summary of the delivered behavior
**Why** — the problem it solves, from the ticket's Description
**Impact** — what users or dependent systems will notice
**Risks and limitations** — known edge cases and deferred work from `## As-Built Notes`
**Follow-ups** — open items, if any
```

Write for a reader who has not seen the code; name files only when they aid navigation. Then offer once to save the explainer to a file path the user names; write the file only if they provide a path.

## Safety rules

- Never edit ticket files, `INDEX.md`, other repo files, or git state; never commit; never run mutating shell commands. The only permitted write is the explainer file, at an explicit user-provided path.
- Do not use Linear.
- Do not invoke `implement-ticket`, `update-ticket`, `review-ticket`, or commit skills; only suggest next steps.
- If the implementation cannot be located, ask — never quiz from guessed code.
