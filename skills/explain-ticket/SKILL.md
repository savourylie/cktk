---
name: explain-ticket
description: "Explain what a development ticket is for before implementation: the problem, affected users, intended behavior, project value, scope, and completion criteria. Use for explain-ticket or requests such as 'what is this ticket about?' or '解釋這張票在做什麼'. Accepts a local docs/tickets/ ticket or a Linear issue. Read-only; does not start implementation research, a decision interview, or coding."
---

# Explain a Ticket

Help the user understand the work before deciding how to implement it. Explain
the ticket's purpose and intended outcome in the user's language, grounded in
the ticket and the project context needed to make it meaningful.

Examples in Codex: `$explain-ticket 007`, `$explain-ticket ENG-42`, or
`$explain-ticket` for the ticket already established in the conversation. Use
the host's native skill invocation syntax when suggesting commands elsewhere.

## Resolve the ticket and source

1. Prefer the reference in the current request or invocation. Otherwise use the
   single ticket already established in the conversation, then an unambiguous
   current `ticket-NNN-*` or `linear-TEAM-NUMBER-*` branch if git is available.
   Ask for a reference when none is established; when several fit, show their
   IDs and titles and ask which one. Do not select arbitrary pending work.
2. Classify the source before fetching. A `docs/tickets/` path, `TICKET-007`,
   `007`, `#7`, or `7` denotes a local ticket; normalize numeric references to
   three digits. Other `TEAM-NUMBER` references and Linear issue URLs denote
   Linear. An explicit source or an already-confirmed Linear issue identity
   takes precedence over these shorthand rules; ask about a genuine conflict.
3. **Local:** read the explicit ticket path, or resolve exactly one
   `docs/tickets/NNN-*.md` in the identified project. In a git worktree, locate
   the main checkout as the parent of the path returned by
   `git rev-parse --path-format=absolute --git-common-dir`. Do not guess among
   duplicate files. Read the matching INDEX row
   and relevant dependency tickets when they help explain scope or sequencing;
   a missing INDEX does not prevent explaining an available ticket.
4. **Linear:** fetch the exact issue through authenticated Linear MCP read
   tools, using their actual schemas. Read its description, acceptance criteria,
   relations, and relevant comments. Disclose a changed canonical identifier.
   No git repository is required. If reads are unavailable, report the access
   limit; a user-provided issue body can support a text-only explanation, clearly
   identified as such. Never substitute a local ticket, guess live issue state,
   or use API-key, HTTP, CLI, or browser fallbacks.

Identify the selected ticket by ID/title and source so a wrong target is easy
to catch. Reuse already-read content and confirmed decisions for the same
ticket; refresh facts when changes or conflicting evidence could matter.

## Recover enough context to explain accurately

Read applicable `AGENTS.md` / `CLAUDE.md` or equivalent repository guidance
before exploring a repository. Follow relevant requirements, design references,
related tickets, and decisions only as needed to explain the ticket's role.
Use available read tools for linked sources; note consequential missing context
instead of inventing it. Do not require a particular PRD filename or project
binding.

Inspect code only when an important claim about current behavior needs checking.
Before using local code to explain a Linear issue, establish that the repository
matches the issue through known project context or repository/path references.
With an unknown or mismatched repository, continue from issue text where useful
and state that current code behavior is unverified. Ask about the repository
only if that missing context prevents an accurate explanation.

Distinguish the ticket's description of today's problem, behavior observed in
code, the intended change, and your own inferences. A planned outcome or Done
label is not proof of a released feature. If the ticket is already implemented,
explain its purpose without claiming to have verified the delivered result.

## Explain the work

Lead with a plain-language account of whose problem this ticket addresses and
what should change. Cover the following where relevant, without forcing a long
template onto a small ticket:

- **Problem and people:** who encounters the problem, under what circumstances,
  and what happens today.
- **Intended behavior:** a concrete before/after scenario using the project's
  actual terminology; label illustrative details not established by sources.
- **Project role:** why the work matters and what it enables next. For groundwork,
  explain which later capability depends on it without treating the groundwork
  as the entire feature. Do not invent urgency or business impact.
- **Scope and completion:** what this ticket includes, what is outside its scope,
  and observable acceptance conditions. Flag missing criteria rather than
  presenting your proposals as agreed requirements.
- **Dependencies and uncertainty:** material prerequisites, ambiguous business
  rules, or source conflicts that affect the explanation.

Use concise source links or file references for material claims. Explain terms
that affect understanding; avoid an inventory of files or implementation steps.
If ambiguity prevents the core explanation, ask the focused question needed to
resolve it while explaining what the evidence does support. Otherwise surface
the uncertainty without starting a decision interview.

## Finish at the explanation

Leave the ticket identity, purpose, scope, and consequential uncertainties clear
in the conversation for the next stage. When useful, suggest `clarify-ticket`
for local tickets or `clarify-ticket-linear` for Linear issues to research the
implementation and discuss choices. Do not automatically invoke them or repeat
the whole explanation when the user moves to that stage.

For an explanation of delivered work, `debrief-result` covers results and
`quiz-ticket` / `quiz-ticket-linear` with `explain` covers an implementation
diff. Re-explaining a specific statement belongs to `clarify`.

This skill is read-only: do not edit files, update ticket fields or status, post
comments, create branches/worktrees, or start implementation. It produces an
explanation in the conversation, not a saved plan or a readiness verdict.
