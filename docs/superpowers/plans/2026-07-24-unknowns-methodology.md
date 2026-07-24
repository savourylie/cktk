# Finding-Your-Unknowns Methodology Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Weave the four-unknowns methodology (blind spot pass, references, durable as-built notes) into the existing cktk lifecycle skills and add a new `quiz-ticket` / `quiz-ticket-linear` skill pair for post-implementation understanding checks and explainers.

**Architecture:** All changes are to Markdown skill documents and one bash validation script. Every touched skill exists in two authored dialects — `skills/<name>/SKILL.md` (Claude, canonical) and `.agents/skills/<name>/SKILL.md` (Codex, condensed/host-neutral) — plus a symlink in `.agent/skills/<name>` (Antigravity). New skills additionally need `.agents/skills/<name>/agents/openai.yaml`. Registration surfaces are `catalog.json`, `.claude-plugin/plugin.json` (keywords), and `README.md`.

**Tech Stack:** Markdown skill files, YAML frontmatter, bash (`scripts/check-codex-skills.sh` with embedded Ruby YAML validation), git.

**Spec:** `docs/superpowers/specs/2026-07-24-unknowns-methodology-design.md`

## Global Constraints

- **Test cycle adaptation:** these are prose/config files, not code, so the per-task cycle is: edit → targeted `grep` verification with expected output → `./scripts/check-codex-skills.sh` (must print `Validated N skill(s) across Claude, Codex, and Antigravity.`) → commit. N = 28 for Tasks 1–5, 29 after Task 6, 30 after Tasks 7–8.
- **Behavioral divergence to respect:** Claude `implement-ticket` never commits and never updates ticket status; Codex `implement-ticket` commits (Phase 6) and updates status itself (Phase 7). Claude `implement-ticket-linear` summarizes in Phase 8; Codex `implement-ticket-linear` summarizes in Phase 7. Edits must land in the phase that exists in each dialect.
- **Shared section-name literals** (exact spelling, used across tasks): `### Blind spots`, `## References`, `## As-Built Notes`.
- **Four-unknowns labels** (exact): Known knowns, Known unknowns, Unknown knowns, Unknown unknowns.
- **Interactive-skill contract** (enforced by `scripts/check-codex-skills.sh` for clarify twins today, extended to quiz twins in Task 8): Claude frontmatter has `user-invocable: true`, `disable-model-invocation: true`, and a non-empty `argument-hint`; Codex frontmatter has ONLY `name` and `description` keys; both SKILL.md dialects contain the literals `Portable interaction`, `Never assume an option limit`, and `AGENTS.md`, and never contain `AskUserQuestion`; `agents/openai.yaml` has `interface.display_name`, `interface.short_description` (25–64 chars), `interface.default_prompt` mentioning `$<skill-name>`, and `policy.allow_implicit_invocation: false`.
- All `description` frontmatter values ≤ 1024 characters.
- Antigravity symlinks must be exactly `../../skills/<name>` (relative), created from inside `.agent/skills/`.
- Commit messages: conventional commits, ending with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Do not touch: `update-ticket`, `update-ticket-linear`, `commit-ticket`, `commit-push-pr`, worktree skills, handoff skills, design/UX/image skills, `AGENTS.md`.

---

### Task 1: Blind spot pass in `clarify-ticket` (both trees)

**Files:**
- Modify: `skills/clarify-ticket/SKILL.md`
- Modify: `.agents/skills/clarify-ticket/SKILL.md`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the `### Blind spots` briefing bucket and the two calibration questions ("What's obvious to you about this ticket that isn't written down?", "How familiar are you with this area of the code?") — Task 2 mirrors them for Linear; Task 8's validation contract assumes the buckets exist.

- [ ] **Step 1: Add four-unknowns framing and the Blind spots bucket to the Claude dialect**

In `skills/clarify-ticket/SKILL.md`, find the Phase 4 intro:

```markdown
## Phase 4: Codebase-Grounded Analysis

Explore with read-only tools and safe read-only shell commands. Ground every claim in evidence actually found. Produce four buckets plus a verdict.
```

Replace with:

```markdown
## Phase 4: Codebase-Grounded Analysis

Explore with read-only tools and safe read-only shell commands. Ground every claim in evidence actually found. Produce five buckets plus a verdict.

Frame the analysis with the four types of unknowns:

- **Known knowns** — what the ticket states; verify these against the code.
- **Known unknowns** — gaps the ticket admits; turn each into an open question.
- **Unknown knowns** — details obvious to the user but unwritten; elicit these in the guided discussion.
- **Unknown unknowns** — factors nobody has considered; hunt these in the Blind spots bucket.
```

- [ ] **Step 2: Insert the Blind spots analysis bucket (Claude dialect)**

In the same file, the `### Risks` bucket ends with this bullet list item:

```markdown
- Feasibility of each acceptance criterion
```

Insert immediately after it (before `### Dependencies`):

```markdown
### Blind spots

Deliberately hunt what the ticket does not mention. Check each category against the actual code; report a finding with `path:line` evidence or move on:

- Adjacent code paths that call, render, or depend on the areas this ticket changes
- Error and edge paths the ticket ignores (failures, empty states, concurrency, permissions)
- Data-shape changes with migration, backfill, or rollback implications
- Implicit conventions the ticket silently assumes (project guidance or dominant code patterns)
- Test surface: existing tests that will break, or coverage the ticket does not request

If no category produces a finding, record "No blind spots found" — never silently omit the bucket.
```

- [ ] **Step 3: Add Blind spots to the briefing template (Claude dialect)**

In the Phase 5 briefing template, find:

```markdown
### Risks (code-grounded)
- [high] ... — evidence: `src/...:NN`

### Dependencies
```

Replace with:

```markdown
### Risks (code-grounded)
- [high] ... — evidence: `src/...:NN`

### Blind spots
- <category>: ... — evidence: `src/...:NN` (or "No blind spots found")

### Dependencies
```

- [ ] **Step 4: Add the calibration questions to Phase 6 (Claude dialect)**

Find:

```markdown
## Phase 6: Guided Discussion

Walk substantive open items one topic at a time using the portable interaction rules. Batch trivial confirmations. Record each outcome as:
```

Replace with:

```markdown
## Phase 6: Guided Discussion

Open with two calibration questions, asked one at a time before the open items:

1. **Unknown knowns** — "What's obvious to you about this ticket that isn't written down?" Fold answers into resolved details, risks, or blind spots.
2. **Experience calibration** — "How familiar are you with this area of the code?" Scale later explanations to the answer: more background when familiarity is low, terser confirmation when high.

Then walk substantive open items one topic at a time using the portable interaction rules. Batch trivial confirmations. Record each outcome as:
```

And in the same phase, replace the line:

```markdown
If there are no open items, skip directly to the summary.
```

with:

```markdown
If there are no open items beyond the two calibration questions, proceed directly to the summary after asking them.
```

- [ ] **Step 5: Mirror in the Codex dialect**

In `.agents/skills/clarify-ticket/SKILL.md`, find the Phase 4 intro:

```markdown
## Phase 4: Analyze

Use read-only exploration and safe read-only shell commands. Produce:
```

Replace with:

```markdown
## Phase 4: Analyze

Frame the analysis with the four types of unknowns: known knowns (verify against code), known unknowns (turn into open questions), unknown knowns (elicit in discussion), unknown unknowns (hunt as blind spots).

Use read-only exploration and safe read-only shell commands. Produce:
```

Then find the Risks bucket bullet:

```markdown
- **Risks** — likely files/modules, divergent patterns, missing prerequisites, migrations/compatibility, blast radius, and AC feasibility. Tag severity and cite `path:line`.
```

Insert immediately after it:

```markdown
- **Blind spots** — what the ticket does not mention: adjacent callers/dependents, ignored error and edge paths, migration/backfill/rollback implications, implicit conventions from project guidance or dominant patterns, and test surface. Cite `path:line`, or record "No blind spots found".
```

Then in Phase 5, find:

```markdown
Present a `Clarification Briefing — TICKET-NNN` with readiness, code context, the four analysis buckets, severity, and evidence. Then walk substantive open items one at a time using portable interaction; batch trivial confirmations.
```

Replace with:

