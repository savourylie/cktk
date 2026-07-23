# clarify-ticket-linear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new cktk skill, `clarify-ticket-linear`, that fetches a Linear issue, runs a codebase-grounded clarity/risk analysis, briefs the user, discusses open items interactively, and ends with a readiness summary — strictly advisory and read-only.

**Architecture:** This is a **documentation-artifact skill**, not code. It ships as Markdown `SKILL.md` files plus JSON/YAML registration, mirroring the existing `update-ticket-linear` skill across three trees: the canonical Claude tree (`skills/`), the multi-agent/Codex tree (`.agents/skills/`, with an `agents/openai.yaml` interface), and a symlink tree (`.agent/skills/`) referenced by `catalog.json`. Because there is no runtime code, each task's "test" is a **structural verification** (the repo's `scripts/check-codex-skills.sh` validator, JSON linting, symlink resolution) rather than a unit test; the behavioral acceptance test is a manual dry-run against a real Linear issue (Task 4).

**Tech Stack:** Markdown (SKILL.md), JSON (`catalog.json`, `.claude-plugin/plugin.json`), YAML (`agents/openai.yaml`), Bash validator (`scripts/check-codex-skills.sh`), Linear MCP (runtime dependency, read-only).

## Global Constraints

These apply to every task; copied verbatim from the spec (`docs/superpowers/specs/2026-07-23-clarify-ticket-linear-design.md`).

- **Skill name:** `clarify-ticket-linear`. In every ordered list (catalog, keywords, README bullets, install lists, usage examples, the install `for` loop), place it **immediately before `implement-ticket-linear`**.
- **Read-only guarantee:** never modifies the Linear issue (no state, comment, description, or acceptance-criteria edits); never edits repo files; never commits; never runs mutating/destructive shell. Both Linear and the codebase are read-only.
- **Linear MCP:** required and **read-only tools suffice** (get/search issue, list relations, get comments). No write tools needed. If missing → stop with a setup hint; **no** API-key / CLI / browser fallbacks.
- **Not `docs/tickets/`:** Linear is the source of truth; this skill never reads or writes `docs/tickets/`.
- **Frontmatter:** canonical `skills/.../SKILL.md` must have `name`, a non-empty `description` **≤ 1024 characters**, and `user-invocable: true`. The `.agents/.../SKILL.md` variant must have `name` + non-empty `description` ≤ 1024 chars.
- **Tree parity (validator-enforced):** every skill dir under `skills/` must have a matching dir under `.agents/skills/` with a `SKILL.md` **and** an `agents/openai.yaml` (valid YAML). `openai.yaml` policy is `allow_implicit_invocation: false` (external-service workflow → explicit-only).
- **Readiness verdict** vocabulary: `ready` / `needs-clarification` / `blocked`. Team workflow states are never listed or mapped.

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `skills/clarify-ticket-linear/SKILL.md` | Canonical, full skill instructions (Claude tree) | 1 |
| `.agents/skills/clarify-ticket-linear/SKILL.md` | Condensed multi-agent/Codex variant | 2 |
| `.agents/skills/clarify-ticket-linear/agents/openai.yaml` | Codex interface + explicit-only policy | 2 |
| `.agent/skills/clarify-ticket-linear` | Symlink → `../../skills/clarify-ticket-linear` (catalog path target) | 2 |
| `catalog.json` | Skill registry entry | 3 |
| `.claude-plugin/plugin.json` | Keyword registration | 3 |
| `README.md` | Docs: description bullet, install lists, usage examples, policy list, install loop | 3 |

---

## Task 1: Author the canonical SKILL.md

**Files:**
- Create: `skills/clarify-ticket-linear/SKILL.md`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the canonical skill contract. Later tasks rely on the exact skill name `clarify-ticket-linear`, the frontmatter `description` string (reused/condensed in Task 2's variant and Task 3's registration), and `user-invocable: true`.

