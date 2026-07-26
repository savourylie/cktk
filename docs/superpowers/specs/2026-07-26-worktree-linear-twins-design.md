# Design: Linear Twins for the Worktree Skills

**Date:** 2026-07-26
**Status:** Approved

## Context

Every ticket skill in cktk exists as a docs/Linear pair — `implement-ticket` ·
`implement-ticket-linear`, `update-ticket` · `update-ticket-linear`,
`clarify-ticket` · `clarify-ticket-linear`, `quiz-ticket` · `quiz-ticket-linear`.
The two worktree skills are the exception: `create-worktree` and `merge-worktree`
resolve tickets by globbing `docs/tickets/NNN-*.md`, so neither works for a Linear
issue, and neither has a twin.

The gap is not theoretical. Three existing documents route around it in prose:

- `skills/implement-ticket-linear/SKILL.md:154` creates its worktree inline with
  the parenthetical *"do not call `/create-worktree` — that skill requires
  `docs/tickets/`"*.
- `skills/implement-ticket-linear/SKILL.md:275,305` tells the user `/merge-worktree`
  "will **not** work for Linear branches" and merges inline instead.
- `skills/update-ticket-linear/SKILL.md:203` ends a completed run with *"Land the
  branch manually"* plus raw `git checkout` / `git merge` commands, for the same
  reason.

So the Linear half of the workflow can create a worktree only as a side effect of
starting an implementation, and can never clean one up except through
`implement-ticket-linear`'s landing menu or by hand.

**The naming contract already exists.** `implement-ticket-linear` and
`update-ticket-linear` both use `.worktrees/<issue_id>-<slug>` with branch
`linear-<issue_id>-<slug>`, and `update-ticket-linear:100` discovers worktrees by
the `<issue_id>-` prefix rather than by exact slug. The new twins adopt that
contract rather than inventing one; it is the single point of failure for
discovery across all four Linear skills.

## Decisions (from brainstorming)

1. **Both twins land in this pass.** `create-worktree-linear` alone would leave
   the loop open, and `update-ticket-linear`'s "land it manually" note with no
   command to point at.
2. **No delegation refactor.** `implement-ticket-linear` keeps its inline worktree
   creation and inline merge. Only the stale cross-references change. Delegating
   the landing merge would re-create the defect AGENTS.md rule 6 documents —
   calling a merge skill from inside the worktree it refuses to run in — and the
   inline path already carries the `cd "$MAIN_ROOT"` fix for it. Accepted cost:
   two implementations of "merge a linear branch" that can drift.
3. **`create-worktree-linear` never writes to Linear**, including the
   `Todo → In Progress` transition `implement-ticket-linear` performs. Preparing a
   workspace is not starting work, and a five-issue batch would fire five status
   writes.
4. **`merge-worktree-linear` does not require Linear MCP at all.** Everything it
   needs is on disk.
5. **A `.gitignore`-only dirty checkout is offered a commit rather than refused**,
   following the convention commit 448c868 established for this exact situation.

## Design

### 1. Argument grammar

Both twins mirror their docs counterparts token for token, substituting Linear
issue references for `TICKET-NNN`:

```
create-worktree-linear  <issue>...  [base]
merge-worktree-linear   <issue>...  [base] [no-cleanup]
```

`<issue>` is a Linear identifier `TEAM-NUMBER` (case-insensitive; the team key is
normalized to uppercase) or a `linear.app` URL containing one — the same two forms
`implement-ticket-linear` and `update-ticket-linear` accept. At least one is
required. Base defaults to `main`. Two or more base-looking tokens is a conflict:
report and stop.

| Invocation | Issues | Base | no-cleanup |
| --- | --- | --- | --- |
| `/create-worktree-linear ENG-42` | ENG-42 | main | — |
| `/create-worktree-linear ENG-42 ENG-43 dev` | ENG-42, ENG-43 | dev | — |
| `/merge-worktree-linear ENG-42 no-cleanup` | ENG-42 | main | yes |

#### The collision the docs twins do not have

