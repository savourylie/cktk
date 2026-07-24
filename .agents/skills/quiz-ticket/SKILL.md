---
name: "quiz-ticket"
description: "Use only when the user explicitly asks to quiz their understanding of an implemented docs/tickets/ ticket, or to generate a stakeholder explainer for one, or invokes quiz-ticket. Do not use for Linear issue ids or URLs. Reads the ticket and its implementation diff, asks understanding-check questions one at a time (default), or with `explain` produces a what-changed/why/impact explainer. Read-only: never edits tickets, INDEX.md, or git."
---

# Quiz an Implemented Ticket (advisory, read-only)

Verify the user's understanding of what was actually built for one `docs/tickets/` ticket, or with `explain` produce a stakeholder explainer. The quiz hunts unknown unknowns (behavior never considered), surfaces unknown knowns (recognized but unstated), and answers known unknowns with `path:line` evidence. Never edit files or git. Use `quiz-ticket-linear` for Linear issues.

Resolve the ticket reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. A trailing `explain` token (case-insensitive) switches to explain mode. Empty input means auto-detect.

## Portable interaction

When asking questions or requesting selection:

1. Ask questions one at a time and wait for the answer before continuing.
2. Show every candidate with a stable ticket id and distinguishing path/title.
3. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
4. Never assume an option limit or implicit "Other" choice.

Refer to follow-up skills by name. Use host-native invocation syntax when known; otherwise show the plain skill name and arguments.

## Phase 1: Resolve Ticket and Implementation

1. Require a git repo with `docs/tickets/`, then resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. Normalize the ticket ref (`TICKET-007`, `007`, `#7`, `7`) to `NNN`; with no ref, auto-detect from a `ticket-NNN-*` branch, a registered `.worktrees/` entry, or `in-progress`/`done` INDEX rows (confirm the pick). Resolve exactly one `$MAIN_ROOT/docs/tickets/NNN-*.md`; stop on zero/multiple matches.
3. Locate the implementation diff, in order: registered worktree `.worktrees/NNN-*`, local `ticket-NNN-*` branch (merge-base diff), commits referencing `TICKET-NNN`, or ask the user (branch, commit range, or current changes).

## Phase 2: Study

1. Read the full ticket, including `## As-Built Notes` and `## References` when present, plus the matching INDEX row (warn and confirm if status is `pending`).
2. Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent).
3. Read the diff and the full current content of every changed file. Note non-obvious decisions, edge cases, integration points, and documented deviations.

## Phase 3a: Quiz (default)

Build 5–8 questions mixing why (design decisions), behavior (what happens when X), and where (which code handles Y). Ask one at a time; after each answer, confirm or correct with `path:line` evidence. Coach, don't grade. Prioritize `## As-Built Notes` deviations and code the user likely has not read. Close with an on-screen understanding summary: solid areas, corrected gaps with evidence, and files worth rereading.

## Phase 3b: Explain (`explain` token)

Skip the quiz. Present a stakeholder explainer: what changed (plain language), why, impact on users and dependent systems, risks/limitations (including deferred work from `## As-Built Notes`), and follow-ups. Offer once to save it to a user-named path; write only if a path is provided.

## Safety rules

- Read-only: never edit tickets, INDEX, repo files, or git; never commit or run mutating commands. The only permitted write is the explainer file at an explicit user-provided path.
- Do not use Linear.
- Do not call implementation, update, review, or commit skills; only suggest them.
- If the implementation cannot be located, ask — never quiz from guessed code.
