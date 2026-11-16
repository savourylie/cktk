# Optional implementation delegation

Read only for `via <executor>`. Delegation is single-ticket implementation; the invoking host owns business clarification, Linear access, verification, review, and authorized finishing.

## Validate before setup

Parse the final `via <executor>` clause before interpreting the base branch. Accept `codex`, `claude`, `grok`, `pi`, or `agy` case-insensitively. Reject a duplicate `via`, a missing or unknown executor, tokens after the executor, or ambiguous multi-ticket delegation. Do not reinterpret an invalid executor as a base branch. A model or reasoning effort the user names for `agy` or `pi` is an override (below), not part of the clause.

Determine `current_host` from the invoking runtime, not installed CLIs. Use `codex`, `claude`, `grok`, or `pi` for those hosts; another identified host may use its lowercase identifier, such as `opencode` or `antigravity`. The host is a label, not another executor choice: `via` still supports only the five validated CLIs. The adapter treats host `antigravity` as the `agy` executor. If executor equals current host, ask the user to omit `via` for native implementation. Do not silently choose a different executor.

Resolve `scripts/run-ticket-executor.sh` from the loaded skill's real directory, following installation symlinks, never from the target project's code. Before any workspace or Linear-state mutation, run `bash "$ADAPTER" --check --host "$current_host" --executor "$executor"`, with any override in its environment: it applies the same executor, host, and Pi/agy-override validation and CLI discovery as a run, without launching anything, and a non-zero exit stops delegation before setup. The adapter owns supported command templates and version validation; inspect it when the installed version needs checking.

### Pi has no sandbox

`via pi` runs the Pi coding agent with no sandbox and no per-action approval: its tools act with the user's full permissions. The adapter passes `--no-approve`, so the checkout's `.pi/` settings, extensions, skills, and prompts never load into the executor, and `--no-session`, so no resumable Pi session is saved. Repository context files such as `AGENTS.md` still load, as they do for the other executors.

Optionally set `CKTK_PI_USAGE_DIR` to an absolute directory outside the work directory. The adapter then also writes `<stem>.pi-usage.jsonl` there: a Pi session-format JSONL containing only the `session` header and assistant `message` records with `usage`, `provider`, `model`, and `responseId`. It contains no prompt, system prompt, tool call, or tool output, and it is not a resumable session. TokenBar/Syrtis can read that directory as an additional Pi usage root; records collapse against a real Pi session by `responseId`. Any export failure is recorded as `pi_usage_error` and does not change the delegation outcome.

Strongly recommend `worktree` with `via pi`. Without it, say before launch that Pi will edit the current checkout directly, alongside any pre-existing changes, and suggest `worktree`; continue unless the user changes the request. A worktree confines the diff and protects the main checkout's uncommitted work; it is not a security boundary, because Pi can still reach any path the user can.

Pi uses its own default provider, model, and thinking level. Set `CKTK_PI_MODEL` (and optionally `CKTK_PI_PROVIDER`, which requires a model) or `CKTK_PI_THINKING` in the adapter's environment only when the user names one; otherwise leave them unset. The adapter needs `python3` to read Pi's JSON output. A Pi record adds the `provider`, `model`, `thinking_level`, and `stop_reason` of Pi's last response, a `final_message_file` holding its final text, run counters (`turn_count`, `tool_call_count`, `tool_error_count`, `total_tokens`), and the optional `pi_usage_file`/`pi_usage_error` of the usage export; report the model and thinking level with the outcome. A model error or truncated response is recorded as `failed` even though Pi itself exits 0.

A Pi record also adds a `transcript_file`: a readable `<stem>.transcript.md` digest of the whole run — per-turn assistant text, truncated thinking, and every tool call with its arguments, result summary, error flag, and duration. The raw JSON event stream stays in `output_file` for anything the digest drops. Read the transcript whenever a Pi run fails, times out, or leaves a diff that does not match its final message, and cite the relevant steps, failed tool calls, and commands in the outcome report instead of only the final message. Transcript building is best effort; a failure is recorded as `transcript_error` and does not change the delegation outcome.

### agy runs with auto-approved permissions

