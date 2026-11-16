#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adapter="$root/skills/implement-ticket/scripts/run-ticket-executor.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/cktk-ticket-delegation-test.XXXXXX")"
tmp="$(cd "$tmp" && pwd -P)"
fake_bin="$tmp/bin"
repo="$tmp/repo"
task_file="$tmp/ticket-task.md"
tests=0

# Pi and agy overrides come only from the cases that set them.
unset CKTK_PI_MODEL CKTK_PI_PROVIDER CKTK_PI_THINKING CKTK_PI_USAGE_DIR
unset CKTK_AGY_MODEL CKTK_AGY_EFFORT

cleanup() {
  if [[ "${KEEP_TEST_TMP:-0}" = "1" ]]; then
    printf 'Kept test directory: %s\n' "$tmp" >&2
    return
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  tests=$((tests + 1))
  printf 'ok %d - %s\n' "$tests" "$1"
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" ||
    fail "expected '$expected' in $file"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "did not expect path to exist: $1"
}

assert_json_field() {
  local file="$1"
  local field="$2"
  local expected="$3"

  python3 - "$file" "$field" "$expected" <<'PY'
import json
import sys

path, field, expected = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)
actual = data[field]
if str(actual) != expected:
    raise SystemExit(f"{path}: expected {field}={expected!r}, got {actual!r}")
PY
}

json_field() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)[sys.argv[2]])
PY
}

assert_pi_usage() {
  local file="$1"
  local expected_cwd="$2"
  python3 - "$file" "$expected_cwd" <<'PY' || fail "Pi usage export was invalid: $file"
import json
import sys

path, expected_cwd = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    lines = [json.loads(line) for line in handle if line.strip()]

assert lines[0]["type"] == "session"
assert lines[0]["version"] == 3
assert lines[0]["id"] == "cktk-pi-success"
assert lines[0]["cwd"] == expected_cwd

messages = [line for line in lines[1:] if line["type"] == "message"]
expected = [
    (100, 10, 5, 0, 115, "resp-1", "fake-model-1"),
    (200, 20, 0, 7, 227, "resp-2", "fake-model-2"),
]
assert len(messages) == len(expected)
for record, (i, o, cache_read, cache_write, total, response_id, model) in zip(
    messages, expected
):
    message = record["message"]
    assert message["role"] == "assistant"
    assert message["usage"] == {
        "input": i,
        "output": o,
        "cacheRead": cache_read,
        "cacheWrite": cache_write,
        "totalTokens": total,
    }
    assert message["provider"] == "fake-provider"
    assert message["model"] == model
    assert message["responseId"] == response_id
    assert "content" not in message
    assert record["timestamp"].endswith("Z")

raw = open(path, encoding="utf-8").read()
assert "Calling a tool." not in raw
assert "Implemented the ticket." not in raw
PY
}

run_case() {
  local name="$1"
  local expected_exit="$2"
  local path_value="$3"
  shift 3
  local stdout="$tmp/$name.stdout"
  local stderr="$tmp/$name.stderr"
  local actual_exit

  set +e
  env \
    PATH="$path_value" \
    FAKE_AGENT_LOG="$tmp/$name.fake.log" \
    FAKE_AGENT_STDIN="$tmp/$name.fake.stdin" \
    FAKE_AGENT_MODE="${FAKE_AGENT_MODE:-success}" \
    FAKE_AGENT_EXIT_CODE="${FAKE_AGENT_EXIT_CODE:-0}" \
    FAKE_AGENT_VERSION_EXIT_CODE="${FAKE_AGENT_VERSION_EXIT_CODE:-0}" \
    FAKE_AGENT_CHANGE_FILE="${FAKE_AGENT_CHANGE_FILE:-}" \
    FAKE_AGENT_STDOUT_FILE="${FAKE_AGENT_STDOUT_FILE:-}" \
    /bin/bash "$adapter" "$@" >"$stdout" 2>"$stderr"
  actual_exit=$?
  set -e

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    printf '%s\n' "--- stdout ($name) ---" >&2
    cat "$stdout" >&2
    printf '%s\n' "--- stderr ($name) ---" >&2
    cat "$stderr" >&2
    fail "$name exited $actual_exit, expected $expected_exit"
  fi
}

[[ -x "$adapter" ]] ||
  fail "delegation adapter is not executable: $adapter"

mkdir -p "$fake_bin" "$repo"
git -C "$repo" init -q
git -C "$repo" config user.name "Ticket Delegation Test"
git -C "$repo" config user.email "ticket-delegation@example.com"
printf 'baseline\n' >"$repo/tracked.txt"
git -C "$repo" add tracked.txt
git -C "$repo" commit -qm "baseline"

cat >"$fake_bin/fake-agent" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" = "--version" ]]; then
  printf 'fake-agent 1.0\n'
  exit "${FAKE_AGENT_VERSION_EXIT_CODE:-0}"
fi

{
  printf 'argv:'
  printf ' <%s>' "$@"
  printf '\n'
} >"${FAKE_AGENT_LOG:?}"
cat >"${FAKE_AGENT_STDIN:?}"
if [[ -n "${FAKE_AGENT_STDOUT_FILE:-}" ]]; then
  cat "$FAKE_AGENT_STDOUT_FILE"
fi

