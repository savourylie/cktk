---
name: "implement-ticket-linear"
description: "Implement a Linear issue, including one in Backlog, with project business context, validation, and review. Supports worktree isolation and optional delegation via codex, claude, or grok. Requires Linear MCP. Prefer explicit invocation with $implement-ticket-linear."
---

# Implement a Linear Issue

Use Linear as the source of the requested issue and implement its business outcome in this repository. Deliver reviewed code and verification by default; perform commits, PRs, merges, and completion updates only within the user's authorization.

## Resolve the request

Use `$implement-ticket-linear <issue> [worktree] [base] [via <executor>]` or equivalent conversation instructions.

- An exact issue ID such as `ENG-42` or a Linear issue URL selects the target. Uppercase the team key. With no ID, use a unique issue already identified in the conversation or current issue branch; ask if ambiguous. Missing arguments never select an arbitrary backlog issue.
- Preserve `<issue>`, `<issue> <base>`, `<issue> worktree`, and `<issue> worktree <base>`. The case-insensitive `worktree` parameter keeps its isolated-checkout behavior and default `main` base. Current-checkout mode starts a new branch from current HEAD unless a base is supplied.
- Validate a final `via <executor>` for `codex`, `claude`, or `grok` through [delegation](references/delegation.md) before setup.
- Only an explicit bounded batch authorizes multiple issues. Establish its scope, order, and prerequisite integration, then apply this workflow per issue; do not silently stack branches.

Use the available authenticated Linear MCP tools and inspect their schemas. If the exact issue cannot be read, report the blocker instead of inventing an API-key, CLI, browser, or local-ticket replacement. Do not use `docs/tickets/` as this issue's source.

## Establish business context

Fetch the exact issue's description, acceptance criteria, state, team/project, relations, and relevant comments. Read applicable `AGENTS.md` / `CLAUDE.md` and the relevant code.

Read [business context](references/business-context.md). Establish the issue's role in the overall project business scope, the user/business flow it supports, and directly and indirectly related tickets. Follow relevant project documents, requirements, and decisions; no particular PRD or design filename is required.

Before implementation, briefly explain the business role, related issue IDs and their effects, and the intended change. Distinguish confirmed relationships from inference and identify evidence gaps that matter to the behavior.

**If the issue definition conflicts with the discovered business context, stop and ask the user to resolve it.** Cite the competing sources and explain what would differ for users, business rules, or acceptance. Do not silently choose one interpretation, expand the task, or document an unapproved deviation as an as-built decision. Check again when new evidence appears during implementation or review.

## Prepare and start

**Issues in Backlog can be implemented directly; moving them to Todo is not a prerequisite.** Triage, already-started, and other non-terminal states are also valid starting points. A backlog state is not a blocker relation.

Classify workflow state by the team's actual types through `list_issue_statuses` or the available equivalent. For completed/canceled issues, require an explicit reimplementation request and preserve the terminal status. Resolve open blockers, unmet prerequisites, and business contradictions before coding.

Read [workspace setup](references/workspace.md) before branch/worktree operations. Keep the `linear-<issue_id>-<slug>` and `.worktrees/<issue_id>-<slug>` naming contract, reuse existing work by issue ID, and verify dependencies in the chosen checkout. Revisit context if its code differs from the initial evidence.

Use `workdir: WORK_DIR` for each shell call, `git -C "$WORK_DIR"` for git, and absolute file paths. A prior `cd` does not select the directory for future tools or invoked skills.

After business context, dependencies, workspace, and executor readiness are established, an `unstarted` issue follows the existing **Todo → In Progress** transition. Re-fetch before writing, select a team-owned `started` status (prefer In Progress), and write only the state field using its actual ID. Honor read-only bindings. Reassess a concurrent state change rather than overwriting it.

For backlog, triage, or already-started issues, retain the current state unless the user authorized a specific transition. Unknown state types do not justify guessing a write. Missing write access or a failed start update is reported while otherwise-ready implementation continues. If work later stops, report any transition already made without automatically reverting it.

## Implement and verify

Implement the agreed business outcome using repository conventions. Choose tests that establish the changed behavior and address its risk, and run mandatory repository and issue checks.

For `via`, follow [delegation](references/delegation.md) with this skill's bundled `scripts/run-ticket-executor.sh`. Include the business context and relationships; Codex owns subsequent verification and authorized lifecycle actions.

Review the full issue change against acceptance criteria, agreed business rules, and impact on related issues using the [review rubric](../review-ticket/references/review-guidelines.md). For delegated work or an explicitly requested skill review, read [review-ticket](../review-ticket/SKILL.md) and invoke `$review-ticket <canonical issue URL>` in the issue checkout. URL mode selects uncommitted Linear review without a branch-name collision. For resumed committed work, also use `$review-ticket --ticket <ID> --base <base>`; that mode excludes local edits.

Fix regressions from this work and rerun affected checks. Repeat broader checks when changes or findings warrant them. Report pre-existing failures, unavailable checks, and unresolved acceptance evidence accurately. Business contradictions return to clarification.

## Deliver and continue within authorization

Report the business result, effects on related issues, key decisions, verification, remaining manual acceptance, and branch/worktree. Include manual verification steps when necessary to establish the actual behavior.

An as-built comment is posted only when authorized: show the concrete summary, preserve existing comments, and reconcile uncertain results before retrying. Do not force a separate comment-choice prompt on every run.

Read [finishing](references/finishing.md) when the user has authorized commits, PRs, merges, or status updates. `$update-ticket-linear` owns completion evaluation and any separately authorized Project Context or decision-log follow-up. `$merge-worktree-linear` can land a worktree later when its preconditions hold. Otherwise leave the result ready for review and identify the useful next step.

Reuse prior authorization. Ask only for missing material decisions, business conflicts, or additional scope; required unanswered questions stay pending. Preserve unrelated changes and delegation diagnostics, and never provide Linear credentials or status authority to an executor.
