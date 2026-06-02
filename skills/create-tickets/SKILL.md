---
name: create-tickets
description: "Generate dev tickets from requirements documents, append new tickets to an existing project from a features catalog, or break down a Plan Mode plan into tickets. MUST invoke when a user provides a PRD, product spec, or requirements doc and wants tickets created; provides a FEATURES.md / feature catalog and wants to add new features to an existing ticket set; has just written or points at a Plan Mode plan and wants it broken into tickets; asks to break down, split, or decompose requirements or a plan into dev work items; or references docs/tickets/ for review, audit, reordering, or fixes. Three modes: PRD (greenfield), FEATURES (append from a catalog), and PLAN (from a Plan Mode plan). Triggers on: /create-tickets, create tickets, break down into tasks, ticket this out, dev tickets from PRD, break down a plan into tickets, ticket out the plan, turn the plan into tickets, plan mode to tickets, add features to project, ticket new features, extend ticket tracker, review tickets in docs/tickets/"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

Turn a PRD (and optional design/UX/reference documents) into a set of well-ordered, independently-completable development tickets, or extend an existing ticket set with new features from a FEATURES.md catalog.

## Inputs

Arguments are key-value pairs separated by spaces. Keys are case-insensitive.

| Argument | Required | Description |
| --- | --- | --- |
| `PRD: <file_path>` | PRD mode only (or auto-detected) | Exactly one path to the product requirements document |
| `FEATURES: <file_path>` | FEATURES mode only | Exactly one path to a feature catalog; adds new features to an existing project |
| `PLAN` or `PLAN: <file_path>` | PLAN mode only | Bare `PLAN` uses the plan from the current conversation (just produced in Plan Mode); `PLAN: <path>` reads a saved plan file (e.g. one under `~/.claude/plans/`) |
| `DESIGN: <input> [<input> …]` | No | One or more design inputs — file path, directory path, or URL (see Input Types in Phase 1) |
| `UX: <input> [<input> …]` | No | One or more UX inputs — file path, directory path, or URL (see Input Types in Phase 1) |
| `MISC: <input> [<input> …]` | No | One or more reference inputs — file path, directory path, or URL (see Input Types in Phase 1) |

### Modes

This skill has three modes, chosen by which of `PRD:`, `FEATURES:`, or `PLAN` is passed:

- **PRD mode (greenfield)** — the default. Generates a full ticket set from scratch. Used when starting a new project or when a new PRD supersedes the ticket tracker.
- **FEATURES mode (append)** — for adding new features to a project that already has tickets in `docs/tickets/`. Automatically appends without prompting; continues the existing ticket numbering pattern; reads existing tickets to avoid re-ticketing capabilities that are already built; merges new rows into the existing `INDEX.md` rather than overwriting it.
- **PLAN mode** — breaks a Plan Mode plan (the implementation plan just produced in this conversation, or a saved plan file) into tickets. The ticket structure *adapts to the plan's size* — a small focused plan yields a few tickets, a large plan is grouped into phases — and no project-scaffolding ticket is created when the project already exists. Existing tickets are handled like PRD mode (prompts overwrite/append/abort).

`PRD:`, `FEATURES:`, and `PLAN` are mutually exclusive — pass at most one. If more than one is given, the skill reports the conflict and stops. `DESIGN:`, `UX:`, and `MISC:` are accepted in any mode as supplementary context and each accept one or more space-separated inputs.

**Examples:**
```
/create-tickets PRD: docs/PRD.md DESIGN: docs/DESIGN.md
/create-tickets PRD: docs/PRD.md UX: docs/UX_DESIGN.md docs/WIREFRAMES.md MISC: docs/API.md docs/MIGRATION.md
/create-tickets PRD: docs/PRD.md DESIGN: https://api.anthropic.com/v1/design/h/abc123
/create-tickets PRD: docs/PRD.md DESIGN: system-design/ docs/legacy-spec.pdf
/create-tickets
/create-tickets FEATURES: docs/FEATURES.md
/create-tickets FEATURES: docs/FEATURES.md DESIGN: docs/DESIGN.md docs/ARCHITECTURE.md
/create-tickets PLAN
/create-tickets PLAN: ~/.claude/plans/022-agile-candy.md
/create-tickets PLAN DESIGN: docs/DESIGN.md
```

## Phase 1: Gather Inputs

