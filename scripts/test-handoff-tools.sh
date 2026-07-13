#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exporter="$root/skills/codex-handoff/scripts/codex-handoff.sh"
grok_exporter="$root/skills/grok-handoff/scripts/grok-handoff.sh"
opencode_exporter="$root/skills/opencode-handoff/scripts/opencode-handoff.sh"
finder="$root/skills/takeover/scripts/find-handoff.sh"
installer="$root/scripts/install-global-handoff-tools.sh"
all_agent_installer="$root/scripts/install-all-agent-skills.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/cktk-handoff-test.XXXXXX")"
tmp="$(cd "$tmp" && pwd -P)"
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

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_symlink() {
  [[ -L "$1" ]] || fail "expected symlink: $1"
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "did not expect '$unexpected' in $file"
  fi
}

init_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name "Handoff Test"
  git -C "$repo" config user.email "handoff@example.com"
  printf 'base\n' >"$repo/tracked.txt"
  git -C "$repo" add tracked.txt
  git -C "$repo" commit -qm "initial"
}

# Models Claude Code's projects/<key> derivation (every non-alphanumeric -> "-",
# for the <=200 char case). Intentionally does NOT share the exporter's regex, so
# the fixture lands where Claude actually writes it and a mismatched exporter regex
# would fail the test.
project_key() {
  python3 - "$1" <<'PY'
import re
import sys

print(re.sub(r"[^A-Za-z0-9]", "-", sys.argv[1]))
PY
}

write_session() {
  local path="$1"
  local prefix="$2"
  local count="$3"
  local i

  : >"$path"
  for ((i = 1; i <= count; i++)); do
    printf '{"type":"user","message":"%s-%d"}\n' "$prefix" "$i" >>"$path"
  done
}

[[ -x "$exporter" ]] || fail "exporter is not executable: $exporter"
[[ -x "$grok_exporter" ]] || fail "grok exporter is not executable: $grok_exporter"
[[ -x "$finder" ]] || fail "takeover finder is not executable: $finder"
[[ -x "$installer" ]] || fail "global installer is not executable: $installer"
[[ -x "$all_agent_installer" ]] || fail "all-agent installer is not executable: $all_agent_installer"

no_session_repo="$tmp/no-session"
empty_claude="$tmp/empty-claude"
init_repo "$no_session_repo"
mkdir -p "$empty_claude"
if (
  cd "$no_session_repo"
  CLAUDE_CONFIG_DIR="$empty_claude" "$exporter"
) >"$tmp/no-session.out" 2>"$tmp/no-session.err"; then
  fail "exporter unexpectedly succeeded without a Claude session"
fi
assert_contains "$tmp/no-session.err" "No Claude Code session found"
[[ ! -e "$no_session_repo/.ai/handoffs/latest.json" ]] ||
  fail "no-session failure created latest.json"
[[ ! -d "$no_session_repo/.ai/handoffs" ]] ||
  fail "no-session failure created a handoff directory"
pass "exporter fails cleanly when no Claude session exists"

repo="$tmp/project_with punctuation"
claude_config="$tmp/claude-config"
init_repo "$repo"
printf 'unstaged change\n' >>"$repo/tracked.txt"
printf 'staged change\n' >"$repo/staged.txt"
git -C "$repo" add staged.txt
printf 'untracked-body-MARKER\n' >"$repo/untracked.txt"

key="$(project_key "$repo")"
project_dir="$claude_config/projects/$key"
mkdir -p "$project_dir"
write_session "$project_dir/old-session.jsonl" "old" 2
write_session "$project_dir/new-session.jsonl" "new" 5
python3 - "$project_dir/old-session.jsonl" "$project_dir/new-session.jsonl" <<'PY'
import os
import sys

os.utime(sys.argv[1], (1_700_000_000, 1_700_000_000))
os.utime(sys.argv[2], (1_800_000_000, 1_800_000_000))
PY
mkdir -p "$project_dir/new-session/subagents"
printf '{"type":"assistant","message":"subagent"}\n' \
  >"$project_dir/new-session/subagents/agent-1.jsonl"
printf '{"metadata":true}\n' >"$project_dir/new-session/subagents/agent-1.meta.json"
mkdir -p "$repo/nested/work"

