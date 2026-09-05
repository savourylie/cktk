# Project Bindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add an `init-project` skill that records where a repository's Linear
project and Notion workspace live, then teach `/update-ticket-linear` to sync the
Linear Project Context and append cross-cutting decisions to the Notion decision
log.

**Architecture:** Documentation artifacts, not code. Part A writes a versioned
contract at `.ai/cktk/project.json`, described normatively in one shared
`references/` file that both skills point at. Part B adds two phases to
`update-ticket-linear` that read that contract and degrade to a report whenever a
precondition fails.

**Tech Stack:** Markdown `SKILL.md` documents across three trees (`skills/`,
`.agents/skills/`, `.agent/skills/`), JSON registration in `catalog.json`, Linear
MCP and Notion MCP at runtime.

**Spec:** `docs/superpowers/specs/2026-09-04-project-bindings-design.md`

## Global Constraints

- Three trees stay consistent: every skill in `skills/` needs a folder in
  `.agents/skills/` and a symlink in `.agent/skills/` (AGENTS.md rule 1).
- Never symlink or copy `SKILL.md` between the Claude and Codex trees — the Codex
  copy is a separate document with Codex-native instructions (AGENTS.md rule 2).
- Shared `references/` live under `skills/` and reach Codex by symlink
  (AGENTS.md rule 3).
- Adding a skill means updating all three trees, `README.md`, `catalog.json`, and
  rerunning `scripts/check-codex-skills.sh` (AGENTS.md rule 4).
- Codex docs use `$skill-name` invocation syntax; Claude docs use `/skill-name`.
- Before writing a call to another skill, read the callee's preconditions
  (AGENTS.md rule 6).
- The contract file is `.ai/cktk/project.json`, `schema_version: 1`.
- Duplicate detection uses a `cktk:decision-logged <ISSUE-ID> → <url>` marker
  comment on the Linear issue. **Never read the decision log to check for
  duplicates** — a real log runs to tens of thousands of characters and reports no
  truncation warning. Entries still carry `cktk:<ISSUE-ID>:<slug>` for humans;
  nothing queries it.
- The Project Context is a Linear **Document** (`save_document`), never the project
  description (`save_project`). The description is read-only and out of scope.
- Linear documents are listed by **project id**; a team-scoped query returns empty
  even when the document exists.
- Permitted Notion writes: `notion-create-pages`, and `notion-update-page` with
  `command: "insert_content"` and `position: {"type":"end"}`. `update_content` and
  `replace_content` are forbidden by name.

**Verification is structural.** This repository has no unit-test harness for
skills. Each task's test is `scripts/check-codex-skills.sh`, JSON parsing, and
symlink resolution, as established by the plans dated 2026-07-23 and 2026-07-26.
Behavioural verification is a manual dry run (Task 6).

---

## Part A — the binding contract

### Task 1: The normative schema reference

**Files:**
- Create: `skills/init-project/references/project-schema.md`

**Interfaces:**
- Produces: the single normative description of `.ai/cktk/project.json` — field
  names, the three `status` values (`validated`, `read-only`, `unresolved`), both
  `decision_log.shape` variants, and the read protocol for consumers.

- [ ] **Step 1: Write the reference document**

Cover, in order: the file's purpose and location; that it is committed; the full
annotated example from spec §1; a field table; the `status` semantics; the
database-shaped versus page-shaped variants; the `schema_version` rule that a
reader finding a higher version reports and skips; and a "How to read this file"
section for consumer skills that states a missing file is never an error.

- [ ] **Step 2: Verify the example parses**

```bash
sed -n '/^```json$/,/^```$/p' skills/init-project/references/project-schema.md \
  | sed '1d;$d' | python3 -m json.tool > /dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add skills/init-project/references/project-schema.md
git commit -m "feat(init-project): add the project bindings schema reference"
```

### Task 2: The Claude-tree skill

**Files:**
- Create: `skills/init-project/SKILL.md`

**Interfaces:**
- Consumes: `references/project-schema.md` from Task 1.
- Produces: the `/init-project` slash command; the written contract file that
  Part B reads.

- [ ] **Step 1: Write frontmatter**

`name: init-project`, `user-invocable: true`, and a `description` carrying trigger
phrases (`/init-project`, bind repo to Linear, set up project bindings, connect
Notion workspace, where does this project live).

- [ ] **Step 2: Write the phases**

Six phases matching spec §2: Discover (read `README.md`, `docs/PRD.md`, design and
architecture docs; harvest URLs; infer team key and slug); Fill gaps by listing
(`list_teams`, `list_projects`, Notion search — never ask for a raw id); Propose
prefilled with sources cited as `file:line`; Validate including the consent-gated
write probe and the two possibly-missing database properties; Offer to create what
is missing, structure only; Report and re-run with per-binding correction.

- [ ] **Step 3: Write Safety Rules**

Never invent product content. Never record an unvalidated binding as `validated`.
Never add a property to a shared Notion database without explicit consent. Never
write the contract file when validation left every binding `unresolved`. Offer the
`.ai/cktk/delegation/` `.gitignore` line rather than adding it silently.

- [ ] **Step 4: Verify frontmatter parses**