- [ ] **Step 1: Create the canonical SKILL.md with this exact content**

````markdown
---
name: clarify-ticket-linear
description: "Fetch a Linear issue and interactively clarify its details and risks against the codebase before implementation — strictly read-only, never modifies Linear or git. Produces a codebase-grounded briefing, a guided discussion, and a readiness summary. Requires Linear MCP (read-only). Triggers on: /clarify-ticket-linear, /clarify-ticket-linear ENG-42, clarify Linear issue ENG-42, de-risk ticket before implementing, discuss ticket details and risks"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a pre-implementation ticket clarifier. Your job is to fetch a Linear issue, analyze it against the actual codebase, surface details that need confirming and risks worth knowing, discuss the open items interactively with the user, and end with a readiness summary. Follow each phase precisely.

**This skill is strictly advisory and read-only.** It never modifies the Linear issue (no state, comment, description, or acceptance-criteria changes), never edits repo files, and never commits. Linear is the source of truth; it does **not** use `docs/tickets/`.

## Prerequisites

1. **Linear MCP** must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp). **Read-only tools suffice** (get/search issue, list relations, get comments). No write tools are needed.
2. If Linear MCP tools are missing, stop with a short setup hint. Do **not** invent API-key, CLI, or browser fallbacks.
3. Prefer the host's actual Linear MCP tool names; discover schemas rather than inventing fields.
4. Team workflow states are **not** listed or mapped — the readiness verdict is this skill's own, independent of Linear states.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Clarify that issue. |
| (empty) | Auto-detect the issue from branch / matching linear worktree, then clarify. |

`<issue>` is either a Linear identifier `TEAM-NUMBER` (e.g. `ENG-42`, `CKTK-7`; case-insensitive, team key uppercased) or a Linear issue URL containing that identifier.

**Not accepted:** a status token, multi-issue batches, free-text title search alone, or any write/commit flags. Extra tokens beyond a single issue → stop with an unrecognized-arguments error.

## Phase 1: Parse Arguments & Resolve Handles

1. Confirm you're inside a git repo, then compute:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse `$ARGUMENTS`. Split on whitespace.
   - If the first token looks like an issue id (`TEAM-NUM`) or a URL, treat it as `issue_ref`. No further tokens are expected.
   - If `$ARGUMENTS` is empty, run **auto-detect** (below) to resolve `issue_ref`.
   - If a first token is present but is neither an issue id/URL nor empty, stop with an unrecognized-arguments error.
   - Any extra tokens beyond the issue → stop with an unrecognized-arguments error.

### Auto-detect (only when `$ARGUMENTS` is empty)

**1a. Current branch.** Run `git branch --show-current`. If it matches `^linear-([A-Za-z]+-[0-9]+)-`, extract the issue id, uppercase the team key, set `WORK_DIR=$CURRENT_ROOT`, tell the user in one line, and proceed.

**1b. Registered linear worktrees.** Inspect `git worktree list --porcelain` for paths under `$MAIN_ROOT/.worktrees/`. For each path, read `git -C <path> branch --show-current`; if it matches `^linear-([A-Za-z]+-[0-9]+)-`, capture the issue id as a candidate.

**1c. Resolve candidates.**
- **1 candidate** — use it; set `WORK_DIR` to that worktree path; announce detection.
- **2+ candidates** — use `AskUserQuestion` to pick (label each with issue id + worktree path). Cap listed options at 4; rely on "Other".
- **0 candidates** — stop: `No issue was passed, the current branch isn't a linear-<ISSUE>-* branch, and no matching linear worktree was found. Please pass an issue id (e.g., /clarify-ticket-linear ENG-42).`

3. Normalize `issue_id`: `^[A-Za-z]+-\d+$` → uppercase the team key; URL → extract the first `TEAM-NUM` path segment (fail if none).

## Phase 2: Fetch Linear Issue (read-only)

