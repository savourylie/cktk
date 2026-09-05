# Finishing an implemented ticket

Read when the user authorizes a commit, push/PR, local merge, or tracker update. Reuse authorization from the conversation; do not force another menu or treat silence as consent. A broad implementation request alone does not select these additional actions.

Before any action, present enough of the implementation and verification result for the user to assess it. Resolve business contradictions first. Keep commit/PR readiness distinct from completion acceptance; pending manual acceptance may permit a clearly described PR without proving the ticket done.

## Scope and directory

| Action | Working context | Relevant skill |
| --- | --- | --- |
| Commit code and local as-built notes | Verified ticket `WORK_DIR` and branch | `commit-ticket` |
| Push/open a PR | Ticket `WORK_DIR`, with exact head and base | `commit-push-pr` when its commit precondition applies |
| Update local tracker | Ticket `WORK_DIR` | `update-ticket NNN <status>` |
| Update Linear | Exact issue, evidence from `WORK_DIR` | `update-ticket-linear <issue_id> [status]` |
| Merge and optionally clean up | `MAIN_ROOT`, after ticket commits | `merge-worktree` / `merge-worktree-linear` for compatible worktrees, or a local branch merge |

Read the active host's callee before invoking it. Provide the work directory, expected branch, exact identity, and requested scope explicitly. Recheck these before writes. Do not rely on a prior `cd` or on a skill inheriting its caller's working directory.

Inspect staged and unstaged changes against the recorded baseline. Only ticket-owned changes and authorized workflow preparation belong in its commits. Existing staged files and delegation diagnostics must not be swept in. A callee that cannot preserve this scope must not be invoked as though all dirty files belonged to the ticket.

## Commits and PRs

For a requested commit, invoke `commit-ticket` in the ticket checkout only when there are intended changes to commit. Supply the scope and ticket identity. Do not create empty or duplicate commits or amend history without authorization.

For a PR, verify remote access and the intended target before publishing. Use the known base explicitly; an unknown or ambiguous base needs a decision, and the ticket's own remote branch is not a base. The current `commit-push-pr` skill expects uncommitted changes and does not define a base argument, so do not blindly pass an unsupported positional base.

When that skill applies, provide the exact head/base as task context and ensure the actual PR operation uses them. If it cannot express that target, or the ticket was already committed, carry out the authorized push/PR steps directly with explicit head/base using available git/PR tools; do not manufacture a new change to satisfy a commit-only precondition. Inspect existing PRs before creating another. Respect the same scope, authentication, and history protections; report a permission failure rather than bypassing it.

## Tracker updates

Run the matching update skill only for an authorized status action, passing the exact ticket/issue and requested mode. Confirm acceptance evidence first. Do not use an explicit `done` argument to bypass unmet or unverified criteria; required manual acceptance needs the user's acceptance or an explicit project rule.

`update-ticket` edits local ticket metadata and `INDEX.md` and creates its own documentation commit. Call it before staging implementation files so that commit cannot absorb already-staged code; preserve unrelated staging. `update-ticket-linear` does not commit code. Its Project Context and Notion writes have their own authorization and binding requirements; an implementation or issue-status request does not automatically authorize them.

Keep updates on the implementation branch before any requested merge/cleanup so local evidence is still available and local tracker changes are included. If the user chose a different ordering, follow it deliberately and report any remaining work. Post an as-built comment only when separately authorized, avoiding a duplicate summary if the update workflow already supplies it.

## Local merge and cleanup

Commit the intended ticket changes in `WORK_DIR` first. Resolve the integration base; it must differ from the ticket branch. Inspect `MAIN_ROOT` before switching to it.

A main-checkout `.gitignore` addition made by worktree setup can prevent the merge helpers from running. If its only change is the recorded `.worktrees/` line, include that exact preparation in an authorized merge: switch safely to the intended base, then commit that line on the base before invoking a helper that requires a clean checkout. Do not commit it on an unrelated branch or include other main-checkout changes. If preparation overlaps user edits or switching would overwrite work, stop for that concrete conflict.

For a registered worktree, invoke the matching merge helper from `MAIN_ROOT` only after reading its preconditions. Both refuse a caller inside the target worktree and require a clean main checkout; the Codex local-ticket helper also requires a clean ticket worktree. Precommitting ticket changes avoids reliance on different auto-commit behavior across hosts. The helpers remove worktrees, and their `no-cleanup` flag preserves only the branch, not the directory. Invoke cleanup only within the user's requested scope.

For a branch-only implementation, or a request to retain the worktree, merge from the verified base checkout without invoking a helper that removes the directory. Use a normal `merge --no-ff`, preserve unrelated work, and do not reset a diverged base. If this merge conflicts, abort only the merge started by this run, report the conflicting files, and retain the implementation branch/worktree.

After a confirmed merge, remove the worktree only when authorized and when no user shell/caller depends on that directory. Run removal from `MAIN_ROOT`; never force removal of dirty work. Delete a local branch only after confirming its work reached the base and cleanup was authorized. Do not push or delete remote branches as a side effect of a local merge.

Report actual commits, PR URL, state changes, retained worktrees, and incomplete actions. A partial finish must not be described as complete.