case "${FAKE_AGENT_MODE:-success}" in
  success)
    if [[ -n "${FAKE_AGENT_CHANGE_FILE:-}" ]]; then
      printf 'delegated change\n' >"$FAKE_AGENT_CHANGE_FILE"
    fi
    ;;
  sleep)
    sleep 10
    ;;
  commit)
    printf 'delegated commit\n' >"${FAKE_AGENT_CHANGE_FILE:?}"
    git -C "$(dirname "$FAKE_AGENT_CHANGE_FILE")" \
      add "$(basename "$FAKE_AGENT_CHANGE_FILE")"
    git -C "$(dirname "$FAKE_AGENT_CHANGE_FILE")" \
      commit -qm "forbidden delegated commit"
    ;;
  commit-sleep)
    printf 'delegated commit before sleep\n' >"${FAKE_AGENT_CHANGE_FILE:?}"
    git -C "$(dirname "$FAKE_AGENT_CHANGE_FILE")" \
      add "$(basename "$FAKE_AGENT_CHANGE_FILE")"
    git -C "$(dirname "$FAKE_AGENT_CHANGE_FILE")" \
      commit -qm "forbidden delegated commit before timeout"
    sleep 10
    ;;
  *)
    printf 'unknown fake mode: %s\n' "$FAKE_AGENT_MODE" >&2
    exit 99
    ;;
esac

exit "${FAKE_AGENT_EXIT_CODE:-0}"
FAKE
chmod +x "$fake_bin/fake-agent"
for executor_name in codex claude grok pi; do
  ln -s fake-agent "$fake_bin/$executor_name"
done

cat >"$task_file" <<EOF
Implement the ticket acceptance criteria.
Keep this literal: \$(touch "$tmp/INJECTED")
EOF

# Pi's JSON event stream, abridged to the events the adapter reads. Stderr
# shares the output capture, so a non-JSON line is mixed in.
cat >"$tmp/pi-events.jsonl" <<'EOF'
{"type":"session","version":3,"id":"fake-session"}
pi: warming up provider
{"type":"agent_start"}
{"type":"turn_start"}
{"type":"message_update","usage":{"input":1,"output":1},"assistantMessageEvent":{"type":"text_delta"}}
{"type":"message_end","message":{"role":"user","content":[{"type":"text","text":"task"}]}}
{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"Calling a tool."},{"type":"toolCall","id":"call-1","name":"bash","arguments":{"command":"npm test"}}],"timestamp":1760000000000,"responseId":"resp-1","provider":"fake-provider","model":"fake-model-1","thinkingLevel":"low","stopReason":"toolUse","usage":{"input":100,"output":10,"cacheRead":5,"cacheWrite":0,"totalTokens":115}}}
{"type":"tool_execution_start","toolCallId":"call-1","toolName":"bash","args":{"command":"npm test"}}
{"type":"tool_execution_end","toolCallId":"call-1","toolName":"bash","result":{"content":[{"type":"text","text":"exit 1: boom"}],"isError":true},"isError":true,"durationMs":3400}
{"type":"tool_execution_start","toolCallId":"call-2","toolName":"write","args":{"path":"app.txt","content":"delegated change"}}
{"type":"tool_execution_end","toolCallId":"call-2","toolName":"write","result":{"content":[{"type":"text","text":"wrote app.txt"}],"isError":false},"isError":false,"durationMs":12}
{"type":"turn_end"}
{"type":"turn_start"}
{"type":"message_end","message":{"role":"assistant","content":[{"type":"thinking","thinking":"hidden"},{"type":"text","text":"Implemented the ticket."}],"timestamp":1760000001000,"responseId":"resp-2","provider":"fake-provider","model":"fake-model-2","thinkingLevel":"xhigh","stopReason":"stop","usage":{"input":200,"output":20,"cacheRead":0,"cacheWrite":7,"totalTokens":227}}}
{"type":"turn_end"}
{"type":"agent_end"}
EOF
cat >"$tmp/pi-error-events.jsonl" <<'EOF'
{"type":"message_end","message":{"role":"assistant","content":[],"provider":"fake-provider","model":"fake-model-2","thinkingLevel":"xhigh","stopReason":"error","errorMessage":"429 rate limited"}}
EOF

system_path="/usr/bin:/bin"
test_path="$fake_bin:$system_path"

# Invalid argument values must fail before launching any executor.
run_case invalid-timeout 2 "$test_path" \
  --host claude \
  --executor codex \
  --work-dir "$repo" \
  --task-file "$task_file" \
  --record-file "$tmp/invalid-timeout.json" \
  --timeout-seconds 0
assert_contains "$tmp/invalid-timeout.stderr" \
  "timeout seconds must be a positive integer"
assert_not_exists "$tmp/invalid-timeout.fake.log"
pass "invalid adapter arguments fail before launch"

# Executor selection is a closed allowlist.
run_case unsupported 3 "$test_path" \
  --host claude \
  --executor unsupported \
  --work-dir "$repo" \
  --task-file "$task_file" \
  --record-file "$tmp/unsupported.json"
assert_contains "$tmp/unsupported.stderr" "unsupported executor: unsupported"
assert_not_exists "$tmp/unsupported.fake.log"
pass "unsupported executors are rejected"

# The native host path is not delegated back into the same CLI.
run_case same-host 3 "$test_path" \
  --host codex \
  --executor codex \
  --work-dir "$repo" \
  --task-file "$task_file" \
  --record-file "$tmp/same-host.json"
assert_contains "$tmp/same-host.stderr" \
  "executor 'codex' is the current host; omit via to use native implementation"