`create-worktree` classifies a token as a ticket by `^\d+$|^#\d+$|^TICKET-\d+$`,
which no branch name realistically matches. The Linear pattern
`^[A-Za-z]+-\d+$` is not so lucky: `release-2026`, `v2-1`, and `sprint-14` are all
plausible branch names that parse as issue identifiers. The docs twins' own
example base branch, `release-2026`, collides.

Pattern classification therefore runs first, and a tiebreak applies to the
**trailing token only**, only on the path where it has already failed:

- **`create-worktree-linear`** — if a trailing id-looking token does not resolve
  as a Linear issue but does resolve as a branch (`origin/<t>`, then local `<t>`),
  treat it as the base and say so in one line rather than aborting the batch.
- **`merge-worktree-linear`** — the same shape without MCP: if a trailing
  id-looking token has no registered worktree and no `linear-<issue_id>-*` branch, but
  does resolve as a branch, it is the base.

If a repository genuinely has a branch named `ENG-42` while issue ENG-42 also
exists, the issue wins. Document it; do not add disambiguation machinery. This
matches how `implement-ticket-linear` resolves the `worktree` keyword against a
same-named branch (`skills/implement-ticket-linear/SKILL.md:58`).

### 2. Resolution: match by id prefix, not by slug

A ticket filename is stable, so `create-worktree` can treat the slug as
authoritative. A Linear title is editable, so the slug computed today may not be
the slug computed last week — and a naive exact-path check would create a **second**
worktree for an issue that already has one.

Resolution for each issue, in order:

1. A registered worktree under `$MAIN_ROOT/.worktrees/<issue_id>-*`
   (`git worktree list --porcelain`) → skip with `worktree already exists at
   <path>`, matching the docs twin's skip-if-exists.
2. Else a local branch matching `linear-<issue_id>-*` → reuse that branch, and
   place the worktree at **its** slug so the path and branch stay coherent. Report
   the reuse, and if the slug differs from the current title's, say so in one line.
3. Else create fresh: worktree `.worktrees/<issue_id>-<slug>`, branch
   `linear-<issue_id>-<slug>`.

Two matches for one id (two `linear-ENG-42-*` branches) → report the ambiguity,
skip that issue, continue the batch. This is a per-issue error, not a batch abort;
batch aborts are reserved for up-front resolution failures.

**Slug derivation is copied verbatim** from `implement-ticket-linear:95-100` —
lowercase, every run of non-alphanumerics to a single `-`, strip leading and
trailing `-`, truncate to ~40 characters preferring a cut at a hyphen, fall back to
`issue` for an empty result. Any drift here silently breaks the handoff to
`/implement-ticket-linear <id> worktree`, which reuses a worktree only when it
computes the same path.

### 3. `create-worktree-linear`

**Prerequisites.** Linear MCP, read tools only. Missing → stop with the setup hint
the other Linear skills use; do not invent API-key, CLI, or browser fallbacks.

**Phase 1 — parse arguments** per §1.

**Phase 2 — resolve root and issues.**
`MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`,
so the skill behaves the same from the main checkout or another worktree. Fetch
each issue by exact identifier. Not found, or ambiguous → **stop the whole batch**
before creating anything, exactly as `create-worktree:39` does for a missing ticket
file: a typo in one id means the user wants to fix the input, not skip ahead. Then
apply §2 resolution.

**Phase 3 — prepare the repo.** Identical to `create-worktree:50-65`: fetch the
base from `origin` (on failure, continue with the local base and warn that the
worktree may be stale), resolve `origin/<base>` → local `<base>` → stop if neither
exists, and ensure `$MAIN_ROOT/.gitignore` ignores `.worktrees/` — create the file
if missing, append the line if absent, leave it alone if present, and report any
change so the modification is not silent. **Do not commit it** (see §5).

**Phase 4 — create.** Per issue, in the order given: `git worktree add <path>
<branch>` when reusing a branch, else `git worktree add <path> -b <branch>
<base-ref>`. A single failure is reported and the batch continues.

**Phase 5 — report.** Issue id, path, and branch per row; separate sections for
skipped and failed; the `.gitignore` note; and the two follow-ups that make the
skill useful:

