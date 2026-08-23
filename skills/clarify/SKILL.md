---
name: clarify
description: "Re-explain something you just said so the user actually understands it. Use when the user says they do not understand, asks \"what do you mean?\", asks for your previous point in plainer terms, or invokes the clarify skill during development work. Recover the missing project context from Linear, Notion, docs/tickets/, repository docs, and the code, then re-explain with explicit scope, resolved references, defined terminology, and the missing reasoning steps filled in. Do not use to analyze a ticket's requirements or risks before implementation — that is clarify-ticket or clarify-ticket-linear. Read-only: never edit files, tickets, Linear, Notion, or git."
user-invocable: true
disable-model-invocation: false
argument-hint: "[what was unclear]"
---

**Invocation input:** `$ARGUMENTS`

# Clarify What You Just Said (read-only)

The user did not understand something you said. Recover the context they are missing and explain the point again.

The problem is usually not difficult wording. The user may be missing the **context, scope, referent, terminology, or intermediate reasoning** that you already had in mind and never stated. Fix that, rather than paraphrasing the same sentence.

Stay read-only: never edit repository files, tickets, Linear, Notion, or git.

## Portable interaction rules

- Resolve the clarification target from populated invocation input when available; otherwise use the surrounding user request. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- When the user must select or confirm something, show every candidate with a stable label and distinguishing detail.
- Use the host's structured choice mechanism only when it is available and can represent the candidates clearly. Otherwise ask a concise numbered prose question and accept a number or label.
- Never assume an option limit or an automatically supplied "Other" choice.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.
- Ask at most one question at a time and wait for the answer.

## Scope of this skill

| Situation | Skill |
| --- | --- |
| The user did not understand something **you** said | this skill |
| The **result** of just-finished work was stated without its project-level meaning | `debrief-result` |
| The user wants a **ticket's** requirements, risks, and readiness analyzed before implementation | `clarify-ticket` (`docs/tickets/`) or `clarify-ticket-linear` (Linear) |
| The user's understanding of an **already-implemented** ticket should be checked | `quiz-ticket` or `quiz-ticket-linear` |

This skill clarifies a statement, not a work item. It produces no briefing, no readiness verdict, and no file.

## Phase 1: Identify the target statement

1. Resolve the target:
   - Populated invocation input naming a topic, term, or quote → clarify that.
   - Empty input → the most recent substantive statement you made.
2. If several statements could plausibly be meant, list the candidates with short quotes and ask which one, using the portable interaction rules.
3. Restate in one line what you are about to clarify, so a wrong target is caught before you spend effort on it.

## Phase 2: Diagnose what was actually confusing

Name the likely missing piece before rewriting anything:

- missing project context
- unclear scope
- unclear referent
- undefined acronym
- undefined project terminology
- missing intermediate reasoning
- switching between abstraction levels
- assuming knowledge from a ticket or document that was never stated to the user

Fix the cause. Restating the same sentence in different words fixes none of these.

## Phase 3: Recover the project context

Do this before explaining, whenever the answer depends on project-specific facts. Do not ask the user to repeat context you can recover yourself.

**Anchors.** Use any ticket ID, feature name, component name, project name, error message, or distinctive technical term in the unclear statement as your search anchor.

**Retrieval priority.** Prefer context in roughly this order, and stop as soon as the ambiguity is resolved:

1. The specific Linear issue being worked on — read-only Linear MCP tools when available.
2. Directly linked or closely related Linear issues.
3. Notion documents explicitly linked from that issue — read-only Notion MCP tools when available.
4. Notion documents about the same feature or component.
5. Repository sources: the matching `docs/tickets/NNN-*.md` and `INDEX.md`, root `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` and more deeply scoped instruction files, `docs/PRD.md`, `docs/DESIGN.md`.
6. The code itself, at the paths the statement was about.
7. Broader workspace or project documentation, only when the earlier sources leave the ambiguity unresolved.

