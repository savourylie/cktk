---
name: "debrief-result"
description: "Explain a delivered or partial result in its project business context, connect technical work to its meaning, and clarify consequential gaps or ambiguity. Use for $debrief-result or when the user asks what a result means for the project, including after implement-ticket or implement-ticket-linear. Not for re-explaining one sentence (clarify), quizzes, or code review. No ticket id required: start from the conversation. Read-only."
---

# Debrief a Result (read-only)

Explain what the work achieved, why it matters to the project, and what is still unresolved. A result may be complete, partial, blocked, or limited to findings. Example: `$debrief-result` uses the current conversation; `$debrief-result the import validation work` names a result. No ticket number is required.

## Scope

- A complete or partial **result's** meaning needs explanation → this skill.
- The user did not understand a **sentence you said** → `clarify`.
- The user wants to be quizzed on what was built → `quiz-ticket` or `quiz-ticket-linear`.
- The user wants bugs or ticket alignment → `review-ticket`.
- The user wants whole-project strategy or backlog priorities → `project-advisor`.

## Establish the result and its context

1. Use the result the user names, otherwise the most recent unambiguous result. Identify the ticket, feature, or operation in one sentence so the user can catch a wrong target. If several results fit, ask which one using their distinguishing names. If no result is available, ask the user to identify or describe the work; do not guess or simply stop. Never ask for an ID already established in the conversation.
2. Recover the original problem, whose workflow or business rule it affects, the ticket's role and agreed scope, completed work, verification, and actual delivery stage from the conversation. Reuse explicit user decisions. A previous “done” label or passing test count alone does not establish every claimed outcome.
3. Read only the evidence still needed: the relevant ticket and relations, project context, requirements and decisions, linked Linear or Notion sources through available read tools, and repository docs or code. Use known sources and focused searches; no particular PRD filename is mandatory. Inspect code or a diff only when a missing fact matters to the explanation, without starting a new review or validation run. Do not reread the entire backlog.
4. Distinguish supported facts, inferences, and unknowns. If a source is unavailable, use other relevant evidence where sufficient and name any consequential limit. If sources disagree or the intended outcome remains unclear, show the concrete ambiguity and ask the question needed to resolve it before drawing dependent conclusions. Continue explaining independently supported facts.

## Explain the meaning at the right level

Lead with the result and its supported completion state. Then connect the following in a few short paragraphs or bullets, rather than filling fixed headings:

- **Purpose and business effect:** what problem this work addresses in the project, what the completed portion changes for the affected actor or workflow, and why that matters. State a concrete before/after behavior where the evidence supports one.
- **Technical cause and evidence:** which meaningful implementation change produces that effect, why it does so, and what verification supports or limits the claim. Include enough technical detail to understand the result, without a file inventory or command log.
- **Boundaries and next step:** what this enables next and what still prevents the intended outcome, when relevant. Separate missing acceptance within this ticket from broader project work outside its scope. Do not invent a next gap just to fill a template.

Keep component, ticket, feature, and project claims distinct. Explain whether the result is groundwork, usable behavior in a branch, merged work, or a deployed capability; do not turn a local implementation into a claim that users can already use it. For partial work, say what was achieved so far and what remains unavailable. If no implementation happened, explain the value of the actual findings or preparation without inventing delivered behavior.

For a ticket whose completion is supported by existing evidence, explicitly say it is complete and ready to prepare a PR and proceed toward merge, or give the actual later stage if already in a PR or merged. This is not a fresh review or proof of unchecked merge gates. If completion cannot be established, say whether a required outcome is missing or merely unverified, and what evidence or decision is needed. Correct an earlier overstatement when the available evidence contradicts it.

For an incomplete or blocked result, connect the remaining business outcome to the obstacle, the evidence for its cause, a concrete resolution and how to verify it, and a recommended disposition. Say whether to continue the same ticket, use an existing dependency, propose a separate ticket, or pause with a specific condition for resuming. Explain the reason; outline the outcome and relationship of proposed new work without creating it. Do not move required acceptance out of scope to manufacture completion. Keep these recommendations distinct from actions actually taken.

## Build shared understanding

Use the user's language and established project terms. Name concrete actors, rules, and components; define unfamiliar terms and resolve ambiguous “this,” “it,” or “the system.” Explain the causal steps between the technical change and business effect rather than jumping between levels. Keep the final explanation self-contained, with concise source links where they substantiate a material claim.

Recover facts before asking the user to repeat them. Ask only when uncertainty about the result, goal, scope, terminology, or business rule materially changes the explanation or recommendation. State what is known, offer the plausible interpretations and their consequences when useful, and ask the focused missing question. Use the available interaction mechanism and keep dependent conclusions pending until answered. Reuse prior answers; silence does not resolve a required question. Do not demand a generic “do you understand?” confirmation when the context is clear. If the user corrects the framing, revise the explanation from that shared context.

## Safety rules

- Strictly read-only: never edit files, tickets, Linear, Notion, or git; never commit or run mutating commands.
- Do not call implementation, ticket creation/update, review, quiz, commit, PR, or worktree skills. Explain or recommend next steps only.
- Do not invent ticket IDs, project facts, acceptance evidence, or results. A debrief neither changes tracker state nor authorizes lifecycle actions.