1. Parse `$ARGUMENTS` by splitting on whitespace and walking tokens left-to-right. A token that is exactly `PRD:`, `FEATURES:`, `DESIGN:`, `UX:`, `MISC:`, or `PLAN`/`PLAN:` (case-insensitive, colon optional only for `PLAN`, nothing else) opens a new section; every subsequent token that does not match a key is appended to that section's input list. If a token appears before any key, error and stop. `PRD:` and `FEATURES:` accept exactly one file path each — error if more are provided. `PLAN` is special: it accepts **zero or one** value — bare `PLAN` (no following path) means "use the plan from the current conversation," and a single path reads that plan file; more than one path is an error. `DESIGN:`, `UX:`, and `MISC:` accept one or more inputs (file paths, directory paths, or URLs — see Input Types in step 7). A key other than `PLAN` with no following inputs is an error.

2. **Mode detection** — `PRD:`, `FEATURES:`, and `PLAN` are mutually exclusive:
   - If more than one of `PRD:`, `FEATURES:`, or `PLAN` is present, report the conflict ("PRD mode is for greenfield, FEATURES mode appends from a catalog, PLAN mode breaks down a Plan Mode plan — pass exactly one") and **stop**.
   - If `PLAN` is present → **PLAN mode** (see step 3 for sourcing).
   - Else if `FEATURES:` is present → **FEATURES mode**.
   - Otherwise → **PRD mode**.

3. **PLAN mode** — plan sourcing and existing-ticket handling:
   a. Obtain the plan:
      - If `PLAN: <path>` was given, read that file. If it does not exist, report the error and **stop**.
      - If bare `PLAN` was given (no path), use the implementation plan most recently produced in the **current conversation** (typically via Plan Mode). If that plan was written to a `~/.claude/plans/*.md` file whose path appears in this session, read that file fresh — it is more complete than a possibly-summarized transcript. If no plan is evident in the conversation, tell the user to pass `PLAN: <path>` or create a plan first, and **stop**. Do **not** scan `~/.claude/plans/` for a "latest" plan — that directory is global across projects and its filenames are opaque.
   b. Create `docs/tickets/` if it does not exist.
   c. If any `NNN-*.md` ticket files already exist in `docs/tickets/`, handle them exactly like PRD mode (step 4c): ask whether to **Overwrite** (restart at 001, 3-digit padding), **Append** (keep existing; run the numbering-pattern detection in step 6; new tickets start at `max_num + 1` with the existing width), or **Abort**.

4. **PRD mode** — PRD discovery and existing-ticket handling:
   a. If no `PRD:` argument is provided:
      - Glob `docs/tickets/PRDv*.md` — if matches exist, pick the one with the highest version number.
      - If no versioned PRD, check for `docs/tickets/PRD.md`.
      - If nothing in `docs/tickets/`, fall back to `docs/PRD.md`.
      - If still nothing found, tell the user no PRD was found and **stop**.
   b. Create `docs/tickets/` if it does not exist.
   c. If any `NNN-*.md` ticket files already exist in `docs/tickets/`, warn the user and ask whether to:
      - **Overwrite** — delete existing tickets and start fresh. Numbering restarts at 001 with 3-digit padding.
      - **Append** — keep existing tickets. Run the numbering-pattern detection in step 6 below; new tickets start at `max_num + 1` with the existing zero-padding width.
      - **Abort** — stop without changes.

5. **FEATURES mode** — verify the existing project:
   a. Confirm the `FEATURES:` file path exists. If not, report the error and **stop**.
   b. Confirm `docs/tickets/` exists and contains at least one `NNN-*.md` ticket file. If not, report: "FEATURES mode requires an existing project with tickets in `docs/tickets/`. For a new project, use PRD mode instead." and **stop**.
   c. Confirm `docs/tickets/INDEX.md` exists — it carries the phase groupings needed for merging. If missing, report the error and **stop**.
   d. Run the numbering-pattern detection in step 6.

6. **Numbering-pattern detection** (runs in FEATURES mode always, and in PRD+Append and PLAN+Append):
   - Glob `docs/tickets/*.md` and filter to names matching `^(\d+)-.+\.md$`.
   - Let `max_num` be the largest captured integer, and `width` be the digit-length of that file's numeric prefix (e.g., `042-foo.md` → width 3; `0042-foo.md` → width 4). Preserving width matters when a project chose a non-default padding — sibling skills glob by zero-padded prefix, so mixing widths would break them.
   - New tickets begin at `max_num + 1`, zero-padded to `width` digits.
   - For checkpoint numbering, grep `docs/tickets/*.md` and `docs/tickets/INDEX.md` for `Checkpoint N` and `TEST: Checkpoint N`. The next checkpoint number is `max_found + 1` (or `0` if none found).

