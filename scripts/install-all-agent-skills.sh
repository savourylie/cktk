#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
claude_skills="$root/skills"
codex_skills="$root/.agents/skills"
antigravity_skills="$root/.agent/skills"

bin_dir="$HOME/.local/bin"
codex_home="${CODEX_HOME:-$HOME/.codex}"
codex_target="$codex_home/skills"
antigravity_home="${AGENT_HOME:-$HOME/.agent}"
antigravity_target="$antigravity_home/skills"
opencode_home="${OPENCODE_HOME:-$HOME/.config/opencode}"
opencode_target="$opencode_home/skills"

die() {
  printf 'install-all-agent-skills: %s\n' "$*" >&2
  exit 1
}

resolve_path() {
  python3 - "$1" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
}

skill_name() {
  python3 - "$1" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    text = handle.read(2048)

match = re.search(r"(?m)^name:\s*[\"']?([^\"'\n]+)[\"']?\s*$", text)
if not match:
    sys.exit(1)
print(match.group(1).strip())
PY
}

looks_like_skill_dir() {
  local destination="$1"
  local expected="$2"
  local actual

  [[ -f "$destination/SKILL.md" ]] || return 1
  actual="$(skill_name "$destination/SKILL.md")" || return 1
  [[ "$actual" = "$expected" ]]
}

link_path() {
  local source="$1"
  local destination="$2"
  local label="$3"

  [[ -e "$source" || -L "$source" ]] || die "missing source for $label: $source"
  mkdir -p "$(dirname "$destination")"

  if [[ -L "$destination" ]]; then
    rm "$destination"
    ln -s "$source" "$destination"
  elif [[ -e "$destination" ]]; then
    die "refusing to overwrite existing non-symlink $label: $destination"
  else
    ln -s "$source" "$destination"
  fi
}

link_skill_dir() {
  local source="$1"
  local destination="$2"
  local skill="$3"

  [[ -d "$source" ]] || die "missing skill source: $source"
  mkdir -p "$(dirname "$destination")"

  if [[ -L "$destination" ]]; then
    rm "$destination"
    ln -s "$source" "$destination"
  elif [[ -d "$destination" ]]; then
    if looks_like_skill_dir "$destination" "$skill"; then
      rm -rf "$destination"
      ln -s "$source" "$destination"
    else
      die "refusing to replace non-cktk skill directory: $destination"
    fi
  elif [[ -e "$destination" ]]; then
    die "refusing to replace existing file: $destination"
  else
    ln -s "$source" "$destination"
  fi
}

install_shell_helpers() {
  local exporter="$claude_skills/codex-handoff/scripts/codex-handoff.sh"
  local finder="$claude_skills/takeover/scripts/find-handoff.sh"

  [[ -x "$exporter" ]] || die "missing executable: $exporter"
  [[ -x "$finder" ]] || die "missing executable: $finder"

  link_path "$exporter" "$bin_dir/codex-handoff" "shell helper"
  link_path "$finder" "$bin_dir/cktk-takeover" "shell helper"

  printf 'Shell helpers:\n'
  printf '  %s -> %s\n' "$bin_dir/codex-handoff" "$exporter"
  printf '  %s -> %s\n' "$bin_dir/cktk-takeover" "$finder"

  case ":${PATH:-}:" in
    *":$bin_dir:"*) ;;
    *)
      printf '\n%s is not currently in PATH.\n' "$bin_dir"
      printf 'Add this line to your shell profile:\n'
      printf '  export PATH="$HOME/.local/bin:$PATH"\n'
      ;;
  esac
}

install_codex_skills() {
  local skill
  local count=0

  [[ -d "$codex_skills" ]] || die "missing Codex skill tree: $codex_skills"
  mkdir -p "$codex_target"

  while IFS= read -r skill; do
    link_skill_dir "$codex_skills/$skill" "$codex_target/$skill" "$skill"
    count=$((count + 1))
  done < <(find "$codex_skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

  printf '\nCodex skills:\n'
  printf '  installed %d skill link(s) under %s\n' "$count" "$codex_target"
}

install_antigravity_skills() {
  local skill
  local count=0
  local resolved

  [[ -d "$antigravity_skills" ]] || die "missing Antigravity skill tree: $antigravity_skills"
  mkdir -p "$(dirname "$antigravity_target")"

  if [[ -L "$antigravity_target" ]]; then
    resolved="$(resolve_path "$antigravity_target")"
    if [[ "$resolved" = "$antigravity_skills" ]] ||
      [[ -e "$resolved/cktk-upgrade/SKILL.md" || -L "$resolved/cktk-upgrade" ]]; then
      rm "$antigravity_target"
      ln -s "$antigravity_skills" "$antigravity_target"
      printf '\nAntigravity skills:\n'
      printf '  %s -> %s\n' "$antigravity_target" "$antigravity_skills"
      return
    fi
    # Preserve a user-managed aggregate symlink and install into its target.
  elif [[ ! -e "$antigravity_target" ]]; then
    ln -s "$antigravity_skills" "$antigravity_target"
    printf '\nAntigravity skills:\n'
    printf '  %s -> %s\n' "$antigravity_target" "$antigravity_skills"
    return
  elif [[ ! -d "$antigravity_target" ]]; then
    die "refusing to replace existing non-directory: $antigravity_target"
  fi

  while IFS= read -r skill; do
    link_path "$antigravity_skills/$skill" "$antigravity_target/$skill" "Antigravity skill"
    count=$((count + 1))
  done < <(find "$antigravity_skills" -mindepth 1 -maxdepth 1 -type l -exec basename {} \; | sort)

  printf '\nAntigravity skills:\n'
  printf '  installed %d skill link(s) under %s\n' "$count" "$antigravity_target"
}

install_opencode_skills() {
  local skill
  local count=0

  [[ -d "$claude_skills" ]] || die "missing Claude skill tree: $claude_skills"
  mkdir -p "$opencode_target"

  while IFS= read -r skill; do
    link_skill_dir "$claude_skills/$skill" "$opencode_target/$skill" "$skill"
    count=$((count + 1))
  done < <(find "$claude_skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

  printf '\nOpenCode skills:\n'
  printf '  installed %d skill link(s) under %s\n' "$count" "$opencode_target"
}

install_project_ignore() {
  local project_root="${PROJECT_ROOT:-}"
  local git_root
  local gitignore

  [[ -n "$project_root" ]] || return 0
  git_root="$(git -C "$project_root" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$git_root" ]] || return 0

  if git -C "$git_root" check-ignore -q .ai/handoffs/ 2>/dev/null; then
    printf '\nProject ignore:\n'
    printf '  .ai/handoffs/ is already ignored in %s\n' "$git_root"
    return 0
  fi

  gitignore="$git_root/.gitignore"
  mkdir -p "$(dirname "$gitignore")"
  if [[ -s "$gitignore" ]] && [[ "$(tail -c 1 "$gitignore")" != "" ]]; then
    printf '\n' >>"$gitignore"
  fi
  printf '.ai/handoffs/\n' >>"$gitignore"

  printf '\nProject ignore:\n'
  printf '  added .ai/handoffs/ to %s\n' "$gitignore"
}

command -v python3 >/dev/null 2>&1 || die "Python 3 is required"
[[ -d "$claude_skills" ]] || die "missing Claude skill tree: $claude_skills"

install_shell_helpers
install_codex_skills
install_antigravity_skills
install_opencode_skills
install_project_ignore
