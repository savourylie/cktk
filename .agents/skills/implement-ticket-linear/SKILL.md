---
name: "implement-ticket-linear"
description: "Use when the user explicitly asks to implement a Linear issue (not docs/tickets markdown). Optionally pass `worktree` after the issue id (with an optional base branch) to run inside an isolated git worktree. Prefer explicit invocation with $implement-ticket-linear. Requires Linear MCP."
---

# Implement a Linear Issue

Implement one Linear issue end to end: fetch it via Linear MCP, write the code, validate, and review. Treat this as an explicit workflow skill because it writes code and runs checks.

**This skill does not use `docs/tickets/`.** The Linear issue is the source of truth. It also does **not** commit git changes and does **not** mutate Linear (no status/comment/assignee updates).

If the user included an issue id or URL after `$implement-ticket-linear`, implement that issue. Empty args are invalid — always require an id or URL.

## Prerequisites

1. Linear MCP must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp).
2. If Linear MCP tools are missing, stop with a short setup hint. Do not invent API-key or CLI fallbacks.
3. Use only **read** Linear tools (get/list/search issue). Never call update/create/delete/assign. The only permitted write is the single opt-in as-built comment in Phase 7, posted only after explicit user confirmation.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Implement that Linear issue in the current checkout. |
| `<issue> worktree` | Isolated worktree off `origin/main`. |
| `<issue> worktree <base>` | Isolated worktree off `origin/<base>`. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Normalize team keys to uppercase. The `worktree` keyword is case-insensitive; only that exact word triggers worktree mode. A second non-`worktree` token is a typo — stop and say so.

Not accepted: title-only search, status flags, commit flags, multi-issue batches, empty “next assigned” mode.

## Phase 1: Parse & Resolve

1. Parse args: `issue_ref` (required), `use_worktree`, `base` (default `main` when worktree mode).
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

## Phase 3: Working Directory

1. If `use_worktree`:
   - Reuse an existing registered worktree at the path (dirty state is OK; note it later).
   - Else create inline — do **not** call `$create-worktree` (it requires markdown tickets):
     - Fetch `origin/<base>` when possible
     - Ensure `.worktrees/` is in `$MAIN_ROOT/.gitignore`
     - `git worktree add` with new or existing `linear-…` branch from the resolved base ref
   - `WORK_DIR =` worktree path
2. Else `WORK_DIR = $MAIN_ROOT` (or current toplevel if already on a purposeful worktree).
3. `cd "$WORK_DIR"` once. Prefix absolute file tools with `$WORK_DIR`.
4. State in one sentence where work is happening.

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
   - Prefer invoking `$review-ticket` when available
   - Or read `../review-ticket/references/review-guidelines.md` and review only the ticket diff
   - Treat Linear title + description + AC as the requirements
4. Fix findings and re-check until build is clean and no P0/P1 remain.

## Phase 7: Summary (no commit; Linear write only by opt-in)

Stop after a clear summary:

1. Issue id, title, what changed
2. Deviations and follow-ups
3. Explicit note: **no git commit**, **Linear status unchanged**
4. Manual testing steps
5. **Next step for Linear status:** when ready to mark the issue done (or move it), run `$update-ticket-linear <issue_id>` (optionally with an explicit status such as `done`). That skill evaluates acceptance criteria and writes back to Linear; this skill stays Linear-read-only.
6. **As-built comment (opt-in):** ask exactly once — "Post this as-built summary as a comment on <issue_id>? (y/N)", default no. Only an explicit yes posts one comment (deviations from spec and why, key decisions, follow-ups/tech debt; "None" where empty) via the Linear MCP comment tool. Never change any other Linear field.
7. If worktree mode: path, branch, base, and **manual land** instructions — `$merge-worktree` only understands markdown `TICKET-NNN` worktrees:

```bash
git checkout <base>
git merge linear-<issue_id>-<slug>
# or push + open PR from the worktree branch
```

## Safety Rules

- Never mutate Linear except the single opt-in as-built comment after explicit user confirmation; never change status, assignee, labels, or any other field.
- Never commit; do not call `$commit-ticket`, `$commit-push-pr`, `$update-ticket`, or `$update-ticket-linear` (status updates belong in a separate `$update-ticket-linear` invocation after implementation).
- Do not use `docs/tickets/` as the ticket source.
- If dirty unrelated changes conflict with the issue, stop and ask.
- In worktree mode, do not switch the main checkout branch or delete the worktree at the end.
- Missing Linear MCP or unresolvable issue → stop.
