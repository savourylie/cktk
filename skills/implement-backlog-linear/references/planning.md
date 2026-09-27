# Plan a backlog run

Planning is read-only: it makes no Linear writes and no commits. It writes only under `$MAIN_ROOT/.worktrees/.cktk/runs/`: the snapshot input, and a run directory when a run is planned. Git ignores both once `.gitignore` lists `.worktrees/`; until then they appear as an untracked `.worktrees/`, which execution's pre-flight repairs.

## Resolve the scope

Read applicable repository instructions. If `.ai/cktk/project.json` exists, read the [project bindings contract](../../init-project/references/project-schema.md), and use its Linear team and project only when their status is `validated` or `read-only`. `EPIC` and `ISSUES` do not combine; with both, stop and ask for one. Otherwise take the first case that applies:

- `EPIC`: resolve the epic with `get_issue`, by identifier or URL, and stop if Linear has no such issue. The run's team is `TEAM` when given, otherwise the epic's team. Resolve `PROJECT` when given, and pass a bound project only as `binding_project`: the planner stops when the team, `PROJECT`, or the binding disagrees with the epic. Sub-issues in another team or project, and blockers outside the epic's family, stay out of the run and hold what depends on them as `outside-scope`.
- `ISSUES`: the run takes exactly the listed issues. Accept identifiers or URLs separated by spaces or commas, and stop, naming each one Linear does not have. The run's team is `TEAM` when given, otherwise the first listed issue's team. Resolve `PROJECT` when given, and pass a bound project only as `binding_project`: the planner stops when the listed issues span teams or projects, or disagree with `PROJECT` or the binding. An unlisted blocker or sub-issue holds what needs it as `outside-scope` instead of joining the run.
- `TEAM` without `PROJECT`: plan the whole team. Pass a bound project to the planner only so that a scope stop can mark it.
- Neither: use the bound team and project. Without a usable binding, ask for the team.
- `PROJECT`: resolve it in Linear and confirm the team takes part in it.

Resolve the invoking Linear user (the `me` user) for the assignment check.

## Gather the snapshot

1. List the scope's open issues with one `list_issues` call per state type — `triage`, `backlog`, `unstarted`, and `started` — filtered by the team and, when given, the project. Follow every page. Request `id`, `title`, `statusType`, `labels`, `assigneeId`, `project`, and `parentId`.
2. For each listed issue, call `get_issue` with `includeRelations: true`, and record the identifiers it is blocked by and the identifiers it blocks. When no `PROJECT` was given and step 1 already lists open issues from two or more projects, skip steps 2 to 4: the planner stops on scope, and relations do not change that.
3. For each listed issue, list its sub-issues with `list_issues` filtered only by `parentId` — no team or project filter — in any state, and record their identifiers as `sub_issues`. A parent waits for every open sub-issue, including one outside the scope.
4. For each referenced identifier that is not in the list — a blocker, a blocked issue, or a sub-issue — call `get_issue` once and record its state type. Completed blockers inside the scope are among them.
5. Write `$MAIN_ROOT/.worktrees/.cktk/runs/snapshot-input.json` in this shape:

```json
{
  "team": {"id": "<team id>", "key": "ENG"},
  "me": "<user id>",
  "requested_project": {"id": "<project id>", "name": "Website"},
  "requested_epic": null,
  "requested_issues": null,
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
      "blocks": ["ENG-13"],
      "sub_issues": []
    }
  ],
  "external": [
    {"id": "ENG-10", "state_type": "completed", "title": "Export service"}
  ]
}
```

Use `null` for an absent `requested_project`, `requested_epic`, `requested_issues`, `binding_project`, `assignee`, `project`, or `parent`. State types are Linear's: `triage`, `backlog`, `unstarted`, `started`, `completed`, `canceled`, and `duplicate`.