```
Created 2 worktree(s) from origin/main:

  ENG-42  .worktrees/ENG-42-add-csv-export   branch: linear-ENG-42-add-csv-export
  ENG-43  .worktrees/ENG-43-fix-search       branch: linear-ENG-43-fix-search

Open one with:
  cd .worktrees/ENG-42-add-csv-export

Implement in it with:
  /implement-ticket-linear ENG-42 worktree
```

Do not `cd` into the worktree, install dependencies, or commit anything.

### 4. `merge-worktree-linear`

**Prerequisites: none beyond git.** This is the one deliberate deviation from the
`-linear` convention. The worktree path, the branch name, and the issue id are all
on disk, so requiring MCP would only add a failure mode to a cleanup operation.
If MCP happens to be available it is used for exactly one thing — reading the issue
title as commit-message context during auto-commit — and its absence is never an
error; the branch slug supplies that context instead.

**Phase 1 — parse** per §1. **Phase 2 — resolve** per §2, in reverse: find the
registered worktree under `.worktrees/<issue_id>-*`, else the `linear-<issue_id>-*`
branch. Neither → record "already cleaned up" and continue.

**Phase 3 — pre-flight**, mirroring `merge-worktree:47-87`, run once for the whole
batch:

1. **CWD must not be inside a target worktree** — removing it would orphan the
   user's shell. Refuse and tell them to `cd "$MAIN_ROOT"`.
2. **Main checkout must be clean**, with one carve-out. `/create-worktree-linear`
   leaves `.gitignore` dirty by design, which trips this check deterministically on
   the first run in any repo that had not already ignored `.worktrees/` — the
   AGENTS.md rule 6 defect, reached here through direct invocation rather than
   delegation. When the *only* dirty entry is `.gitignore` and its only change is
   the added `.worktrees/` line, offer to commit it (`[Y/n]`, default yes),
   matching the convention 448c868 established. Anything else refuses as the docs
   twin does.
3. **Fetch and resolve the base**, then switch the main checkout to it and
   fast-forward — `git switch <base>` when it exists locally, else
   `git switch -c <base> origin/<base>`; abort and report if the fast-forward fails
   on a diverged local base.
4. **Dirty-worktree scan with batched auto-commit.** For each target worktree,
   `git -C <path> status --porcelain`; present all dirty worktrees in one message
   with modified/added/deleted/untracked counts and ask `[Y/n]`, default yes. On
   yes, commit each with a conventional-style message referencing the issue id. A
   commit that fails (pre-commit hook) is **not** retried with `--no-verify`; the
   ticket is marked and Phase 4 skips its merge because the worktree is still
   dirty.

**Phase 4 — per-issue merge and cleanup**, each issue independent:
`merge-base --is-ancestor` detects a branch already merged upstream (the usual
post-PR state) and skips straight to cleanup; otherwise
`git -C "$MAIN_ROOT" merge --no-ff -m "Merge linear-<issue_id>-<slug> into <base>"`.
On conflict: `merge --abort`, report the conflicted files, retain the worktree,
continue. Cleanup is `worktree remove` (with a `worktree prune` retry when the
directory is gone but still registered) then `branch -D` unless `no-cleanup` was
passed. `-D` is deliberate and safe here for the same reason as
`merge-worktree:107` — this step is reached only when the merge is confirmed, and
a GitHub squash-merge leaves the branch tip a non-ancestor that `-d` would refuse.

**Phase 5 — report**, grouped by outcome, plus the Linear-specific closing note:

```
Linear status is not updated by this skill — run /update-ticket-linear ENG-42 done
when ready.
```

No push, no remote branch deletion, no Linear write.

### 4a. Verified against real git (2026-07-26)

Run in a scratch repo with a real `origin` remote before writing any of the four
documents, because all four prescribe these sequences verbatim.

1. **`git branch --list 'linear-ENG-42-*'` prints `+ linear-ENG-42-…`** — the `+`
   marks a branch checked out in another worktree, and `*` marks the current one.
   Prefix discovery must use
   `git branch --list --format='%(refname:short)' 'linear-<issue_id>-*'`, which
   prints the bare name. A naive parse would carry the marker into a branch name.
