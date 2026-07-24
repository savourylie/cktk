---
name: "quiz-ticket-linear"
description: "Use only when the user explicitly asks to quiz their understanding of an implemented Linear issue, or to generate a stakeholder explainer for one, or invokes quiz-ticket-linear. Do not use for docs/tickets/ markdown tickets. Fetches the issue via read-only Linear MCP tools, studies the local implementation diff, asks understanding-check questions one at a time (default), or with `explain` produces a what-changed/why/impact explainer. Never modifies Linear or git. Requires Linear MCP."
---

# Quiz an Implemented Linear Issue (advisory, read-only)

Verify the user's understanding of what was actually built for one Linear issue, or with `explain` produce a stakeholder explainer. The quiz hunts unknown unknowns (behavior never considered), surfaces unknown knowns (recognized but unstated), and answers known unknowns with `path:line` evidence. Never modify Linear or git. Use `quiz-ticket` for markdown tickets.

Resolve the issue reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. A trailing `explain` token (case-insensitive) switches to explain mode. Empty input means auto-detect from `linear-*` branches.

## Portable interaction

When asking questions or requesting selection:

1. Ask questions one at a time and wait for the answer before continuing.
2. Show every candidate with a stable issue id/path and distinguishing label.
3. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
4. Never assume an option limit or implicit "Other" choice.

Refer to follow-up skills by name. Use host-native invocation syntax when known; otherwise show the plain skill name and arguments.

## Phase 1: Resolve and Fetch

1. Require authenticated Linear MCP read tools (no HTTP/API-key/CLI fallbacks) and a git repository, then resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. Normalize the issue ref (`TEAM-NUMBER` id or URL; uppercase the team key). With no ref, auto-detect from current or worktree branches matching `linear-<TEAM-NUMBER>-*`; confirm the pick.
3. Fetch the issue by exact identifier: title, description, state, acceptance criteria, relations, and comments — including any as-built comment a previous implement run posted.

## Phase 2: Study

1. Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent).
2. Locate the implementation diff, in order: registered worktree `.worktrees/<issue_id>-*`, local `linear-<issue_id>-*` branch (merge-base diff), commits referencing the issue id, or ask the user (branch, commit range, or current changes).
3. Read the diff and the full current content of every changed file. Note non-obvious decisions, edge cases, integration points, and deviations flagged in the as-built comment.

## Phase 3a: Quiz (default)

Build 5–8 questions mixing why (design decisions), behavior (what happens when X), and where (which code handles Y). Ask one at a time; after each answer, confirm or correct with `path:line` evidence. Coach, don't grade. Prioritize as-built deviations and code the user likely has not read. Close with an on-screen understanding summary: solid areas, corrected gaps with evidence, and files worth rereading.

## Phase 3b: Explain (`explain` token)

Skip the quiz. Present a stakeholder explainer: what changed (plain language), why, impact on users and dependent systems, risks/limitations (including deferred work from the as-built comment), and follow-ups. Offer once to save it to a user-named path; write only if a path is provided.

## Safety rules

- Linear is strictly read-only here: never change state, description, comments, assignee, labels, or any field — this skill never writes to Linear, not even a comment.
- Repository read-only: never edit files or git; never commit or run mutating commands. The only permitted write is the explainer file at an explicit user-provided path.
- Do not use `docs/tickets/` as the ticket source.
- Do not call implementation, update, or commit skills; only suggest them.
- If the implementation cannot be located, ask — never quiz from guessed code.
