---
name: implement-ticket-linear
description: "Implement a Linear issue in its project business context, including issues in Backlog, with validation and review. Supports worktree isolation and optional delegation via codex, claude, or grok. Requires Linear MCP. Use for implement-ticket-linear or requests to implement a Linear issue."
---

# Implement a Linear Issue

Deliver the issue's business outcome using Linear as the ticket source. The default is reviewed implementation and an explicit completion verdict with business and technical meaning; commits, publishing, merging, and completion updates require authorization from the conversation.

Read [result delivery](references/delivery.md) at the start of every run. Apply it to every handoff, including unavailable Linear access, a readiness blocker, or incomplete implementation; the user should not need a separate debrief to understand the outcome.

## Inputs and access

Accept `<issue> [worktree] [base] [via <executor>]` from the invocation arguments or the user's request. Resolve an exact issue identifier such as `ENG-42` or a Linear issue URL; normalize the team key to uppercase. If omitted, use a unique issue from the conversation or current issue branch, otherwise ask. Do not select arbitrary backlog work.

Preserve `<issue>`, `<issue> <base>`, `<issue> worktree`, and `<issue> worktree <base>`. The case-insensitive `worktree` keyword requests isolation; its default base remains `main`. Current-checkout mode defaults to current HEAD. An explicit base must resolve.

A final `via <executor>` supports `codex`, `claude`, or `grok`; read [delegation](references/delegation.md) and validate it before setup. Process a bounded multi-issue set only when explicitly requested, resolving its order and prerequisite integration per issue rather than silently stacking branches.

Use available authenticated Linear MCP tools and their actual schemas. If issue reads are unavailable, report that blocker; do not invent an API-key, CLI, browser, or local-ticket fallback. This skill does not use `docs/tickets/` as its issue source.

## Understand the issue in the project

1. Fetch the exact issue, including its description, acceptance criteria, team/project, state, relations, and relevant comments. Read applicable repository instructions and relevant code.
2. Read [business context](references/business-context.md). Establish the issue's role in the whole project's business scope, its direct and indirect ticket relationships, and the requirements and decisions that govern this change. Discover relevant project documents and canonical sources rather than requiring a specific PRD filename.
3. Explain that business role, the related issue IDs and their effect, and the intended scope before implementation. Identify inferred relationships and any consequential gaps in evidence.
4. **If the issue definition contradicts this context, stop and ask the user to resolve the conflict.** Cite both sources and explain the behavioral or acceptance consequence. Do not silently prefer the issue, change the product rule, or use an as-built comment to justify the deviation. Apply this rule to conflicts discovered during implementation or review too.

## Readiness and Linear state

**Backlog is a valid starting state.** It does not require moving the issue to Todo first. Triage, an already-started state, or another non-terminal state is likewise not a refusal. Distinguish a workflow state from an actual unresolved blocker relation or missing prerequisite.

Classify states by the team's actual state types, using `list_issue_statuses` or the available equivalent. A completed or canceled issue requires an explicit reimplementation request; leave terminal status unchanged. Resolve open blockers and business contradictions before starting.

Prepare the checkout using [workspace setup](references/workspace.md), and confirm its code contains the prerequisites. Preserve `linear-<issue_id>-<slug>` and `.worktrees/<issue_id>-<slug>`; reuse existing work by issue ID even if its title changed. Recheck context when the selected checkout differs.

Only after the business check, dependencies, workspace, and selected executor are ready, perform the existing **Todo → In Progress** transition for an `unstarted` issue. Re-read the issue before writing; resolve a `started` state from its team's statuses, preferring that team's In Progress state, and update only the state field with its ID. Respect a read-only binding. If the state changed concurrently, reassess readiness and do not overwrite it.

Backlog, triage, and already-started issues are implemented with their current state preserved unless the user authorized a specific transition. If state types cannot be verified, do not guess a transition. Missing write capability or a refused start update is reported without blocking otherwise-ready implementation. If a later failure stops work after a successful transition, report the actual state; do not auto-revert a potentially concurrent change.

## Implement, verify, and review

Use an explicit working directory on every shell call and absolute paths for file tools. A `cd` from an earlier call is not a portable directory guarantee.

Implement the agreed business behavior. Select tests by the changed behavior and risk, honoring required repository and issue checks. For `via`, use the bundled `scripts/run-ticket-executor.sh` through [delegation](references/delegation.md), including the resolved business context in its task input.

Review the whole issue change against acceptance criteria, agreed business rules, and effects on related issues, using the [review rubric](../review-ticket/references/review-guidelines.md). For delegated work or an explicitly requested skill review, resolve `review-ticket` using [workspace setup](references/workspace.md#calls-across-skills), read its instructions, and invoke it with the canonical issue URL in the issue checkout: URL mode unambiguously reviews uncommitted work against Linear. For committed work on a resumed branch, use `--ticket <ID> --base <base>` as well; that mode excludes uncommitted edits.

Fix problems introduced here and rerun affected checks. Broaden verification when new changes or findings warrant it. Distinguish existing failures and unavailable checks, and keep unmet or manual acceptance visible rather than claiming completion.

## Deliver and authorized follow-up

Use [result delivery](references/delivery.md) to state whether the issue is complete, what the completed work means for the project, and which technical changes and verification support that account. When incomplete, explain the original problem, the obstacle, a concrete way forward, and whether to continue this issue, propose separate work, or pause with a condition for resuming.

Post an as-built comment only when the user has authorized that comment; summarize the concrete content before posting and reconcile an uncertain result before retrying. No mandatory comment prompt is needed. Preserve issue fields and other people's comments.

For further actions already authorized, read [finishing](references/finishing.md). Completion updates belong to `update-ticket-linear`, including its acceptance evaluation and any separately authorized Project Context / decision-log follow-up. `merge-worktree-linear` is available for later worktree landing once its preconditions hold. Base the final handoff on the actual outcome of those actions. Otherwise, explicitly say a verified complete issue is ready to prepare a PR and proceed toward merge; for incomplete work, name what remains and the useful next step.

Carry forward authorization without asking again. Ask for a missing material decision or a business contradiction, and keep required unanswered questions pending. Preserve unrelated work and diagnostics; never send Linear credentials to an executor or let it change issue state.