2. **A squash-merged branch is not an ancestor of the base.**
   `git merge-base --is-ancestor` exits 1 after `merge --squash`, and `git branch -d`
   then refuses. This is the documented reason `merge-worktree:107` uses `-D`, now
   confirmed rather than assumed; the Linear twin inherits it for the same reason.
3. **`git branch -d` refuses while the branch is checked out in a worktree**
   (`cannot delete branch … used by worktree at …`). Cleanup must therefore remove
   the worktree *before* deleting the branch — the order `merge-worktree:105-107`
   already uses, now with a concrete failure behind it.
4. **`git worktree remove` refuses on modified or untracked files**
   (`fatal: … contains modified or untracked files, use --force to delete it`) but
   **succeeds when the worktree is clean and holds only ignored files** such as
   `node_modules/`. Auto-commit runs `git add -A`, which sweeps untracked files and
   leaves ignored ones — so after an accepted auto-commit, removal succeeds. The
   refusal is reachable only when the user *declined* auto-commit, and Phase 4's
   dirty guard already skips those tickets before cleanup. **Therefore
   `merge-worktree-linear` never passes `--force`**: on that error it reports and
   retains the worktree. This narrows known follow-up 5 of the 2026-07-25 spec,
   which assumed ignored build output alone would block removal.
5. **`git worktree add <path> -b <branch> origin/<base>` sets the new branch to
   track `origin/<base>`** ("set up to track 'origin/main'"), so the worktree
   reports "up to date with 'origin/main'" and a later bare `git push` targets the
   wrong ref. `create-worktree` has always done this; the Linear twin inherits it
   for parity rather than silently diverging with `--no-track`. Recorded as a known
   follow-up below, since fixing it is a decision about both pairs at once.

### 5. `.gitignore` stays uncommitted

`create-worktree-linear` inherits the docs twin's rule: report the `.gitignore`
change, never commit it. Committing it would be a repo-level change the user did
not ask for, from a skill whose job is to prepare a workspace. The consequence —
tripping a downstream clean-checkout check — is handled where it lands, in
§4 Phase 3 step 2, rather than by making creation commit on the user's behalf.

### 6. Cross-reference fixes

The whole of decision 2. Six references across four documents, all currently
accurate about `/merge-worktree` and all now incomplete:

| Location | Change |
| --- | --- |
| `skills/implement-ticket-linear/SKILL.md:275` | keep the inline-merge statement; add that `/merge-worktree-linear` lands it standalone later |
| `skills/implement-ticket-linear/SKILL.md:305` | same, as the justification for option 1 merging inline |
| `.agents/skills/implement-ticket-linear/SKILL.md:120,142` | same two, in Codex idiom (`$merge-worktree-linear`) |
| `skills/update-ticket-linear/SKILL.md:203` | replace "Land the branch manually" with `/merge-worktree-linear <issue_id>`; keep the raw git commands as the fallback |
| `.agents/skills/update-ticket-linear/SKILL.md:114` | same, Codex idiom |

No control flow changes in any of the four.

### 7. Codex tree

Both twins get a separately written `.agents/skills/<name>/SKILL.md` in Codex
idiom — `$create-worktree-linear`, explicit-invocation framing, `name` and
`description` frontmatter only — plus `agents/openai.yaml` with
`allow_implicit_invocation: false`, matching `create-worktree`'s own policy since
both mutate the working tree. `.agent/skills/<name>` is a symlink to
`../../skills/<name>`.

### 8. Validator

`scripts/check-codex-skills.sh` gains `validate_worktree_linear_contract`. The
generic loop already covers frontmatter, the openai.yaml contract, and the
symlink; this function pins the invariants whose breakage would surface only as a
user's missing worktree:

- both new skills, both trees: `require_literal` `linear-<issue_id>-<slug>` and
  `.worktrees/<issue_id>-<slug>` — the naming contract shared with the implement
  and update twins.
- `create-worktree-linear`, both trees: `require_literal "never writes to Linear"`
  and `forbid_literal "save_issue"`, pinning decision 3 against a future
  copy-paste from `implement-ticket-linear`. The forbidden literal is the write
  tool, not the phrase `Todo → In Progress`: the skill legitimately names that
  transition when explaining which write it declines to make, so forbidding the
  phrase would fire on its own disclaimer.
