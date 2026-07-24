---
name: "review-ticket"
description: "Review code changes for bugs and ticket alignment. Use for prompts like review my diff, review this branch, review against main, review PR 42, review ticket 42, review Linear issue ENG-42, or review commit abc1234."
---

# Code Review

Review code changes for bugs, regressions, and ticket or Linear-issue mismatches using a structured priority system.

## Mode Detection

Parse any text that follows the skill invocation. Evaluate the rules in order — first match wins:

1. No trailing arguments: run `git status --porcelain`. If there are uncommitted changes, review those. Otherwise compare `HEAD` against the default branch.
2. `--pr <number>`: review the pull request diff from `gh pr diff <number>`.
3. `--uncommitted`: review staged and unstaged local changes only.
4. `--staged`: review staged changes only.
5. Bare ticket number such as `42`: review the current uncommitted changes against the matching ticket file under `docs/tickets/`. If none matches and the user meant an all-digit commit-hash prefix, tell them to pass a longer prefix.
6. A URL containing `linear.app`: Linear mode — extract the first path segment matching `[A-Za-z]+-\d+` (uppercase the team key) as `issue_id` and review uncommitted changes against that issue.
7. An id matching `^[A-Za-z]+-\d+$` such as `ENG-42` (case-insensitive): Linear mode with the uppercased-team-key `issue_id`. If a local or remote branch with this exact name also exists (`git show-ref`), ask the user once whether they meant the branch or the Linear issue.
8. An existing branch name (`git show-ref --verify --quiet "refs/heads/<arg>"` or `refs/remotes/origin/<arg>`): review `HEAD` against that branch using the merge base.
9. Anything `git rev-parse --verify --quiet "<arg>^{commit}"` resolves (full or short SHA, tag, `HEAD~2`): commit mode — review that single commit's diff.
10. Anything else: report the unrecognized argument and stop.

Linear mode requires Linear MCP; if its tools are missing, stop with a short setup hint — no API-key, CLI, or browser fallbacks. Read-only: never write to Linear.

## Gather Context

1. Produce the correct diff for the selected mode. In Linear mode the diff is the uncommitted changes, same as ticket mode. In commit mode use `git diff "<sha>^..<sha>"` (`git show <sha>` for a root commit; a merge diffs against its first parent — note that in the Mode line).
2. If the diff is empty, report that there is nothing to review and stop.
3. Read the full content of every changed file. In commit mode read files at the commit's version (`git show <sha>:<path>`) if the working tree has moved past that commit.
4. Read `AGENTS.md` files in the repo root and relevant subdirectories if they exist.
5. Also read `CLAUDE.md` files when present because some repos still keep local guidance there.
6. In ticket mode, read the matched ticket file and use it as extra review context. Treat deviations documented in its `## As-Built Notes` section as intentional context, not scope drift, unless they contradict an acceptance criterion.
7. In Linear mode, fetch the issue via Linear MCP read tools (exact identifier match; stop if missing or ambiguous) and use its title, description, state, and acceptance criteria as the ticket context. Treat deviations documented in an as-built comment on the issue as intentional context, not scope drift, unless they contradict an acceptance criterion.

## Review Instructions

1. Read `./references/review-guidelines.md` and apply the full rubric.
2. Focus on issues introduced by the diff, not pre-existing problems.
3. Only report findings that clearly meet the review rubric.
4. Assign a priority and confidence to each finding.
5. In ticket or Linear mode, also check acceptance criteria and scope alignment.

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