assert_not_exists "$tmp/same-host.fake.log"
pass "delegation back to the invoking host is rejected"

# Other hosts can use the existing validated executor boundary.
for invoking_agent in opencode antigravity; do
  FAKE_AGENT_MODE=success \
  FAKE_AGENT_EXIT_CODE=0 \
  FAKE_AGENT_CHANGE_FILE="$repo/$invoking_agent-change.txt" \
    run_case "$invoking_agent-host" 0 "$test_path" \
      --host "$invoking_agent" \
      --executor claude \
      --work-dir "$repo" \
      --task-file "$task_file" \
      --record-file "$tmp/$invoking_agent-host.json" \
      --timeout-seconds 5
  assert_json_field "$tmp/$invoking_agent-host.json" host "$invoking_agent"
  assert_json_field "$tmp/$invoking_agent-host.json" executor claude
  assert_json_field "$tmp/$invoking_agent-host.json" status completed
done
pass "OpenCode and Antigravity hosts can use supported executors"

# CLI discovery occurs before a task package or process is created.
run_case missing-cli 4 "$system_path" \
  --host codex \
  --executor claude \
  --work-dir "$repo" \
  --task-file "$task_file" \
  --record-file "$tmp/missing-cli.json"
assert_contains "$tmp/missing-cli.stderr" "Claude Code CLI is not installed"
assert_not_exists "$tmp/missing-cli.task.md"
assert_not_exists "$tmp/missing-cli.output.log"
pass "missing CLIs fail before launch"

# An installed but unusable CLI fails discovery before packaging or launch.
FAKE_AGENT_VERSION_EXIT_CODE=41 \
  run_case failed-version-check 4 "$test_path" \
    --host grok \
    --executor claude \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/failed-version-check.json"
assert_contains "$tmp/failed-version-check.stderr" \
  "Claude Code CLI failed its version check"
assert_not_exists "$tmp/failed-version-check.task.md"
assert_not_exists "$tmp/failed-version-check.fake.log"
pass "unusable CLIs fail discovery before launch"

# Codex receives only its fixed argv template, and the adapter builds the final
# implementation-only task package without evaluating ticket text as shell.
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/codex-change.txt" \
  run_case codex-success 0 "$test_path" \
    --host claude \
    --executor codex \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/codex-success.json" \
    --timeout-seconds 5
assert_contains "$tmp/codex-success.fake.log" \
  "argv: <exec> <--cd> <$repo> <->"
assert_contains "$tmp/codex-success.fake.stdin" \
  "must not commit, push, merge, delete a worktree, or change ticket status"
assert_contains "$tmp/codex-success.fake.stdin" \
  "\$(touch \"$tmp/INJECTED\")"
assert_not_exists "$tmp/INJECTED"
assert_json_field "$tmp/codex-success.json" executor codex
assert_json_field "$tmp/codex-success.json" status completed
assert_json_field "$tmp/codex-success.json" exit_code 0
codex_package="$(json_field "$tmp/codex-success.json" task_package_file)"
codex_output="$(json_field "$tmp/codex-success.json" output_file)"
[[ -f "$codex_package" ]] || fail "missing task package: $codex_package"
[[ -f "$codex_output" ]] || fail "missing output capture: $codex_output"
pass "Codex uses a fixed template and literal task package"

# Claude and Grok use their own immutable non-interactive templates.
git -C "$repo" add codex-change.txt
git -C "$repo" commit -qm "reset after codex fixture"
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/claude-change.txt" \
  run_case claude-success 0 "$test_path" \
    --host grok \
    --executor claude \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/claude-success.json"
assert_contains "$tmp/claude-success.fake.log" \
  "argv: <--print> <--dangerously-skip-permissions>"
assert_json_field "$tmp/claude-success.json" status completed

git -C "$repo" add claude-change.txt
git -C "$repo" commit -qm "reset after claude fixture"
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/grok-change.txt" \
  run_case grok-success 0 "$test_path" \
    --host codex \
    --executor grok \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/grok-success.json"
grok_package="$(json_field "$tmp/grok-success.json" task_package_file)"
assert_contains "$tmp/grok-success.fake.log" \
  "argv: <--cwd> <$repo> <--permission-mode> <bypassPermissions> <--prompt-file> <$grok_package>"
[[ ! -s "$tmp/grok-success.fake.stdin" ]] ||
  fail "Grok received a duplicate stdin prompt in addition to --prompt-file"
assert_json_field "$tmp/grok-success.json" status completed
pass "Claude and Grok use fixed invocation templates"

# Pi runs headless from stdin, without a saved session or project-local
# resources, and keeps Pi's own model selection unless the host overrides it.
# An opt-in usage export gives local trackers the Pi usage without persisting a
# resumable session.
git -C "$repo" add grok-change.txt
git -C "$repo" commit -qm "reset after grok fixture"
CKTK_PI_USAGE_DIR="$tmp/pi-usage" \
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/pi-change.txt" \
FAKE_AGENT_STDOUT_FILE="$tmp/pi-events.jsonl" \
  run_case pi-success 0 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-success.json" \
    --timeout-seconds 5
grep -Fxq -- "argv: <--print> <--mode> <json> <--no-session> <--no-approve>" \
  "$tmp/pi-success.fake.log" ||
  fail "Pi did not receive exactly its default template"
assert_contains "$tmp/pi-success.fake.stdin" \
  "must not commit, push, merge, delete a worktree, or change ticket status"
