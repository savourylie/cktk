---
name: review-ticket
description: "Review code changes for bugs and issues, including a committed feature branch against a base branch with Linear ticket context. Triggers on: /review-ticket, review code, review changes, review my diff, code review, find bugs, review uncommitted, review against main, review this branch, check my changes, review against ticket, review a Linear issue, review ENG-42, review Linear ticket against main, review this commit, review commit abc123"
user-invocable: true
---

# Code Review

Review code changes using structured guidelines and a priority system (P0-P3). Supports uncommitted changes, branch comparisons, pull requests, single commits, and alignment review against docs tickets or Linear issues. The explicit `--ticket <ID> [--base <branch>]` form combines a committed branch comparison with Linear issue context.

## Mode Detection

Determine what to review based on `$ARGUMENTS`. Evaluate the rules in order — first match wins:

1. **Explicit committed Linear branch: `--ticket <ID> [--base <branch>]`** — If either `--ticket` or `--base` occurs, parse only this flag form; never fall through to a legacy mode. Require `--ticket` exactly once with a value matching `^[A-Za-z]+-\d+$` (case-insensitive), normalize the team key to uppercase, and accept `--base` at most once. The two flags may appear in either order. Reject missing values, duplicate flags, positional tokens, and any other flag. This explicit form always means Linear, so do not run the branch/issue collision prompt. Resolve the base as described below, fetch the exact Linear issue, and review committed `HEAD` against the base with a merge-base diff. Staged and unstaged changes are intentionally outside this mode's diff.
2. **No arguments** — Auto-detect: run `git status --porcelain`. If there are uncommitted changes (staged or unstaged), review those. Otherwise, detect the default branch (`main` or `master`) and review `HEAD` against it.
3. **`--pr <number>`** — PR mode: fetch the diff with `gh pr diff <number>`.
4. **`--uncommitted`** — Explicitly review only uncommitted changes (`git diff` + `git diff --cached`).
5. **`--staged`** — Review only staged changes (`git diff --cached`).
6. **Ticket number** (bare integer, e.g., `42`) — Ticket mode: review uncommitted changes against the ticket spec at `docs/tickets/<number>-*.md`. Glob for the file since the description suffix varies. If no matching ticket file is found, report the error and stop (if the user meant an all-digit commit-hash prefix, tell them to pass a longer prefix).
7. **Linear issue URL** (a URL containing `linear.app`) — Linear mode: extract the first path segment matching `[A-Za-z]+-\d+` and uppercase the team key to get `issue_id`. If none is found, report the error and stop. Review uncommitted changes (`git diff` + `git diff --cached`) against the Linear issue.
8. **Linear issue id** (matches `^[A-Za-z]+-\d+$`, e.g., `ENG-42`, case-insensitive) — Legacy Linear mode with `issue_id` set to the uppercased-team-key form. Review uncommitted changes, preserving the existing behavior. **Collision guard:** if a local or remote branch with this exact name also exists (check `git show-ref`), ask the user one question — compare against that branch, or review against the Linear issue — and proceed with their answer.
9. **Branch name** — the sole argument names an existing branch, resolved with the branch-resolution rules below: compare committed `HEAD` against it using the merge base.
10. **Commit** — `git rev-parse --verify --quiet "$ARG^{commit}"` resolves (full or short SHA, tag, `HEAD~2`, …): commit mode — review that single commit's diff.
11. **Anything else** — report the unrecognized argument and stop. Legacy modes accept exactly the argument shape shown above; reject unsupported extra arguments rather than guessing.

### Argument Errors for the Explicit Flag Form

Use concise, actionable errors and stop:

- Missing ticket value: `--ticket requires a Linear issue ID like TAI-90.`
- Invalid ticket value: `Invalid --ticket value '<value>'; expected a Linear issue ID like TAI-90.`
- Missing base value: `--base requires a branch name.`
- `--base` without `--ticket`: `--base is only supported with --ticket <ID>.`
- Duplicate flags or extra tokens: `Unsupported argument '<value>'; expected --ticket <ID> [--base <branch>].`

