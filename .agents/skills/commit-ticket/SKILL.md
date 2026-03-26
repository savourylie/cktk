---
name: "commit-ticket"
description: "Use when the user explicitly asks to stage the intended repo changes and create a single git commit. Prefer explicit invocation with $commit-ticket."
---

# Commit Current Changes

Create one commit from the current repository changes. Treat this as an explicit workflow skill. Do not trigger it just because a user mentioned git in passing.

## Workflow

1. Inspect the current git state before staging anything:
   - `git status --short`
   - `git diff --stat`
   - `git diff --cached --stat`
   - `git branch --show-current`
   - `git log --oneline -10`
2. Determine the intended scope from the user's request and the current diff.
3. If unrelated dirty changes are present and the user did not ask to include them, stop and explain the conflict instead of guessing.
4. Stage only the files that belong in the commit.
5. Create a single commit. If the user supplied a message, use it. Otherwise derive a concise conventional commit message from the actual changes.
6. Report the final commit hash and subject line.

## Commit Message Rules

- Prefer conventional commit prefixes such as `feat`, `fix`, `docs`, `refactor`, `test`, or `chore`.
- Keep the subject line specific to the staged changes.
- If the diff is mixed or unclear, ask the user before committing.

## Safety Rules

- Do not amend an existing commit unless the user explicitly asked for it.
- Do not create extra commits.
- Do not stage ignored files or unrelated generated output unless they are part of the requested change.
- If there is nothing to commit, say so and stop.