With `EPIC`, walk the epic's family in place of steps 1 and 3: list the epic's sub-issues with `list_issues` filtered only by `parentId` — no team, project, or state filter — then the sub-issues of every issue found, until a round finds no new issue. Request the fields of step 1, and record the epic and every issue found, in any state, in `issues`; `parent` links them, so `sub_issues` may stay empty. Step 2 then reads relations only for the open issues in the run's team and the epic's project, the ones the planner can select, and step 4 reads what those relations name outside the family. Set `requested_epic` to `{"id": "<epic identifier>"}`.

With `ISSUES`, the listed issues replace step 1: read each with `get_issue` and `includeRelations: true`, which is also its step 2, and record it in `issues`, in whatever state, under the identifier Linear returns. Then run steps 3 and 4 for the open ones, and set `requested_issues` to the recorded identifiers.

Each relation read returns the issue's whole body. When more than about 20 issues need relation reads, give the remaining steps, with the issue list, to one subagent that writes the snapshot file above and reports only counts and failures, so the issue bodies stay out of this session.

## Run the planner

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" plan \
  --snapshot "$MAIN_ROOT/.worktrees/.cktk/runs/snapshot-input.json" \
  --runs-dir "$MAIN_ROOT/.worktrees/.cktk/runs" \
  --repo "$MAIN_ROOT" --base "<base>" --parallel <n> --host "<host>"
```

`<host>` is the invoking runtime, such as `claude` or `codex`. With `--repo`, the planner finds local work — registered `.worktrees/<ID>-*` worktrees and `linear-<ID>-*` branches — so that an issue an earlier run left started can resume. It also records the base tip as `base_sha`, so that execution counts only landings made after the plan.

The output's `status` decides what follows:

- `stop`: report the scope's `reason` as the table below says. No run directory exists.
- `nothing-eligible`: report the exclusions, grouped as in [present the plan](#present-the-plan). There is no run and no `/goal` line.
- `planned`: present the plan. `run_id` names the run — it starts with the epic's identifier for an epic, and with `<TEAM>-issues-` for listed issues — and `run_dir` holds `plan.json` and `snapshot.json`.

| Stop reason | Report |
| --- | --- |
| `binding-mismatch` | This repository is bound to a different project than the scope's; name both. In a team run, ask for `PROJECT:` |
| `multiple-projects` | List the team's projects, mark the bound one, and ask for `PROJECT:` |
| `epic-team-mismatch` | `TEAM` is not the epic's team |
| `epic-project-mismatch` | `PROJECT` is not the epic's project |
| `epic-closed` | The epic is completed, canceled, or a duplicate, so nothing runs under it |
| `epic-not-found` | The snapshot lacks the epic; gather it again |
| `issues-not-found` | The snapshot lacks some listed issues; name them and gather again |
| `issues-team-mismatch` | Some listed issues are not in the run's team; name them |
| `issues-multiple-projects` | The open listed issues span projects: list them, mark the bound one, and ask for issues from one project |
| `issues-project-mismatch` | `PROJECT` is not the listed issues' project |
| `epic-with-issues` | `EPIC` and `ISSUES` were both given; ask for one |

## Present the plan

In the user's language, show:

- the run id, the scope — for an epic, its identifier, title, and project; for listed issues, the list — and the result of the binding check;
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
| `closed` | Listed, but already completed, canceled, or a duplicate; nothing to run |
| `epic-not-broken-down` | An issue titled `[Epic] …` with no sub-issues at all: its work has not been split into issues yet |
| `cycle` | Dependency cycle |
| `blocked` | Blocked. `roots` names each cause as `<kind>:<issue>`: a gate label, `outside-scope`, `canceled` or `duplicate` (neither is delivery, so a person decides whether the relation still holds), `cycle`, `unknown`, or one of the reasons above |

When the scope's binding is `read-only`, stop after presenting the plan and print no `/goal` line: execution writes to Linear, which that binding forbids.

Otherwise, end with the `/goal` line. Localize its words but keep the quoted tokens, and use the host's explicit skill syntax — `/implement-backlog-linear` in Claude Code, `$implement-backlog-linear` in Codex:

```text
/goal Run /implement-backlog-linear RUN: <run-id> until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"
```

Pasting that line is the user's confirmation. Do not start execution from a planning run.
