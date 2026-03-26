---
name: "commit-push-pr"
description: "Use when the user explicitly asks to commit the current changes, push the branch, and open a pull request. Prefer explicit invocation with $commit-push-pr."
---

# Commit, Push, and Open a PR

Create one commit, push the branch, and open a pull request. Treat this as an explicit workflow skill because it mutates git state and talks to external services.

## Workflow

1. Inspect the repo state first:
   - `git status --short`
   - `git diff --stat`
   - `git diff --cached --stat`
   - `git branch --show-current`
   - `git remote -v`
2. Determine whether the current branch is safe to use:
   - If already on a feature branch, keep it unless the user asked otherwise.
   - If on `main` or `master`, create a new branch using the default `codex/<topic>` convention unless the user provided a branch name.
3. Stage only the intended files.
4. Create a single commit with a clear conventional message.
5. Push the branch to `origin`.
6. Open a pull request with `gh pr create`. Reuse a user-provided title/body when available. Otherwise derive them from the commit and diff summary.
7. Report the branch name, commit hash, and PR URL.

## PR Rules

- If `gh` is missing, the repo has no `origin`, or authentication is unavailable, stop and explain the blocker.
- Prefer one focused PR over batching unrelated work.
- Do not force-push unless the user explicitly asked for it.

## Safety Rules

- Do not amend commits or rewrite history unless the user explicitly asked for it.
- If unrelated dirty changes are present, stop and ask rather than mixing scopes.
- If there is nothing to commit, do not push or open a PR.

