# Discuss an Implementation Before Coding

Shared by the local and Linear clarification skills after their source and code
analysis. Keep their source-selection, readiness, and read-only rules in force.
Read this reference before presenting the briefing or asking decision questions.

## Research first, then frame the decisions

Carry forward the same ticket's explanation, user decisions, constraints, and
audience preferences from the conversation. Refresh evidence that may have
changed, especially blockers and the selected checkout. Do not repeat resolved
questions or restart an explanation unless new evidence changes it.

Use the ticket, relevant docs, and available code to resolve factual questions
before asking the user. In code mode, identify existing behavior, patterns to
reuse, affected callers, and a feasible approach tied to the acceptance criteria.
In text-only mode, distinguish a proposed approach from verified feasibility;
do not invent modules, file paths, or repository conventions.

Separate findings into decisions needing the user's judgment, facts still
missing, and routine engineering choices the agent can make. Bring forward
choices that materially change product behavior, scope, compatibility, cost,
risk, or delivery. Recommend routine details from established conventions and
explain consequential assumptions without turning each into a question.

## Present a short briefing and agenda

State the ticket, code context or text-only mode, preliminary readiness, and
proposed approach. Summarize material details to confirm, risks, blind spots,
dependencies, and open questions with the evidence gathered by the entry skill.
Keep the user-facing account focused on consequences; attach code references
where they support a decision. Identify unassessed areas rather than claiming
the research found every possible issue.

Give unresolved discussion topics stable labels such as Q1 and Q2, ordered by
dependency and impact so earlier answers can narrow later choices. Mark actual
blockers and distinguish missing facts from decisions. For a small ticket, a
short agenda is enough. If nothing needs discussion, proceed to the plan.

Do not always open with familiarity or "what hasn't been written down?"
questions. Use established context; ask a focused background question only when
its answer materially changes the explanation or approach.

## Discuss choices one at a time

For each substantive decision, explain:

- The specific question and why it matters for this ticket.
- The viable options, usually two or three, with stable labels. For each, give
  its behavioral consequence, main benefit, and meaningful cost or limitation.
  Include effort, compatibility, or maintenance implications when consequential;
  do not invent precise estimates.
- The recommended option and why it fits the evidence and known constraints.

Do not pad the menu with infeasible alternatives to reach a count. A missing
fact calls for a factual question, not fabricated choices. Leave room for a
custom answer, a combination when feasible, or deferral with its consequences.

Use the host's structured choices when suitable; otherwise use a numbered prose
question. Follow the host's actual limits without dropping viable options.
Wait for the answer before the next dependent decision. Batch only small,
independent confirmations. A recommendation, preselected option, or silence is
not a user decision; keep required unanswered questions pending and continue
only independent research.

Capture the selected behavior and rationale in the conversation. Reconcile
answers with acceptance criteria and earlier decisions. Surface material
contradictions instead of silently overriding either source. Investigate any
newly affected code and update the remaining agenda before proceeding. Do not
force a settled issue open again without new evidence.

## Leave an actionable implementation plan

Finish on screen with detail proportional to the work:

- **Readiness:** apply the entry skill's verdict to the final decisions and
  evidence, including unresolved dependencies. Text-only readiness means the
  specification is ready; code feasibility remains unassessed.
- **Decisions and scope:** what the user chose, meaningful rationale, and any
  agreed scope changes. Label agent-selected routine details separately so they
  are not mistaken for user decisions.
- **Implementation steps:** ordered changes, existing patterns to reuse, and
  affected modules when verified. Include migration, compatibility, or rollout
  steps only where needed. A text-only plan names behaviors and investigation
  steps rather than guessed repository details.
- **Verification:** how to check the acceptance criteria and consequential error
  or edge behavior, using relevant existing tests or manual checks. Describe
  proposed checks as a plan, not as checks already performed.
- **Open items and risks:** remaining questions, unverified assumptions, blockers,
  and material risks with proposed mitigations. State what evidence or decision
  would resolve open items; keep dependent steps conditional.
- **Next step:** when ready, suggest `implement-ticket NNN` for a local ticket
  or `implement-ticket-linear ISSUE-ID` for a Linear issue, using the resolved
  ID and host-native invocation syntax. Otherwise name the blocker to resolve.

Retain the plan and decisions in the conversation for follow-up. Finishing the
discussion does not authorize coding or ticket updates. Do not invoke another
skill, write a plan file, save decisions to Linear, change status, or start a
worktree as part of this read-only workflow.
