# Plan a backlog run

Planning is read-only: it makes no Linear writes and no commits. It writes only under `$MAIN_ROOT/.worktrees/.cktk/runs/`: the snapshot input, and a run directory when a run is planned. Git ignores both once `.gitignore` lists `.worktrees/`; until then they appear as an untracked `.worktrees/`, which execution's pre-flight repairs.

## Resolve the scope

Read applicable repository instructions. If `.ai/cktk/project.json` exists, read the [project bindings contract](../../init-project/references/project-schema.md), and use its Linear team and project only when their status is `validated` or `read-only`.

- `TEAM` without `PROJECT`: plan the whole team. Pass a bound project to the planner only so that a scope stop can mark it.
- Neither: use the bound team and project. Without a usable binding, ask for the team.
- `PROJECT`: resolve it in Linear and confirm the team takes part in it.

Resolve the invoking Linear user (the `me` user) for the assignment check.

## Gather the snapshot

1. List the scope's open issues with one `list_issues` call per state type — `triage`, `backlog`, `unstarted`, and `started` — filtered by the team and, when given, the project. Follow every page. Request `id`, `title`, `statusType`, `labels`, `assigneeId`, `project`, and `parentId`.
2. For each listed issue, call `get_issue` with `includeRelations: true`, and record the identifiers it is blocked by and the identifiers it blocks. When no `PROJECT` was given and step 1 already lists open issues from two or more projects, skip this step and the next: the planner stops on scope, and relations do not change that.
3. For each referenced identifier that is not in the list, call `get_issue` once and record its state type. Completed blockers inside the scope are among them.
4. Write `$MAIN_ROOT/.worktrees/.cktk/runs/snapshot-input.json` in this shape:

```json
{
  "team": {"id": "<team id>", "key": "ENG"},
  "me": "<user id>",
  "requested_project": {"id": "<project id>", "name": "Website"},
  "binding_project": {"id": "<project id>", "name": "Website"},
  "issues": [
    {
      "id": "ENG-12",
      "title": "Add CSV export",
      "state_type": "backlog",
      "labels": ["frontend"],
      "assignee": null,
      "project": {"id": "<project id>", "name": "Website"},
      "parent": null,
      "blocked_by": ["ENG-10"],
      "blocks": ["ENG-13"]
    }
  ],
  "external": [
    {"id": "ENG-10", "state_type": "completed", "title": "Export service"}
  ]
}
```

Use `null` for an absent `requested_project`, `binding_project`, `assignee`, `project`, or `parent`. State types are Linear's: `triage`, `backlog`, `unstarted`, `started`, `completed`, and `canceled`.

Each relation read returns the issue's whole body. When step 1 lists more than about 20 issues, give steps 2 and 3, with the list from step 1, to one subagent that writes the snapshot file above and reports only counts and failures, so the issue bodies stay out of this session.

## Run the planner

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" plan \
  --snapshot "$MAIN_ROOT/.worktrees/.cktk/runs/snapshot-input.json" \
  --runs-dir "$MAIN_ROOT/.worktrees/.cktk/runs" \
  --repo "$MAIN_ROOT" --base "<base>" --parallel <n> --host "<host>"
```

`<host>` is the invoking runtime, such as `claude` or `codex`. With `--repo`, the planner finds local work — registered `.worktrees/<ID>-*` worktrees, `linear-<ID>-*` branches, and `Merge linear-<ID>-…` commits on the base — so that an issue an earlier run left started can resume.

The output's `status` decides what follows:

- `stop`: report `binding-mismatch` (this repository is bound to a different project) or `multiple-projects` (list the projects and mark the bound one), and ask for `PROJECT:`. No run directory exists.
- `nothing-eligible`: report the exclusions, grouped as below. There is no run and no `/goal` line.
- `planned`: present the plan. `run_id` names the run, and `run_dir` holds `plan.json` and `snapshot.json`.

## Present the plan

In the user's language, show:

- the run id, the scope, and the result of the binding check;
- `PARALLEL`, recommending 1 when repository instructions show tests that share a port, database, or other fixed resource. The plan stores the value, so taking the recommendation means planning again with `PARALLEL: 1`;
- `layers`: each issue with its title and its in-plan blockers from `edges`. Layers are for reading; execution starts an issue as soon as its blockers land;
- `excluded`, grouped by reason, with the blocking path for dependency exclusions, such as `ENG-24 ← ENG-23 ← ENG-20`;
- the preparatory writes execution may make: committing `.worktrees/` to `.gitignore` on the base when the line is missing, and creating the team label `human-blocked` when it is missing;
- that execution merges into the local base and never pushes, so Done will mean "merged into local `<base>`".

| Planner reason | Group |
| --- | --- |
| `human-gate` | Human gate, by `label`: `human-setup`, `human-acceptance`, or `human-blocked` (parked by an earlier run) |
| `someone-else` | Assigned to someone else |
| `not-triaged` | Still in triage |
| `running-elsewhere` | Started, with no work in this repository |
| `epic-not-broken-down` | An issue titled `[Epic] …` with no open sub-issues: its work has not been split into issues yet |
| `cycle` | Dependency cycle |
| `blocked` | Blocked. `roots` names each cause as `<kind>:<issue>`: a gate label, `outside-scope`, `canceled` (cancellation is not delivery, so a person decides whether the relation still holds), `cycle`, `unknown`, or one of the reasons above |

End with the `/goal` line. Localize its words but keep the quoted tokens, and use the host's explicit skill syntax — `/implement-backlog-linear` in Claude Code, `$implement-backlog-linear` in Codex:

```text
/goal Run /implement-backlog-linear RUN: <run-id> until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"
```

Pasting that line is the user's confirmation. Do not start execution from a planning run.
