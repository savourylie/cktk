#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bin_dir="$HOME/.local/bin"
codex_exporter="$root/skills/codex-handoff/scripts/codex-handoff.sh"
grok_exporter="$root/skills/grok-handoff/scripts/grok-handoff.sh"
opencode_exporter="$root/skills/opencode-handoff/scripts/opencode-handoff.sh"
finder="$root/skills/takeover/scripts/find-handoff.sh"

die() {
  printf 'install-global-handoff-tools: %s\n' "$*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || die "Python 3 is required"
[[ -x "$codex_exporter" ]] || die "missing executable: $codex_exporter"
[[ -x "$grok_exporter" ]] || die "missing executable: $grok_exporter"
[[ -x "$opencode_exporter" ]] || die "missing executable: $opencode_exporter"
[[ -x "$finder" ]] || die "missing executable: $finder"

resolve_link() {
  python3 - "$1" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
}

check_destination() {
  local destination="$1"
  local resolved

  if [[ -L "$destination" ]]; then
    resolved="$(resolve_link "$destination")"
    case "$resolved" in
      "$root" | "$root"/*)
        return 0
        ;;
      *)
        die "Refusing to overwrite unrelated symlink: $destination -> $(readlink "$destination")"
        ;;
    esac
  elif [[ -e "$destination" ]]; then
    die "Refusing to overwrite existing file: $destination"
  fi
}

check_destination "$bin_dir/codex-handoff"
check_destination "$bin_dir/grok-handoff"
check_destination "$bin_dir/opencode-handoff"
check_destination "$bin_dir/cktk-takeover"

mkdir -p "$bin_dir"
ln -sfn "$codex_exporter" "$bin_dir/codex-handoff"
ln -sfn "$grok_exporter" "$bin_dir/grok-handoff"
ln -sfn "$opencode_exporter" "$bin_dir/opencode-handoff"
ln -sfn "$finder" "$bin_dir/cktk-takeover"

printf 'Installed:\n'
printf '  %s -> %s\n' "$bin_dir/codex-handoff" "$codex_exporter"
printf '  %s -> %s\n' "$bin_dir/grok-handoff" "$grok_exporter"
printf '  %s -> %s\n' "$bin_dir/opencode-handoff" "$opencode_exporter"
printf '  %s -> %s\n' "$bin_dir/cktk-takeover" "$finder"

case ":${PATH:-}:" in
  *":$bin_dir:"*)
    ;;
  *)
    printf '\n%s is not currently in PATH.\n' "$bin_dir"
    printf 'Add this line to your shell profile:\n'
    printf '  export PATH="$HOME/.local/bin:$PATH"\n'
    ;;
esac
