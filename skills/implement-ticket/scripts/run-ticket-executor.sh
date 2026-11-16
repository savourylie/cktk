#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  run-ticket-executor.sh \
    --host <invoking-agent-id> \
    --executor <codex|claude|grok|pi|agy> \
    --work-dir <absolute-dir> \
    --task-file <absolute-file> \
    --record-file <absolute-file> \
    [--timeout-seconds <positive-int>]

  run-ticket-executor.sh --check \
    --host <invoking-agent-id> \
    --executor <codex|claude|grok|pi|agy>

--check validates the executor, the host, any pi or agy overrides, and the
CLI discovery below, then exits 0 without packaging or launching anything.
The host `antigravity` is the same agent as the executor `agy`.

Environment (pi only; each defaults to Pi's own settings):
  CKTK_PI_MODEL     model pattern or ID passed to pi --model
  CKTK_PI_PROVIDER  provider passed to pi --provider; requires CKTK_PI_MODEL
  CKTK_PI_THINKING  off|minimal|low|medium|high|xhigh|max, passed to pi --thinking
  CKTK_PI_USAGE_DIR absolute directory outside the work directory for an
                    optional usage-only Pi-format JSONL export

A pi run also requires python3, which reads Pi's JSON event stream into the
record's provider, model, thinking_level, stop_reason, turn_count,
tool_call_count, tool_error_count, total_tokens, pi_usage_file,
pi_usage_error, final_message_file, transcript_file, and transcript_error.

Environment (agy only; each defaults to the Antigravity CLI's own settings):
  CKTK_AGY_MODEL    model ID passed to agy --model (see `agy models`); a
                    base ID such as gemini-3.8-flash combines with
                    CKTK_AGY_EFFORT, an ID with an effort suffix such as
                    claude-opus-5-5-high already fixes the effort
  CKTK_AGY_EFFORT   low|medium|high|xhigh|max, passed to agy --effort

agy reads its prompt only from the command line, so the task file must be at
most 120000 bytes. An agy run also requires python3, which reads agy's
stream-json events into the record's model, requested_model,
requested_effort, agy_status, agy_error, conversation_id, turn_count,
tool_call_count, tool_error_count, total_tokens, final_message_file,
transcript_file, and transcript_error.

Exit codes:
  0  executor completed and left reviewable changes (with --check: executor is usable)
  2  invalid arguments, including an agy task file over 120000 bytes
  3  unsupported executor or executor matches the invoking host
  4  executor CLI is not installed
  5  executor timed out
  6  executor completed without reviewable changes
  7  executor changed the pinned branch/HEAD or Git state could not be verified
EOF
}

die() {
  local exit_code="$1"
  shift
  printf 'ERROR: %s\n' "$*" >&2
  exit "$exit_code"
}

require_value() {
  local flag="$1"
  local count="$2"
  [[ "$count" -ge 2 ]] || die 2 "$flag requires a value"
}

json_string_or_null() {
  if [[ -n "$1" ]]; then
    printf '"%s"' "$(json_escape "$1")"
  else
    printf 'null'
  fi
}

json_int_or_null() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    printf '%s' "$1"
  else
    printf 'null'
  fi
}

json_escape() {
  local value="$1"
  local output=""
  local character
  local code
  local escaped
  local i
  local LC_ALL=C

  for ((i = 0; i < ${#value}; i++)); do
    character="${value:i:1}"
    case "$character" in
      '"') output+='\"' ;;
      \\) output+='\\' ;;
      $'\b') output+='\b' ;;
      $'\f') output+='\f' ;;
      $'\n') output+='\n' ;;
      $'\r') output+='\r' ;;
      $'\t') output+='\t' ;;
      *)
        printf -v code '%d' "'$character"
        if [[ "$code" -lt 32 ]]; then
          printf -v escaped '\\u%04x' "$code"
          output+="$escaped"
        else
          output+="$character"
        fi
        ;;
    esac
  done

  printf '%s' "$output"
}

host=""
executor=""
work_dir=""
task_file=""
record_file=""
timeout_seconds=1800
timeout_given=false
check_only=false

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --host)
      require_value "$1" "$#"
      host="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
      shift 2
      ;;
    --executor)
      require_value "$1" "$#"
      executor="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
      shift 2
      ;;
    --work-dir)
      require_value "$1" "$#"
      work_dir="$2"
      shift 2
      ;;
    --task-file)
      require_value "$1" "$#"
      task_file="$2"
      shift 2
      ;;
    --record-file)
      require_value "$1" "$#"
      record_file="$2"
      shift 2
      ;;
    --timeout-seconds)
      require_value "$1" "$#"
      timeout_seconds="$2"
      timeout_given=true
      shift 2
      ;;
    --check)
      check_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die 2 "unknown argument: $1"
      ;;
  esac
done

[[ -n "$host" ]] || die 2 "--host is required"
[[ -n "$executor" ]] || die 2 "--executor is required"
if [[ "$check_only" = true ]]; then
  [[ -z "$work_dir$task_file$record_file" && "$timeout_given" = false ]] ||
    die 2 "--check takes only --host and --executor"
else
  [[ -n "$work_dir" ]] || die 2 "--work-dir is required"
  [[ -n "$task_file" ]] || die 2 "--task-file is required"
  [[ -n "$record_file" ]] || die 2 "--record-file is required"
fi
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] ||
  die 2 "timeout seconds must be a positive integer"

[[ "$host" =~ ^[a-z][a-z0-9-]*$ ]] || die 2 "invalid host identifier: $host"

case "$executor" in
  codex|claude|grok|pi|agy) ;;
  *) die 3 "unsupported executor: $executor" ;;
esac

# Antigravity is both a host label and, through its CLI, the agy executor.
host_as_executor="$host"
if [[ "$host" = "antigravity" ]]; then
  host_as_executor="agy"
fi
if [[ "$executor" = "$host_as_executor" ]]; then
  die 3 "executor '$executor' is the current host; omit via to use native implementation"
fi

