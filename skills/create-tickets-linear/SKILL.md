---
name: create-tickets-linear
description: "Create development issues in Linear from requirements, a feature catalog, or a conversation or saved plan. Use when the user wants work broken into Linear tickets or added to a Linear backlog, with acceptance criteria and dependency relations."
---

Turn the requested work into coherent, verifiable Linear issues. Linear owns the identifiers, workflow states, and dependency graph; do not generate a parallel `docs/tickets/` tracker or `INDEX.md`.

## Resolve the source and destination

Interpret the invocation arguments with the current conversation. Accept natural language and case-insensitive aliases, with or without a space after the colon. Respect quoted values containing spaces.

| Input | Meaning |
| --- | --- |
| `PRD: <input>` · `FEATURES: <input>` | Requirements or a feature catalog |
| `PLAN` · `PLAN: <path>` | The plan identified in this conversation, or a saved plan |
| `DESIGN:` · `UX:` · `MISC:` | Supplementary files, directories, or URLs; multiple inputs are allowed |
| `TEAM: <key/name/id>` | Destination Linear team |
| `PROJECT: <name/id/URL>` | Destination project, when the work belongs to one |

Prefer the source and destination the user has identified in this conversation. Complementary sources may be combined. For bare `PLAN`, use this session's plan and reread its saved file when the path is known; never choose the newest file from a global plans directory.

If a repository is available, follow applicable `CLAUDE.md` / `AGENTS.md` instructions. Locate the main repository root even when working in a worktree, and read `.ai/cktk/project.json` if present. Before using bindings, read the [project bindings contract](../init-project/references/project-schema.md). Use compatible validated bindings for unspecified destinations and authoritative requirements; honor binding versions and read-only restrictions. Do not modify the bindings or run setup automatically. If the contract is unavailable, skip binding-derived behavior rather than guessing its shape.

Missing bindings do not prevent planning. Use explicit inputs or live discovery; ask for a destination only when it is still unresolved or ambiguous. An explicit project does not inherit a team from an unrelated binding. Verify the project and its team membership through live Linear reads; projects can involve multiple teams, so resolve the issue's team as well. A team-only request can target that team's backlog without a project.

If requirements were not supplied, use the bound canonical source when available, then `docs/PRD.md`. Ask for missing requirements if none resolves. Read relevant source content with available document, URL, and image tools; start directory exploration from its index or design notes. Report access failures and continue only where missing content does not materially affect the issues.

Examples below show skill names and arguments; use the invoking agent's skill mechanism.

```text
create-tickets-linear PRD: docs/PRD.md TEAM: ENG PROJECT: "Account Platform"
create-tickets-linear FEATURES:docs/FEATURES.md
create-tickets-linear PLAN
create-tickets-linear append issues for account recovery to the bound Linear project
```

## Establish coverage and shape the work

Discover the authenticated Linear connector/MCP tools and inspect their current schemas. Use read capabilities to resolve teams, projects, workflow statuses, and existing issues; require issue-creation and relation capabilities before publishing a dependent batch. If a required capability or write access is unavailable, preserve the proposed issues as a draft and report the blocker. Do not invent tool names, fields, credentials, or an API/CLI workaround.

Search within the resolved team/project and follow pagination until relevant coverage is understood. Do not restrict duplicate checks to open issues; include completed and archived work where relevant. Read full bodies, relations, and implementation evidence for likely overlaps instead of loading every issue body.

Distinguish implemented work, ticketed-but-unfinished work, uncovered work, and canceled/superseded work. Ticket prose alone is not proof of delivery; a canceled issue is not completed work. Reuse existing coverage and dependencies, create only the gap, and clarify uncertainty that would otherwise cause duplicate or contradictory tickets. If everything is covered, report that without writes.

Give each new issue one coherent, reviewable outcome with concrete acceptance criteria and proportionate verification. Keep coupled implementation and tests together; split when outcomes, dependencies, or risks merit separate treatment. Do not impose file-count, workday, criterion-count, or ticket-count quotas. Preserve scope and agreed decisions; distinguish required constraints from suggested approaches.

Create a separate checkpoint only for additional integration verification, significant risk, or user acceptance. Use automated checks, manual checks, or both. Only work that actually needs that verification depends on it; no fixed cadence or final checkpoint is required.

## Prepare and publish

Read [references/issue-format.md](references/issue-format.md) for the issue body and native field mapping. Prepare titles, descriptions, destination, and real dependency edges before writing; check scope coverage and cycles, including relevant existing dependencies. Resolve material source or scope conflicts first.

A request to create Linear issues authorizes publishing that scope into the resolved destination. Briefly show the destination and proposed breakdown, then proceed without asking again when already authorized. A request to draft, plan, or review stops at the proposal. If creation or the destination still needs a decision, make the proposal concrete before asking.

- Preserve existing issues' descriptions, workflow states, assignments, and other fields. Do not treat a new PRD as permission to delete, cancel, recreate, or renumber a backlog. Project descriptions, Project Context documents, Notion, and repository code are outside this creation flow.
- Use Linear's assigned IDs and URLs. Temporary planning labels are only local handles, never invented `TEAM-NUMBER` identifiers.
- Let the team's configured creation state apply unless the request or project convention specifies another. Resolve any explicit state through the team's live workflow list and use its ID/type, not assumed names such as `pending` or `blocked`. Dependencies are native blocking relations; a blocked issue need not have a special status.
- Set assignee, priority, labels, cycle, milestone, or parent only when requested or established by project conventions, after resolving actual targets. Do not create teams, projects, labels, workflow states, or milestones merely to reproduce phase headings.
- Create prerequisites before dependents when possible. Record each confirmed issue's internal ID, identifier, and URL as it is returned. Set a dependent's native `blockedBy` relation to its prerequisites, including existing issues; if relations require a follow-up write, wait until both IDs exist. Read the tool's relation semantics and preserve unrelated relations.
- Re-fetch new issues to confirm destination, body, status, and dependencies. A parent/child relation or a prose link alone does not establish a blocking dependency. If a relation cannot be saved or verified, report it as incomplete rather than treating the batch as ready.

## Partial success and handoff

Treat each confirmed creation as durable. After a timeout or ambiguous write response, reconcile against live issues and the recorded receipts before issuing another create call. Never blindly recreate the batch. On permission failure or an outcome that cannot be reconciled, stop dependent writes, preserve successful issues, and report the exact unresolved units or relations; do not delete successes as rollback. Resume only the confirmed missing work.

Report created issue links, the resolved team/project, reused coverage, ready-to-start issues, checkpoint rationale when relevant, and material assumptions or verification gaps. Distinguish created, reused, not created, and relations still pending; a partially published batch is not complete. Do not claim creation in a draft-only run.
