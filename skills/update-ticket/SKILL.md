---
name: update-ticket
description: "Evaluate and update a local ticket status, reconcile dependencies and INDEX.md, and commit the scoped documentation changes. Supports existing branches and worktrees. Use for /update-ticket, mark ticket done, or update ticket status."
user-invocable: true
---

# Update a Local Ticket

Bring the ticket and its derived tracker state into agreement with the requested status and verified outcome. This workflow includes one scoped documentation commit. **When completion is supported and no material uncertainty remains, mark Done directly without asking for confirmation.**

## Resolve the request and evidence

Accept a ticket number such as `TICKET-002`, `002`, `#002`, or `2`, followed by an optional status: `done`, `in-progress`, `pending`, `blocked`, or `deferred`. With no status, evaluate whether Done is justified; otherwise retain the current status. With no identifier, use unambiguous conversation/caller context before branch or worktree discovery. Ask only if identity or intent remains unclear.

Read [assessment](references/assessment.md) to select the exact ticket and `WORK_DIR`, recover its business role and related constraints, and evaluate completion. It supports pending and already-committed work in current or linked checkouts. A normal status update does not create, switch, merge, or remove a worktree.

For `auto` or `done`, apply the evidence standard in that reference. Reuse valid tests and previously confirmed acceptance. Missing formal checkboxes do not prevent completion when the required outcome is clear and verified; checked boxes alone do not prove it. A substantive conflict or consequential evidence gap needs clarification, while a fully supported completion proceeds immediately. Other explicit statuses do not require a full completion review.

## Reconcile the local tracker

Follow [local tracker updates](references/local-tracker.md). Update only the selected ticket and affected dependency projections in `WORK_DIR`. Recompute dependent readiness from actual ticket requirements and statuses, including when work is reopened; do not rely on existing checkmarks as the source of truth.

An already-matching status skips the redundant status edit, not the rest of reconciliation. Repair stale index/dependency data and finish recoverable document changes from an earlier attempt. Preserve unrelated ticket edits and existing staging, and do not create an empty commit when there is no intended diff.

## Commit and report

Read and invoke [commit-ticket](../commit-ticket/SKILL.md) with the exact working directory, branch, and document paths/hunks belonging to this update. Its staging and complete message rules apply. Include only intended tracker changes, even when code or other tickets are already staged; no repository-wide or ticket-directory-wide add is needed.

Read back the changed tickets, index consistency, resulting documentation commit, and remaining git state. Report the old/new status, concise acceptance evidence, actual dependent changes, commit hash, and unresolved items. Show a full ready-work list only when useful or requested.

Keep landing separate from a status update. For an already-authorized follow-up, continue only the remaining actions using [finishing](../implement-ticket/references/finishing.md); read the active merge skill's preconditions and use the known base from `MAIN_ROOT`. Otherwise report the useful next action without a fixed menu.
