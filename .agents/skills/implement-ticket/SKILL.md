---
name: "implement-ticket"
description: "Implement a docs/tickets ticket with project business context, validation, and review. Supports worktree isolation and optional delegation via codex, claude, or grok. Prefer explicit invocation with $implement-ticket."
---

# Implement a Local Ticket

Use the requested ticket to deliver a change that fits the project's business workflow. The default outcome is reviewed implementation, as-built notes, and verification results. Continue to commits, PRs, merges, or tracker completion only within the user's authorization.

## Select the work

Use `$implement-ticket <ticket> [worktree] [base] [via <executor>]`, or equivalent instructions from the conversation.

- Accept `TICKET-007`, `007`, `#7`, and `7` as ticket `007`. If omitted, resolve a unique ticket from the conversation or current ticket branch. Ask when the target is unclear; never interpret missing arguments as permission to run the backlog.
- Keep all existing forms: `<ticket>`, `<ticket> <base>`, `<ticket> worktree`, and `<ticket> worktree <base>`. `worktree` is case-insensitive and selects an isolated checkout.
- New branches use current HEAD in the current checkout, or `main` by default in worktree mode. A supplied base overrides that default and must resolve.
- `via <executor>` is an optional final clause for `codex`, `claude`, or `grok`. Read [delegation](references/delegation.md) and validate it before creating workspace state.
- An explicit batch needs a defined ticket set, order, and plan for integrating prerequisites. Apply the workflow per ticket; do not automatically stack branches or continue through all remaining tickets.

## Establish the business meaning

Read the exact `docs/tickets/NNN-*.md` ticket and relevant `INDEX.md` entries, applicable `AGENTS.md` / `CLAUDE.md`, and relevant code. Resolve missing or ambiguous ticket identity before proceeding. The filename determines the slug.

Read [business context](references/business-context.md) before implementation. Establish which project goal and user/business flow this ticket serves, what it owns, and how directly and indirectly related tickets affect the work. Relevant requirements and decisions supply context; a missing `docs/PRD.md` or design file is not itself a blocker.

Briefly state the business role, related ticket IDs and relationships, and the intended change. Separate source-backed relationships from inference, and check that prerequisites actually exist in the selected code.

**Stop for user clarification if the ticket's definition conflicts with the discovered business context.** Explain the conflicting sources and the behavioral or acceptance consequence. Do not silently reinterpret the requirement, widen the task, or use an as-built note to legitimize the change. This check remains active during implementation and review.

An already-done ticket requires an explicit request to reimplement it. Resolve unmet prerequisites or agree a scope change before implementing work that depends on them.

## Work in the correct checkout

Read [workspace setup](references/workspace.md) before branch/worktree mutations. Keep `ticket-NNN-<slug>` and `.worktrees/NNN-<slug>` compatible with the other ticket skills. Record the selected directory, branch, base when known, and existing changes. Recheck context if choosing a different checkout changes the evidence.

Pass `workdir: WORK_DIR` on each shell call, use `git -C "$WORK_DIR"` for git, and use absolute file paths. Do not rely on a prior `cd` or assume a called skill inherits the checkout.

## Implement and check

Implement the agreed business behavior using the repository's conventions. Choose suitable tests for the changed behavior and risk, while honoring required repository and ticket checks.

For `via`, follow [delegation](references/delegation.md) using this skill's bundled `scripts/run-ticket-executor.sh`. Supply the business context and ticket relationships; Codex remains responsible for interpreting the result and carrying out authorized follow-up.

- Run relevant verification and review the full ticket change against acceptance criteria, agreed business rules, and effects on related tickets. Apply the [review rubric](../review-ticket/references/review-guidelines.md).
- Delegated work and explicitly requested skill reviews use [review-ticket](../review-ticket/SKILL.md), invoked as `$review-ticket NNN` against the ticket checkout. The bare number selects ticket-aware uncommitted review. For resumed committed work, additionally inspect the relevant branch diff against a known base with the same ticket context.
- Fix regressions introduced by the work and rerun affected checks. Broaden or repeat verification when new changes or findings justify it; report pre-existing failures and unavailable checks separately.
- An unresolved business contradiction returns to clarification. Unverified acceptance or unresolved correctness issues must remain visible in the result.

## Record and finish

Append material implementation decisions, agreed deviations, and follow-ups as a dated entry under `## As-Built Notes`. Preserve earlier entries and skip empty boilerplate. Keep this edit with the code; status, acceptance checkboxes, and `INDEX.md` belong to an authorized tracker update.

Report the business result, effects on related tickets, checks and their limits, remaining manual acceptance, and the branch/worktree. Give manual verification steps when needed to establish the behavior.

For already-authorized follow-up, read [finishing](references/finishing.md) and continue. It covers `$commit-ticket`, `$commit-push-pr`, `$update-ticket`, and `$merge-worktree`. Otherwise leave the implementation ready for review and identify the useful next action without forcing a landing menu.

## Decisions and boundaries

Reuse authorization already given in this conversation. Ask only when a material decision is missing, requirements conflict, or scope would expand. Use available interaction tools without assuming an option count; a required answer stays pending until provided.

Preserve unrelated work and delegation diagnostics, keep diagnostics out of commits, and avoid force-pushing or rewriting history. Completion status follows verified acceptance and the authorized workflow.