```markdown
Present a `Clarification Briefing — TICKET-NNN` with readiness, code context, the five analysis buckets, severity, and evidence. Open the discussion with two calibration questions, one at a time: what is obvious to the user but not written down (unknown knowns), and how familiar they are with this area of the code (scale explanation depth to the answer). Then walk substantive open items one at a time using portable interaction; batch trivial confirmations.
```

- [ ] **Step 6: Verify**

Run:

```bash
grep -c "Blind spots" skills/clarify-ticket/SKILL.md .agents/skills/clarify-ticket/SKILL.md
```

Expected: `skills/clarify-ticket/SKILL.md:` ≥ 3 and `.agents/skills/clarify-ticket/SKILL.md:` ≥ 2.

```bash
grep -c "Unknown knowns" skills/clarify-ticket/SKILL.md
```

Expected: ≥ 2 (framing bullet + Phase 6 question label).

```bash
./scripts/check-codex-skills.sh
```

Expected: `Validated 28 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 7: Commit**

```bash
git add skills/clarify-ticket/SKILL.md .agents/skills/clarify-ticket/SKILL.md
git commit -m "feat(clarify-ticket): add blind spot pass and calibration questions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Blind spot pass in `clarify-ticket-linear` (both trees)

**Files:**
- Modify: `skills/clarify-ticket-linear/SKILL.md`
- Modify: `.agents/skills/clarify-ticket-linear/SKILL.md`

**Interfaces:**
- Consumes: the same `### Blind spots` bucket name and calibration-question wording pattern established in Task 1.
- Produces: the Linear-mode blind spot rules (code mode vs text-only mode) that Task 8's validation leaves untouched (existing `text-only` literal checks must keep passing).

- [ ] **Step 1: Add framing and the Blind spots bucket (Claude dialect)**

In `skills/clarify-ticket-linear/SKILL.md`, find:

```markdown
## Phase 5: Analyze Details and Risks

Use read-only tools and safe read-only shell commands. Produce four buckets plus a verdict.
```

Replace with:

```markdown
## Phase 5: Analyze Details and Risks

Use read-only tools and safe read-only shell commands. Produce five buckets plus a verdict.

Frame the analysis with the four types of unknowns:

- **Known knowns** — what the issue states; verify these against the code when available.
- **Known unknowns** — gaps the issue admits; turn each into an open question.
- **Unknown knowns** — details obvious to the user but unwritten; elicit these in the guided discussion.
- **Unknown unknowns** — factors nobody has considered; hunt these in the Blind spots bucket.
```

- [ ] **Step 2: Insert the Blind spots bucket with the mode split (Claude dialect)**

The `### Risks` bucket in this file ends with:

```markdown
- In text-only mode, make no codebase claims. Cite precise sources such as `issue description`, `Acceptance Criterion 2`, `comment by <name/date>`, or `blocked-by relation <ID>`.
```

Insert immediately after it (before `### Dependencies`):

```markdown
### Blind spots

Deliberately hunt what the issue does not mention.

- In code mode, check each category against the actual code and cite `path:line`: adjacent code paths that depend on the areas this issue changes, ignored error and edge paths, data-shape changes with migration/backfill/rollback implications, implicit conventions from project guidance or dominant patterns, and test surface.
- In text-only mode, make no codebase claims. Limit blind spots to gaps in the issue text itself — unspecified error handling, missing rollout or migration mention, undefined edge cases — citing Linear sources such as `issue description` or `Acceptance Criterion 2`.

If no category produces a finding, record "No blind spots found" — never silently omit the bucket.
```

- [ ] **Step 3: Add Blind spots to the briefing template (Claude dialect)**

In the Phase 6 briefing template, find:

```markdown
### Risks
- [high] ... — evidence: `<path:line | Linear source>`

### Dependencies
```

Replace with:

```markdown
### Risks
- [high] ... — evidence: `<path:line | Linear source>`

### Blind spots
- <category>: ... — evidence: `<path:line | Linear source>` (or "No blind spots found")

### Dependencies
```

- [ ] **Step 4: Add the calibration questions to Phase 7 (Claude dialect)**

Find:

```markdown
## Phase 7: Guided Discussion

Walk substantive open items one topic at a time using the portable interaction rules. Batch trivial confirmations. Record each outcome as:
```

Replace with:

```markdown
## Phase 7: Guided Discussion

Open with two calibration questions, asked one at a time before the open items:

1. **Unknown knowns** — "What's obvious to you about this issue that isn't written down?" Fold answers into resolved details, risks, or blind spots.
2. **Experience calibration** — "How familiar are you with the code or systems this issue touches?" Scale later explanations to the answer: more background when familiarity is low, terser confirmation when high.

Then walk substantive open items one topic at a time using the portable interaction rules. Batch trivial confirmations. Record each outcome as:
```

And replace:

```markdown
If there are no open items, skip directly to the summary.
```

with:

```markdown
If there are no open items beyond the two calibration questions, proceed directly to the summary after asking them.
```

- [ ] **Step 5: Mirror in the Codex dialect**

In `.agents/skills/clarify-ticket-linear/SKILL.md`:

1. Find the Phase 5 intro:

```markdown
## Phase 5: Analyze

Use read-only tools and safe read-only shell commands. Produce:
```

Replace with:

```markdown
## Phase 5: Analyze

Frame the analysis with the four types of unknowns: known knowns (verify against code when available), known unknowns (turn into open questions), unknown knowns (elicit in discussion), unknown unknowns (hunt as blind spots).

Use read-only tools and safe read-only shell commands. Produce:
```

2. In the same phase's bucket list, the **Risks** bullet ends with the sub-bullet:

```markdown
  - Text-only: no code claims; cite `issue description`, a numbered criterion, a dated/attributed comment, or a relation id.
```

Insert immediately after it (before the **Dependencies** bullet):

```markdown
- **Blind spots** — what the issue does not mention. Code mode: adjacent callers/dependents, ignored error and edge paths, migration/backfill/rollback implications, implicit conventions, and test surface, cited as `path:line`. Text-only mode: gaps in the issue text only (unspecified error handling, missing rollout/migration mention, undefined edge cases), citing Linear sources. Record "No blind spots found" when nothing surfaces.
```

3. In `## Phase 6: Briefing and Discussion`, find:

```markdown
Present a `Clarification Briefing — <ISSUE-ID>` with readiness, analysis mode, four analysis buckets, severity, and source-specific evidence. Then walk substantive open items one at a time using portable interaction; batch trivial confirmations. Record outcomes as **resolved here** or **still open**. Skip discussion if nothing is open.
```

Replace with:

```markdown
Present a `Clarification Briefing — <ISSUE-ID>` with readiness, analysis mode, five analysis buckets, severity, and source-specific evidence. Open the discussion with two calibration questions, one at a time: what is obvious to the user but not written down (unknown knowns), and how familiar they are with the code or systems this issue touches (scale explanation depth to the answer). Then walk substantive open items one at a time using portable interaction; batch trivial confirmations. Record outcomes as **resolved here** or **still open**. Skip the open-item walk if nothing is open beyond the calibration questions.
```

- [ ] **Step 6: Verify**

```bash
grep -c "Blind spots" skills/clarify-ticket-linear/SKILL.md .agents/skills/clarify-ticket-linear/SKILL.md
```

Expected: Claude ≥ 3, Codex ≥ 2.

```bash
grep -c "text-only" skills/clarify-ticket-linear/SKILL.md
```

Expected: at least the pre-edit count (the existing validation literal `ANALYSIS_MODE=text-only` and `text-only` checks must keep passing).

```bash
./scripts/check-codex-skills.sh
```

Expected: `Validated 28 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 7: Commit**

```bash
git add skills/clarify-ticket-linear/SKILL.md .agents/skills/clarify-ticket-linear/SKILL.md
git commit -m "feat(clarify-ticket-linear): add blind spot pass and calibration questions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `## References` section in the ticket template (`create-tickets`, both trees)