### Base Branch Resolution

Use the same resolution for the legacy branch mode and the explicit `--base` form:

1. Validate the branch value with `git check-ref-format --branch`; reject an invalid name.
2. Prefer the exact local ref `refs/heads/<branch>`.
3. Otherwise use `refs/remotes/origin/<branch>` as `origin/<branch>`.
4. If neither exists, report `Base branch '<branch>' was not found locally or on origin.` and stop.

When `--base` is omitted, preserve the existing default-branch behavior: try `main`, then `master`, resolving each with the same local-then-`origin` rules. If neither resolves, report that no default `main` or `master` branch was found and ask the user to pass `--base <branch>`.

**Linear mode prerequisite:** Linear MCP must be available and authenticated in the host agent (official server: `https://mcp.linear.app/mcp`, documented at https://linear.app/docs/mcp). If no Linear MCP tools are available, stop and tell the user to configure Linear MCP. Do **not** invent API-key, CLI, or browser workarounds. This skill only ever **reads** from Linear (get / list / search) — it never creates, updates, comments on, or assigns issues.

## Gather Context

1. Run the appropriate git diff command for the detected mode:
   - Explicit `--ticket` + base and legacy branch modes: compute `merge_base=$(git merge-base "$base_ref" HEAD)` and use `git diff "$base_ref"...HEAD`, which is equivalent to diffing from that merge base through `HEAD`. If no merge base exists, report the two refs have no common ancestor and stop.
   - Legacy bare-id/URL Linear and docs-ticket modes: use the uncommitted changes (`git diff` + `git diff --cached`).
   - Commit mode: use `git diff "<sha>^..<sha>"`; if `<sha>^` does not resolve (root commit), use `git show <sha>` instead. For merge commits `<sha>^` is the first parent, so the diff is the merge's net effect against its first parent — note this in the Mode line.
   - Other modes retain their commands from Mode Detection.

   If any selected diff is empty, report that there is nothing to review and stop before loading ticket context or changed files.
2. Identify all files changed in the diff.
3. Read the complete content of every changed file to understand surrounding code and context. In explicit `--ticket` + base and legacy branch modes, read the committed `HEAD` version when the working tree differs. In commit mode, read files at the commit's version (`git show <sha>:<path>`) when the working tree has moved past that commit. This keeps full-file context aligned with the selected diff.
4. Read every applicable `AGENTS.md` and `CLAUDE.md`: start at the repository root, then check each ancestor directory down to every changed file's directory. Review findings must respect all instructions whose scope covers a changed file.
5. **Ticket mode only:** Read the matched ticket file from `docs/tickets/`. Use its requirements, acceptance criteria, and description as additional review context. Evaluate whether the uncommitted changes correctly and completely implement what the ticket specifies. If the ticket contains an `## As-Built Notes` section, treat deviations documented there as intentional, agreed context — not scope drift — but still flag any documented deviation that contradicts an acceptance criterion.
6. **Both Linear modes:** Require authenticated Linear MCP read tools. If they are absent or unavailable, report `Linear MCP is unavailable; configure and authenticate the Linear MCP tools, then retry.` and stop — do not use API-key, CLI, browser, or fuzzy local fallbacks. Fetch the exact issue by `issue_id` with the Linear MCP tools and require an exact identifier match; if it is missing or ambiguous, report that and stop. Capture the issue's title, description/body, state, priority, labels, and acceptance criteria (checklists or a labeled section in the body). List the issue's comments and capture any as-built comments. Use all of that as ticket context. Treat deviations documented in an as-built comment as intentional, agreed context — not scope drift — unless they contradict an acceptance criterion.

## Review Instructions

1. Read `references/review-guidelines.md` (located next to this SKILL.md) and apply ALL guidelines strictly.
2. Focus exclusively on issues **introduced in the diff**. Do not flag pre-existing problems.
3. For each potential finding, evaluate it against the 8 bug detection criteria. Only include it if all criteria are met.
4. Assign each finding a **priority** (P0-P3) and a **confidence** score (0-100%).
5. Only report findings with confidence >= 70%.
6. **Ticket and both Linear modes:** In addition to bug and regression detection, evaluate:
   - Does the diff implement what the ticket/issue describes?
   - Are there acceptance criteria in the ticket/issue that are not addressed by the changes?
   - Are there changes that go beyond or contradict the ticket/issue scope?

## Output Format

Present the review in this exact structure:

```
## Code Review

**Mode**: [uncommitted | staged | branch: HEAD vs {base} (merge-base) | PR #{number} | ticket: #N (filename) | linear: {ISSUE-ID} ({title}), uncommitted | Linear ticket {ISSUE-ID} against {base} (merge-base) | commit: {short-sha} ({subject})]
**Files reviewed**: [count]
**Verdict**: [Correct | Incorrect] — confidence: [X]%

### Findings

#### [P1] Title of finding (max 80 chars, imperative mood)
**File**: `path/to/file.ext` (lines 42-47) — Confidence: 92%

One paragraph explaining why this is a bug, what scenarios trigger it,
and what impact it has.

` ` `suggestion
// concrete fix if applicable — minimal lines, no commentary
` ` `

---

(repeat for each finding, ordered by priority then confidence)

### Ticket Alignment (ticket and Linear modes)
**Ticket**: `docs/tickets/42-user-auth.md`   (ticket mode)
**Issue**: ENG-42 — {title}                  (Linear mode; include the issue URL if known)

- [x] Requirement A — implemented in `file.ts`
- [ ] Requirement B — not addressed in current changes
- [x] Requirement C — implemented in `other.ts`

### Summary
[1-3 sentences justifying the verdict. State what was checked.
If no issues found, explain what categories were examined.]
```

If no findings meet the confidence threshold:

```
## Code Review

**Mode**: [mode]
**Files reviewed**: [count]
**Verdict**: Correct — confidence: [X]%

### No Issues Found

Reviewed [count] files for bugs, security issues, logic errors,
and CLAUDE.md compliance. No issues met the reporting threshold.

### Summary
[Brief description of what was checked and why the changes look correct.]
```

## Behavioral Rules

- **Prefer silence over noise.** If unsure whether something is a real bug, do not report it. False positives erode trust.
- **Large diffs (500+ lines):** Prioritize the highest-risk files first (security-sensitive, core logic, data handling). Review all files but allocate attention proportionally to risk.
- **CLAUDE.md compliance:** If project guidelines exist, check adherence — but only flag violations that are clearly called out in the CLAUDE.md, not loose interpretations.
- **After initial review:** Switch to conversational mode for follow-up questions, explanations, or discussion. Respond in plain text.
- **Re-review:** If the user says "re-review", "review again", or "rerun", produce the full structured output format again.
- **No fix generation unless asked.** The review identifies issues. Only generate fixes if the user explicitly asks.

## Usage Examples

```
/review-ticket                    # Auto-detect: uncommitted changes or branch diff
/review-ticket main               # Compare HEAD against main
/review-ticket --pr 42            # Review pull request #42
/review-ticket --uncommitted      # Explicitly review uncommitted changes
/review-ticket --staged           # Review only staged changes
/review-ticket 42                 # Review uncommitted changes against ticket #42
/review-ticket ENG-42             # Review uncommitted changes against Linear issue ENG-42
/review-ticket https://linear.app/acme/issue/ENG-42/add-export   # Same, via issue URL
/review-ticket --ticket TAI-90 --base main   # Review committed HEAD vs main with Linear ticket context
/review-ticket --ticket TAI-90               # Same, resolving the default main/master base
/review-ticket abc1234            # Review a single commit's diff
/review-ticket HEAD~1             # Any commit-ish that isn't a branch works
```
