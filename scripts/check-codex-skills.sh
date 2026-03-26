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

if [[ ! -d "$claude_root" ]]; then
  fail "missing Claude skill root: $claude_root"
fi

if [[ ! -d "$codex_root" ]]; then
  fail "missing Codex skill root: $codex_root"
fi

mapfile -t claude_skills < <(find "$claude_root" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
mapfile -t codex_skills < <(find "$codex_root" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

if [[ "${#claude_skills[@]}" -eq 0 ]]; then
  fail "no Claude skills found under $claude_root"
fi

for skill in "${claude_skills[@]}"; do
  codex_skill="$codex_root/$skill"
  codex_skill_md="$codex_skill/SKILL.md"
  codex_yaml="$codex_skill/agents/openai.yaml"

  if [[ ! -d "$codex_skill" ]]; then
    fail "missing Codex skill directory for $skill"
    continue
  fi

  if [[ ! -f "$codex_skill_md" ]]; then
    fail "missing Codex SKILL.md for $skill"
  else
    if ! rg -q '^name:' "$codex_skill_md"; then
      fail "missing name frontmatter in $codex_skill_md"
    fi
    if ! rg -q '^description:' "$codex_skill_md"; then
      fail "missing description frontmatter in $codex_skill_md"
    fi
  fi

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