**Files:**
- Modify: `skills/create-tickets/references/TEMPLATE.md` (single source — the Codex tree's `references/` is a symlink to this directory; do NOT create a second copy)
- Modify: `skills/create-tickets/SKILL.md`
- Modify: `.agents/skills/create-tickets/SKILL.md`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the optional `## References` ticket section. Tickets carrying it are read (not written) by `implement-ticket` and `quiz-ticket` naturally, since both read the whole ticket file.

- [ ] **Step 1: Add the section to TEMPLATE.md**

In `skills/create-tickets/references/TEMPLATE.md`, find the end of the `## Visual Reference` block:

```markdown
Example: "The landing page hero section is visible at `/`. Left side shows the heading in Outfit 800 with a yellow circle behind it. Right side shows a placeholder image with blob clip-path. A dot-grid pattern fills the background. The primary CTA button uses the Candy Button style and responds to hover/active with shadow shifts."

## Implementation Notes
```

Replace with:

```markdown
Example: "The landing page hero section is visible at `/`. Left side shows the heading in Outfit 800 with a yellow circle behind it. Right side shows a placeholder image with blob clip-path. A dot-grid pattern fills the background. The primary CTA button uses the Candy Button style and responds to hover/active with shadow shifts."

## References
> Existing code or documents to imitate, each with a note on what to take from it. Delete this section when the project has no relevant exemplar.

- `src/components/SettingsModal.tsx` — focus trap and escape handling to reuse for the new modal
- `docs/DESIGN.md` § Forms — validation error copy pattern

## Implementation Notes
```

- [ ] **Step 2: Add the population rule to the Claude dialect**

In `skills/create-tickets/SKILL.md` Phase 3, find the rules-list bullet:

```markdown
- **Visual Reference**: For frontend tickets, describe what the user should see when the ticket is complete — specific enough that someone could visually verify it. Delete this section entirely for non-UI tickets.
```

Insert immediately after it:

```markdown
- **References**: Pointers to existing code or documents to imitate, each with a note on what to take from it. Populate in FEATURES and PLAN modes (the existing codebase offers exemplars) and whenever provided design/UX/reference documents contain a relevant pattern; verify every referenced path exists before writing it. Delete this section entirely when there is no relevant exemplar.
```

- [ ] **Step 3: Add the self-review check to the Claude dialect**

In the same file, Phase 5 item 6 currently reads:

```markdown
6. **Consistency**
   - Do all tickets follow the template format?
   - Are status values correct given dependencies?
   - Does INDEX.md accurately reflect all ticket files?
   - Are checkpoint rows bold in INDEX.md with `Gate:` notes?
```

Replace with:

```markdown
6. **Consistency**
   - Do all tickets follow the template format?
   - Are status values correct given dependencies?
   - Does INDEX.md accurately reflect all ticket files?
   - Are checkpoint rows bold in INDEX.md with `Gate:` notes?
   - Does every path listed in a `## References` section exist in the repo (verify with a glob or file read)?
```

- [ ] **Step 4: Mirror in the Codex dialect**

In `.agents/skills/create-tickets/SKILL.md` Phase 3, find:

```markdown
- Design/Visual Reference: include for UI tickets, delete for non-UI
```

Insert immediately after it:

```markdown
- References: existing code or documents to imitate, each with a note on what to take from it; populate in FEATURES/PLAN modes and from provided design/UX inputs; verify paths exist; delete when there is no exemplar
```

Then in Phase 5, find:

```markdown
6. Consistency (template format, status correctness, INDEX accuracy, checkpoint rows bold with `Gate:` notes)
```

Replace with:

```markdown
6. Consistency (template format, status correctness, INDEX accuracy, checkpoint rows bold with `Gate:` notes, every `## References` path exists in the repo)
```

- [ ] **Step 5: Verify**

```bash
grep -c "## References" skills/create-tickets/references/TEMPLATE.md
grep -c "References" skills/create-tickets/SKILL.md .agents/skills/create-tickets/SKILL.md
readlink .agents/skills/create-tickets/references
./scripts/check-codex-skills.sh
```

Expected: TEMPLATE count = 1; both SKILL.md counts ≥ 2; `readlink` prints a relative symlink target (confirming single-source template); script prints `Validated 28 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 6: Commit**

```bash
git add skills/create-tickets/references/TEMPLATE.md skills/create-tickets/SKILL.md .agents/skills/create-tickets/SKILL.md
git commit -m "feat(create-tickets): add References exemplar section to ticket template

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Durable As-Built Notes in `implement-ticket` + `review-ticket` awareness (both trees)

**Files:**
- Modify: `skills/implement-ticket/SKILL.md`
- Modify: `.agents/skills/implement-ticket/SKILL.md`
- Modify: `skills/review-ticket/SKILL.md`
- Modify: `.agents/skills/review-ticket/SKILL.md`
- Modify: `README.md` (one line — the `implement-ticket` entry)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the exact `## As-Built Notes` ticket-file section format below. Task 6's `quiz-ticket` reads this section by this exact name; Task 8's validation requires the literal `As-Built Notes` in quiz-ticket. The canonical section format is:

```markdown
## As-Built Notes
> Appended by implement-ticket on YYYY-MM-DD.

### Deviations from spec
- <what differs from the ticket/design source and why> (or "None")

### Key decisions
- <decision made during implementation and its rationale>

### Follow-ups / tech debt
- <deferred item or concern> (or "None")
```

- [ ] **Step 1: Restructure Phase 6 in the Claude dialect**

In `skills/implement-ticket/SKILL.md`, find:

```markdown
## Phase 6: Summary and Manual Testing

Present the following to the user:

### Implementation Summary
```

Replace with:

````markdown
## Phase 6: As-Built Notes, Summary, and Manual Testing

### As-Built Notes (write to the ticket file)

Before presenting the summary, append an `## As-Built Notes` section to `$WORK_DIR/docs/tickets/NNN-<slug>.md`. If the section already exists from a previous session, add a new dated entry beneath the existing content instead of duplicating the heading:

```markdown
## As-Built Notes
> Appended by implement-ticket on YYYY-MM-DD.

### Deviations from spec
- <what differs from the ticket/design source and why> (or "None")

### Key decisions
- <decision made during implementation and its rationale>

### Follow-ups / tech debt
- <deferred item or concern> (or "None")
```

This is the only ticket-file edit this skill makes — never change `## Status`, acceptance-criteria checkboxes, or `INDEX.md`. Leave the edit uncommitted alongside the code changes so it lands in the same commit the user makes later. In worktree mode the append happens in the worktree's copy of `docs/tickets/` and merges back via `/merge-worktree`.

Present the following to the user:

### Implementation Summary
````

- [ ] **Step 2: Point the summary at the recorded notes (Claude dialect)**

In the same file, the Implementation Summary list currently contains:

```markdown
3. Note any deviations from the ticket spec or design source, and why.
```

Replace with:

```markdown
3. Summarize the deviations recorded in `## As-Built Notes` (or state there were none).
```

- [ ] **Step 3: Reconcile the no-edit rule at the end of the file (Claude dialect)**

Find the closing paragraph:

```markdown
**Do NOT commit changes, update ticket status, or invoke the `/update-ticket`, `/commit-ticket`, or `/commit-push-pr` skills.** The user will handle those steps separately. (In worktree mode the natural next step after manual testing is `/merge-worktree NNN <base>`.)
```

Replace with:

```markdown
**Do NOT commit changes, update ticket status, or invoke the `/update-ticket`, `/commit-ticket`, or `/commit-push-pr` skills.** The user will handle those steps separately. Appending `## As-Built Notes` to the ticket file (Phase 6) is the one intended ticket-file edit; status and checkboxes stay untouched. (In worktree mode the natural next step after manual testing is `/merge-worktree NNN <base>`.)
```

- [ ] **Step 4: Add the append step to the Codex dialect's commit phase**

The Codex dialect commits and updates status itself, so the notes must land before staging. In `.agents/skills/implement-ticket/SKILL.md`, find:

```markdown
## Phase 6: Commit

1. Stage the files for the ticket (in `$WORK_DIR`, on the ticket branch when in worktree mode).
```

Replace with:

```markdown
## Phase 6: Commit

1. Append an `## As-Built Notes` section to `$WORK_DIR/docs/tickets/NNN-*.md` before staging — a dated entry with deviations from spec and why, key decisions, and follow-ups/tech debt (write "None" where a bucket is empty; if the section already exists, add a new dated entry beneath it). Do not change `## Status` or acceptance checkboxes here — Phase 7 owns those.
2. Stage the files for the ticket, including the ticket file with its As-Built Notes (in `$WORK_DIR`, on the ticket branch when in worktree mode).
```

Then renumber the remaining Phase 6 steps: the commit-message step (currently `2.`) becomes `3.`, and the no-unrelated-changes step (currently `3.`) becomes `4.`.

- [ ] **Step 5: Teach `review-ticket` to respect documented deviations (Claude dialect)**

In `skills/review-ticket/SKILL.md`, find Gather Context step 5:

```markdown
5. **Ticket mode only:** Read the matched ticket file from `docs/tickets/`. Use its requirements, acceptance criteria, and description as additional review context. Evaluate whether the uncommitted changes correctly and completely implement what the ticket specifies.
```

Replace with:

```markdown
5. **Ticket mode only:** Read the matched ticket file from `docs/tickets/`. Use its requirements, acceptance criteria, and description as additional review context. Evaluate whether the uncommitted changes correctly and completely implement what the ticket specifies. If the ticket contains an `## As-Built Notes` section, treat deviations documented there as intentional, agreed context — not scope drift — but still flag any documented deviation that contradicts an acceptance criterion.
```

- [ ] **Step 6: Same rule in the Codex dialect of `review-ticket`**

In `.agents/skills/review-ticket/SKILL.md`, find Gather Context item 6:

```markdown
6. In ticket mode, read the matched ticket file and use it as extra review context.
```

Replace with:

```markdown
6. In ticket mode, read the matched ticket file and use it as extra review context. Treat deviations documented in its `## As-Built Notes` section as intentional context, not scope drift, unless they contradict an acceptance criterion.
```

- [ ] **Step 7: Update the README entry for implement-ticket**

In `README.md`, find:

```markdown
- `implement-ticket` — implement a specific ticket from `docs/tickets/`, run code review, and provide manual testing instructions (the `docs/tickets/` twin of `implement-ticket-linear`)
```

Replace with:

```markdown
- `implement-ticket` — implement a specific ticket from `docs/tickets/`, run code review, append as-built notes (deviations, decisions, follow-ups) to the ticket file, and provide manual testing instructions (the `docs/tickets/` twin of `implement-ticket-linear`)
```

- [ ] **Step 8: Verify**

```bash
grep -c "As-Built Notes" skills/implement-ticket/SKILL.md .agents/skills/implement-ticket/SKILL.md skills/review-ticket/SKILL.md .agents/skills/review-ticket/SKILL.md
grep -c "as-built notes" README.md
./scripts/check-codex-skills.sh
```

Expected: first grep prints counts ≥ 3, ≥ 2, = 1, = 1; second grep prints 1 (the README entry uses lowercase). Script prints `Validated 28 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 9: Commit**

```bash
git add skills/implement-ticket/SKILL.md .agents/skills/implement-ticket/SKILL.md skills/review-ticket/SKILL.md .agents/skills/review-ticket/SKILL.md README.md
git commit -m "feat(implement-ticket): persist as-built notes into the ticket file

review-ticket now treats documented deviations as intentional context.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Opt-in Linear as-built comment in `implement-ticket-linear` (both trees + README)

**Files:**
- Modify: `skills/implement-ticket-linear/SKILL.md`
- Modify: `.agents/skills/implement-ticket-linear/SKILL.md`
- Modify: `README.md` (the `implement-ticket-linear` entry)

**Interfaces:**
- Consumes: the as-built content buckets from Task 4 (deviations / key decisions / follow-ups), reused as the comment body.
- Produces: the opt-in comment mechanism ("Post this as-built summary as a comment on `<issue_id>`? (y/N)", default no). Task 7's `quiz-ticket-linear` reads such comments when present.

- [ ] **Step 1: Carve out the single permitted write in Prerequisites (Claude dialect)**

In `skills/implement-ticket-linear/SKILL.md`, find:

```markdown
3. Prefer Linear MCP tools that **read** a single issue (get / list / search by identifier). **Do not** call update, create, delete, comment, or assign tools — this skill is read-only against Linear.
```

Replace with:

```markdown
3. Prefer Linear MCP tools that **read** a single issue (get / list / search by identifier). **Do not** call update, create, delete, or assign tools. The **only** permitted write is the single opt-in as-built comment in Phase 8, posted only after the user explicitly confirms.
```

- [ ] **Step 2: Adjust the summary reminder and add the opt-in comment block (Claude dialect)**

In Phase 8's Implementation Summary list, find:

```markdown
5. Reminder that **Linear was not updated** (status still whatever it was) and **nothing was committed**
```

Replace with:

```markdown
5. Reminder that **Linear status was not changed** and **nothing was committed** (the only possible Linear write is the opt-in as-built comment below)
```

Then find the heading that follows the Implementation Summary list:

```markdown
### Worktree Note (only when `use_worktree` was true)
```

Insert immediately before it:

```markdown
### As-Built Comment (opt-in Linear write)

After presenting the summary, ask exactly once, as its own question: "Post this as-built summary as a comment on <issue_id>? (y/N)". Default is no.

- Only an explicit yes posts the comment; any other answer (no, silence, ambiguity) skips it without re-asking.
- On yes, post one comment via the Linear MCP comment-creation tool containing: deviations from the issue spec and why, key decisions made during implementation, and follow-ups/tech debt (write "None" where a bucket is empty).
- This is the only Linear write this skill may ever perform — never change status, assignee, labels, or any other field.

```

- [ ] **Step 3: Update the Safety Rules (Claude dialect)**

Find:

```markdown
- **Never** update Linear (status, comments, assignee, labels).
```

Replace with:

```markdown
- **Never** change Linear status, assignee, labels, or any other field. The single permitted write is the opt-in as-built comment in Phase 8, and only after explicit user confirmation.
```

- [ ] **Step 4: Mirror in the Codex dialect**

In `.agents/skills/implement-ticket-linear/SKILL.md`:

1. Find Prerequisites item 3:

```markdown
3. Use only **read** Linear tools (get/list/search issue). Never call update/create/delete/comment/assign.
```

Replace with:

```markdown
3. Use only **read** Linear tools (get/list/search issue). Never call update/create/delete/assign. The only permitted write is the single opt-in as-built comment in Phase 7, posted only after explicit user confirmation.
```

2. Find the Phase 7 heading:

```markdown
## Phase 7: Summary (no commit, no Linear write)
```

Replace with:

```markdown
## Phase 7: Summary (no commit; Linear write only by opt-in)
```

3. In the Phase 7 numbered list, insert after item 5 (the `$update-ticket-linear` next-step item) a new item, renumbering the worktree item that follows:

```markdown
6. **As-built comment (opt-in):** ask exactly once — "Post this as-built summary as a comment on <issue_id>? (y/N)", default no. Only an explicit yes posts one comment (deviations from spec and why, key decisions, follow-ups/tech debt; "None" where empty) via the Linear MCP comment tool. Never change any other Linear field.
```

4. Find the first Safety Rule:

```markdown
- Never mutate Linear.
```

Replace with:

```markdown
- Never mutate Linear except the single opt-in as-built comment after explicit user confirmation; never change status, assignee, labels, or any other field.
```

- [ ] **Step 5: Update the README guarantee wording**

In `README.md`, find:

```markdown
- `implement-ticket-linear` — implement a Linear issue (via Linear MCP) with code review and optional worktree; does not use `docs/tickets/` and does not write back to Linear (the Linear twin of `implement-ticket`)
```

Replace with:

```markdown
- `implement-ticket-linear` — implement a Linear issue (via Linear MCP) with code review and optional worktree; does not use `docs/tickets/`; its only Linear write is an opt-in as-built comment posted after explicit confirmation (the Linear twin of `implement-ticket`)
```

- [ ] **Step 6: Verify**

```bash
grep -c "opt-in" skills/implement-ticket-linear/SKILL.md .agents/skills/implement-ticket-linear/SKILL.md
grep -c "y/N" skills/implement-ticket-linear/SKILL.md .agents/skills/implement-ticket-linear/SKILL.md
grep -c "does not write back to Linear" README.md
./scripts/check-codex-skills.sh
```

Expected: opt-in ≥ 3 in each dialect; `y/N` = 1 in each dialect; README count = 0 (old guarantee wording fully replaced); script prints `Validated 28 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 7: Commit**

```bash
git add skills/implement-ticket-linear/SKILL.md .agents/skills/implement-ticket-linear/SKILL.md README.md
git commit -m "feat(implement-ticket-linear): opt-in Linear as-built comment

Softens the guarantee to: never writes to Linear without explicit
confirmation. Default remains no write.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: New skill `quiz-ticket` (all three trees)

**Files:**
- Create: `skills/quiz-ticket/SKILL.md`
- Create: `.agents/skills/quiz-ticket/SKILL.md`
- Create: `.agents/skills/quiz-ticket/agents/openai.yaml`
- Create: symlink `.agent/skills/quiz-ticket` → `../../skills/quiz-ticket`

**Interfaces:**
- Consumes: the `## As-Built Notes` ticket section (Task 4) and `## References` (Task 3) as quiz material; the interactive-skill contract literals from Global Constraints.
- Produces: the `quiz-ticket` skill with default quiz mode and `explain` mode. Task 7 mirrors its structure for Linear; Task 8 registers it and adds its validation contract.

- [ ] **Step 1: Write the Claude dialect**

Create `skills/quiz-ticket/SKILL.md` with exactly this content:

````markdown
---
name: quiz-ticket
description: "Quiz your understanding of an implemented docs/tickets/ ticket, or generate a stakeholder explainer with `explain`. Use only when the request names docs/tickets/, a TICKET-NNN reference, or the quiz-ticket skill; do not use for Linear issue IDs or URLs. Reads the ticket and its implementation diff, then asks understanding-check questions one at a time and corrects misconceptions with file:line evidence. Read-only: never edits tickets, INDEX.md, or git; writes a file only when the user asks to save the explainer."
user-invocable: true
disable-model-invocation: true
argument-hint: "[ticket] [explain]"
---

**Invocation input:** `$ARGUMENTS`

# Quiz an Implemented Ticket (advisory, read-only)

Verify the user's understanding of what was actually built for one `docs/tickets/` ticket, or produce a stakeholder explainer. Agent-implemented code the user has not internalized is a blind spot waiting to bite; this skill turns the implementation's unknowns back into known knowns. The quiz hunts the user's unknown unknowns (behavior they never considered), surfaces unknown knowns (things they would recognize but could not state), and answers known unknowns with `path:line` evidence.

Use `docs/tickets/` as the source of truth. Do not use Linear. For a Linear issue, use the `quiz-ticket-linear` skill.

## Portable interaction rules

- Resolve the ticket reference from populated invocation input when available; otherwise use the ticket reference in the surrounding user request. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- Ask questions one at a time and wait for the answer before continuing.
- When the user must select or confirm something, show every candidate with a stable ticket id and distinguishing label.
- Use the host's structured choice mechanism only when it is available and can represent the candidates clearly. Otherwise ask a concise numbered prose question and accept a ticket id or number.
- Never assume an option limit or an automatically supplied "Other" choice.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites and argument grammar

Require a git repository containing `docs/tickets/`. If it is missing, stop with a short hint that Linear issues use `quiz-ticket-linear`.

Accept one optional `<ticket>` plus one optional mode token:

| Input | Meaning |
| --- | --- |
| `TICKET-007`, `007`, `#7`, or `7` | Quiz that ticket; normalize to three-digit `NNN`. |
| `<ticket> explain` | Produce a stakeholder explainer instead of a quiz. |
| Empty | Auto-detect a recently implemented ticket, then quiz it. |

`explain` is case-insensitive and must be the last token. Reject status tokens, multi-ticket batches, write/commit flags, invalid refs, and extra tokens.

## Phase 1: Resolve the Ticket

1. Resolve repository roots:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse the invocation input or surrounding request. If a ticket ref exists, normalize it to `NNN`; otherwise auto-detect:
   - Current branch matching `^ticket-(\d{3})-.+$` → use its `NNN`.
   - Otherwise registered worktrees under `$MAIN_ROOT/.worktrees/` with branches matching `^ticket-(\d{3})-.+$`.
   - Otherwise `INDEX.md` rows whose status is `in-progress` or `done`, most recently touched first (judge by `git log` mentions of the ticket file).
   - One candidate → ask for confirmation; multiple → apply the portable interaction rules; none → stop and request a ticket number.
3. Resolve exactly one `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match or multiple matches → stop and report the problem. Derive `slug` from the filename.

## Phase 2: Read Ticket and Project Context

1. Read the full ticket file, including its `## As-Built Notes` section when present — deviations documented there are prime quiz material — and any `## References` section.
2. Read the ticket's `INDEX.md` row. If the status is `pending`, warn that the ticket appears unimplemented and ask whether to continue anyway.
3. Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent) to calibrate terminology to the project's conventions.

