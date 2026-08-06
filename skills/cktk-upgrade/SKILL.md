---
name: cktk-upgrade
description: "Upgrade cktk to the latest version and automatically reconcile Claude Code, Codex, Antigravity, OpenCode, and handoff helper installs. Triggers on: /cktk-upgrade, upgrade cktk, update cktk, get latest cktk"
user-invocable: true
allowed-tools: Bash(claude:*), Bash(CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1 claude:*), Bash(git:*), Bash(test:*), Bash(ls:*), Bash(bash:*), Read
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

2. If `yes`, get the plugin marketplace path:
   ```bash
   cd "$HOME/.claude/plugins/marketplaces/cktk" && pwd
   ```
   Set **INSTALL_TYPE** to `plugin-marketplace` and **CKTK_DIR** to the marketplace path.

3. Else, check if the current working directory is a cktk git clone:
   ```bash
   git -C "$(git rev-parse --show-toplevel 2>/dev/null)" remote get-url origin 2>/dev/null | grep -q 'cktk' && echo "yes" || echo "no"
   ```
   If `yes`, get the repo root:
   ```bash
   git rev-parse --show-toplevel
   ```
   Set **INSTALL_TYPE** to `git-clone` and **CKTK_DIR** to the repo root.

4. If neither is found, report that no cktk git installation was found and stop. Suggest the user install via `/plugin marketplace add savourylie/cktk` then `/plugin install cktk@cktk`, or clone from `https://github.com/savourylie/cktk`.

## Step 2: Record current state

Run `git -C <CKTK_DIR> rev-parse HEAD` and save the output as **OLD_HEAD**.

## Step 3: Update the active checkout and Claude plugin

### Plugin marketplace install

If **INSTALL_TYPE** is `plugin-marketplace`, use Claude Code's supported plugin commands instead of writing into `~/.claude/plugins/cache` directly:

```bash
CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1 claude plugin marketplace update cktk
claude plugin list --json
```

From the JSON list, find every installed entry whose `id` is `cktk@cktk`. For each editable `user`, `project`, or `local` scope, run:

```bash
CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1 claude plugin update cktk@cktk --scope <SCOPE>
```

If the marketplace is registered but the plugin is not installed in any scope, continue without the plugin-update command. The marketplace checkout is still the source for all-agent reconciliation.

If a scope-specific plugin update fails after the marketplace update succeeded, record that Claude plugin-cache failure but still run all-agent reconciliation from **CKTK_DIR**. Report the failed scope in the final response.

Do not select a cache directory manually and do not use `rsync` on Claude's plugin cache. Claude Code owns its cache metadata and version directories.

### Git clone install

If **INSTALL_TYPE** is `git-clone`, run:

```bash
cd <CKTK_DIR> && git fetch origin && git pull origin main
```

If either update path reports that it is already current, record that result but continue to all-agent install reconciliation.

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
- If **INSTALL_TYPE** is `plugin-marketplace`: tell the user to run `/reload-plugins` in Claude Code, or restart it, for the updated plugin skills to take effect.
- Note that Codex must be restarted before newly installed skill names appear in its skill registry.
- The all-agent installer actions for shell helpers, Codex skills, Antigravity skills, OpenCode skills, and project `.gitignore`.

If there were no new commits, report that cktk is already on the latest version instead of listing changes.

## Safety

- Run `scripts/install-all-agent-skills.sh` automatically after a successful version check; do not ask a second confirmation question.
- Never write to Claude Code's plugin cache directly. Use `claude plugin marketplace update` and `claude plugin update` so Claude Code keeps its cache and installation metadata consistent.
- Only edit the invoking project's `.gitignore`; do not infer another project from the later working directory.
- The installer may replace existing cktk-owned skill folders or symlinks, but must not overwrite unrelated files or unrelated skill directories.
- Do not discard local cktk changes, force-push, or reset.