```bash
RUBYOPT=--disable=gems ruby -ryaml -e 'm=YAML.load_file(ARGV[0]); abort "bad" unless m["name"] && m["description"]' skills/init-project/SKILL.md && echo OK
```
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/init-project/SKILL.md
git commit -m "feat(init-project): add the Claude-tree binding skill"
```

### Task 3: The Codex and Antigravity trees

**Files:**
- Create: `.agents/skills/init-project/SKILL.md` (separate Codex-native document)
- Create: `.agents/skills/init-project/references` → `../../../skills/init-project/references`
- Create: `.agent/skills/init-project` → `../../skills/init-project`

- [ ] **Step 1: Write the Codex document**

Same six phases, Codex-native metadata and `$init-project` invocation syntax. Not
a copy and not a symlink.

- [ ] **Step 2: Create the symlinks**

```bash
ln -s ../../../skills/init-project/references .agents/skills/init-project/references
ln -s ../../skills/init-project .agent/skills/init-project
```

- [ ] **Step 3: Verify they resolve**

```bash
test -f .agents/skills/init-project/references/project-schema.md \
  && test -f .agent/skills/init-project/SKILL.md && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .agents/skills/init-project .agent/skills/init-project
git commit -m "feat(init-project): add Codex and Antigravity trees"
```

### Task 4: Registration

**Files:**
- Modify: `catalog.json`
- Modify: `README.md`

- [ ] **Step 1: Add the catalog entry**

Match the shape of the neighbouring entries, `"path": ".agent/skills/init-project"`.

- [ ] **Step 2: Add the README rows**

The skill table, the install loop's skill list, and a usage example under the
Linear commands.

- [ ] **Step 3: Verify JSON**

```bash
python3 -m json.tool catalog.json > /dev/null \
  && python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add catalog.json README.md
git commit -m "feat(init-project): register the skill in catalog and README"
```

### Task 5: Full structural check

- [ ] **Step 1: Run the validator**

```bash
scripts/check-codex-skills.sh
```
Expected: exits 0, no `ERROR:` lines.

- [ ] **Step 2: Fix anything it reports, then rerun.**

- [ ] **Step 3: Commit only if step 2 changed files.**

### Task 6: Manual dry run — GATE — PASSED 2026-09-04

Run against the TaiwanEval and Redbeak workspaces. Everything below was exercised
and passed; five defects it surfaced were fixed in cc809da, 06046e9, 8f03ef1,
617ea04, a64a0c0, a2d2b4c, e68d86d, 072fe4d and 6274b22.

**Not exercised, and therefore unverified going into Part B:**

- A **database-shaped** decision log. Both workspaces keep a page, so the database
  path — property/type checking, `notion-create-pages` — has never run.
- A deliberately wrong URL failing at `init-project` and recording `unresolved`.
- The write probe actually running; both runs skipped it, which is the default.
- Creating a missing Linear project or decision log from scratch.
- Repointing inbound references after a migration; that was added after the one
  migration had already run.

- [x] Discovery finds the Linear and Notion URLs already sitting in a repository's
      `README.md`.
- [x] Validation resolves the Linear project and the Notion decision log.
- [x] The write probe offer appears and declining records `read-only`; not run. Originally: creates and removes a probe entry, and declining it records
      `read-only`.
- [ ] NOT TESTED — A deliberately wrong Notion URL fails at `init-project` with a clear reason
      and is recorded `unresolved`, not `validated`.
- [x] A re-run after moving the Notion page corrects one field without redoing the
      whole flow.
- [x] The written file matches `references/project-schema.md` exactly.
- [x] Running in a project whose Project Context sits in the description (Redbeak)
      offers the `y/N` migration; declining changes nothing and reports the
      misconfiguration; accepting creates the document, confirms it by fetching it
      back, and only then replaces the description with a pointer.

---

## Part B — consuming the bindings

Tasks 7-10 implemented 2026-09-05 in e8c970b. Task 11 (dry run) is open.

### Task 7 — DONE: Phase 1 binding load and phase renumbering

**Files:**
- Modify: `skills/update-ticket-linear/SKILL.md` — Phase 1, and Phase 8 heading
  renumbered to Phase 10
- Modify: `.agents/skills/update-ticket-linear/SKILL.md`

Phase 1 loads `.ai/cktk/project.json`; missing, unreadable, or a higher
`schema_version` is recorded and the run continues. Never blocks a status update.

### Task 8 — DONE: Phase 8 — Project Context sync

Per spec §3. `save_document` with `patch`, targeting the bound Project Context
document — **not** `save_project` and not the project description. Anchors from
ordinary prose, never from issue-identifier substrings, which serialize as
`<issue …>` markup. Runs after Phase 7's cascade. Skipped when no status was
written, bindings are absent, or `project_context.enabled` is false. Reports the
re-serialization caveat and, on declined consent, prints the patch operations.

### Task 9 — DONE: Phase 9 — Notion decision log

Per spec §4. The named-referent gate; the one-entry-per-issue check against the
Linear-side marker comment; the name-and-type pre-write schema check; the two
permitted write calls, appending at `append_position` rather than under a located
heading. Posts the marker comment only after the Notion write returns, and reports
loudly with the entry URL if that comment fails. Drafts into the summary whenever a
precondition fails.

### Task 10 — DONE: Safety Rules, Phase 10 summary, and ripples

**Files:**
- Modify: both `update-ticket-linear` trees — Safety Rules and the Phase 10 summary
- Modify: `skills/implement-ticket-linear/SKILL.md:332` and
  `.agents/skills/implement-ticket-linear/SKILL.md:181`
- Modify: `README.md`

### Task 11: Part B dry run

- [ ] A status change produces a correct patch.
- [ ] A hand-edited description produces a clean abort and a report, with nothing
      half-written.
- [ ] A second run on the same issue produces a draft, never a duplicate entry.
- [ ] Declining every prompt leaves behaviour identical to today, plus the printed
      draft.
