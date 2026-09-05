# Agent Handoff

Handoff bundles let one coding agent continue work left by another without manually locating local transcript files. Supported export paths:

- **Claude Code → Codex** via `codex-handoff`
- **Any coding agent → Grok Build** via `grok-handoff` (git snapshot + agent summary; optionally attaches a Claude Code transcript when present)
- **Any coding agent → OpenCode** via `opencode-handoff` (git snapshot + agent summary; optionally attaches a Claude Code transcript when present)
- **Generic takeover** via `takeover` in the receiving agent

For the skill catalog and a quick summary, see the [README](../README.md#agent-handoff).

## Bundles and privacy

Bundles are written beneath `.ai/handoffs/` and remain entirely local. They may contain Claude Code transcripts, agent summaries, tool output, file paths, command output, and git diffs, including secrets accidentally printed during the source session. Add this directory to every participating project's `.gitignore`:

```gitignore
.ai/handoffs/
```

Do not upload or commit generated handoff bundles.

## One-time setup (shell helpers)

Install shell helpers once so you can still export when the source agent is rate-limited or unresponsive. From a full cktk checkout:

```bash
bash /absolute/path/to/cktk/scripts/install-all-agent-skills.sh
```

That adds `codex-handoff`, `grok-handoff`, `opencode-handoff`, and `cktk-takeover` under `~/.local/bin`, and reconciles agent skill links from the selected checkout. The source and linked/plugin mode are recorded for future upgrades; see [installation and migration](../README.md#install) for Claude/Grok compatibility and old-plugin handling. `$cktk-upgrade` and `/cktk-upgrade` run reconciliation automatically after a successful version check.

If `~/.local/bin` is not on your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Without installing helpers, you can still run the scripts by absolute path from a cktk checkout:

```bash
bash /absolute/path/to/cktk/skills/codex-handoff/scripts/codex-handoff.sh
bash /absolute/path/to/cktk/skills/grok-handoff/scripts/grok-handoff.sh --source claude
bash /absolute/path/to/cktk/skills/opencode-handoff/scripts/opencode-handoff.sh --source claude
```

## Claude Code → Codex

### When Claude Code is still responsive

1. In Claude Code, from the project repo:

   ```text
   /codex-handoff
   ```

2. Open Codex in the **same repository**.

3. In Codex:

   ```text
   $takeover
   ```

### When Claude Code has hit a rate / usage / context limit

You cannot run `/codex-handoff` inside Claude. Export from the terminal instead:

1. Make sure shell helpers are installed (see [One-time setup](#one-time-setup-shell-helpers)).

2. From the project repo:

   ```bash
   cd /path/to/project
   codex-handoff
   ```

   This requires a Claude Code session on disk for the repo (`~/.claude/projects/...`). It writes a bundle under `.ai/handoffs/codex/` and prints the absolute path.

3. Open Codex in the **same repository**.

4. In Codex:

   ```text
   $takeover
   ```

## Any agent → Grok Build or OpenCode

The Grok Build and OpenCode paths are identical apart from the skill name and bundle directory: `grok-handoff` writes under `.ai/handoffs/grok/`, and `opencode-handoff` writes under `.ai/handoffs/opencode/`.

### When the source agent is still responsive

1. In the source agent, invoke the skill (it should write an agent summary, then run the exporter):

   ```text
   /grok-handoff        # or: /opencode-handoff
   ```

   In Codex:

   ```text
   $grok-handoff        # or: $opencode-handoff
   ```

2. Open Grok Build (or OpenCode) in the **same repository**.

3. In the receiving agent:

   ```text
   /takeover
   ```

### When Claude Code (or another source agent) has hit a rate / usage / context limit

You cannot invoke the handoff skill inside the blocked agent. Export from the terminal instead:

1. Make sure shell helpers are installed (see [One-time setup](#one-time-setup-shell-helpers)).

2. From the project repo:

   ```bash
   cd /path/to/project
   grok-handoff --source claude       # or: opencode-handoff --source claude
   ```

   By default this:

   - Snapshots git status, diffs, log, and untracked files
   - Auto-attaches the latest Claude Code session for the repo when one exists
   - Writes a bundle under `.ai/handoffs/grok/` (or `.ai/handoffs/opencode/`) and prints the absolute path

   Useful variants (both exporters accept the same flags):

   ```bash
   # Fail if no Claude Code session is found
   grok-handoff --source claude --require-session

   # Git-only (no transcript)
   grok-handoff --source claude --no-session

   # Attach your own continuation notes (recommended if you can write them)
   grok-handoff --source claude --summary /tmp/agent-summary.md
   ```

3. Open Grok Build (or OpenCode) in the **same repository**.

4. In the receiving agent:

   ```text
   /takeover
   ```

## After takeover

In the receiving agent, `$takeover` / `/takeover`:

1. Locates the newest pending (or in-progress) handoff under `.ai/handoffs/`
2. Reads `TAKEOVER.md`, optional `agent-summary.md`, git snapshot, and optional session tail
3. Summarizes prior work and risks before editing
4. Marks the handoff in progress, continues the task, and marks it done only after the work is complete and verified
