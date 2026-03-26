---
name: "review-ticket"
description: "Review code changes for bugs and ticket alignment. Use for prompts like review my diff, review this branch, review against main, review PR 42, or review ticket 42."
---

# Code Review

Review code changes for bugs, regressions, and ticket mismatches using a structured priority system.

## Mode Detection

Parse any text that follows the skill invocation. Support these modes:

1. No trailing arguments: run `git status --porcelain`. If there are uncommitted changes, review those. Otherwise compare `HEAD` against the default branch.
2. Branch name such as `main` or `develop`: review `HEAD` against that branch using the merge base.
3. `--pr <number>`: review the pull request diff from `gh pr diff <number>`.
4. `--uncommitted`: review staged and unstaged local changes only.
5. `--staged`: review staged changes only.
6. Bare ticket number such as `42`: review the current uncommitted changes against the matching ticket file under `docs/tickets/`.

## Gather Context

1. Produce the correct diff for the selected mode.
2. If the diff is empty, report that there is nothing to review and stop.
3. Read the full content of every changed file.
4. Read `AGENTS.md` files in the repo root and relevant subdirectories if they exist.
5. Also read `CLAUDE.md` files when present because some repos still keep local guidance there.
6. In ticket mode, read the matched ticket file and use it as extra review context.

## Review Instructions

1. Read `./references/review-guidelines.md` and apply the full rubric.
2. Focus on issues introduced by the diff, not pre-existing problems.
3. Only report findings that clearly meet the review rubric.
4. Assign a priority and confidence to each finding.
5. In ticket mode, also check acceptance criteria and scope alignment.

## Output Format

Use this structure:

````markdown
## Code Review

**Mode**: [mode]
**Files reviewed**: [count]
**Verdict**: [Correct | Incorrect] - confidence: [X]%

### Findings

#### [P1] Title of finding
**File**: `path/to/file.ext` (lines 42-47) - Confidence: 92%

One paragraph explaining the bug, when it triggers, and why it matters.

```suggestion
// minimal concrete fix if applicable
```
````

If no issues meet the reporting threshold, use a "No Issues Found" section instead.

## Behavior Rules

- Prefer silence over noise.
- For large diffs, spend the most attention on high-risk files.
- After the main review, switch back to plain conversational follow-up if the user asks questions.
- If the user asks to re-review, run the full structured review again.
