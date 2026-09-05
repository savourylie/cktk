---
name: commit-push-pr
description: "Commit pending work when needed, push the intended branch, and create or reuse a GitHub pull request. Supports ticket work, ad hoc edits, and already-committed branches. Use for /commit-push-pr or requests to push work and open a PR."
user-invocable: true
---

# Prepare Changes for a Pull Request

Finish the user's intended work through a pushed branch and a useful PR. Invoking this skill authorizes staging and committing when needed, pushing, and creating or maintaining the matching PR. Honor narrower instructions and existing authorization; a ticket and uncommitted changes are both optional.

## Establish the working context and target

Read applicable repository instructions. Resolve the checkout and scope from the current request, then the active conversation or caller's work directory, otherwise the current checkout. Retain the implementation worktree and existing feature branch by default. Select the directory explicitly for every shell call and use absolute file paths; do not rely on a previous `cd`.

Resolve the push destination and PR repository, head, and base from explicit instructions and the implementation context, then an existing PR or unambiguous repository configuration. Accept these as task context without requiring a positional argument format. Do not hard-code `origin` or `main`, or treat the head branch's own remote tracking ref as the PR base. Clarify only a target that remains ambiguous or conflicts with the request.

If work needs publishing while on the target base or repository default branch, safely create a topic branch from the intended work before committing or publishing. Follow the user's branch name or repository naming convention; preserve the original branch and unrelated work. An existing feature branch does not need to be renamed or recreated.

Inspect local changes, commits relative to the intended base, the remote branch, and existing PRs with available authenticated GitHub tooling. Verify remote access and the intended destination before publishing. Missing tools or access should produce a concrete blocker, not a request to repeat an already-authorized action.

## Commit only when needed

When intended pending changes exist, read and invoke [commit-ticket](../commit-ticket/SKILL.md) in the selected checkout with the exact scope and any supplied message. It stages intended changes, preserves excluded content and partial selections, and applies the full Conventional Commits message standard. Reuse applicable verification from the preceding work.

When the intended content is already committed, skip that step and continue. Preserve existing commits; do not manufacture a change or empty commit to satisfy this workflow. Unrelated dirty files alone do not block publishing an isolated, committed scope.

## Describe and publish the complete change

Review the complete proposed PR diff and its commits against the intended base. Limiting the files in a new commit does not exclude earlier commits from the PR. If the branch includes unapproved unrelated work, resolve that scope before pushing. Safe isolation on a separate topic branch from the intended base is allowed when consistent with the requested head/checkout; preserve the original branch and worktree, and verify the isolated change. If the work cannot be safely separated within those constraints, clarify the conflict before publishing. Do not silently include unrelated commits or rewrite existing history.

Write the PR for someone who has not read the conversation. Explain the problem or business purpose, resulting behavior, consequential decisions, and verification evidence or remaining acceptance work. Cover the whole PR, including earlier commits. Follow the repository template, explicit title/body, language, and draft preference; scale detail to the change without imposing fixed headings or length. Use verified ticket references when relevant and closing keywords only for intended, authorized completion.

Locate an open PR by its head repository/branch and base. Reuse a matching PR, retaining useful human edits and its draft/ready state unless the user requests a change; update the title or body only when needed for the requested work. A PR for a different target is not a match to silently retarget. If there is no publishable diff and no matching PR needing work, report a no-op.

Push only the intended head branch to the verified destination, skipping a push when it is already at the intended commit. Create a PR only when no matching open PR exists. With `gh`, pass the repository, head, and base explicitly to `gh pr create`; use a file tool to write a multi-paragraph body outside the staging scope and pass `--body-file`. With other GitHub tools, use their equivalent structured fields. Preserve actual newlines and literal shell characters.

## Confirm the result and resume safely

After a failed or uncertain operation, inspect the relevant local HEAD, remote branch, and PR state before retrying only the unfinished action. A nonzero result does not prove that nothing was written. Stop when a permission failure, conflicting scope, or unresolved target prevents safe progress; preserve the work and distinguish completed actions from blockers.

Read back the remote head and PR repository, head/base, title/body, and state. Report the branch, new commit hash or existing HEAD, and PR URL, plus intentionally remaining changes or incomplete checks when relevant. Do not infer authorization for force-pushing, rewriting history, merging, deleting branches/worktrees, or tracker updates from a commit/push/PR request.
