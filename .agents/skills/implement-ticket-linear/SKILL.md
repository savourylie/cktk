---
name: "implement-ticket-linear"
description: "Use when the user explicitly asks to implement a Linear issue (not docs/tickets markdown). The issue is implemented on its own branch, and the run ends by offering to merge it, open a PR, commit only, or leave it. Optionally pass a base branch, or `worktree` (with an optional base branch) to run inside an isolated git worktree. Prefer explicit invocation with $implement-ticket-linear. Requires Linear MCP."
---

# Implement a Linear Issue

Implement one Linear issue end to end: fetch it via Linear MCP, write the code, validate, and review. Treat this as an explicit workflow skill because it writes code and runs checks.

**This skill does not use `docs/tickets/`.** The Linear issue is the source of truth. It does **not** mutate Linear except for a single opt-in as-built comment (see Phase 7) — never status, assignee, or label changes. It commits git changes only when the user picks a landing option in Phase 8.

If the user included an issue id or URL after `$implement-ticket-linear`, implement that issue. Empty args are invalid — always require an id or URL.

## Portable interaction rules

This skill prompts the user three times — once if the working tree is dirty (Phase 3), once to offer the as-built comment (Phase 7), and once to land the work (Phase 8). All three follow these rules:

- Show every option with a stable number and a one-line description of what it does.
- Use the host's structured choice mechanism only when it is available and can represent the options clearly. Otherwise ask a concise numbered prose question and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous response as the documented default; never re-ask and never escalate.
- Refer to other skills by name, using `$skill-name` syntax when suggesting a command.

## Prerequisites

1. Linear MCP must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp).
2. If Linear MCP tools are missing, stop with a short setup hint. Do not invent API-key or CLI fallbacks.
3. Use only **read** Linear tools (get/list/search issue). Never call update/create/delete/assign. The only permitted write is the single opt-in as-built comment in Phase 7, posted only after explicit user confirmation.

## Argument grammar

Every invocation implements on a branch:

| Invocation | Meaning |
| --- | --- |
| `<issue>` | New branch off the current HEAD, in the current checkout. |
| `<issue> <base>` | New branch off `origin/<base>`, in the current checkout. |
| `<issue> worktree` | New branch off `origin/main`, inside an isolated worktree. |
| `<issue> worktree <base>` | New branch off `origin/<base>`, inside an isolated worktree. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Normalize team keys to uppercase. The `worktree` keyword is case-insensitive; only that exact word triggers worktree mode. Any other trailing token is read as a base branch and must resolve — check `git rev-parse --verify --quiet origin/<token>` then `git rev-parse --verify --quiet <token>`. If neither resolves, stop with "unrecognized argument '<token>' — did you mean 'worktree'? (no branch named '<token>' found locally or on origin)".

Not accepted: title-only search, status flags, commit flags, multi-issue batches, empty “next assigned” mode.

## Phase 1: Parse & Resolve

1. Parse args: `issue_ref` (required), `use_worktree`, `base_token` (the trailing non-`worktree` token, if any — validate it resolves as a branch per the argument grammar).
2. Normalize to `issue_id`:
   - `TEAM-NUM` pattern → uppercase team key
   - URL → extract first `TEAM-NUM` path segment; fail if none
3. Resolve main repo root:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```

## Phase 2: Fetch Linear Issue

1. Fetch by `issue_id` via Linear MCP. Exact match only; stop if missing or ambiguous.
2. Capture title, description, state, labels/project/priority, relations, and any acceptance criteria in the body.
3. Derive `slug` from the title: lowercase, non-alphanumerics → `-`, collapse, trim, ~40 chars. Fallback slug: `issue`.
4. Worktree path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`. Branch: `linear-<issue_id>-<slug>`.
5. If state is terminal (Done / Completed / Canceled / Cancelled / Duplicate), report and stop unless the user explicitly asked to re-implement (then confirm once). Still do not write to Linear.

## Phase 3: Working Directory and Branch

0. Resolve `base` — the branch Phase 8 will offer to merge into. Worktree mode: `base_token` if present, else `main`. Current checkout: `base_token` if present, else the current branch from `git rev-parse --abbrev-ref HEAD` — but if that current branch already **is** `linear-<issue_id>-<slug>` (you are resuming), a branch cannot be its own base and nothing on disk records what it forked from: ask once, per the portable interaction rules, offering the plausible bases that exist locally or on `origin`, and if the user declines, record no base and mark Phase 8's option 1 unavailable rather than guessing. Without this rule option 1 would merge the branch into itself — git reports "Already up to date" and exits 0, so the skill would claim a successful land while nothing reached the real base. If `git rev-parse --abbrev-ref HEAD` returns `HEAD` (detached), stop and ask for an explicit base branch.
1. If `use_worktree`:
   - Reuse an existing registered worktree at the path (dirty state is OK; note it later).
   - Else create inline — do **not** call `$create-worktree` (it requires markdown tickets):
     - Fetch `origin/<base>` when possible
     - Ensure `.worktrees/` is in `$MAIN_ROOT/.gitignore`
     - `git worktree add` with new or existing `linear-…` branch from the resolved base ref
   - `WORK_DIR =` worktree path. The branch already exists on it — skip step 4.
