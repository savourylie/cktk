---
name: update-ticket-linear
description: "Update a Linear issue from verified evidence, reconcile affected dependencies, and optionally sync bound project documents. Supports existing branches/worktrees and custom workflow states. Requires Linear MCP. Use for update-ticket-linear or update Linear status."
---

# Update a Linear Issue

Update the issue's actual workflow state and relevant completion evidence. Linear is the ticket source; this skill does not use local ticket files or create git commits. **When the completion evidence is sufficient and no material doubt remains, mark Done directly without another confirmation.**

Use available authenticated Linear MCP tools and discover their current schemas. Missing capabilities block only the operations that need them; report the concrete limitation without inventing API-key, CLI, or browser workarounds.

## Resolve identity, state, and working context

Accept `<issue> [status]`, where the issue is an exact Linear identifier or issue URL. Normalize the team key to uppercase. Preserve multiword state names such as `In Progress` when extracting the status from the request; interpret accompanying prose as task context. With no identifier, use unambiguous conversation/caller context, then branch or registered-worktree identity. Do not select a different assigned issue or start a batch implicitly.

Fetch the exact issue, its team, full description, relevant comments, and relations. List that team's workflow states **before deciding whether completion assessment is required**. Match an explicit state name first; otherwise resolve these aliases from actual team configuration:

| Alias | Meaning |
| --- | --- |
| `done` | A completed-category state, using the team's documented choice when several exist |
| `in-progress` | The team's intended started state |
| `pending` | The team's intended ready/unstarted state; do not silently equate it with Backlog |
| `blocked` | An actual blocked state if the team has one; blocker relations are a separate property |
| `deferred` | A configured postponement state; never substitute Canceled solely from this alias |

Use exact state identities and actual categories. Ask only if the requested mapping remains ambiguous; do not invent a state or change the user's meaning. An explicit Backlog state is valid. Canceled and duplicate outcomes do not prove a prerequisite was delivered.

Read [assessment](references/assessment.md) to resolve `WORK_DIR` and the business/acceptance context. Retain the caller's checkout and known base, including existing or renamed worktrees and committed branches. Repository access is needed only for evidence that depends on it; changing a non-completion state does not itself require a git checkout.

## Decide and apply the status

With no status, assess whether Done is justified; otherwise retain the current state. For every completed-category target, including custom names, apply the same completion standard. Reuse valid evidence and confirmed manual acceptance. Clear completion proceeds immediately; ask only for a material contradiction, missing required acceptance, or another consequential uncertainty.

Capture the exact affected dependent IDs before writing. Update only the intended state and supported acceptance checkboxes, preserving the rest of the issue. Check only verified criteria; never mark an unmet criterion as met merely because the status changed. Add or update an evaluation comment only when it contributes missing evidence; inspect existing comments to avoid repeating it and preserve human edits. Other fields remain outside scope unless requested.

Re-fetch relevant dependents and their remaining blockers. Move a blocked issue to the team's ready state only when all required blockers are satisfied and those dependencies were its blocking reason. On reopening, reconsider affected readiness using actual requirements; do not automatically regress started/completed work. Do not convert contextual relationships into blocker edges or delete native relations to simulate completion. Where a team has no matching state or readiness is uncertain, report the impact without inventing a transition.

An already-matching state skips only the state write. Reconcile still-requested checkboxes, evidence, dependent updates, and eligible document follow-up. After an error or uncertain response, read current state before retrying only unfinished operations. Keep affected IDs and confirmed results available for recovery; a related issue alone is not proof of a former blocker.

## Optional project documents

Use compatible project bindings from the selected repository only when they belong to this issue's actual project; the [bindings contract](../init-project/references/project-schema.md) governs each binding. Missing bindings never block the issue update and do not trigger setup questions.

These follow-ups are independent and cannot hold a supported Done transition for approval:

- [Project Context](references/project-context.md): reconcile the bound Linear Document's permitted state sections under `sync_project_context`.
- [Decision log](references/decision-log.md): record an evidenced cross-cutting decision under `write_decision_log`, even when Project Context sync is disabled. A known unfinished write can be recovered without another status transition.

Honor each preference and prior authorization separately. Prepare any concrete proposed write before asking for missing authorization; never ask to reconfirm the Done transition just because an optional document requires consent.

## Confirm and report

Read back issue state, changed content, and actual dependent outcomes. Report the transition, concise supporting evidence, work location, useful readiness changes, and completed or blocked follow-ups. Distinguish a successful status update from a failed optional sync. Summarize document changes; show a full patch or backlog only when useful or requested.

Return enough context for separately authorized landing. A matching `merge-worktree-linear` must run from `MAIN_ROOT` with the verified base and its active preconditions; being on a ticket branch alone does not select a safe merge/cleanup operation. Do not commit code or merge as a side effect of updating Linear.