assert_contains "$tmp/pi-success.fake.stdin" \
  "\$(touch \"$tmp/INJECTED\")"
assert_not_exists "$tmp/INJECTED"
assert_json_field "$tmp/pi-success.json" executor pi
assert_json_field "$tmp/pi-success.json" host claude
assert_json_field "$tmp/pi-success.json" status completed
assert_json_field "$tmp/pi-success.json" exit_code 0
assert_json_field "$tmp/pi-success.json" provider fake-provider
assert_json_field "$tmp/pi-success.json" model fake-model-2
assert_json_field "$tmp/pi-success.json" thinking_level xhigh
assert_json_field "$tmp/pi-success.json" stop_reason stop
pi_final="$(json_field "$tmp/pi-success.json" final_message_file)"
[[ "$(cat "$pi_final")" = "Implemented the ticket." ]] ||
  fail "Pi final message was not extracted from the last assistant message"
pi_usage="$(json_field "$tmp/pi-success.json" pi_usage_file)"
[[ -f "$pi_usage" ]] || fail "Pi usage export was not written: $pi_usage"
assert_pi_usage "$pi_usage" "$repo"
[[ "$(json_field "$tmp/pi-success.json" pi_usage_error)" = "None" ]] ||
  fail "Pi usage export reported an error"
pi_transcript="$(json_field "$tmp/pi-success.json" transcript_file)"
[[ -f "$pi_transcript" ]] || fail "Pi transcript was not written: $pi_transcript"
[[ "$(json_field "$tmp/pi-success.json" transcript_error)" = "None" ]] ||
  fail "Pi transcript reported an error"
assert_contains "$pi_transcript" "Calling a tool."
assert_contains "$pi_transcript" "Implemented the ticket."
assert_contains "$pi_transcript" 'tool `bash` {"command":"npm test"}'
assert_contains "$pi_transcript" "**error** in 3400ms"
assert_contains "$pi_transcript" "exit 1: boom"
assert_contains "$pi_transcript" 'tool `write` {"path":"app.txt"'
assert_contains "$pi_transcript" "ok in 12ms: wrote app.txt"
assert_contains "$pi_transcript" "thinking (truncated): hidden"
assert_contains "$pi_transcript" "warming up provider"
assert_json_field "$tmp/pi-success.json" turn_count 2
assert_json_field "$tmp/pi-success.json" tool_call_count 2
assert_json_field "$tmp/pi-success.json" tool_error_count 1
assert_json_field "$tmp/pi-success.json" total_tokens 342
pi_transcript_mode="$(python3 -c \
  'import os,sys; print("%o" % (os.stat(sys.argv[1]).st_mode & 0o777))' \
  "$pi_transcript")"
[[ "$pi_transcript_mode" = "600" ]] ||
  fail "Pi transcript is not owner-only readable"
pass "Pi uses a fixed stdin template and records the model it used"
pass "Pi writes an opt-in usage-only export without saving a session"
pass "Pi writes a readable transcript and run counters for the host"

git -C "$repo" add pi-change.txt
git -C "$repo" commit -qm "reset after pi fixture"
CKTK_PI_PROVIDER=openrouter \
CKTK_PI_MODEL=anthropic/claude-sonnet-4 \
CKTK_PI_THINKING=high \
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/pi-model-change.txt" \
  run_case pi-model-override 0 "$test_path" \
    --host codex \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-model-override.json" \
    --timeout-seconds 5
assert_contains "$tmp/pi-model-override.fake.log" \
  "argv: <--print> <--mode> <json> <--no-session> <--no-approve> <--provider> <openrouter> <--model> <anthropic/claude-sonnet-4> <--thinking> <high>"
assert_json_field "$tmp/pi-model-override.json" status completed
[[ "$(json_field "$tmp/pi-model-override.json" pi_usage_file)" = "None" ]] ||
  fail "Pi wrote a usage export without CKTK_PI_USAGE_DIR"
pass "Pi model, provider, and thinking overrides are passed as fixed arguments"

# An export failure degrades to pi_usage_error without changing the outcome:
# classification metadata is printed before the export is attempted, and a
# read-only usage directory makes the export write fail.
mkdir -p "$tmp/pi-usage-fail"
chmod 500 "$tmp/pi-usage-fail"
CKTK_PI_USAGE_DIR="$tmp/pi-usage-fail" \
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/pi-usage-fail-change.txt" \
FAKE_AGENT_STDOUT_FILE="$tmp/pi-events.jsonl" \
  run_case pi-usage-failure 0 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-usage-failure.json" \
    --timeout-seconds 5
chmod 700 "$tmp/pi-usage-fail"
assert_json_field "$tmp/pi-usage-failure.json" status completed
assert_json_field "$tmp/pi-usage-failure.json" model fake-model-2
assert_json_field "$tmp/pi-usage-failure.json" stop_reason stop
[[ "$(json_field "$tmp/pi-usage-failure.json" pi_usage_file)" = "None" ]] ||
  fail "Pi recorded a usage export path despite the failed write"
pi_usage_error="$(json_field "$tmp/pi-usage-failure.json" pi_usage_error)"
[[ -n "$pi_usage_error" && "$pi_usage_error" != "None" ]] ||
  fail "Pi usage export failure was not recorded in pi_usage_error"
assert_contains "$tmp/pi-usage-failure.stderr" \
  "WARNING: Pi usage export failed:"
