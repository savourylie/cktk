---
name: implement-backlog-linear
description: "Plan and run every Linear issue an agent can finish without a person, for one team, project, epic, or list of issues. Selects issues without human-setup or human-acceptance labels whose blockers are done or also selected, implements them in parallel worktrees through implement-ticket-linear, lands each on the base through a serial merge queue, marks it Done, and parks work that needs a person. A read-only plan comes first; execution runs from the /goal line it prints. Requires Linear MCP. Use for implement-backlog-linear or requests to work through a Linear backlog, epic, or set of issues automatically."
---

# Run a Linear Backlog to Its Human Boundary

Work through every issue in one Linear scope that an agent can finish without a person, and stop where people are needed. `implement-ticket-linear` still does each issue's work; this skill selects the issues, schedules them, lands them, and reports. The user's `human-setup` and `human-acceptance` labels mark work that needs a person, and this skill adds `human-blocked` to work it could not finish.

Use the available authenticated Linear MCP tools and their actual schemas. Without issue reads, report that blocker; do not invent an API-key, CLI, or browser fallback.

## Modes

Accept keyed arguments, case-insensitive, with or without a space after the colon. Quoted values may contain spaces.

| Input | Meaning |
| --- | --- |
| `TEAM: <key/name/id>` | Linear team; optional when `EPIC`, `ISSUES`, or a validated `.ai/cktk/project.json` supplies it |
| `PROJECT: <name/id/URL>` | Linear project. One project is one repository |
| `EPIC: <ID/URL>` | One epic: its open sub-issues at every depth in the epic's team and project, then the epic itself. It supplies the team; `TEAM` and `PROJECT`, when given, must match it |
| `ISSUES: <IDs/URLs>` | Exactly these issues, separated by spaces or commas; an unlisted blocker or sub-issue is reported, never added. They supply the team; `TEAM` and `PROJECT`, when given, must match them. Not combined with `EPIC` |
| `PARALLEL: <n>` | Implementation subagents at once; default 3 |
| `BASE: <branch>` | Branch that issues land on; default `main` |
| `RUN: <run-id>` | Execute a confirmed plan; takes no other input |

Without `RUN:`, plan: read [planning](references/planning.md). Planning is read-only and ends with a `/goal` line; pasting that line is the user's confirmation and starts execution.

With `RUN:`, execute a confirmed plan: read [execution](references/execution.md), then [merge queue](references/merge-queue.md) and [stopping](references/stopping.md) as results reach them. Subagents receive the [subagent briefs](references/subagent-briefs.md).

```text
implement-backlog-linear TEAM: ENG PROJECT: "Website"
implement-backlog-linear                          # the bound team and project
implement-backlog-linear TEAM: ENG PARALLEL: 1
implement-backlog-linear EPIC: ENG-40             # one epic's sub-issues, then the epic
implement-backlog-linear ISSUES: ENG-42 ENG-43    # exactly these issues
implement-backlog-linear RUN: ENG-website-20260926-1430
```

## Shared rules

- Resolve `MAIN_ROOT` from the absolute common git directory and verify it with `git worktree list --porcelain`. Select the directory explicitly on every shell call, and use absolute paths for file tools.
- `$SKILL_DIR` is this skill's real directory, resolved through installation symlinks. Run `$SKILL_DIR/scripts/backlog_graph.py` from there, never from the target project. It owns scope, selection, readiness, locking, and status lines; use its output instead of recomputing them.
- Run directories live under `$MAIN_ROOT/.worktrees/.cktk/runs/`. They are local and never staged.
- Before calling another skill, read its active host document for refusals, side effects, and argument modes, and pass the work directory, branch, issue, and authorized scope explicitly, as in `implement-ticket`'s [calls across skills](../implement-ticket/references/workspace.md#calls-across-skills).
- Answer in the user's language. Status lines and the `/goal` line keep their fixed English tokens.
- The confirmed plan is the authorization boundary: execution may shrink it and never grows it. `RUN:` authorizes, for planned issues only, the preparatory `.gitignore` commit and label creation the plan names, implementation and commits in issue worktrees, merges into the base, Linear updates through `update-ticket-linear`, and parking. It does not authorize pushing, pull requests, or optional document follow-ups whose preference is `ask`.
- Only this skill adds `human-blocked`, and only through an append-only label operation.