pi_model="${CKTK_PI_MODEL:-}"
pi_provider="${CKTK_PI_PROVIDER:-}"
pi_thinking="${CKTK_PI_THINKING:-}"
pi_usage_dir="${CKTK_PI_USAGE_DIR:-}"
if [[ "$executor" = "pi" ]]; then
  # These values become single argv entries, never shell text. The character
  # allowlists still keep them from being read as additional pi options.
  if [[ -n "$pi_model" ]]; then
    [[ "$pi_model" =~ ^[A-Za-z0-9][A-Za-z0-9._:/@+-]*$ ]] ||
      die 2 "invalid CKTK_PI_MODEL: $pi_model"
  fi
  if [[ -n "$pi_provider" ]]; then
    [[ "$pi_provider" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
      die 2 "invalid CKTK_PI_PROVIDER: $pi_provider"
    [[ -n "$pi_model" ]] ||
      die 2 "CKTK_PI_PROVIDER requires CKTK_PI_MODEL"
  fi
  case "$pi_thinking" in
    ''|off|minimal|low|medium|high|xhigh|max) ;;
    *) die 2 "invalid CKTK_PI_THINKING: $pi_thinking" ;;
  esac
  if [[ -n "$pi_usage_dir" ]]; then
    case "$pi_usage_dir" in
      /*) ;;
      *) die 2 "CKTK_PI_USAGE_DIR must be an absolute path: $pi_usage_dir" ;;
    esac
  fi
fi

agy_model="${CKTK_AGY_MODEL:-}"
agy_effort="${CKTK_AGY_EFFORT:-}"
if [[ "$executor" = "agy" ]]; then
  # Single argv entries, never shell text; the allowlist keeps a value from
  # being read as another agy option. agy itself rejects an unknown model or
  # a model whose effort suffix conflicts with CKTK_AGY_EFFORT.
  if [[ -n "$agy_model" ]]; then
    [[ "$agy_model" =~ ^[A-Za-z0-9][A-Za-z0-9._:/@+-]*$ ]] ||
      die 2 "invalid CKTK_AGY_MODEL: $agy_model"
  fi
  case "$agy_effort" in
    ''|low|medium|high|xhigh|max) ;;
    *) die 2 "invalid CKTK_AGY_EFFORT: $agy_effort" ;;
  esac
fi

cli_label=""
case "$executor" in
  codex) cli_label="Codex CLI" ;;
  claude) cli_label="Claude Code CLI" ;;
  grok) cli_label="Grok Build CLI" ;;
  pi) cli_label="Pi coding agent CLI" ;;
  agy) cli_label="Antigravity CLI" ;;
esac

executor_path=""
discover_executor() {
  executor_path="$(command -v "$executor" 2>/dev/null || true)"
  [[ -n "$executor_path" ]] ||
    die 4 "$cli_label is not installed (expected command: $executor)"
  if ! "$executor_path" --version >/dev/null 2>&1; then
    die 4 "$cli_label failed its version check"
  fi
  if [[ "$executor" = "pi" || "$executor" = "agy" ]]; then
    command -v python3 >/dev/null 2>&1 ||
      die 4 "python3 is required to read $cli_label output"
  fi
}

if [[ "$check_only" = true ]]; then
  discover_executor
  printf '%s is available for host %s: %s\n' "$cli_label" "$host" "$executor_path"
  exit 0
fi

case "$work_dir" in
  /*) ;;
  *) die 2 "work directory must be an absolute path: $work_dir" ;;
esac
case "$task_file" in
  /*) ;;
  *) die 2 "task file must be an absolute path: $task_file" ;;
esac
case "$record_file" in
  /*) ;;
  *) die 2 "record file must be an absolute path: $record_file" ;;
esac

[[ -d "$work_dir" ]] ||
  die 2 "work directory does not exist: $work_dir"
work_dir="$(cd "$work_dir" && pwd -P)"

[[ -f "$task_file" && -r "$task_file" ]] ||
  die 2 "task file is not a readable file: $task_file"
task_file_dir="$(cd "$(dirname "$task_file")" && pwd -P)"
task_file="$task_file_dir/$(basename "$task_file")"

repo_root="$(git -C "$work_dir" rev-parse --show-toplevel 2>/dev/null)" ||
  die 2 "work directory is not inside a git worktree: $work_dir"
repo_root="$(cd "$repo_root" && pwd -P)"
[[ "$repo_root" = "$work_dir" ]] ||
  die 2 "work directory must be the root of the pinned git worktree: $work_dir"

discover_executor

# agy takes its prompt only as a --print argument. Refuse a task that would
# not fit one argv entry on every supported platform (Linux caps a single
# argument at 128 KiB) before creating any package or process.
agy_task_limit=120000
if [[ "$executor" = "agy" ]]; then
  task_file_bytes="$(wc -c <"$task_file" | tr -d '[:space:]')"
  [[ "$task_file_bytes" -le "$agy_task_limit" ]] ||
    die 2 "task file is $task_file_bytes bytes; agy accepts at most $agy_task_limit"
fi

# No task package, output capture, or process is created before CLI discovery.
record_dir="$(dirname "$record_file")"
mkdir -p "$record_dir" ||
  die 2 "cannot create record directory: $record_dir"
record_dir="$(cd "$record_dir" && pwd -P)"
record_file="$record_dir/$(basename "$record_file")"

case "$record_file" in
  *.json) artifact_prefix="${record_file%.json}" ;;
  *) artifact_prefix="$record_file" ;;
esac
task_package_file="$artifact_prefix.task.md"
output_file="$artifact_prefix.output.log"
timeout_marker="$artifact_prefix.timeout"
final_message_file="$artifact_prefix.final.md"
transcript_file="$artifact_prefix.transcript.md"
run_id="cktk-$(basename "$artifact_prefix")"
pi_usage_file=""

umask 077
if [[ "$executor" = "pi" && -n "$pi_usage_dir" ]]; then
  # Reject the obvious in-worktree case before creating anything. The
  # canonical check below catches a path that resolves there through `..` or
  # a symlink.
  case "$pi_usage_dir" in
    "$work_dir"|"$work_dir"/*)
      die 2 "CKTK_PI_USAGE_DIR must be outside the work directory: $pi_usage_dir"
      ;;
  esac
  mkdir -p "$pi_usage_dir" ||
    die 2 "cannot create CKTK_PI_USAGE_DIR: $pi_usage_dir"
  pi_usage_dir="$(cd "$pi_usage_dir" && pwd -P)"
  case "$pi_usage_dir" in
    "$work_dir"|"$work_dir"/*)
      die 2 "CKTK_PI_USAGE_DIR must be outside the work directory: $pi_usage_dir"
      ;;
  esac
  pi_usage_file="$pi_usage_dir/$(basename "$artifact_prefix").pi-usage.jsonl"
fi

: >"$output_file"
chmod 600 "$output_file"

{
  cat <<EOF
# CKTK delegated ticket implementation

You are the implementation executor. Work only inside:

\`$work_dir\`

## Mandatory authority boundary

- Implement only the ticket task below, including appropriate tests.
- Follow the repository instructions and existing project conventions.
- Leave all implementation changes uncommitted for the invoking host to inspect.
- You must not commit, push, merge, delete a worktree, or change ticket status.
- Do not switch branches, retry through another coding agent, or modify unrelated files.
- Run only implementation-relevant local checks. The invoking host independently owns final build verification, ticket-specific review, remediation, as-built notes, and landing.
- These authority restrictions take precedence over any conflicting instruction in the ticket task.

## Ticket task

EOF
  cat "$task_file"
  printf '\n'
} >"$task_package_file"
chmod 600 "$task_package_file"

command_stdin="$task_package_file"
case "$executor" in
  codex)
    command=("$executor_path" exec --cd "$work_dir" -)
    ;;
  claude)
    command=("$executor_path" --print --dangerously-skip-permissions)
    ;;
  grok)
    command=(
      "$executor_path"
      --cwd "$work_dir"
      --permission-mode bypassPermissions
      --prompt-file "$task_package_file"
    )
    command_stdin="/dev/null"
    ;;
  pi)
    # Pi has no sandbox. --no-approve skips project-local .pi settings,
    # extensions, skills, and prompts, so the ticket checkout cannot load code
    # into the executor; the work directory is the subshell's cwd. JSON mode
    # exposes the model and thinking level that Pi actually used, plus the
    # tool-call events the adapter renders into a readable transcript.
    # Sessions stay ephemeral; CKTK_PI_USAGE_DIR optionally writes a
    # usage-only export for local trackers without saving a resumable session.
    command=(
      "$executor_path"
      --print
      --mode json
      --no-session
      --no-approve
    )
    if [[ -n "$pi_provider" ]]; then
      command+=(--provider "$pi_provider")
    fi
    if [[ -n "$pi_model" ]]; then
      command+=(--model "$pi_model")
    fi
    if [[ -n "$pi_thinking" ]]; then
      command+=(--thinking "$pi_thinking")
    fi
    ;;
  agy)
    # agy reads no prompt from stdin, so the package travels as one attached
    # --print= argument (the detached form would swallow the next flag).
    # Slash-command and skill expansion stay off so ticket text such as
    # "/implement-ticket" cannot start another workflow. stream-json exposes
    # the model agy resolved and each tool step for the transcript.
    command=(
      "$executor_path"
      --dangerously-skip-permissions
      --disable-slash-commands
      --output-format stream-json
    )
    if [[ -n "$agy_model" ]]; then
      command+=(--model "$agy_model")
    fi
    if [[ -n "$agy_effort" ]]; then
      command+=(--effort "$agy_effort")
    fi
    command+=("--print=$(cat "$task_package_file")")
    command_stdin="/dev/null"
    ;;
esac

before_head="$(git -C "$work_dir" rev-parse HEAD)"
before_ref="$(git -C "$work_dir" symbolic-ref -q HEAD || true)"

status_pathspecs=(.)
for artifact_path in \
  "$task_file" \
  "$record_file" \
  "$task_package_file" \
  "$output_file" \
  "$final_message_file" \
  "$transcript_file"; do
  case "$artifact_path" in
    "$work_dir"/*)
      relative_artifact="${artifact_path#"$work_dir"/}"
      status_pathspecs+=(":(exclude,literal)$relative_artifact")
      ;;
  esac
done

reviewable_fingerprint() {
  {
    printf 'INDEX\0'
    git -C "$work_dir" diff \
      --binary \
      --no-ext-diff \
      --cached \
      "$before_head" \
      -- \
      "${status_pathspecs[@]}"
    printf '\0WORKTREE\0'
    git -C "$work_dir" diff \
      --binary \
      --no-ext-diff \
      -- \
      "${status_pathspecs[@]}"
    printf '\0UNTRACKED\0'
    while IFS= read -r -d '' untracked_path; do
      absolute_untracked="$work_dir/$untracked_path"
      printf 'PATH\0%s\0' "$untracked_path"
      if [[ -L "$absolute_untracked" ]]; then
        printf 'SYMLINK\0%s\0' "$(readlink "$absolute_untracked")"
      elif [[ -f "$absolute_untracked" ]]; then
        if [[ -x "$absolute_untracked" ]]; then
          printf 'MODE\0%s\0' 100755
        else
          printf 'MODE\0%s\0' 100644
        fi
        git hash-object --no-filters -- "$absolute_untracked"
      else
        printf 'OTHER\0'
      fi
    done < <(
      git -C "$work_dir" ls-files \
        --others \
        --exclude-standard \
        -z \
        -- \
        "${status_pathspecs[@]}"
    )
  } | git hash-object --stdin
}

if ! before_fingerprint="$(reviewable_fingerprint)"; then
  die 2 "cannot inspect the worktree before executor launch"
fi

started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
child_pid=""
watchdog_pid=""

terminate_child() {
  if [[ -n "$watchdog_pid" ]]; then
    kill "$watchdog_pid" 2>/dev/null || true
  fi
  if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill -TERM -- "-$child_pid" 2>/dev/null ||
      kill -TERM "$child_pid" 2>/dev/null ||
      true
  fi
}
trap 'terminate_child' EXIT
trap 'terminate_child; exit 130' HUP INT TERM

rm -f "$timeout_marker" "$final_message_file" "$transcript_file" "$transcript_file.tmp"
if [[ -n "$pi_usage_file" ]]; then
  rm -f "$pi_usage_file" "$pi_usage_file.tmp"
fi

# Job control gives the executor its own process group in non-interactive Bash.
# The watchdog can then terminate the CLI and any child it spawned without
# signalling this adapter or unrelated processes.
set -m
(
  cd "$work_dir"
  exec "${command[@]}"
) <"$command_stdin" >"$output_file" 2>&1 &
child_pid=$!
set +m

(
  sleep "$timeout_seconds"
  if kill -0 "$child_pid" 2>/dev/null; then
    : >"$timeout_marker"
    kill -TERM -- "-$child_pid" 2>/dev/null ||
      kill -TERM "$child_pid" 2>/dev/null ||
      true
    sleep 2
    if kill -0 "$child_pid" 2>/dev/null; then
      kill -KILL -- "-$child_pid" 2>/dev/null ||
        kill -KILL "$child_pid" 2>/dev/null ||
        true
    fi
  fi
) &
watchdog_pid=$!

set +e
wait "$child_pid"
target_exit=$?
set -e
child_pid=""

if [[ ! -e "$timeout_marker" ]]; then
  kill "$watchdog_pid" 2>/dev/null || true
fi
set +e
wait "$watchdog_pid" 2>/dev/null
set -e
watchdog_pid=""

status=""
adapter_exit=0
timed_out=false

if [[ -e "$timeout_marker" ]]; then
  timed_out=true
  target_exit=5
  rm -f "$timeout_marker"
fi

pi_used_provider=""
pi_used_model=""
pi_used_thinking=""
pi_stop_reason=""
pi_transcript_written=""
pi_transcript_error=""
pi_turn_count=""
pi_tool_call_count=""
pi_tool_error_count=""
pi_total_tokens=""
pi_usage_file_written=""
pi_usage_error=""
if [[ "$executor" = "pi" ]]; then
  # The last assistant message names the provider, model, and thinking level
  # that answered, and the same pass renders a readable run transcript with
  # per-turn tool calls. When CKTK_PI_USAGE_DIR is set, it also writes a
  # usage-only Pi-format JSONL there. These diagnostics are best effort:
  # unparseable output leaves them null and does not change the Git
  # classification below.
  pi_parser_file=""
  if ! pi_parser_file="$(mktemp "$record_dir/.pi-usage-parser.XXXXXX")"; then
    pi_parser_file=""
  fi
  if [[ -n "$pi_parser_file" ]]; then
    cat >"$pi_parser_file" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

(
    output_path,
    final_path,
    transcript_path,
    usage_path,
    run_id,
    started_at,
    work_dir,
) = sys.argv[1:8]

last = None
usages = []
timeline = []
open_tool_calls = {}
turns = 0
tool_calls = 0
tool_errors = 0
with open(output_path, encoding="utf-8", errors="replace") as handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except ValueError:
            # Stderr shares the capture, so a non-JSON line is usually a Pi
            # warning; keep it visible in the transcript.
            timeline.append(("raw", line.strip()))
            continue
        if not isinstance(event, dict):
            continue
        event_type = event.get("type")
        if event_type == "turn_start":
            turns += 1
            timeline.append(("turn", turns))
        elif event_type == "message_end":
            message = event.get("message")
            if not isinstance(message, dict) or message.get("role") != "assistant":
                continue
            last = message
            if isinstance(message.get("usage"), dict):
                usages.append((message, event.get("timestamp")))
            for part in message.get("content") or []:
                if not isinstance(part, dict):
                    continue
                if part.get("type") == "text" and str(part.get("text", "")).strip():
                    timeline.append(("text", part["text"]))
                elif part.get("type") == "thinking" and str(
                    part.get("thinking", "")
                ).strip():
                    timeline.append(("thinking", part["thinking"]))
        elif event_type == "tool_execution_start":
            tool_calls += 1
            call = {
                "name": event.get("toolName"),
                "args": event.get("args"),
                "end": None,
            }
            call_id = event.get("toolCallId")
            if isinstance(call_id, str) and call_id:
                open_tool_calls[call_id] = call
            timeline.append(("tool", call))
        elif event_type == "tool_execution_end":
            if event.get("isError"):
                tool_errors += 1
            call_id = event.get("toolCallId")
            call = (
                open_tool_calls.pop(call_id, None)
                if isinstance(call_id, str)
                else None
            )
            if call is None:
                call = {"name": event.get("toolName"), "args": None, "end": None}
                timeline.append(("tool", call))
            call["end"] = event

if last is None:
    sys.exit(0)

text = "\n".join(
    part.get("text", "")
    for part in last.get("content") or []
    if isinstance(part, dict) and part.get("type") == "text"
)
if last.get("errorMessage"):
    text = (text + "\n\n" if text else "") + str(last["errorMessage"])
with open(final_path, "w", encoding="utf-8") as handle:
    handle.write(text.rstrip("\n") + "\n")

# Printed before the optional exports run: a failure while building the
# transcript or the usage file must not cost the record the classification
# metadata that drives stop_reason handling.
for key in ("provider", "model", "thinkingLevel", "stopReason"):
    value = last.get(key)
    print("" if value is None else " ".join(str(value).split()))


def field(value):
    return "" if value is None else " ".join(str(value).split())


def compact(value, limit):
    if not isinstance(value, str):
        try:
            value = json.dumps(
                value, ensure_ascii=False, separators=(",", ":"), default=str
            )
        except (TypeError, ValueError):
            value = str(value)
    value = value.strip()
    if len(value) > limit:
        value = value[:limit].rstrip() + " …[truncated]"
    return value


def oneline(value, limit):
    return compact(" ".join(str(value).split()), limit)


def result_text(result):
    if isinstance(result, dict):
        parts = [
            part["text"]
            for part in result.get("content") or []
            if isinstance(part, dict) and isinstance(part.get("text"), str)
        ]
        text_value = "\n".join(parts).strip()
        if not text_value and result.get("details") is not None:
            text_value = compact(result.get("details"), 800)
        return text_value
    return compact(result, 800)


transcript_written = ""
transcript_error = ""
turn_count = tool_call_count = tool_error_count = total_tokens = ""
# Broad catch: like the usage export, the transcript is best effort and must
# degrade to transcript_error, never kill the parser before the usage export.
try:
    total = 0
    for message, _event_timestamp in usages:
        usage = message.get("usage")
        if not isinstance(usage, dict):
            continue
        value = usage.get("totalTokens")
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            value = sum(
                max(0, int(usage.get(key)))
                for key in ("input", "output", "cacheRead", "cacheWrite")
                if not isinstance(usage.get(key), bool)
                and isinstance(usage.get(key), (int, float))
            )
        total += max(0, int(value))

    model_label = "/".join(
        part
        for part in (field(last.get("provider")), field(last.get("model")))
        if part
    )
    lines = [
        f"# Pi delegation transcript: {run_id}",
        "",
        f"- started: {started_at}",
        f"- work dir: {work_dir}",
        f"- last response: {model_label or 'unknown model'}"
        f" · thinking: {field(last.get('thinkingLevel')) or 'unknown'}"
        f" · stop reason: {field(last.get('stopReason')) or 'unknown'}",
        f"- turns: {turns} · tool calls: {tool_calls}"
        f" ({tool_errors} failed) · assistant tokens: {total} total",
    ]
    for item in timeline:
        kind = item[0]
        if kind == "turn":
            lines += ["", f"## Turn {item[1]}", ""]
        elif kind == "text":
            lines += ["**assistant:**", "", str(item[1]).strip(), ""]
        elif kind == "thinking":
            lines += [f"> thinking (truncated): {oneline(item[1], 400)}", ""]
        elif kind == "raw":
            lines += [f"`[non-JSON output]` {oneline(item[1], 300)}", ""]
        elif kind == "tool":
            call = item[1]
            name = str(call.get("name") or "unknown")
            args = compact(call["args"], 300) if call.get("args") is not None else ""
            end = call.get("end")
            if end is None:
                lines += [
                    f"- tool `{name}` {args} → no result recorded;"
                    " the run ended during this call",
                    "",
                ]
                continue
            duration = end.get("durationMs")
            duration_label = (
                f" in {duration}ms"
                if isinstance(duration, (int, float))
                and not isinstance(duration, bool)
                else ""
            )
            if end.get("isError"):
                lines.append(f"- tool `{name}` {args} → **error**{duration_label}")
                excerpt = compact(result_text(end.get("result")), 800)
                if excerpt:
                    lines.append("")
                    lines.append("  ```")
                    lines += [f"  {part}" for part in excerpt.splitlines()]
                    lines.append("  ```")
            else:
                summary = oneline(result_text(end.get("result")), 200)
                summary = f": {summary}" if summary else ""
                lines.append(f"- tool `{name}` {args} → ok{duration_label}{summary}")
            lines.append("")
    if last.get("errorMessage"):
        lines += [f"**error:** {str(last['errorMessage']).strip()}", ""]

    body = "\n".join(lines).rstrip("\n") + "\n"
    if len(body) > 2_000_000:
        body = (
            body[:2_000_000].rstrip("\n")
            + "\n\n[transcript truncated at 2 MB; the raw event stream"
            " continues in the output log]\n"
        )
    temp_path = transcript_path + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as handle:
        handle.write(body)
    os.chmod(temp_path, 0o600)
    os.replace(temp_path, transcript_path)
    transcript_written = transcript_path
    turn_count = str(turns)
    tool_call_count = str(tool_calls)
    tool_error_count = str(tool_errors)
    total_tokens = str(total)
except Exception as error:
    transcript_written = ""
    turn_count = tool_call_count = tool_error_count = total_tokens = ""
    transcript_error = " ".join(str(error).split()) or type(error).__name__
    try:
        os.unlink(transcript_path + ".tmp")
    except OSError:
        pass

print(transcript_written)
print(transcript_error)
print(turn_count)
print(tool_call_count)
print(tool_error_count)
print(total_tokens)


def iso_timestamp(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return (
            datetime.fromtimestamp(value / 1000, tz=timezone.utc)
            .isoformat(timespec="milliseconds")
            .replace("+00:00", "Z")
        )
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


usage_written = ""
usage_error = ""
if usage_path:
    # Broad catch: the export is best effort, and a failure while building
    # records (for example a corrupt numeric timestamp overflowing
    # datetime) must degrade to pi_usage_error like a write failure, not
    # kill the parser.
    try:
        header_timestamp = started_at or (
            datetime.now(timezone.utc)
            .isoformat(timespec="milliseconds")
            .replace("+00:00", "Z")
        )
        header_id = run_id or "cktk"
        records = []
        for index, (message, event_timestamp) in enumerate(usages):
            model = message.get("model")
            if not isinstance(model, str) or not model.strip():
                continue
            usage = message.get("usage")
            if not isinstance(usage, dict):
                continue
            tokens = {}
            for key in ("input", "output", "cacheRead", "cacheWrite"):
                value = usage.get(key)
                if isinstance(value, bool) or not isinstance(value, (int, float)):
                    value = 0
                tokens[key] = max(0, int(value))
            # TokenBar's Pi parser ignores non-assistant usage and counts a
            # message only when it carries a model; keep the export to the
            # same shape as a real Pi session.
            if sum(tokens.values()) == 0:
                continue
            total = usage.get("totalTokens")
            if isinstance(total, bool) or not isinstance(total, (int, float)):
                total = sum(tokens.values())
            provider = message.get("provider")
            response_id = message.get("responseId")
            record = {
                "type": "message",
                "id": (
                    response_id
                    if isinstance(response_id, str) and response_id.strip()
                    else f"{header_id}-{index}"
                ),
                "timestamp": iso_timestamp(message.get("timestamp"))
                or iso_timestamp(event_timestamp)
                or header_timestamp,
                "message": {
                    "role": "assistant",
                    "model": model,
                    "usage": {**tokens, "totalTokens": max(0, int(total))},
                },
            }
            if isinstance(provider, str) and provider.strip():
                record["message"]["provider"] = provider
            if isinstance(response_id, str) and response_id.strip():
                record["message"]["responseId"] = response_id
            records.append(record)

        if records:
            os.makedirs(os.path.dirname(usage_path), mode=0o700, exist_ok=True)
            temp_path = usage_path + ".tmp"
            with open(temp_path, "w", encoding="utf-8") as handle:
                handle.write(
                    json.dumps(
                        {
                            "type": "session",
                            "version": 3,
                            "id": header_id,
                            "timestamp": header_timestamp,
                            "cwd": work_dir,
                        },
                        ensure_ascii=False,
                        separators=(",", ":"),
                    )
                    + "\n"
                )
                for record in records:
                    handle.write(
                        json.dumps(
                            record,
                            ensure_ascii=False,
                            separators=(",", ":"),
                        )
                        + "\n"
                    )
            os.chmod(temp_path, 0o600)
            os.replace(temp_path, usage_path)
            usage_written = usage_path
    except Exception as error:
        usage_written = ""
        usage_error = " ".join(str(error).split()) or type(error).__name__
        try:
            os.unlink(usage_path + ".tmp")
        except OSError:
            pass

print(usage_written)
print(usage_error)
PY
  fi
  pi_metadata=()
  if [[ -n "$pi_parser_file" ]]; then
    while IFS= read -r line; do
      pi_metadata+=("$line")
    done < <(
      python3 -I "$pi_parser_file" \
        "$output_file" \
        "$final_message_file" \
        "$transcript_file" \
        "$pi_usage_file" \
        "$run_id" \
        "$started_at" \
        "$work_dir" 2>/dev/null || true
    )
    rm -f "$pi_parser_file"
  fi
  pi_used_provider="${pi_metadata[0]:-}"
  pi_used_model="${pi_metadata[1]:-}"
  pi_used_thinking="${pi_metadata[2]:-}"
  pi_stop_reason="${pi_metadata[3]:-}"
  pi_transcript_written="${pi_metadata[4]:-}"
  pi_transcript_error="${pi_metadata[5]:-}"
  pi_turn_count="${pi_metadata[6]:-}"
  pi_tool_call_count="${pi_metadata[7]:-}"
  pi_tool_error_count="${pi_metadata[8]:-}"
  pi_total_tokens="${pi_metadata[9]:-}"
  pi_usage_file_written="${pi_metadata[10]:-}"
  pi_usage_error="${pi_metadata[11]:-}"
  if [[ -n "$pi_transcript_written" ]]; then
    if [[ -s "$pi_transcript_written" ]]; then
      chmod 600 "$pi_transcript_written" 2>/dev/null || true
    else
      pi_transcript_written=""
      [[ -n "$pi_transcript_error" ]] ||
        pi_transcript_error="transcript was not written"
    fi
  fi
  if [[ -n "$pi_usage_file_written" ]]; then
    if [[ -s "$pi_usage_file_written" ]]; then
      chmod 600 "$pi_usage_file_written" 2>/dev/null || true
    else
      pi_usage_file_written=""
      pi_usage_error="usage export was not written"
    fi
  fi
  if [[ -f "$final_message_file" ]]; then
    chmod 600 "$final_message_file"
  fi
  if [[ -n "$pi_transcript_error" ]]; then
    printf 'WARNING: Pi transcript export failed: %s\n' "$pi_transcript_error" >&2
  fi
  if [[ -n "$pi_usage_error" ]]; then
    printf 'WARNING: Pi usage export failed: %s\n' "$pi_usage_error" >&2
  fi
fi

agy_used_model=""
agy_status=""
agy_error=""
agy_conversation_id=""
agy_transcript_written=""
agy_transcript_error=""
agy_turn_count=""
agy_tool_call_count=""
agy_tool_error_count=""
agy_total_tokens=""
if [[ "$executor" = "agy" ]]; then
  # agy's stream-json names the resolved model in its init event, reports
  # every tool step as step_update events, and ends with one result event.
  # The same pass writes the final response and a readable transcript. All
  # of it is best effort: unparseable output leaves the fields null and does
  # not change the Git classification below.
  agy_parser_file=""
  if ! agy_parser_file="$(mktemp "$record_dir/.agy-parser.XXXXXX")"; then
    agy_parser_file=""
  fi
  if [[ -n "$agy_parser_file" ]]; then
    cat >"$agy_parser_file" <<'PY'
import json
import os
import sys

(
    output_path,
    final_path,
    transcript_path,
    run_id,
    started_at,
    work_dir,
    requested_model,
    requested_effort,
) = sys.argv[1:9]

init = {}
result = None
steps = {}
order = []
raw_lines = []
cli_error = ""
with open(output_path, encoding="utf-8", errors="replace") as handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except ValueError:
            # Stderr shares the capture: keep agy's own error lines visible.
            text = line.strip()
            raw_lines.append(text)
            if text.startswith("error:"):
                cli_error = text[len("error:"):].strip()
            continue
        if not isinstance(event, dict):
            continue
        kind = event.get("event")
        if kind == "init" and isinstance(event.get("init"), dict):
            init = event["init"]
        elif kind == "result" and isinstance(event.get("result"), dict):
            result = event["result"]
        elif kind == "step_update" and isinstance(event.get("step_update"), dict):
            update = event["step_update"]
            index = update.get("step_index")
            if index not in steps:
                steps[index] = {"type": update.get("step_type"), "text": ""}
                order.append(index)
            step = steps[index]
            step["state"] = update.get("state")
            if update.get("tool_name"):
                step["tool"] = update["tool_name"]
            info = update.get("tool_info")
            if isinstance(info, dict) and info.get("parameters") is not None:
                step["args"] = info["parameters"]
            if isinstance(update.get("text_delta"), str):
                step["text"] += update["text_delta"]
            if update.get("error"):
                step["error"] = update["error"]
            if isinstance(update.get("duration_seconds"), (int, float)):
                step["duration"] = update["duration_seconds"]


def field(value):
    return "" if value is None else " ".join(str(value).split())


def compact(value, limit):
    if not isinstance(value, str):
        try:
            value = json.dumps(value, ensure_ascii=False, separators=(",", ":"), default=str)
        except (TypeError, ValueError):
            value = str(value)
    value = " ".join(value.split())
    return value if len(value) <= limit else value[:limit].rstrip() + " …[truncated]"


result = result or {}
error = field(result.get("error")) or cli_error
response = result.get("response") if isinstance(result.get("response"), str) else ""
if response or error:
    text = response.rstrip("\n")
    if error:
        text = (text + "\n\n" if text else "") + error
    with open(final_path, "w", encoding="utf-8") as handle:
        handle.write(text + "\n")

tool_steps = [steps[i] for i in order if steps[i].get("type") == "tool"]
tool_errors = [
    s for s in tool_steps
    if s.get("error") or field(s.get("state")) not in ("DONE", "ACTIVE", "PENDING", "")
]
usage = result.get("usage") if isinstance(result.get("usage"), dict) else {}
total = usage.get("total_tokens")
turns = result.get("num_turns")

# Classification metadata first, so a transcript failure cannot cost it.
print(field(init.get("model")))
print(field(result.get("status")))
print(error)
print(field(result.get("conversation_id") or ""))
print(turns if isinstance(turns, int) and not isinstance(turns, bool) else "")
print(len(tool_steps) if init or result else "")
print(len(tool_errors) if init or result else "")
print(total if isinstance(total, int) and not isinstance(total, bool) else "")

transcript_written = ""
transcript_error = ""
try:
    lines = [
        f"# agy delegation transcript: {run_id}",
        "",
        f"- started: {started_at}",
        f"- work dir: {work_dir}",
        f"- model: {field(init.get('model')) or 'unknown'}"
        f" (requested: {requested_model or 'default'}, effort: {requested_effort or 'default'})",
        f"- status: {field(result.get('status')) or 'no result'}"
        f" · conversation: {field(result.get('conversation_id')) or 'unknown'}",
        f"- tool calls: {len(tool_steps)} ({len(tool_errors)} failed)"
        f" · total tokens: {total if total is not None else 'unknown'}",
        "",
    ]
    for line in raw_lines:
        lines += [f"`[non-JSON output]` {compact(line, 300)}", ""]
    for index in order:
        step = steps[index]
        kind = step.get("type")
        if kind == "agent_response" and step["text"].strip():
            lines += ["**assistant:**", "", step["text"].strip(), ""]
        elif kind == "tool":
            name = step.get("tool") or "unknown"
            args = compact(step["args"], 300) if step.get("args") is not None else ""
            state = field(step.get("state")) or "unknown"
            duration = f" in {step['duration']:.1f}s" if "duration" in step else ""
            if state == "ACTIVE":
                outcome = "no result recorded; the run ended during this call"
            elif step in tool_errors:
                outcome = f"**{state.lower()}**{duration}"
            else:
                outcome = f"ok{duration}"
            lines.append(f"- tool `{name}` {args} → {outcome}")
            if step.get("error"):
                lines.append(f"  error: {compact(step['error'], 800)}")
            lines.append("")
    if error:
        lines += [f"**error:** {error}", ""]
    body = "\n".join(lines).rstrip("\n") + "\n"
    if len(body) > 2_000_000:
        body = body[:2_000_000].rstrip("\n") + (
            "\n\n[transcript truncated at 2 MB; the raw event stream"
            " continues in the output log]\n"
        )
    temp_path = transcript_path + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as handle:
        handle.write(body)
    os.chmod(temp_path, 0o600)
    os.replace(temp_path, transcript_path)
    transcript_written = transcript_path
except Exception as error_value:
    transcript_error = " ".join(str(error_value).split()) or type(error_value).__name__
    try:
        os.unlink(transcript_path + ".tmp")
    except OSError:
        pass

print(transcript_written)
print(transcript_error)
PY
  fi
  agy_metadata=()
  if [[ -n "$agy_parser_file" ]]; then
    while IFS= read -r line; do
      agy_metadata+=("$line")
    done < <(
      python3 -I "$agy_parser_file" \
        "$output_file" \
        "$final_message_file" \
        "$transcript_file" \
        "$run_id" \
        "$started_at" \
        "$work_dir" \
        "$agy_model" \
        "$agy_effort" 2>/dev/null || true
    )
    rm -f "$agy_parser_file"
  fi
  agy_used_model="${agy_metadata[0]:-}"
  agy_status="${agy_metadata[1]:-}"
  agy_error="${agy_metadata[2]:-}"
  agy_conversation_id="${agy_metadata[3]:-}"
  agy_turn_count="${agy_metadata[4]:-}"
  agy_tool_call_count="${agy_metadata[5]:-}"
  agy_tool_error_count="${agy_metadata[6]:-}"
  agy_total_tokens="${agy_metadata[7]:-}"
  agy_transcript_written="${agy_metadata[8]:-}"
  agy_transcript_error="${agy_metadata[9]:-}"
  if [[ -n "$agy_transcript_written" && ! -s "$agy_transcript_written" ]]; then
    agy_transcript_written=""
    [[ -n "$agy_transcript_error" ]] ||
      agy_transcript_error="transcript was not written"
  fi
  if [[ -z "$agy_transcript_written" && -z "$agy_transcript_error" ]]; then
    agy_transcript_error="agy output could not be read"
  fi
  if [[ -f "$final_message_file" ]]; then
    chmod 600 "$final_message_file"
  fi
  if [[ -n "$agy_transcript_error" ]]; then
    printf 'WARNING: agy transcript export failed: %s\n' "$agy_transcript_error" >&2
  fi
fi

after_head="$(git -C "$work_dir" rev-parse HEAD 2>/dev/null || true)"
after_ref="$(git -C "$work_dir" symbolic-ref -q HEAD 2>/dev/null || true)"

if [[ -z "$after_head" || "$after_head" != "$before_head" || "$after_ref" != "$before_ref" ]]; then
  status="forbidden_git_state"
  adapter_exit=7
elif [[ "$timed_out" = true ]]; then
  status="timed_out"
  adapter_exit=5
elif [[ "$target_exit" -ne 0 ]]; then
  status="failed"
  adapter_exit="$target_exit"
elif [[ "$pi_stop_reason" =~ ^(error|aborted|length)$ ]]; then
  # Pi's JSON mode exits 0 for these stops; its text mode would exit 1.
  status="failed"
  adapter_exit=1
elif [[ -n "$agy_status" && "$agy_status" != "SUCCESS" ]]; then
  # A result event that is not SUCCESS is a failed turn, whatever the exit.
  status="failed"
  adapter_exit=1
else
  if ! after_fingerprint="$(reviewable_fingerprint)"; then
    status="git_inspection_failed"
    adapter_exit=7
  elif [[ "$after_fingerprint" = "$before_fingerprint" ]]; then
    status="no_changes"
    adapter_exit=6
  else
    status="completed"
    adapter_exit=0
  fi
fi

finished_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
record_tmp="$(mktemp "$record_dir/.ticket-delegation-record.XXXXXX")"
chmod 600 "$record_tmp"
{
  printf '{\n'
  printf '  "executor":"%s",\n' "$(json_escape "$executor")"
  printf '  "host":"%s",\n' "$(json_escape "$host")"
  printf '  "status":"%s",\n' "$(json_escape "$status")"
  printf '  "exit_code":%d,\n' "$target_exit"
  printf '  "started_at":"%s",\n' "$(json_escape "$started_at")"
  printf '  "finished_at":"%s",\n' "$(json_escape "$finished_at")"
  printf '  "output_file":"%s",\n' "$(json_escape "$output_file")"
  if [[ "$executor" = "pi" ]]; then
    printf '  "task_package_file":"%s",\n' "$(json_escape "$task_package_file")"
    printf '  "provider":%s,\n' "$(json_string_or_null "$pi_used_provider")"
    printf '  "model":%s,\n' "$(json_string_or_null "$pi_used_model")"
    printf '  "thinking_level":%s,\n' "$(json_string_or_null "$pi_used_thinking")"
    printf '  "stop_reason":%s,\n' "$(json_string_or_null "$pi_stop_reason")"
    printf '  "turn_count":%s,\n' "$(json_int_or_null "$pi_turn_count")"
    printf '  "tool_call_count":%s,\n' "$(json_int_or_null "$pi_tool_call_count")"
    printf '  "tool_error_count":%s,\n' "$(json_int_or_null "$pi_tool_error_count")"
    printf '  "total_tokens":%s,\n' "$(json_int_or_null "$pi_total_tokens")"
    printf '  "pi_usage_file":%s,\n' "$(json_string_or_null "$pi_usage_file_written")"
    printf '  "pi_usage_error":%s,\n' "$(json_string_or_null "$pi_usage_error")"
    printf '  "transcript_error":%s,\n' "$(json_string_or_null "$pi_transcript_error")"
    if [[ -f "$final_message_file" ]]; then
      printf '  "final_message_file":"%s",\n' "$(json_escape "$final_message_file")"
    else
      printf '  "final_message_file":null,\n'
    fi
    if [[ -n "$pi_transcript_written" ]]; then
      printf '  "transcript_file":"%s"\n' "$(json_escape "$pi_transcript_written")"
    else
      printf '  "transcript_file":null\n'
    fi
  elif [[ "$executor" = "agy" ]]; then
    printf '  "task_package_file":"%s",\n' "$(json_escape "$task_package_file")"
    printf '  "model":%s,\n' "$(json_string_or_null "$agy_used_model")"
    printf '  "requested_model":%s,\n' "$(json_string_or_null "$agy_model")"
    printf '  "requested_effort":%s,\n' "$(json_string_or_null "$agy_effort")"
    printf '  "agy_status":%s,\n' "$(json_string_or_null "$agy_status")"
    printf '  "agy_error":%s,\n' "$(json_string_or_null "$agy_error")"
    printf '  "conversation_id":%s,\n' "$(json_string_or_null "$agy_conversation_id")"
    printf '  "turn_count":%s,\n' "$(json_int_or_null "$agy_turn_count")"
    printf '  "tool_call_count":%s,\n' "$(json_int_or_null "$agy_tool_call_count")"
    printf '  "tool_error_count":%s,\n' "$(json_int_or_null "$agy_tool_error_count")"
    printf '  "total_tokens":%s,\n' "$(json_int_or_null "$agy_total_tokens")"
    printf '  "transcript_error":%s,\n' "$(json_string_or_null "$agy_transcript_error")"
    if [[ -f "$final_message_file" ]]; then
      printf '  "final_message_file":"%s",\n' "$(json_escape "$final_message_file")"
    else
      printf '  "final_message_file":null,\n'
    fi
    if [[ -n "$agy_transcript_written" ]]; then
      printf '  "transcript_file":"%s"\n' "$(json_escape "$agy_transcript_written")"
    else
      printf '  "transcript_file":null\n'
    fi
  else
    printf '  "task_package_file":"%s"\n' "$(json_escape "$task_package_file")"
  fi
  printf '}\n'
} >"$record_tmp"
mv -f "$record_tmp" "$record_file"

case "$status" in
  completed)
    printf 'Delegated implementation completed; record: %s\n' "$record_file"
    ;;
  no_changes)
    printf 'ERROR: executor completed without reviewable changes; record: %s\n' \
      "$record_file" >&2
    ;;
  timed_out)
    printf 'ERROR: executor timed out after %s seconds; record: %s\n' \
      "$timeout_seconds" "$record_file" >&2
    ;;
  forbidden_git_state)
    printf 'ERROR: executor changed the pinned branch or HEAD; record: %s\n' \
      "$record_file" >&2
    ;;
  git_inspection_failed)
    printf 'ERROR: could not verify reviewable Git changes; record: %s\n' \
      "$record_file" >&2
    ;;
  failed)
    if [[ "$target_exit" -eq 0 && "$executor" = "agy" ]]; then
      printf 'ERROR: agy finished with status %s; record: %s\n' \
        "$agy_status" "$record_file" >&2
    elif [[ "$target_exit" -eq 0 ]]; then
      printf 'ERROR: executor stopped with reason %s; record: %s\n' \
        "$pi_stop_reason" "$record_file" >&2
    else
      printf 'ERROR: executor exited %s; record: %s\n' \
        "$target_exit" "$record_file" >&2
    fi
    ;;
esac

exit "$adapter_exit"
