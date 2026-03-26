# dev-skills

Software development workflow skills for [Claude Code](https://claude.ai/claude-code).

## Skills

### `/implement-ticket`
Implements tickets from a project's ticket tracker (`docs/tickets/`), one by one. Reads the PRD and design doc, picks the next pending ticket, implements it, runs code review, commits, updates ticket status, and loops until all tickets are done.

### `/review-ticket`
Reviews code changes for bugs using a structured priority system (P0-P3). Supports uncommitted changes, branch diffs, PR diffs, and ticket-based review. Applies strict bug detection criteria to minimize false positives.

### `/update-ticket`
Updates a ticket's status, cascades dependency changes to dependent tickets, refreshes `INDEX.md` counts and dependency graph, and commits.

### `/commit-ticket`
Creates a git commit from the current staged and unstaged changes.

### `/commit-push-pr`
Commits changes, pushes the branch, and opens a pull request in one step.

### `/feature-catalog`
Generates a structured catalog of user-facing features from a codebase. Explores routes, components, API endpoints, and configuration to discover what end users can do, then produces a categorized Markdown document.

## Install

```
/plugin marketplace add savourylie/dev-skills
/plugin install dev-skills@savourylie
```

## Usage

```
/implement-ticket                  # Implement all pending tickets
/implement-ticket TICKET-003       # Implement a specific ticket

/review-ticket                # Auto-detect: uncommitted or branch diff
/review-ticket main           # Compare HEAD against main
/review-ticket --pr 42        # Review a pull request
/review-ticket 42             # Review against ticket #42

/update-ticket TICKET-003 done     # Mark a ticket as done
/update-ticket 5 in-progress       # Update ticket status

/commit-ticket                     # Commit current changes
/commit-push-pr                    # Commit, push, and open a PR

/feature-catalog                   # Generate feature catalog for current project
```

## Project Structure

These skills expect your project to have:
- `docs/PRD.md` — Product requirements document
- `docs/DESIGN.md` — Architecture and design document
- `docs/tickets/INDEX.md` — Ticket index with status tracking
- `docs/tickets/TICKET-NNN.md` — Individual ticket files