## Phase 3: Locate and Study the Implementation

1. Locate the implementation diff, in order:
   - A registered worktree `$MAIN_ROOT/.worktrees/NNN-*` (branch `ticket-NNN-*`): diff that branch against its merge base with its base branch.
   - A local branch `ticket-NNN-*`: the same merge-base diff.
   - Commits whose messages reference `TICKET-NNN` or the ticket filename: their combined diff.
   - Otherwise ask the user where the implementation lives (a branch, a commit range, or current uncommitted changes); also accept "use the current state of the files the ticket names."
2. Read the diff AND the full current content of each changed file — questions must reflect the code as it exists, not just the delta.
3. Note behaviors worth probing: non-obvious decisions, edge-case handling, integration points, and anything `## As-Built Notes` flags as a deviation.

## Phase 4: Quiz Mode (default)

Build 5–8 questions mixing three kinds:

- **Why** — design decisions and trade-offs ("Why does the export run in a worker instead of the request handler?")
- **Behavior** — what the code does in a specific scenario ("What happens when the list is empty?")
- **Where** — which code handles a responsibility ("Where is the retry limit enforced?")

Rules:

- Ask the questions one at a time using the portable interaction rules; wait for each answer before continuing.
- After each answer, confirm or correct with `path:line` evidence. Coach, don't grade — no scores, no letter grades.
- Prioritize questions about deviations recorded in `## As-Built Notes` and code the user is least likely to have read.
- Stop early if the user asks to stop; go deeper on a topic when they ask.

