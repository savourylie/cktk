---
name: clarify-ticket-linear
description: "Clarify a Linear issue before implementation. Use only when the request names Linear, a TEAM-NUMBER issue id, a linear.app issue URL, or the clarify-ticket-linear skill; do not use for docs/tickets/ or TICKET-NNN markdown tickets. Fetch the issue through read-only Linear MCP tools, analyze it against relevant code when available, discuss ambiguities and risks, and produce a readiness summary. Never modify Linear, repo files, or git."
user-invocable: true
disable-model-invocation: true
argument-hint: "[issue-id-or-url]"
---

**Invocation input:** `$ARGUMENTS`

# Clarify a Linear Issue (advisory, read-only)

Fetch one Linear issue, analyze its requirements and risks against relevant code when available, discuss unresolved details with the user, and end with a readiness summary. **Never** modify Linear, repository files, or git.

Use Linear as the ticket source of truth. Do not use `docs/tickets/`.

## Portable interaction rules

- Resolve the issue reference from populated invocation input when available; otherwise use the identifier or URL in the surrounding user request. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- When the user must select or confirm something, show every candidate with a stable issue id/path and distinguishing label.
- Use the host's structured choice mechanism only when available and suitable. Otherwise ask a concise numbered prose question and accept an issue id, number, or path.
- Never assume an option limit or an automatically supplied “Other” choice.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites and argument grammar

Require authenticated Linear MCP read tools. Discover the host's actual read-tool schemas instead of inventing names or fields. If unavailable, stop with a short setup hint; do not use HTTP, API-key, CLI, or browser fallbacks.

Accept one optional `<issue>`:

| Input | Meaning |
| --- | --- |
| `ENG-42` or another `TEAM-NUMBER` id | Clarify that issue; uppercase the team key. |
| A Linear issue URL containing an id | Extract and clarify that issue. |
| Empty | Auto-detect from a git branch or registered worktree. |

Reject status tokens, multi-issue batches, title-only searches, write/commit flags, invalid refs, and extra tokens.

## Phase 1: Resolve the Issue Reference

1. Parse the populated invocation input or surrounding user request before requiring a repository.
2. If an id or URL is present:
   - Normalize `^[A-Za-z]+-\d+$` by uppercasing the team key.
   - For a URL, extract a complete `TEAM-NUMBER` path token; fail if none exists.
3. Probe git without making it mandatory:
   - If `git rev-parse --is-inside-work-tree` succeeds, set `REPO_AVAILABLE=true` and compute:
     ```
     MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
     CURRENT_ROOT=$(git rev-parse --show-toplevel)
     ```
   - Otherwise set `REPO_AVAILABLE=false`; do not run further git commands.
4. If the issue ref is still empty:
   - Without a repo, stop and request an issue id or URL.
   - With a repo, inspect the current branch for `^linear-([A-Za-z]+-\d+)-.+$`.
   - Otherwise inspect registered worktrees under `$MAIN_ROOT/.worktrees/` for branches matching that pattern.
   - One candidate → use it. Multiple candidates → apply the portable interaction rules. None → stop and request an issue id or URL.

## Phase 2: Fetch the Linear Issue (read-only)

1. Fetch by exact normalized identifier through available Linear MCP read tools. Missing or ambiguous → stop.
2. If an old identifier resolves to an issue with a new canonical identifier, use the canonical identifier and disclose the alias.
3. Capture:
   - Canonical id, title, URL, and full description
   - Workflow state name and state type when available
   - Team, priority, labels, project, and cycle when present
   - `blocked by`, `blocks`, and related relations
   - Comments when read tools expose them
   - Acceptance criteria from checklist items or a clearly labeled section
   - Repository links, project guidance, referenced paths, or other clues about the intended codebase
4. For every blocker, obtain its state type when the initial relation payload omits it and another read call can provide it.
5. Classify blockers conservatively:
   - State type `completed` → satisfied.
   - Any other known state type → unsatisfied while the `blocked by` relation remains.
   - Missing/unknown type → do not infer completion; report it as unresolved and treat it as blocking until confirmed.
6. Derive `slug` from the title: lowercase, replace non-alphanumerics with `-`, collapse repeats, trim, and truncate to about 40 characters; fallback `issue`.

## Phase 3: Resolve and Validate Code Context

If `REPO_AVAILABLE=false`, set `ANALYSIS_MODE=text-only` and continue without computing worktree handles.

If a repo is available:

1. Compute expected handles:
   - `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`
   - `linear-<issue_id>-<slug>`
2. Choose a candidate `WORK_DIR`:
   - A worktree already selected during auto-detection
   - `$CURRENT_ROOT` when its branch matches `^linear-<issue_id>-.+$`
   - Exact registered worktree path
   - A unique registered worktree path starting with `$MAIN_ROOT/.worktrees/<issue_id>-`
   - Otherwise `$CURRENT_ROOT`
3. Check whether the issue is plausibly associated with the candidate repo using issue links/path references, project guidance, `git remote get-url origin`, repo basename, and manifests:
   - Clear match → set `ANALYSIS_MODE=code`.
   - Clear mismatch → disclose it and ask whether to use this repo, supply another repo, or continue text-only. Do not make code-grounded claims before confirmation.
   - No useful repo clue → disclose the assumption and ask for confirmation before code-grounded analysis. The user may choose text-only instead.