Do not search an entire workspace unnecessarily. Retrieve enough to resolve the ambiguity, then stop.

**Degrade gracefully.** Linear MCP and Notion MCP are optional. When either is unavailable, skip that tier silently and use the repository sources and the code. Do not stop, and do not tell the user to install anything. Name the sources you actually used only when that changes how much they should trust the answer — for example, when the answer rests on the code rather than on a written specification.

**Conflicting context.** Do not silently merge conflicting sources. If a ticket and a Notion document disagree, say so explicitly. Prefer newer and more task-specific information, and say which source you are leaning on and why — but identify the conflict rather than presenting one authoritative interpretation.

## Phase 4: Explain

**Read `references/explaining-clearly.md` before writing the explanation.** It carries the full rules and the worked before/after examples for each one.

The rules in short:

1. **Make scope explicit.** Say which level you mean: this function or the module, this endpoint or the service, this ticket or the whole feature, current behavior or proposed behavior. When useful, name the level as `project → feature → component → operation`.
2. **Resolve references explicitly.** Replace `this`, `it`, `they`, `the system`, `the pipeline`, `the handler` with the concrete thing whenever more than one target is possible.
3. **Do not introduce unexplained abbreviations.** Write `full term (ABBREVIATION)` on first use, unless the user already used it, it was defined earlier, it is established project context needed here, or it is extremely common general vocabulary. If it appears only once, do not abbreviate at all.
4. **Introduce project terminology before relying on it.** Anchor terms like *evaluator*, *ingestion pipeline*, *scoring worker*, *canonical record*, or *publication state* to what they actually are. Prefer terminology already used by the user, the ticket, or authoritative project documentation. Do not invent new names.
5. **Fill in missing reasoning steps.** If the chain is A → B → C → D, state B and C when they are needed to see why D follows. Unpack sentences built on *therefore*, *this means*, *as a result*, *essentially*, *under the hood*, *by design*, *this allows*, *this prevents*, *this ensures*.
6. **Prefer concrete explanations.** Use `actor → action → object → consequence` over abstract noun-heavy phrasing, with the real component, function, file, ticket, or document names.
7. **Match readability to the language.** English: one main claim per sentence, short sentences, familiar words. Chinese: 短句、主詞寫出來、少用連續的「這個／它／該」、講清楚哪一層與哪一步。Never sacrifice technical accuracy to improve readability.

Answer in the language the user is using.

When the answer is not simple, this structure helps:

```
**What we're talking about** — the relevant ticket, feature, component, or document
**Scope** — exactly how broad the claim is
**What I meant** — the original statement in plain language
**Why** — the missing causal or reasoning steps
**Concrete example** — from the actual project implementation
```

Do not apply these headings mechanically when a short direct answer would do.

## Phase 5: Final check, then hand back

Before responding, verify:

- Did I retrieve the project context this explanation depends on?
- Is it clear which ticket, feature, or component I am talking about?
- Is the scope explicit?
- Does every important reference have an obvious target?
- Did I introduce any unexplained abbreviation?
- Did I assume terminology just because it appears in a ticket or document?
- Did I skip a reasoning step because the code or documentation already made it obvious to me?
- Am I distinguishing this specific implementation from the general concept?
- For Chinese, are subjects, scope, and relationships explicit enough?

If any answer is wrong, revise before responding.

Close with one question: whether that landed, or which part is still unclear. Then continue the development work that was interrupted.

## Safety rules

- Stay read-only everywhere: no file edits, commits, mutating shell commands, or destructive commands.
- Use only read operations against Linear and Notion. Never create, update, comment on, or move anything in either.
- Never guess a project fact to make an explanation tidier. If a source does not answer it, say so and mark it as an open question.
- Do not invoke `implement-ticket`, `update-ticket`, `commit-ticket`, `commit-push-pr`, or the worktree skills; this skill only explains.
- Do not turn a clarification into a redesign. If the user's confusion exposes a real problem with the plan, say so in one or two sentences and let them decide.
