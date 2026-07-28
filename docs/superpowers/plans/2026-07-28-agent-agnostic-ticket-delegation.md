# Agent-Agnostic Ticket Delegation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the two CKTK ticket-implementation skills delegate implementation to Codex, Claude Code, or Grok Build, then have the invoking host independently verify and review the result.

**Architecture:** A shared shell adapter accepts an explicit executor allowlist and a prepared task file, launches the chosen CLI in the pinned worktree, bounds the wait, and records the outcome. The existing Claude and Codex skill documents parse `via <executor>`, prepare the task input after branch/worktree setup, invoke the adapter for Phase 4, and preserve the current build/review/landing phases.

**Tech Stack:** Markdown skills, POSIX-compatible Bash, existing CKTK shell-test conventions.

## Global Constraints

- Scope is limited to `implement-ticket` and `implement-ticket-linear`.
- Supported target executors are exactly `codex`, `claude`, and `grok` in this release.
- Invocation syntax is `<ticket> [worktree] [base] via <executor>`; `via` is case-insensitive and must be final.
- No `via` clause must preserve the current native implementation workflow.
- The delegated agent may implement only; it must not commit, push, merge, delete a worktree, or change ticket status.
- The invoking host remains responsible for build verification, ticket-specific review, remediation, as-built notes, and landing.
- Keep Claude source skills and separate Codex-native skills synchronized; Antigravity links to Claude skill folders.

---

### Task 1: Add a tested delegation adapter

**Files:**
- Create: `skills/ticket-delegation/scripts/run-ticket-executor.sh`
- Create: `scripts/test-ticket-delegation.sh`
- Modify: `.agents/skills/implement-ticket/scripts` (symlink to the shared script directory)
- Modify: `.agents/skills/implement-ticket-linear/scripts` (symlink to the shared script directory)

**Interfaces:**
- Consumes: `--executor <codex|claude|grok> --work-dir <absolute-dir> --task-file <absolute-file> --record-file <absolute-file> [--timeout-seconds <positive-int>]`.
- Produces: exit `0` only when the target CLI exits successfully; a record file with `executor`, `status`, `exit_code`, `started_at`, `finished_at`, and `output_file` fields.
- Error exits: `2` invalid arguments, `3` unsupported executor, `4` missing CLI, `5` timeout, otherwise the target process exit code.

- [ ] **Step 1: Write the failing adapter tests**

Add isolated temporary-directory fixtures in `scripts/test-ticket-delegation.sh`. Put fake `codex`, `claude`, and `grok` executables at the front of `PATH`; each fake records its received arguments and optionally returns a configured exit code. Add assertions for:

```bash
run_adapter codex success
assert_contains "$record" '"executor":"codex"'
assert_contains "$record" '"status":"completed"'
assert_contains "$fake_log" 'exec'

run_adapter unsupported success
assert_exit 3
assert_contains "$stderr" 'unsupported executor: unsupported'

PATH="$empty_path" run_adapter claude success
assert_exit 4
assert_contains "$stderr" 'Claude Code CLI is not installed'
```

Also add tests proving a non-zero target result is recorded as `failed`, a sleeping fake process is recorded as `timed_out`, and a task file is passed through stdin or the chosen documented non-interactive prompt interface without shell interpolation.

- [ ] **Step 2: Run the test script to verify failure**

Run: `bash scripts/test-ticket-delegation.sh`

Expected: FAIL because `run-ticket-executor.sh` does not exist.

- [ ] **Step 3: Implement the adapter**

Create `run-ticket-executor.sh` with strict shell mode. Parse only the declared flags, resolve `work-dir`, `task-file`, and `record-file` to existing absolute paths, and reject all executor strings except `codex`, `claude`, and `grok`.

Define these immutable command templates in one `case` block, with the task content supplied as a file/standard-input channel rather than concatenated shell text:

```bash
case "$executor" in
  codex)  command -v codex >/dev/null || missing_cli "Codex CLI" ; command=(codex exec --cd "$work_dir") ;;
  claude) command -v claude >/dev/null || missing_cli "Claude Code CLI" ; command=(claude --print --dangerously-skip-permissions) ;;
  grok)   command -v grok >/dev/null || missing_cli "Grok Build CLI" ; command=(grok) ;;
esac
```

Before invocation, create the record directory and an adjacent output file with restrictive permissions. Invoke the selected command from `work-dir`, capture stdout/stderr into the output file, and use the portable `timeout` command when available; otherwise start a watchdog that terminates only the spawned process group at the configured limit. Atomically write the JSON record after completion. Never invoke `eval`, never accept a free-form command, and never delete the target worktree.