7. Read all inputs:
   - **PRD mode**: the PRD (required); all DESIGN, UX, and MISC inputs (one or more each, if provided); `CLAUDE.md` at the project root (if it exists) — for tech stack constraints, coding standards, and architectural decisions that affect how tickets are scoped.
   - **FEATURES mode**: the FEATURES file (required); every existing `docs/tickets/NNN-*.md` file (required — needed to detect which features are already built); `docs/tickets/INDEX.md` (required); all DESIGN, UX, and MISC inputs (one or more each, if provided); `CLAUDE.md` at the project root (if it exists).
   - **PLAN mode**: the plan (required — from the conversation or the `PLAN:` file); all DESIGN, UX, and MISC inputs (if provided); `CLAUDE.md` at the project root (if it exists). In PLAN+Append, also read every existing `docs/tickets/NNN-*.md` file and `docs/tickets/INDEX.md` — needed to continue numbering and avoid re-ticketing work that is already built.

   **Input Types** — for each value in a DESIGN, UX, or MISC list, determine how to read it:

   | Pattern | How to read |
   |---|---|
   | Starts with `http://` or `https://` | Use WebFetch. If the response is a 4xx error or empty body, print: "Claude Design share URLs are session-gated — export the handoff bundle to `./system-design/` and re-run, or pass a PDF or HTML export instead." and **stop**. |
   | Path resolves to a directory | Enumerate immediate children. Read every `.md`, `.txt`, `.html`, `.json`, `.css`, `.svg`, `.png`, `.jpg`, `.jpeg`, `.webp` file. For a Claude Design handoff bundle, prioritize: `design-notes.md` and top-level `*.md` first (intent), then `*.html` (layout and inline tokens), then images in `screenshots/` and top-level images (visual truth), then `*.json`/`*.css`. Read image files multimodally. Skip unknown binaries (e.g., `.zip`, `.mov`) with a one-line note. |
   | File ending in `.md`, `.txt`, `.html`, `.json`, `.css`, `.svg` | Read as text with the Read tool. |
   | File ending in `.pdf` | Read with the Read tool. If the file exceeds 10 pages, page through it (`pages: "1-10"`, `"11-20"`, …) until all pages are covered. |
   | File ending in `.pptx` | Delegate to the `document-skills:pptx` skill to extract slide content and notes. If that skill is unavailable, stop with: "PPTX extraction requires document-skills:pptx — re-export as PDF or HTML and re-run." |
   | File ending in `.png`, `.jpg`, `.jpeg`, `.webp` | Read multimodally as an image with the Read tool. |

8. If any specified file path (non-URL, non-directory) does not exist, report the error and **stop**.

## Phase 2: Analyze & Plan

Read all input files carefully before writing anything. In **PRD mode**, build a full plan from scratch. In **FEATURES mode**, first build a mental model of what already exists, then plan only the gap — see the FEATURES-mode additions at the end of this phase. In **PLAN mode**, the plan is your primary input and is usually already partly decomposed — see the PLAN-mode notes at the end of this phase.

As you read, identify:

- **Features** — every distinct user-facing capability described in the PRD
- **Infrastructure concerns** — tech stack setup, storage, API integrations, build tooling
- **Design constraints** — component patterns, tokens, typography, color systems, animations (from DESIGN and UX docs)
- **Open questions** — anything the PRD flags as TBD or "open question" — note these as assumptions in relevant tickets rather than blocking on them
- **Out of scope** — explicitly listed out-of-scope items. Do not create tickets for these.

Build a dependency graph before writing any tickets:

1. **What must exist first?** Project scaffolding, design tokens, core data models, base components.
2. **What depends on what?** A chat UI needs the base layout. Audio input needs the chat interface. Export needs session storage.
3. **What can be parallelized?** Independent features that share no dependencies can be worked on in any order once their shared foundation is done.

Group the work into phases:
- **Phase 1 — Foundation**: Project setup, design tokens, core infrastructure
- **Phase 2 — Core Features**: The main capabilities described in the PRD
- **Phase 3 — Polish & QA**: Integration, edge cases, final QA pass

Use more phases if the project warrants it (e.g., Phase 2a and 2b if core features have a natural split). The phases are for human readability in the INDEX — they don't affect the dependency numbers.

Plan checkpoint placement — test gate tickets that verify work before proceeding:

