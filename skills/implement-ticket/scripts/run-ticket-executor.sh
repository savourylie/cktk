#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  run-ticket-executor.sh \
    --host <invoking-agent-id> \
    --executor <codex|claude|grok|pi> \
    --work-dir <absolute-dir> \
    --task-file <absolute-file> \
    --record-file <absolute-file> \
    [--timeout-seconds <positive-int>]

  run-ticket-executor.sh --check \
    --host <invoking-agent-id> \
    --executor <codex|claude|grok|pi>

--check validates the executor, the host, any pi overrides, and the CLI
discovery below, then exits 0 without packaging or launching anything.

Environment (pi only; each defaults to Pi's own settings):
  CKTK_PI_MODEL     model pattern or ID passed to pi --model
  CKTK_PI_PROVIDER  provider passed to pi --provider; requires CKTK_PI_MODEL
  CKTK_PI_THINKING  off|minimal|low|medium|high|xhigh|max, passed to pi --thinking
  CKTK_PI_USAGE_DIR absolute directory outside the work directory for an
                    optional usage-only Pi-format JSONL export

A pi run also requires python3, which reads Pi's JSON event stream into the
record's provider, model, thinking_level, stop_reason, pi_usage_file,
pi_usage_error, and final_message_file.

Exit codes:
  0  executor completed and left reviewable changes (with --check: executor is usable)
  2  invalid arguments
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
  codex|claude|grok|pi) ;;
  *) die 3 "unsupported executor: $executor" ;;
esac

if [[ "$executor" = "$host" ]]; then
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

cli_label=""
case "$executor" in
  codex) cli_label="Codex CLI" ;;
  claude) cli_label="Claude Code CLI" ;;
  grok) cli_label="Grok Build CLI" ;;
  pi) cli_label="Pi coding agent CLI" ;;
esac

executor_path=""
discover_executor() {
  executor_path="$(command -v "$executor" 2>/dev/null || true)"
  [[ -n "$executor_path" ]] ||
    die 4 "$cli_label is not installed (expected command: $executor)"
  if ! "$executor_path" --version >/dev/null 2>&1; then
    die 4 "$cli_label failed its version check"
  fi
  if [[ "$executor" = "pi" ]]; then
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
    # exposes the model and thinking level that Pi actually used. Sessions
    # stay ephemeral; CKTK_PI_USAGE_DIR optionally writes a usage-only export
    # for local trackers without saving a resumable session.
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
esac

before_head="$(git -C "$work_dir" rev-parse HEAD)"
before_ref="$(git -C "$work_dir" symbolic-ref -q HEAD || true)"

status_pathspecs=(.)
for artifact_path in \
  "$task_file" \
  "$record_file" \
  "$task_package_file" \
  "$output_file" \
  "$final_message_file"; do
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

rm -f "$timeout_marker" "$final_message_file"
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
pi_usage_file_written=""
pi_usage_error=""
if [[ "$executor" = "pi" ]]; then
  # The last assistant message names the provider, model, and thinking level
  # that answered. When CKTK_PI_USAGE_DIR is set, the same pass writes a
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
    usage_path,
    run_id,
    started_at,
    work_dir,
) = sys.argv[1:7]

last = None
usages = []
with open(output_path, encoding="utf-8", errors="replace") as handle:
    for line in handle:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if not isinstance(event, dict) or event.get("type") != "message_end":
            continue
        message = event.get("message")
        if not isinstance(message, dict) or message.get("role") != "assistant":
            continue
        last = message
        if isinstance(message.get("usage"), dict):
            usages.append((message, event.get("timestamp")))

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

# Printed before the optional export runs: a failure while building or
# writing the usage file must not cost the record the classification
# metadata that drives stop_reason handling.
for key in ("provider", "model", "thinkingLevel", "stopReason"):
    value = last.get(key)
    print("" if value is None else " ".join(str(value).split()))


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
  pi_usage_file_written="${pi_metadata[4]:-}"
  pi_usage_error="${pi_metadata[5]:-}"
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
  if [[ -n "$pi_usage_error" ]]; then
    printf 'WARNING: Pi usage export failed: %s\n' "$pi_usage_error" >&2
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
    printf '  "pi_usage_file":%s,\n' "$(json_string_or_null "$pi_usage_file_written")"
    printf '  "pi_usage_error":%s,\n' "$(json_string_or_null "$pi_usage_error")"
    if [[ -f "$final_message_file" ]]; then
      printf '  "final_message_file":"%s"\n' "$(json_escape "$final_message_file")"
    else
      printf '  "final_message_file":null\n'
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
    if [[ "$target_exit" -eq 0 ]]; then
      printf 'ERROR: executor stopped with reason %s; record: %s\n' \
        "$pi_stop_reason" "$record_file" >&2
    else
      printf 'ERROR: executor exited %s; record: %s\n' \
        "$target_exit" "$record_file" >&2
    fi
    ;;
esac

exit "$adapter_exit"
