---
name: create-tickets-linear
description: "Turn requirements, a feature catalog, or a conversation or saved plan into Linear issues with acceptance criteria and native dependencies. Use for creating or extending a Linear backlog. Prefer explicit invocation with $create-tickets-linear."
---

Create a useful Linear backlog from the user's requested work. Keep Linear as the tracker: its assigned identifiers, workflow states, and relations replace local ticket numbering and `INDEX.md`.

## Inputs and target

Read the text following `$create-tickets-linear` in the context of the conversation. Support natural language and these case-insensitive aliases:

- `PRD:` or `FEATURES:` for requirements or a feature catalog.
- `PLAN` for the plan identified in this session, or `PLAN: <path>` for a saved plan.
- `DESIGN:`, `UX:`, and `MISC:` for multiple supplementary files, directories, or URLs.
- `TEAM:` for a Linear team key, name, or ID; `PROJECT:` for a project name, ID, or URL.

Accept both `KEY:value` and `KEY: value`, including quoted values with spaces. Use the user's stated sources and scope; combine complementary inputs. When a conversation plan has a known saved path, reread it. Never select a plan by searching a global plans directory for the latest file.

Follow applicable `AGENTS.md` and relevant project instructions. When a repository is present, find its main root even from a worktree. If `.ai/cktk/project.json` exists there, read the [project bindings contract](../init-project/references/project-schema.md) before consuming it. Compatible validated bindings can supply unspecified destinations and authoritative source locations. Respect their versions and read-only restrictions; do not rewrite configuration or invoke setup. If the contract cannot be read, skip binding behavior.

Explicit destinations take precedence over defaults. Verify the selected project and team through live Linear reads; do not combine an explicit project with an unrelated bound team. Resolve an issue team even for a project shared by multiple teams. A team-only request can create issues in that team's backlog without choosing a project. Without bindings, use explicit targets or live candidate discovery; clarify only a destination that remains ambiguous.

Source discovery uses the current request and conversation first, then bound canonical requirements when available, then `docs/PRD.md`. Ask for missing requirements if necessary. Read documents, URLs, and visual references with available tools, following relevant directory indexes. Explain source-access failures and their impact; proceed with a gap only where it does not materially affect the tickets.

```text
$create-tickets-linear PRD: docs/PRD.md TEAM: ENG PROJECT: "Account Platform"
$create-tickets-linear FEATURES:docs/FEATURES.md
$create-tickets-linear PLAN
$create-tickets-linear append recovery-flow issues to the bound Linear project
```

## Read existing work and plan the gap

Discover the actual authenticated Linear connector/MCP tools and read their schemas. Resolve destinations and workflow states with read tools. Confirm creation and relation capabilities before publishing dependent issues. Missing capabilities or refused writes leave a draft and a clear blocker; do not fabricate tool arguments or use ad hoc credential, API, or CLI fallbacks.

Use scoped issue listing and relevant searches, following pagination far enough to establish coverage. Include completed and archived issues where relevant, not just open work. Fetch full bodies and relations for likely matches, and inspect code when needed to distinguish intended behavior from implemented behavior.

Separate implemented, ticketed-but-unfinished, uncovered, and canceled/superseded work. Reuse existing issues for coverage and prerequisites. A description is not proof of implementation, and cancellation does not mean delivery. Create only missing outcomes; clarify overlaps that cannot be resolved. A fully covered request needs no new issues.

Choose coherent, independently verifiable outcomes after their prerequisites. Keep coupled implementation and tests together. Split for meaningful deliverables, dependencies, or risk, without quotas on files, workdays, criteria, or issue count. Preserve the user's scope and agreed decisions. Record assumptions and separate required constraints from optional implementation suggestions.

Add a checkpoint only when integration, risk, or user acceptance requires verification beyond individual issues. Its checks may be automated, manual, or both; only its actual dependents wait for it. There is no fixed checkpoint cadence or mandatory final gate.

## Create native Linear issues

Read [references/issue-format.md](references/issue-format.md). Prepare the titles, bodies, destination, and dependency graph; verify coverage, real prerequisites, and absence of cycles involving new or relevant existing issues. Resolve material conflicts before writing.

Show the destination and proposed breakdown briefly. When the user already requested creation in that scope, continue without another approval round. For a draft, planning, or review request, return the proposal without writes. If a destination or creation decision remains necessary, ask after preparing the reviewable proposal.

Preserve existing issue content, workflow state, ownership, and unrelated fields. Do not replace or cancel a backlog because a new source document was provided. Do not maintain a `docs/tickets/` mirror, change repository code, or update project descriptions, Project Context documents, or Notion as part of issue creation.

Use Linear-assigned internal IDs, identifiers, and URLs; temporary planning labels never become fabricated issue IDs. Default to the team's configured creation state unless the request or project convention specifies one. Resolve explicit statuses from the live team's workflow by ID/type. Do not invent `pending` or `blocked` states; blocking relations carry dependency information independently of status.

Apply assignees, priorities, labels, cycles, milestones, or parents only when requested or supported by project conventions, using resolved targets. Phase grouping does not authorize creating projects, teams, labels, milestones, or workflow states.

Create prerequisites before dependents where possible and capture every returned ID and URL. Use native `blockedBy` edges on dependents, including edges to existing prerequisites; where a follow-up relation write is needed, wait for both IDs. Inspect relation update semantics and preserve unrelated edges. Re-fetch created issues to check team/project, body, state, and blockers. Parent/child structure and prose links are not substitutes for blocking relations. Unverified or unsaved edges remain incomplete.

## Recover and report accurately

Keep successful creation receipts. If a create response times out or is ambiguous, reconcile live issues against those receipts and the proposed issue before retrying. Never rerun the entire batch blindly. If permission fails or an outcome cannot be reconciled, stop dependent writes and preserve successes; report missing issues and unresolved relations without rolling back by deletion. Resume only confirmed missing work.

Return links to created issues, destination, reused coverage, issues ready to start, and any checkpoint rationale, assumptions, or evidence gaps. Separate created, reused, not created, and relation-pending outcomes. A draft has created nothing, and a partially published batch must be reported as partial.
