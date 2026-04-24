#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_root="$root/skills"
codex_root="$root/.agents/skills"
failed=0

say() {
  printf '%s\n' "$*"
}

fail() {
  say "ERROR: $*"
  failed=1
}

load_skill_names() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

validate_skill_md() {
  local skill_md="$1"
  local label="$2"
  local description_length

  if [[ ! -f "$skill_md" ]]; then
    fail "missing $label SKILL.md: $skill_md"
    return
  fi

  if ! description_length="$(ruby -e '
    require "yaml"

    metadata = YAML.load_file(ARGV[0])
    unless metadata.is_a?(Hash)
      warn "frontmatter did not parse to a mapping"
      exit 2
    end

    name = metadata["name"]
    description = metadata["description"]

    unless name.is_a?(String) && !name.empty?
      warn "missing or invalid name frontmatter"
      exit 3
    end

    unless description.is_a?(String) && !description.empty?
      warn "missing or invalid description frontmatter"
      exit 4
    end

    puts description.length
  ' "$skill_md" 2>&1)"; then
    fail "invalid YAML frontmatter in $skill_md: $description_length"
    return
  fi

  if [[ "$description_length" -gt 1024 ]]; then
    fail "$label description exceeds 1024 characters in $skill_md ($description_length)"
  fi
}

if [[ ! -d "$claude_root" ]]; then
  fail "missing Claude skill root: $claude_root"
fi

if [[ ! -d "$codex_root" ]]; then
  fail "missing Codex skill root: $codex_root"
fi

claude_skills=()
while IFS= read -r skill; do
  claude_skills+=("$skill")
done < <(load_skill_names "$claude_root")

codex_skills=()
while IFS= read -r skill; do
  codex_skills+=("$skill")
done < <(load_skill_names "$codex_root")

if [[ "${#claude_skills[@]}" -eq 0 ]]; then
  fail "no Claude skills found under $claude_root"
fi

for skill in "${claude_skills[@]}"; do
  claude_skill_md="$claude_root/$skill/SKILL.md"
  codex_skill="$codex_root/$skill"
  codex_skill_md="$codex_skill/SKILL.md"
  codex_yaml="$codex_skill/agents/openai.yaml"

  validate_skill_md "$claude_skill_md" "Claude"

  if [[ ! -d "$codex_skill" ]]; then
    fail "missing Codex skill directory for $skill"
    continue
  fi

  validate_skill_md "$codex_skill_md" "Codex"

  if [[ ! -f "$codex_yaml" ]]; then
    fail "missing openai.yaml for $skill"
  else
    if ! ruby -e 'require "yaml"; YAML.load_file(ARGV[0])' "$codex_yaml" >/dev/null 2>&1; then
      fail "invalid YAML in $codex_yaml"
    fi
  fi

  for shared in references scripts assets; do
    claude_shared="$claude_root/$skill/$shared"
    codex_shared="$codex_skill/$shared"

    if [[ -e "$claude_shared" || -L "$claude_shared" ]]; then
      if [[ ! -L "$codex_shared" ]]; then
        fail "expected symlink for $codex_shared"
      elif [[ ! -e "$codex_shared" ]]; then
        fail "broken symlink at $codex_shared"
      fi
    elif [[ -e "$codex_shared" || -L "$codex_shared" ]]; then
      fail "unexpected shared directory entry at $codex_shared"
    fi
  done
done

for skill in "${codex_skills[@]}"; do
  if [[ ! -d "$claude_root/$skill" ]]; then
    fail "Codex skill has no matching Claude skill: $skill"
  fi
done

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

say "Validated ${#claude_skills[@]} Codex skill(s)."