Close with an understanding summary, on screen only:

```
## Understanding Summary — TICKET-NNN
**Solid** — areas the user explained correctly
**Gaps** — misconceptions corrected, each with the relevant `path:line`
**Worth rereading** — files or functions to review
```

## Phase 5: Explain Mode (`explain` argument)

Skip the quiz. Produce a stakeholder-facing explainer in chat:

```
## Explainer — TICKET-NNN: <title>
**What changed** — plain-language summary of the delivered behavior
**Why** — the problem it solves, from the ticket's Description
**Impact** — what users or dependent systems will notice
**Risks and limitations** — known edge cases and deferred work from `## As-Built Notes`
**Follow-ups** — open items, if any
```

Write for a reader who has not seen the code; name files only when they aid navigation. Then offer once to save the explainer to a file path the user names; write the file only if they provide a path.

## Safety rules

- Never edit ticket files, `INDEX.md`, other repo files, or git state; never commit; never run mutating shell commands. The only permitted write is the explainer file, at an explicit user-provided path.
- Do not use Linear.
- Do not invoke `implement-ticket`, `update-ticket`, `review-ticket`, or commit skills; only suggest next steps.
- If the implementation cannot be located, ask — never quiz from guessed code.
````

- [ ] **Step 2: Write the Codex dialect**

Create `.agents/skills/quiz-ticket/SKILL.md` with exactly this content:

```markdown
---
name: "quiz-ticket"
description: "Use only when the user explicitly asks to quiz their understanding of an implemented docs/tickets/ ticket, or to generate a stakeholder explainer for one, or invokes quiz-ticket. Do not use for Linear issue ids or URLs. Reads the ticket and its implementation diff, asks understanding-check questions one at a time (default), or with `explain` produces a what-changed/why/impact explainer. Read-only: never edits tickets, INDEX.md, or git."
---

# Quiz an Implemented Ticket (advisory, read-only)

Verify the user's understanding of what was actually built for one `docs/tickets/` ticket, or with `explain` produce a stakeholder explainer. The quiz hunts unknown unknowns (behavior never considered), surfaces unknown knowns (recognized but unstated), and answers known unknowns with `path:line` evidence. Never edit files or git. Use `quiz-ticket-linear` for Linear issues.

Resolve the ticket reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. A trailing `explain` token (case-insensitive) switches to explain mode. Empty input means auto-detect.

## Portable interaction

When asking questions or requesting selection:

1. Ask questions one at a time and wait for the answer before continuing.
2. Show every candidate with a stable ticket id and distinguishing path/title.
3. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
4. Never assume an option limit or implicit "Other" choice.

Refer to follow-up skills by name. Use host-native invocation syntax when known; otherwise show the plain skill name and arguments.