4. Record whether code context is confirmed, user-confirmed, or text-only.

## Phase 4: Read Project Context

Skip this phase in text-only mode.

Within `WORK_DIR`:

1. Read applicable repository guidance before analysis:
   - Root `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or equivalent host/project instruction files
   - More deeply scoped instruction files when they apply to likely affected paths
2. Read `docs/PRD.md` when present.
3. Read the relevant design source when present, in order:
   - `docs/DESIGN.md`
   - `docs/design/DESIGN.md`
   - Relevant files in `design-system/` or `docs/design-system/`
4. Treat conflicts between Linear, repository guidance, PRD, design, and code as details to confirm or risks.

## Phase 5: Analyze Details and Risks

Use read-only tools and safe read-only shell commands. Produce five buckets plus a verdict.

Frame the analysis with the four types of unknowns:

- **Known knowns** — what the issue states; verify these against the code when available.
- **Known unknowns** — gaps the issue admits; turn each into an open question.
- **Unknown knowns** — details obvious to the user but unwritten; elicit these in the guided discussion.
- **Unknown unknowns** — factors nobody has considered; hunt these in the Blind spots bucket.

### Details to confirm

List ambiguity, undefined terms, missing/untestable acceptance criteria, inconsistent issue fields/comments, and requirement conflicts. Explain why each matters.

### Risks

Tag each risk `high`, `medium`, or `low`.

- In code mode, cite `path:line` evidence for likely files/modules, divergent patterns, missing prerequisites, migration/compatibility concerns, and acceptance-criteria feasibility.
- In text-only mode, make no codebase claims. Cite precise sources such as `issue description`, `Acceptance Criterion 2`, `comment by <name/date>`, or `blocked-by relation <ID>`.

### Blind spots

Deliberately hunt what the issue does not mention.

- In code mode, check each category against the actual code and cite `path:line`: adjacent code paths that depend on the areas this issue changes, ignored error and edge paths, data-shape changes with migration/backfill/rollback implications, implicit conventions from project guidance or dominant patterns, and test surface.
- In text-only mode, make no codebase claims. Limit blind spots to gaps in the issue text itself — unspecified error handling, missing rollout or migration mention, undefined edge cases — citing Linear sources such as `issue description` or `Acceptance Criterion 2`.

If no category produces a finding, record "No blind spots found" — never silently omit the bucket.

### Dependencies

List:

- `blocked by` relations with state name, state type, and satisfaction result
- Issues this issue blocks
- Code-level prerequisites in code mode

### Open questions

List only questions unresolved by the issue, comments, relations, project context, and code evidence available in the selected analysis mode.

### Readiness verdict

- `ready` — well specified, risks understood, and no unsatisfied/unknown blockers
- `needs-clarification` — unresolved requirements or untestable criteria prevent a confident start
- `blocked` — an unsatisfied/unknown `blocked by` relation or another hard blocker prevents starting

Text-only mode may still be `ready` for specification quality, but state explicitly that code feasibility was not assessed.

## Phase 6: Present the Briefing

Present before discussion:

```
## Clarification Briefing — <ISSUE-ID>: <title>
**Readiness:** <ready | needs-clarification | blocked>
**Analysis mode:** <code: confirmed path | code: user-confirmed path | text-only>

### Details to confirm
- ...

### Risks
- [high] ... — evidence: `<path:line | Linear source>`

### Blind spots
- <category>: ... — evidence: `<path:line | Linear source>` (or "No blind spots found")

### Dependencies
- blocked by <ISSUE> (<state name>, <state type>, <satisfied | unsatisfied | unknown>) ...

### Open questions
1. ...
```

## Phase 7: Guided Discussion

Open with two calibration questions, asked one at a time before the open items:

1. **Unknown knowns** — "What's obvious to you about this issue that isn't written down?" Fold answers into resolved details, risks, or blind spots.
2. **Experience calibration** — "How familiar are you with the code or systems this issue touches?" Scale later explanations to the answer: more background when familiarity is low, terser confirmation when high.

Then walk substantive open items one topic at a time using the portable interaction rules. Batch trivial confirmations. Record each outcome as:

- **Resolved here** — capture the user's decision.
- **Still open** — retain it for the issue author or another external source.

If there are no open items beyond the two calibration questions, proceed directly to the summary after asking them.

## Phase 8: Readiness Summary

Present on screen only:

```
## Clarification Summary — <ISSUE-ID>
**Verdict:** <ready to implement | needs author input | blocked by <...>>
**Analysis mode:** <code | text-only>

**Resolved**
- ...

**Open questions for the author**
- ... (or "none")

**Key risks to watch during implementation**
- [severity] ...

**Suggested next step**
- Use implement-ticket-linear with <ISSUE-ID>, or resolve the blockers/questions first.
```

## Safety rules

- Use only Linear MCP read operations. Never change state, description, comments, acceptance criteria, assignee, labels, project, or any other Linear field.
- Stay read-only in the repository: no file edits, commits, mutating shell commands, or destructive commands.
- Do not use `docs/tickets/` as the ticket source.
- Do not invoke `implement-ticket-linear`, `update-ticket-linear`, `commit-ticket`, or `commit-push-pr`; only suggest a next step.
- Never present an unconfirmed or mismatched repo as code-grounded evidence.
- Missing tools, ambiguous issues, or unknown blocker state must never be guessed.
