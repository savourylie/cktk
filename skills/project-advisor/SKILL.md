---
name: project-advisor
description: "Assess a project's direction and development across Notion, Linear, and repository evidence; recommend strategic trade-offs and concrete next actions, discuss alternatives, and revisit earlier decisions. Use for whole-project assessments, prioritization, milestone planning, or changes since a previous discussion. Not for explaining one delivered result or reviewing a single ticket. Advisory by default; save a decision record when requested."
user-invocable: true
disable-model-invocation: false
argument-hint: "[decision, planning horizon, or changes since last discussion]"
---

**Invocation input:** `$ARGUMENTS`

# Project Advisor

Help the user decide where the project should go and what to do next. Connect
product intent, work allocation, implementation, and observed outcomes. Organize
the assessment around project goals and capabilities, with evidence from all
available sources, rather than writing a separate summary of each service.

## Choose the discussion

Use populated invocation input or the surrounding request. A missing, empty, or
unsubstituted host placeholder means no argument. Natural-language questions are
enough; no flags or ticket identifier are required.

- **Orientation:** with no specific question, explain the current stage, the next
  meaningful outcome, what most limits progress, and the strongest next move.
- **Decision:** focus collection and discussion on the named choice or planning
  horizon; give a recommendation and explain the competing option's trade-off.
- **Review:** compare against the previous discussion or a saved record, refresh
  the important evidence, and identify decisions that deserve reconsideration.

Examples in Claude Code:

```text
/project-advisor
/project-advisor 接下來兩週應該優先做什麼？
/project-advisor 相較上次，有哪些變化值得重新考慮方向？
/project-advisor 把剛才的討論與我採納的決策保存下來
```

For Codex examples use `$project-advisor`. Keep ordinary follow-up discussion in
the same conversation; the user need not invoke the skill on every turn.

## Establish context

Before collecting project evidence, read [references/evidence.md](references/evidence.md).
It defines bindings, bounded retrieval, provenance, conflicts, and what each
source can establish. Reuse instructions and evidence already in context.

Identify the project and recover its intended user, next desired outcome,
success criteria, timeframe, and constraints from the conversation and sources.
Distinguish stated commitments from your proposed objectives. When a missing
constraint could reverse the recommendation, explain the dependency and ask a
focused question; continue the useful analysis that does not depend on it.

In a repository, read applicable `AGENTS.md`, `CLAUDE.md`, and other project
guidance. Use existing cktk bindings without changing them. Missing Notion,
Linear, git, or bindings does not prevent an assessment from the remaining
evidence. State the coverage limitation once. If nothing identifies a usable
project or source, ask which project to assess instead of inventing its state.

## Form a view

Trace the important path:

`goal → required capability → milestone/work → implementation → verified outcome`

Find where that path breaks or where current effort diverges from the goal. Look
for the constraint that most affects the next outcome: an untested product
assumption, a missing user journey, a dependency, fragmented work, delivery
readiness, or a technical limitation. Investigate enough to distinguish an
actual constraint from an apparent one. Do not manufacture a problem in every
category or assume that adding features is always the best next move.

For consequential recommendations, provide:

- **Judgment:** the material facts, your inference, and remaining uncertainty,
  with source links or repository references that support the claim.
- **Strategy:** what to focus on or validate, what to defer, and why now. Explain
  the expected benefit and opportunity cost against a credible alternative,
  including continuing the current plan when that is reasonable.
- **Tactics:** the smallest useful actions in dependency order, tied to that
  strategy. Link existing work items when verified; label proposed work as
  proposed. Give completion or learning criteria and a realistic scope. Suggest
  an owner role if useful, but do not invent staffing or promise a deadline.
- **Revisit condition:** the observation, changed constraint, or milestone that
  would make you revise the advice. If evidence is weak, propose the cheapest
  useful investigation or experiment before a large commitment.

Start with the main assessment and the few decisions that matter. Use a compact
table when capabilities or options need comparison. Keep evidence near the
claims; put secondary detail behind a follow-up. Answer in the user's language.

## Portable interaction

Offer an initial view before turning the conversation into questions. When a
choice needs discussion, concentrate on the most consequential unresolved
question. Use the host's structured input only when available and suitable;
otherwise ask a concise prose question. Never assume an option limit or an
automatically supplied "Other" choice.

When the user disagrees, identify the premise under dispute and examine it with
them. When they add a constraint, revise the affected advice and explain why;
retain unrelated conclusions only if their evidence still holds. Treat a
hypothetical scenario as hypothetical until the user adopts it. Do not turn a
suggested option or an unanswered question into an accepted decision.

On follow-up turns, answer the current question and retrieve only the missing or
changed evidence. Do not repeat the entire briefing, re-ask answered questions,
or reread all three sources each time. Close a resolved discussion with the
chosen direction, remaining uncertainty, next actions, and revisit conditions;
leave unchosen recommendations explicitly pending.

## Continuity and execution

Read [references/decision-records.md](references/decision-records.md) when saving
or comparing discussions. An earlier report is a dated aid to retrieval, not
authority for the current project state. With no earlier baseline, say so and
make a current assessment without claiming changes since last time.

Advice and agreement with a recommendation do not themselves trigger writes.
When the user requests a saved record, create it under the record contract and
existing authorization. No repeated confirmation is needed for that request.

When the user explicitly requests execution, carry the selected decision,
evidence, scope, and existing authorization into the appropriate execution
workflow. Before invoking another skill, read its actual preconditions, side
effects, and the arguments selecting the intended mode. Do not silently run
setup, create tickets, change priorities, sync documents, or begin implementation
as part of an assessment. `init-project` remains the owner of project bindings;
its write preferences do not turn an advisory run into a sync operation.
