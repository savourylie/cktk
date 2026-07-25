# Design: Always-Branch and Landing Step for the Implement Twins

**Date:** 2026-07-25
**Status:** Approved

## Context

`implement-ticket` and `implement-ticket-linear` currently guarantee neither a
branch nor an outcome:

- **Non-worktree mode** implements on whatever branch happens to be checked out.
  Running the skill on `main` writes ticket code straight onto `main`'s working
  tree.
- **Worktree mode** already creates a branch (`ticket-NNN-<slug>` /
  `linear-<ID>-<slug>`) plus an isolated checkout, and points at
  `merge-worktree` to land it.
- **Both** end with an explicit rule forbidding commits: *"Do NOT commit changes
  … or invoke the `update-ticket`, `commit-ticket`, or `commit-push-pr`
  skills."* The work is left uncommitted and the user decides everything.

Two changes are wanted: a branch on **every** invocation, and a proposal at the
end offering to merge to the base branch or hand off to `commit-push-pr`.

**Tree divergence to respect.** The Codex copies are separate documents, not
copies. `.agents/skills/implement-ticket/SKILL.md` already commits (its Phase 6)
and updates ticket status itself (Phase 7), and supports a no-argument backlog
loop that the Claude copy does not have. This divergence is deliberate and
recorded in `docs/superpowers/plans/2026-07-24-unknowns-methodology.md`. The two
trees therefore need different edits.

**Relevant existing behavior.** `update-ticket` stages only `docs/tickets/`
(`skills/update-ticket/SKILL.md:198-200`), so its commit can never sweep code in.
That makes it safe to run the status update *before* the code commit and still
have both land on the same branch.

## Decisions (from brainstorming)

1. **In-place branch by default; `worktree` stays opt-in.** The default run
   branches in the current checkout. Worktree mode is unchanged — it already
   creates a branch, so both paths now guarantee one.
2. **Base is the current HEAD, with an optional override.** No fetch and no
   branch switching in the common case; an explicit base token forks from
   `origin/<base>` instead.
3. **Landing menu offers merge / PR / commit-only / nothing**, defaulting to
   *nothing* so an ambiguous or absent answer never mutates the repo.
4. **Status handling is asymmetric.** The ticket file lives in the repo, so the
   docs twin offers to run `update-ticket` as part of landing. Linear status is
   an external write, so the Linear twin only reminds — its no-writes guarantee
   is preserved.
5. **A dirty tree warns and confirms once, then carries over.** Default no.
6. **The Codex backlog loop branches per ticket forked from HEAD** so dependent
   tickets stack and still compile, and asks the landing question once at the
   end of the run for the whole stack.

## Design

### 1. Argument grammar

The base token is no longer gated behind `worktree`:

`<ticket> [worktree] [base]`

| Invocation | Mode | Branch | Base recorded |
| --- | --- | --- | --- |
| `007` | in-place | `ticket-007-<slug>` | current branch (HEAD, no fetch) |
| `007 dev` | in-place | `ticket-007-<slug>` | `origin/dev` (fetched) |
| `007 worktree` | worktree | `ticket-007-<slug>` | `origin/main` |
| `007 worktree dev` | worktree | `ticket-007-<slug>` | `origin/dev` |

The Linear twin takes `<issue> [worktree] [base]` with branch
`linear-<ID>-<slug>`; everything else is identical.

**Typo guard.** The current specs reject any second token that is not
`worktree`, which is what protects against `worktre`. Opening the base slot
would lose that protection, so the guard moves to resolution: a non-`worktree`
token must resolve to a real branch (`origin/<tok>` or local `<tok>`). If it does
not:

```
unrecognized argument 'worktre' — did you mean 'worktree'?
(no branch named 'worktre' found locally or on origin)
```

A repository that genuinely has a branch named `worktree` resolves in favor of
worktree mode. Document this; do not add disambiguation machinery for it.

A fourth token is still an error. Detached HEAD with no base token stops and asks
for an explicit base, because there would be no merge target to record.

### 2. Branch phase

Slots into `implement-ticket` Phase 1 after slug resolution, and
`implement-ticket-linear` Phase 3. Branch names are exactly the ones worktree
mode already uses, so `update-ticket`, `merge-worktree`, and `quiz-ticket` need
no new pattern to recognize.

In-place mode:

```
already on <branch>              → reuse; report "resuming on <branch>"
<branch> exists, not checked out → git switch <branch>; report "reusing existing branch"
otherwise:
  dirty tree?  → list the files, confirm once (default NO); on no, stop
  base token?  → git fetch origin <base>
                 git switch -c <branch> origin/<base>   (fall back to local <base>)
  no token?    → git switch -c <branch>
```

