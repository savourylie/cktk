---
name: create-tickets
description: "Generate dev tickets from requirements documents, extend an existing project with new features, or break a Plan Mode plan into tickets. Use when the user provides a PRD, product spec, or requirements doc and wants tickets created; provides a FEATURES catalog to add new features to an existing project; has just written or points at a Plan Mode plan and wants it broken into tickets; or asks to break down requirements or a plan into development work items. Prefer explicit invocation with $create-tickets."
---

**Argument:** `$ARGUMENTS`

Turn a PRD or FEATURES catalog (and optional design/UX/reference inputs) into well-ordered development tickets, or extend an existing ticket project with new features.

## Inputs

Arguments are key-value pairs separated by spaces:

- `PRD: <file_path>` — exactly one path to the product requirements document (auto-detected if omitted; mutually exclusive with `FEATURES:`)
- `FEATURES: <file_path>` — exactly one path to a feature catalog; appends new tickets to an existing project (mutually exclusive with `PRD:`)
- `PLAN` or `PLAN: <file_path>` — break a Plan Mode plan into tickets. Bare `PLAN` uses the plan from the current conversation; `PLAN: <path>` reads a saved plan file. Mutually exclusive with `PRD:`/`FEATURES:`
- `DESIGN: <input> [<input> …]` — one or more design inputs: file path, directory path, or URL
- `UX: <input> [<input> …]` — one or more UX specification inputs: file path, directory path, or URL
- `MISC: <input> [<input> …]` — one or more additional reference inputs: file path, directory path, or URL

## Phase 1: Gather Inputs

1. Parse `$ARGUMENTS`: tokenize on whitespace. Tokens exactly matching `PRD:`, `FEATURES:`, `DESIGN:`, `UX:`, `MISC:`, or `PLAN`/`PLAN:` (case-insensitive; colon optional only for `PLAN`) open a new section; all subsequent non-key tokens append to that section. `PRD:` and `FEATURES:` accept exactly one value each; if more than one of `PRD:`/`FEATURES:`/`PLAN` is passed, error and stop ("pass exactly one"). `PLAN` accepts zero or one value — bare `PLAN` means use the plan from the current conversation; one path reads that file; more than one is an error. `DESIGN:`, `UX:`, and `MISC:` accept one or more inputs. A key other than `PLAN` with no values is an error.

2. **Mode** (`PRD:`/`FEATURES:`/`PLAN` are mutually exclusive): if `PLAN` is present → PLAN mode; else if `FEATURES:` is present → FEATURES mode (append); else → PRD mode (greenfield).

3. **PLAN mode** — obtain the plan: `PLAN: <path>` reads that file (error and stop if missing); bare `PLAN` uses the implementation plan most recently produced in the current conversation (if it was saved to a `~/.claude/plans/*.md` path referenced this session, read that file fresh; if no plan is evident, ask the user to pass `PLAN: <path>` or create a plan first, and stop — do **not** scan `~/.claude/plans/`). Create `docs/tickets/` if absent; if `NNN-*.md` files already exist, handle like PRD mode: overwrite (restart at 001), append (continue from `max_num + 1` at the existing width), or abort.

4. **PRD mode** — if no `PRD:` given, auto-detect:
   a. Glob `docs/tickets/PRDv*.md` → highest version number
   b. Fall back to `docs/tickets/PRD.md`
   c. Fall back to `docs/PRD.md`
   d. Nothing found → error and stop

5. **PRD mode** — create `docs/tickets/` if it does not exist. If `NNN-*.md` ticket files already exist, ask: overwrite (restart at 001), append (continue from `max_num + 1`), or abort.

6. **FEATURES mode** — verify the `FEATURES:` file exists, `docs/tickets/` contains at least one `NNN-*.md` file, and `docs/tickets/INDEX.md` exists. Error and stop if any check fails. Detect numbering width and `max_num` from existing files; new tickets start at `max_num + 1` with the same zero-padding width.

7. Read all inputs plus `CLAUDE.md` at the project root if present. In FEATURES mode and PLAN+Append, also read every existing `docs/tickets/NNN-*.md` and `docs/tickets/INDEX.md`.

   **Input Types** — for each value in a DESIGN, UX, or MISC list:

   | Pattern | How to read |
   |---|---|
   | Starts with `http://` or `https://` | WebFetch. On 4xx or empty body: print "Claude Design share URLs are session-gated — export the handoff bundle to `./system-design/` and re-run, or pass a PDF or HTML export instead." and stop. |
   | Directory path | Enumerate children; read `.md`, `.txt`, `.html`, `.json`, `.css`, `.svg`, `.png/.jpg/.jpeg/.webp`. For a Claude Design handoff bundle: `*.md` first, then `*.html`, then `screenshots/` images, then `*.json`/`*.css`. Read images multimodally. Skip unknown binaries with a one-line note. |
   | `.md`, `.txt`, `.html`, `.json`, `.css`, `.svg` | Read as text. |
   | `.pdf` | Read; page through in 10-page chunks if >10 pages. |
   | `.pptx` | Delegate to `document-skills:pptx`; if unavailable, stop with "Re-export as PDF or HTML and re-run." |
   | `.png`, `.jpg`, `.jpeg`, `.webp` | Read multimodally. |
   | Non-existent file path | Error and stop. |

## Phase 2: Analyze & Plan

Read all inputs. Identify features, infrastructure concerns, design constraints, open questions (note as assumptions), and out-of-scope items.

