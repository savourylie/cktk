# Subagent briefs

Fill every `<placeholder>`, then give the brief to a fresh subagent through the host's facility, such as the Agent tool in Claude Code or `spawn_agent` in Codex. `<CKTK_ROOT>` is the cktk checkout that contains this skill, resolved through installation symlinks. Paste the result-file section below into each brief where it says so.

## Result file

Finish by writing `<RUN_DIR>/results/<NAME>.json` — first as `<NAME>.json.tmp`, then renamed, so a half-written file is never read — and return exactly the same JSON as your final message:

```json
{
  "issue": "ENG-12",
  "verdict": "complete",
  "branch": "linear-ENG-12-add-csv-export",
  "worktree": "/abs/path/.worktrees/ENG-12-add-csv-export",
  "commits": ["<sha>"],
  "checks": [{"command": "npm test", "result": "pass"}],
  "business_summary": "One or two sentences on what this now lets users do.",
  "blocker": null,
  "delegation": null
}
```

`verdict` is one of:

- `complete`: acceptance is met and the work is committed. `commits` may be empty when nothing needed to change, as for a parent its sub-issues already delivered.
- `incomplete`: work remains; `blocker` explains why.
- `needs-decision`: a person must choose; `blocker.options` lists the choices and their consequences.
- `failed`: the run itself broke, such as a tool error.

A `blocker` has `kind` (`decision`, `environment`, `defect`, or `prerequisite`), `question`, `evidence`, `options`, and `suggestion`.

`delegation` is `null` for native implementation. With an executor it is `{"executor": "<executor>", "record": "<absolute path to the adapter's <stem>.json>"}`; for `pi`, the record also names the model and thinking level that ran.

## Implementation brief

```text
You are implementing one Linear issue in an unattended backlog run. Nobody is watching this run, so never wait for an answer.

Issue: <ISSUE>
Run: <RUN_ID>, run directory <RUN_DIR>
Main repository: <MAIN_ROOT>
Base: <BASE>
Skill: read <CKTK_ROOT>/skills/implement-ticket-linear/SKILL.md and follow it.

1. Run implement-ticket-linear with the arguments "<ISSUE> worktree <BASE><VIA_CLAUSE>". It creates or reuses <MAIN_ROOT>/.worktrees/<ISSUE>-<slug> on the branch linear-<ISSUE>-<slug>. Work only in that worktree.
2. You are authorized to commit this issue's changes in that worktree through commit-ticket, and to make the start transition implement-ticket-linear performs. You are not authorized to merge, push, open a pull request, change any other Linear state, post comments, or change labels.
3. Where implement-ticket-linear says to stop and ask the user — a business contradiction, a missing decision, missing required acceptance — stop without waiting, and put the question, the evidence, and the options in the result.
4. <NAME> is <ISSUE>.
<delegation section>

<result-file section>
```

`<VIA_CLAUSE>` is ` via <EXECUTOR>` when the plan has an `executor`, and empty otherwise. Paste the delegation section below where the brief says so only with an executor; otherwise drop that line. `<HOST>` is the runtime running this `RUN:`, which can differ from the one that planned it.

### Delegation section

```text
5. Delegate only the implementation step, to <EXECUTOR>, through implement-ticket-linear's delegation reference; your current_host is <HOST>. Use <RUN_DIR>/delegation/<ISSUE> as its diagnostics directory, never a directory inside the worktree: the merge queue lands only a clean worktree. You still prepare the worktree, verify, review with review-ticket, fix what you find, and commit; never commit the diagnostics.
6. Run the adapter once. Do not retry it, and do not implement natively in its place. Map an outcome other than completed:
   - failed, timed_out, or git_inspection_failed: verdict failed, with the record's status and the executor's error in blocker.evidence and blocker.kind environment.
   - no_changes: complete with empty commits only when acceptance is already met; otherwise incomplete, blocker.kind defect.
   - forbidden_git_state: incomplete, blocker.kind defect, naming the commit or branch change the executor made. Do not reset or remove it.
7. Set delegation in the result to the executor and the record path, whatever the outcome.
```

## Repair brief

The repair brief always runs natively, even when the plan has an executor.

```text
You are repairing one issue branch so that it merges cleanly into <BASE> in an unattended backlog run. Nobody is watching this run, so never wait for an answer.

Issue: <ISSUE>
Worktree: <WORKTREE>, branch <BRANCH>
State: <BASE> is being merged into the branch; <the conflicted files, or "merged; these checks fail: …">
This issue's intent: <one paragraph from the issue and its result summary>
Landed issues touching the same files: <ISSUE — intent>, one per line
Checks to pass: <commands>

1. Work only in <WORKTREE>. Resolve the merge so that every issue's intended behavior survives, then run the checks.
2. If the issues require incompatible behavior, do not choose between them. Run git merge --abort if the merge is unfinished, and return needs-decision with both behaviors and their consequences.
3. On success, commit the merge in the worktree. Never reset, rebase, force, or discard commits.
4. <NAME> is <ISSUE>.repair.

<result-file section>
```
