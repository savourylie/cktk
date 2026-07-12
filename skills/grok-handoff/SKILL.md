---
name: grok-handoff
description: "Use when any coding agent needs to hand the current repository task to Grok Build, especially before a usage or context limit interrupts ongoing work."
user-invocable: true
allowed-tools: Bash
---

# Hand Off Work to Grok Build

Export the current task state into a local handoff bundle that Grok Build can take over with `/takeover` (or `$takeover`). Works from Claude Code, Codex, Antigravity, Cursor, or any other coding agent.

If you are already running inside Grok Build, stop and tell the user to run `/takeover` instead. Do not create a handoff bundle from Grok to Grok.

## Workflow

1. Write an agent summary file (for example under `/tmp` or the system temp directory) covering:
   - Goal / original request
   - What was completed
   - What is incomplete and the next concrete steps
   - Key files touched or still needed
   - Risks, open questions, and important commands already run

2. Locate this skill's bundled `scripts/grok-handoff.sh` and run it from the current project with a real source name and the summary path. Examples:

   Claude Code plugin install:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/grok-handoff/scripts/grok-handoff.sh" \
     --source claude \
     --summary /tmp/agent-summary.md
   ```

   Other agents (pass your own source name; skip Claude sessions if desired):

   ```bash
   bash /path/to/cktk/skills/grok-handoff/scripts/grok-handoff.sh \
     --source codex \
     --summary /tmp/agent-summary.md \
     --no-session
   ```

   Useful flags:
   - `--source AGENT` — `claude`, `codex`, `antigravity`, `cursor`, etc.
   - `--summary PATH` — copies the file into the bundle as `agent-summary.md`
   - `--no-session` — do not look for Claude Code transcripts
   - `--require-session` — fail if no Claude Code session is found
   - Default session mode is auto: attach a Claude session when present

3. If the exporter fails, report its error and stop. Do not create or repair a bundle manually.

4. On success, report:
   - The absolute bundle path printed by the script
   - That the bundle is local and may contain sensitive transcripts, summaries, file paths, and diffs
   - That the user should open **Grok Build** in the same repository and run `/takeover` (or `$takeover`)

Do not upload the bundle or commit `.ai/handoffs/`.
