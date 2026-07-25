---
name: cktk-upgrade
description: "Upgrade cktk to the latest version and automatically reconcile Claude Code, Codex, Antigravity, OpenCode, and handoff helper installs. Triggers on: /cktk-upgrade, upgrade cktk, update cktk, get latest cktk"
user-invocable: true
allowed-tools: Bash(git:*), Bash(test:*), Bash(ls:*), Bash(cp:*), Bash(rm:*), Bash(mkdir:*), Bash(cat:*), Bash(rsync:*), Bash(bash:*), Read
---

# Upgrade cktk

Pull the latest cktk skills from GitHub, then automatically reconcile the local installs for Claude Code, Codex, Antigravity, OpenCode, and the handoff shell helpers.

## Step 1: Detect install type

Before changing directories, record the invocation directory and detect whether it belongs to a git repository:

```bash
pwd
git rev-parse --show-toplevel 2>/dev/null || echo "N/A"
```

Save these as **INVOCATION_DIR** and **PROJECT_ROOT**. The installer step applies `.gitignore` changes only to **PROJECT_ROOT**, never to whichever repository happens to be current later in the workflow.

Run these checks to classify the installation:

1. Check if a plugin marketplace install exists:
   ```bash
   test -d "$HOME/.claude/plugins/marketplaces/cktk/.git" && echo "yes" || echo "no"
   ```

2. If `yes`, get the plugin marketplace path and cache path:
   ```bash
   cd "$HOME/.claude/plugins/marketplaces/cktk" && pwd
   ```
   ```bash
   ls -d "$HOME/.claude/plugins/cache/cktk/cktk/"* 2>/dev/null | head -1 || echo "N/A"
   ```
   Set **INSTALL_TYPE** to `plugin-marketplace`, **CKTK_DIR** to the marketplace path, and **CACHE_PATH** to the cache path or `N/A`.

3. Else, check if the current working directory is a cktk git clone:
   ```bash
   git -C "$(git rev-parse --show-toplevel 2>/dev/null)" remote get-url origin 2>/dev/null | grep -q 'cktk' && echo "yes" || echo "no"
   ```
   If `yes`, get the repo root:
   ```bash
   git rev-parse --show-toplevel
   ```
   Set **INSTALL_TYPE** to `git-clone` and **CKTK_DIR** to the repo root.

4. If neither is found, report that no cktk git installation was found and stop. Suggest the user install via `/plugin marketplace add savourylie/cktk` then `/plugin install cktk@savourylie`, or clone from `https://github.com/savourylie/cktk`.

## Step 2: Record current state

Run `git -C <CKTK_DIR> rev-parse HEAD` and save the output as **OLD_HEAD**.

## Step 3: Pull latest

Run:

```bash
cd <CKTK_DIR> && git fetch origin && git pull origin main
```

If the pull reports "Already up to date", record that result but continue to all-agent install reconciliation.

### Sync plugin cache (plugin-marketplace only)

If new commits were pulled, **INSTALL_TYPE** is `plugin-marketplace`, and the plugin cache path detected in Step 1 is not `N/A`, sync the updated files into the cache:

```bash
rsync -a --delete --exclude '.git' <CKTK_DIR>/ <CACHE_PATH>/
```

## Step 4: Reconcile all local agent installs

After every successful version check, including "Already up to date", run the all-agent installer from the active cktk checkout:

```bash
PROJECT_ROOT="<PROJECT_ROOT>" bash <CKTK_DIR>/scripts/install-all-agent-skills.sh
```

If **PROJECT_ROOT** is `N/A`, omit the `PROJECT_ROOT=...` environment assignment.

This script automatically:

- installs or updates handoff shell helpers under `~/.local/bin`;
- installs or updates Codex global skill links under `${CODEX_HOME:-$HOME/.codex}/skills`;
- installs or updates Antigravity global skill links under `${AGENT_HOME:-$HOME/.agent}/skills`;
- installs or updates OpenCode global skill links under `${OPENCODE_HOME:-$HOME/.config/opencode}/skills`;
- adds `.ai/handoffs/` and `.ai/interactions/` to the invoking project's `.gitignore` when **PROJECT_ROOT** is a git repository and each path is not already ignored.

If the script reports that `~/.local/bin` is not in `PATH`, include that guidance in the final response.

## Step 5: Report

Run `git -C <CKTK_DIR> rev-parse --short HEAD` to get the new short hash and `git -C <CKTK_DIR> log --oneline <OLD_HEAD>..HEAD` to list changes.

Report to the user:
- Previous version: `<OLD_HEAD short>`
- Updated to: `<NEW_HEAD short>`
- Changes pulled (the log output)
- If **INSTALL_TYPE** is `plugin-marketplace`: note that a Claude Code restart may be needed for the updated skills to take effect.
- The all-agent installer actions for shell helpers, Codex skills, Antigravity skills, OpenCode skills, and project `.gitignore`.

If there were no new commits, report that cktk is already on the latest version instead of listing changes.

## Safety

- Run `scripts/install-all-agent-skills.sh` automatically after a successful version check; do not ask a second confirmation question.
- Only edit the invoking project's `.gitignore`; do not infer another project from the later working directory.
- The installer may replace existing cktk-owned skill folders or symlinks, but must not overwrite unrelated files or unrelated skill directories.
- Do not discard local cktk changes, force-push, or reset.
