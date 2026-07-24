---
name: quiz-ticket-linear
description: "Quiz your understanding of an implemented Linear issue, or generate a stakeholder explainer with `explain`. Use only when the request names Linear, a TEAM-NUMBER issue id, a linear.app issue URL, or the quiz-ticket-linear skill; do not use for docs/tickets/ or TICKET-NNN markdown tickets. Fetches the issue via read-only Linear MCP tools, studies the local implementation diff, then asks understanding-check questions one at a time and corrects misconceptions with file:line evidence. Never modifies Linear or git; writes a file only when the user asks to save the explainer."
user-invocable: true
disable-model-invocation: true
argument-hint: "[issue-id-or-url] [explain]"
---

**Invocation input:** `$ARGUMENTS`

# Quiz an Implemented Linear Issue (advisory, read-only)

Verify the user's understanding of what was actually built for one Linear issue, or produce a stakeholder explainer. Agent-implemented code the user has not internalized is a blind spot waiting to bite; this skill turns the implementation's unknowns back into known knowns. The quiz hunts the user's unknown unknowns (behavior they never considered), surfaces unknown knowns (things they would recognize but could not state), and answers known unknowns with `path:line` evidence.

Use Linear as the ticket source of truth. Do not use `docs/tickets/`. For a markdown ticket, use the `quiz-ticket` skill.

## Portable interaction rules

- Resolve the issue reference from populated invocation input when available; otherwise use the identifier or URL in the surrounding user request. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- Ask questions one at a time and wait for the answer before continuing.
- When the user must select or confirm something, show every candidate with a stable issue id/path and distinguishing label.
- Use the host's structured choice mechanism only when available and suitable. Otherwise ask a concise numbered prose question and accept an issue id, number, or path.
- Never assume an option limit or an automatically supplied "Other" choice.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites and argument grammar

Require authenticated Linear MCP read tools; discover the host's actual read-tool schemas instead of inventing names or fields. If unavailable, stop with a short setup hint; do not use HTTP, API-key, CLI, or browser fallbacks.

Also require a git repository — the quiz is grounded in the local implementation. Without one, stop and explain that this skill needs the repo where the issue was implemented.

Accept one optional `<issue>` plus one optional mode token:

| Input | Meaning |
| --- | --- |
| `ENG-42` or another `TEAM-NUMBER` id | Quiz that issue; uppercase the team key. |
| A Linear issue URL containing an id | Extract and quiz that issue. |
| `<issue> explain` | Produce a stakeholder explainer instead of a quiz. |
| Empty | Auto-detect from a `linear-*` git branch or registered worktree. |

`explain` is case-insensitive and must be the last token. Reject status tokens, multi-issue batches, title-only searches, write/commit flags, invalid refs, and extra tokens.

## Phase 1: Resolve the Issue and Fetch It

1. Resolve repository roots:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse the invocation input. Normalize `^[A-Za-z]+-\d+$` by uppercasing the team key; for a URL, extract a complete `TEAM-NUMBER` path token and fail if none exists. With no ref, auto-detect from the current branch or registered worktree branches matching `^linear-([A-Za-z]+-\d+)-.+$`; one candidate → use it; multiple → apply the portable interaction rules; none → stop and request an issue id or URL.
3. Fetch the issue by exact normalized identifier through Linear MCP read tools. Missing or ambiguous → stop. Capture the canonical id, title, description, state, acceptance criteria (checklists or a labeled section), relations, and comments — including any as-built comment a previous `implement-ticket-linear` run posted; deviations documented there are prime quiz material.

## Phase 2: Read Project Context

Within the repo, read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent) to calibrate terminology to the project's conventions.

## Phase 3: Locate and Study the Implementation

1. Derive `slug` from the issue title (lowercase, non-alphanumerics → `-`, collapse, trim, ~40 chars; fallback `issue`). Locate the implementation diff, in order:
   - A registered worktree `$MAIN_ROOT/.worktrees/<issue_id>-*` (branch `linear-<issue_id>-*`): diff that branch against its merge base with its base branch.
   - A local branch `linear-<issue_id>-*`: the same merge-base diff.
   - Commits whose messages reference `<issue_id>`: their combined diff.
   - Otherwise ask the user where the implementation lives (a branch, a commit range, or current uncommitted changes).
2. Read the diff AND the full current content of each changed file — questions must reflect the code as it exists, not just the delta.
3. Note behaviors worth probing: non-obvious decisions, edge-case handling, integration points, and anything the as-built comment flags as a deviation.

## Phase 4: Quiz Mode (default)

Build 5–8 questions mixing three kinds:

- **Why** — design decisions and trade-offs
- **Behavior** — what the code does in a specific scenario
- **Where** — which code handles a responsibility

Rules:

- Ask the questions one at a time using the portable interaction rules; wait for each answer before continuing.
- After each answer, confirm or correct with `path:line` evidence. Coach, don't grade — no scores, no letter grades.
- Prioritize questions about deviations recorded in the as-built comment and code the user is least likely to have read.
- Stop early if the user asks to stop; go deeper on a topic when they ask.

Close with an understanding summary, on screen only:

```
## Understanding Summary — <ISSUE-ID>
**Solid** — areas the user explained correctly
**Gaps** — misconceptions corrected, each with the relevant `path:line`
**Worth rereading** — files or functions to review
```

## Phase 5: Explain Mode (`explain` argument)

Skip the quiz. Produce a stakeholder-facing explainer in chat:

```
## Explainer — <ISSUE-ID>: <title>
**What changed** — plain-language summary of the delivered behavior
**Why** — the problem it solves, from the issue description
**Impact** — what users or dependent systems will notice
**Risks and limitations** — known edge cases and deferred work from the as-built comment
**Follow-ups** — open items, if any
```

Write for a reader who has not seen the code; name files only when they aid navigation. Then offer once to save the explainer to a file path the user names; write the file only if they provide a path.

## Safety rules

- Use only Linear MCP read operations. Never change state, description, comments, acceptance criteria, assignee, labels, or any other Linear field — this skill never writes to Linear, not even a comment.
- Stay read-only in the repository: no file edits, commits, or mutating shell commands. The only permitted write is the explainer file, at an explicit user-provided path.
- Do not use `docs/tickets/` as the ticket source.
- Do not invoke `implement-ticket-linear`, `update-ticket-linear`, or commit skills; only suggest next steps.
- If the implementation cannot be located, ask — never quiz from guessed code.