1. Confirm Linear MCP read tools are present. If not, stop with the setup hint.
2. Fetch the issue by `issue_id` (exact match). Missing or ambiguous → stop.
3. Capture:
   - Title, URL if known
   - Description / body (full text)
   - Current workflow state name (context only)
   - Team id/key, priority, labels, project, cycle (if present)
   - Relations: **blocks**, **blocked by**, related (with their states if returned)
   - Comments (if returned)
   - Acceptance criteria: checklist lines in the body (`- [ ]` / `- [x]`), or a clearly labeled Acceptance Criteria section
4. Derive **slug** from the title: lowercase; non-alphanumerics → `-`; collapse repeats; trim; ~40 chars; fallback `issue`.
5. Compute worktree handles (used only to locate code context):
   - Path: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`
   - Branch: `linear-<issue_id>-<slug>`

## Phase 3: Resolve Code Context (WORK_DIR)

If `WORK_DIR` was not already set by auto-detect:

1. Prefer `$CURRENT_ROOT` when its branch matches `^linear-<issue_id>-.+$`.
2. Else if a registered worktree at `$MAIN_ROOT/.worktrees/<issue_id>-*` exists (exact slug path first, else any registered path starting with `$MAIN_ROOT/.worktrees/<issue_id>-`), use it and tell the user in one line.
3. Otherwise `WORK_DIR=$CURRENT_ROOT`.

If there is no usable repo (not a git repo, or nothing relevant to inspect), run in **text-only mode**: base the analysis on the issue text alone and flag this clearly in the briefing.

All code inspection is read-only and runs against `WORK_DIR`.

## Phase 4: Codebase-Grounded Analysis

Explore read-only (grep/glob/read files; safe read-only shell only — never mutating or destructive commands). Ground every claim in evidence you actually found. Produce four buckets plus a verdict.

### 4.1 Details to confirm
Ambiguities, underspecified requirements, undefined terms, and acceptance criteria that are missing, vague, or untestable. For each, note what is unclear and why it matters.

### 4.2 Risks (code-grounded)
For each risk, give a **severity** (`high` / `medium` / `low`) and **evidence** (`path:line`):
- Files/modules the work will most likely touch, and their blast radius
- Conflicting or divergent patterns already in the code
- Missing prerequisites or dependencies (libraries, migrations, feature flags, config)
- Migration / data / backward-compatibility / breaking-change concerns
- Whether each acceptance criterion is actually feasible against the current code

### 4.3 Dependencies
- Linear relations: **blocked by** (with state — is the blocker done?) and **blocks**
- Code-level prerequisites discovered during analysis

### 4.4 Open questions
What neither the ticket nor the code answers — the questions to take back to the ticket author or resolve before starting.

### 4.5 Readiness verdict
- `ready` — well specified, low or well-understood risk, no open blockers
- `needs-clarification` — one or more open questions or unclear acceptance criteria block a confident start
- `blocked` — an open dependency or hard blocker prevents starting now

## Phase 5: Present the Briefing

Present on screen before any discussion:

```
## Clarification Briefing — <ISSUE-ID>: <title>
**Readiness:** <ready | needs-clarification | blocked>
**Code context:** <main checkout | .worktrees/<issue_id>-<slug> | text-only (no repo)>

### Details to confirm
- ...

### Risks (code-grounded)
- [high] ... — evidence: `src/...:NN`

### Dependencies
- blocked by <ISSUE> (<state>) ...

### Open questions
1. ...
```

## Phase 6: Guided Discussion

Walk the open items with the user one topic at a time (use `AskUserQuestion` for crisp choices, prose otherwise). Batch trivial confirmations; surface the substantive items individually. For each, record the outcome as either:
- **Resolved here** — the user answered; capture the decision.
- **Still open** — needs the ticket author or external input; keep it on the open list.

Keep it efficient — do not force every trivial detail into its own turn.

## Phase 7: Readiness Summary (on-screen only)

Present a final summary. Write nothing to Linear, files, or git:

```
## Clarification Summary — <ISSUE-ID>
**Verdict:** <ready to implement | needs author input | blocked by <...>>

