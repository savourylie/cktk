---
name: "commit-push-pr"
description: "Commit pending work when needed, push the intended branch, and create or reuse a GitHub PR for ticket work or ad hoc edits, including already-committed branches. Prefer explicit invocation with $commit-push-pr."
---

# Commit as Needed, Push, and Prepare a PR

Use `$commit-push-pr` to bring the selected work to a pushed branch and a useful PR. The invocation authorizes the necessary staging/commit, push, and creation or maintenance of the matching PR without another confirmation. Follow narrower user instructions and prior authorization. A ticket ID and pending changes are optional.

## Resolve the checkout and PR target

Read applicable `AGENTS.md` / `CLAUDE.md`. Take the working directory and scope from the request, then the active conversation or caller's `WORK_DIR`, otherwise the current checkout. Keep the implementation worktree and existing feature branch by default. Use an explicit `workdir` on each shell call, `git -C "$WORK_DIR"` for git, and absolute file paths.

Determine the push destination and PR repository, head, and base from explicit instructions and implementation context, then a matching existing PR or unambiguous repository configuration. These can be passed as natural-language task context; no positional argument syntax is required. Do not assume `origin`/`main` or use the head's own upstream tracking ref as its PR base. Ask only if the target remains ambiguous or contradicts the request.

If work needs publishing while on the target base or repository default branch, create a topic branch safely from the intended work before committing or publishing. Respect the requested name or repository convention, otherwise use `codex/<topic>`. Preserve the original branch and unrelated work; retain an existing feature branch without renaming it merely to fit that default.

Inspect pending changes, commits against the intended base, remote branch state, and existing PRs using available authenticated GitHub tools. Establish remote access and the destination before publication. Report missing capabilities or authentication as concrete blockers; existing authorization does not need to be requested again.

## Reuse the commit workflow

If intended pending content exists, read [commit-ticket](../commit-ticket/SKILL.md), then invoke `$commit-ticket` with the exact `WORK_DIR`, branch, scope, and supplied message if any. It handles default staging, new files, excluded content, partial selections, and complete Conventional Commits messages. Carry forward verification that still applies.

If the work is already committed, continue to publishing without an extra commit. Keep existing history intact; no empty or duplicate commit is needed. Unrelated dirty content is not itself a blocker when the intended work can be isolated.

## Prepare the PR from the full branch change

Inspect all proposed PR commits and the actual diff against the selected base. A path-limited new commit does not limit the rest of the branch being published. Resolve unapproved unrelated commits before pushing. You may safely isolate the approved work on a separate topic branch from the selected base, preserving the original branch and worktree, when the requested head/checkout permits it. Verify the isolated change; if separation cannot satisfy those constraints, clarify the conflict before publication. Do not silently broaden the PR or rewrite existing history.

Explain the problem or business purpose and resulting behavior for a reviewer who has not seen the conversation. Include important decisions, applicable verification evidence, and remaining acceptance work. Cover earlier commits as well as a new one. Honor the repository template and the user's title/body, language, and draft preference; choose the length and structure by explanatory value. Ticket references are optional and verified; closing keywords require intended, authorized completion.

Check for an open PR with the exact head repository/branch and base. Reuse it, preserving useful human edits and its draft/ready status unless the user requests a change; edit its title or body only as needed for this work. Do not silently retarget a PR for another base. With no publishable diff and no matching PR needing work, report a no-op.

Push only the intended head to the resolved remote destination when it is not already at the intended commit. Create a PR only if a matching open PR does not exist. For `gh pr create`, specify `--repo`, `--head`, and `--base`; write a multi-paragraph body with a file tool outside the staging scope and use `--body-file`. Other GitHub tools should receive equivalent explicit, structured values. Preserve actual newlines and literal shell characters.

## Verify and recover from partial progress

When a result fails or is uncertain, read the relevant local HEAD, remote head, and matching PR before retrying only what remains unfinished. A nonzero exit does not guarantee that the operation made no changes. If permission, scope, or target conflicts cannot be resolved within the request, preserve the work and report what succeeded and what is blocked.

Read back the remote head and PR repository, head/base, title/body, and state. Report the branch, new commit hash or existing HEAD, and PR URL, plus any intentionally excluded changes or unfinished checks. This workflow does not itself authorize force-pushes, history rewrites, merges, branch/worktree deletion, or tracker updates.