1. **Feature checkpoints** — after each group of 2–5 implementation tickets that together deliver a testable outcome, plan a checkpoint ticket. The checkpoint tests that specific feature in isolation.
2. **Phase checkpoints** — at the end of each phase, plan a checkpoint that verifies the integration of everything built in that phase. This gates entry to the next phase. If a phase already ends with a feature checkpoint that covers the full phase, it can double as the phase checkpoint.
3. **Final checkpoint** — the very last ticket is always an end-to-end checkpoint that tests the complete system.

Checkpoint tickets are dependencies: the next group of implementation tickets should list the preceding checkpoint in their `Requires:` line. This enforces the gate.

### FEATURES-mode additions

Before writing new tickets in FEATURES mode:

1. **Build the existing-work inventory** — from the existing ticket files you read in Phase 1, extract a short list: each ticket's title plus a one-line summary of what it delivered (from its Description + Acceptance Criteria). Also note the existing phase groupings from `INDEX.md`. This is your map of what's already built.

2. **Identify gaps** — walk the FEATURES.md catalog feature by feature. For each feature, classify:
   - **Already covered** — an existing ticket (or group of tickets) clearly delivered this. Skip it and note it for the Phase 6 summary.
   - **Partially covered** — some part exists but the feature as described in FEATURES.md has unbuilt sub-capabilities. Plan tickets only for the unbuilt parts.
   - **Not covered** — no existing ticket addresses this. Plan new tickets.

3. **Dependencies on existing tickets** — new tickets may legitimately depend on existing done, in-progress, or even pending tickets. Reference them by their existing number (e.g., `Requires: #014`). Ticket numbers stay stable across modes.

4. **Phase placement** — decide whether new tickets extend the last existing phase or form a new one:
   - If the new features thematically fit the most recent phase (e.g., both are "Polish & QA" items), extend that phase.
   - If they represent a distinct new theme or a significant chunk of work, add `Phase N+1 — [theme]`.
   - Err toward a new phase when in doubt — it keeps phase tables readable.

5. **Checkpoint planning** — same rules as PRD mode, continuing the checkpoint sequence from `next_checkpoint` detected in Phase 1. Do not add a new project-wide "final end-to-end" checkpoint if one already exists; add a feature or phase checkpoint for the new batch instead.

### PLAN-mode additions

A Plan Mode plan is implementation-focused and usually already decomposed — it commonly has sections like `## Context`, `## Approach`, `## Files` / `## Critical files`, `## Verification`, and `## Out of scope`. Work *with* that structure rather than re-deriving everything:

1. **Map the plan's units of work into tickets.** The plan's `## Approach` steps and per-file changes (`## Files`) are natural ticket boundaries — each coherent change becomes one ticket, still respecting the "1–3 files, one outcome" rule (split a step that is too big; combine trivially-related steps that are each too small).
2. **Honor scope boundaries.** Do not create tickets for anything the plan lists as out of scope. Carry the plan's stated assumptions and risks into the relevant tickets' Implementation Notes.
3. **Base testing on the plan's verification.** Use the plan's `## Verification` section as the source for ticket Testing sections and checkpoint acceptance criteria.
4. **Scale structure to the plan's size.** A small, focused plan should yield a handful of tickets and at most one end-to-end checkpoint — do **not** force the Foundation/Core/Polish phase structure onto it. A large, multi-part plan may still warrant phase grouping and phase/final checkpoints as in PRD mode. Let the plan's own shape decide.
5. **No scaffolding for existing projects.** A plan almost always targets an existing codebase. Do not emit a project-scaffolding first ticket unless the plan itself is to bootstrap a brand-new project (no existing tickets and an empty or near-empty repo).
6. **PLAN+Append.** If the plan is appended to a project that already has tickets, also apply the FEATURES-mode gap logic above: read existing tickets, skip work that is already built or ticketed, and reference existing tickets by number in `Requires:`.

## Phase 3: Write Ticket Files

Read this skill's `references/TEMPLATE.md` for the ticket format.

Each ticket should represent one focused session of work — roughly what a developer could complete in a day:

