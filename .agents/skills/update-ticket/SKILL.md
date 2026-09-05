---
name: "update-ticket"
description: "Update a local ticket from verified evidence, reconcile dependencies and INDEX.md, and commit only the intended documentation changes in its checkout. Prefer explicit invocation with $update-ticket."
---

# Reconcile a Local Ticket's Status

Use `$update-ticket` to update the selected local ticket and its tracker, including a scoped documentation commit. **If completion is established and there is no material doubt, mark Done automatically; do not ask for another confirmation.**

## Identify the work and assess the outcome

Accept `TICKET-002`, `002`, `#002`, or `2` and an optional `done`, `in-progress`, `pending`, `blocked`, or `deferred`. Without a status, evaluate Done and otherwise retain the current status. Resolve an omitted ticket from clear conversation or caller context, then the branch/registered worktrees. Ask only when identity or intent cannot be resolved.

Read [assessment](references/assessment.md) for the ticket's business context, exact identity, working directory, and completion evidence. Preserve an explicit caller `WORK_DIR` and branch. On every shell call, select `workdir` explicitly or use `git -C "$WORK_DIR"`; use absolute file paths. Existing current-checkout and linked-worktree implementations, including committed work, are valid inputs.

For `auto` or `done`, reuse applicable verification and confirmed acceptance. A clear, verified outcome can justify Done without a formal checklist; a checked box does not itself establish fresh evidence. Complete supported transitions directly. Ask a focused question only for a material contradiction, required acceptance that is still unconfirmed, or another consequential gap. Other explicit statuses do not require the full completion assessment.

## Update only the relevant tracker state

Apply [local tracker updates](references/local-tracker.md) in the selected checkout. Reconcile the target, affected dependencies, and `docs/tickets/INDEX.md` from actual requirements and statuses. Reopening work also requires checking derived dependency marks and readiness.

If the requested status already matches, skip that write and check for stale projections or unfinished changes from an earlier attempt. Preserve unrelated edits and staging. An intended empty diff is a no-op, not a reason to create a new commit.

## Commit the documents and confirm

Read [commit-ticket](../commit-ticket/SKILL.md), then invoke `$commit-ticket` with the verified `WORK_DIR`, branch, and exact document paths/hunks owned by this update. Reuse its staging, isolation, verification, and complete message rules. Existing staged code or other ticket edits must remain outside this documentation commit.

Verify the resulting ticket/index state and documentation commit, including intentionally remaining changes. Report the old/new status, evidence supporting completion, affected dependents, hash, and unresolved work concisely; a full backlog listing is optional.

A status update does not itself create/switch worktrees or merge work. When a caller has already authorized further actions, use [finishing](../implement-ticket/references/finishing.md) for only what remains, preserving the exact base and the active merge skill's `MAIN_ROOT` preconditions. Otherwise identify the useful next step without a mandatory menu.