The dirty-tree prompt exists because `git switch -c` carries uncommitted changes
onto the new branch, where the landing step would otherwise sweep unrelated work
into the ticket commit:

```
Working tree has 3 uncommitted file(s):
  M  src/api/client.ts
  M  README.md
  ?? scratch.md

These will be carried onto ticket-007-add-export and may land in the
ticket commit.

Continue? [y/N]
```

If `git switch -c <branch> origin/<base>` fails because local changes conflict
with the target base, report git's error and stop — do not force, stash, or
discard.

**Resuming needs its own base rule.** Base resolution reads the current branch,
but on the reuse path the current branch *is* the ticket branch, so a naive read
records the branch as its own base. Landing option 1 would then merge the branch
into itself — git reports "Already up to date" and exits 0, so the skill would
report a successful land while nothing reached the real base, and the follow-up
`git branch -d` would fail because the branch is checked out. Nothing on disk
records what a branch forked from, so when the current branch already is the
ticket branch and no base token was passed, **ask once** (following the portable
interaction rules), listing the plausible bases that actually exist locally or on
`origin`. If the user declines to answer, mark landing option 1 unavailable
rather than guessing — options 2, 3, and 4 need no base.

Worktree mode is untouched except that it records `base` the same way, so the
landing step has a target in both modes.

### 3. Landing phase

A new final phase in both skills, replacing the "do not commit" rule. It runs
**after** the implementation summary and manual-testing instructions, so the user
reads what was built before choosing.

Asked once. An ambiguous, empty, or unavailable answer is treated as option 4.
Never re-asked.

```
TICKET-007 implemented on ticket-007-add-export (base: dev).
How do you want to land it?

  1  Merge into dev locally  (commit → merge --no-ff → delete branch)
  2  Open a PR               (invokes commit-push-pr)
  3  Commit only             (stay on the branch, decide later)
  4  Nothing                 (leave changes uncommitted)  [default]
```

**Option 2 is pre-flighted.** If `git remote get-url origin` or `gh auth status`
fails, option 2 is listed as unavailable with the reason rather than offered and
then failing mid-flight.

Behavior per option and mode:

| | in-place | worktree |
| --- | --- | --- |
| **1 Merge** | `commit-ticket` → `git switch <base>` → `git merge --no-ff` → `git branch -d <branch>` | docs twin: delegate to `merge-worktree NNN <base>`, which already auto-commits, merges, removes the worktree, and deletes the branch. Linear twin: the same steps inline, since `merge-worktree` is `docs/tickets/`-only |
| **2 PR** | `commit-push-pr`; stay on the branch | same — it runs in the pinned worktree cwd and pushes the ticket branch. A later `merge-worktree NNN` detects "already merged upstream" and only cleans up |
| **3 Commit** | `commit-ticket`; stay on the branch | same |
| **4 Nothing** | today's behavior; report the branch name and how to land later | unchanged |

Rules that apply to option 1:

- **The base may not exist locally.** When the run forked from `origin/<base>`,
  a local `<base>` may never have existed. Follow `merge-worktree`'s rule
  (`skills/merge-worktree/SKILL.md:59-62`): `git switch <base>` if it exists
  locally, otherwise `git switch -c <base> origin/<base>`.
- **Never push.** This matches `merge-worktree`, which also stops at the local
  merge. The report ends with `git push` as the explicit next step.
- **On conflict:** `git merge --abort`, report the conflicted files, leave the
  branch intact, and do not attempt resolution.
- **Use `git branch -d`, not `-D`.** After a successful `--no-ff` merge the safe
  delete always succeeds; a refusal is information worth surfacing rather than
  overriding. (`merge-worktree` uses `-D` because it must also handle GitHub
  squash-merges, where the branch tip is not an ancestor of the base.)

### 4. Status follow-up (docs twin only)

When the user picks 1, 2, or 3, ask exactly one follow-up, default no:

```
Also mark TICKET-007 done? [y/N]
```

On yes, invoke `update-ticket NNN done` **before** the code commit. Its commit
touches only `docs/tickets/`, so the two commits stay clean and separate, and
both land on the ticket branch — inside the merge for option 1, inside the PR for
option 2.

The Linear twin does not ask. It reports:

```
Linear status unchanged — run update-ticket-linear ENG-42 done when ready.
```

### 5. Portable interaction

These skills gain user prompts for the first time, so both copies of both skills
adopt the `## Portable interaction rules` section already used by the clarify and
quiz twins and by `interact-html`:

- Show every option with a stable number and a one-line description of what it
  does.
- Use the host's structured choice mechanism only when it is available and can
  represent the options clearly; otherwise ask a concise numbered prose question
  and accept the number or the option name.
- Never assume an option limit or an automatically supplied "Other" choice.
- Treat an unanswered or ambiguous prompt as the documented default; never
  re-ask, never escalate.