**Resolved**
- ...

**Open questions for the author**
- ... (or "none")

**Key risks to watch during implementation**
- [severity] ...

**Suggested next step**
- /implement-ticket-linear <ISSUE-ID>   (or: resolve the blockers/questions above first)
```

## Safety Rules

- **Always** require Linear MCP read tools; never invent Linear HTTP/API/CLI/browser workarounds. Missing or unresolvable issue → stop.
- **Read-only everywhere.** Never modify the Linear issue (state, comment, description, acceptance criteria). Never edit repo files. Never commit. Never run mutating or destructive shell commands.
- Codebase analysis is read-only (grep/glob/read + safe read-only commands only).
- Do not use `docs/tickets/` as the ticket source.
- Do not invoke mutating cktk skills (`implement-ticket-linear`, `update-ticket-linear`, `commit-ticket`, `commit-push-pr`) — only *suggest* them as next steps.
- Prefer a matching `.worktrees/<issue_id>-*` for code context when present.
- An unrelated dirty working tree does not block analysis, but note it if it muddies code-context reads.
````

- [ ] **Step 2: Verify the frontmatter parses and the description is within the length limit**

Run (same YAML check the repo validator uses):
```bash
RUBYOPT=--disable=gems ruby -e 'require "yaml"; m=YAML.load_file(ARGV[0]); abort("frontmatter not a mapping") unless m.is_a?(Hash); abort("bad name") unless m["name"].is_a?(String) && !m["name"].empty?; abort("bad description") unless m["description"].is_a?(String) && !m["description"].empty?; abort("description too long: #{m["description"].length}") if m["description"].length > 1024; puts "OK name=#{m["name"]} desc_len=#{m["description"].length}"' skills/clarify-ticket-linear/SKILL.md
grep -q '^user-invocable: true$' skills/clarify-ticket-linear/SKILL.md && echo "user-invocable OK"
```
Expected: `OK name=clarify-ticket-linear desc_len=<number ≤ 1024>` followed by `user-invocable OK`.

Note: `scripts/check-codex-skills.sh` will **not** pass yet — the `.agents/skills/` mirror does not exist until Task 2. That is expected; the full validator goes green in Task 2.

- [ ] **Step 3: Commit**

```bash
git add skills/clarify-ticket-linear/SKILL.md
git commit -m "feat(clarify-ticket-linear): add canonical skill

Advisory, read-only Linear skill: fetch an issue, run a codebase-grounded
clarity/risk analysis, brief the user, discuss open items, and end with a
readiness summary.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Create the multi-agent mirror, Codex interface, and symlink

**Files:**
- Create: `.agents/skills/clarify-ticket-linear/SKILL.md`
- Create: `.agents/skills/clarify-ticket-linear/agents/openai.yaml`
- Create: `.agent/skills/clarify-ticket-linear` (symlink → `../../skills/clarify-ticket-linear`)

**Interfaces:**
- Consumes: the skill name and contract from Task 1.
- Produces: `skills/` ↔ `.agents/skills/` parity so `scripts/check-codex-skills.sh` passes, and the `.agent/skills/clarify-ticket-linear` path that `catalog.json` will reference in Task 3.

- [ ] **Step 1: Create the condensed multi-agent variant with this exact content**

````markdown
---
name: "clarify-ticket-linear"
description: "Use when the user explicitly asks to clarify or de-risk a Linear issue before implementing it (not docs/tickets markdown) — fetch the issue, analyze it against the codebase, surface details and risks, discuss interactively, and end with a readiness summary. Strictly read-only: never modifies Linear or git. Prefer explicit invocation with $clarify-ticket-linear. Requires Linear MCP (read-only)."
---

# Clarify a Linear Issue (advisory, read-only)