`via agy` runs the Antigravity CLI headless with `--dangerously-skip-permissions`: every tool request is approved, so it acts with the user's full permissions and its configured MCP servers. Recommend `worktree` as for Pi. The adapter disables slash-command and skill expansion so ticket text cannot start another workflow; repository context files such as `AGENTS.md` still load. agy takes its prompt only on the command line, so the packaged task is visible in the process list while it runs and the input file must be at most 120000 bytes; trim a larger input instead of splitting the run. agy saves the run as a normal conversation whose `conversation_id` the record names, so the user can inspect it later.

agy uses its own default model and effort. When the user names one, set `CKTK_AGY_MODEL` to an ID from `agy models` and/or `CKTK_AGY_EFFORT` to `low`, `medium`, `high`, `xhigh`, or `max` in the adapter's environment for both `--check` and the run; otherwise leave them unset. Map a display name such as "Claude Opus 5.5 high" to its ID (`claude-opus-5-5-high`); a base ID such as `gemini-3.8-flash` combines with `CKTK_AGY_EFFORT`, while an ID with an effort suffix already fixes it and conflicts with a different effort. `--check` validates only the syntax; agy rejects an unknown model or a conflicting effort at launch, which the record shows as `failed` with `agy_error`. The adapter needs `python3` to read agy's stream-json output. An agy record adds `model` (as agy resolved it), `requested_model`, `requested_effort`, `agy_status`, `agy_error`, `conversation_id`, run counters (`turn_count`, `tool_call_count`, `tool_error_count`, `total_tokens`), a `final_message_file`, and a `transcript_file` digest of assistant text and tool steps (or `transcript_error`); report the model and effort with the outcome, and read the transcript as for Pi when a run fails or its diff does not match its final message. A result other than `SUCCESS` is recorded as `failed` even if agy exits 0.

## Package the agreed task

After business-context and workspace readiness, create a unique stem under `$DELEGATION_DIR`: the diagnostics directory a calling skill supplies, otherwise `$WORK_DIR/.ai/cktk/delegation/`. A caller that needs a clean worktree, such as `implement-backlog-linear`, supplies a directory outside it. Write `<stem>.input.md` with a file-writing tool. Include the exact ticket, full requirements and acceptance criteria, business role, direct and indirect ticket relationships with supporting evidence, agreed decisions, scope boundaries, absolute source/workspace paths, expected areas, and relevant checks.

Include the instruction to stop and report a new business contradiction rather than choosing an interpretation. The target agent **must not commit, push, merge, delete a worktree, or change ticket status**. Do not provide connector credentials, hidden reasoning, or instructions to access Linear. The host owns any Backlog → In Progress or Todo → In Progress transition at the time specified by the invoking skill.

Use `<stem>.json` as the outcome record. Preserve diagnostics on failure/timeout; exclude `$DELEGATION_DIR` from source review and all staging.

## Run the adapter once

```sh
bash "$ADAPTER" \
  --host "$current_host" \
  --executor "$executor" \
  --work-dir "$WORK_DIR" \
  --task-file "$DELEGATION_DIR/<stem>.input.md" \
  --record-file "$DELEGATION_DIR/<stem>.json" \
  --timeout-seconds 1800
```

Select `WORK_DIR` explicitly for this call. The adapter validates the executor, discovers the CLI, builds its task package, bounds execution, captures output, checks git state and changes, and writes the outcome record. Do not replace it with `eval`, a free-form command template, or an automatic retry.

On non-zero exit, read the record's `status` when available and report the error, directory, and record path. Raw executor exit codes can be preserved, so do not infer the cause from the number alone. In particular, distinguish `no_changes`, `forbidden_git_state`, `git_inspection_failed`, and timeout. Preserve all work; do not commit, reset, retry, land, or remove the worktree after a failed run.

On success, read the executor's outcome and inspect the actual changes against the pre-delegation baseline. Source changes must exist outside the diagnostic directory; a pre-existing dirty file is not evidence of new work. If there is no reviewable implementation, report that and stop. A business conflict or blocked/incomplete outcome still needs host attention even when the process exited zero.

Continue to host-run validation and ticket-specific review in the main skill. The executor's final message is not verification, and it cannot resolve business contradictions on the user's behalf.