Build a dependency graph:
1. What must exist first? (scaffolding, tokens, data models)
2. What depends on what?
3. What can be parallelized?

**PRD mode**: group into phases: Foundation → Core Features → Polish & QA.

**FEATURES mode**: build an inventory of what existing tickets already deliver. Walk the FEATURES catalog feature-by-feature: classify each as "already covered" (skip), "partially covered" (ticket only the gap), or "not covered" (new tickets). New tickets may depend on existing ones by their existing number.

**PLAN mode**: the plan is usually already decomposed (`## Approach`, `## Files`, `## Verification`, `## Out of scope`). Map its units of work into tickets rather than re-deriving from scratch; honor its out-of-scope list; base testing/checkpoint criteria on its verification section. Scale the ticket count and checkpoints to the plan's size (a small plan → a few tickets + at most one checkpoint; don't force Foundation/Core/Polish), and do not create a scaffolding ticket unless the plan bootstraps a brand-new project. In PLAN+Append, also apply the FEATURES-mode gap logic (skip already-built work; reference existing tickets by number).

Plan checkpoint placement (both modes):
- **Feature checkpoints** after each group of 2–5 tickets that deliver a testable outcome
- **Phase checkpoints** at the end of each phase (gate to next phase)
- **Final end-to-end checkpoint** as the very last ticket in PRD mode; continue the checkpoint sequence in FEATURES mode and PLAN+Append; in PLAN mode scale to the plan (a single end-to-end checkpoint for a small plan)
- Checkpoints are dependencies: subsequent tickets require the checkpoint

## Phase 3: Write Ticket Files

Read `./references/TEMPLATE.md` for the format.

Each ticket = one focused day of work. File naming: `NNN-kebab-case-title.md` in `docs/tickets/`. Use 3-digit padding in PRD+Overwrite and greenfield PLAN; preserve detected width in FEATURES mode, PRD+Append, and PLAN+Append. In PLAN mode there is no scaffolding first ticket unless the project is genuinely new.

Rules:
- Header: `# [TICKET-NNN] Title`
- Status: `pending` (deps met) or `blocked` (deps unmet)
- Dependencies: `- Requires: #NNN, #NNN` or `- Requires: None`
- Acceptance criteria: 2–3 minimum, specific and testable
- Design/Visual Reference: include for UI tickets, delete for non-UI
- Implementation Notes: key files, decisions, gotchas
- Testing: how to verify completion

### Checkpoint Tickets

Read `./references/TEMPLATE.md` — "Checkpoint Ticket Variant" section. For each checkpoint from Phase 2:

- Filename: `NNN-test-checkpoint-N-kebab.md` or `NNN-test-phaseN-checkpoint.md`
- Header: `# [TICKET-NNN] TEST: Checkpoint N — Title` or `# [TICKET-NNN] TEST: Phase N Checkpoint — Title`
- Description: what tests to run, that it's a gate, 2–3 paragraphs with context
- Acceptance criteria: pass/fail test cases, not code changes
- Implementation notes: "Manual test execution ticket — no code changes unless bugs found"
- Dependencies: last implementation ticket(s) in the group being tested
- Number checkpoints sequentially across the project (Checkpoint 0, 1, 2...)

## Phase 4: Write INDEX.md

Read `./references/INDEX.md` for the format.

**PRD or PLAN greenfield (or PRD+Overwrite)**: generate `docs/tickets/INDEX.md` from scratch with today's date, summary table (emoji status markers), phase tables (number, linked title, backtick-wrapped status, dependencies, notes), checkpoint rows in bold with `Gate: Phase N` in Notes, and a status key.

**FEATURES mode (or PRD+Append / PLAN+Append)**: do **not** overwrite `INDEX.md`. Merge new rows: preserve all existing rows/statuses; extend the last phase table or add a new `## Phase N — [theme]` section above the Status Key; recount the Summary; update the date (with an optional parenthetical like `(added TICKET-015 through TICKET-021)`).

## Phase 5: Self-Review

Review ALL tickets for:
1. Dependency ordering issues (circular, missing, or non-existent deps)
2. Missing acceptance criteria (<2 or vague)
3. Scope creep (>3 files or >5 criteria → split)
4. Gaps (PRD/FEATURES entries with no ticket, missing infrastructure)
5. Checkpoint coverage (every phase has one, final ticket is a checkpoint in PRD mode, gate deps correct, criteria are pass/fail)
6. Consistency (template format, status correctness, INDEX accuracy, checkpoint rows bold with `Gate:` notes)
7. **Append-mode checks** (FEATURES mode, PRD+Append, and PLAN+Append): new tickets continue from `max_num + 1` with the detected width; no existing files modified; INDEX merged not rewritten; no duplicate coverage.
8. **PLAN-mode coverage** (PLAN mode): every actionable item in the plan's Approach/Files is ticketed; nothing the plan put out of scope was ticketed; no scaffolding ticket for an existing project.

Fix any problems found. Update both ticket files and INDEX.md.

## Phase 6: Summary

Report: mode (PRD greenfield, FEATURES append, or PLAN — for PLAN, note whether the plan came from this conversation or a file path), ticket count (implementation + checkpoint), phase grouping with checkpoint gates, assumptions made, path to INDEX.md. In FEATURES mode, list which FEATURES catalog entries were skipped (already covered by existing tickets). Suggest `$implement-ticket 001` for greenfield or `$implement-ticket <first new number>` for append.
