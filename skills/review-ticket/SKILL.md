---
name: review-ticket
description: "Review code changes for bugs and issues. Triggers on: /review-ticket, review code, review changes, review my diff, code review, find bugs, review uncommitted, review against main, review this branch, check my changes, review against ticket, review a Linear issue, review ENG-42, review this commit, review commit abc123"
user-invocable: true
---

# Code Review

Review code changes using structured guidelines and a priority system (P0-P3). Supports uncommitted changes, branch comparisons, pull requests, single commits, and alignment review against docs tickets or Linear issues.

## Mode Detection

Determine what to review based on `$ARGUMENTS`. Evaluate the rules in order — first match wins:

1. **No arguments** — Auto-detect: run `git status --porcelain`. If there are uncommitted changes (staged or unstaged), review those. Otherwise, detect the default branch (`main` or `master`) and review `HEAD` against it.
2. **`--pr <number>`** — PR mode: fetch the diff with `gh pr diff <number>`.
3. **`--uncommitted`** — Explicitly review only uncommitted changes (`git diff` + `git diff --cached`).
4. **`--staged`** — Review only staged changes (`git diff --cached`).
5. **Ticket number** (bare integer, e.g., `42`) — Ticket mode: review uncommitted changes against the ticket spec at `docs/tickets/<number>-*.md`. Glob for the file since the description suffix varies. If no matching ticket file is found, report the error and stop (if the user meant an all-digit commit-hash prefix, tell them to pass a longer prefix).
6. **Linear issue URL** (a URL containing `linear.app`) — Linear mode: extract the first path segment matching `[A-Za-z]+-\d+` and uppercase the team key to get `issue_id`. If none is found, report the error and stop. Review uncommitted changes (`git diff` + `git diff --cached`) against the Linear issue.
7. **Linear issue id** (matches `^[A-Za-z]+-\d+$`, e.g., `ENG-42`, case-insensitive) — Linear mode with `issue_id` set to the uppercased-team-key form. **Collision guard:** if a local or remote branch with this exact name also exists (check `git show-ref`), ask the user one question — compare against that branch, or review against the Linear issue — and proceed with their answer.
8. **Branch name** — the argument names an existing branch (`git show-ref --verify --quiet "refs/heads/$ARG"`, or `refs/remotes/origin/$ARG`): compare current HEAD against it using `git diff $(git merge-base $ARG HEAD)..HEAD`.
9. **Commit** — `git rev-parse --verify --quiet "$ARG^{commit}"` resolves (full or short SHA, tag, `HEAD~2`, …): commit mode — review that single commit's diff.
10. **Anything else** — report the unrecognized argument and stop.

**Linear mode prerequisite:** Linear MCP must be available and authenticated in the host agent (official server: `https://mcp.linear.app/mcp`, documented at https://linear.app/docs/mcp). If no Linear MCP tools are available, stop and tell the user to configure Linear MCP. Do **not** invent API-key, CLI, or browser workarounds. This skill only ever **reads** from Linear (get / list / search) — it never creates, updates, comments on, or assigns issues.

## Gather Context

1. Run the appropriate git diff command for the detected mode. If the diff is empty, tell the user there are no changes to review and stop. For Linear mode the diff is the uncommitted changes (`git diff` + `git diff --cached`), same as ticket mode. For commit mode use `git diff "<sha>^..<sha>"`; if `<sha>^` does not resolve (root commit), use `git show <sha>` instead. For merge commits `<sha>^` is the first parent, so the diff is the merge's net effect against its first parent — note this in the Mode line.
2. Identify all files changed in the diff.
3. Read the full content of each changed file to understand surrounding code and context. In commit mode, read changed files at the commit's version (`git show <sha>:<path>`) when the working tree has moved past that commit, so the context matches what was committed.
4. Check for CLAUDE.md files in the repo root and in each directory containing changed files. If found, read them — review findings should respect any project-specific guidelines they contain.
5. **Ticket mode only:** Read the matched ticket file from `docs/tickets/`. Use its requirements, acceptance criteria, and description as additional review context. Evaluate whether the uncommitted changes correctly and completely implement what the ticket specifies. If the ticket contains an `## As-Built Notes` section, treat deviations documented there as intentional, agreed context — not scope drift — but still flag any documented deviation that contradicts an acceptance criterion.
6. **Linear mode only:** Fetch the issue by `issue_id` via Linear MCP (search/list/get as available; prefer an exact identifier match). If the issue is not found or the match is ambiguous, report and stop. Capture the title, description/body, state, priority, labels, and acceptance criteria (checklists or a labeled section in the body). Use them as the ticket requirements and evaluate whether the uncommitted changes correctly and completely implement what the issue specifies. Also list the issue's comments: if a previous `/implement-ticket-linear` run posted an as-built comment, treat deviations documented there as intentional, agreed context — not scope drift — but still flag any documented deviation that contradicts an acceptance criterion.

## Review Instructions

1. Read `references/review-guidelines.md` (located next to this SKILL.md) and apply ALL guidelines strictly.
2. Focus exclusively on issues **introduced in the diff**. Do not flag pre-existing problems.
3. For each potential finding, evaluate it against the 8 bug detection criteria. Only include it if all criteria are met.
4. Assign each finding a **priority** (P0-P3) and a **confidence** score (0-100%).
5. Only report findings with confidence >= 70%.
6. **Ticket and Linear modes:** In addition to bug detection, evaluate:
   - Does the diff implement what the ticket/issue describes?
   - Are there acceptance criteria in the ticket/issue that are not addressed by the changes?
   - Are there changes that go beyond or contradict the ticket/issue scope?

## Output Format

Present the review in this exact structure:

```
## Code Review

**Mode**: [uncommitted | staged | branch: HEAD vs {base} | PR #{number} | ticket: #N (filename) | linear: {ISSUE-ID} ({title}) | commit: {short-sha} ({subject})]
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
/review-ticket abc1234            # Review a single commit's diff
/review-ticket HEAD~1             # Any commit-ish that isn't a branch works
```
