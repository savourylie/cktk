---
name: create-tickets
description: "Turn requirements, a feature catalog, or a conversation or saved plan into development tickets under docs/tickets/, with dependencies and an INDEX.md tracker. Use for creating or extending a ticket backlog. Prefer explicit invocation with $create-tickets."
---

Create tickets with clear completion criteria and preserve the conventions that implementation and status-update skills consume. Let the work determine its decomposition.

## Understand the inputs and intended operation

Interpret the text after `$create-tickets` with the user's current request and conversation. Accept natural language and the familiar case-insensitive aliases:

- `PRD: <path>` for requirements and `FEATURES: <path>` for a feature catalog.
- `PLAN` for the plan identified in this conversation, or `PLAN: <path>` for a saved plan.
- `DESIGN:`, `UX:`, and `MISC:` for supplementary context; each accepts multiple files, directories, or URLs.

Both `KEY:value` and `KEY: value` are valid; preserve quoted paths with spaces. Combine complementary sources and clarify conflicts only when they materially change scope. For a conversation plan with a known saved path, read that file fresh. Do not guess a plan by searching a global plans directory for the latest file.

If the user has supplied no requirements through the request or conversation, look for the highest-numbered `docs/tickets/PRDv*.md`, then `docs/tickets/PRD.md`, then `docs/PRD.md`. Ask for the missing source if none resolves.

Source type does not determine whether this is a new project. Create a new tracker if there are no tickets; otherwise default to append unless the user requested replacement. Replacing a set requires authorization for the affected existing tickets. When that is missing, prepare the proposed replacement and identify the files affected before asking; preserve source documents and unrelated files. Honor an operation already chosen in the conversation without asking again.

```text
$create-tickets PRD: docs/PRD.md DESIGN: system-design/
$create-tickets FEATURES:docs/FEATURES.md
$create-tickets PLAN: "docs/plans/account recovery.md"
$create-tickets append tickets for the recovery flow from docs/PRD.md
```

## Establish scope and existing coverage

Follow applicable `AGENTS.md` instructions and relevant project documentation. Read the requested requirements; use the host's available document, browser, and image capabilities for supplementary sources. Start directory exploration from an index or design notes and inspect relevant visual evidence. Report the actual reason a source could not be read. Proceed with a disclosed gap only if it does not materially affect the ticket scope or acceptance.

For an existing backlog, begin with `docs/tickets/INDEX.md` and inspect related tickets and code. Expand as needed to resolve overlap and dependencies. Do not require a full reread of every ticket body. A missing index can be reconstructed from unambiguous ticket files; conflicting state needs clarification.

Keep these distinctions when deciding what to add:

- **Implemented:** use recorded completion and relevant code evidence where needed; ticket prose alone is not proof.
- **Ticketed but unfinished:** reuse that coverage and reference its ticket ID when it is a prerequisite.
- **Uncovered or partially covered:** create only the missing work.

If the requested work is fully covered, explain the coverage without creating redundant tickets.

## Choose ticket boundaries and verification

Aim for one coherent, reviewable outcome per ticket, verifiable after its prerequisites. Coupled implementation and tests may span several layers or files. Split when outcomes can ship independently or dependencies and risks merit separate handling. There is no required file count, workday size, criterion count, or number of tickets.

Keep the user's scope and agreed plan decisions. Bootstrap only missing foundations. Use phases or themes when useful, without imposing Foundation/Core/Polish. Describe observable acceptance and proportionate verification; distinguish required constraints from suggested implementation details so the implementing agent can adapt its approach.

Document reasonable assumptions; resolve missing decisions that would materially change scope, architecture, or acceptance before writing the affected tickets.

Use a separate checkpoint for an integration boundary, significant risk, or a user acceptance gate when individual ticket checks are insufficient. Explain the additional verification and its dependents. Only work that needs the gate should depend on it. Checkpoints can use automated checks, manual checks, or both; no fixed interval or final checkpoint is required. Existing gates remain intact during append.

## Produce compatible files

Read [references/TEMPLATE.md](references/TEMPLATE.md) and [references/INDEX.md](references/INDEX.md) for the shared ticket and tracker formats.

Write under `docs/tickets/`. New and authorized replacement sets start at `001` with three-digit padding. On append, scan numeric prefixes matching `^(\d+)-.+\.md$`; continue after the highest number with that filename's padding width. Preserve existing IDs, filenames, and references. Continue numbered checkpoints after the highest existing `Checkpoint N`, or start at 0; phase checkpoint labels use their phase numbers.

Append changes only new ticket files, new index rows or sections, summary counts, and the update date. Preserve existing tickets and index rows, statuses, notes, and commentary. Set each new ticket's initial status and completed-dependency markers according to the templates.

## Check the result

Validate source coverage and avoid duplicate work. Review new tickets for coherent scope, concrete acceptance, meaningful verification, and valid reference paths. Inspect IDs and dependency edges across the tracker for missing targets and cycles; load additional ticket detail only where needed. Confirm new statuses and dependency markers, index links, and accurate totals.

Correct newly created tickets and necessary index updates. Report unrelated old inconsistencies without rewriting them; resolve existing ambiguity first if it prevents valid numbering or dependencies.

Finish with the source and create/append/replace operation, new count and ID range, reasons for any checkpoints, skipped implemented or already-ticketed work, material assumptions or evidence gaps, a link to `INDEX.md`, and tickets ready to start. Explicitly report when no new tickets were needed.
