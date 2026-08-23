---
name: "clarify"
description: "Use when the user says they do not understand something you just said, asks what you mean, asks for your previous point in plainer terms, or invokes clarify during development work. Recover the missing project context from Linear, Notion, docs/tickets/, repository docs, and the code, then explain the point again with explicit scope, resolved references, defined terminology, and the missing reasoning steps filled in. Do not use to analyze a ticket's requirements or risks before implementation — that is clarify-ticket or clarify-ticket-linear. Read-only: never edit files, tickets, Linear, Notion, or git."
---

# Clarify What You Just Said (read-only)

The user did not understand something you said. Recover the context they are missing, then explain the point again.

The problem is usually not difficult wording. The user may be missing the **context, scope, referent, terminology, or intermediate reasoning** you already had in mind and never stated. Fix that cause; do not paraphrase the same sentence.

Stay read-only: never edit repository files, tickets, Linear, Notion, or git.

Example: `$clarify` with no arguments clarifies your most recent substantive statement; `$clarify the scoring worker part` clarifies a named topic.

## Portable interaction

Resolve the clarification target from explicit skill arguments when the host provides them; otherwise use the surrounding request. Empty input means the most recent substantive statement.

When selection or confirmation is needed:

1. Show every candidate with a stable label and a distinguishing short quote.
2. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
3. Never assume an option limit or an implicit "Other" choice.
4. Ask at most one question at a time and wait for the answer.

Refer to other skills by name; use host-native invocation syntax when known.

## Scope

This skill clarifies a statement, not a work item. It produces no briefing, no readiness verdict, and no file.

- The user did not understand something **you** said → this skill.
- The **result** of just-finished work was stated without its project-level meaning → `debrief-result`.
- A **ticket's** requirements, risks, and readiness need analyzing before implementation → `clarify-ticket` (docs/tickets) or `clarify-ticket-linear` (Linear).
- The user's understanding of an **already-implemented** ticket needs checking → `quiz-ticket` or `quiz-ticket-linear`.

## Phase 1: Identify the target

Resolve the target statement, list candidates and ask when several are plausible, then restate in one line what you are about to clarify so a wrong target is caught early.

## Phase 2: Diagnose the confusion

Name the likely missing piece first: missing project context, unclear scope, unclear referent, undefined acronym, undefined project terminology, missing intermediate reasoning, switching between abstraction levels, or assuming knowledge from a ticket or document that was never stated to the user.

## Phase 3: Recover project context

Do this whenever the answer depends on project-specific facts. Do not ask the user to repeat context you can recover yourself.

Use any ticket ID, feature name, component name, project name, error message, or distinctive technical term in the unclear statement as a search anchor. Prefer sources in this order and stop as soon as the ambiguity is resolved:

1. The specific Linear issue being worked on (read-only Linear tools when available)
2. Directly linked or closely related issues
3. Notion documents explicitly linked from that issue (read-only Notion tools when available)
4. Notion documents about the same feature or component
5. Repository sources: the matching `docs/tickets/NNN-*.md` and `INDEX.md`, root and scoped `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`, `docs/PRD.md`, `docs/DESIGN.md`
6. The code at the paths the statement was about
7. Broader project documentation, only when earlier sources leave the ambiguity unresolved

Do not search an entire workspace unnecessarily.

**Degrade gracefully.** Linear and Notion tooling is optional. When either is unavailable, skip that tier silently and use the repository sources and the code. Do not stop, and do not tell the user to install anything. Name the sources you actually used only when that changes how much they should trust the answer.

**Conflicting context.** Never silently merge conflicting sources. Say the ticket and the document disagree, prefer newer and more task-specific information, and say which source you are leaning on and why.

## Phase 4: Explain

Read `references/explaining-clearly.md` before writing the explanation. It carries the full rules and worked before/after examples. In short:

1. **Scope** — say which level you mean (this function or the module, this ticket or the whole feature, current or proposed behavior). When useful, name it as `project → feature → component → operation`.
2. **References** — replace `this`, `it`, `the system`, `the pipeline`, `the handler` with the concrete thing whenever more than one target is possible.
3. **Abbreviations** — write `full term (ABBREVIATION)` on first use unless the user already used it, it was defined earlier, it is established project context needed here, or it is extremely common general vocabulary. Used only once: do not abbreviate.
4. **Project terminology** — anchor terms such as *evaluator*, *ingestion pipeline*, *scoring worker*, or *publication state* to what they actually are. Prefer the user's, the ticket's, or the documentation's wording; do not invent names.
5. **Reasoning steps** — if the chain is A → B → C → D, state B and C. Unpack *therefore*, *this means*, *as a result*, *under the hood*, *by design*, *this prevents*, *this ensures*.
6. **Concreteness** — prefer `actor → action → object → consequence` with real component, function, file, ticket, and document names.
7. **Readability** — English: one main claim per sentence, short sentences, familiar words. Chinese: 短句、主詞寫出來、少用連續的「這個／它／該」、講清楚哪一層與哪一步。Never sacrifice technical accuracy for readability.

Answer in the language the user is using. When the answer is not simple, this structure helps — but do not apply it mechanically to a short answer:

```
**What we're talking about** — the relevant ticket, feature, component, or document
**Scope** — exactly how broad the claim is
**What I meant** — the original statement in plain language
**Why** — the missing causal or reasoning steps
**Concrete example** — from the actual project implementation
```

## Phase 5: Final check, then hand back

Verify before responding: context retrieved, subject named, scope explicit, every reference resolved, no unexplained abbreviation, no assumed terminology, no skipped reasoning step, specific implementation distinguished from the general concept, and — for Chinese — subjects and relationships explicit. Revise if any answer is wrong.

Close with one question: whether that landed, or which part is still unclear. Then continue the interrupted development work.

## Safety rules

- Strictly read-only: never edit files, tickets, or git; never commit or run mutating or destructive commands.
- Use only read operations against Linear and Notion. Never create, update, comment on, or move anything in either.
- Never guess a project fact to make an explanation tidier. Say what you could not find and mark it open.
- Do not call implementation, update, commit, PR, or worktree skills; this skill only explains.
- Do not turn a clarification into a redesign. If the confusion exposes a real problem, say so in one or two sentences and let the user decide.