assert_not_exists "$tmp/pi-usage-fail/pi-usage-failure.pi-usage.jsonl.tmp"
git -C "$repo" add pi-usage-fail-change.txt
git -C "$repo" commit -qm "reset after pi usage failure fixture"
pass "a Pi usage export failure is recorded without changing the outcome"

# Override values are validated before CLI discovery or launch.
CKTK_PI_PROVIDER=openrouter \
  run_case pi-provider-without-model 2 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-provider-without-model.json"
assert_contains "$tmp/pi-provider-without-model.stderr" \
  "CKTK_PI_PROVIDER requires CKTK_PI_MODEL"
assert_not_exists "$tmp/pi-provider-without-model.fake.log"
assert_not_exists "$tmp/pi-provider-without-model.task.md"
CKTK_PI_MODEL=--approve \
  run_case pi-invalid-model 2 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-invalid-model.json"
assert_contains "$tmp/pi-invalid-model.stderr" "invalid CKTK_PI_MODEL: --approve"
assert_not_exists "$tmp/pi-invalid-model.fake.log"
CKTK_PI_THINKING=extreme \
  run_case pi-invalid-thinking 2 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-invalid-thinking.json"
assert_contains "$tmp/pi-invalid-thinking.stderr" \
  "invalid CKTK_PI_THINKING: extreme"
assert_not_exists "$tmp/pi-invalid-thinking.fake.log"
CKTK_PI_USAGE_DIR=relative/pi-usage \
  run_case pi-usage-relative 2 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-usage-relative.json"
assert_contains "$tmp/pi-usage-relative.stderr" \
  "CKTK_PI_USAGE_DIR must be an absolute path"
assert_not_exists "$tmp/pi-usage-relative.fake.log"
CKTK_PI_USAGE_DIR="$repo/pi-usage" \
  run_case pi-usage-in-worktree 2 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-usage-in-worktree.json"
assert_contains "$tmp/pi-usage-in-worktree.stderr" \
  "CKTK_PI_USAGE_DIR must be outside the work directory"
assert_not_exists "$tmp/pi-usage-in-worktree.fake.log"
assert_not_exists "$repo/pi-usage"
pass "invalid Pi overrides fail before launch"

# A Pi host cannot delegate to Pi, near-miss names are not Pi, and a Pi host
# can still delegate to another executor.
run_case pi-same-host 3 "$test_path" \
  --host pi \
  --executor pi \
  --work-dir "$repo" \
  --task-file "$task_file" \
  --record-file "$tmp/pi-same-host.json"
assert_contains "$tmp/pi-same-host.stderr" \
  "executor 'pi' is the current host; omit via to use native implementation"
assert_not_exists "$tmp/pi-same-host.fake.log"
run_case pi-unknown-executor 3 "$test_path" \
  --host claude \
  --executor pi-mono \
  --work-dir "$repo" \
  --task-file "$task_file" \
  --record-file "$tmp/pi-unknown-executor.json"
assert_contains "$tmp/pi-unknown-executor.stderr" \
  "unsupported executor: pi-mono"
assert_not_exists "$tmp/pi-unknown-executor.fake.log"
git -C "$repo" add pi-model-change.txt
git -C "$repo" commit -qm "reset after pi override fixture"
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/pi-host-change.txt" \
  run_case pi-host 0 "$test_path" \
    --host pi \
    --executor claude \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-host.json" \
    --timeout-seconds 5
assert_json_field "$tmp/pi-host.json" host pi
assert_json_field "$tmp/pi-host.json" executor claude
assert_json_field "$tmp/pi-host.json" status completed
pass "Pi host and executor names are validated"

run_case pi-missing-cli 4 "$system_path" \
  --host claude \
  --executor pi \
  --work-dir "$repo" \
  --task-file "$task_file" \
  --record-file "$tmp/pi-missing-cli.json"
assert_contains "$tmp/pi-missing-cli.stderr" \
  "Pi coding agent CLI is not installed (expected command: pi)"
assert_not_exists "$tmp/pi-missing-cli.task.md"
pass "a missing Pi CLI fails before launch"

# Pi outcomes share the adapter's Git and timeout classification.
git -C "$repo" add pi-host-change.txt
git -C "$repo" commit -qm "reset after pi host fixture"
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="" \
  run_case pi-no-change 6 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-no-change.json"
assert_json_field "$tmp/pi-no-change.json" status no_changes
assert_json_field "$tmp/pi-no-change.json" executor pi
assert_json_field "$tmp/pi-no-change.json" model None
assert_json_field "$tmp/pi-no-change.json" final_message_file None
assert_json_field "$tmp/pi-no-change.json" transcript_file None
assert_json_field "$tmp/pi-no-change.json" tool_call_count None

before_pi_commit_head="$(git -C "$repo" rev-parse HEAD)"
FAKE_AGENT_MODE=commit \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/pi-forbidden.txt" \
  run_case pi-forbidden 7 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-forbidden.json"
assert_json_field "$tmp/pi-forbidden.json" status forbidden_git_state
assert_json_field "$tmp/pi-forbidden.json" exit_code 0
[[ "$(git -C "$repo" rev-parse HEAD)" != "$before_pi_commit_head" ]] ||
  fail "adapter discarded Pi's forbidden commit"

FAKE_AGENT_MODE=sleep \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="" \
  run_case pi-timeout 5 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-timeout.json" \
    --timeout-seconds 1
