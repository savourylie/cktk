---
name: implement-ticket
description: "Implement a docs/tickets ticket in its project business context, with validation and review. Supports worktree isolation and optional implementation delegation via codex, claude, or grok. Use for /implement-ticket or requests to implement a local development ticket."
user-invocable: true
---

# Implement a Ticket

Implement the requested ticket as part of the project's business workflow. By default, deliver reviewed code, as-built notes, and a clear account of verification. Commit, publish, merge, and completion-status updates follow the user's authorization in this conversation.

## Inputs and scope

Accept `<ticket> [worktree] [base] [via <executor>]` from `$ARGUMENTS` or the user's request.

- Normalize `7`, `007`, `#7`, and `TICKET-007` to `007`. With no explicit ID, use an unambiguous ticket already identified in the conversation or the current ticket branch; otherwise ask. An empty invocation never starts the whole backlog.
- Preserve `<ticket>`, `<ticket> <base>`, `<ticket> worktree`, and `<ticket> worktree <base>`. The `worktree` keyword is case-insensitive and remains an explicit request for an isolated checkout.
- Without `worktree`, a new ticket branch starts at the current HEAD unless a base is supplied. With `worktree`, the default base remains `main`. An explicit base must resolve.
- The optional final `via <executor>` supports `codex`, `claude`, or `grok`. Before setup, read [delegation](references/delegation.md) to validate this mode.
- Process multiple tickets only when the user explicitly requests a bounded batch. Establish its scope, order, and dependency integration before starting; apply this workflow to each ticket. Do not silently stack branches or expand to the remaining backlog.

## Understand the business context

1. Resolve the repository and exact ticket file under `docs/tickets/`; the filename supplies its slug. Read the ticket, relevant tracker entries, applicable `AGENTS.md` / `CLAUDE.md`, and the code needed to understand the behavior. Missing or ambiguous ticket identity needs clarification.
2. Read [business context](references/business-context.md). Establish the ticket's role in the project, the business outcome it enables, its direct and indirect ticket relationships, and the boundaries of this change. Use relevant project requirements and decisions; no particular PRD or design filename is mandatory.
3. Before implementation, briefly explain that role and the related ticket IDs, distinguishing confirmed relationships from inferred ones. Verify prerequisites against the selected code, not just tracker labels.
4. **If the ticket definition contradicts the business context, stop and ask the user to resolve the conflict before implementation.** Cite the conflicting sources and their practical effect. Do not silently choose a source, expand the scope, or record an unapproved deviation as an as-built decision. Apply the same rule to contradictions discovered later.
5. An already-done ticket needs an explicit reimplementation request. An unresolved prerequisite requires resolution or an agreed scope change before proceeding.

## Prepare and implement

Read [workspace setup](references/workspace.md) before creating, switching, or reusing a branch or worktree. Preserve the `ticket-NNN-<slug>` branch and `.worktrees/NNN-<slug>` directory contracts. Record the work directory, branch, base when known, and pre-existing changes. If the selected checkout changes the relevant evidence, revisit the business-context check.

Use an explicit working directory for every shell call and absolute paths for file tools. A previous `cd` is not a portable guarantee for later calls or other skills.

Implement within the agreed business scope, following relevant repository conventions. Choose the approach and tests according to the behavior and risk; add or adjust tests where they provide useful evidence or are required by the ticket or repository.

When `via` is requested, use the bundled `scripts/run-ticket-executor.sh` through [delegation](references/delegation.md). Pass the resolved business context and relationships to the executor. This host keeps responsibility for verification, decisions, and lifecycle actions.

## Verify and review

- Run the checks required by the repository or ticket, plus those justified by the affected behavior. Distinguish failures introduced here from pre-existing failures or unavailable checks.
- Review the complete ticket change against acceptance criteria, the agreed business rules, and effects on related tickets. Use the [review rubric](../review-ticket/references/review-guidelines.md).
- For delegated implementation or an explicitly requested skill review, read and invoke [review-ticket](../review-ticket/SKILL.md) with bare `NNN`, in the ticket checkout. That mode checks uncommitted changes against the ticket. For resumed committed work, also review the relevant branch diff against a known base with the same ticket context; do not mistake an empty uncommitted diff for a full review.
- Fix issues introduced by this work and rerun the affected checks. Repeat broader checks when a change or finding warrants it. Report unresolved problems and incomplete acceptance evidence without claiming completion.

## Deliver and authorized follow-up

Append a concise dated entry under `## As-Built Notes` in the ticket for material implementation decisions, agreed deviations, and follow-ups. Preserve existing entries and omit empty boilerplate. This does not change status, acceptance checkboxes, or `INDEX.md`.

Explain the business result, important effects on related tickets, verification performed, remaining manual acceptance, and the branch/worktree location. Include useful manual steps when automated checks do not establish the user-visible result.

If the conversation already authorizes further actions, read [finishing](references/finishing.md) and continue within that scope. It covers `commit-ticket`, `commit-push-pr`, `update-ticket`, and `merge-worktree`, including their different checkout requirements. Otherwise leave the result ready for review and name the useful next step; no fixed landing menu or extra status prompt is required.

## Interaction and boundaries

Carry forward prior authorization; do not ask the same question again. Ask only for a material missing decision, conflicting requirements, or additional scope. Use the host's available interaction mechanism without assuming fixed option counts. A required unanswered question remains pending; silence is not approval.

Preserve unrelated changes, avoid force-pushing or rewriting history, and keep delegation diagnostics out of commits. Completion status must reflect verified acceptance and the user's authorized workflow.
