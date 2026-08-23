---
name: "debrief-result"
description: "Use when the user wants the project-level meaning of a result that was just delivered without being explained — typically after implement-ticket or implement-ticket-linear — or invokes $debrief-result. Do not use to re-explain a previous sentence (clarify), quiz understanding, or review code. No ticket id required: use the current conversation. Read-only: never edit files, tickets, Linear, or git. Prefer explicit invocation with $debrief-result."
---

# Debrief a Result (read-only)

The last result was stated (done, landed, AC met, files changed) without saying what it means for the project. Zoom out and explain that. Example: `$debrief-result` with no arguments.

The current conversation already has the work. Do not ask for a ticket number.

## Scope

- A **result's** project-level meaning was left unexplained → this skill.
- The user did not understand a **sentence you said** → `clarify`.
- The user wants to be quizzed on what was built → `quiz-ticket` or `quiz-ticket-linear`.
- The user wants bugs or ticket alignment → `review-ticket`.

## Do

1. Take the result from this conversation (named result, else the most recent). If none, say so and stop. Do not ask for a ticket id.
2. Read only what you still need to situate it: `docs/PRD.md` and design if present, plus remaining backlog already in context. Do not hunt for a ticket file, branch, or diff when the conversation already has the outcome.
3. Explain, in this order:

```
**Project now** — what the product can do that it could not before
**Unlocked** — what this makes possible next
**Still missing** — the next project-level gap
```

4. Keep it short. No file lists, no acceptance-criteria checkboxes, no quiz, no review.

Answer in the language the user is using.

## Safety rules

- Strictly read-only: never edit files, tickets, Linear, Notion, or git; never commit or run mutating commands.
- Do not call implementation, update, review, quiz, commit, PR, or worktree skills.
- Do not invent a ticket id or guess a result that is not in this conversation.
