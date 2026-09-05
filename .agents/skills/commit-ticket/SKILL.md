---
name: "commit-ticket"
description: "Stage intended changes and create one documented git commit for ticket work or ad hoc edits, including unstaged changes and new files. Prefer explicit invocation with $commit-ticket."
---

# Commit the Intended Changes

Use `$commit-ticket` for ticket implementation or ad hoc modifications. No ticket ID or pre-staging is required. The request authorizes staging the selected work and creating one commit without an extra confirmation.

## Select the working context

Resolve the checkout and scope from the current request, then the active conversation or caller's `WORK_DIR`; otherwise use the current checkout's pending changes. Verify the repository and branch. In a worktree flow, retain the implementation checkout. Use an explicit `workdir` on every shell call, `git -C "$WORK_DIR"` for git, and absolute file paths. A commit request does not itself require creating or switching branches.

Read relevant `AGENTS.md` / `CLAUDE.md` and inspect actual staged, unstaged, and untracked content. Read existing message conventions or recent history when needed. Diff statistics alone are insufficient to decide the content or explain the change.

**By default, stage and commit all intended pending changes in that scope**: previously staged content, unstaged modifications/deletions, and relevant new files. Respect an explicit staged-only or path-limited request. For a general commit request with no narrower scope or known exclusions, use the checkout's pending changes; an ad hoc change does not need a ticket to justify inclusion.

Known unrelated work, ignored output, and local diagnostics remain outside scope unless requested. A new file is not unrelated merely because it is untracked. Proceed when the intended changes can be isolated; ask only for an ambiguous target, unclear ownership, or overlapping changes that cannot be safely separated.

## Prepare the selected content

Stage the in-scope changes yourself. Use path or hunk selection when needed; use a broad add only after confirming that everything it includes is intended.

Review the actual proposed commit diff and new-file contents, and perform an appropriate diff/format check. Preserve excluded working-tree changes and existing staging selections. Plain `git commit` includes the index, so unrelated staged changes must be isolated from the commit rather than silently included or globally unstaged.

For an explicit partial-staging request, preserve the selected hunks. Do not stage the whole file or choose a commit mode that substitutes all working-tree content for the reviewed staged content. If isolation is uncertain, ask before altering the user's selection.

Reuse valid verification from the preceding work. Satisfy repository-required checks and investigate unresolved concerns, without automatically repeating implementation or a full review.

## Message standard

Default to [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), honoring an explicit user message or repository-required format:

```text
<type>[(scope)][!]: <summary>

<body with the reason and resulting behavior>

[footers]
```

Choose `feat` for added capability, `fix` for a correction, or a suitable repository type such as `refactor`, `docs`, `test`, or `chore`. Scope optionally names the affected component. Use `!` or a `BREAKING CHANGE:` footer for incompatible behavior.

Apply this additional quality standard for completeness; the underlying specification allows an omitted body:

- **Include a body for substantive changes.** State why the change was needed and what behavior it produces. Include consequential decisions, trade-offs, compatibility effects, or migration guidance. Explain the final outcome for a future reader rather than listing files or recounting the session.
- Include meaningful verification evidence and limitations when available. Separate executed checks from pending or suggested checks; never claim a test passed without evidence. Empty headings and repeated boilerplate are unnecessary, and paragraphs or bullets are both valid.
- A tiny self-explanatory correction can have a subject alone. Scale detail to what needs explaining, with no mandatory line count. Use the user's requested language or the repository's established language.
- Add a verified `Refs:` footer only when a ticket/reference is relevant. A ticket ID is not required in the message or scope. Closing keywords require intended, authorized completion. Use attribution/sign-off trailers only when warranted, and explain breaking behavior plus the needed adaptation.

Preserve a user-supplied exact message. Improve a supplied draft only within that request, while meeting repository-enforced requirements.

## Create and confirm the commit

Create one commit from the reviewed selection. Write a multi-paragraph message using a file tool to a temporary file outside the staging scope and use `git commit -F`; preserve actual newlines and literal shell characters.

Inspect failures before retrying; if the commit result is uncertain, check HEAD and git state first. Resolve routine hook or formatting issues only within the authorized scope, then recheck the content; otherwise preserve the work and report the blocker. Do not bypass hooks, create an empty commit, amend history, or change author/signing configuration without authorization.

Read back the commit hash, full message, and actual content, and inspect the remaining git state. Report the hash and subject, plus intentionally excluded changes or incomplete checks when relevant. If the intended diff is empty, report a no-op. Pushes, PRs, and tracker changes require their own authorized follow-up.