## Phase 1: Resolve Ticket and Implementation

1. Require a git repo with `docs/tickets/`, then resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. Normalize the ticket ref (`TICKET-007`, `007`, `#7`, `7`) to `NNN`; with no ref, auto-detect from a `ticket-NNN-*` branch, a registered `.worktrees/` entry, or `in-progress`/`done` INDEX rows (confirm the pick). Resolve exactly one `$MAIN_ROOT/docs/tickets/NNN-*.md`; stop on zero/multiple matches.
3. Locate the implementation diff, in order: registered worktree `.worktrees/NNN-*`, local `ticket-NNN-*` branch (merge-base diff), commits referencing `TICKET-NNN`, or ask the user (branch, commit range, or current changes).

## Phase 2: Study

1. Read the full ticket, including `## As-Built Notes` and `## References` when present, plus the matching INDEX row (warn and confirm if status is `pending`).
2. Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent).
3. Read the diff and the full current content of every changed file. Note non-obvious decisions, edge cases, integration points, and documented deviations.

## Phase 3a: Quiz (default)

Build 5–8 questions mixing why (design decisions), behavior (what happens when X), and where (which code handles Y). Ask one at a time; after each answer, confirm or correct with `path:line` evidence. Coach, don't grade. Prioritize `## As-Built Notes` deviations and code the user likely has not read. Close with an on-screen understanding summary: solid areas, corrected gaps with evidence, and files worth rereading.

## Phase 3b: Explain (`explain` token)

Skip the quiz. Present a stakeholder explainer: what changed (plain language), why, impact on users and dependent systems, risks/limitations (including deferred work from `## As-Built Notes`), and follow-ups. Offer once to save it to a user-named path; write only if a path is provided.

## Safety rules

- Read-only: never edit tickets, INDEX, repo files, or git; never commit or run mutating commands. The only permitted write is the explainer file at an explicit user-provided path.
- Do not use Linear.
- Do not call implementation, update, review, or commit skills; only suggest them.
- If the implementation cannot be located, ask — never quiz from guessed code.
```

- [ ] **Step 3: Write the Codex interface metadata**

Create `.agents/skills/quiz-ticket/agents/openai.yaml` with exactly:

```yaml
interface:
  display_name: "Quiz Ticket"
  short_description: "Quiz yourself on an implemented markdown ticket"
  default_prompt: "Use $quiz-ticket to read one implemented docs/tickets/ ticket and its diff, then quiz the user's understanding one question at a time, or produce a stakeholder explainer with `explain`."

policy:
  allow_implicit_invocation: false
```

(`short_description` is 47 characters — inside the 25–64 band Task 8 will enforce.)

- [ ] **Step 4: Create the Antigravity symlink**

```bash
ln -s ../../skills/quiz-ticket .agent/skills/quiz-ticket
```

- [ ] **Step 5: Verify**

```bash
readlink .agent/skills/quiz-ticket
grep -c "one at a time" skills/quiz-ticket/SKILL.md .agents/skills/quiz-ticket/SKILL.md
grep -c "As-Built Notes" skills/quiz-ticket/SKILL.md .agents/skills/quiz-ticket/SKILL.md
grep -c "AskUserQuestion" skills/quiz-ticket/SKILL.md .agents/skills/quiz-ticket/SKILL.md
./scripts/check-codex-skills.sh
```

Expected: `readlink` prints exactly `../../skills/quiz-ticket`; "one at a time" ≥ 2 in each dialect; "As-Built Notes" ≥ 2 in each; "AskUserQuestion" = 0 in each (grep -c prints 0 and exits 1 — that is the pass condition); script prints `Validated 29 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 6: Commit**

```bash
git add skills/quiz-ticket .agents/skills/quiz-ticket .agent/skills/quiz-ticket
git commit -m "feat(quiz-ticket): add post-implementation quiz and explainer skill

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: New skill `quiz-ticket-linear` (all three trees)

**Files:**
- Create: `skills/quiz-ticket-linear/SKILL.md`
- Create: `.agents/skills/quiz-ticket-linear/SKILL.md`
- Create: `.agents/skills/quiz-ticket-linear/agents/openai.yaml`
- Create: symlink `.agent/skills/quiz-ticket-linear` → `../../skills/quiz-ticket-linear`

**Interfaces:**
- Consumes: quiz/explain structure from Task 6; the opt-in as-built comment (Task 5) as readable quiz material; interactive-skill contract literals.
- Produces: the `quiz-ticket-linear` skill. Task 8 registers it and adds its validation contract (requires the literal `as-built`).

- [ ] **Step 1: Write the Claude dialect**

Create `skills/quiz-ticket-linear/SKILL.md` with exactly this content:

````markdown
---
name: quiz-ticket-linear
description: "Quiz your understanding of an implemented Linear issue, or generate a stakeholder explainer with `explain`. Use only when the request names Linear, a TEAM-NUMBER issue id, a linear.app issue URL, or the quiz-ticket-linear skill; do not use for docs/tickets/ or TICKET-NNN markdown tickets. Fetches the issue via read-only Linear MCP tools, studies the local implementation diff, then asks understanding-check questions one at a time and corrects misconceptions with file:line evidence. Never modifies Linear or git; writes a file only when the user asks to save the explainer."
user-invocable: true
disable-model-invocation: true
argument-hint: "[issue-id-or-url] [explain]"
---

**Invocation input:** `$ARGUMENTS`

# Quiz an Implemented Linear Issue (advisory, read-only)

Verify the user's understanding of what was actually built for one Linear issue, or produce a stakeholder explainer. Agent-implemented code the user has not internalized is a blind spot waiting to bite; this skill turns the implementation's unknowns back into known knowns. The quiz hunts the user's unknown unknowns (behavior they never considered), surfaces unknown knowns (things they would recognize but could not state), and answers known unknowns with `path:line` evidence.

Use Linear as the ticket source of truth. Do not use `docs/tickets/`. For a markdown ticket, use the `quiz-ticket` skill.

## Portable interaction rules

- Resolve the issue reference from populated invocation input when available; otherwise use the identifier or URL in the surrounding user request. Treat a missing, empty, or unsubstituted host placeholder as no argument.
- Ask questions one at a time and wait for the answer before continuing.
- When the user must select or confirm something, show every candidate with a stable issue id/path and distinguishing label.
- Use the host's structured choice mechanism only when available and suitable. Otherwise ask a concise numbered prose question and accept an issue id, number, or path.
- Never assume an option limit or an automatically supplied "Other" choice.
- Refer to other skills by name. When suggesting a command, use host-native syntax if known (`/skill` in Claude Code, `$skill` in Codex); otherwise show the plain skill name and arguments.

## Prerequisites and argument grammar

Require authenticated Linear MCP read tools; discover the host's actual read-tool schemas instead of inventing names or fields. If unavailable, stop with a short setup hint; do not use HTTP, API-key, CLI, or browser fallbacks.

Also require a git repository — the quiz is grounded in the local implementation. Without one, stop and explain that this skill needs the repo where the issue was implemented.

Accept one optional `<issue>` plus one optional mode token:

| Input | Meaning |
| --- | --- |
| `ENG-42` or another `TEAM-NUMBER` id | Quiz that issue; uppercase the team key. |
| A Linear issue URL containing an id | Extract and quiz that issue. |
| `<issue> explain` | Produce a stakeholder explainer instead of a quiz. |
| Empty | Auto-detect from a `linear-*` git branch or registered worktree. |

`explain` is case-insensitive and must be the last token. Reject status tokens, multi-issue batches, title-only searches, write/commit flags, invalid refs, and extra tokens.

## Phase 1: Resolve the Issue and Fetch It

1. Resolve repository roots:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse the invocation input. Normalize `^[A-Za-z]+-\d+$` by uppercasing the team key; for a URL, extract a complete `TEAM-NUMBER` path token and fail if none exists. With no ref, auto-detect from the current branch or registered worktree branches matching `^linear-([A-Za-z]+-\d+)-.+$`; one candidate → use it; multiple → apply the portable interaction rules; none → stop and request an issue id or URL.
3. Fetch the issue by exact normalized identifier through Linear MCP read tools. Missing or ambiguous → stop. Capture the canonical id, title, description, state, acceptance criteria (checklists or a labeled section), relations, and comments — including any as-built comment a previous `implement-ticket-linear` run posted; deviations documented there are prime quiz material.

## Phase 2: Read Project Context

Within the repo, read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent) to calibrate terminology to the project's conventions.

## Phase 3: Locate and Study the Implementation

1. Derive `slug` from the issue title (lowercase, non-alphanumerics → `-`, collapse, trim, ~40 chars; fallback `issue`). Locate the implementation diff, in order:
   - A registered worktree `$MAIN_ROOT/.worktrees/<issue_id>-*` (branch `linear-<issue_id>-*`): diff that branch against its merge base with its base branch.
   - A local branch `linear-<issue_id>-*`: the same merge-base diff.
   - Commits whose messages reference `<issue_id>`: their combined diff.
   - Otherwise ask the user where the implementation lives (a branch, a commit range, or current uncommitted changes).
2. Read the diff AND the full current content of each changed file — questions must reflect the code as it exists, not just the delta.
3. Note behaviors worth probing: non-obvious decisions, edge-case handling, integration points, and anything the as-built comment flags as a deviation.

## Phase 4: Quiz Mode (default)

Build 5–8 questions mixing three kinds:

- **Why** — design decisions and trade-offs
- **Behavior** — what the code does in a specific scenario
- **Where** — which code handles a responsibility

Rules:

- Ask the questions one at a time using the portable interaction rules; wait for each answer before continuing.
- After each answer, confirm or correct with `path:line` evidence. Coach, don't grade — no scores, no letter grades.
- Prioritize questions about deviations recorded in the as-built comment and code the user is least likely to have read.
- Stop early if the user asks to stop; go deeper on a topic when they ask.

Close with an understanding summary, on screen only:

```
## Understanding Summary — <ISSUE-ID>
**Solid** — areas the user explained correctly
**Gaps** — misconceptions corrected, each with the relevant `path:line`
**Worth rereading** — files or functions to review
```

## Phase 5: Explain Mode (`explain` argument)

Skip the quiz. Produce a stakeholder-facing explainer in chat:

```
## Explainer — <ISSUE-ID>: <title>
**What changed** — plain-language summary of the delivered behavior
**Why** — the problem it solves, from the issue description
**Impact** — what users or dependent systems will notice
**Risks and limitations** — known edge cases and deferred work from the as-built comment
**Follow-ups** — open items, if any
```

Write for a reader who has not seen the code; name files only when they aid navigation. Then offer once to save the explainer to a file path the user names; write the file only if they provide a path.

## Safety rules

- Use only Linear MCP read operations. Never change state, description, comments, acceptance criteria, assignee, labels, or any other Linear field — this skill never writes to Linear, not even a comment.
- Stay read-only in the repository: no file edits, commits, or mutating shell commands. The only permitted write is the explainer file, at an explicit user-provided path.
- Do not use `docs/tickets/` as the ticket source.
- Do not invoke `implement-ticket-linear`, `update-ticket-linear`, or commit skills; only suggest next steps.
- If the implementation cannot be located, ask — never quiz from guessed code.
````

- [ ] **Step 2: Write the Codex dialect**

Create `.agents/skills/quiz-ticket-linear/SKILL.md` with exactly this content:

```markdown
---
name: "quiz-ticket-linear"
description: "Use only when the user explicitly asks to quiz their understanding of an implemented Linear issue, or to generate a stakeholder explainer for one, or invokes quiz-ticket-linear. Do not use for docs/tickets/ markdown tickets. Fetches the issue via read-only Linear MCP tools, studies the local implementation diff, asks understanding-check questions one at a time (default), or with `explain` produces a what-changed/why/impact explainer. Never modifies Linear or git. Requires Linear MCP."
---

