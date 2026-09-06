# Deliver a ticket result with shared context

Use this for both implementation skills, including work stopped before coding. Summarize what is true at this handoff; a report does not replace remaining authorized work that can still be completed.

## State the verdict first

Judge completion against the agreed ticket scope, business outcome, and project definition of completion. Reuse applicable acceptance, test, and review evidence. Keep requirements that are met, unmet, and unverified distinct. Missing required manual acceptance or a consequential evidence gap prevents a completion claim; optional improvements outside the agreed scope do not.

- **Complete:** explicitly name the ticket and say it is complete and ready to prepare a PR and proceed toward merge. For example: “Ticket 007 is complete within its agreed scope; it is ready for a PR and the merge process.” Do not leave the user to infer completion from “implemented,” a passing test count, or a file list.
- **Incomplete:** explicitly say the ticket is not complete and identify the remaining outcome or acceptance gap. If code is implemented but required verification is missing, say exactly that; do not present an unverified behavior as either proven working or proven broken.

If missing access or ambiguous identity prevents assessing the ticket at all, say completion cannot be determined and explain what blocked this run. Use only known context and ask for the missing information; a refused or unstarted run is not proof that the ticket itself is unfinished.

Keep this verdict separate from lifecycle facts. Report whether code is in a local branch/worktree, committed, in a PR, merged, or deployed only to the extent established. State the actual tracker status when known and relevant; declaring completion does not itself change it. A ticket can be complete while an authorized push or tracker write fails, unless that action is itself part of the ticket's completion criteria. Explain both outcomes.

“Ready for the merge process” does not assert that remote CI, required reviews, or mergeability have been checked. Name known remaining integration gates when relevant. Only say it can merge immediately when the applicable gates are confirmed. If a PR already exists or the work is merged, report that stage and its actual next step instead of suggesting it still needs a PR. A draft PR for incomplete work is not evidence that the ticket is complete.

## Explain completed work at both levels

Every handoff, whether complete or incomplete, must connect:

- **Project/business meaning:** the original problem, whose workflow or business rule it affects, and this ticket's role in solving it. Explain what the completed portion now enables and why that matters, including relevant effects on related tickets. Keep the scope explicit: a component being implemented does not prove the whole feature is available to users.
- **Ticket/technical execution:** the concrete behavior or mechanism changed, why it produces that business result, and the verification evidence and limits. Prefer a few meaningful details over a file inventory or command log. Include useful manual acceptance steps only when still needed.

For partial work, distinguish usable behavior, groundwork for later work, and behavior still unavailable. If nothing was implemented, say so and describe only useful findings or preparation actually completed. Include the branch/worktree or PR link when it helps the user continue.

## Make an incomplete result actionable

After the verdict and completed progress, explain these points in the relevant business context:

1. **Remaining problem:** what required outcome is missing and how that limits the project's intended workflow. Name the actual actor, rule, or dependency rather than saying only “blocked.”
2. **Obstacle:** what prevents completion, the evidence for that diagnosis, and any uncertainty. Distinguish a code defect, an unavailable prerequisite or environment, missing acceptance, and a business decision; do not invent a cause for a failed check.
3. **Resolution:** recommend a concrete next action, why it addresses the obstacle, and how resolution will be verified. For a decision, explain the competing behaviors and the consequence of choosing each; do not merely ask “what next?”
4. **Disposition:** say whether to continue this ticket, use an existing dependency ticket, propose a new ticket, or pause this ticket. Routine fixes and unmet acceptance normally stay in this ticket. Separate work is appropriate for an independently scoped prerequisite or follow-up: describe its proposed outcome, acceptance, and relationship, and reuse an existing ticket when possible. A pause needs a specific reason and condition for resuming, with the responsible person or system only when known.

A recommendation to create a ticket or pause work is not an executed tracker change. Honor existing authorization for actual actions; this reporting guidance grants none. Never move required acceptance into a proposed follow-up just to declare the original ticket complete. A scope change needs the user's agreement.

## Establish common ground without adding ceremony

Reuse the business context and decisions already established. Name the relevant ticket, feature, actor, and current versus intended behavior; define project terms the user has not been given. Connect the technical cause to the business consequence instead of jumping between those levels.

Recover missing facts from available relevant sources before asking the user to repeat them. If a material ambiguity in the goal, scope, business rule, or evidence remains, state what is known and ask the focused question needed to resolve it. Keep dependent actions and conclusions pending while continuing independent authorized work. Do not guess, infer agreement from silence, or ask a generic confirmation when the meaning and authorization are already clear.

Answer in the user's language. Prefer a direct verdict followed by a few short paragraphs or bullets; these are content requirements, not mandatory headings. Keep evidence close to its claim and the final handoff self-contained.
