# Park, halt, and finish

`RUNS` and `RUN_DIR` are as in [execution](execution.md).

## Park an issue

Park an issue when its result is `incomplete` or `needs-decision`, when its repair fails, when `update-ticket-linear` will not mark it Done, or when it fails twice.

1. Add the label with an append-only operation: `save_issue` with `addLabels: ["human-blocked"]`. Never send `labels`, which replaces the issue's whole label set.
2. Read the issue's comments. Unless this run's parking comment is already there, post one comment in the structure `implement-ticket`'s [delivery](../../implement-ticket/references/delivery.md) uses for an incomplete result:
   - the remaining problem, and how it limits the intended workflow;
   - the obstacle and its evidence;
   - a concrete resolution; for a decision, the options and the consequence of each;
   - where the work is: the worktree and branch, or "already merged into `<base>`";
   - that removing `human-blocked` lets the next plan take the issue again.
3. Leave the workflow state, worktree, and branch as they are, and [refresh the state](execution.md#refresh-the-state): the planner removes the issue's planned dependents from this run.

## Halt the run

Halt when a condition affects every issue:

- the main checkout changes, or cannot return to the base;
- the base diverges from `origin/<base>`, including a fast-forward refusal inside `merge-worktree-linear`;
- Linear reads or writes fail for access reasons;
- the plan is missing, belongs to another repository, or another run holds the lock;
- two consecutive results fail with the same environment error.

Dispatch and land nothing more. Wait for running subagents to finish, as in [execution](execution.md#wait-for-results), and keep their results for the next run instead of routing them. Then release the lock, unless another run holds it:

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" unlock --runs-dir "$RUNS" --run-id <run-id>
```

Start the report with the halted status line, then give the cause and what the user should fix, and end with the same `/goal` line so the run can resume:

```sh
python3 "$SKILL_DIR/scripts/backlog_graph.py" halted --plan "$RUN_DIR/plan.json" --reason "<short reason>"
```

| Stop | Decided by | Goal state | Resume |
| --- | --- | --- | --- |
| Halt | This skill: continuing is unsafe | Ended, through its `HALTED` branch | Fix the cause, then paste the same `/goal` line, in either host |
| Goal pause | The host: usage limit, goal-check cap, API error, check timeout | Still set, paused | Claude Code: send a message. Codex: `/goal resume` |

## Finish

When the status line shows `AI-ELIGIBLE 0`, release the lock and write the final report. Start it with the status line; then, in the user's language, cover:

- the issues completed in this run, each with one line of business meaning from its result;
- parked issues, with the obstacle, where the work is, and the recommended resolution;
- human-gated issues, and the issues blocked by them or by parked issues;
- optional document follow-ups skipped because their preference is `ask`, with the prepared content saved under `$RUN_DIR/followups/`;
- issues that became eligible outside the plan: gather a fresh snapshot as in [planning](planning.md#gather-the-snapshot), run the planner with `--dry-run`, and list the issues in its `order` that this plan does not contain, suggesting a new plan;
- how many commits the base is ahead of `origin/<base>`, and that this run did not push.