assert_json_field "$tmp/pi-timeout.json" status timed_out
assert_json_field "$tmp/pi-timeout.json" exit_code 5
[[ "$(wc -l <"$tmp/pi-timeout.fake.log" | tr -d ' ')" = "1" ]] ||
  fail "timed-out Pi run was retried"
pass "Pi no-change, forbidden commit, and timeout outcomes are classified"

# Pi's JSON mode exits 0 when the model call ends in an error; the adapter
# reads the stop reason so the run is not mistaken for a no-change success.
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="" \
FAKE_AGENT_STDOUT_FILE="$tmp/pi-error-events.jsonl" \
  run_case pi-error-stop 1 "$test_path" \
    --host claude \
    --executor pi \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/pi-error-stop.json"
assert_json_field "$tmp/pi-error-stop.json" status failed
assert_json_field "$tmp/pi-error-stop.json" exit_code 0
assert_json_field "$tmp/pi-error-stop.json" stop_reason error
assert_contains "$tmp/pi-error-stop.stderr" \
  "executor stopped with reason error"
assert_contains "$(json_field "$tmp/pi-error-stop.json" final_message_file)" \
  "429 rate limited"
assert_contains "$(json_field "$tmp/pi-error-stop.json" transcript_file)" \
  "**error:** 429 rate limited"
assert_json_field "$tmp/pi-error-stop.json" tool_call_count 0
pass "a Pi model error is recorded as a failure"

# Records for other executors keep their existing fields.
python3 - "$tmp/codex-success.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    record = json.load(handle)
extra = {
    "provider",
    "model",
    "thinking_level",
    "stop_reason",
    "final_message_file",
    "transcript_file",
    "transcript_error",
    "turn_count",
    "tool_call_count",
    "tool_error_count",
    "total_tokens",
} & set(record)
if extra:
    raise SystemExit(f"non-Pi record gained Pi fields: {sorted(extra)}")
PY
pass "non-Pi records keep their existing fields"

# A target failure is recorded and returned without retrying.
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=23 \
FAKE_AGENT_CHANGE_FILE="" \
  run_case target-failure 23 "$test_path" \
    --host claude \
    --executor codex \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/target-failure.json"
assert_json_field "$tmp/target-failure.json" status failed
assert_json_field "$tmp/target-failure.json" exit_code 23
[[ "$(wc -l <"$tmp/target-failure.fake.log" | tr -d ' ')" = "1" ]] ||
  fail "target failure was retried"
pass "target failures are recorded without retries"

# A forbidden branch/HEAD mutation takes precedence even if the target also
# exits non-zero, and the adapter preserves the commit for host inspection.
before_forbidden_head="$(git -C "$repo" rev-parse HEAD)"
FAKE_AGENT_MODE=commit \
FAKE_AGENT_EXIT_CODE=23 \
FAKE_AGENT_CHANGE_FILE="$repo/forbidden-failure.txt" \
  run_case forbidden-on-failure 7 "$test_path" \
    --host grok \
    --executor codex \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/forbidden-on-failure.json"
assert_json_field "$tmp/forbidden-on-failure.json" status forbidden_git_state
assert_json_field "$tmp/forbidden-on-failure.json" exit_code 23
[[ "$(git -C "$repo" rev-parse HEAD)" != "$before_forbidden_head" ]] ||
  fail "adapter discarded the target's forbidden commit"
pass "forbidden git state takes precedence over target failure"

# The same safety classification wins when the target commits before timing out.
FAKE_AGENT_MODE=commit-sleep \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/forbidden-timeout.txt" \
  run_case forbidden-on-timeout 7 "$test_path" \
    --host codex \
    --executor claude \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/forbidden-on-timeout.json" \
    --timeout-seconds 1
assert_json_field "$tmp/forbidden-on-timeout.json" status forbidden_git_state
assert_json_field "$tmp/forbidden-on-timeout.json" exit_code 5
[[ -f "$repo/forbidden-timeout.txt" ]] ||
  fail "adapter discarded timed-out target work"
pass "forbidden git state takes precedence over timeout"

# A no-op target must not claim pre-existing dirty work as this run's outcome.
printf 'pre-existing user work\n' >"$repo/pre-existing.txt"
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="" \
  run_case no-change 6 "$test_path" \
    --host codex \
    --executor grok \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/no-change.json"
assert_json_field "$tmp/no-change.json" status no_changes
assert_json_field "$tmp/no-change.json" exit_code 0
[[ -f "$repo/pre-existing.txt" ]] ||
  fail "no-change handling discarded pre-existing work"
pass "dirty-baseline no-op runs stop safely and preserve work"

# A bounded wait terminates the target once and preserves its diagnostic files.
FAKE_AGENT_MODE=sleep \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="" \
  run_case timeout 5 "$test_path" \
    --host codex \
    --executor claude \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/timeout.json" \
    --timeout-seconds 1
assert_json_field "$tmp/timeout.json" status timed_out
assert_json_field "$tmp/timeout.json" exit_code 5
timeout_output="$(json_field "$tmp/timeout.json" output_file)"
[[ -f "$timeout_output" ]] || fail "timeout did not preserve output capture"
[[ "$(wc -l <"$tmp/timeout.fake.log" | tr -d ' ')" = "1" ]] ||
  fail "timed-out target was retried"
pass "timeouts are bounded, recorded, and not retried"

