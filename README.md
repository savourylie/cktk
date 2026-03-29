# cktk

Software development workflow skills for both OpenAI Codex and Claude Code.

## Compatibility Layout

This repo intentionally carries two skill trees:

- `.agents/skills/` is the Codex-facing tree.
- `skills/` is the Claude-facing tree.

The two trees share support files where possible, but they do not share `SKILL.md` files. The Codex skills are rewritten to match Codex conventions and metadata.

## Skills

- `implement-ticket` - implement a specific ticket from `docs/tickets/`, run code review, and provide manual testing instructions
- `review-ticket` - review uncommitted changes, branch diffs, PR diffs, or ticket implementations for bugs and scope gaps
- `update-ticket` - change a ticket status, cascade dependency markers, refresh `docs/tickets/INDEX.md`, and commit the doc updates
- `commit-ticket` - create a single git commit from the intended repo changes
- `commit-push-pr` - create one commit, push the branch, and open a pull request
- `feature-catalog` - explore a codebase and produce a user-facing feature catalog

## Codex Install

Codex discovers repo-local skills from `.agents/skills/` when you launch Codex inside the repo or a child directory.

### Repo-local

If you want these skills available only inside this repository, nothing else is required. Launch Codex from this repo root or from a nested directory and Codex will scan `.agents/skills/`.

If you want to use this skill set from another repo without copying it, symlink the Codex tree into that repo:

```sh
mkdir -p /path/to/target-repo/.agents
ln -s /absolute/path/to/cktk/.agents/skills /path/to/target-repo/.agents/skills
```

### User-global

If you want these skills available across repos, install them under `$HOME/.agents/skills`:

```sh
mkdir -p "$HOME/.agents"
ln -s /absolute/path/to/cktk/.agents/skills "$HOME/.agents/skills"
```

If you already have other global Codex skills, symlink individual skill folders instead of replacing the whole directory.

### Install from GitHub in Codex Desktop

Codex can also install skills directly from this GitHub repo via `$skill-installer`.

After any installer-based install, restart Codex if the new skills do not appear immediately.

#### Install all skills

Use one installer request with all six skill paths:

```text
$skill-installer install from https://github.com/savourylie/cktk with these paths:
.agents/skills/commit-ticket
.agents/skills/commit-push-pr
.agents/skills/feature-catalog
.agents/skills/implement-ticket
.agents/skills/review-ticket
.agents/skills/update-ticket
```

#### Install an individual skill

Use the GitHub directory URL for the specific skill you want:

```text
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/commit-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/commit-push-pr
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/feature-catalog
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/implement-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/review-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/update-ticket
```

## Codex Usage

Prefer explicit skill invocation for deterministic behavior:

```text
$implement-ticket TICKET-003
$review-ticket
$review-ticket main
$review-ticket --pr 42
$update-ticket TICKET-003 done
$commit-ticket
$commit-push-pr
$feature-catalog
```

`review-ticket` and `feature-catalog` also include descriptions suitable for Codex's implicit skill matching. The write-heavy workflows remain explicit-only in their `agents/openai.yaml` policy.

## Claude Code Install

```text
/plugin marketplace add savourylie/cktk
/plugin install cktk@savourylie
```

## Claude Code Usage

```text
/implement-ticket 003              # Implement a specific ticket
/implement-ticket TICKET-003       # Also accepts full ticket ID

/review-ticket                     # Auto-detect: uncommitted or branch diff
/review-ticket main                # Compare HEAD against main
/review-ticket --pr 42             # Review a pull request
/review-ticket 42                  # Review against ticket #42

/update-ticket TICKET-003 done     # Mark a ticket as done
/update-ticket 5 in-progress       # Update ticket status

/commit-ticket                     # Commit current changes
/commit-push-pr                    # Commit, push, and open a PR

/feature-catalog                   # Generate feature catalog for current project
```

## Project Structure

These ticket-management skills expect a project to provide:

- `docs/PRD.md` - product requirements document
- `docs/DESIGN.md` - architecture and design document
- `docs/tickets/INDEX.md` - ticket index with status tracking
- `docs/tickets/TICKET-NNN.md` - individual ticket files

## Validation

Run the Codex-tree validation script after changing the skill layout:

```sh
./scripts/check-codex-skills.sh
```