2. Else `WORK_DIR = $MAIN_ROOT` (or current toplevel if already on a purposeful worktree).
3. `cd "$WORK_DIR"` once. Prefix absolute file tools with `$WORK_DIR`.
4. Create or reuse `linear-<issue_id>-<slug>` (current checkout only). Never implement onto whatever branch happened to be checked out:
   - Already on it → reuse and report "resuming".
   - Exists but not checked out → `git switch linear-<issue_id>-<slug>`, report the reuse, do not rebase.
   - Otherwise: if `git status --porcelain` is non-empty, list the files, warn they will be carried onto the branch and may land in the commit, and ask "Continue? [y/N]" — anything but an explicit yes stops before the branch is created. Then `git switch -c linear-<issue_id>-<slug> origin/<base>` when a `base_token` was given (fetch first; fall back to local `<base>`; stop if neither ref exists), otherwise `git switch -c linear-<issue_id>-<slug>`. If the switch fails because local changes would be overwritten, report git's error and stop.
5. State in one sentence which branch you are on and where work is happening.

## Phase 4: Project Context (soft)

1. Read `$WORK_DIR/docs/PRD.md` if present.
2. Read design source if present (`docs/DESIGN.md`, `docs/design/DESIGN.md`, or a `design-system/` folder).
3. Missing PRD/design is non-fatal — Linear body is primary.
4. Skim `AGENTS.md` / `CLAUDE.md` / package manifests when present.

## Phase 5: Implement

1. State plan: issue id/title, files to touch, risks, acceptance criteria. If Linear shows an open blocker relation, stop and report.
2. Implement fully under `$WORK_DIR` against the issue and design context.
3. Follow project conventions; add tests when the repo has a suite or the issue implies testable behavior.

## Phase 6: Validate

1. Run lint, type-check, test, and build commands for the repo (cwd is `$WORK_DIR`).
2. Fix regressions introduced by the work.
3. Review pass against `$review-ticket` guidelines:
   - Prefer invoking `$review-ticket <issue_id>` when available — its Linear mode fetches the issue and checks acceptance-criteria alignment
   - Or read `../review-ticket/references/review-guidelines.md` and review only the ticket diff
   - Treat Linear title + description + AC as the requirements
4. Fix findings and re-check until build is clean and no P0/P1 remain.

## Phase 7: Summary (no commit; Linear write only by opt-in)

Stop after a clear summary:

1. Issue id, title, what changed
2. Deviations and follow-ups
3. Explicit note: **Linear status unchanged**, and **nothing committed** until the user picks an option in Phase 8
4. Manual testing steps
5. **Next step for Linear status:** when ready to mark the issue done (or move it), run `$update-ticket-linear <issue_id>` (optionally with an explicit status such as `done`). That skill evaluates acceptance criteria and writes back to Linear; this skill never changes Linear status (its only Linear write is the opt-in as-built comment).
6. **As-built comment (opt-in):** ask exactly once — "Post this as-built summary as a comment on <issue_id>? (y/N)", default no. Only an explicit yes posts one comment (deviations from spec and why, key decisions, follow-ups/tech debt; "None" where empty) via the Linear MCP comment tool. Never change any other Linear field.
7. If worktree mode: path, branch, and base. Note that `$merge-worktree` only understands markdown `TICKET-NNN` worktrees, so Phase 8 merges inline.

## Phase 8: Land the Work

Ask exactly once, after the Phase 7 summary, following the portable interaction rules. Before asking, check whether option 2 is available: both `git remote get-url origin` and `gh auth status` must succeed. If either fails, show option 2 as unavailable with the reason and do not accept it.

````
<issue_id> implemented on linear-<issue_id>-<slug> (base: <base>).
How do you want to land it?

  1  Merge into <base> locally  (commit → merge --no-ff → delete branch)
  2  Open a PR                  ($commit-push-pr)
  3  Commit only                (stay on the branch)
  4  Nothing                    (leave changes uncommitted)  [default]
````

An ambiguous, empty, or unanswered response is option 4. Never re-ask. None of these options writes to Linear.

**Option 1 — merge into `<base>`.** Both modes merge inline, since `$merge-worktree` only understands markdown tickets:

- Invoke `$commit-ticket` (in worktree mode the pinned cwd puts the commit on the issue branch).
- From `$MAIN_ROOT`: `git switch <base>` if the base exists locally, otherwise `git switch -c <base> origin/<base>`.
- `git merge --no-ff -m "Merge linear-<issue_id>-<slug> into <base>" linear-<issue_id>-<slug>`.
- On conflict: `git merge --abort`, report the conflicted files, leave branch and worktree intact, stop.
- On success: in worktree mode `git worktree remove .worktrees/<issue_id>-<slug>`, then `git branch -d linear-<issue_id>-<slug>`. Use `-d`, not `-D`.
- Never push. Close with `git push` as the next step.

**Option 2 — open a PR:** invoke `$commit-push-pr`; stay on the branch and leave the worktree in place.

**Option 3 — commit only:** invoke `$commit-ticket`; stay on the branch.

**Option 4 — nothing:** leave the changes uncommitted; report the branch name and that `$commit-push-pr` or a manual merge can land it later.

## Safety Rules

- Never mutate Linear except the single opt-in as-built comment after explicit user confirmation; never change status, assignee, labels, or any other field. Nothing in Phase 8 writes to Linear.
- No commit, merge, push, or branch deletion before Phase 8, and then only per the user's explicit choice. Never force-push, and never delete or overwrite a remote branch. Never call `$update-ticket` or `$update-ticket-linear` — status updates belong in a separate `$update-ticket-linear` invocation after implementation.
- Do not use `docs/tickets/` as the ticket source.
- If dirty unrelated changes conflict with the issue, stop and ask.
- In worktree mode, do not switch the main checkout branch or delete the worktree except as part of an explicitly chosen Phase 8 option 1.
- Missing Linear MCP or unresolvable issue → stop.