# --check validates and discovers without packaging, launching, or a work
# directory, so callers can confirm an executor before any mutation.
check_files_before="$(ls "$tmp" | wc -l | tr -d ' ')"
run_case check-pi 0 "$test_path" \
  --check \
  --host claude \
  --executor PI
assert_contains "$tmp/check-pi.stdout" \
  "Pi coding agent CLI is available for host claude: $fake_bin/pi"
assert_not_exists "$tmp/check-pi.fake.log"
[[ "$(ls "$tmp" | grep -vc '^check-pi\.')" = "$check_files_before" ]] ||
  fail "--check created files besides its own captured output"
run_case check-same-host 3 "$test_path" \
  --check \
  --host pi \
  --executor pi
assert_contains "$tmp/check-same-host.stderr" \
  "executor 'pi' is the current host"
run_case check-unsupported 3 "$test_path" \
  --check \
  --host claude \
  --executor pi-mono
run_case check-missing-cli 4 "$system_path" \
  --check \
  --host claude \
  --executor codex
assert_contains "$tmp/check-missing-cli.stderr" "Codex CLI is not installed"
FAKE_AGENT_VERSION_EXIT_CODE=41 \
  run_case check-failed-version 4 "$test_path" \
    --check \
    --host codex \
    --executor grok
CKTK_PI_THINKING=extreme \
  run_case check-invalid-override 2 "$test_path" \
    --check \
    --host claude \
    --executor pi
assert_contains "$tmp/check-invalid-override.stderr" \
  "invalid CKTK_PI_THINKING: extreme"
run_case check-with-run-arguments 2 "$test_path" \
  --check \
  --host claude \
  --executor pi \
  --work-dir "$repo"
assert_contains "$tmp/check-with-run-arguments.stderr" \
  "--check takes only --host and --executor"
pass "--check validates and discovers an executor without launching it"

