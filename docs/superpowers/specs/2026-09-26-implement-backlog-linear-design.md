# Design: `implement-backlog-linear` — Run a Linear Backlog to Its Human Boundary

**Date:** 2026-09-26
**Status:** Approved in brainstorming; awaiting written-spec review

## Context

Today the user works through local tickets with a hand-written Codex goal:

> `/goal Use the implement-ticket skill to implement tickets 011-015. Once each ticket is done, use the update-ticket skill to update the status of the ticket and all the related tickets to unblock them. Then, use the commit-ticket skill to commit the ticket. Work on these tickets one by one in this manner until all of them are marked as done.`

That loop needs a hand-picked range, runs one ticket at a time, and has no rule for a ticket the agent cannot finish. The user has many Linear teams and projects, each with many ready issues, and marks issues that need a person with two labels of their own convention: `human-setup` and `human-acceptance`. No cktk skill referenced either label before this design.

The goal: given a Linear team and optionally a project, find every issue an agent can finish without a person — including downstream issues that become ready as upstream ones land — implement them in parallel worktrees through the existing single-issue skill, land each on `main`, mark it Done, and continue until only human-gated issues and the issues they block remain.

### What the callees require (AGENTS.md rule 6)

Reading the skills this orchestrator calls surfaced these constraints. Each is answered by a decision below.

| Callee | Precondition or side effect | Consequence for an unattended, parallel run |
| --- | --- | --- |
| `implement-ticket-linear` | "Do not select arbitrary backlog work"; one issue per run; stops to ask on a business contradiction | Selection belongs to a new skill; a subagent's question must come back as a result |
| `create-worktree-linear` | Appends `.worktrees/` to `$MAIN_ROOT/.gitignore` and deliberately leaves it uncommitted | Parallel subagents would race on one file, and the dirt trips the merge helper |
| `merge-worktree-linear` | Refuses inside a target worktree or on a dirty main checkout; Y/n prompts for auto-commit and the `.gitignore` carve-out; never pushes; never resolves a conflict | Landing is serial, run by the orchestrator from `MAIN_ROOT`, with work already committed |
| `create-worktree(-linear)`, `implement-ticket/references/workspace.md` | Prefer freshly fetched `origin/<base>` over local `<base>` | Without a push, a downstream worktree starts without the upstream work merged moments earlier |
| `update-ticket-linear` | Project Context and decision-log follow-ups ask when their preference is `ask` | An unattended run must decide these in advance |

### What `/goal` does and does not do

`/goal` is a host command in both targets, and a skill cannot turn it on. (Claude Code has a gated `ProposeGoal` tool that asks the user to approve a goal with one keypress; it is not available in this environment, so the design does not depend on it.)

- **Claude Code 2.1.283** — `/goal [<condition> | clear]` sets the condition and starts working. After each turn a separate evaluator reads the conversation and decides whether the condition is met; if not, Claude continues. The goal *pauses* on usage limits, API errors, a check timeout, or when "goal checks kept finding it unmet this turn"; it *fails* when the evaluator judges the condition impossible.
- **Codex 0.157** — `/goal [<objective>|clear|edit|pause|resume]` pursues an objective through pursuing, paused, stalled, usage-limited, and achieved states.

The skill therefore cannot guarantee it keeps running; `/goal` does. The skill's job is to make every round safe to re-enter and to print a status line the goal can check.

### Tool facts used below

Linear MCP `list_issues` returns `labels`, `statusType`, `project`, `assigneeId`, and `parentId`, but no relations; relations need one `get_issue(includeRelations: true)` per issue. `save_issue` offers append-only `addLabels`; its `labels` field replaces the whole set. Codex 0.157 exposes `spawn_agent` / `wait_agent`, bounded by `agents.max_threads`. Claude Code runs Agent-tool subagents in the background and notifies on completion.

## Decisions (from brainstorming)

