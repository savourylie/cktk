#!/usr/bin/env bash

set -euo pipefail

mode="find"
json_output=0
handoff_dir_arg=""

usage() {
  cat <<'EOF'
Usage: find-handoff.sh [--handoff-dir PATH] [--mark-in-progress | --mark-done] [--json]

Find the current repository's newest eligible handoff bundle.
EOF
}

die() {
  printf 'find-handoff: %s\n' "$*" >&2
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --mark-in-progress)
      [[ "$mode" = "find" ]] || die "status flags are mutually exclusive"
      mode="mark-in-progress"
      shift
      ;;
    --mark-done)
      [[ "$mode" = "find" ]] || die "status flags are mutually exclusive"
      mode="mark-done"
      shift
      ;;
    --json)
      json_output=1
      shift
      ;;
    --handoff-dir)
      [[ -n "${2:-}" ]] || die "--handoff-dir requires a value"
      handoff_dir_arg="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is required"
command -v python3 >/dev/null 2>&1 || die "Python 3 is required"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
  die "run this command from inside a git repository"
repo_root="$(cd "$repo_root" && pwd -P)"

python3 - "$repo_root" "$mode" "$json_output" "$handoff_dir_arg" <<'PY'
import glob
import json
import os
import sys
from datetime import datetime


repo_root, mode, json_output, handoff_dir_arg = sys.argv[1:]
json_output = json_output == "1"
handoffs_root = os.path.realpath(os.path.join(repo_root, ".ai", "handoffs"))
latest_path = os.path.join(handoffs_root, "latest.json")

if mode == "mark-done":
    eligible = {"in_progress"}
else:
    # find and mark-in-progress also surface in-progress handoffs so an
    # interrupted takeover can be resumed (and re-marking stays idempotent).
    eligible = {"pending", "in_progress"}
new_status = {
    "mark-in-progress": "in_progress",
    "mark-done": "done",
}.get(mode)


def load_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else None
    except (OSError, json.JSONDecodeError):
        return None


def inside_handoffs(path):
    try:
        return os.path.commonpath((handoffs_root, os.path.realpath(path))) == handoffs_root
    except ValueError:
        return False


def resolve_handoff_dir(value):
    if not isinstance(value, str) or not value:
        return None
    path = value if os.path.isabs(value) else os.path.join(repo_root, value)
    path = os.path.realpath(path)
    return path if inside_handoffs(path) else None


def candidate_from_manifest(manifest_path):
    manifest_path = os.path.realpath(manifest_path)
    if not inside_handoffs(manifest_path):
        return None
    data = load_json(manifest_path)
    if not data or data.get("status") not in eligible:
        return None
    handoff_dir = os.path.dirname(manifest_path)
    created = data.get("created_at")
    try:
        sort_time = datetime.fromisoformat(created).timestamp()
    except (TypeError, ValueError):
        sort_time = os.path.getmtime(manifest_path)
    return sort_time, handoff_dir, manifest_path, data


candidates = []
if handoff_dir_arg:
    selected_dir = resolve_handoff_dir(handoff_dir_arg)
    if not selected_dir:
        print(
            "find-handoff: --handoff-dir must resolve beneath this repository's .ai/handoffs directory.",
            file=sys.stderr,
        )
        sys.exit(2)
    candidate = candidate_from_manifest(os.path.join(selected_dir, "HANDOFF.json"))
    if candidate:
        candidates.append(candidate)
else:
    latest = load_json(latest_path)
    if latest:
        latest_dir = resolve_handoff_dir(latest.get("handoff_dir"))
        if latest_dir:
            candidate = candidate_from_manifest(os.path.join(latest_dir, "HANDOFF.json"))
            if candidate:
                candidates.append(candidate)

    if not candidates:
        pattern = os.path.join(handoffs_root, "*", "*", "HANDOFF.json")
        for manifest_path in glob.glob(pattern):
            candidate = candidate_from_manifest(manifest_path)
            if candidate:
                candidates.append(candidate)

if not candidates:
    print(
        "find-handoff: No pending or in-progress handoff work exists in this repository."
        if mode != "mark-done"
        else "find-handoff: No in-progress handoff exists in this repository.",
        file=sys.stderr,
    )
    sys.exit(1)

_, handoff_dir, manifest_path, manifest = max(candidates, key=lambda item: item[0])


def atomic_json_write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    temp = f"{path}.tmp.{os.getpid()}"
    try:
        with open(temp, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
        os.replace(temp, path)
    finally:
        try:
            os.unlink(temp)
        except FileNotFoundError:
            pass


if new_status:
    manifest["status"] = new_status
    atomic_json_write(manifest_path, manifest)
    latest = {
        "schema_version": "1.0",
        "target_agent": manifest.get("target_agent"),
        "handoff_dir": os.path.relpath(handoff_dir, repo_root),
        "status": new_status,
    }
    atomic_json_write(latest_path, latest)

result = {
    "handoff_dir": handoff_dir,
    "manifest_path": manifest_path,
    "takeover_path": os.path.join(handoff_dir, "TAKEOVER.md"),
    "status": new_status or manifest.get("status"),
    "target_agent": manifest.get("target_agent"),
    "source_agent": manifest.get("source_agent"),
    "created_at": manifest.get("created_at"),
}

if json_output:
    print(json.dumps(result, indent=2))
else:
    print(f"Handoff: {result['handoff_dir']}")
    print(f"Status: {result['status']}")
    print(f"Target agent: {result['target_agent']}")
    print(f"Source agent: {result['source_agent']}")
    print(f"Created at: {result['created_at']}")
PY