- [ ] **Step 4: Run the adapter tests to verify success**

Run: `bash scripts/test-ticket-delegation.sh`

Expected: PASS for success, invalid argument, unsupported executor, absent CLI, target failure, and timeout fixtures.

- [ ] **Step 5: Commit the adapter**

```bash
git add skills/ticket-delegation/scripts/run-ticket-executor.sh \
  scripts/test-ticket-delegation.sh \
  .agents/skills/implement-ticket/scripts \
  .agents/skills/implement-ticket-linear/scripts
git commit -m "feat: add ticket delegation executor adapter"
```

### Task 2: Add `via` parsing and delegation to the document-ticket skill

**Files:**
- Modify: `skills/implement-ticket/SKILL.md`
- Modify: `.agents/skills/implement-ticket/SKILL.md`
- Modify: `README.md`
- Modify: `scripts/check-codex-skills.sh`

**Interfaces:**
- Consumes: existing argument grammar plus final `via <executor>` pair.
- Produces: `executor` unset for native runs, or one of `codex`, `claude`, `grok` for delegated runs.
- Depends on: `run-ticket-executor.sh` from Task 1.

- [ ] **Step 1: Add failing static consistency checks**

Extend `scripts/check-codex-skills.sh` with assertions for both implement-ticket documents:

```bash
assert_contains "$skill_md" 'via <executor>'
assert_contains "$skill_md" 'run-ticket-executor.sh'
assert_contains "$skill_md" 'must not commit, push, merge, delete a worktree, or change ticket status'
```

Add README checks or examples for `implement-ticket 003 worktree via claude`, `implement-ticket 003 via codex`, and `implement-ticket 003 dev via grok`.

- [ ] **Step 2: Run the checker to verify failure**

Run: `bash scripts/check-codex-skills.sh`

Expected: FAIL because neither skill document nor README describes the new executor clause.

- [ ] **Step 3: Update both skill documents**

In each `implement-ticket` document:

1. Extend the frontmatter description and grammar table with the final `via <executor>` clause.
2. Parse `via` before interpreting a trailing base token. Reject duplicate clauses, missing executor, unknown executor, and tokens after the executor.
3. Preserve all existing branch/worktree behavior after removing the `via` pair from the argument token list.
4. After Phase 3 and before native Phase 4 edits, write a task file under `$WORK_DIR/.ai/cktk/delegation/` containing the ticket requirements, PRD/design paths, explicit working directory, relevant test expectations, and the implementation-only boundary.
5. Invoke the shared adapter only when `executor` is set. On success, inspect `git status --porcelain`; if it is empty, report that no reviewable implementation was produced and stop. On adapter failure, report the preserved work location and record path, then stop without committing or discarding.
6. On successful changed worktree, resume the existing Phase 5 build and ticket-review flow unchanged.

Use Codex-native phrasing and tool conventions in `.agents/skills/implement-ticket/SKILL.md`; do not copy the Claude document verbatim.

- [ ] **Step 4: Update the user documentation**

Add the three `via` examples to the ticket-workflow section in `README.md`, state that `via` is optional and final, list the supported executors, and state that the invoking agent independently verifies and reviews before any landing choice.

- [ ] **Step 5: Run the static checker and inspect the diff**

Run: `bash scripts/check-codex-skills.sh && git diff --check`

Expected: PASS with matching Claude/Codex coverage and no whitespace errors.

- [ ] **Step 6: Commit the document-ticket integration**

```bash
git add skills/implement-ticket/SKILL.md .agents/skills/implement-ticket/SKILL.md \
  README.md scripts/check-codex-skills.sh
git commit -m "feat: delegate implement-ticket through CLI agents"
```

### Task 3: Add `via` parsing and delegation to the Linear-ticket skill

**Files:**
- Modify: `skills/implement-ticket-linear/SKILL.md`
- Modify: `.agents/skills/implement-ticket-linear/SKILL.md`
- Modify: `README.md`
- Modify: `scripts/check-codex-skills.sh`

**Interfaces:**
- Consumes: a Linear issue identifier plus the same final `via <executor>` clause.
- Produces: the same adapter request as Task 2, with Linear issue content included in the task file.
- Depends on: Tasks 1 and 2.

- [ ] **Step 1: Add failing Linear-specific checks**

