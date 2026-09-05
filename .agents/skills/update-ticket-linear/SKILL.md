---
name: "update-ticket-linear"
description: "Update a Linear issue from verified evidence, reconcile affected dependencies, and optionally sync bound project documents without git commits. Supports worktrees and custom states. Prefer explicit invocation with $update-ticket-linear. Requires Linear MCP."
---

# Reconcile a Linear Issue's State

Use `$update-ticket-linear` for the exact issue and intended transition. Linear owns the ticket; `docs/tickets/` and git commits are outside this skill. **When acceptance is established and no material uncertainty remains, move to Done automatically with no extra confirmation.**

Discover the actual authenticated Linear MCP tools and schemas. Report missing capabilities for the affected operation; do not invent API-key or CLI fallbacks. Optional document capabilities are not prerequisites for updating the issue.

## Identify the issue and resolve its workflow

Accept an issue identifier or URL and extract the optional status while retaining multiword names such as `In Progress`; accompanying explanatory prose supplies context. Normalize the team key. With no identifier, prefer clear conversation/caller context, then the current branch or a verified registered worktree; ask only if the target remains ambiguous. Do not fall back to a different assigned issue or an implicit batch.

Fetch the exact issue, team, description, relevant comments, and native relations. Resolve the team's workflow states **before evaluating completion**. Honor an explicit state name, otherwise map aliases using actual configuration:

| Alias | Resolve to |
| --- | --- |
| `done` | The intended completed-category state |
| `in-progress` | The team's intended started state |
| `pending` | Its ready/unstarted state; Backlog is distinct |
| `blocked` | An existing blocked state; do not confuse it with a blocker relation |
| `deferred` | A configured postponement state, never an automatic Canceled substitution |

Use verified state identities and categories, asking only for an unresolved mapping. An explicit Backlog state is supported. Completed, canceled, and duplicate outcomes are different; the latter two do not prove delivery of a dependency.

Read [assessment](references/assessment.md) for business context, acceptance, and checkout selection. Retain the exact caller `WORK_DIR`, branch, and known base. Use explicit `workdir` or `git -C "$WORK_DIR"` per shell call and absolute file paths. Current-checkout, worktree, and already-committed evidence all work; only evidence requiring repository access needs a checkout.

## Assess completion and reconcile the issue

Without a status, evaluate Done and otherwise retain the current state. Apply the same evidence standard to every completed-category target, including a custom state name. Reuse valid tests and confirmed acceptance. Proceed directly when supported; seek clarification only for a material contradiction, unconfirmed required acceptance, or consequential evidence gap. Non-completion transitions do not need a full completion review.

Record the exact affected dependent IDs before writes. Update the intended state and only the acceptance boxes supported by evidence, preserving other description content. An evaluation comment is useful when it adds missing evidence; inspect current comments first and update only known workflow-owned content or add a needed comment, preserving human edits. Do not repeat an existing summary or treat a status change as proof that an unchecked criterion passed.

Re-fetch each affected dependent's blockers and current state. Move it from blocked to the team's ready state only if all required blockers are satisfied and those dependencies explain its blocked state. When work reopens, reconcile affected readiness from requirements; do not automatically regress started/completed issues. Keep contextual relationships distinct from native blockers, and do not remove native relations to imitate completion. Report unclear readiness or an unavailable mapping without forcing a state change.

When state already matches, skip that write and finish any still-requested checkbox, evidence, dependency, or eligible document work. On failure or uncertainty, read actual state before retrying only what remains; preserve the affected IDs and confirmed results needed for recovery. Do not infer a former blocking edge merely from a related issue.

## Optional document follow-up

Read the [project bindings contract](../init-project/references/project-schema.md) when compatible repository bindings are available. Check the specific binding and its ownership against the issue's actual project; missing configuration never blocks the status update or requires a setup question.

Each follow-up is independent:

- Read [Project Context](references/project-context.md) only for an eligible sync of its bound state sections under `sync_project_context`.
- Read [Decision log](references/decision-log.md) when an evidenced cross-cutting decision or a known incomplete log operation warrants it under `write_decision_log`. Disabling context sync does not disable this path; retrying it does not require another status transition.

Honor separate preferences and existing authorization. Prepare a concrete write before requesting missing consent. A supported Done transition proceeds without waiting for optional document approval, and a document failure does not undo it.

## Verify and summarize

Read back the issue, changed content, and actual dependent transitions. Report old/new status, concise evidence, `WORK_DIR` when relevant, affected readiness, and completed or unresolved follow-ups. Report optional sync failure separately from status success. Full patches and whole-backlog listings are optional.

Return the branch/base and remaining work for any already-authorized landing. `$merge-worktree-linear` requires its active preconditions and execution from `MAIN_ROOT` with the verified base; do not infer cleanup eligibility just from a ticket branch name. This status workflow does not commit code, merge, or remove worktrees.
