# Design: Incorporating the "Finding Your Unknowns" Methodology

**Date:** 2026-07-24
**Status:** Approved
**Source:** [A Field Guide to Claude Fable: Finding Your Unknowns](https://claude.com/blog/a-field-guide-to-claude-fable-finding-your-unknowns)

## Context

The article describes an iterative agentic-coding methodology built on the four
types of unknowns:

- **Known knowns** — information explicitly stated in the prompt or ticket.
- **Known unknowns** — gaps you are aware of but have not resolved.
- **Unknown knowns** — obvious details you would not write down but would
  recognize ("of course it should match the settings page").
- **Unknown unknowns** — factors neither you nor the agent has considered.

It organizes practices into three phases: **pre-implementation** (blind spot
pass, interviews, references, implementation plans, brainstorms/prototypes),
**during implementation** (durable notes tracking deviations from the plan),
and **post-implementation** (stakeholder explainers and quizzes that verify
the *human's* understanding of agent-written changes).

cktk's ticket lifecycle already covers roughly half of this:

| Article practice | cktk today |
| --- | --- |
| Interviews | `clarify-ticket` / `clarify-ticket-linear` guided discussion |
| Implementation plans | `create-tickets` (incl. PLAN mode) |
| Brainstorms/prototypes | Host-agent territory (e.g. superpowers) — out of scope for cktk |
| Blind spot pass | Partial — clarify analyzes what the ticket says, not what it omits |
| References | Missing — no ticket section pointing at exemplar code |
| Durable implementation notes | Missing — `implement-ticket` reports deviations only in chat |
| Explainers | Partial — `commit-push-pr` PR body; wrong audience/depth |
| Quizzes | Missing |

## Decisions (from brainstorming)

1. **Hybrid approach.** Weave pre/during practices into existing skills; add
   exactly one new skill pair for the post-implementation phase.
2. **Both twins now.** The new quiz skill ships as `quiz-ticket` and
   `quiz-ticket-linear` together, preserving lifecycle twin parity.
3. **Quiz + explain mode.** One skill, two modes: interactive quiz by default;
   an `explain` argument produces a stakeholder explainer instead.
4. **Linear as-built notes via opt-in comment.** `implement-ticket-linear`
   offers (explicit Y/n, default no) to post the as-built summary as a Linear
   issue comment. Its guarantee wording becomes "never writes to Linear
   without explicit confirmation."

## Design

### 1. Four-unknowns framing — inline, not a shared file

Each skill that needs the framework (clarify twins, quiz twins) carries a
short (~8-line) inline summary of the four unknowns in its own SKILL.md.
No shared `references/` doc: the framework is tiny, and cross-skill symlinked
references are what already broke `$skill-installer` compatibility for the
handoff skills.

### 2. Clarify twins: blind spot pass

Applies to `clarify-ticket` and `clarify-ticket-linear`, in both the Claude
and Codex trees (4 documents).

- **Phase 4 (Codebase-Grounded Analysis)** gains a **Blind spots**
  subsection: after analyzing what the ticket says, deliberately hunt what it
  does *not* say — adjacent code paths that will be affected, error and edge
  paths, data migration and rollback, implicit project conventions, test
  surface. Every blind spot must be grounded in actual code (file references),
  not speculation.
- **Phase 5 briefing template** gains a matching `### Blind spots` section.
- **Phase 6 (Guided Discussion)** gains two host-neutral questions:
  - Unknown-knowns elicitation: "What's obvious to you about this ticket that
    isn't written down?"
  - Experience calibration: "How familiar are you with this area of the
    code?" — the answer adjusts how much the discussion explains.

### 3. create-tickets: References section

- `references/TEMPLATE.md` gains an optional `## References` section:
  pointers to existing code to imitate, each with a note on *what* to take
  from it (e.g. "modal behavior: `src/components/SettingsModal.tsx` —
  focus trap and escape handling").
- Phase 3 rules: populate References in FEATURES and PLAN modes (a codebase
  exists to point at) and from any provided design/UX documents; delete the
  section entirely when there is no exemplar. Follow the existing
  delete-when-empty convention used by Design/Visual Reference.
- Phase 5 self-review: verify referenced paths exist in the repo.

### 4. Implement twins: durable as-built notes

- **`implement-ticket` Phase 6** changes from "note deviations in chat" to:
  first append an `## As-Built Notes` section to the ticket file, then
  present the chat summary. Section contents: date, deviations from spec and
  why, key decisions made during implementation, follow-ups/tech debt.
  In worktree mode the append happens in the worktree's copy of
  `docs/tickets/` and merges back via `merge-worktree`.
- **`update-ticket` / `review-ticket`** already read ticket files, so they
  see As-Built Notes with no structural change. `review-ticket`'s
  ticket-alignment mode gets one added instruction: deviations documented in
  As-Built Notes count as intentional, not scope drift.
- **`implement-ticket-linear`** presents the same as-built summary in chat,
  then offers (explicit Y/n, default no) to post it as a comment on the
  Linear issue. No other Linear writes. README and skill guarantee wording
  updated accordingly.

### 5. New skill pair: quiz-ticket / quiz-ticket-linear

Read-only advisory skills, like the clarify twins: never edit tickets,
INDEX.md, git state, or Linear.

**Inputs.** A ticket number (`quiz-ticket NNN`) or Linear issue ID
(`quiz-ticket-linear ENG-42`), plus optional `explain` argument.

**Context loading.** Read the ticket (including As-Built Notes when present),
then locate the implementation: a matching `.worktrees/NNN-*` worktree, a
`ticket-NNN-*` branch, or commits referencing the ticket ID; if none is
found, ask the user where the implementation lives (or quiz against the
current state of the files the ticket names).

**Quiz mode (default).** 5–8 questions asked one at a time using the same
portable, host-neutral interaction contract as the clarify twins. Mix of:

- *Why* — design decisions and trade-offs made in the implementation.
- *Behavior* — what happens when X (edge cases, error paths).
- *Where* — which code handles Y.

Evaluate each answer, correct misconceptions with `file:line` references,
and close with an understanding summary and remaining gaps.

**Explain mode (`explain` argument).** Produce a stakeholder-facing
explainer — what changed, why, user impact, risks/limitations — in chat,
with an offer to save it to a file the user names.

**Codex policy.** Explicit-only invocation in `agents/openai.yaml`, matching
the other interactive skills.

### 6. Registration and validation

- New skill pair added to all three trees: `skills/` (canonical),
  `.agents/skills/` (rewritten Codex copies), `.agent/skills/` (symlinks).
- `catalog.json`, keyword surfaces, and README updated: skills list, Claude
  and Codex usage sections, installer path lists (counts move from
  twenty-four to twenty-six). Mirror the registration steps used for
  `clarify-ticket` (commit `a8c803e`).
- `scripts/check-codex-skills.sh` portable-contract check extended to cover
  the quiz twins.
- Acceptance gate: `./scripts/check-codex-skills.sh` passes.

## Out of scope

- A brainstorming/prototyping skill (host agents already provide this).
- Changes to `commit-ticket`, `commit-push-pr`, worktree skills, handoff
  skills, or any design/UX/image skills.
- Persisting quiz results anywhere (quiz output is conversational).
- A standalone experience-profile document; experience disclosure happens
  conversationally inside the clarify discussion.

## Acceptance criteria

1. Clarify twins surface at least one code-grounded blind-spot category per
   briefing (or explicitly state none was found) and ask the two new
   discussion questions.
2. `create-tickets` output includes a populated `## References` section
   whenever exemplar code or docs exist, and omits it otherwise.
3. After `implement-ticket` completes, the ticket file contains an
   `## As-Built Notes` section; `review-ticket` ticket mode treats its
   documented deviations as intentional.
4. `implement-ticket-linear` never writes to Linear unless the user
   explicitly confirms the as-built comment.
5. `quiz-ticket 007` runs an interactive quiz grounded in the real diff;
   `quiz-ticket 007 explain` produces a stakeholder explainer; the Linear
   twin does the same from a Linear issue.
6. `./scripts/check-codex-skills.sh` passes with all trees, catalog, and
   README updated.
