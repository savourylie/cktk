---
name: "cktk-upgrade"
description: "Use when the user explicitly asks to upgrade cktk to the latest version from GitHub and automatically reconcile Claude Code, Codex, Antigravity, OpenCode, and handoff helper installs. Prefer explicit invocation with $cktk-upgrade."
---

# Upgrade cktk

Pull the latest cktk skills from GitHub, then automatically reconcile local installs for Claude Code, Codex, Antigravity, OpenCode, and handoff shell helpers. Treat this as an explicit workflow skill. Do not trigger it just because a user mentioned upgrading in passing.

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

4. Update the active checkout:
   - For **plugin-marketplace**, use Claude Code's supported update flow:
     ```
     CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1 claude plugin marketplace update cktk
     claude plugin list --json
     ```
     From the JSON list, find every installed entry whose `id` is `cktk@cktk`. For each editable `user`, `project`, or `local` scope, run:
     ```
     CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1 claude plugin update cktk@cktk --scope <SCOPE>
     ```
     If the marketplace is registered but the plugin is not installed, continue without the plugin-update command.
     If a scope-specific plugin update fails after the marketplace update succeeded, record that Claude plugin-cache failure but still run all-agent reconciliation from the cktk root. Report the failed scope in the final response.
   - For **git-clone**, run:
     ```
     cd <CKTK_DIR> && git fetch origin && git pull origin main
     ```
   If Git reports "Already up to date" or the selected path otherwise reports that it is already current, record that result but continue to all-agent install reconciliation.

   Never select a cache directory manually, copy files into `~/.claude/plugins/cache`, or use `rsync` there. Claude Code owns its cache metadata and version directories.

5. After every successful version check, including an already-current result, run the all-agent installer from the active cktk checkout:
   ```
   PROJECT_ROOT="<PROJECT_ROOT>" bash <CKTK_DIR>/scripts/install-all-agent-skills.sh
   ```
   If `PROJECT_ROOT` is unavailable, omit the `PROJECT_ROOT=...` assignment.

   This automatically:
   - installs or updates handoff shell helpers under `~/.local/bin`;
   - installs or updates Codex global skill links under `${CODEX_HOME:-$HOME/.codex}/skills`;
   - installs or updates Antigravity global skill links under `${AGENT_HOME:-$HOME/.agent}/skills`;
   - installs or updates OpenCode global skill links under `${OPENCODE_HOME:-$HOME/.config/opencode}/skills`;
   - adds `.ai/handoffs/` and `.ai/interactions/` to the invoking project's `.gitignore` when `PROJECT_ROOT` is a git repository and each path is not already ignored.

6. Show the user what changed:
   - Previous commit vs new commit (short hashes)
   - `git log --oneline <OLD_HEAD>..HEAD`
   - For plugin-marketplace installs: tell the user to run `/reload-plugins` in Claude Code, or restart it, for the updated plugin skills to take effect.
   - Note that Codex must be restarted before newly installed skill names appear in its skill registry.
   - The all-agent installer actions for shell helpers, Codex skills, Antigravity skills, OpenCode skills, and project `.gitignore`.
   If no commits changed, state that cktk is already current.

## Safety Rules

- Run `scripts/install-all-agent-skills.sh` automatically after a successful version check; do not ask a second confirmation question.
- Never write to Claude Code's plugin cache directly. Use `claude plugin marketplace update` and `claude plugin update` so Claude Code keeps its cache and installation metadata consistent.
- Only edit the invoking project's `.gitignore`; do not infer a different project after changing directories.
- The installer may replace existing cktk-owned skill folders or symlinks, but must not overwrite unrelated files or unrelated skill directories.
- Do not force-push or reset. Use `git pull` only.
- If the pull fails due to local changes, report the error and stop instead of discarding changes.
