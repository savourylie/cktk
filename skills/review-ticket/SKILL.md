---
name: review-ticket
description: "Review code changes for bugs and issues. Triggers on: /review-ticket, review code, review changes, review my diff, code review, find bugs, review uncommitted, review against main, review this branch, check my changes, review against ticket"
user-invocable: true
---

# Code Review

Review code changes using structured guidelines and a priority system (P0-P3). Supports uncommitted changes, branch comparisons, and pull requests.

## Mode Detection

Determine what to review based on `$ARGUMENTS`:

1. **No arguments** — Auto-detect: run `git status --porcelain`. If there are uncommitted changes (staged or unstaged), review those. Otherwise, detect the default branch (`main` or `master`) and review `HEAD` against it.
2. **Branch name** (e.g., `main`, `develop`) — Compare current HEAD against the given branch using `git diff $(git merge-base $BRANCH HEAD)..HEAD`.
3. **`--pr <number>`** — PR mode: fetch the diff with `gh pr diff <number>`.
4. **`--uncommitted`** — Explicitly review only uncommitted changes (`git diff` + `git diff --cached`).
5. **`--staged`** — Review only staged changes (`git diff --cached`).
6. **Ticket number** (bare integer, e.g., `42`) — Ticket mode: review uncommitted changes against the ticket spec at `docs/tickets/<number>-*.md`. Glob for the file since the description suffix varies. If no matching ticket file is found, report the error and stop.

## Gather Context

1. Run the appropriate git diff command for the detected mode. If the diff is empty, tell the user there are no changes to review and stop.
2. Identify all files changed in the diff.
3. Read the full content of each changed file to understand surrounding code and context.
4. Check for CLAUDE.md files in the repo root and in each directory containing changed files. If found, read them — review findings should respect any project-specific guidelines they contain.
5. **Ticket mode only:** Read the matched ticket file from `docs/tickets/`. Use its requirements, acceptance criteria, and description as additional review context. Evaluate whether the uncommitted changes correctly and completely implement what the ticket specifies. If the ticket contains an `## As-Built Notes` section, treat deviations documented there as intentional, agreed context — not scope drift — but still flag any documented deviation that contradicts an acceptance criterion.

## Review Instructions

1. Read `references/review-guidelines.md` (located next to this SKILL.md) and apply ALL guidelines strictly.
2. Focus exclusively on issues **introduced in the diff**. Do not flag pre-existing problems.
3. For each potential finding, evaluate it against the 8 bug detection criteria. Only include it if all criteria are met.
4. Assign each finding a **priority** (P0-P3) and a **confidence** score (0-100%).
5. Only report findings with confidence >= 70%.
6. **Ticket mode only:** In addition to bug detection, evaluate:
   - Does the diff implement what the ticket describes?
   - Are there acceptance criteria in the ticket that are not addressed by the changes?
   - Are there changes that go beyond or contradict the ticket scope?

## Output Format

Present the review in this exact structure:

```
## Code Review

**Mode**: [uncommitted | staged | branch: HEAD vs {base} | PR #{number} | ticket: #N (filename)]
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

### Ticket Alignment (ticket mode only)
**Ticket**: `docs/tickets/42-user-auth.md`

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
```