1. **A new portable orchestrator skill, `implement-backlog-linear`.** Rejected alternatives: a read-only planner that hands execution to a free-form `/goal` prompt, where every rule below would live in an ad hoc prompt re-derived each round; and an external script driving headless CLIs, which needs a Linear API key outside MCP, a path the Linear skills forbid.
2. **Two steps: plan, then execute.** Planning is read-only and prints the plan plus an exact `/goal` line. Pasting that line is the confirmation. A bare `/goal 確認` would not work, because the goal text is the condition the evaluator checks.
3. **The confirmed plan is the authorization boundary.** Execution touches only planned issues, and the set only shrinks. Issues that become eligible mid-run are reported, not taken.
4. **An issue the agent cannot finish is parked** with a `human-blocked` label and an explanatory comment. Removing the label is the signal to retry.
5. **Merge conflicts: the agent tries once.** A conflict it cannot resolve, or one that is really a business trade-off between two issues, parks the issue.
6. **One Linear project is one repository.** With no project given, the team's open issues must span at most one project; otherwise the skill stops.
7. **A parent waits for its sub-issues**, then goes through the normal pipeline, which often amounts to verification only.
8. **Issues assigned to someone else are not taken.**
9. **Merge before Done.** Done means "merged into local `main`", so a dependent is never unblocked before its prerequisite code is there.
10. **No push, no PR.**
11. **Worktree base resolution prefers the local base when it contains `origin/<base>`.** This is the only change to existing skills.
12. **A crashed or errored subagent is retried once. Two consecutive issues failing on the same environment problem halt the run.**
13. **Optional document follow-ups:** `always` runs, `ask` is skipped and reported with its prepared content, `never` is skipped.
14. **A halt is an exit of the goal**, and the halt report reprints the `/goal` line for resuming.

## Design

### 1. Invocation

Keyed arguments, as in `create-tickets-linear`, case-insensitive:

```text
implement-backlog-linear [TEAM: <key|name|id>] [PROJECT: <name|id|url>] [PARALLEL: <n>] [BASE: <branch>]
implement-backlog-linear RUN: <run-id>
```

- Without `RUN:` the skill plans. `PARALLEL` defaults to 3 and `BASE` to `main`.
- `TEAM` is required unless a validated `.ai/cktk/project.json` supplies it. With neither `TEAM` nor `PROJECT`, the binding supplies both. An explicit `TEAM` without `PROJECT` follows the no-project rule in §2 even when a binding exists.
- `RUN:` executes a stored plan and takes every other setting from it; passing other arguments with `RUN:` is an error.
- Codex metadata (`agents/openai.yaml`) sets `allow_implicit_invocation: false`: the workflow changes the repository and writes to Linear, so it runs only when named.

### 2. Scope

Resolve the team, then:

- **Project given:** candidates are that project's issues in that team. If `.ai/cktk/project.json` binds a different project, stop: this is the wrong repository.
- **No project:** collect the projects of the team's non-terminal issues. Projects with no open issues do not count.
  - Two or more: stop, list them, mark the bound one when a binding exists, and ask for `PROJECT:`.
  - Exactly one: the scope is that project plus the team's issues that have no project.
  - None: the scope is the team's issues.
  - If a binding names a different project from the one found, stop.

### 3. Selection

Classify each in-scope non-terminal issue by the first matching row:

| Class | Condition | In the plan |
| --- | --- | --- |
| Human gate | Label `human-setup`, `human-acceptance`, or `human-blocked` (case-insensitive name match) | Excluded |
| Someone else's | Assigned to a user other than the invoking user | Excluded |
| Not triaged | State type `triage` | Excluded |
| Running elsewhere | State type `started` with no registered `.worktrees/<ID>-*` worktree and no `linear-<ID>-*` branch in this repository | Excluded |
| Candidate | State type `backlog` or `unstarted`; or `started` with local work in this repository (an earlier run to resume) | Next step |

Completed, canceled, and duplicate issues are terminal and never become work.

