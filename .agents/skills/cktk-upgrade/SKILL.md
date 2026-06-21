---
name: "cktk-upgrade"
description: "Use when the user explicitly asks to upgrade cktk to the latest version from GitHub and automatically reconcile Claude Code, Codex, Antigravity, and handoff helper installs. Prefer explicit invocation with $cktk-upgrade."
---

# Upgrade cktk

Pull the latest cktk skills from GitHub, then automatically reconcile local installs for Claude Code, Codex, Antigravity, and handoff shell helpers. Treat this as an explicit workflow skill. Do not trigger it just because a user mentioned upgrading in passing.

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
   If the pull reports "Already up to date", record that result but continue to all-agent install reconciliation.

5. If new commits were pulled, for **plugin-marketplace** installs only, sync the updated files to the plugin cache directory at `$HOME/.claude/plugins/cache/cktk/cktk/<version>/` (excluding `.git`).

6. After every successful version check, including "Already up to date", run the all-agent installer from the active cktk checkout:
   ```
   PROJECT_ROOT="<PROJECT_ROOT>" bash <CKTK_DIR>/scripts/install-all-agent-skills.sh
   ```
   If `PROJECT_ROOT` is unavailable, omit the `PROJECT_ROOT=...` assignment.

   This automatically:
   - installs or updates handoff shell helpers under `~/.local/bin`;
   - installs or updates Codex global skill links under `${CODEX_HOME:-$HOME/.codex}/skills`;
   - installs or updates Antigravity global skill links under `${AGENT_HOME:-$HOME/.agent}/skills`;
   - adds `.ai/handoffs/` to the invoking project's `.gitignore` when `PROJECT_ROOT` is a git repository and the path is not already ignored.

7. Show the user what changed:
   - Previous commit vs new commit (short hashes)
   - `git log --oneline <OLD_HEAD>..HEAD`
   - For plugin-marketplace installs: note that a Claude Code restart may be needed.
   - The all-agent installer actions for shell helpers, Codex skills, Antigravity skills, and project `.gitignore`.
   If no commits changed, state that cktk is already current.

## Safety Rules

- Run `scripts/install-all-agent-skills.sh` automatically after a successful version check; do not ask a second confirmation question.
- Only edit the invoking project's `.gitignore`; do not infer a different project after changing directories.
- The installer may replace existing cktk-owned skill folders or symlinks, but must not overwrite unrelated files or unrelated skill directories.
- Do not force-push or reset. Use `git pull` only.
- If the pull fails due to local changes, report the error and stop instead of discarding changes.
