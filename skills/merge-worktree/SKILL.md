---
name: merge-worktree
description: "Merge one or more ticket worktrees back into their base branch, then remove the worktree directory and delete the local branch. The cleanup half of /create-worktree. Detects already-merged branches (e.g., merged via GitHub PR) and just cleans up in that case. Auto-commits any uncommitted implementation code in the worktree before merging (interactive Y/n prompt, defaults to yes) — users do NOT need to run /commit-ticket or git commit before /merge-worktree. Pass `no-cleanup` to keep the local branch around after merging (worktree directory is still removed). Use when the user is done with a ticket worktree and wants it landed or cleaned up."
user-invocable: true
---

**Argument:** `$ARGUMENTS`

Close the loop on `/create-worktree`. Merge each ticket's branch back into its base, then remove the worktree directory and delete the local branch. If a branch was already merged remotely (typical after a GitHub PR merge), detect that and skip straight to cleanup so we don't create a redundant merge commit.

## Phase 1: Parse Arguments

Use the same rule as `/create-worktree` so users don't have to learn two grammars. Split `$ARGUMENTS` on whitespace and classify each token:

- **Ticket number** — matches `^\d+$`, `^#\d+$`, or `^TICKET-\d+$` (case-insensitive). Normalize to a 3-digit zero-padded number.
- **`no-cleanup` flag** — matches `^no-cleanup$` (case-insensitive). When set, the local branch is preserved after merging (the worktree directory is still removed). Duplicates are ignored. Does **not** consume the base-branch slot.
- **Base branch** — anything else. At most one base-branch token. Two or more non-ticket, non-flag tokens → report the conflict and stop.

If no ticket numbers are provided, ask the user for at least one and stop. If no base-branch token is provided, default the base to `main`.

Examples:

| Invocation | Tickets | Base | no-cleanup |
| --- | --- | --- | --- |
| `/merge-worktree 7` | 007 | main | no |
| `/merge-worktree 7 8 9` | 007, 008, 009 | main | no |
| `/merge-worktree 7 dev` | 007 | dev | no |
| `/merge-worktree TICKET-007 release-2026` | 007 | release-2026 | no |
| `/merge-worktree 7 no-cleanup` | 007 | main | yes |
| `/merge-worktree 7 dev no-cleanup` | 007 | dev | yes |

## Phase 2: Resolve the Main Repo Root and Tickets

1. Confirm we're inside a git repo. Resolve the **main** repo root so the skill behaves the same whether invoked from the main checkout or from another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```

2. For each ticket number `NNN`, glob `$MAIN_ROOT/docs/tickets/NNN-*.md`.
   - If no file matches, report `TICKET-NNN not found in docs/tickets/` and stop the whole batch — a typo in one number means the user wants to fix the input rather than half-cleanup.
   - If multiple files match, report the ambiguity and stop.

3. Extract the slug from each filename (strip the `NNN-` prefix and `.md` suffix). For each ticket, record:
   - Worktree path: `$MAIN_ROOT/.worktrees/NNN-<slug>`
   - Branch name: `ticket-NNN-<slug>`

## Phase 3: Pre-flight Checks

These run once before touching any ticket. If any of them fail, stop the entire batch — a clean refusal is much better than a half-applied state.

1. **CWD must not be inside a target worktree.** If the user's current working directory is inside any worktree we're about to remove, removing it would orphan their shell. Compare `git rev-parse --show-toplevel` against each target worktree path. If there's a match, refuse and tell the user to `cd "$MAIN_ROOT"` first.

2. **Main checkout must be clean.** The merge will land on the main checkout's HEAD, so any uncommitted changes there would be at risk. Run `git -C "$MAIN_ROOT" status --porcelain`. If it produces any output, refuse and tell the user to commit, stash, or discard.

3. **Fetch the base.** Run `git -C "$MAIN_ROOT" fetch origin <base>`. If `origin` is missing or the fetch fails (no remote, no network, no such ref), continue with the local base branch and warn the user that the result may be merging against a stale base.

4. **Resolve the base ref.** Prefer `origin/<base>`; fall back to local `<base>`. If neither exists, report `base branch '<base>' not found locally or on origin` and stop.

5. **Switch the main checkout to the base branch and fast-forward it.**
   - If local `<base>` exists: `git -C "$MAIN_ROOT" switch <base>`.
   - If local `<base>` doesn't exist (only `origin/<base>` was found): `git -C "$MAIN_ROOT" switch -c <base> origin/<base>`.
   - Then update local base to match origin: `git -C "$MAIN_ROOT" merge --ff-only origin/<base>` (skip if no `origin/<base>`). If the FF fails (local base has diverged from origin), abort and report — that's a real situation that needs human judgment, not a default decision.