- **1–3 files changed** per ticket, with one clear outcome
- **Independently testable** — every ticket has a concrete "done" state you can verify
- **No bundling of unrelated concerns** — if a ticket touches both the data layer and a UI component that aren't tightly coupled, split them
- **Err on the side of smaller** — two small tickets are better than one overloaded ticket
- **First ticket** — in PRD mode, the first ticket is always project scaffolding (repo init, dependency installation, design token setup, base layout). In FEATURES mode, the first new ticket is simply the next-numbered ticket — there is no scaffolding ticket, since the project already exists. In PLAN mode, do **not** create a scaffolding ticket either, unless the plan is genuinely greenfield (bootstrapping a new project); otherwise the first ticket is just the first unit of work from the plan.
- **Last ticket** — in PRD mode, the last ticket is always the final end-to-end checkpoint (see checkpoint rules below). In FEATURES mode, the last new ticket is typically a feature or phase checkpoint for the newly-added batch; do not create a redundant project-wide end-to-end checkpoint if the existing set already has one. In PLAN mode, end with a checkpoint scaled to the plan (a single end-to-end checkpoint for a small plan; phase + final checkpoints for a large one); omit a checkpoint only when the plan is trivial.

Save each ticket to `docs/tickets/` with the filename pattern `NNN-kebab-case-title.md` (e.g., `001-project-setup.md`, `002-design-tokens.md`). Use 3-digit padding by default (greenfield PRD mode, PRD+Overwrite, and greenfield PLAN mode). In FEATURES mode, PRD+Append, and PLAN+Append, use the `width` detected in Phase 1 and start from `max_num + 1` — do not renumber or rewrite any existing ticket files.

Rules for each ticket:

- **Header**: Use `# [TICKET-NNN] Title` format.
- **Status**: Set to `pending` if all dependencies are met (or it has none). Set to `blocked` if it depends on unfinished tickets.
- **Dependencies**: Use `- Requires: #NNN, #NNN` format. If none, write `- Requires: None`.
- **Acceptance Criteria**: Write specific, testable statements. Not "it works" but "the chat input accepts text and sends it on Enter, displaying the message in the conversation view." Minimum 2–3 criteria per ticket.
- **Design Reference**: For UI tickets, reference specific sections from the design document (e.g., "§ Typography > Scale", "§ Components > Buttons"). Delete this section entirely for non-UI tickets.
- **Visual Reference**: For frontend tickets, describe what the user should see when the ticket is complete — specific enough that someone could visually verify it. Delete this section entirely for non-UI tickets.
- **Implementation Notes**: Key files to create/modify, architectural decisions, gotchas. Reference CLAUDE.md conventions here if applicable.
- **Testing**: How to verify the ticket is complete — commands to run, URLs to visit, expected behavior.

### Checkpoint Tickets

For each checkpoint position identified in Phase 2, write a checkpoint ticket. Read this skill's `references/TEMPLATE.md` — "Checkpoint Ticket Variant" section for the format.

- **Filename**: `NNN-test-checkpoint-N-kebab-description.md` (feature checkpoints) or `NNN-test-phaseN-checkpoint.md` (phase checkpoints)
- **Header**: `# [TICKET-NNN] TEST: Checkpoint N — What's Being Tested` or `# [TICKET-NNN] TEST: Phase N Checkpoint — Phase Summary`
- **Description**: State what tests to execute, that this is a gate, and what must pass before proceeding. Include 2–3 paragraphs: context on what was just built, what this checkpoint verifies, and what is gated by it.
- **Acceptance Criteria**: Specific pass/fail test cases — not code changes. Each criterion is a concrete verification step.
- **Implementation Notes**: Begin with "This is a manual test execution ticket — no code changes unless bugs are found during testing." Then list common failure modes, test commands, and environment notes.
- **Dependencies**: The last implementation ticket(s) in the group being tested.

Number checkpoints sequentially across the entire project (Checkpoint 0, Checkpoint 1, ...) — do not restart numbering per phase. The final ticket is always the last checkpoint. In FEATURES mode and PLAN+Append, continue the checkpoint sequence from the `next_checkpoint` detected in Phase 1.

## Phase 4: Write INDEX.md

Read this skill's `references/INDEX.md` for the index format.

### PRD or PLAN greenfield (or PRD+Overwrite)

Generate `docs/tickets/INDEX.md` from scratch containing:

1. **Last updated date** — today's date
2. **Summary table** — counts of tickets by status, using emoji markers (✅ Done, 🔧 In Progress, 📋 Pending, 🚫 Blocked, ⏸️ Deferred)
3. **Phase tables** — one table per phase, each ticket showing: number, linked title (relative path), status (backtick-wrapped), dependencies, notes
4. **Checkpoint rows** — format checkpoint ticket links in bold: `[**TEST: Checkpoint N — Title**](./NNN-test-...)`. In the Notes column, write `Gate: Phase N` or `Gate: Final`
5. **Status key** — definition of each status value

