# Ticket branches and worktrees

Read before creating, switching, or reusing a ticket checkout. These are working-directory and compatibility rules; choose routine implementation details according to the repository.

## Establish identity and directory

Resolve `CURRENT_ROOT` with `git rev-parse --show-toplevel` and `MAIN_ROOT` from the repository's absolute common git directory, verifying it against `git worktree list --porcelain`. In the usual checkout layout:

```sh
git rev-parse --path-format=absolute --git-common-dir
git worktree list --porcelain
```

Record absolute `WORK_DIR`, the expected ticket branch, and the base when known. Pass these explicitly to tools and called skills. Shell calls must select their directory each time; git can use `git -C "$WORK_DIR"`. File reads and edits use absolute paths. A previous `cd`, shell variable assignment, or sub-skill call does not guarantee state in a later tool invocation.

Preserve the interoperable names:

| Ticket source | Branch | New worktree path |
| --- | --- | --- |
| Local ticket `NNN`, filename slug | `ticket-NNN-<slug>` | `$MAIN_ROOT/.worktrees/NNN-<slug>` |
| Linear identifier `<issue_id>` | `linear-<issue_id>-<slug>` | `$MAIN_ROOT/.worktrees/<issue_id>-<slug>` |

For a new Linear branch, derive the slug from the title: lowercase, collapse non-alphanumerics to hyphens, trim, limit to about 40 characters preferably at a hyphen, and use `issue` if empty. Existing identity wins over a newly computed slug.

Inspect registered worktrees and exact ticket-ID branch prefixes before creating anything. Prefer the current checkout when it already holds the requested ticket, provided it satisfies the requested isolation: `worktree` requires a linked checkout, not `MAIN_ROOT`. Otherwise reuse one unambiguous matching checkout/branch; verify it belongs to this repository and issue. For Linear, search `linear-<issue_id>-*` using `git branch --list --format='%(refname:short)'` so branch markers are not mistaken for names. A renamed issue must not create duplicate work. Multiple matching branches or mismatched path/branch identity needs clarification; an unregistered directory at the target path must not be overwritten.

## Resolve the base

- A new current-checkout branch without an explicit base starts at current HEAD. Record the current branch as the potential merge target, unless it is already the ticket branch.
- A new isolated worktree uses the explicit base, otherwise `main`. Keep the existing `<ticket> worktree [base]` interface for both ticket families.
- Validate supplied base names and resolve the actual branch ref. For a requested base, fetch `origin/<base>` when available, prefer that ref, and fall back to a local base with a stale-source note if fetching is unavailable. If neither exists, ask instead of creating from a different ref.
- When resuming, use a base already established in the conversation or reliable repository metadata. The ticket branch and its own remote tracking branch are not its integration base. If the base is unknown, implementation can continue on the existing branch; ask when a full branch review, PR target, or merge needs it. Never merge a branch into itself.
- A new current-checkout branch from detached HEAD needs an explicit base; worktree mode already resolves its own base. Do not silently reset, rebase, or transplant an existing ticket branch to the requested base.

## Set up the checkout

Inspect existing staged, unstaged, and untracked changes before mutations and retain that baseline for scope review. Preserve unrelated work. Routine unrelated changes that can remain untouched do not require a blanket confirmation; overlap, an unsafe branch switch, or ambiguous ownership does. Do not stash, discard, or sweep changes into a future commit to make setup pass.

With `worktree`, retain isolation: use a matching linked checkout, or create one without switching the main checkout's branch. If the intended ticket branch is already checked out in `MAIN_ROOT`, resolve that conflict with the user; do not silently drop isolation or force a second checkout. Read the active host's `create-worktree` or `create-worktree-linear` before calling it with the exact ticket/issue and base from a verified main-repository context. The local variant needs a uniquely matching main-checkout ticket file. Both variants may add `.worktrees/` to the main checkout's `.gitignore` and deliberately leave that change uncommitted. Record that workflow-owned change for later finishing; inspect the actual registered result because a skipped or partial creation is not success.

Without `worktree`, use the current checkout unless the requested ticket already has a matching checkout elsewhere; report any switch of work location. Create or safely switch to the ticket branch. If that branch is checked out elsewhere, use its verified checkout rather than forcing a second checkout.

Reusing a dirty ticket checkout is allowed when the relevant work and ownership are understood. Report the resumed changes and do not count them all as newly produced implementation.

After setup, verify `WORK_DIR`, its current branch, the ticket evidence, and the actual presence of prerequisites. If the ticket or code differs from the initial context, repeat the relevant business consistency check. Announce the selected location before implementation.

## Calls across skills

Read the called skill's active host document for its refusals, side effects, and argument modes. Supply the absolute work directory, expected branch, exact ticket identity, and authorized operation. Check directory and branch before any mutation; do not assume invocation inherits a previous shell's cwd.

Implementation, validation, review, ticket notes, commits, and PRs operate on `WORK_DIR`. Switching to the merge base, merging, and worktree removal operate from `MAIN_ROOT`. Never switch all finishing operations to the main checkout indiscriminately. If the host cannot reliably target a sub-skill at the selected checkout, do not run it against a guessed directory.
