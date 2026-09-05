# Context and acceptance for a status update

Use this for both local and Linear tickets. Resolve the working context for every update; perform the completion assessment only for auto mode or a completed target. The outcome is a defensible status decision, not a mandatory new implementation/review cycle.

## Preserve identity and the working directory

Use the current request first, then the conversation or caller's exact ticket/issue, `WORK_DIR`, branch, and known base. Otherwise inspect the current branch and registered worktrees, using exact ticket-ID boundaries. An unrelated dirty checkout, a Backlog status, or the absence of uncommitted changes is not a reason to reject the intended ticket.

For a repository, resolve the current checkout and verify `MAIN_ROOT` against `git worktree list --porcelain`; the common git directory can help locate it. Recognize `ticket-NNN-<slug>` / `.worktrees/NNN-<slug>` and `linear-<issue_id>-<slug>` / `.worktrees/<issue_id>-<slug>`. Existing registered identity wins over a slug recomputed from a renamed ticket. Verify the selected path is really that repository's checkout and matches the requested issue; a directory merely existing is insufficient. Multiple plausible matches need clarification.

Select the directory explicitly for every shell call and use absolute file paths. Read local ticket files from the selected checkout, not a mandatory main-checkout copy that may be missing or stale. Read Linear tickets from the exact issue. Do not create/switch branches or worktrees as part of status reconciliation.

For code evidence, consider relevant staged, unstaged, new-file, committed branch, and current code content. Use the integration base established during implementation or verified repository context for branch comparisons. The ticket branch's own upstream tracking ref is not that base; an empty diff against it does not prove there was no implementation. Unknown base requires clarification only when it prevents a reliable assessment; direct current-code evidence may suffice.

## Recover the governing business meaning

Reuse the agreed project role, user/business outcome, direct dependencies, and indirect constraints from implementation or review. Confirm they still apply to the actual ticket and evidence. If context is missing or changed, use focused discovery as described in [business context](../../implement-ticket/references/business-context.md); do not reread the whole backlog by default.

The question is whether the required outcome is delivered under the project's definition of completion. Read relevant issue text, specifications, decisions, comments, and code. Distinguish formal blockers from contextual relationships. A canceled prerequisite is not proof of delivery. Resolve a contradiction in scope, business rules, ownership, or acceptance before dependent status changes; a resolution already supplied by the user remains valid.

## Evaluate only what needs evidence

Map a Linear target to its real team state/category before deciding whether this assessment applies. A custom completed name has the same acceptance standard as `done`; non-completion transitions do not require a full completion review.

Evaluate the actual requirements, not just checklist syntax:

- Reuse prior tests, review, and acceptance when they apply to this content and requirement. Investigate relevant changes or uncertainty; do not rerun a suite solely because a status update was requested.
- Existing checked boxes can point to earlier evidence but are not proof by themselves. Read enough supporting context to rely on them; do not automatically invalidate a documented, still-applicable acceptance.
- Without a formal checklist, use the clearly defined outcome in the ticket and governing context. If it is concrete and verified, Done is valid without asking the user to create AC. An unclear required outcome is a real gap.
- Visual behavior can be verified with available tools. Ask for human acceptance only where the requirement actually calls for it or suitable evidence is unavailable. Already-confirmed human acceptance does not need another confirmation.
- Keep `met`, `unmet`, and `unverified` distinct. Record meaningful evidence and limitations without forcing a fixed report format. A user's explicit change to scope or acceptance can resolve a requirement; record it as that decision, not as a test that passed.

## Decide without a redundant approval round

**Auto mode and an explicit completed target both proceed directly when the required outcome is supported, necessary acceptance is confirmed, and no material contradiction or uncertainty remains. Do not ask “mark Done?” or wait for approval in that case.**

If a consequential requirement is unmet or unverified, the required manual acceptance is missing, or business definitions conflict, retain the current status and ask one focused question that identifies the gap and the decision/evidence needed. A generic `done` argument alone does not resolve a known conflict. Nonessential limitations can be reported while proceeding when they do not affect the completion standard.

An explicit non-completion status can be applied without this full assessment when identity and meaning are clear. Do not invent reasons for a block or postponement. Do not silently reopen an already-completed issue merely because a later reconciliation discovers a discrepancy; surface it and resolve the requested action.
