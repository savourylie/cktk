---
name: codex-handoff
description: "Use when Claude Code needs to hand the current repository task to Codex, especially before a usage or context limit interrupts ongoing work."
user-invocable: true
allowed-tools: Bash
---

# Hand Off Work to Codex

Export the latest Claude Code session and current git state into a local bundle that Codex can inspect without another model call.

## Workflow

1. Locate this skill's bundled `scripts/codex-handoff.sh` and run it from the current project. In a Claude Code plugin install, the command is:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/codex-handoff/scripts/codex-handoff.sh"
   ```

2. If the exporter fails, report its error and stop. Do not create or repair a bundle manually.

3. On success, report:
   - The absolute bundle path printed by the script.
   - That the bundle is local and may contain sensitive transcripts, tool output, file paths, and diffs.
   - That the user should open Codex in the same repository and run `$takeover`.

Do not upload the bundle or commit `.ai/handoffs/`.
