---
name: debrief-result
description: "Explain the project-level meaning of a result that was stated without being explained. Use when the user invokes debrief-result, asks what a just-finished result means for the project, or wants to zoom out after implement-ticket or implement-ticket-linear. Do not use to re-explain a previous sentence (that is clarify), quiz understanding (quiz-ticket), or review code (review-ticket). No ticket id required: use the current conversation. Read-only: never edit files, tickets, Linear, or git."
user-invocable: true
disable-model-invocation: false
---

# Debrief a Result (read-only)

The last result was stated (done, landed, AC met, files changed) without saying what it means for the project. Zoom out and explain that. The current conversation already has the work; do not ask for a ticket number.

## When not to use

| Situation | Skill |
| --- | --- |
| The user did not understand a **sentence you said** | `clarify` |
| The user wants to be quizzed on what was built | `quiz-ticket` or `quiz-ticket-linear` |
| The user wants bugs or ticket alignment | `review-ticket` |

This skill explains a **result's meaning for the project**, not a sentence, not a diff, not a quiz.

## Do

1. Take the result from this conversation — the ticket or issue just implemented, the summary already given, the landing choice. If the user named a result, use that; otherwise use the most recent one. If the conversation does not contain a result, say so and stop. Do not ask for a ticket id.
2. Read only what you still need to situate it: `docs/PRD.md` and design if present, plus remaining backlog (`docs/tickets/INDEX.md` or Linear relations already in context). Do not hunt for a ticket file, branch, or diff when the conversation already has the outcome.
3. Explain, in this order:

```
**Project now** — what the product can do that it could not before
**Unlocked** — what this makes possible next
**Still missing** — the next project-level gap
```

4. Keep it short. No file lists, no acceptance-criteria checkboxes, no quiz, no review.

Answer in the language the user is using.

## Safety rules

- Read-only: never edit files, tickets, Linear, Notion, or git; never commit or run mutating commands.
- Do not invoke `implement-ticket`, `update-ticket`, `review-ticket`, `quiz-ticket`, or commit/merge skills.
- Do not invent a ticket id or guess a result that is not in this conversation.
