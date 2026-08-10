---
name: "review-ticket"
description: "Review code changes for bugs and ticket alignment, including committed feature branches checked against a base branch and an exact Linear issue. Use for prompts like review my diff, review this branch, review against main, review PR 42, review ticket 42, review Linear issue ENG-42, review Linear ticket TAI-90 against main, or review commit abc1234."
---

# Code Review

Review code changes for bugs, regressions, and ticket or Linear-issue mismatches using a structured priority system. The explicit `$cktk:review-ticket --ticket TAI-90 --base main` form reviews a committed feature branch against a base while checking the exact Linear ticket.

## Mode Detection

Parse any text that follows the skill invocation. Evaluate the rules in order — first match wins:

1. Explicit committed Linear branch, `--ticket <ID> [--base <branch>]`: if either named flag occurs, parse only this form and never fall through. Require `--ticket` exactly once with a value matching `^[A-Za-z]+-\d+$` (case-insensitive), uppercase its team key, and accept `--base` at most once. Allow the flags in either order. Reject missing values, duplicate flags, extra positional tokens, and unsupported flags. This form unambiguously selects Linear, even if an identically named branch exists. Resolve the base below, fetch the exact Linear issue, and review committed `HEAD` against the base; exclude staged and unstaged changes.
2. No trailing arguments: run `git status --porcelain`. If there are uncommitted changes, review those. Otherwise compare `HEAD` against the default branch.
3. `--pr <number>`: review the pull request diff from `gh pr diff <number>`.
4. `--uncommitted`: review staged and unstaged local changes only.
5. `--staged`: review staged changes only.
6. Bare ticket number such as `42`: review the current uncommitted changes against the matching ticket file under `docs/tickets/`. If none matches and the user meant an all-digit commit-hash prefix, tell them to pass a longer prefix.
7. A URL containing `linear.app`: legacy Linear mode — extract the first path segment matching `[A-Za-z]+-\d+` (uppercase the team key) as `issue_id` and review uncommitted changes against that issue.
8. An id matching `^[A-Za-z]+-\d+$` such as `ENG-42` (case-insensitive): legacy Linear mode with the uppercased-team-key `issue_id`, preserving uncommitted review. If a local or remote branch with this exact name also exists (`git show-ref`), ask the user once whether they meant the branch or the Linear issue.
9. An existing branch name resolved below: review committed `HEAD` against that branch using the merge base.
10. Anything `git rev-parse --verify --quiet "<arg>^{commit}"` resolves (full or short SHA, tag, `HEAD~2`): commit mode — review that single commit's diff.
11. Anything else: report the unrecognized argument and stop. Legacy modes accept exactly their existing argument shape; reject unsupported extra arguments rather than guessing.

### Explicit Flag Errors

Stop with a concise actionable error:

- `--ticket requires a Linear issue ID like TAI-90.`
- `Invalid --ticket value '<value>'; expected a Linear issue ID like TAI-90.`
- `--base requires a branch name.`
- `--base is only supported with --ticket <ID>.`
- `Unsupported argument '<value>'; expected --ticket <ID> [--base <branch>].`

### Base Branch Resolution

Use this existing local-then-remote convention for branch mode and `--base`:

1. Validate the value with `git check-ref-format --branch`.
2. Prefer exact local `refs/heads/<branch>`.
3. Otherwise resolve `refs/remotes/origin/<branch>` as `origin/<branch>`.
4. Otherwise stop with `Base branch '<branch>' was not found locally or on origin.`

If `--base` is omitted, preserve default-branch behavior: try `main`, then `master`, with the same resolution. If neither resolves, report that no default `main` or `master` branch was found and ask for `--base <branch>`.

Linear mode requires Linear MCP; if its tools are missing, stop with a short setup hint — no API-key, CLI, or browser fallbacks. Read-only: never write to Linear.

## Gather Context

1. Produce the correct diff:
   - Explicit `--ticket` + base and legacy branch modes: compute `merge_base=$(git merge-base "$base_ref" HEAD)` and use `git diff "$base_ref"...HEAD`. If the refs have no common ancestor, report that and stop.
   - Bare-id/URL Linear and docs-ticket modes: use uncommitted changes, as before.
   - Commit mode: use `git diff "<sha>^..<sha>"` (`git show <sha>` for a root commit; a merge diffs against its first parent — note that in the Mode line).
   - Other modes retain the command specified in Mode Detection.
2. If the selected diff is empty, report that there is nothing to review and stop before loading issue or file context.
3. Read the complete content of every changed file. In explicit `--ticket` + base and legacy branch modes, read the committed `HEAD` version if the working tree differs. In commit mode, read the commit's version (`git show <sha>:<path>`) if the working tree has moved past it.
4. Read every applicable `AGENTS.md` and `CLAUDE.md`: start at the repository root and check each ancestor directory down to every changed file's directory.
5. In ticket mode, read the matched ticket file and use it as extra review context. Treat deviations documented in its `## As-Built Notes` section as intentional context, not scope drift, unless they contradict an acceptance criterion.
6. In both Linear modes, require authenticated Linear MCP read tools. If unavailable, stop with `Linear MCP is unavailable; configure and authenticate the Linear MCP tools, then retry.` Do not use API-key, CLI, browser, or fuzzy local fallbacks. Fetch the exact issue identifier (stop if missing or ambiguous), then capture its title, description, state, acceptance criteria, and supporting priority and labels. List its comments and capture any as-built comments. Use all of this as ticket context; treat documented deviations as intentional unless they contradict an acceptance criterion.

## Review Instructions

1. Read `./references/review-guidelines.md` and apply the full rubric.
2. Focus on issues introduced by the diff, not pre-existing problems.
3. Only report findings that clearly meet the review rubric.
4. Assign a priority and confidence to each finding.
5. In ticket or either Linear mode, also check acceptance criteria and scope alignment.

## Output Format

Use this structure:

````markdown
## Code Review

**Mode**: [mode; for the new form use `Linear ticket {ISSUE-ID} against {base} (merge-base)`]
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

## Usage Examples

```text
$cktk:review-ticket                              # Auto-detect uncommitted changes or default-base branch diff
$cktk:review-ticket main                         # Compare committed HEAD against main; no Linear context
$cktk:review-ticket --pr 42                      # Review pull request 42
$cktk:review-ticket --uncommitted                # Review staged and unstaged changes
$cktk:review-ticket --staged                     # Review staged changes only
$cktk:review-ticket 42                           # Review uncommitted changes against docs ticket 42
$cktk:review-ticket TAI-90                       # Review uncommitted changes against Linear issue TAI-90
$cktk:review-ticket --ticket TAI-90 --base main  # Review committed HEAD vs main against Linear issue TAI-90
$cktk:review-ticket --ticket TAI-90              # Same, using default main/master base resolution
$cktk:review-ticket abc1234                      # Review one commit
```

## Behavior Rules

- Prefer silence over noise.
- For large diffs, spend the most attention on high-risk files.
- After the main review, switch back to plain conversational follow-up if the user asks questions.
- If the user asks to re-review, run the full structured review again.
