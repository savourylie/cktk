# Upgrade the selected cktk source

An upgrade request authorizes updating and reconciling the existing installation. Preserve its chosen source and mode; do not silently switch a linked development checkout back to an older marketplace checkout.

## Select and inspect

Record the invocation directory and its git root, if any, as `PROJECT_ROOT` before changing context. Optional handoff `.gitignore` setup applies only there.

Read `~/.local/share/cktk/install.json` when present. Its `source_root` and `mode` (`linked` or `plugin`) identify the installation; an explicit user-selected source or mode takes precedence. `python3 <full-cktk-checkout>/scripts/agent-skills.py source` resolves the registered source. A missing registered checkout needs repair or an explicit replacement; do not fall back silently.

Without a receipt, resolve the loaded skill's real path. A full development checkout supplies the source for linked mode. For a Claude marketplace/plugin installation, use the registered cktk marketplace checkout and plugin mode. Verify `catalog.json`, `.claude-plugin/plugin.json`, and the installer exist; neither a remote URL substring nor an isolated copied skill establishes a full installation.

Record the source's HEAD, branch, upstream, and local changes. Keep the selected absolute directory for every call.

## Update that source

For **linked mode**, fetch its configured upstream remote and fast-forward the selected branch only when possible. Use `git merge --ff-only <verified-upstream>` after fetching. Do not pull a hard-coded branch into a different branch, discard local edits/commits, reset, or force a divergent checkout to match upstream. A checkout already ahead of upstream remains valid; report local commits accurately. If local changes overlap an update or no upstream resolves, report that concrete limitation and still reconcile links from the existing source when possible.

For **plugin mode**, use Claude's supported commands:

```sh
CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1 claude plugin marketplace update cktk
claude plugin list --json
CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1 claude plugin update cktk@cktk --scope <scope>
```

Update only installed `cktk@cktk` entries in editable user/project/local scopes, using the appropriate project directory for project/local scope. Inspect failures and preserve local marketplace edits; do not manipulate cache directories or their metadata. A scope-specific cache failure does not prevent reconciling other agents from a successfully updated source, but it remains an incomplete update.

## Reconcile and verify

After a successful version check, including **Already up to date**, automatically run from the selected full checkout:

```sh
bash <CKTK_DIR>/scripts/install-all-agent-skills.sh --source <CKTK_DIR> --mode <mode>
python3 <CKTK_DIR>/scripts/agent-skills.py doctor --runtime
```

Pass `--project-root <PROJECT_ROOT>` only for the recorded invoking git project. The installer links portable skills through `~/.agents/skills`, retains native Codex entries under `${CODEX_HOME:-$HOME/.codex}/skills`, reconciles OpenCode and Antigravity links and shell helpers, and records the source. Grok reads the shared/Claude skill locations. Linked mode also installs Claude personal skills; plugin mode leaves Claude's cache under its CLI's management.

The installer preflights ownership before changing paths. A matching name alone does not authorize overwriting a directory; resolve unknown copies or foreign links without deleting user work. Exact existing copies are backed up when replaced. Do not rerun an older installer from a different checkout after a conflict.

In linked mode, an enabled old `cktk@cktk` Claude plugin supplies a second source, including through Grok's compatibility import. Once the personal links are verified, an already-authorized migration to linked mode includes disabling only that plugin with `claude plugin disable cktk@cktk --scope <scope>` in the correct project context. Preserve other plugins and do not disable Grok compatibility globally. Plugin mode instead requires its cache payload to match the selected source. Do not treat an old inactive cache folder as an active conflict.

Inspect runtime inventories from the invoking project when available. Report absent/failed CLI inspection as unverified, separately from filesystem checks. Same-real-source aliases are harmless; another plugin with the same skill name remains a selection ambiguity and must be identified without removing that plugin.

Report the previous/current revision, local changes or commits, actions actually completed, and remaining conflicts. A linked checkout with uncommitted edits has HEAD plus a dirty working payload; do not call those edits a released version. Claude plugin changes may need `/reload-plugins`; other agents may need a new session or restart if their registry has not refreshed. Do not claim the current conversation's already-loaded instructions were replaced.
