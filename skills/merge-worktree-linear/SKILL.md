---
name: merge-worktree-linear
description: "Merge one or more Linear issue worktrees back into their base branch, then remove the worktree directory and delete the local branch. The cleanup half of /create-worktree-linear. Detects already-merged branches (e.g. merged via GitHub PR) and just cleans up in that case. Auto-commits any uncommitted implementation code in the worktree before merging (interactive Y/n prompt, defaults to yes). Pass `no-cleanup` to keep the local branch. Does not require Linear MCP and writes nothing to Linear. Triggers on: /merge-worktree-linear, merge Linear worktree, land Linear issue branch, clean up worktree after Linear issue, done with Linear issue worktree"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

Close the loop on `/create-worktree-linear`. Merge each Linear issue's branch back into its base, then remove the worktree directory and delete the local branch. If a branch was already merged remotely (typical after a GitHub PR merge), detect that and skip straight to cleanup so we don't create a redundant merge commit.

This skill **does not require Linear MCP**, and it is the only `-linear` skill that does not. The worktree path, the branch name, and the issue id are all on disk, so cleanup should not fail because a network service is unreachable. If Linear MCP happens to be available it is used for exactly one optional thing — reading an issue title for commit-message context during auto-commit — and its absence is never an error. This skill never writes to Linear; use `/update-ticket-linear <issue>` for that.

## Phase 1: Parse Arguments

Use the same grammar as `/create-worktree-linear` so users don't have to learn two. Split `$ARGUMENTS` on whitespace and classify each token:

- **Issue reference** — matches `^[A-Za-z]+-\d+$` (case-insensitive; uppercase the team key), or a `linear.app` URL containing such an identifier (extract the first path segment matching `[A-Za-z]+-\d+`).
- **`no-cleanup` flag** — matches `^no-cleanup$` (case-insensitive). When set, the local branch is preserved after merging (the worktree directory is still removed). Duplicates are ignored. Does **not** consume the base-branch slot.
- **Base branch** — anything else. At most one base-branch token. Two or more non-issue, non-flag tokens → report the conflict and stop.

If no issue references are provided, ask the user for at least one and stop. If no base-branch token is provided, default the base to `main`.

| Invocation | Issues | Base | no-cleanup |
| --- | --- | --- | --- |
| `/merge-worktree-linear ENG-42` | ENG-42 | main | no |
| `/merge-worktree-linear ENG-42 ENG-43` | ENG-42, ENG-43 | main | no |
| `/merge-worktree-linear ENG-42 dev` | ENG-42 | dev | no |
| `/merge-worktree-linear ENG-42 no-cleanup` | ENG-42 | main | yes |
| `/merge-worktree-linear ENG-42 dev no-cleanup` | ENG-42 | dev | yes |

### The trailing-token tiebreak

The Linear identifier pattern collides with branch names like `release-2026`. Because this skill needs no Linear MCP, the tiebreak is resolved entirely on disk: if a trailing id-looking token has **no** registered worktree under `.worktrees/<token>-*` and **no** branch matching `linear-<token>-*`, but does resolve as a branch (`git rev-parse --verify --quiet origin/<token>`, then `<token>`), treat it as the base and say so in one line. If it resolves as neither, report it as an issue with nothing to merge.

Two cases where the tiebreak does **not** fire, because promoting the token would leave the invocation incoherent:

- **Never promote the last remaining issue token.** If the trailing token is the only issue reference, promoting it leaves zero issues, and Phase 1's "no issue references → ask and stop" has already been evaluated. Leave it classified as an issue and report it with nothing to merge.
- **Never promote when a base token was already classified in Phase 1.** Two base branches have no arbitration rule. Report the conflict — the same one two non-issue tokens produce — and stop.

## Phase 2: Resolve the Main Repo Root and Handles

1. Confirm we're inside a git repo. Resolve the **main** repo root so the skill behaves the same whether invoked from the main checkout or from another worktree:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```

2. For each issue, discover its handles on disk by id prefix — the canonical forms are `.worktrees/<issue_id>-<slug>` and `linear-<issue_id>-<slug>`, as created by `/create-worktree-linear` and `/implement-ticket-linear`:
   - **Worktree:** scan `git worktree list --porcelain` for a registered path matching `$MAIN_ROOT/.worktrees/<issue_id>-*`.
   - **Branch:** `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`. The `--format` is required: plain `git branch --list` prefixes `+ ` for a branch checked out in another worktree and `* ` for the current branch, and those markers are not part of the name.
   - Two or more matches for either → report the ambiguity, skip this issue, continue with the rest.
   - Neither a worktree nor a branch → record "already cleaned up" and continue.

## Phase 3: Pre-flight Checks

These run once before touching any issue. If any of them fail, stop the entire batch — a clean refusal is much better than a half-applied state.

1. **CWD must not be inside a target worktree.** If the user's current working directory is inside any worktree we're about to remove, removing it would orphan their shell. Compare `git rev-parse --show-toplevel` against each target worktree path. If there's a match, refuse and tell the user to `cd "$MAIN_ROOT"` first.

