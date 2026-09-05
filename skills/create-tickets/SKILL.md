---
name: create-tickets
description: "Create or append development tickets in docs/tickets/ from requirements, a feature catalog, or a conversation or saved plan, with dependencies and an INDEX.md tracker. Use when the user wants requirements or a plan turned into tickets."
---

Turn the requested work into coherent, verifiable tickets that fit the project and its existing backlog. Adapt the breakdown to the work; preserve the ticket conventions used by downstream skills.

## Resolve the request

Read the invocation arguments together with the current conversation. Natural-language requests and these existing aliases are supported; keys are case-insensitive, and both `PRD:path` and `PRD: path` work. Respect quoted paths containing spaces.

| Input | Meaning |
| --- | --- |
| `PRD: <path>` | Requirements document |
| `FEATURES: <path>` | Feature catalog; normally append when a tracker already exists |
| `PLAN` or `PLAN: <path>` | The plan identified in this conversation, or a saved plan |
| `DESIGN:`, `UX:`, `MISC:` | Supplementary files, directories, or URLs; each can contain multiple inputs |

Use the user's stated source and scope. Complementary sources can be combined; clarify conflicting requirements when they materially change the work. Bare `PLAN` uses the plan from this session. If its saved path is known, read that file fresh. Never select a plan by scanning a global plans directory for the newest file.

When neither the request nor conversation supplies requirements, discover the PRD in this order: the highest-numbered `docs/tickets/PRDv*.md`, `docs/tickets/PRD.md`, then `docs/PRD.md`. If no source can be resolved, ask for the missing requirements.

Choose the operation independently of the source type:

- **Create** when there are no existing tickets.
- **Append** when extending a backlog; this is the default when tickets already exist and replacement was not requested.
- **Replace** only when the user has authorized replacing the existing ticket set. If authorization is missing, prepare the proposed replacement and identify the files affected before asking. Preserve source documents and unrelated files.

Existing authorization carries forward; do not repeat an overwrite/append/abort prompt after the user has already chosen.

Examples below show skill names and arguments; use the invoking agent's skill mechanism.

```text
create-tickets PRD: docs/PRD.md DESIGN: system-design/
create-tickets FEATURES:docs/FEATURES.md
create-tickets PLAN: "docs/plans/account recovery.md"
create-tickets append tickets for the recovery flow from docs/PRD.md
```

## Gather enough context

Read the source requirements and applicable project instructions, including applicable `AGENTS.md` / `CLAUDE.md`. For directories, begin with the index or design notes and follow relevant references. Use the available tools for documents, URLs, and images; inspect visual evidence when it affects scope or acceptance. Report actual access or extraction failures. Continue with disclosed limitations only when missing material does not materially affect the tickets.

For existing projects, read `docs/tickets/INDEX.md` first, then relevant tickets and code. Expand the search when coverage or dependencies remain unclear; there is no requirement to read every old ticket body. If the index is missing, reconstruct it from ticket files when their state is unambiguous; otherwise clarify the conflicting state.

Distinguish work that is already implemented, work that is ticketed but unfinished, and work with no coverage. A description or acceptance checklist specifies intended behavior; it does not prove delivery. Use recorded status and relevant implementation evidence when needed. Reuse unfinished tickets as coverage or dependencies, and create tickets only for the remaining gap. If everything is covered, report that without adding tickets.

## Shape the work

- Give each ticket one coherent, independently verifiable outcome once its prerequisites are met. Keep coupled API, UI, and test changes together when they deliver that outcome. Split where deliverables, dependencies, or risks can usefully be handled separately; do not impose file-count, workday, or acceptance-criterion quotas.
- Preserve the requested scope, agreed decisions, and useful structure of an existing plan. Add scaffolding only when the project actually needs it. Group into themes or phases only when that helps the reader.
- Acceptance criteria describe observable completion. Testing explains how to verify it with appropriate automated checks, manual checks, or both.
- Separate required constraints from suggested implementation approaches. Include useful evidence, conventions, and risks without prescribing speculative file-by-file steps.
- Record reasonable assumptions. Clarify unresolved choices that would materially change the scope, architecture, or acceptance criteria before writing the affected tickets.

A separate checkpoint is useful for cross-feature integration, significant risk, or an explicit user acceptance gate. Create one only when it adds verification beyond the individual tickets. State what it verifies and what work depends on it; only that work requires the checkpoint. Neither a fixed cadence nor a final checkpoint is required. Preserve existing gates during append.

## Write the tickets and tracker

Read [references/TEMPLATE.md](references/TEMPLATE.md) for ticket fields and checkpoint variants, and [references/INDEX.md](references/INDEX.md) for the tracker layout. Keep these formats compatible with implementation and status-update skills.

Write tickets under `docs/tickets/`. For a new or authorized replacement set, start at `001` with three-digit padding. For append, find the largest numeric filename prefix matching `^(\d+)-.+\.md$`, start at that value plus one, and preserve its padding width. Keep existing IDs, filenames, and dependency references stable. New numbered checkpoints continue after the highest existing `Checkpoint N` (start at 0 if none); phase checkpoint labels follow their phase numbers.

In append, leave existing ticket files and existing index rows, statuses, notes, and commentary untouched. Add new rows or sections and refresh summary counts and the date. Set new-ticket status from actual dependencies, including the completed-dependency markers defined in the templates.

## Verify and hand off

Review the new tickets for scope coverage, duplicate work, coherent outcomes, testable acceptance criteria, and real reference paths. Check IDs and dependency edges across the tracker for missing targets or cycles, reading only the additional ticket detail needed. Verify new statuses and dependency markers, index links, and summary counts.

Fix problems in this run's new tickets and necessary index updates. Report unrelated existing inconsistencies without silently repairing old tickets. If an existing ambiguity prevents valid IDs or dependencies, resolve it before writing affected output.

Report the source and operation, ticket count and new number range, any checkpoint rationale, skipped work (implemented versus already ticketed), material assumptions or missing evidence, and the index path. Identify tickets ready to start; when no new work is needed, say so.