Fetch a Linear issue and interactively clarify its details and risks against the codebase before implementation. Produce a codebase-grounded briefing, discuss the open items with the user, and end with a readiness summary. **Never** modify Linear or git — this skill is strictly advisory.

**This skill does not use `docs/tickets/`.** Linear is the source of truth.

If the user included an issue id or URL after `$clarify-ticket-linear`, use that issue. Empty args mean auto-detect from branch / worktree only.

## Prerequisites

1. Linear MCP must be available and authenticated (official: `https://mcp.linear.app/mcp` — https://linear.app/docs/mcp).
2. Read-only tools suffice (get/search issue, list relations, get comments). No write tools are needed.
3. If Linear MCP tools are missing, stop with a short setup hint. Do not invent API-key or CLI fallbacks.
4. Use the host's real Linear MCP tool names; discover schemas rather than inventing fields. Team workflow states are not listed or mapped — the readiness verdict is this skill's own.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<issue>` | Clarify that issue. |
| (empty) | Auto-detect the issue from branch / worktree, then clarify. |

`<issue>` is a Linear identifier (`ENG-42`) or a Linear issue URL. Uppercase team keys. No status token; extra tokens → stop.

## Phase 1: Parse & Resolve

1. Resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse args into `issue_ref` (optional).
3. If no `issue_ref`, auto-detect:
   - Current branch `^linear-([A-Za-z]+-\d+)-` → issue id; `WORK_DIR=$CURRENT_ROOT`
   - Else a registered `$MAIN_ROOT/.worktrees/*` whose branch matches `^linear-([A-Za-z]+-\d+)-`
   - 1 candidate → use it; 2+ → ask; 0 → stop and request an id
4. Normalize to `issue_id` (TEAM-NUM uppercase, or extract from URL). Unknown extra tokens → stop.

## Phase 2: Fetch Linear Issue (read-only)

1. Fetch by `issue_id` via Linear MCP. Exact match only; stop if missing or ambiguous.
2. Capture title, description, current state (context only), team, labels/project/priority, relations (blocks / blocked-by + states), comments, and checklist acceptance criteria.
3. Derive `slug` (lowercase, non-alphanumerics → `-`, collapse, trim, ~40 chars; fallback `issue`).
4. Worktree handles: `$MAIN_ROOT/.worktrees/<issue_id>-<slug>`, branch `linear-<issue_id>-<slug>`.

## Phase 3: Code Context

1. Prefer `$CURRENT_ROOT` when its branch is `linear-<issue_id>-*`.
2. Else a registered worktree at `$MAIN_ROOT/.worktrees/<issue_id>-*`.
3. Else `WORK_DIR=$CURRENT_ROOT`. No usable repo → text-only mode (flag it).

## Phase 4: Codebase-Grounded Analysis

Read-only exploration only (grep/glob/read + safe read-only commands). Produce four buckets + a verdict:
- **Details to confirm** — ambiguities, underspecified requirements, missing/untestable acceptance criteria.
- **Risks** — files/modules touched, conflicting patterns, missing prerequisites, migration/breaking-change/blast-radius, acceptance-criteria feasibility. Tag each with severity (`high`/`medium`/`low`) + evidence (`path:line`).
- **Dependencies** — Linear relations (+ states) and code prerequisites.
- **Open questions** — what neither the ticket nor the code answers.
- **Verdict** — `ready` / `needs-clarification` / `blocked`.

## Phase 5: Briefing

Present the four buckets + verdict + code-context source on screen.

## Phase 6: Guided Discussion

Walk open items one topic at a time (AskUserQuestion / prose). Record each as resolved-here or still-open-for-author. Batch trivial confirmations.

## Phase 7: Readiness Summary (on-screen only)

Verdict, resolved decisions, open questions for the author, key risks to watch, and a suggested next step (`$implement-ticket-linear <issue>` or resolve blockers first). No writes anywhere.

## Safety Rules

- Require Linear MCP (read); fail closed. Missing/unresolvable issue → stop.
- Strictly read-only: never modify Linear (state/comment/description/AC), never edit files, never commit, never run mutating/destructive commands.
- Do not use `docs/tickets/` as the source.
- Do not call `$implement-ticket-linear`, `$update-ticket-linear`, `$commit-ticket`, or `$commit-push-pr` — only suggest them.
- Prefer matching linear worktrees for code context when present.
````

- [ ] **Step 2: Create the Codex interface file with this exact content**

`.agents/skills/clarify-ticket-linear/agents/openai.yaml`:

```yaml
interface:
  display_name: "Clarify Ticket (Linear)"
  short_description: "Fetch a Linear issue and clarify its details and risks before implementation (read-only)"
  default_prompt: "Fetch the Linear issue via MCP, analyze it against the codebase, surface details to confirm and code-grounded risks, discuss the open items interactively, and end with a readiness summary. Strictly read-only — never modify Linear or git."

policy:
  allow_implicit_invocation: false
```

- [ ] **Step 3: Create the symlink in the `.agent/skills/` tree**

```bash
ln -s ../../skills/clarify-ticket-linear .agent/skills/clarify-ticket-linear
```

- [ ] **Step 4: Verify the symlink resolves and the validator passes**

```bash
ls -l .agent/skills/clarify-ticket-linear
test -e .agent/skills/clarify-ticket-linear/SKILL.md && echo "symlink resolves OK"
bash scripts/check-codex-skills.sh
```
Expected: the `ls -l` line ends with `-> ../../skills/clarify-ticket-linear`; then `symlink resolves OK`; then the validator prints `Validated <N> Codex skill(s).` and exits 0 (N is one greater than before this task).

- [ ] **Step 5: Commit**

```bash
git add .agents/skills/clarify-ticket-linear .agent/skills/clarify-ticket-linear
git commit -m "feat(clarify-ticket-linear): mirror to multi-agent tree + symlink

Condensed .agents variant, Codex openai.yaml (explicit-only), and the
.agent symlink so tree parity passes scripts/check-codex-skills.sh.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Register in catalog, plugin keywords, and README

**Files:**
- Modify: `catalog.json`
- Modify: `.claude-plugin/plugin.json`
- Modify: `README.md`

**Interfaces:**
- Consumes: the skill name, the `.agent/skills/clarify-ticket-linear` path (Task 2), and the description text (Task 1).
- Produces: user-facing registration/discovery. Nothing later depends on it.

- [ ] **Step 1: Add the `catalog.json` entry immediately before `implement-ticket-linear`**

Edit `catalog.json` — replace this block:
```json
    {
      "name": "implement-ticket-linear",
      "path": ".agent/skills/implement-ticket-linear",
      "description": "Implement a Linear issue with code review, optionally in an isolated worktree (requires Linear MCP)"
    },
```
with:
```json
    {
      "name": "clarify-ticket-linear",
      "path": ".agent/skills/clarify-ticket-linear",
      "description": "Fetch a Linear issue and interactively clarify its details and risks against the codebase before implementation — read-only (requires Linear MCP)"
    },
    {
      "name": "implement-ticket-linear",
      "path": ".agent/skills/implement-ticket-linear",
      "description": "Implement a Linear issue with code review, optionally in an isolated worktree (requires Linear MCP)"
    },
```

- [ ] **Step 2: Add the keyword in `.claude-plugin/plugin.json`**

Edit `.claude-plugin/plugin.json` — in the `keywords` array, replace:
```
"implement-ticket", "implement-ticket-linear"
```
with:
```
"implement-ticket", "clarify-ticket-linear", "implement-ticket-linear"
```

- [ ] **Step 3: Add the README description bullet**

Edit `README.md` — replace:
```
- `implement-ticket-linear` — implement a Linear issue (via Linear MCP) with code review and optional worktree; does not use `docs/tickets/` and does not write back to Linear
```
with:
```
- `clarify-ticket-linear` — fetch a Linear issue (via Linear MCP) and interactively clarify its details and risks against the codebase before implementation; read-only, does not use `docs/tickets/`, and never modifies Linear or git
- `implement-ticket-linear` — implement a Linear issue (via Linear MCP) with code review and optional worktree; does not use `docs/tickets/` and does not write back to Linear
```

- [ ] **Step 4: Bump the installer-count wording**

Edit `README.md` — replace:
```
Use one installer request with all twenty-two installer-compatible skill paths:
```
with:
```
Use one installer request with all twenty-three installer-compatible skill paths:
```

- [ ] **Step 5: Add to the install-all path list**

Edit `README.md` — replace:
```
.agents/skills/implement-ticket-linear
.agents/skills/review-ticket
```
with:
```
.agents/skills/clarify-ticket-linear
.agents/skills/implement-ticket-linear
.agents/skills/review-ticket
```

- [ ] **Step 6: Add the per-skill installer command**

Edit `README.md` — replace:
```
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/implement-ticket-linear
```
with:
```
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/clarify-ticket-linear
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/implement-ticket-linear
```

- [ ] **Step 7: Add the `$`-prefixed usage example**

Edit `README.md` — replace:
```
$implement-ticket-linear ENG-42
$implement-ticket-linear ENG-42 worktree
```
with:
```
$clarify-ticket-linear ENG-42
$implement-ticket-linear ENG-42
$implement-ticket-linear ENG-42 worktree
```

- [ ] **Step 8: Add `clarify-ticket-linear` to the Codex explicit-only policy sentence**

Edit `README.md` — replace:
```
`create-tickets`, `implement-ticket`, `implement-ticket-linear`, `update-ticket`, `update-ticket-linear`
```
with:
```
`create-tickets`, `implement-ticket`, `clarify-ticket-linear`, `implement-ticket-linear`, `update-ticket`, `update-ticket-linear`
```

- [ ] **Step 9: Add the `/`-prefixed usage example**

Edit `README.md` — replace:
```
/implement-ticket-linear ENG-42              # Implement a Linear issue (requires Linear MCP)
```
with:
```
/clarify-ticket-linear ENG-42                # Fetch, analyze vs. code, discuss risks (read-only, Linear MCP)
/implement-ticket-linear ENG-42              # Implement a Linear issue (requires Linear MCP)
```

- [ ] **Step 10: Add to the `for s in …` install loop**

Edit `README.md` — replace:
```
for s in create-tickets implement-ticket implement-ticket-linear review-ticket update-ticket update-ticket-linear commit-ticket commit-push-pr create-worktree merge-worktree feature-catalog cktk-upgrade codex-handoff grok-handoff opencode-handoff takeover readme-builder design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign cinematic-design-system gen-image-codex gen-image-agy; do
```
with:
```
for s in create-tickets implement-ticket clarify-ticket-linear implement-ticket-linear review-ticket update-ticket update-ticket-linear commit-ticket commit-push-pr create-worktree merge-worktree feature-catalog cktk-upgrade codex-handoff grok-handoff opencode-handoff takeover readme-builder design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign cinematic-design-system gen-image-codex gen-image-agy; do
```

- [ ] **Step 11: Verify JSON validity, README coverage, and the validator**

```bash
python3 -m json.tool catalog.json > /dev/null && echo "catalog.json valid"
python3 -m json.tool .claude-plugin/plugin.json > /dev/null && echo "plugin.json valid"
echo "README clarify-ticket-linear mentions: $(grep -c 'clarify-ticket-linear' README.md) (expect 7)"
grep -q 'twenty-three installer-compatible' README.md && echo "count wording OK"
bash scripts/check-codex-skills.sh
```
Expected: `catalog.json valid`, `plugin.json valid`, `README clarify-ticket-linear mentions: 7 (expect 7)`, `count wording OK`, and the validator prints `Validated <N> Codex skill(s).` (exit 0). If the mention count differs from 7, one of Steps 3–10 was missed or duplicated — reconcile before committing.

- [ ] **Step 12: Commit**

```bash
git add catalog.json .claude-plugin/plugin.json README.md
git commit -m "feat(clarify-ticket-linear): register in catalog, keywords, and README

Catalog entry, plugin keyword, and all README lists/examples placed
immediately before implement-ticket-linear.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Manual behavioral verification (acceptance gate)

This is the spec's behavioral test. It requires **Linear MCP configured** and access to a **real Linear issue**. If neither is available in this environment, mark the task blocked and report that structural validation (Tasks 1–3) passed but behavioral verification is pending; do not fake it.

**Files:** none (verification only).

- [ ] **Step 1: Invoke the skill against a real issue and observe**

Run the skill (replace `ENG-42` with a real issue id you have access to):
```
/clarify-ticket-linear ENG-42
```
Confirm each of the following:
- The issue is fetched via Linear MCP (title/description/relations shown).
- A **Clarification Briefing** appears with the four buckets (Details to confirm, Risks with severity + `path:line` evidence, Dependencies, Open questions) and a `**Readiness:**` verdict of `ready` / `needs-clarification` / `blocked`, plus a `**Code context:**` line.
- The **guided discussion** engages you on the open items.
- A **Clarification Summary** ends the run with a suggested next step.

- [ ] **Step 2: Confirm zero side effects**

```bash
git status --porcelain
```
Expected: empty (no file changes from the run). Also confirm in Linear that the issue's state, description, and comments are **unchanged** — the skill must not have written anything.

- [ ] **Step 3: Verify auto-detect**

On a branch named like `linear-eng-42-some-slug` (or from a matching `.worktrees/` linear worktree), run `/clarify-ticket-linear` with **no argument** and confirm it auto-detects the issue id and reports which code context it used.

- [ ] **Step 4: Verify the missing-MCP guardrail (if feasible)**

In an environment without Linear MCP, run `/clarify-ticket-linear ENG-42` and confirm it stops with a short setup hint and does **not** attempt any API/CLI/browser fallback.

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-07-23-clarify-ticket-linear-design.md`):
- Identity & contract (name, `user-invocable`, advisory/read-only) → Task 1 frontmatter + body + Safety Rules.
- Prerequisites (Linear MCP read-only, no fallbacks, no state mapping) → Task 1 Prerequisites; enforced in Task 4 Step 4.
- Argument grammar (issue / empty→auto-detect, no status token) → Task 1 Phase 1; verified Task 4 Step 3.
- Phases 1–7 (parse, fetch, code context, analysis, briefing, discussion, summary) → Task 1 body; verified Task 4 Steps 1–2.
- Error handling & safety → Task 1 Safety Rules; verified Task 4 Steps 2 & 4.
- Packaging (canonical, symlink, `.agents` variant + openai.yaml, catalog/plugin/README) → Tasks 2 & 3.
- Validation (validator, JSON lint, manual dry-run, auto-detect) → Task 2 Step 4, Task 3 Step 11, Task 4.
- Out-of-scope (no write-back, no prep-note file, no `docs/tickets/`) → honored throughout; Safety Rules forbid writes.

**Placeholder scan:** none — all SKILL.md, YAML, JSON, and README content is literal; every verification step has an exact command and expected output.

**Type/name consistency:** the skill name `clarify-ticket-linear` is identical across frontmatter (both trees), `openai.yaml` display name aside, the symlink, `catalog.json`, `plugin.json`, and all README entries. Placement rule ("immediately before `implement-ticket-linear`") is applied uniformly. Verdict vocabulary (`ready`/`needs-clarification`/`blocked`) matches between the canonical and condensed variants and the spec.
