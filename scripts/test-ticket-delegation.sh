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
for executor_name in codex claude grok; do
  ln -s fake-agent "$fake_bin/$executor_name"
done

cat >"$task_file" <<EOF
Implement the ticket acceptance criteria.
Keep this literal: \$(touch "$tmp/INJECTED")
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

# A target failure is recorded and returned without retrying.
git -C "$repo" add grok-change.txt
git -C "$repo" commit -qm "reset after grok fixture"
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

printf '1..%d\n' "$tests"