- Refer to other skills by name; use host-native syntax when known (`/skill` in
  Claude Code, `$skill` in Codex), otherwise the plain skill name and arguments.

These skills are **not** added to `validate_clarify_contract`, because that
function also requires `disable-model-invocation: true`, which would break the
`Triggers on:` model invocation both implement twins rely on. Instead
`scripts/check-codex-skills.sh` gains a `validate_implement_contract` covering
the four implement documents with the literal checks only — require
`Portable interaction` and `Never assume an option limit`, forbid
`AskUserQuestion`. This mirrors how `validate_interact_contract` deliberately
omits the explicit-only metadata requirements for `interact-html`.

### 6. Safety rules

The blanket prohibition in both Claude copies is replaced by a scoped one:

> No commit, merge, push, or branch deletion happens before the landing prompt,
> and then only per the user's explicit choice. Never force-push, and never
> delete or overwrite a remote branch.

The second sentence originally read "never touch a remote branch," which
contradicted landing option 2 — `commit-push-pr` pushes the ticket branch, which
is touching a remote branch. The intent was always to forbid *destructive* remote
operations, not the ordinary push the user explicitly asked for.

Everything else stands: do not switch the user's main checkout in worktree mode,
do not delete the worktree, stop rather than overwrite when unrelated dirty
changes conflict. The Linear twin keeps its no-writes rule intact — a local merge
is not a Linear write, and the opt-in as-built comment remains its only one.

### 7. Codex tree

Both Codex documents get the same grammar (§1) and branch phase (§2).

The landing menu differs because the Codex copy already commits and updates
status: option 3 is redundant and the status follow-up is automatic, so its menu
is **merge / PR / stay on branch (default)**.

The no-argument backlog loop branches per ticket **forked from HEAD**, so each
ticket's work stacks on the previous one and dependent tickets still compile.
The landing question is asked **once at the end of the run** for the whole stack,
targeting the base recorded at the start. Forking every ticket from the same base
instead would leave dependent tickets unable to see their predecessors' code.

### 8. Registration

- `skills/implement-ticket/SKILL.md`, `skills/implement-ticket-linear/SKILL.md` —
  canonical edits.
- `.agents/skills/implement-ticket/SKILL.md`,
  `.agents/skills/implement-ticket-linear/SKILL.md` — Codex edits in Codex idiom
  (`$skill-name`).
- `.agent/skills/` — symlinks; nothing to do.
- Four `description:` frontmatter strings — triggers mention branching and
  landing.
- `README.md` — the implement-twins table row and the usage examples at lines
  219-222.
- `catalog.json` — the two implement descriptions.
- `scripts/check-codex-skills.sh` — add `validate_implement_contract` (§5) and
  call it alongside the existing validators.
- Acceptance gate: `./scripts/check-codex-skills.sh` passes.

## Out of scope

- Changing `create-worktree`, `merge-worktree`, `commit-ticket`, or
  `commit-push-pr` themselves. `merge-worktree:64` describes the old
  "implementation code left uncommitted" flow, which stays accurate for option 4;
  it gets a parenthetical, not a rewrite.
- Adding a backlog loop to the Claude copy of `implement-ticket`.
- Pushing on option 1, or any remote-branch operation.
- Writing Linear status from `implement-ticket-linear`.
- Automatic conflict resolution during a landing merge.

## Acceptance criteria

1. `implement-ticket 007` on any branch creates and switches to
   `ticket-007-<slug>` before writing code; re-running it while already on that
   branch resumes without creating a second branch.
2. `implement-ticket 007 dev` fetches and forks from `origin/dev`;
   `implement-ticket 007 worktre` stops with the "did you mean 'worktree'?"
   error.
3. A dirty working tree produces the file list and a confirm prompt that defaults
   to no; answering no stops before any branch is created.
4. Every run ends with the landing prompt. Option 4 (or no answer) leaves the
   repo exactly as today's skills do.
5. Option 1 produces a `--no-ff` merge commit on the recorded base, deletes the
   ticket branch, and does not push. Option 2 reaches an open PR via
   `commit-push-pr`, or is marked unavailable when `origin` or `gh` is missing.
6. In worktree mode the docs twin's option 1 delegates to
   `merge-worktree NNN <base>`; the Linear twin performs the equivalent steps
   inline.
7. The docs twin offers the status follow-up on options 1-3 and runs
   `update-ticket NNN done` before the code commit. The Linear twin never writes
   Linear status.
8. The Codex backlog loop creates one branch per ticket forked from HEAD and asks
   the landing question once at the end of the run.
9. `./scripts/check-codex-skills.sh` passes, including the new
   `validate_implement_contract` over all four implement documents.