- `merge-worktree-linear`, both trees:
  `require_literal "does not require Linear MCP"`, pinning decision 4.
- `implement-ticket-linear` and `update-ticket-linear`, both trees:
  `require_literal "merge-worktree-linear"`, so §6 cannot rot back.

These skills are **not** added to `validate_clarify_contract` — it requires
`disable-model-invocation: true`, which would break the `Triggers on:` model
invocation both twins rely on, the same reasoning that produced
`validate_implement_contract`.

### 9. Registration

- `skills/create-worktree-linear/SKILL.md`,
  `skills/merge-worktree-linear/SKILL.md` — canonical.
- `.agents/skills/{create,merge}-worktree-linear/{SKILL.md,agents/openai.yaml}`.
- `.agent/skills/{create,merge}-worktree-linear` — symlinks.
- `README.md` — the Git-workflow skills table (lines 48-49), the `.agents/skills/`
  install listing (138-139), the `for s in …` install loop (186), and the
  "Git and worktrees" usage examples (241-248).
- `catalog.json` — two entries beside the existing worktree pair, using the
  established twin phrasing.
- `scripts/check-codex-skills.sh` — `validate_worktree_linear_contract` plus its
  call site.
- Acceptance gate: `./scripts/check-codex-skills.sh` passes.

Plugin `keywords` in `.claude-plugin/*.json` are untouched — neither existing
worktree skill appears there.

## Out of scope

- Changing `create-worktree` or `merge-worktree`. Their grammar is
  `TICKET-NNN`-shaped and stays that way; teaching one skill both grammars was
  considered and rejected in favor of naming symmetry with the other four twins.
- Refactoring `implement-ticket-linear` to delegate to either new skill
  (decision 2).
- Writing any Linear status from either new skill, including on merge.
- Pushing, deleting remote branches, or opening PRs.
- Automatic conflict resolution during a merge.

## Known follow-ups

Recorded at design time; none blocks this change.

1. **Worktree branches track the base branch.** Per §4a finding 5, both
   `create-worktree` and `create-worktree-linear` leave the new branch tracking
   `origin/<base>`. Adding `--no-track` would fix the misleading "up to date with
   'origin/main'" status and the wrong bare-push target, but it changes both pairs
   and belongs in its own change.
2. **The 2026-07-25 spec's known follow-up 5 is narrower than recorded.** Ignored
   build output does not block `git worktree remove`; only modified or untracked
   files do. The Linear twins' inline removal in `implement-ticket-linear` Phase 9
   is therefore safe whenever `commit-ticket` has just run, and the gap is limited
   to a `commit-ticket` that leaves files uncommitted.

## Acceptance criteria

1. `/create-worktree-linear ENG-42` creates `.worktrees/ENG-42-<slug>` on branch
   `linear-ENG-42-<slug>` off `origin/main`, and `/implement-ticket-linear ENG-42
   worktree` then reuses that worktree instead of creating a second one.
2. `/create-worktree-linear ENG-42 ENG-43 dev` creates both off `origin/dev`; an
   unresolvable issue id in the batch stops it before any worktree is created.
3. A trailing token that looks like an id but is a branch (`release-2026`) is
   treated as the base, with a one-line note — not reported as a missing issue.
4. An issue that already has a worktree is skipped; an issue whose branch exists
   without a worktree reuses that branch at its own slug, and reports the reuse.
5. Neither skill performs any Linear write; `create-worktree-linear` does not move
   a Todo issue to In Progress.
6. `/merge-worktree-linear ENG-42` merges `--no-ff` into the base, removes the
   worktree, deletes the branch, and does not push. `no-cleanup` retains the
   branch. It completes with Linear MCP unavailable.
7. A main checkout dirty only from `create-worktree-linear`'s `.gitignore` line
   offers to commit it (default yes); any other dirt refuses.
8. An already-merged branch (post-PR) is detected and only cleaned up, with no
   redundant merge commit.
9. All six cross-references in §6 name `merge-worktree-linear`, and no document
   claims the Linear twins require `docs/tickets/`.
10. `./scripts/check-codex-skills.sh` passes, including
    `validate_worktree_linear_contract`.
