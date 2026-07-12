---
name: "grok-handoff"
description: "Use when the user explicitly asks to hand the current repository task off to Grok Build, or invokes $grok-handoff. Prefer explicit invocation with $grok-handoff."
---

# Hand Off Work to Grok Build

Export the current task state into a local handoff bundle that Grok Build can take over. Use this from Codex (or any non-Grok agent) when the user wants Grok Build to continue the work.

If you are already running inside Grok Build, stop and tell the user to run `$takeover` instead. Do not create a handoff bundle from Grok to Grok.

## Workflow

1. Write an agent summary file covering:
   - Goal / original request
   - What was completed
   - What is incomplete and the next concrete steps
   - Key files touched or still needed
   - Risks, open questions, and important commands already run

2. Locate this skill's bundled `scripts/grok-handoff.sh` and run it from the current repository with a real source name and the summary path. Example:

   ```bash
   bash "<skill-dir>/scripts/grok-handoff.sh" \
     --source codex \
     --summary /tmp/agent-summary.md \
     --no-session
   ```

   Use `--source claude` without `--no-session` when a Claude Code transcript should be attached. Default session mode is auto (attach Claude session when present).

3. If the exporter fails, report its error and stop. Do not create or repair a bundle manually.

4. On success, report:
   - The absolute bundle path printed by the script
   - That the bundle is local and may contain sensitive transcripts, summaries, file paths, and diffs
   - That the user should open **Grok Build** in the same repository and run `$takeover` or `/takeover`

Do not upload the bundle or commit `.ai/handoffs/`.