# Quiz an Implemented Linear Issue (advisory, read-only)

Verify the user's understanding of what was actually built for one Linear issue, or with `explain` produce a stakeholder explainer. The quiz hunts unknown unknowns (behavior never considered), surfaces unknown knowns (recognized but unstated), and answers known unknowns with `path:line` evidence. Never modify Linear or git. Use `quiz-ticket` for markdown tickets.

Resolve the issue reference from explicit skill arguments when the host provides them; otherwise use the surrounding request. A trailing `explain` token (case-insensitive) switches to explain mode. Empty input means auto-detect from `linear-*` branches.

## Portable interaction

When asking questions or requesting selection:

1. Ask questions one at a time and wait for the answer before continuing.
2. Show every candidate with a stable issue id/path and distinguishing label.
3. Use the host's structured choice mechanism only when available and suitable; otherwise ask a concise numbered prose question.
4. Never assume an option limit or implicit "Other" choice.

Refer to follow-up skills by name. Use host-native invocation syntax when known; otherwise show the plain skill name and arguments.

## Phase 1: Resolve and Fetch

1. Require authenticated Linear MCP read tools (no HTTP/API-key/CLI fallbacks) and a git repository, then resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   ```
2. Normalize the issue ref (`TEAM-NUMBER` id or URL; uppercase the team key). With no ref, auto-detect from current or worktree branches matching `linear-<TEAM-NUMBER>-*`; confirm the pick.
3. Fetch the issue by exact identifier: title, description, state, acceptance criteria, relations, and comments — including any as-built comment a previous implement run posted.

## Phase 2: Study

1. Read applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, or equivalent).
2. Locate the implementation diff, in order: registered worktree `.worktrees/<issue_id>-*`, local `linear-<issue_id>-*` branch (merge-base diff), commits referencing the issue id, or ask the user (branch, commit range, or current changes).
3. Read the diff and the full current content of every changed file. Note non-obvious decisions, edge cases, integration points, and deviations flagged in the as-built comment.

## Phase 3a: Quiz (default)

Build 5–8 questions mixing why (design decisions), behavior (what happens when X), and where (which code handles Y). Ask one at a time; after each answer, confirm or correct with `path:line` evidence. Coach, don't grade. Prioritize as-built deviations and code the user likely has not read. Close with an on-screen understanding summary: solid areas, corrected gaps with evidence, and files worth rereading.

## Phase 3b: Explain (`explain` token)

Skip the quiz. Present a stakeholder explainer: what changed (plain language), why, impact on users and dependent systems, risks/limitations (including deferred work from the as-built comment), and follow-ups. Offer once to save it to a user-named path; write only if a path is provided.

## Safety rules

- Linear is strictly read-only here: never change state, description, comments, assignee, labels, or any field — this skill never writes to Linear, not even a comment.
- Repository read-only: never edit files or git; never commit or run mutating commands. The only permitted write is the explainer file at an explicit user-provided path.
- Do not use `docs/tickets/` as the ticket source.
- Do not call implementation, update, or commit skills; only suggest them.
- If the implementation cannot be located, ask — never quiz from guessed code.
```

- [ ] **Step 3: Write the Codex interface metadata**

Create `.agents/skills/quiz-ticket-linear/agents/openai.yaml` with exactly:

```yaml
interface:
  display_name: "Quiz Ticket (Linear)"
  short_description: "Quiz yourself on an implemented Linear issue"
  default_prompt: "Use $quiz-ticket-linear to fetch one implemented Linear issue and study its local diff, then quiz the user's understanding one question at a time, or produce a stakeholder explainer with `explain`."

policy:
  allow_implicit_invocation: false
```

(`short_description` is 44 characters — inside the 25–64 band.)

- [ ] **Step 4: Create the Antigravity symlink**

```bash
ln -s ../../skills/quiz-ticket-linear .agent/skills/quiz-ticket-linear
```

- [ ] **Step 5: Verify**

```bash
readlink .agent/skills/quiz-ticket-linear
grep -c "one at a time" skills/quiz-ticket-linear/SKILL.md .agents/skills/quiz-ticket-linear/SKILL.md
grep -ci "as-built" skills/quiz-ticket-linear/SKILL.md .agents/skills/quiz-ticket-linear/SKILL.md
grep -c "AskUserQuestion" skills/quiz-ticket-linear/SKILL.md .agents/skills/quiz-ticket-linear/SKILL.md
./scripts/check-codex-skills.sh
```

Expected: `readlink` prints exactly `../../skills/quiz-ticket-linear`; "one at a time" ≥ 2 in each dialect; "as-built" ≥ 3 in each; "AskUserQuestion" = 0 in each; script prints `Validated 30 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 6: Commit**

```bash
git add skills/quiz-ticket-linear .agents/skills/quiz-ticket-linear .agent/skills/quiz-ticket-linear
git commit -m "feat(quiz-ticket-linear): add Linear twin of quiz-ticket

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Validation contract + registration (script, catalog, keywords, README)