if (
  cd "$repo/nested/work"
  CLAUDE_CONFIG_DIR="$claude_config" "$exporter" --target ..
) >"$tmp/invalid-target.out" 2>"$tmp/invalid-target.err"; then
  fail "exporter accepted a target agent that escapes the output directory"
fi
assert_contains "$tmp/invalid-target.err" "--target contains unsupported characters"

(
  cd "$repo/nested/work"
  CLAUDE_CONFIG_DIR="$claude_config" "$exporter" --tail-lines 3
) >"$tmp/export.out" 2>"$tmp/export.err"

bundle="$(tail -n 1 "$tmp/export.out")"
[[ "$bundle" = "$repo"/.ai/handoffs/codex/*-claude ]] ||
  fail "unexpected bundle path: $bundle"
assert_contains "$tmp/export.err" "is not ignored by git"
for name in \
  HANDOFF.json \
  TAKEOVER.md \
  source-session.jsonl \
  source-session-tail.jsonl \
  git-status.txt \
  git-diff-stat.txt \
  git-diff.patch \
  git-log.txt; do
  assert_file "$bundle/$name"
done
assert_file "$repo/.ai/handoffs/latest.json"
assert_file "$bundle/subagents/agent-1.jsonl"
[[ ! -e "$bundle/subagents/agent-1.meta.json" ]] ||
  fail "exporter copied non-JSONL subagent metadata"
cmp "$project_dir/new-session.jsonl" "$bundle/source-session.jsonl" ||
  fail "full session copy differs"
[[ "$(wc -l <"$bundle/source-session-tail.jsonl" | tr -d ' ')" = "3" ]] ||
  fail "session tail does not contain 3 lines"
assert_contains "$bundle/source-session-tail.jsonl" "new-3"
assert_contains "$bundle/source-session-tail.jsonl" "new-5"
assert_not_contains "$bundle/source-session-tail.jsonl" "new-2"
assert_contains "$bundle/git-status.txt" "tracked.txt"
assert_contains "$bundle/git-status.txt" "staged.txt"
assert_contains "$bundle/git-status.txt" "untracked.txt"
assert_not_contains "$bundle/git-status.txt" ".ai/"
assert_contains "$bundle/git-diff-stat.txt" "tracked.txt"
assert_contains "$bundle/git-diff-stat.txt" "staged.txt"
assert_contains "$bundle/git-diff.patch" "unstaged change"
assert_contains "$bundle/git-diff.patch" "staged change"
# Untracked files' full content is appended to the patch (finding D).
assert_contains "$bundle/git-diff.patch" "untracked.txt"
assert_contains "$bundle/git-diff.patch" "untracked-body-MARKER"
assert_contains "$bundle/git-log.txt" "initial"
python3 - "$bundle" "$repo" <<'PY'
import json
import os
import sys

bundle, repo = sys.argv[1:]
with open(os.path.join(bundle, "HANDOFF.json"), encoding="utf-8") as handle:
    handoff = json.load(handle)
with open(os.path.join(repo, ".ai/handoffs/latest.json"), encoding="utf-8") as handle:
    latest = json.load(handle)

assert handoff["schema_version"] == "1.0"
assert handoff["target_agent"] == "codex"
assert handoff["source_agent"] == "claude"
assert handoff["repo_root"] == repo
assert handoff["status"] == "pending"
assert handoff["session"] == {
    "type": "claude-code-jsonl",
    "path": "source-session.jsonl",
    "tail_path": "source-session-tail.jsonl",
}
assert latest["schema_version"] == "1.0"
assert latest["target_agent"] == "codex"
assert latest["status"] == "pending"
assert os.path.normpath(os.path.join(repo, latest["handoff_dir"])) == bundle
PY

# Ignore both output dirs so this run does not pull the first run's bundle
# (under .ai/handoffs/) into its untracked-file patch.
printf 'custom-handoffs/\n.ai/handoffs/\n' >"$repo/.gitignore"
(
  cd "$repo/nested/work"
  CLAUDE_CONFIG_DIR="$claude_config" "$exporter" \
    --tail-lines 1 \
    --target codex-next \
    --source claude-code \
    --out custom-handoffs
) >"$tmp/custom-export.out" 2>"$tmp/custom-export.err"
custom_bundle="$(tail -n 1 "$tmp/custom-export.out")"
[[ "$custom_bundle" = "$repo"/custom-handoffs/codex-next/*-claude-code ]] ||
  fail "custom exporter flags produced an unexpected bundle: $custom_bundle"
assert_not_contains "$tmp/custom-export.err" "not ignored by git"
# The earlier run's bundle (ignored under .ai/handoffs/) must not leak into this patch.
assert_not_contains "$custom_bundle/git-diff.patch" "source-session"
[[ "$(wc -l <"$custom_bundle/source-session-tail.jsonl" | tr -d ' ')" = "1" ]] ||
  fail "custom tail length was not applied"
python3 - "$custom_bundle/HANDOFF.json" "$repo/custom-handoffs/latest.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    handoff = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    latest = json.load(handle)
assert handoff["target_agent"] == "codex-next"
assert handoff["source_agent"] == "claude-code"
assert latest["target_agent"] == "codex-next"
PY
pass "exporter creates a complete local handoff bundle"

# --- grok-handoff: sessionless export with agent summary ---
grok_repo="$tmp/grok-project"
init_repo "$grok_repo"
printf 'grok unstaged\n' >>"$grok_repo/tracked.txt"
printf 'summary body MARKER\n' >"$tmp/agent-summary.md"
(
  cd "$grok_repo"
  "$grok_exporter" --source codex --summary "$tmp/agent-summary.md" --no-session
) >"$tmp/grok-export.out" 2>"$tmp/grok-export.err"
grok_bundle="$(tail -n 1 "$tmp/grok-export.out")"
[[ "$grok_bundle" = "$grok_repo"/.ai/handoffs/grok/*-codex ]] ||
  fail "unexpected grok bundle path: $grok_bundle"
for name in \
  HANDOFF.json \
  TAKEOVER.md \
  agent-summary.md \
  git-status.txt \
  git-diff-stat.txt \
  git-diff.patch \
  git-log.txt; do
  assert_file "$grok_bundle/$name"
done
[[ ! -e "$grok_bundle/source-session.jsonl" ]] ||
  fail "sessionless grok export unexpectedly included a Claude session"
assert_contains "$grok_bundle/agent-summary.md" "summary body MARKER"
assert_contains "$grok_bundle/TAKEOVER.md" "agent-summary.md"
assert_contains "$grok_bundle/TAKEOVER.md" "Grok Build"
assert_contains "$tmp/grok-export.err" "is not ignored by git"
python3 - "$grok_bundle" "$grok_repo" <<'PY'
import json
import os
import sys

bundle, repo = sys.argv[1:]
with open(os.path.join(bundle, "HANDOFF.json"), encoding="utf-8") as handle:
    handoff = json.load(handle)
with open(os.path.join(repo, ".ai/handoffs/latest.json"), encoding="utf-8") as handle:
    latest = json.load(handle)

assert handoff["schema_version"] == "1.0"
assert handoff["target_agent"] == "grok"
assert handoff["source_agent"] == "codex"
assert handoff["repo_root"] == repo
assert handoff["status"] == "pending"
assert handoff["session"] == {"type": "none"}
assert handoff["summary_path"] == "agent-summary.md"
assert latest["target_agent"] == "grok"
assert latest["status"] == "pending"
assert os.path.normpath(os.path.join(repo, latest["handoff_dir"])) == bundle
PY
pass "grok-handoff creates a sessionless bundle with agent summary"

# --- grok-handoff: auto-attach Claude session when present ---
grok_claude_repo="$tmp/grok-claude-project"
grok_claude_config="$tmp/grok-claude-config"
init_repo "$grok_claude_repo"
printf 'session work\n' >>"$grok_claude_repo/tracked.txt"
grok_key="$(project_key "$grok_claude_repo")"
grok_project_dir="$grok_claude_config/projects/$grok_key"
mkdir -p "$grok_project_dir"
write_session "$grok_project_dir/session.jsonl" "gline" 4
printf 'claude summary\n' >"$tmp/claude-summary.md"
(
  cd "$grok_claude_repo"
  CLAUDE_CONFIG_DIR="$grok_claude_config" "$grok_exporter" \
    --source claude \
    --summary "$tmp/claude-summary.md" \
    --tail-lines 2
) >"$tmp/grok-session.out" 2>"$tmp/grok-session.err"
grok_session_bundle="$(tail -n 1 "$tmp/grok-session.out")"
[[ "$grok_session_bundle" = "$grok_claude_repo"/.ai/handoffs/grok/*-claude ]] ||
  fail "unexpected grok+claude bundle path: $grok_session_bundle"
assert_file "$grok_session_bundle/source-session.jsonl"
assert_file "$grok_session_bundle/source-session-tail.jsonl"
assert_file "$grok_session_bundle/agent-summary.md"
[[ "$(wc -l <"$grok_session_bundle/source-session-tail.jsonl" | tr -d ' ')" = "2" ]] ||
  fail "grok session tail does not contain 2 lines"
python3 - "$grok_session_bundle/HANDOFF.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    handoff = json.load(handle)
assert handoff["target_agent"] == "grok"
assert handoff["source_agent"] == "claude"
assert handoff["session"] == {
    "type": "claude-code-jsonl",
    "path": "source-session.jsonl",
    "tail_path": "source-session-tail.jsonl",
}
assert handoff["summary_path"] == "agent-summary.md"
PY

# --require-session fails cleanly with no Claude session
if (
  cd "$grok_repo"
  CLAUDE_CONFIG_DIR="$tmp/empty-claude" "$grok_exporter" --require-session --source claude
) >"$tmp/grok-require.out" 2>"$tmp/grok-require.err"; then
  fail "grok-handoff --require-session unexpectedly succeeded without a Claude session"
fi
assert_contains "$tmp/grok-require.err" "No Claude Code session found"
pass "grok-handoff attaches Claude sessions and enforces --require-session"

# --- opencode-handoff: sessionless export with agent summary ---
opencode_repo="$tmp/opencode-project"
init_repo "$opencode_repo"
printf 'opencode unstaged\n' >>"$opencode_repo/tracked.txt"
printf 'opencode summary body MARKER\n' >"$tmp/opencode-agent-summary.md"
(
  cd "$opencode_repo"
  "$opencode_exporter" --source codex --summary "$tmp/opencode-agent-summary.md" --no-session
) >"$tmp/opencode-export.out" 2>"$tmp/opencode-export.err"
opencode_bundle="$(tail -n 1 "$tmp/opencode-export.out")"
[[ "$opencode_bundle" = "$opencode_repo"/.ai/handoffs/opencode/*-codex ]] ||
  fail "unexpected opencode bundle path: $opencode_bundle"
for name in \
  HANDOFF.json \
  TAKEOVER.md \
  agent-summary.md \
  git-status.txt \
  git-diff-stat.txt \
  git-diff.patch \
  git-log.txt; do
  assert_file "$opencode_bundle/$name"
done
[[ ! -e "$opencode_bundle/source-session.jsonl" ]] ||
  fail "sessionless opencode export unexpectedly included a Claude session"
assert_contains "$opencode_bundle/agent-summary.md" "opencode summary body MARKER"
assert_contains "$opencode_bundle/TAKEOVER.md" "agent-summary.md"
assert_contains "$opencode_bundle/TAKEOVER.md" "OpenCode"
assert_contains "$tmp/opencode-export.err" "is not ignored by git"
python3 - "$opencode_bundle" "$opencode_repo" <<'PY'
import json
import os
import sys

bundle, repo = sys.argv[1:]
with open(os.path.join(bundle, "HANDOFF.json"), encoding="utf-8") as handle:
    handoff = json.load(handle)
with open(os.path.join(repo, ".ai/handoffs/latest.json"), encoding="utf-8") as handle:
    latest = json.load(handle)

assert handoff["schema_version"] == "1.0"
assert handoff["target_agent"] == "opencode"
assert handoff["source_agent"] == "codex"
assert handoff["repo_root"] == repo
assert handoff["status"] == "pending"
assert handoff["session"] == {"type": "none"}
assert handoff["summary_path"] == "agent-summary.md"
assert latest["target_agent"] == "opencode"
assert latest["status"] == "pending"
assert os.path.normpath(os.path.join(repo, latest["handoff_dir"])) == bundle
PY
pass "opencode-handoff creates a sessionless bundle with agent summary"

# --- opencode-handoff: auto-attach Claude session when present ---
opencode_claude_repo="$tmp/opencode-claude-project"
opencode_claude_config="$tmp/opencode-claude-config"
init_repo "$opencode_claude_repo"
printf 'session work\n' >>"$opencode_claude_repo/tracked.txt"
opencode_key="$(project_key "$opencode_claude_repo")"
opencode_project_dir="$opencode_claude_config/projects/$opencode_key"
mkdir -p "$opencode_project_dir"
write_session "$opencode_project_dir/session.jsonl" "oline" 4
printf 'claude summary for opencode\n' >"$tmp/opencode-claude-summary.md"
(
  cd "$opencode_claude_repo"
  CLAUDE_CONFIG_DIR="$opencode_claude_config" "$opencode_exporter" \
    --source claude \
    --summary "$tmp/opencode-claude-summary.md" \
    --tail-lines 2
) >"$tmp/opencode-session.out" 2>"$tmp/opencode-session.err"
opencode_session_bundle="$(tail -n 1 "$tmp/opencode-session.out")"
[[ "$opencode_session_bundle" = "$opencode_claude_repo"/.ai/handoffs/opencode/*-claude ]] ||
  fail "unexpected opencode+claude bundle path: $opencode_session_bundle"
assert_file "$opencode_session_bundle/source-session.jsonl"
assert_file "$opencode_session_bundle/source-session-tail.jsonl"
assert_file "$opencode_session_bundle/agent-summary.md"
[[ "$(wc -l <"$opencode_session_bundle/source-session-tail.jsonl" | tr -d ' ')" = "2" ]] ||
  fail "opencode session tail does not contain 2 lines"
python3 - "$opencode_session_bundle/HANDOFF.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    handoff = json.load(handle)
assert handoff["target_agent"] == "opencode"
assert handoff["source_agent"] == "claude"
assert handoff["session"] == {
    "type": "claude-code-jsonl",
    "path": "source-session.jsonl",
    "tail_path": "source-session-tail.jsonl",
}
assert handoff["summary_path"] == "agent-summary.md"
PY

# --require-session fails cleanly with no Claude session
if (
  cd "$opencode_repo"
  CLAUDE_CONFIG_DIR="$tmp/empty-claude" "$opencode_exporter" --require-session --source claude
) >"$tmp/opencode-require.out" 2>"$tmp/opencode-require.err"; then
  fail "opencode-handoff --require-session unexpectedly succeeded without a Claude session"
fi
assert_contains "$tmp/opencode-require.err" "No Claude Code session found"
pass "opencode-handoff attaches Claude sessions and enforces --require-session"

(
  cd "$repo"
  "$finder" --json
) >"$tmp/find.json"
python3 - "$tmp/find.json" "$bundle" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    found = json.load(handle)
assert found["handoff_dir"] == sys.argv[2]
assert found["status"] == "pending"
assert found["target_agent"] == "codex"
PY

(
  cd "$repo"
  "$finder" --handoff-dir "$bundle" --mark-in-progress --json
) >"$tmp/in-progress.json"
python3 - "$bundle/HANDOFF.json" "$repo/.ai/handoffs/latest.json" <<'PY'
import json
import sys

for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as handle:
        assert json.load(handle)["status"] == "in_progress"
PY

# A plain re-run resurfaces the in-progress handoff so an interrupted takeover
# can resume; the reported status reflects that it is already underway.
(
  cd "$repo"
  "$finder" --json
) >"$tmp/resume.json"
python3 - "$tmp/resume.json" "$bundle" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    found = json.load(handle)
assert found["handoff_dir"] == sys.argv[2]
assert found["status"] == "in_progress"
PY

# Re-marking an already in-progress handoff is idempotent (it would error if
# mark-in-progress still required a pending status).
(
  cd "$repo"
  "$finder" --handoff-dir "$bundle" --mark-in-progress --json
) >/dev/null

newer_bundle="$repo/.ai/handoffs/codex/newer-in-progress"
mkdir -p "$newer_bundle"
python3 - "$newer_bundle/HANDOFF.json" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(
        {
            "schema_version": "1.0",
            "target_agent": "codex",
            "source_agent": "claude",
            "created_at": "2099-01-01T00:00:00+00:00",
            "status": "in_progress",
        },
        handle,
        indent=2,
    )
    handle.write("\n")
PY

(
  cd "$repo"
  "$finder" --handoff-dir "$bundle" --mark-done --json
) >"$tmp/done.json"
python3 - \
  "$bundle/HANDOFF.json" \
  "$newer_bundle/HANDOFF.json" \
  "$repo/.ai/handoffs/latest.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    assert json.load(handle)["status"] == "done"
with open(sys.argv[2], encoding="utf-8") as handle:
    assert json.load(handle)["status"] == "in_progress"
with open(sys.argv[3], encoding="utf-8") as handle:
    assert json.load(handle)["status"] == "done"
PY
pass "takeover helper locates, resumes, and transitions handoff status"

# Drop the future-dated in-progress distractor so the fallback scan below
# deterministically resolves to the primary bundle once it is pending again.
rm -rf "$newer_bundle"

python3 - "$bundle/HANDOFF.json" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)
data["status"] = "pending"
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
os.replace(tmp, path)
PY
rm "$repo/.ai/handoffs/latest.json"
(
  cd "$repo"
  "$finder" --json
) >"$tmp/fallback.json"
python3 - "$tmp/fallback.json" "$bundle" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    assert json.load(handle)["handoff_dir"] == sys.argv[2]
PY
pass "takeover helper falls back to scanning handoff manifests"

install_home="$tmp/install-home"
mkdir -p "$install_home"
HOME="$install_home" PATH="/usr/bin:/bin" "$installer" \
  >"$tmp/install.out" 2>"$tmp/install.err"
assert_symlink "$install_home/.local/bin/codex-handoff"
assert_symlink "$install_home/.local/bin/grok-handoff"
assert_symlink "$install_home/.local/bin/opencode-handoff"
assert_symlink "$install_home/.local/bin/cktk-takeover"
[[ "$(readlink "$install_home/.local/bin/codex-handoff")" = "$exporter" ]] ||
  fail "codex-handoff symlink points to the wrong exporter"
[[ "$(readlink "$install_home/.local/bin/grok-handoff")" = "$grok_exporter" ]] ||
  fail "grok-handoff symlink points to the wrong exporter"
[[ "$(readlink "$install_home/.local/bin/opencode-handoff")" = "$opencode_exporter" ]] ||
  fail "opencode-handoff symlink points to the wrong exporter"
[[ "$(readlink "$install_home/.local/bin/cktk-takeover")" = "$finder" ]] ||
  fail "cktk-takeover symlink points to the wrong finder"
assert_contains "$tmp/install.out" "not currently in PATH"
HOME="$install_home" PATH="/usr/bin:/bin" "$installer" \
  >"$tmp/install-again.out" 2>"$tmp/install-again.err"

rm "$install_home/.local/bin/codex-handoff"
printf 'preserve me\n' >"$install_home/.local/bin/codex-handoff"
if HOME="$install_home" PATH="/usr/bin:/bin" "$installer" \
  >"$tmp/install-conflict.out" 2>"$tmp/install-conflict.err"; then
  fail "installer overwrote an unrelated regular file"
fi
assert_contains "$install_home/.local/bin/codex-handoff" "preserve me"
assert_contains "$tmp/install-conflict.err" "Refusing to overwrite"

rm "$install_home/.local/bin/codex-handoff"
ln -s /tmp/unrelated-handoff "$install_home/.local/bin/codex-handoff"
if HOME="$install_home" PATH="/usr/bin:/bin" "$installer" \
  >"$tmp/install-link-conflict.out" 2>"$tmp/install-link-conflict.err"; then
  fail "installer overwrote an unrelated symlink"
fi
[[ "$(readlink "$install_home/.local/bin/codex-handoff")" = "/tmp/unrelated-handoff" ]] ||
  fail "installer changed an unrelated symlink"
pass "global installer is safe, idempotent, and PATH-aware"

all_agents_home="$tmp/all-agents-home"
all_agents_codex_home="$tmp/all-agents-codex"
all_agents_project="$tmp/all-agents-project"
mkdir -p "$all_agents_home" "$all_agents_codex_home/skills"
init_repo "$all_agents_project"
printf 'do not touch\n' >"$all_agents_codex_home/skills/private-skill.txt"
HOME="$all_agents_home" CODEX_HOME="$all_agents_codex_home" PROJECT_ROOT="$all_agents_project" PATH="/usr/bin:/bin" \
  "$all_agent_installer" >"$tmp/all-agents.out" 2>"$tmp/all-agents.err"
assert_symlink "$all_agents_home/.local/bin/codex-handoff"
assert_symlink "$all_agents_home/.local/bin/grok-handoff"
assert_symlink "$all_agents_home/.local/bin/opencode-handoff"
assert_symlink "$all_agents_home/.local/bin/cktk-takeover"
[[ "$(readlink "$all_agents_home/.local/bin/codex-handoff")" = "$exporter" ]] ||
  fail "all-agent installer pointed codex-handoff at the wrong exporter"
[[ "$(readlink "$all_agents_home/.local/bin/grok-handoff")" = "$grok_exporter" ]] ||
  fail "all-agent installer pointed grok-handoff at the wrong exporter"
[[ "$(readlink "$all_agents_home/.local/bin/opencode-handoff")" = "$opencode_exporter" ]] ||
  fail "all-agent installer pointed opencode-handoff at the wrong exporter"
[[ "$(readlink "$all_agents_home/.local/bin/cktk-takeover")" = "$finder" ]] ||
  fail "all-agent installer pointed cktk-takeover at the wrong finder"
assert_symlink "$all_agents_codex_home/skills/takeover"
assert_symlink "$all_agents_codex_home/skills/codex-handoff"
assert_symlink "$all_agents_codex_home/skills/grok-handoff"
assert_symlink "$all_agents_codex_home/skills/opencode-handoff"
[[ "$(readlink "$all_agents_codex_home/skills/takeover")" = "$root/.agents/skills/takeover" ]] ||
  fail "Codex takeover symlink points to the wrong skill"
[[ "$(readlink "$all_agents_codex_home/skills/codex-handoff")" = "$root/.agents/skills/codex-handoff" ]] ||
  fail "Codex codex-handoff symlink points to the wrong skill"
[[ "$(readlink "$all_agents_codex_home/skills/grok-handoff")" = "$root/.agents/skills/grok-handoff" ]] ||
  fail "Codex grok-handoff symlink points to the wrong skill"
[[ "$(readlink "$all_agents_codex_home/skills/opencode-handoff")" = "$root/.agents/skills/opencode-handoff" ]] ||
  fail "Codex opencode-handoff symlink points to the wrong skill"
assert_contains "$all_agents_codex_home/skills/private-skill.txt" "do not touch"
assert_symlink "$all_agents_home/.agent/skills"
[[ "$(readlink "$all_agents_home/.agent/skills")" = "$root/.agent/skills" ]] ||
  fail "Antigravity global skills symlink points to the wrong tree"
assert_contains "$tmp/all-agents.out" "Codex skills"
assert_contains "$tmp/all-agents.out" "Antigravity skills"
assert_contains "$tmp/all-agents.out" "Shell helpers"
assert_contains "$all_agents_project/.gitignore" ".ai/handoffs/"
HOME="$all_agents_home" CODEX_HOME="$all_agents_codex_home" PATH="/usr/bin:/bin" \
  "$all_agent_installer" >"$tmp/all-agents-again.out" 2>"$tmp/all-agents-again.err"
stale_home="$tmp/stale-agents-home"
stale_codex_home="$tmp/stale-codex"
stale_tree="$tmp/stale-cktk/.agent/skills"
mkdir -p "$stale_home/.agent" "$stale_codex_home" "$stale_tree/cktk-upgrade"
printf -- '---\nname: cktk-upgrade\ndescription: stale fixture\n---\n' \
  >"$stale_tree/cktk-upgrade/SKILL.md"
ln -s "$stale_tree" "$stale_home/.agent/skills"
HOME="$stale_home" CODEX_HOME="$stale_codex_home" PATH="/usr/bin:/bin" \
  "$all_agent_installer" >"$tmp/stale-agents.out" 2>"$tmp/stale-agents.err"
assert_symlink "$stale_home/.agent/skills"
[[ "$(readlink "$stale_home/.agent/skills")" = "$root/.agent/skills" ]] ||
  fail "stale Antigravity skills symlink was not updated to the active cktk tree"
pass "all-agent installer reconciles global Codex, Antigravity, and shell surfaces"

for skill in codex-handoff grok-handoff opencode-handoff takeover; do
  assert_file "$root/skills/$skill/SKILL.md"
  assert_file "$root/.agents/skills/$skill/SKILL.md"
  assert_file "$root/.agents/skills/$skill/agents/openai.yaml"
  assert_symlink "$root/.agent/skills/$skill"
  [[ "$(readlink "$root/.agent/skills/$skill")" = "../../skills/$skill" ]] ||
    fail "wrong Antigravity symlink for $skill"
  assert_contains "$root/.agents/skills/$skill/agents/openai.yaml" \
    "allow_implicit_invocation: false"
done
assert_symlink "$root/.agents/skills/codex-handoff/scripts"
assert_symlink "$root/.agents/skills/grok-handoff/scripts"
assert_symlink "$root/.agents/skills/opencode-handoff/scripts"
assert_symlink "$root/.agents/skills/takeover/scripts"
assert_contains "$root/.agents/skills/codex-handoff/SKILL.md" \
  "You are already in Codex"
assert_contains "$root/.agents/skills/codex-handoff/SKILL.md" '$takeover'
assert_contains "$root/.agents/skills/grok-handoff/SKILL.md" "Grok Build"
assert_contains "$root/.agents/skills/grok-handoff/SKILL.md" '$grok-handoff'
assert_contains "$root/skills/grok-handoff/SKILL.md" "agent-summary"
assert_contains "$root/.agents/skills/opencode-handoff/SKILL.md" "OpenCode"
assert_contains "$root/.agents/skills/opencode-handoff/SKILL.md" '$opencode-handoff'
assert_contains "$root/skills/opencode-handoff/SKILL.md" "agent-summary"
assert_contains "$root/skills/takeover/SKILL.md" "untrusted"
assert_contains "$root/skills/takeover/SKILL.md" "agent-summary.md"
assert_contains "$root/.agents/skills/takeover/SKILL.md" "untrusted"
assert_contains "$root/.agents/skills/takeover/SKILL.md" "agent-summary.md"
pass "all three agent skill trees expose the handoff skills correctly"

python3 - "$root" <<'PY'
import json
import os
import sys

root = sys.argv[1]
for rel in (
    "catalog.json",
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
):
    with open(os.path.join(root, rel), encoding="utf-8") as handle:
        data = json.load(handle)
    if rel == ".claude-plugin/marketplace.json":
        assert data["plugins"][0]["version"] == "1.2.0"
    else:
        assert data["version"] == "1.2.0"

with open(os.path.join(root, "catalog.json"), encoding="utf-8") as handle:
    names = {skill["name"] for skill in json.load(handle)["skills"]}
assert {"codex-handoff", "grok-handoff", "opencode-handoff", "takeover"} <= names
PY
assert_contains "$root/README.md" '$takeover'
assert_contains "$root/README.md" "/codex-handoff"
assert_contains "$root/README.md" "/grok-handoff"
assert_contains "$root/README.md" '$grok-handoff'
assert_contains "$root/README.md" "/opencode-handoff"
assert_contains "$root/README.md" '$opencode-handoff'
assert_contains "$root/README.md" ".ai/handoffs/"
assert_contains "$root/README.md" "not compatible with archive-based"
assert_contains "$root/README.md" "install-all-agent-skills.sh"
assert_contains "$root/README.md" '${CODEX_HOME:-$HOME/.codex}/skills'
assert_not_contains "$root/README.md" ".agents/skills/codex-handoff"
assert_not_contains "$root/README.md" ".agents/skills/takeover"
assert_contains "$root/.gitignore" ".ai/handoffs/"
for upgrade_skill in \
  "$root/skills/cktk-upgrade/SKILL.md" \
  "$root/.agents/skills/cktk-upgrade/SKILL.md"; do
  assert_contains "$upgrade_skill" "Already up to date"
  assert_contains "$upgrade_skill" "install-all-agent-skills.sh"
  assert_contains "$upgrade_skill" "automatically"
  assert_not_contains "$upgrade_skill" "Apply recommended setup?"
done
pass "documentation and release metadata register the MVP"

printf '1..%d\n' "$tests"