2. **Main checkout must be clean, with one carve-out.** The merge lands on the main checkout's HEAD, so uncommitted changes there would be at risk. Run `git -C "$MAIN_ROOT" status --porcelain`.

   `/create-worktree-linear` deliberately leaves `.gitignore` uncommitted after adding `.worktrees/` to it, which trips this check on the first run in any repo that had not already ignored `.worktrees/` — a refusal naming a cause the user did not create. So when the **only** entry is `.gitignore` (porcelain ` M .gitignore` for a modified file, or `?? .gitignore` for a newly created one) **and** its only change is the added `.worktrees/` line (verify with `git -C "$MAIN_ROOT" diff -- .gitignore`, or by reading the new file), ask once:

   ```
   .gitignore has an uncommitted `.worktrees/` line, left by /create-worktree-linear.
   Commit it so the merge can proceed? [Y/n]
   ```

   Anything but an explicit no records consent to commit that file — but **do not commit it here**. The commit is deferred to step 5, which runs it once the main checkout is on `<base>`. On an explicit no, refuse the batch as below.

   For any other dirty state — or `.gitignore` plus anything else — refuse and tell the user to commit, stash, or discard.

3. **Fetch the base.** Run `git -C "$MAIN_ROOT" fetch origin <base>`. If `origin` is missing or the fetch fails, continue with the local base branch and warn the user that the result may be merging against a stale base.

4. **Resolve the base ref.** Prefer `origin/<base>`; fall back to local `<base>`. If neither exists, report `base branch '<base>' not found locally or on origin` and stop.

5. **Switch the main checkout to the base branch, fast-forward it, then commit the deferred `.gitignore` carve-out.**
   - If local `<base>` exists: `git -C "$MAIN_ROOT" switch <base>`.
   - If it doesn't (only `origin/<base>` was found): `git -C "$MAIN_ROOT" switch -c <base> origin/<base>`.
   - If the switch is refused because the uncommitted `.gitignore` would be overwritten (the current branch and `<base>` disagree about that file), refuse the batch and say so. Never force the switch, and never commit the carve-out on whatever branch happens to be checked out.
   - Then `git -C "$MAIN_ROOT" merge --ff-only origin/<base>` (skip if there is no `origin/<base>`). If the fast-forward fails because the local base has diverged from origin, abort and report — that needs human judgment, not a default decision.
   - Finally, if step 2 recorded consent for the `.gitignore` carve-out, commit it **now**:
     `git -C "$MAIN_ROOT" add .gitignore && git -C "$MAIN_ROOT" commit -m "chore: ignore .worktrees/"`.

   Committing after the switch is the whole point of the ordering. `/merge-worktree-linear ENG-42 dev` from a `main` checkout would otherwise strand `chore: ignore .worktrees/` on `main`; switching to `dev` would drop the ignore line, `.worktrees/` would reappear as `?? .worktrees/` on the next run, and the carve-out — scoped to a lone `.gitignore` — would not cover it, so the batch would refuse with "commit, stash, or discard" over a directory holding the user's work.

6. **Worktree dirty-state scan + auto-commit.** The natural flow is `/implement-ticket-linear ENG-42 worktree` → `/update-ticket-linear ENG-42` → `/merge-worktree-linear ENG-42`, and neither of those commits implementation code. Rather than refuse, detect it up front and offer to commit.

   For each target issue whose worktree exists on disk, run `git -C "<worktree_path>" status --porcelain`. If non-empty, record the issue plus counts of modified / added / deleted / untracked files derived from the porcelain codes (`M` / `A` / `D` / `??`).

   If the dirty list is empty, proceed to Phase 4. Otherwise present it in a single batched message and wait:

   ```
   Found uncommitted changes in 2 worktree(s):

     ENG-42  3 modified, 1 untracked   (.worktrees/ENG-42-add-csv-export)
     ENG-43  1 modified                (.worktrees/ENG-43-fix-search)

   Auto-commit each before merging? [Y/n]
   ```

   - **If yes** (default): for each dirty worktree, in order:
     1. Gather commit-message context. If Linear MCP is available, read the issue title; otherwise use the branch slug. Never fail because MCP is absent.
     2. Inspect the changes: `git -C "<worktree_path>" diff HEAD`, plus `git -C "<worktree_path>" status --porcelain` for untracked files.
     3. Generate a single conventional-style commit message reflecting the changes — subject ≤72 chars, referencing the issue as `<issue_id>`. Let the diff drive the message.
     4. Stage and commit: `git -C "<worktree_path>" add -A` then `git -C "<worktree_path>" commit -m "<message>"`.
     5. **If the commit fails** (e.g. a pre-commit hook blocks it), do **not** retry with `--no-verify`. Mark this issue with an error and continue with the next dirty worktree — Phase 4 step 2 then skips its merge because the worktree is still dirty.
     6. Tag issues committed here so Phase 5 can label them `auto-committed`.
   - **If no**: leave those worktrees alone. Phase 4 step 2's defensive dirty check skips them.