**Edges.** Native blocks / blocked-by relations, fetched with one `get_issue(includeRelations: true)` per non-terminal issue, plus an implicit edge making every parent wait for each of its sub-issues. Related, duplicate, and prose links are not edges.

**Eligible set.** Starting from the candidates, repeatedly remove any issue with a blocker that is neither completed nor still in the set, until nothing changes. Record why each issue was removed:

- blocked, directly or transitively, by a human gate;
- blocked by an unfinished issue outside the scope;
- blocked by a canceled or duplicate issue — cancellation is not delivery, so a person decides whether the relation still holds;
- part of a dependency cycle (the members Kahn's algorithm cannot order, and their dependents).

The remaining issues form a DAG, displayed in topological layers. Layers are for reading only; execution does not wait for a layer to finish.

**Parallelism hint.** If repository instructions show tests that share a port, database, or other fixed resource, the plan recommends `PARALLEL: 1`.

### 4. The plan and its run directory

The plan states the run id, the scope and binding check, `PARALLEL`, the layered issues with their in-plan blockers, the excluded issues grouped by reason, and the two preparatory writes execution may make: committing a `.worktrees/` ignore line on the base, and creating the `human-blocked` team label. It ends with the `/goal` line in the user's language, keeping the quoted tokens verbatim and using the host's explicit skill syntax (`/…` in Claude Code, `$…` in Codex):

```text
/goal Run /implement-backlog-linear RUN: ENG-website-20260926-1430 until its latest STATUS line shows "AI-ELIGIBLE 0" or "HALTED"
```

If nothing is eligible, the plan says so, lists the exclusions, and prints no `/goal` line.

The run directory is `$MAIN_ROOT/.worktrees/.cktk/runs/<run-id>/`. It holds `plan.json` (scope, base, `PARALLEL`, issue order, edges, exclusions, host, creation time) and `results/<ISSUE>.json` (subagent outcomes). `.worktrees/` is the ignored home of every worktree already, and the leading dot keeps this directory clear of `<ID>-<slug>` names. Planning writes nothing else: no Linear writes and no commits.

### 5. Execution pre-flight

Runs at every start and resume, from `MAIN_ROOT`:

1. Load `plan.json` and verify it belongs to this repository. Take the lock `$MAIN_ROOT/.worktrees/.cktk/runs/ACTIVE`, which names the run and host. A lock naming this run is taken over, since that is a resume; a lock naming another run stops execution and names the lock file to remove if that session is gone.
2. Re-read every planned issue:
   - newly completed: counts as done elsewhere; its dependents proceed normally;
   - newly canceled, gated, or assigned to someone else: removed, together with its planned dependents;
   - nothing is ever added.
3. The main checkout must be on the base and clean. A clean checkout on another branch is switched to the base, and the switch is reported. Any other dirt stops execution, with one carve-out that step 5 repairs: `.gitignore` either lacks the `.worktrees/` line or carries it as its only uncommitted change, and the only other entry is an untracked `.worktrees/`.
4. Fetch `origin/<base>`. Fast-forward a local base that is behind; halt if the two have diverged.
5. If the committed `.gitignore` on the base lacks `.worktrees/`, add the line and commit `chore: ignore .worktrees/`. This happens before any subagent creates a worktree.
6. Ensure the `human-blocked` label exists on the team; create it if it is missing.
7. Detect the host's subagent facility. Without one, `PARALLEL` becomes 1 and issues run in topological order.

### 6. Scheduling and subagents

An issue is **ready** when every blocker, explicit or implicit, is completed in Linear and, for a planned blocker, landed on the base. Immediately before dispatch, re-read the issue: if it is now completed (Linear can auto-close a parent), treat it as done; if it is now canceled, gated, or reassigned, remove it and its dependents.

Keep up to `PARALLEL` subagents busy, one issue each, and fill a free slot as soon as an issue is ready.

The implementation brief (kept in `references/subagent-briefs.md`) gives the subagent `MAIN_ROOT`, the base, the run id, the issue, and the cktk source path, and requires it to:

- run `implement-ticket-linear <ID> worktree <base>` in the repository's own `.worktrees/<ID>-<slug>`, not in a host-provided worktree;
- commit the result in that worktree through `commit-ticket`;
- write only within that worktree, plus the start transition `implement-ticket-linear` already performs: no merge, push, PR, other Linear state, comment, or label;
- never wait on a question: a business contradiction or missing decision ends its run, with the question, evidence, and options in its result;
- write `results/<ID>.json` and return the same content:

```json
{
  "issue": "ENG-12",
  "verdict": "complete | incomplete | needs-decision | failed",
  "branch": "linear-ENG-12-add-csv-export",
  "worktree": "/abs/path/.worktrees/ENG-12-add-csv-export",
  "commits": ["<sha>"],
  "checks": [{"command": "npm test", "result": "pass"}],
  "business_summary": "…",
  "blocker": {"kind": "decision | environment | defect | prerequisite", "question": "…", "evidence": "…", "options": ["…"], "suggestion": "…"}
}
```

**Waiting.** Under Claude Code's `/goal`, every ended turn is a check, and repeated unmet checks in one turn pause the goal, so an orchestrator that ends its turn to wait for subagents may pause its own goal. Codex blocks with `wait_agent`. Claude Code has no blocking wait for background work — `Monitor` and background shell commands only notify — so the spike (§13) chooses among three outcomes: (A) ending the turn is safe because background work does not use up goal checks; (B) the orchestrator waits in the foreground with the planner's bounded `wait`; (C) Claude Code runs issues inline with `PARALLEL` 1.

**Spike result (2026-09-26, Claude Code 2.1.283):** Outcome A. In a headless `/goal` run, the main agent dispatched two background subagents and ended its turn three times: after dispatching, and after each completion notification. At the two turn ends while a subagent was still running, the session's Stop hooks ran without the goal's evaluator; the evaluator ran only at the last turn end, with no background work left, and recorded the goal as met. No pause appeared, and both result files were written. Headless `stream-json` output prints no evaluator lines, so the evidence is the session transcript's `stop_hook_summary` hook lists and `goal_status` entries. `references/execution.md` uses the matching Claude Code waiting paragraph.

**Resuming.** Progress is derived from Linear and git, not stored:

- a planned issue with a `Merge linear-<ID>-…` commit on the base that is not completed in Linear resumes at the Linear update (§7.4);
- an issue with a result file whose commits are on its branch resumes at the merge queue;
- an issue `started` with a worktree or branch is dispatched again, and `implement-ticket-linear` continues from that worktree or branch.

### 7. Merge queue

Serial, first come first served, run by the orchestrator:

1. **Sync.** In the issue's worktree, merge the local base into the issue branch. If that merge is a no-op, the subagent's checks stand. Otherwise rerun the issue's checks and the repository's required checks in the worktree.
2. **Repair once.** A conflict or failing check goes to a conflict brief: the issue, the issues whose merges on the base touched the conflicting files (identified by their `Merge linear-<ID>-…` subjects), and the instruction to keep both intents and rerun the checks. A business trade-off between two issues is returned, not decided. Failure parks the issue: an unfinished merge is aborted with `git merge --abort`, and a committed attempt stays and is named in the parking comment. Nothing is reset.
3. **Land.** From `MAIN_ROOT`, invoke `merge-worktree-linear <ID> <base>`. Its preconditions hold by construction: the caller is outside the worktree, the main checkout is clean, and the worktree is committed. Because the queue is serial and the base has not moved since the sync, the merge is conflict-free and lands exactly the tested tree. The helper removes the worktree and the local branch.
4. **Update Linear.** Invoke `update-ticket-linear <ID>` in auto mode with `WORK_DIR = MAIN_ROOT`, the merge commit, the subagent's verification evidence, and the optional-document policy of decision 13. It marks the issue Done and moves unblocked dependents to the team's ready state. If it will not mark Done, the issue is parked with its code already on the base, and its dependents stay blocked.
5. **Recompute** readiness and fill free slots.

A parent with nothing left to build returns `complete` with no commits. The merge helper reports it as already merged, and `update-ticket-linear` verifies the parent's acceptance against its sub-issues.

### 8. Parking

Triggers:

- a subagent verdict of `incomplete` or `needs-decision`;
- a failed repair (§7.2);
- a refused Done (§7.4);
- a second crash or tool error, after one automatic retry in the same worktree.

Actions, each safe to repeat:

- call `save_issue` with `addLabels: ["human-blocked"]`, never `labels`, which replaces the set;
- post one comment in `implement-ticket`'s delivery structure for an incomplete result: the remaining problem, the obstacle and its evidence, a concrete resolution, and for a decision the options with their consequences. Add where the work is (worktree and branch, or already on the base) and that removing the label re-admits the issue. Check existing comments first so a retry does not duplicate it;
- leave the workflow state, worktree, and branch as they are;
- drop the issue's planned dependents from this run and report them as blocked by a parked issue.

### 9. Halting

Triggers are conditions that affect every issue:

- the main checkout becomes dirty or cannot return to the base;
- the base diverges from origin, including `merge-worktree-linear`'s fast-forward refusal;
- Linear reads or writes fail for access reasons;
- the plan is missing or belongs to another repository;
- two consecutive issues fail with the same environment error, such as the same dependency installation or service start failure.

Actions: dispatch nothing new, let running subagents finish (their work stays in their worktrees for the next run), release the lock, and print the halt report, ending with the same `/goal` line.

| Stop | Decided by | Goal state | Resume |
| --- | --- | --- | --- |
| Halt | The skill: continuing is unsafe | Ended, through the `HALTED` branch of the condition | Fix the cause, then paste the same `/goal` line in either host |
| Goal pause | The host: usage limit, check cap, API error, check timeout | Still set, paused | Claude Code: send a message. Codex: `/goal resume` |

### 10. Status line and final report

Every message that ends a turn during execution, including the final report, starts with one line in fixed tokens:

```text
STATUS implement-backlog-linear RUN ENG-website-20260926-1430 · AI-ELIGIBLE 0 · DONE 11 · PARKED 2 · HUMAN-GATED 5 · BLOCKED 7
STATUS implement-backlog-linear RUN ENG-website-20260926-1430 · HALTED · base diverged from origin/main
```

`AI-ELIGIBLE` counts planned issues not yet completed, parked, or removed. The fixed tokens keep the goal check independent of the conversation language. The rest of the report follows the user's language and `implement-ticket`'s delivery reference:

- completed issues, each with one line of business meaning;
- parked issues, with reason, location, and recommendation;
- human-gated issues and the issues they block;
- skipped optional document follow-ups, with their prepared content;
- issues that became eligible outside the plan, found by rerunning selection read-only;
- how far the base leads `origin/<base>`, unpushed.

The lock is released after the final report.

### 11. Changes to existing skills

**Base resolution**, in `skills/create-worktree-linear/SKILL.md`, `skills/create-worktree/SKILL.md`, their Codex documents under `.agents/skills/`, and `skills/implement-ticket/references/workspace.md`:

> After fetching, use local `<base>` when `origin/<base>` is its ancestor (equal, or local ahead). Use `origin/<base>` when local is behind or missing. When the two have diverged, use `origin/<base>` and warn.

This also repairs the manual flow. `merge-worktree-linear ENG-42` merges locally without pushing, so a following `create-worktree-linear ENG-43` today starts from an `origin/main` without ENG-42, and `implement-ticket-linear` then reports a missing prerequisite. The wording changes with the rule wherever it states origin-first behavior: both create skills' frontmatter descriptions ("defaults to main, fetched fresh from origin") and the README usage examples that say "off origin/…" for `implement-ticket` and `create-worktree`.

Reverse check (rule 6): every document mentioning `create-worktree` was read, and none depends on origin-first resolution; `clarify-ticket` only forbids invoking it. The behavior this makes more common — a worktree carrying unpushed base commits — matters only when a PR is opened from that worktree before the base is pushed; the updated documents say so.

**Deliberately unchanged:**

- `implement-ticket-linear`: its "stop and ask the user" becomes the subagent's returned question, in the shape the brief defines.
- `update-ticket-linear`: it already keeps an unauthorized follow-up's prepared content and summarizes it.
- `merge-worktree-linear`: the pre-flight and the merge queue satisfy its preconditions.

### 12. Repository integration

- `skills/implement-backlog-linear/SKILL.md`, with `references/planning.md` (§2–4), `references/execution.md` (§5–6), `references/merge-queue.md` (§7), `references/stopping.md` (§8–10), and `references/subagent-briefs.md` (implementation and conflict briefs, result schema).
- `skills/implement-backlog-linear/scripts/backlog_graph.py`: a standard-library Python planner that applies §2, §3, the readiness and removal rules of §5–§8, the lock, and the status lines deterministically. The model gathers Linear and git facts; the script decides, because these rules form the authorization boundary and are easy to misapply by hand across dozens of issues. `scripts/test-backlog-graph.py` tests it.
- `skills/implement-backlog-linear/agents/openai.yaml`.
- Symlinks `.agents/skills/implement-backlog-linear` and `.agent/skills/implement-backlog-linear` → `../../skills/implement-backlog-linear`.
- A `catalog.json` entry with `portable: true`; a `README.md` table row and a two-step lifecycle example.
- The portable constraints `scripts/check-portable-skills.py` enforces: standard frontmatter only, no `$ARGUMENTS`, every relative link resolving, Codex metadata present.

### 13. Verification

1. **Spike before writing the execution reference.** In Claude Code under `/goal`, dispatch two background subagents and observe whether waiting by ending the turn uses up goal checks and trips the per-turn cap; if it does, probe the planner's bounded foreground `wait`. The result selects outcome A, B, or C in §6.
2. **Repository checks:** `scripts/check-codex-skills.sh`, `scripts/check-portable-skills.py`, `scripts/test-agent-skills.py`, and `scripts/test-backlog-graph.py`.
3. **Read-only planning run** against one of the user's real Linear projects, compared with the user's expectation.
4. **End-to-end rehearsal** in a throwaway repository and Linear project, in both Claude Code and Codex, with 6–8 issues covering a parallel pair, a chain, a parent with sub-issues, a `human-setup` issue with a dependent, a pair built to conflict, and an issue built to park. Creating that Linear data needs the user's go-ahead at the time.

## Out of scope

- A `docs/tickets/` twin (`implement-backlog`).
- `via codex|claude|grok` delegation.
- Pushing or opening PRs.
- Having `create-tickets-linear` apply `human-setup` / `human-acceptance` when it creates issues.

## Risks

- **Waiting in Claude Code** (§6) was settled by the spike. A later Claude Code release can change goal-check behavior; if a run's goal pauses unexpectedly after an upgrade, repeat the spike.
- **Sandboxed Codex subagents** must write `.git/worktrees/` metadata and `MAIN_ROOT/.worktrees/`. `implement-ticket-linear`'s worktree mode already needs this; the rehearsal confirms it.
- **Shared test resources** across parallel worktrees are mitigated only by the `PARALLEL` hint.
- **Orchestrator context** grows with each issue's summary. Derivable progress makes compaction survivable, not free.
- **Uncommitted prompt-audit edits.** On 2026-09-26 the working tree carries audit edits to the frontmatter description of both create skills, the same lines §11 changes. The implementation builds on top of those edits, so the audit should be committed or otherwise settled first.