All tickets start as either `pending` (no dependencies or all dependencies met) or `blocked` (has unmet dependencies). The summary counts should reflect the initial state.

### FEATURES mode (or PRD+Append / PLAN+Append)

Do **not** overwrite `INDEX.md`. Merge new rows into the existing file:

1. **Preserve everything existing** — all existing phase tables, rows, statuses, and notes stay untouched. Only add new rows and/or new phase sections for the newly-created tickets.
2. **Extend the last phase** — if the new tickets thematically fit the most recent phase, append their rows at the bottom of that phase's table. Checkpoint rows are bold with `Gate: Phase N` in Notes.
3. **Or add a new phase section** — insert a new `## Phase N — [theme]` heading and table below the last existing phase, above the Status Key.
4. **Update the Summary table** — recount all rows across all phase tables (existing + new) and rewrite the counts. Existing statuses are not changed by this run.
5. **Update the "Last updated" date** to today. Optionally include a short context note in parentheses (e.g., `(added TICKET-015 through TICKET-021)`) matching the style of previous updates.
6. **Do not touch** the Status Key or any structural commentary.

## Phase 5: Self-Review

This phase is mandatory. After writing all tickets, review every ticket in `docs/tickets/` for:

1. **Dependency ordering issues**
   - Can ticket N actually be started given its listed dependencies?
   - Are there circular dependencies?
   - Does any ticket depend on a ticket that doesn't exist?

2. **Missing acceptance criteria**
   - Every ticket needs at least 2–3 specific, testable criteria.
   - Criteria must be concrete (not "works correctly" or "is properly styled").

3. **Scope creep**
   - Does any ticket touch more than 3 files?
   - Does any ticket have more than 5 acceptance criteria?
   - If so, consider splitting it into smaller tickets.

4. **Gaps**
   - Is there a feature in the PRD that no ticket covers?
   - Is there infrastructure assumed but never set up?

5. **Checkpoint coverage**
   - Does every phase have at least one checkpoint?
   - Is the final ticket a checkpoint (not an implementation ticket)?
   - Do implementation tickets after a checkpoint list that checkpoint in their dependencies?
   - Are checkpoint acceptance criteria testable pass/fail statements (not code changes)?

6. **Consistency**
   - Do all tickets follow the template format?
   - Are status values correct given dependencies?
   - Does INDEX.md accurately reflect all ticket files?
   - Are checkpoint rows bold in INDEX.md with `Gate:` notes?

7. **Append-mode checks** (applies to FEATURES mode, PRD+Append, and PLAN+Append; skip in greenfield / PRD+Overwrite)
   - **Numbering**: the lowest new ticket number equals `max_num + 1` from Phase 1, and all new tickets share the same zero-padding width as existing ones.
   - **Existing files untouched**: no existing ticket file was renumbered, renamed, or modified.
   - **INDEX merged, not rewritten**: all existing rows and statuses are intact; only new rows or new phase sections were added.
   - **Dependencies**: new-ticket `Requires:` lines correctly reference existing ticket numbers where dependencies are real.
   - **No duplicate work** (FEATURES mode and PLAN+Append): for each new ticket, confirm no existing ticket already delivers the same capability. If overlap is found, either narrow the new ticket's scope or delete it.

8. **PLAN-mode coverage** (applies to PLAN mode; skip otherwise)
   - Every actionable item in the plan's Approach / Files is covered by at least one ticket.
   - Nothing the plan listed as out of scope was ticketed.
   - No project-scaffolding ticket was created for an existing project.

Fix any problems you find. Update both the ticket files and INDEX.md if changes are made.

## Phase 6: Summary

Tell the user:
- Which mode ran (PRD greenfield, PRD append, FEATURES append, or PLAN) — and for PLAN, whether the plan came from this conversation or a file path
- How many tickets were created in this run (implementation + checkpoint); in FEATURES mode, PRD+Append, and PLAN+Append, state the new number range (e.g., "added TICKET-015 through TICKET-021")
- How they're grouped by phase, including where checkpoints gate progress
- In FEATURES mode: which FEATURES.md entries were skipped because existing tickets already cover them
- Any assumptions made due to open questions in the source document
- The path to `docs/tickets/INDEX.md` as the project tracker
- Suggest next steps: `/implement-ticket 001` for greenfield, or `/implement-ticket <first new number>` to start the new batch