## Phase 4: Per-Issue Merge and Cleanup

Process issues in the order given. Each is independent — one failure should not stop the others.

For each `(issue_id, worktree_path, branch)`:

1. **Already cleaned up?** If neither the worktree path exists (registered in `git worktree list --porcelain`) nor the branch exists, record "already cleaned up" and continue.

2. **Worktree clean?** Defensive guard — by Phase 3 step 6 it should be. If the worktree exists and `git -C "<worktree_path>" status --porcelain` is still non-empty, skip with `uncommitted changes in <worktree_path> — auto-commit was declined or failed` and continue. Never silently lose uncommitted work.

3. **Already merged upstream?** Run `git -C "$MAIN_ROOT" merge-base --is-ancestor <branch> <base-ref>`. Exit code 0 means the branch is already in the base — the typical post-PR-merge state. Skip the merge and go to step 5.

4. **Merge the branch into the base.** From the main checkout:
   ```
   git -C "$MAIN_ROOT" merge --no-ff -m "Merge <branch> into <base>" <branch>
   ```
   `--no-ff` always produces a recognizable merge commit so the issue's work can be reverted as a single unit later.
   - **On conflict:** `git -C "$MAIN_ROOT" merge --abort` to clean up the half-merged state, record which files conflicted, skip cleanup for this issue, and continue with the next.
   - **On other failure:** record the error, skip cleanup for this issue, continue.

5. **Cleanup.** If Phase 2 discovered **no worktree** for this issue — a branch-only issue, the state `/implement-ticket-linear` leaves behind in current-checkout mode — skip the removal entirely and go straight to the branch delete below. Calling `git worktree remove` on a path that is not a registered worktree fails with `fatal: '<path>' is not a working tree` and exit 128, which matches neither failure branch below, leaving the agent guessing whether to proceed.

   Otherwise remove the worktree **before** deleting the branch — `git branch -d/-D` refuses with `cannot delete branch '<branch>' used by worktree at '<path>'` while it is still checked out there.
   - `git -C "$MAIN_ROOT" worktree remove <worktree_path>` — removes the directory and unregisters it. If it fails because the worktree is missing on disk but still registered, run `git -C "$MAIN_ROOT" worktree prune` and retry once.
   - If it fails with `contains modified or untracked files`, **do not pass `--force`** — report it and retain the worktree. Ignored build output such as `node_modules/` does not trigger this; only modified or untracked files do, which means auto-commit was declined or partially failed and there is real work to preserve.
   - If the `no-cleanup` flag was passed, stop here: leave the local branch and record `branch retained (no-cleanup)`.
   - Otherwise: `git -C "$MAIN_ROOT" branch -D <branch>`. Force-delete is intentional and safe here — this step is reached only when the merge is confirmed, either by step 3's `--is-ancestor` check or step 4's successful `merge --no-ff`, so the branch's content is in the base. It is required for the common GitHub squash-/rebase-merge case, where the branch tip is no longer a strict ancestor of the merged base and `git branch -d` refuses.
   - If `branch -D` still fails (unexpected — e.g. another worktree references the branch), record the failure and continue.

## Phase 5: Report

Print a summary the user can scan at a glance:

```
Merged 4 worktree(s) into dev:

  ENG-42  auto-committed + merged + cleaned up
  ENG-43  merged + cleaned up
  ENG-44  already merged upstream — cleaned up
  ENG-45  merged + worktree removed — branch retained (no-cleanup)
  ENG-46  SKIPPED — uncommitted changes in .worktrees/ENG-46-fix-search (auto-commit declined or failed)
  ENG-47  CONFLICT — files: src/foo.ts, src/bar.ts (worktree retained)

main checkout is now on: dev (<short-hash>)

Linear status is not updated by this skill — run /update-ticket-linear ENG-42 done when ready.
```

Group entries by outcome (auto-committed-and-merged, merged-and-cleaned, already-merged-and-cleaned, branch-retained-by-flag, skipped, conflict, error) so the user immediately sees what needs follow-up. Issues whose changes were auto-committed in Phase 3 get the `auto-committed` prefix so those commits can be audited afterwards. The `branch retained (no-cleanup)` label is informational — the user asked for it.

Do not push to origin, and do not delete the remote branch. The only commits this skill ever creates are the merge commits in Phase 4, the user-confirmed auto-commits in Phase 3 step 6, and the user-confirmed `.gitignore` commit in Phase 3 step 5.

## Safety Rules

- **Never writes to Linear**, and never requires Linear MCP. Marking an issue done stays a deliberate, separate `/update-ticket-linear` step.
- Never push, never delete a remote branch, never open a PR.
- Never pass `--force` to `git worktree remove`, and never `--no-verify` to a commit.
- Never resolve a merge conflict — abort, report, and retain the worktree.
- Refuse the batch when the cwd is inside a target worktree, or when the main checkout is dirty beyond the `.gitignore` carve-out.
- Do not touch `docs/tickets/` — that is `/merge-worktree`'s domain.
