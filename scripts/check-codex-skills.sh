#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_root="$root/skills"
codex_root="$root/.agents/skills"
antigravity_root="$root/.agent/skills"
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

load_symlink_names() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type l -exec basename {} \; | sort
}

validate_skill_md() {
  local skill_md="$1"
  local label="$2"
  local description_length

  if [[ ! -f "$skill_md" ]]; then
    fail "missing $label SKILL.md: $skill_md"
    return
  fi

  if ! description_length="$(RUBYOPT=--disable=gems ruby -e '
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

validate_openai_yaml() {
  local openai_yaml="$1"
  local skill="$2"
  local error

  if ! error="$(RUBYOPT=--disable=gems ruby -e '
    require "yaml"

    path, skill = ARGV
    metadata = YAML.load_file(path)
    abort("top level is not a mapping") unless metadata.is_a?(Hash)

    interface = metadata["interface"]
    abort("missing interface mapping") unless interface.is_a?(Hash)
    %w[display_name short_description default_prompt].each do |key|
      value = interface[key]
      abort("missing or invalid interface.#{key}") unless value.is_a?(String) && !value.empty?
    end

    policy = metadata["policy"]
    abort("missing policy mapping") unless policy.is_a?(Hash)
    implicit = policy["allow_implicit_invocation"]
    abort("policy.allow_implicit_invocation must be boolean") unless [true, false].include?(implicit)

    if %w[clarify-ticket clarify-ticket-linear quiz-ticket quiz-ticket-linear].include?(skill)
      short = interface["short_description"]
      abort("short_description must be 25-64 characters") unless (25..64).cover?(short.length)
      abort("default_prompt must mention $#{skill}") unless interface["default_prompt"].include?("$#{skill}")
      abort("interactive skills must be explicit-only") unless implicit == false
    end
  ' "$openai_yaml" "$skill" 2>&1)"; then
    fail "invalid openai.yaml contract in $openai_yaml: $error"
  fi
}

require_literal() {
  local file="$1"
  local text="$2"

  if ! grep -Fq -- "$text" "$file"; then
    fail "$file must contain: $text"
  fi
}

forbid_literal() {
  local file="$1"
  local text="$2"

  if grep -Fq -- "$text" "$file"; then
    fail "$file must not contain host-specific text: $text"
  fi
}

# Same mechanism as forbid_literal, different reason: the text is not
# host-specific, it is a superseded guarantee that must not creep back in.
forbid_stale_claim() {
  local file="$1"
  local text="$2"

  if grep -Fq -- "$text" "$file"; then
    fail "$file contains a claim that is no longer true: $text"
  fi
}

# Same mechanism again, third reason: the text names a Linear write tool in a
# skill whose contract is read-only.
forbid_write_call() {
  local file="$1"
  local text="$2"

  if grep -Fq -- "$text" "$file"; then
    fail "$file must not call a Linear write tool: $text"
  fi
}

validate_clarify_contract() {
  local skill
  local claude_skill_md
  local codex_skill_md
  local metadata_error

  for skill in clarify-ticket clarify-ticket-linear quiz-ticket quiz-ticket-linear; do
    claude_skill_md="$claude_root/$skill/SKILL.md"
    codex_skill_md="$codex_root/$skill/SKILL.md"

    if ! metadata_error="$(RUBYOPT=--disable=gems ruby -e '
      require "yaml"

      claude_path, codex_path, expected_name = ARGV
      claude = YAML.load_file(claude_path)
      codex = YAML.load_file(codex_path)

      abort("Claude skill must be user-invocable") unless claude["user-invocable"] == true
      abort("Claude skill must disable model invocation") unless claude["disable-model-invocation"] == true
      hint = claude["argument-hint"]
      abort("Claude skill must provide argument-hint") unless hint.is_a?(String) && !hint.empty?

      unexpected = codex.keys - %w[name description]
      abort("Codex frontmatter has unsupported keys: #{unexpected.join(", ")}") unless unexpected.empty?
      abort("Codex skill name mismatch") unless codex["name"] == expected_name
    ' "$claude_skill_md" "$codex_skill_md" "$skill" 2>&1)"; then
      fail "invalid cross-agent metadata for $skill: $metadata_error"
    fi

    for skill_md in "$claude_skill_md" "$codex_skill_md"; do
      require_literal "$skill_md" "Portable interaction"
      require_literal "$skill_md" "Never assume an option limit"
      require_literal "$skill_md" "AGENTS.md"
      forbid_literal "$skill_md" "AskUserQuestion"
      forbid_literal "$skill_md" "rely on \"Other\""
    done
  done

  for skill_md in \
    "$claude_root/clarify-ticket/SKILL.md" \
    "$codex_root/clarify-ticket/SKILL.md"; do
    require_literal "$skill_md" "Never let \`#007\` match \`#0070\`"
    require_literal "$skill_md" "ticket was renamed"
  done

  for skill_md in \
    "$claude_root/clarify-ticket-linear/SKILL.md" \
    "$codex_root/clarify-ticket-linear/SKILL.md"; do
    require_literal "$skill_md" "REPO_AVAILABLE=false"
    require_literal "$skill_md" "ANALYSIS_MODE=text-only"
    require_literal "$skill_md" "state type"
    require_literal "$skill_md" "text-only"
  done

  for skill_md in \
    "$claude_root/quiz-ticket/SKILL.md" \
    "$codex_root/quiz-ticket/SKILL.md" \
    "$claude_root/quiz-ticket-linear/SKILL.md" \
    "$codex_root/quiz-ticket-linear/SKILL.md"; do
    require_literal "$skill_md" "one at a time"
    require_literal "$skill_md" "explain"
  done

  for skill_md in \
    "$claude_root/quiz-ticket/SKILL.md" \
    "$codex_root/quiz-ticket/SKILL.md"; do
    require_literal "$skill_md" "As-Built Notes"
  done

  for skill_md in \
    "$claude_root/quiz-ticket-linear/SKILL.md" \
    "$codex_root/quiz-ticket-linear/SKILL.md"; do
    require_literal "$skill_md" "as-built comment"
  done
}

if [[ ! -d "$claude_root" ]]; then
  fail "missing Claude skill root: $claude_root"
fi

if [[ ! -d "$codex_root" ]]; then
  fail "missing Codex skill root: $codex_root"
fi

if [[ ! -d "$antigravity_root" ]]; then
  fail "missing Antigravity skill root: $antigravity_root"
fi

claude_skills=()
while IFS= read -r skill; do
  claude_skills+=("$skill")
done < <(load_skill_names "$claude_root")

codex_skills=()
while IFS= read -r skill; do
  codex_skills+=("$skill")
done < <(load_skill_names "$codex_root")

antigravity_skills=()
while IFS= read -r skill; do
  antigravity_skills+=("$skill")
done < <(load_symlink_names "$antigravity_root")

if [[ "${#claude_skills[@]}" -eq 0 ]]; then
  fail "no Claude skills found under $claude_root"
fi

for skill in "${claude_skills[@]}"; do
  claude_skill_md="$claude_root/$skill/SKILL.md"
  codex_skill="$codex_root/$skill"
  codex_skill_md="$codex_skill/SKILL.md"
  codex_yaml="$codex_skill/agents/openai.yaml"
  antigravity_skill="$antigravity_root/$skill"

  validate_skill_md "$claude_skill_md" "Claude"

  if [[ ! -d "$codex_skill" ]]; then
    fail "missing Codex skill directory for $skill"
    continue
  fi

  validate_skill_md "$codex_skill_md" "Codex"

  if [[ ! -f "$codex_yaml" ]]; then
    fail "missing openai.yaml for $skill"
  else
    validate_openai_yaml "$codex_yaml" "$skill"
  fi

  if [[ ! -L "$antigravity_skill" ]]; then
    fail "expected Antigravity symlink for $skill: $antigravity_skill"
  elif [[ ! -e "$antigravity_skill" ]]; then
    fail "broken Antigravity symlink for $skill: $antigravity_skill"
  elif [[ "$(readlink "$antigravity_skill")" != "../../skills/$skill" ]]; then
    fail "wrong Antigravity symlink target for $skill: $(readlink "$antigravity_skill")"
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

for skill in "${antigravity_skills[@]}"; do
  if [[ ! -d "$claude_root/$skill" ]]; then
    fail "Antigravity skill has no matching Claude skill: $skill"
  fi
done

validate_interact_contract() {
  local skill="interact-html"
  local claude_skill_md="$claude_root/$skill/SKILL.md"
  local codex_skill_md="$codex_root/$skill/SKILL.md"
  local openai_yaml="$codex_root/$skill/agents/openai.yaml"
  local metadata_error
  local skill_md

  # interact-html follows the portable-interaction contract but, unlike the
  # clarify/quiz entry-point workflows, is a mid-flow mechanism that allows
  # implicit/model invocation by design — so no explicit-only or
  # disable-model-invocation requirements here.
  if ! metadata_error="$(RUBYOPT=--disable=gems ruby -e '
    require "yaml"

    claude_path, codex_path, yaml_path, expected_name = ARGV
    claude = YAML.load_file(claude_path)
    codex = YAML.load_file(codex_path)
    yaml = YAML.load_file(yaml_path)

    abort("Claude skill must be user-invocable") unless claude["user-invocable"] == true
    hint = claude["argument-hint"]
    abort("Claude skill must provide argument-hint") unless hint.is_a?(String) && !hint.empty?

    unexpected = codex.keys - %w[name description]
    abort("Codex frontmatter has unsupported keys: #{unexpected.join(", ")}") unless unexpected.empty?
    abort("Codex skill name mismatch") unless codex["name"] == expected_name

    short = yaml["interface"]["short_description"]
    abort("short_description must be 25-64 characters") unless (25..64).cover?(short.length)
    abort("default_prompt must mention $#{expected_name}") unless yaml["interface"]["default_prompt"].include?("$#{expected_name}")
  ' "$claude_skill_md" "$codex_skill_md" "$openai_yaml" "$skill" 2>&1)"; then
    fail "invalid cross-agent metadata for $skill: $metadata_error"
  fi

  for skill_md in "$claude_skill_md" "$codex_skill_md"; do
    require_literal "$skill_md" "Portable interaction"
    require_literal "$skill_md" "Never assume an option limit"
    require_literal "$skill_md" "AGENTS.md"
    forbid_literal "$skill_md" "AskUserQuestion"
    forbid_literal "$skill_md" "rely on \"Other\""
  done
}

validate_implement_contract() {
  local skill
  local skill_md
  local reference
  local reference_error

  # Validate discoverability and resource integrity, not a mandatory menu or
  # exact prose. Behavioral decisions are checked with isolated task scenarios.
  for skill in implement-ticket implement-ticket-linear; do
    for skill_md in "$claude_root/$skill/SKILL.md" "$codex_root/$skill/SKILL.md"; do
      if [[ -L "$skill_md" ]]; then
        fail "implement entry points must be separate host-native documents: $skill_md"
      fi
      for reference in business-context.md workspace.md delegation.md finishing.md; do
        require_literal "$skill_md" "(references/$reference)"
      done
      forbid_literal "$skill_md" "AskUserQuestion"

      if ! reference_error="$(RUBYOPT=--disable=gems ruby -e '
        entry, shared = ARGV
        directory = File.dirname(entry)
        references = File.join(directory, "references")
        abort("references do not resolve to the shared implementation resources") unless
          File.realpath(references) == File.realpath(shared)

        files = [entry] + Dir.glob(File.join(references, "*.md"))
        files.each do |file|
          File.read(file).scan(/\[[^\]]+\]\(([^)\s]+)\)/).flatten.each do |target|
            next if target.match?(/\A(?:[a-z][a-z0-9+.-]*:|#)/i)
            target = target.split("#", 2).first
            resolved = File.expand_path(target, File.dirname(file))
            abort("missing reference #{target} from #{file}") unless File.file?(resolved)
          end
        end
      ' "$skill_md" "$claude_root/implement-ticket/references" 2>&1)"; then
        fail "invalid implementation references for $skill_md: $reference_error"
      fi
    done
  done
}

validate_ticket_delegation_contract() {
  local skill
  local skill_root
  local adapter
  local adapter_error

  # All four entry points must still reach the same actual adapter. Its fixed
  # CLI boundary is exercised by scripts/test-ticket-delegation.sh.
  for skill in implement-ticket implement-ticket-linear; do
    for skill_root in "$claude_root" "$codex_root"; do
      adapter="$skill_root/$skill/scripts/run-ticket-executor.sh"
      if ! adapter_error="$(RUBYOPT=--disable=gems ruby -e '
        actual, expected = ARGV
        abort("missing or unreadable delegation adapter") unless File.readable?(actual)
        abort("delegation adapter does not resolve to the canonical script") unless
          File.realpath(actual) == File.realpath(expected)
      ' "$adapter" "$claude_root/implement-ticket/scripts/run-ticket-executor.sh" 2>&1)"; then
        fail "invalid delegation adapter for $skill_root/$skill: $adapter_error"
      fi
    done
  done
}

validate_worktree_linear_contract() {
  local skill_md

  # The Linear worktree twins share one naming contract with
  # implement-ticket-linear and update-ticket-linear: worktrees at
  # .worktrees/<issue_id>-<slug>, branches at linear-<issue_id>-<slug>.
  # This pins the canonical form each document creates and prints. Discovery
  # deliberately keys on the <issue_id>- prefix rather than on the whole form,
  # so a slug that drifts is tolerated at read time -- but the .worktrees/ and
  # linear- halves are load-bearing, and a document that renamed either would
  # send one skill looking where the others never write.
  for skill_md in \
    "$claude_root/create-worktree-linear/SKILL.md" \
    "$codex_root/create-worktree-linear/SKILL.md" \
    "$claude_root/merge-worktree-linear/SKILL.md" \
    "$codex_root/merge-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "linear-<issue_id>-<slug>"
    require_literal "$skill_md" ".worktrees/<issue_id>-<slug>"
  done

  # create-worktree-linear prepares a workspace, so it must never write to
  # Linear — including the Todo -> In Progress transition its implement
  # sibling performs. The forbidden literals are the write tools rather than
  # the name of that transition, which the skill legitimately mentions when
  # explaining which write it declines to make. save_comment is forbidden
  # beside save_issue because implement-ticket-linear does post a comment and
  # is the obvious copy-paste source. The MCP *requirement* is asserted here
  # for the mirror-image reason its merge twin's lack of one is asserted
  # below: nothing else stops a rewrite from swapping the two prerequisites.
  for skill_md in \
    "$claude_root/create-worktree-linear/SKILL.md" \
    "$codex_root/create-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "never writes to Linear"
    require_literal "$skill_md" "must be available and authenticated"
    forbid_write_call "$skill_md" "save_issue"
    forbid_write_call "$skill_md" "save_comment"
  done

  # merge-worktree-linear deliberately works without Linear MCP: the worktree,
  # the branch, and the issue id are all on disk, so cleanup must not fail
  # because a service is unreachable. This is the only -linear skill with no
  # MCP prerequisite, which makes it the easiest one to "fix" by mistake.
  for skill_md in \
    "$claude_root/merge-worktree-linear/SKILL.md" \
    "$codex_root/merge-worktree-linear/SKILL.md"; do
    require_literal "$skill_md" "does not require Linear MCP"
    require_literal "$skill_md" "never writes to Linear"
    forbid_write_call "$skill_md" "save_issue"
    forbid_write_call "$skill_md" "save_comment"
  done

  # implement-ticket-linear merges inline and now also names
  # merge-worktree-linear as the later, standalone way to land a worktree
  # branch; update-ticket-linear never merges anything itself and used to
  # tell the user to land the branch "manually" instead. Keep the pointer to
  # the cleanup twin present in all four documents, and keep the superseded
  # manual-landing phrasing out of update-ticket-linear specifically.
  for skill_md in \
    "$claude_root/implement-ticket-linear/SKILL.md" \
    "$codex_root/implement-ticket-linear/SKILL.md" \
    "$claude_root/update-ticket-linear/SKILL.md" \
    "$codex_root/update-ticket-linear/SKILL.md"; do
    require_literal "$skill_md" "merge-worktree-linear"
  done

  forbid_stale_claim "$claude_root/update-ticket-linear/SKILL.md" "Land the branch manually"
  forbid_stale_claim "$codex_root/update-ticket-linear/SKILL.md" "manual land"
}

validate_review_ticket_contract() {
  local skill_md

  # The explicit flag form combines two previously separate review dimensions:
  # a committed branch diff and exact Linear issue context. Pin its parser,
  # diff, context, and failure contracts in both host-native documents.
  for skill_md in \
    "$claude_root/review-ticket/SKILL.md" \
    "$codex_root/review-ticket/SKILL.md"; do
    # --ticket TAI-90 --base main and default-base resolution.
    require_literal "$skill_md" '--ticket <ID> [--base <branch>]'
    require_literal "$skill_md" 'git diff "$base_ref"...HEAD'
    require_literal "$skill_md" 'try `main`, then `master`'
    require_literal "$skill_md" \
      'Linear ticket {ISSUE-ID} against {base} (merge-base)'

    # Invalid/missing values, extra arguments, and unresolved bases.
    require_literal "$skill_md" \
      '--ticket requires a Linear issue ID like TAI-90.'
    require_literal "$skill_md" \
      "Invalid --ticket value '<value>'; expected a Linear issue ID like TAI-90."
    require_literal "$skill_md" '--base requires a branch name.'
    require_literal "$skill_md" \
      '--base is only supported with --ticket <ID>.'
    require_literal "$skill_md" \
      "Unsupported argument '<value>'; expected --ticket <ID> [--base <branch>]."
    require_literal "$skill_md" \
      "Base branch '<branch>' was not found locally or on origin."

    # Empty diffs and unavailable Linear tooling must stop early.
    require_literal "$skill_md" 'there is nothing to review and stop'
    require_literal "$skill_md" \
      'Linear MCP is unavailable; configure and authenticate the Linear MCP tools, then retry.'

    # Exact ticket context, complete changed files, and scoped repo guidance.
    require_literal "$skill_md" 'exact issue'
    require_literal "$skill_md" 'title, description'
    require_literal "$skill_md" 'state'
    require_literal "$skill_md" 'acceptance criteria'
    require_literal "$skill_md" 'as-built comments'
    require_literal "$skill_md" 'complete content of every changed file'
    require_literal "$skill_md" 'AGENTS.md'
    require_literal "$skill_md" 'CLAUDE.md'

    # Backward compatibility: auto, PR, uncommitted, staged, docs-ticket,
    # Linear URL/id, branch, commit, and unrecognized-argument modes.
    require_literal "$skill_md" 'git status --porcelain'
    require_literal "$skill_md" '--pr <number>'
    require_literal "$skill_md" '--uncommitted'
    require_literal "$skill_md" '--staged'
    require_literal "$skill_md" 'docs/tickets/'
    require_literal "$skill_md" 'linear.app'
    require_literal "$skill_md" '^[A-Za-z]+-\d+$'
    require_literal "$skill_md" \
      'local or remote branch with this exact name also exists'
    require_literal "$skill_md" 'legacy branch mode'
    require_literal "$skill_md" 'git rev-parse --verify --quiet'
    require_literal "$skill_md" 'Anything else'
  done

  require_literal "$claude_root/review-ticket/SKILL.md" \
    '/review-ticket --ticket TAI-90 --base main'
  require_literal "$claude_root/review-ticket/SKILL.md" \
    '/review-ticket --ticket TAI-90               # Same, resolving the default main/master base'
  require_literal "$codex_root/review-ticket/SKILL.md" \
    '$cktk:review-ticket --ticket TAI-90 --base main'
  require_literal "$codex_root/review-ticket/SKILL.md" \
    '$cktk:review-ticket --ticket TAI-90              # Same, using default main/master base resolution'
}

validate_update_agents_contract() {
  local skill="update-agents"
  local claude_skill_md="$claude_root/$skill/SKILL.md"
  local codex_skill_md="$codex_root/$skill/SKILL.md"
  local openai_yaml="$codex_root/$skill/agents/openai.yaml"
  local metadata_error
  local skill_md

  if ! metadata_error="$(RUBYOPT=--disable=gems ruby -e '
    require "yaml"

    claude_path, codex_path, yaml_path, expected_name = ARGV
    claude = YAML.load_file(claude_path)
    codex = YAML.load_file(codex_path)
    yaml = YAML.load_file(yaml_path)

    abort("Claude skill must be user-invocable") unless claude["user-invocable"] == true
    hint = claude["argument-hint"]
    abort("Claude skill must provide argument-hint") unless hint.is_a?(String) && !hint.empty?

    unexpected = codex.keys - %w[name description]
    abort("Codex frontmatter has unsupported keys: #{unexpected.join(", ")}") unless unexpected.empty?
    abort("Codex skill name mismatch") unless codex["name"] == expected_name

    short = yaml["interface"]["short_description"]
    abort("short_description must be 25-64 characters") unless (25..64).cover?(short.length)
    abort("default_prompt must mention $#{expected_name}") unless yaml["interface"]["default_prompt"].include?("$#{expected_name}")
    abort("write-heavy skill must be explicit-only") unless yaml["policy"]["allow_implicit_invocation"] == false
  ' "$claude_skill_md" "$codex_skill_md" "$openai_yaml" "$skill" 2>&1)"; then
    fail "invalid cross-agent metadata for $skill: $metadata_error"
  fi

  for skill_md in "$claude_skill_md" "$codex_skill_md"; do
    require_literal "$skill_md" "Portable interaction"
    require_literal "$skill_md" "Never assume an option limit"
    require_literal "$skill_md" "AGENTS.md"
    require_literal "$skill_md" "CLAUDE.md"
    require_literal "$skill_md" "Never commit"
    require_literal "$skill_md" "remember next time"
    forbid_literal "$skill_md" "AskUserQuestion"
    forbid_literal "$skill_md" "rely on \"Other\""
  done

  require_literal "$claude_skill_md" "/update-agents"
  require_literal "$codex_skill_md" '$update-agents'
  require_literal "$root/README.md" "/update-agents"
}

validate_clarify_contract
validate_interact_contract
validate_implement_contract
validate_ticket_delegation_contract
validate_worktree_linear_contract
validate_review_ticket_contract
validate_update_agents_contract

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

say "Validated ${#claude_skills[@]} skill(s) across Claude, Codex, and Antigravity."