6. **Worktree dirty-state scan + auto-commit.** The natural cktk workflow is `/implement-ticket NNN worktree` → `/update-ticket NNN` → `/merge-worktree NNN`, which leaves implementation code uncommitted in the worktree (only ticket metadata gets committed by `/update-ticket`). Rather than refuse to merge, we detect this state up front and offer to commit it.

   For each target ticket whose worktree exists on disk, run `git -C "<worktree_path>" status --porcelain`. If the output is non-empty, record the ticket plus a short summary of what's dirty — counts of modified / added / deleted / untracked files derived from the porcelain status codes (`M`/`A`/`D`/`??`) — into a "dirty worktrees" list.

   If the dirty list is empty, proceed to Phase 4. Otherwise, present the list to the user in a single batched message and wait for confirmation:

   ```
   Found uncommitted changes in 2 worktree(s):

     TICKET-007  3 modified, 1 untracked   (.worktrees/007-fix-search)
     TICKET-009  1 modified                (.worktrees/009-add-export)

   Auto-commit each before merging? [Y/n]
   ```

   - **If yes** (default): for each dirty worktree, in order:
     1. Read the ticket title from `docs/tickets/NNN-*.md` (first H1 line) for commit-message context.
     2. Inspect the changes: `git -C "<worktree_path>" diff HEAD` (and `git -C "<worktree_path>" status --porcelain` for untracked files).
     3. Generate a single conventional-style commit message that reflects the changes — subject line ≤72 chars, referencing the ticket as `TICKET-NNN`. Don't pad with boilerplate; let the diff drive the message.
     4. Stage and commit: `git -C "<worktree_path>" add -A` then `git -C "<worktree_path>" commit -m "<message>"`.
     5. **If the commit fails** (e.g., a pre-commit hook blocks it), do **not** retry with `--no-verify`. Mark this ticket with an error and continue with the next dirty worktree — Phase 4 step 2 will then skip the merge for it because the worktree is still dirty.
     6. Tag tickets that were committed here so Phase 5 can label them `auto-committed` in the report.
   - **If no**: leave those worktrees alone. They'll be skipped naturally by Phase 4 step 2's defensive dirty check.

## Phase 4: Per-Ticket Merge and Cleanup

Process tickets in the order given. Each ticket is independent — one ticket's failure should not stop the others.

For each `(NNN, slug, worktree_path, branch)`:

1. **Already cleaned up?** If neither `<worktree_path>` exists on disk (and is registered in `git worktree list --porcelain`) nor the branch exists (`git rev-parse --verify --quiet <branch>` fails), record as "already cleaned up" and continue.

2. **Worktree clean?** Defensive guard — by Phase 3 step 6 the worktree should already be clean (either it always was, or the user accepted the auto-commit prompt). If the worktree exists and `git -C "<worktree_path>" status --porcelain` is still non-empty, skip with `uncommitted changes in <worktree_path> — auto-commit was declined or failed` and continue with the next ticket. Never silently lose uncommitted work.

3. **Already merged upstream?** Run `git -C "$MAIN_ROOT" merge-base --is-ancestor <branch> <base-ref>`. If exit code is 0, the branch is already in the base — typical post-PR-merge state. Skip the merge step and go straight to step 5.

4. **Merge the branch into the base.** From the main checkout: `git -C "$MAIN_ROOT" merge --no-ff -m "Merge <branch> into <base>" <branch>`. `--no-ff` always produces a recognizable merge commit so the ticket's work can be reverted as a single unit later.
   - **On conflict**: run `git -C "$MAIN_ROOT" merge --abort` to clean up the half-merged state, record which files conflicted, skip cleanup for this ticket, and continue with the next.
   - **On other failure**: record the error, skip cleanup for this ticket, continue.

5. **Cleanup.**
   - `git -C "$MAIN_ROOT" worktree remove <worktree_path>` — removes the directory and unregisters the worktree. If it fails because the worktree is missing on disk but still registered, run `git -C "$MAIN_ROOT" worktree prune` and retry once.
   - If the `no-cleanup` flag was passed, stop here: leave the local branch in place and record `branch retained (no-cleanup)` for the report.
   - Otherwise: `git -C "$MAIN_ROOT" branch -D <branch>`. Force-delete is intentional and safe here — we only reach this step when the merge is confirmed, either via step 3's `--is-ancestor` check or step 4's successful `merge --no-ff`. In both cases the branch's content is in the base, so there's no unmerged work to lose. This is the fix for the common GitHub squash-/rebase-merge case, where the local branch tip is no longer a strict ancestor of the merged base and `git branch -d` would refuse.
   - If `branch -D` still fails (unexpected — e.g., another worktree references the branch), record the failure for the report and continue with the next ticket.

## Phase 5: Report

Print a summary the user can scan at a glance:

```
Merged 4 worktree(s) into dev:

  TICKET-007  auto-committed + merged + cleaned up
  TICKET-008  merged + cleaned up
  TICKET-009  already merged upstream — cleaned up
  TICKET-010  merged + worktree removed — branch retained (no-cleanup)
  TICKET-011  SKIPPED — uncommitted changes in .worktrees/011-fix-search (auto-commit declined or failed)
  TICKET-012  CONFLICT — files: src/foo.ts, src/bar.ts (worktree retained)

main checkout is now on: dev (<short-hash>)
```

Group entries by outcome (auto-committed-and-merged, merged-and-cleaned, already-merged-and-cleaned, branch-retained-by-flag, skipped, conflict, error) so the user immediately sees what needs follow-up. Tickets where Phase 3 step 6 synthesized a commit get the `auto-committed` prefix so the user can audit those commits afterward if they want. The `branch retained (no-cleanup)` label is informational — the user asked for it explicitly via the flag, so it does not need follow-up.

Do not push to origin, and do not delete the remote branch. The only commits this skill ever creates are (a) the merge commits in Phase 4 and (b) the user-confirmed auto-commits in Phase 3 step 6. Push is a separate decision the user makes (often via `/commit-push-pr` or plain `git push`).