Extend `scripts/check-codex-skills.sh` to require both Linear documents to include `via <executor>`, the shared adapter reference, and a statement that the pre-implementation Linear state transition stays in the host workflow rather than being delegated.

- [ ] **Step 2: Run the checker to verify failure**

Run: `bash scripts/check-codex-skills.sh`

Expected: FAIL because the Linear documents do not yet contain the required delegation contract.

- [ ] **Step 3: Update the Linear skill documents**

Mirror the exact parser and failure contract from Task 2. Keep the existing host-owned Linear behavior intact: load the issue, move Todo to In Progress when the current skill requires it, and perform any opt-in final comment/status action only after host-side review and landing selection.

Build the adapter task file from the Linear issue title, description, acceptance criteria, repository requirements, and design source. Do not include MCP credentials, raw connector tokens, or instructions to update Linear in the delegated prompt. Resume the existing Linear build/review flow only after a successful adapter exit and a non-empty reviewable change set.

Use a distinct Codex-native document in `.agents/skills/implement-ticket-linear/SKILL.md`.

- [ ] **Step 4: Update README coverage**

Add `implement-ticket-linear ENG-42 via codex` as an example and clarify that the same `via` clause applies to both ticket skill families.

- [ ] **Step 5: Run validation**

Run: `bash scripts/check-codex-skills.sh && bash scripts/test-ticket-delegation.sh && git diff --check`

Expected: all checks PASS.

- [ ] **Step 6: Commit the Linear-ticket integration**

```bash
git add skills/implement-ticket-linear/SKILL.md \
  .agents/skills/implement-ticket-linear/SKILL.md README.md \
  scripts/check-codex-skills.sh
git commit -m "feat: delegate Linear ticket implementation"
```

### Task 4: Perform end-to-end documentation and tree validation

**Files:**
- Modify: `catalog.json` only if its descriptions need explicit `via` discovery text.
- Modify: `.agent/skills/implement-ticket` and `.agent/skills/implement-ticket-linear` only if their symlinks are missing or stale.

**Interfaces:**
- Consumes: completed adapter and all six Claude/Codex skill documents.
- Produces: valid three-tree layout and reproducible verification evidence.

- [ ] **Step 1: Inspect all three skill trees**

Run:

```bash
for skill in implement-ticket implement-ticket-linear; do
  test -f "skills/$skill/SKILL.md"
  test -f ".agents/skills/$skill/SKILL.md"
  test -L ".agent/skills/$skill"
done
```

Expected: every assertion succeeds; repair only a missing/stale link rather than copying a `SKILL.md`.

- [ ] **Step 2: Run complete verification**

Run:

```bash
bash scripts/test-ticket-delegation.sh
bash scripts/check-codex-skills.sh
git diff --check
git status --short
```

Expected: the two tests and diff check pass; status contains only intended final changes.

- [ ] **Step 3: Review the final documentation paths**

Confirm the README links/users can discover the new syntax and that every skill’s grammar, adapter invocation, no-change stop, and host-side review contract are stated consistently.

- [ ] **Step 4: Commit any final metadata correction**

```bash
git add catalog.json .agent/skills README.md
git commit -m "docs: document ticket delegation support"
```

Skip this commit when no metadata or documentation changes remain after Task 3.

## As-Implemented Notes (2026-07-28)

- The user explicitly requested ready-to-commit status, so every commit step above was skipped.
- The current repository validator treats every top-level `skills/` directory as a user-facing skill. To avoid creating an incomplete `ticket-delegation` skill, the shared adapter lives at `skills/implement-ticket/scripts/run-ticket-executor.sh`; `implement-ticket-linear/scripts` and both Codex script directories are symlinks to that canonical support material.
- The adapter adds required `--host <codex|claude|grok>` validation, rejects delegation back to the current host, and uses exit `6` for a successful no-change stop and exit `7` for a changed branch/HEAD.
- No-change detection fingerprints staged, unstaged, and untracked reviewable state before and after execution, excluding only the run diagnostics. This lets an existing dirty worktree remain resumable without allowing a no-op target to claim the user's prior changes. Branch/HEAD mutation checks run after success, failure, and timeout and take precedence in the outcome record.
- Raw target exit codes are preserved, so callers read the record's `status` field rather than assigning meaning from a numeric exit alone.
- Installed Grok Build CLI help documents `--prompt-file` for headless file input, so its fixed template uses `grok --cwd <work-dir> --permission-mode bypassPermissions --prompt-file <package>` instead of the interactive bare `grok` command.