# agy takes the package as one attached --print= argument with stdin closed,
# never expands slash commands, and passes model and effort only when set.
cat >"$tmp/agy-events.jsonl" <<'EOF'
{"event":"init","conversation_id":"conv-1","init":{"model":"gemini-3.8-flash","cwd":"/repo","permission_mode":"always-proceed"}}
{"event":"step_update","step_update":{"conversation_id":"conv-1","step_index":0,"state":"DONE","step_type":"user_input"}}
{"event":"step_update","step_update":{"conversation_id":"conv-1","step_index":1,"state":"DONE","step_type":"agent_response","text_delta":"Running the tests first."}}
{"event":"step_update","step_update":{"conversation_id":"conv-1","step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"run_command","tool_info":{"name":"run_command","parameters":{"CommandLine":"npm test"}}}}
{"event":"step_update","step_update":{"conversation_id":"conv-1","step_index":2,"state":"ERROR","step_type":"tool","tool_name":"run_command","error":"exit 1: boom","duration_seconds":3.4}}
{"event":"step_update","step_update":{"conversation_id":"conv-1","step_index":3,"state":"DONE","step_type":"tool","tool_name":"write_file","tool_info":{"name":"write_file","parameters":{"Path":"/repo/app.txt"}},"duration_seconds":0.2}}
agy: warming up
{"event":"step_update","step_update":{"conversation_id":"conv-1","step_index":4,"state":"DONE","step_type":"agent_response","text_delta":"Implemented the ticket.\n"}}
{"event":"result","result":{"conversation_id":"conv-1","status":"SUCCESS","response":"Implemented the ticket.\n","duration_seconds":7.7,"num_turns":1,"usage":{"input_tokens":200,"output_tokens":35,"thinking_tokens":0,"cache_read_tokens":10,"total_tokens":235}}}
EOF
cat >"$tmp/agy-error-events.jsonl" <<'EOF'
{"event":"result","result":{"conversation_id":"","status":"ERROR","response":"","error":"quota exhausted","num_turns":0,"usage":{"total_tokens":0},"finished_reason":"error"}}
EOF
ln -s fake-agent "$fake_bin/agy"

CKTK_AGY_MODEL=gemini-3.8-flash \
CKTK_AGY_EFFORT=high \
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/agy-change.txt" \
FAKE_AGENT_STDOUT_FILE="$tmp/agy-events.jsonl" \
  run_case agy-success 0 "$test_path" \
    --host claude \
    --executor AGY \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/agy-success.json" \
    --timeout-seconds 5
assert_contains "$tmp/agy-success.fake.log" \
  "argv: <--dangerously-skip-permissions> <--disable-slash-commands> <--output-format> <stream-json> <--model> <gemini-3.8-flash> <--effort> <high> <--print=# CKTK delegated ticket implementation"
assert_contains "$tmp/agy-success.fake.log" \
  "must not commit, push, merge, delete a worktree, or change ticket status"
assert_contains "$tmp/agy-success.fake.log" "\$(touch \"$tmp/INJECTED\")"
assert_not_exists "$tmp/INJECTED"
[[ ! -s "$tmp/agy-success.fake.stdin" ]] ||
  fail "agy received a stdin prompt in addition to --print"
assert_json_field "$tmp/agy-success.json" executor agy
assert_json_field "$tmp/agy-success.json" status completed
assert_json_field "$tmp/agy-success.json" model gemini-3.8-flash
assert_json_field "$tmp/agy-success.json" requested_model gemini-3.8-flash
assert_json_field "$tmp/agy-success.json" requested_effort high
assert_json_field "$tmp/agy-success.json" agy_status SUCCESS
assert_json_field "$tmp/agy-success.json" agy_error None
assert_json_field "$tmp/agy-success.json" conversation_id conv-1
assert_json_field "$tmp/agy-success.json" turn_count 1
assert_json_field "$tmp/agy-success.json" tool_call_count 2
assert_json_field "$tmp/agy-success.json" tool_error_count 1
assert_json_field "$tmp/agy-success.json" total_tokens 235
assert_json_field "$tmp/agy-success.json" transcript_error None
agy_final="$(json_field "$tmp/agy-success.json" final_message_file)"
assert_contains "$agy_final" "Implemented the ticket."
agy_transcript="$(json_field "$tmp/agy-success.json" transcript_file)"
assert_contains "$agy_transcript" "- model: gemini-3.8-flash (requested: gemini-3.8-flash, effort: high)"
assert_contains "$agy_transcript" "tool \`run_command\` {\"CommandLine\":\"npm test\"} → **error** in 3.4s"
assert_contains "$agy_transcript" "  error: exit 1: boom"
assert_contains "$agy_transcript" "tool \`write_file\` {\"Path\":\"/repo/app.txt\"} → ok in 0.2s"
assert_contains "$agy_transcript" "\`[non-JSON output]\` agy: warming up"
assert_contains "$agy_transcript" "Running the tests first."
git -C "$repo" add agy-change.txt
git -C "$repo" commit -qm "reset after agy fixture"

FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/agy-default-change.txt" \
  run_case agy-default 0 "$test_path" \
    --host codex \
    --executor agy \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/agy-default.json" \
    --timeout-seconds 5
assert_contains "$tmp/agy-default.fake.log" \
  "argv: <--dangerously-skip-permissions> <--disable-slash-commands> <--output-format> <stream-json> <--print=# CKTK delegated ticket implementation"
assert_json_field "$tmp/agy-default.json" status completed
assert_json_field "$tmp/agy-default.json" requested_model None
assert_json_field "$tmp/agy-default.json" requested_effort None
assert_json_field "$tmp/agy-default.json" model None
git -C "$repo" add agy-default-change.txt
git -C "$repo" commit -qm "reset after agy default fixture"
pass "agy uses a fixed template with optional model and effort"

# A non-SUCCESS result is a failure even though agy exited 0.
FAKE_AGENT_MODE=success \
FAKE_AGENT_EXIT_CODE=0 \
FAKE_AGENT_CHANGE_FILE="$repo/agy-error-change.txt" \
FAKE_AGENT_STDOUT_FILE="$tmp/agy-error-events.jsonl" \
  run_case agy-error 1 "$test_path" \
    --host claude \
    --executor agy \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/agy-error.json" \
    --timeout-seconds 5
assert_json_field "$tmp/agy-error.json" status failed
assert_json_field "$tmp/agy-error.json" agy_status ERROR
assert_json_field "$tmp/agy-error.json" agy_error "quota exhausted"
assert_contains "$tmp/agy-error.stderr" "agy finished with status ERROR"
assert_contains "$(json_field "$tmp/agy-error.json" final_message_file)" "quota exhausted"
git -C "$repo" add agy-error-change.txt
git -C "$repo" commit -qm "reset after agy error fixture"
pass "an agy error result is recorded as a failure"

# Antigravity cannot delegate to its own CLI, and overrides and oversized
# tasks fail before any package or process exists.
for invoking_agent in antigravity agy Antigravity; do
  run_case "agy-same-host-$invoking_agent" 3 "$test_path" \
    --host "$invoking_agent" \
    --executor agy \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/agy-same-host-$invoking_agent.json"
  assert_contains "$tmp/agy-same-host-$invoking_agent.stderr" \
    "executor 'agy' is the current host"
  assert_not_exists "$tmp/agy-same-host-$invoking_agent.fake.log"
done
CKTK_AGY_EFFORT=turbo \
  run_case agy-invalid-effort 2 "$test_path" \
    --host claude \
    --executor agy \
    --work-dir "$repo" \
    --task-file "$task_file" \
    --record-file "$tmp/agy-invalid-effort.json"
assert_contains "$tmp/agy-invalid-effort.stderr" "invalid CKTK_AGY_EFFORT: turbo"
assert_not_exists "$tmp/agy-invalid-effort.fake.log"
CKTK_AGY_MODEL=--sandbox \
  run_case agy-invalid-model 2 "$test_path" \
    --check \
    --host claude \
    --executor agy
assert_contains "$tmp/agy-invalid-model.stderr" "invalid CKTK_AGY_MODEL: --sandbox"
python3 -c 'import sys; sys.stdout.write("x" * 120001)' >"$tmp/agy-large-task.md"
run_case agy-large-task 2 "$test_path" \
  --host claude \
  --executor agy \
  --work-dir "$repo" \
  --task-file "$tmp/agy-large-task.md" \
  --record-file "$tmp/agy-large-task.json"
assert_contains "$tmp/agy-large-task.stderr" \
  "task file is 120001 bytes; agy accepts at most 120000"
assert_not_exists "$tmp/agy-large-task.task.md"
assert_not_exists "$tmp/agy-large-task.fake.log"
run_case check-agy 0 "$test_path" \
  --check \
  --host antigravity-ide \
  --executor agy
assert_contains "$tmp/check-agy.stdout" "Antigravity CLI is available for host antigravity-ide"
pass "agy host, override, and size limits are validated before launch"

printf '1..%d\n' "$tests"
