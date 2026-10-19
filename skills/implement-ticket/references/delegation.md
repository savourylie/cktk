# Optional implementation delegation

Read only for `via <executor>`. Delegation is single-ticket implementation; the invoking host owns business clarification, Linear access, verification, review, and authorized finishing.

## Validate before setup

Parse the final `via <executor>` clause before interpreting the base branch. Accept `codex`, `claude`, `grok`, or `pi` case-insensitively. Reject a duplicate `via`, a missing or unknown executor, tokens after the executor, or ambiguous multi-ticket delegation. Do not reinterpret an invalid executor as a base branch.

Determine `current_host` from the invoking runtime, not installed CLIs. Use `codex`, `claude`, `grok`, or `pi` for those hosts; another identified host may use its lowercase identifier, such as `opencode` or `antigravity`. The host is a label, not another executor choice: `via` still supports only the four validated CLIs. If executor equals current host, ask the user to omit `via` for native implementation. Do not silently choose a different executor.

Resolve `scripts/run-ticket-executor.sh` from the loaded skill's real directory, following installation symlinks, never from the target project's code. Check adapter and target CLI availability before starting workspace or Linear-state mutations. The adapter owns supported command templates and version validation; inspect it when the installed version needs checking.

### Pi has no sandbox

`via pi` runs the Pi coding agent with no sandbox and no per-action approval: its tools act with the user's full permissions. The adapter passes `--no-approve`, so the checkout's `.pi/` settings, extensions, skills, and prompts never load into the executor, and `--no-session`, so no Pi session is saved. Repository context files such as `AGENTS.md` still load, as they do for the other executors.

Strongly recommend `worktree` with `via pi`. Without it, say before launch that Pi will edit the current checkout directly, alongside any pre-existing changes, and suggest `worktree`; continue unless the user changes the request. A worktree confines the diff and protects the main checkout's uncommitted work; it is not a security boundary, because Pi can still reach any path the user can.

Pi uses its own default provider, model, and thinking level. Set `CKTK_PI_MODEL` (and optionally `CKTK_PI_PROVIDER`, which requires a model) or `CKTK_PI_THINKING` in the adapter's environment only when the user names one; otherwise leave them unset. The adapter needs `python3` to read Pi's JSON output. A Pi record adds the `provider`, `model`, `thinking_level`, and `stop_reason` of Pi's last response and a `final_message_file` holding its final text; report the model and thinking level with the outcome. A model error or truncated response is recorded as `failed` even though Pi itself exits 0.

## Package the agreed task

After business-context and workspace readiness, create a unique stem under `$WORK_DIR/.ai/cktk/delegation/`. Write `<stem>.input.md` with a file-writing tool. Include the exact ticket, full requirements and acceptance criteria, business role, direct and indirect ticket relationships with supporting evidence, agreed decisions, scope boundaries, absolute source/workspace paths, expected areas, and relevant checks.

Include the instruction to stop and report a new business contradiction rather than choosing an interpretation. The target agent **must not commit, push, merge, delete a worktree, or change ticket status**. Do not provide connector credentials, hidden reasoning, or instructions to access Linear. The host owns any Backlog → In Progress or Todo → In Progress transition at the time specified by the invoking skill.

Use `<stem>.json` as the outcome record. Preserve diagnostics on failure/timeout; exclude `.ai/cktk/delegation/` from source review and all staging.

## Run the adapter once

```sh
bash "$ADAPTER" \
  --host "$current_host" \
  --executor "$executor" \
  --work-dir "$WORK_DIR" \
  --task-file "$WORK_DIR/.ai/cktk/delegation/<stem>.input.md" \
  --record-file "$WORK_DIR/.ai/cktk/delegation/<stem>.json" \
  --timeout-seconds 1800
```

Select `WORK_DIR` explicitly for this call. The adapter validates the executor, discovers the CLI, builds its task package, bounds execution, captures output, checks git state and changes, and writes the outcome record. Do not replace it with `eval`, a free-form command template, or an automatic retry.

On non-zero exit, read the record's `status` when available and report the error, directory, and record path. Raw executor exit codes can be preserved, so do not infer the cause from the number alone. In particular, distinguish `no_changes`, `forbidden_git_state`, `git_inspection_failed`, and timeout. Preserve all work; do not commit, reset, retry, land, or remove the worktree after a failed run.

On success, read the executor's outcome and inspect the actual changes against the pre-delegation baseline. Source changes must exist outside the diagnostic directory; a pre-existing dirty file is not evidence of new work. If there is no reviewable implementation, report that and stop. A business conflict or blocked/incomplete outcome still needs host attention even when the process exited zero.

Continue to host-run validation and ticket-specific review in the main skill. The executor's final message is not verification, and it cannot resolve business contradictions on the user's behalf.
