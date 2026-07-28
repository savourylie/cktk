#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  run-ticket-executor.sh \
    --host <codex|claude|grok> \
    --executor <codex|claude|grok> \
    --work-dir <absolute-dir> \
    --task-file <absolute-file> \
    --record-file <absolute-file> \
    [--timeout-seconds <positive-int>]

Exit codes:
  0  executor completed and left reviewable changes
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
      shift 2
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
[[ -n "$work_dir" ]] || die 2 "--work-dir is required"
[[ -n "$task_file" ]] || die 2 "--task-file is required"
[[ -n "$record_file" ]] || die 2 "--record-file is required"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] ||
  die 2 "timeout seconds must be a positive integer"

case "$host" in
  codex|claude|grok) ;;
  *) die 2 "unsupported host: $host" ;;
esac

case "$executor" in
  codex|claude|grok) ;;
  *) die 3 "unsupported executor: $executor" ;;
esac

if [[ "$executor" = "$host" ]]; then
  die 3 "executor '$executor' is the current host; omit via to use native implementation"
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

cli_label=""
case "$executor" in
  codex) cli_label="Codex CLI" ;;
  claude) cli_label="Claude Code CLI" ;;
  grok) cli_label="Grok Build CLI" ;;
esac

executor_path="$(command -v "$executor" 2>/dev/null || true)"
[[ -n "$executor_path" ]] ||
  die 4 "$cli_label is not installed (expected command: $executor)"
if ! "$executor_path" --version >/dev/null 2>&1; then
  die 4 "$cli_label failed its version check"
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

umask 077
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
esac

before_head="$(git -C "$work_dir" rev-parse HEAD)"
before_ref="$(git -C "$work_dir" symbolic-ref -q HEAD || true)"

status_pathspecs=(.)
for artifact_path in \
  "$task_file" \
  "$record_file" \
  "$task_package_file" \
  "$output_file"; do
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

rm -f "$timeout_marker"

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
  printf '  "task_package_file":"%s"\n' "$(json_escape "$task_package_file")"
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
    printf 'ERROR: executor exited %s; record: %s\n' \
      "$target_exit" "$record_file" >&2
    ;;
esac

exit "$adapter_exit"
