---
name: "cktk-upgrade"
description: "Use when the user explicitly asks to upgrade cktk to the latest version from GitHub. Prefer explicit invocation with $cktk-upgrade."
---

# Upgrade cktk

Pull the latest cktk skills from GitHub and update the local installation. Treat this as an explicit workflow skill. Do not trigger it just because a user mentioned upgrading in passing.

## Workflow

1. Record the invocation directory and its git root, if one exists. Preserve this as `PROJECT_ROOT`; later optional `.gitignore` setup applies only to this project.

2. Detect the cktk install type by checking these locations in order:
   - `$HOME/.claude/plugins/marketplaces/cktk/.git` — if this directory exists, the install type is **plugin-marketplace** and the cktk root is `$HOME/.claude/plugins/marketplaces/cktk`.
   - The current git repo root (via `git rev-parse --show-toplevel`) with a remote URL containing `cktk` — if this matches, the install type is **git-clone** and the cktk root is the repo root.
   - If neither is found, report that no cktk git installation was found. Suggest installing via the Claude Code plugin marketplace or cloning from `https://github.com/savourylie/cktk`.

3. Record the current commit hash before upgrading:
   ```
   git -C <CKTK_DIR> rev-parse HEAD
   ```

4. Pull the latest version:
   ```
   cd <CKTK_DIR> && git fetch origin && git pull origin main
   ```
   If the pull reports "Already up to date", record that result but continue to optional setup.

5. If new commits were pulled, for **plugin-marketplace** installs only, sync the updated files to the plugin cache directory at `$HOME/.claude/plugins/cache/cktk/cktk/<version>/` (excluding `.git`).

6. Show the user what changed:
   - Previous commit vs new commit (short hashes)
   - `git log --oneline <OLD_HEAD>..HEAD`
   - For plugin-marketplace installs: note that a Claude Code restart may be needed.
   If no commits changed, state that cktk is already current.

7. After every successful version check, ask for explicit consent:

   ```text
   Recommended setup:
   1. Add `.ai/handoffs/` to this repo's `.gitignore`.
   2. Install global helper scripts into `~/.local/bin`:
      - codex-handoff
      - cktk-takeover

   Apply recommended setup? [Y/n]
   ```

8. If approved:
   - If `PROJECT_ROOT` exists, use `git -C <PROJECT_ROOT> check-ignore -q .ai/handoffs/`. Add exactly `.ai/handoffs/` to `<PROJECT_ROOT>/.gitignore` only when it is not already ignored; create the file if needed.
   - If the invocation was outside a git repository, explain that no `.gitignore` was changed.
   - Run `bash <CKTK_DIR>/scripts/install-global-handoff-tools.sh` and relay its PATH guidance.

## Safety Rules

- Do not change `.gitignore` or `~/.local/bin` without explicit setup consent.
- Only edit the invoking project's `.gitignore`; do not infer a different project after changing directories.
- Do not force-push or reset. Use `git pull` only.
- If the pull fails due to local changes, report the error and stop instead of discarding changes.