**Files:**
- Modify: `scripts/check-codex-skills.sh`
- Modify: `catalog.json`
- Modify: `.claude-plugin/plugin.json`
- Modify: `README.md`

**Interfaces:**
- Consumes: the quiz twins from Tasks 6–7 with their contract literals (`Portable interaction`, `Never assume an option limit`, `AGENTS.md`, `one at a time`, `explain`, `As-Built Notes` / `as-built`).
- Produces: the enforced contract and all user-facing registration. This is the final acceptance gate.

- [ ] **Step 1: Extend the openai.yaml strict contract to quiz twins**

In `scripts/check-codex-skills.sh`, inside `validate_openai_yaml`, find:

```ruby
    if %w[clarify-ticket clarify-ticket-linear].include?(skill)
      short = interface["short_description"]
      abort("short_description must be 25-64 characters") unless (25..64).cover?(short.length)
      abort("default_prompt must mention $#{skill}") unless interface["default_prompt"].include?("$#{skill}")
      abort("clarify skills must be explicit-only") unless implicit == false
    end
```

Replace with:

```ruby
    if %w[clarify-ticket clarify-ticket-linear quiz-ticket quiz-ticket-linear].include?(skill)
      short = interface["short_description"]
      abort("short_description must be 25-64 characters") unless (25..64).cover?(short.length)
      abort("default_prompt must mention $#{skill}") unless interface["default_prompt"].include?("$#{skill}")
      abort("interactive skills must be explicit-only") unless implicit == false
    end
```

- [ ] **Step 2: Extend the cross-agent metadata and portable-contract loop**

In the same script, inside `validate_clarify_contract`, find:

```bash
  for skill in clarify-ticket clarify-ticket-linear; do
```

Replace with:

```bash
  for skill in clarify-ticket clarify-ticket-linear quiz-ticket quiz-ticket-linear; do
```

(The loop body — Claude frontmatter checks, Codex key restriction, `Portable interaction` / `Never assume an option limit` / `AGENTS.md` literals, `AskUserQuestion` prohibition — now applies to all four skills unchanged.)

- [ ] **Step 3: Add quiz-specific literal checks**

Still inside `validate_clarify_contract`, after the existing `clarify-ticket-linear`-specific loop (the one requiring `REPO_AVAILABLE=false` etc.), insert:

```bash
  for skill_md in \
    "$claude_root/quiz-ticket/SKILL.md" \
    "$codex_root/quiz-ticket/SKILL.md" \
    "$claude_root/quiz-ticket-linear/SKILL.md" \
    "$codex_root/quiz-ticket-linear/SKILL.md"; do
    require_literal "$skill_md" "one at a time"
    require_literal "$skill_md" "explain"
  done

  for skill_md in \
    "$claude_root/quiz-ticket/SKILL.md" \
    "$codex_root/quiz-ticket/SKILL.md"; do
    require_literal "$skill_md" "As-Built Notes"
  done

  for skill_md in \
    "$claude_root/quiz-ticket-linear/SKILL.md" \
    "$codex_root/quiz-ticket-linear/SKILL.md"; do
    require_literal "$skill_md" "as-built comment"
  done
```

- [ ] **Step 4: Register in catalog.json**

In `catalog.json`, insert after the `update-ticket-linear` entry (and before `commit-ticket`):

```json
    {
      "name": "quiz-ticket",
      "path": ".agent/skills/quiz-ticket",
      "description": "Quiz your understanding of an implemented docs/tickets/ ticket from its diff, or generate a stakeholder explainer with `explain` — read-only (docs/tickets twin of quiz-ticket-linear)"
    },
    {
      "name": "quiz-ticket-linear",
      "path": ".agent/skills/quiz-ticket-linear",
      "description": "Quiz your understanding of an implemented Linear issue from its local diff, or generate a stakeholder explainer with `explain` — read-only (requires Linear MCP; Linear twin of quiz-ticket)"
    },
```

- [ ] **Step 5: Add plugin keywords**

In `.claude-plugin/plugin.json`, in the `keywords` array, insert `"quiz-ticket", "quiz-ticket-linear",` immediately after `"clarify-ticket-linear",`.

- [ ] **Step 6: README — skills list**

In `README.md`'s Development Skills list, insert after the `update-ticket-linear` bullet:

```markdown
- `quiz-ticket` — quiz your understanding of an implemented `docs/tickets/` ticket from its implementation diff, or generate a stakeholder explainer with `explain`; read-only (the `docs/tickets/` twin of `quiz-ticket-linear`)
- `quiz-ticket-linear` — quiz your understanding of an implemented Linear issue (via Linear MCP) from its local implementation diff, or generate a stakeholder explainer with `explain`; read-only against Linear and the repo (the Linear twin of `quiz-ticket`)
```

- [ ] **Step 7: README — installer lists and count**

1. In the "Install all skills" block, find the intro line containing `twenty-four installer-compatible skill paths` and change it to `twenty-six installer-compatible skill paths`.
2. In that same block's path list, insert after `.agents/skills/update-ticket-linear`:

```text
.agents/skills/quiz-ticket
.agents/skills/quiz-ticket-linear
```

3. In the "Install an individual skill" block, insert after the `update-ticket-linear` line:

```text
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/quiz-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/quiz-ticket-linear
```

4. In the Antigravity "install directly from GitHub" `for s in …` list, add `quiz-ticket quiz-ticket-linear` after `update-ticket-linear`.

- [ ] **Step 8: README — usage sections and policy list**

1. Codex Usage block — insert after the `$update-ticket-linear ENG-42 in-progress` line:

```text
$quiz-ticket 007
$quiz-ticket 007 explain
$quiz-ticket-linear ENG-42
$quiz-ticket-linear ENG-42 explain
```

2. The explicit-only policy paragraph after the Codex usage block lists skills in parentheses; add `quiz-ticket`, `quiz-ticket-linear` to that list (after `clarify-ticket-linear`).

3. Claude Code Usage block — insert after the `/update-ticket-linear ENG-42 in-progress` line:

```text

/quiz-ticket 007                          # Quiz your understanding of an implemented ticket (read-only)
/quiz-ticket 007 explain                  # Stakeholder explainer instead of a quiz
/quiz-ticket-linear ENG-42                # Same for a Linear issue (requires Linear MCP)
/quiz-ticket-linear ENG-42 explain        # Stakeholder explainer for a Linear issue
```

4. OpenCode Usage section — extend the example block with:

```text
Use quiz-ticket for TICKET-007.
Use quiz-ticket-linear for ENG-42.
```

and change the sentence `The clarification skills use host-neutral questions and follow-up wording.` to `The clarification and quiz skills use host-neutral questions and follow-up wording.`

- [ ] **Step 9: Verify (final acceptance gate)**

```bash
./scripts/check-codex-skills.sh
```

Expected: `Validated 30 skill(s) across Claude, Codex, and Antigravity.` with no ERROR lines.

```bash
RUBYOPT=--disable=gems ruby -e 'require "json"; JSON.parse(File.read("catalog.json")); JSON.parse(File.read(".claude-plugin/plugin.json")); puts "json ok"'
```

Expected: `json ok`

```bash
grep -c "quiz-ticket" README.md
```

Expected: ≥ 12 (skills list ×2, install-all ×2, individual ×2, Antigravity ×1, Codex usage ×2+2, policy list ×2, Claude usage ×4, OpenCode ×2 — counting substring matches of `quiz-ticket`).

Negative check — deliberately break one contract literal to prove the new validation bites, then restore it:

```bash
sed -i '' 's/Never assume an option limit/NEVER ASSUME AN OPTION LIMIT/' skills/quiz-ticket/SKILL.md
./scripts/check-codex-skills.sh; echo "exit: $?"
git checkout -- skills/quiz-ticket/SKILL.md
./scripts/check-codex-skills.sh
```

Expected: the broken run prints an ERROR mentioning `skills/quiz-ticket/SKILL.md` and `exit: 1`; the restored run prints `Validated 30 skill(s) across Claude, Codex, and Antigravity.`

- [ ] **Step 10: Commit**

```bash
git add scripts/check-codex-skills.sh catalog.json .claude-plugin/plugin.json README.md
git commit -m "feat(quiz-ticket): register quiz twins and extend validation contract

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
