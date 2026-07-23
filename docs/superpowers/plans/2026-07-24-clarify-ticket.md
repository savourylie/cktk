# clarify-ticket Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new cktk skill, `clarify-ticket`, the markdown-ticket twin of `clarify-ticket-linear`: it reads a ticket from `docs/tickets/`, runs a codebase-grounded clarity/risk analysis, briefs the user, discusses open items interactively, and ends with a readiness summary — strictly advisory and read-only.

**Architecture:** A documentation-artifact skill (Markdown `SKILL.md` prose + JSON/YAML registration), not runtime code. It ships across the same three trees as its Linear twin: canonical (`skills/`), multi-agent/Codex (`.agents/skills/` + `agents/openai.yaml`), and a symlink (`.agent/skills/`). Verification per task is structural — the repo validator `scripts/check-codex-skills.sh` (enforces `skills/` ↔ `.agents/skills/` parity + valid `openai.yaml`) plus JSON validity — and the behavioral acceptance test (Task 4) is a local dry-run against a `docs/tickets/` fixture (no external service, unlike the Linear twin).

**Tech Stack:** Markdown (SKILL.md), JSON (`catalog.json`, `.claude-plugin/plugin.json`), YAML (`agents/openai.yaml`), Bash validator (`scripts/check-codex-skills.sh`). No runtime dependency.

## Global Constraints

Copied verbatim from the spec (`docs/superpowers/specs/2026-07-24-clarify-ticket-design.md`).

- **Skill name:** `clarify-ticket`. In every ordered list (catalog, keywords, README bullets, install lists, usage examples, the install `for` loop), place it **immediately before `clarify-ticket-linear`**, keeping the base/`-linear` pair adjacent.
- **Read-only guarantee:** never edits ticket files, `INDEX.md`, or any other repo file; never changes a ticket's status or acceptance-criteria checkboxes; never commits; never runs mutating/destructive shell.
- **No external service:** source of truth is `docs/tickets/`. No Linear, no MCP. If `docs/tickets/` is missing, stop with a hint pointing to `clarify-ticket-linear` for Linear issues.
- **Frontmatter:** canonical `skills/.../SKILL.md` has `name`, a non-empty `description` ≤ 1024 chars, and `user-invocable: true`. The `.agents/.../SKILL.md` variant has `name` + non-empty `description` ≤ 1024 chars.
- **Tree parity (validator-enforced):** matching dirs under `skills/` and `.agents/skills/`, each with `SKILL.md`; the `.agents` copy also has `agents/openai.yaml` (valid YAML, `allow_implicit_invocation: false`).
- **Readiness verdict** vocabulary: `ready` / `needs-clarification` / `blocked`.
- **Four parity deltas vs clarify-ticket-linear** (everything else mirrors it): (1) local `docs/tickets/` files instead of Linear MCP; (2) an INDEX.md `pending` fallback as auto-detect step 3; (3) reverse-dependency grep (`Requires: #NNN`) instead of Linear relations; (4) read `docs/PRD.md` + design source and cross-check the ticket against them.

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `skills/clarify-ticket/SKILL.md` | Canonical, full skill instructions (Claude tree) | 1 |
| `.agents/skills/clarify-ticket/SKILL.md` | Condensed multi-agent/Codex variant | 2 |
| `.agents/skills/clarify-ticket/agents/openai.yaml` | Codex interface + explicit-only policy | 2 |
| `.agent/skills/clarify-ticket` | Symlink → `../../skills/clarify-ticket` | 2 |
| `catalog.json` | Skill registry entry | 3 |
| `.claude-plugin/plugin.json` | Keyword registration | 3 |
| `README.md` | Docs: bullet, install lists, usage examples, policy list, install loop | 3 |

---

## Task 1: Author the canonical SKILL.md

**Files:**
- Create: `skills/clarify-ticket/SKILL.md`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the canonical skill contract. Later tasks rely on the exact name `clarify-ticket`, the frontmatter `description`, and `user-invocable: true`.

- [ ] **Step 1: Create the canonical SKILL.md with this exact content**

````markdown
---
name: clarify-ticket
description: "Fetch a ticket from docs/tickets/ and interactively clarify its details and risks against the codebase before implementation — strictly read-only, never edits tickets, INDEX.md, or git. Produces a codebase-grounded briefing, a guided discussion, and a readiness summary. The markdown-ticket twin of clarify-ticket-linear. Triggers on: /clarify-ticket, /clarify-ticket 007, /clarify-ticket TICKET-007, clarify ticket 7, de-risk ticket before implementing, discuss ticket details and risks"
user-invocable: true
---

**Argument:** `$ARGUMENTS`

You are a pre-implementation ticket clarifier. Your job is to read a ticket from `docs/tickets/`, analyze it against the actual codebase, surface details that need confirming and risks worth knowing, discuss the open items interactively with the user, and end with a readiness summary. Follow each phase precisely.

**This skill is strictly advisory and read-only.** It never edits ticket files, `INDEX.md`, or any other repo file; never changes a ticket's status or acceptance-criteria checkboxes; never commits. The ticket tracker in `docs/tickets/` is the source of truth. This is the markdown-ticket twin of `/clarify-ticket-linear` — it has **no Linear involvement**.

## Prerequisites

1. A git repository containing a `docs/tickets/` directory. No MCP or external service is required.
2. If `docs/tickets/` does not exist, stop with a short hint: this repo has no markdown ticket tracker; for Linear issues use `/clarify-ticket-linear`.

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Clarify that ticket. |
| (empty) | Auto-detect the ticket, then clarify. |

`<ticket>` accepts `TICKET-007`, `007`, `#7`, or `7`; normalize to a 3-digit zero-padded `NNN`.

**Not accepted:** a status token, multi-ticket batches, or any write/commit flags. Extra tokens beyond a single ticket → stop with an unrecognized-arguments error.

## Phase 1: Parse Arguments & Resolve Handles

1. Confirm you're inside a git repo, then compute:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse `$ARGUMENTS`. Split on whitespace.
   - If the first token is present, treat it as the ticket ref and normalize to `NNN` (`7`, `007`, `#7`, `TICKET-007` → `007`). No further tokens are expected.
   - If `$ARGUMENTS` is empty, run **auto-detect** (below).
   - If a first token is present but isn't a ticket ref, or there are extra tokens → stop with an unrecognized-arguments error.

### Auto-detect (only when `$ARGUMENTS` is empty)

**1a. Current branch.** Run `git branch --show-current`. If it matches `^ticket-(\d{3})-.+$`, extract `NNN`, set `WORK_DIR=$CURRENT_ROOT`, tell the user in one line, and proceed.

**1b. Registered ticket worktrees.** Inspect `git worktree list --porcelain` for paths under `$MAIN_ROOT/.worktrees/`; for each, read `git -C <path> branch --show-current` and capture `NNN` when it matches `^ticket-(\d{3})-.+$`.
- **1 candidate** — use it; set `WORK_DIR` to that path; announce detection.
- **2+ candidates** — pick via `AskUserQuestion` (label `TICKET-NNN — .worktrees/NNN-<slug>`; cap 4 options, rely on "Other").
- **0 candidates** — continue to 1c.

**1c. INDEX.md pending fallback.** Read `$MAIN_ROOT/docs/tickets/INDEX.md` and collect every ticket whose Status column contains `` `pending` `` (backtick-wrapped).
- **1+ candidates** — pick via `AskUserQuestion` (options labeled `TICKET-NNN — <title>`; if more than 4, list the 4 lowest-numbered — the natural next work — and rely on "Other").
- **0 candidates** — stop: `No ticket number was passed, the current branch isn't a ticket-NNN-<slug> branch, no ticket worktree exists, and no tickets are marked pending in INDEX.md. Please pass a ticket number (e.g., /clarify-ticket 007).`

3. Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match → stop (`TICKET-NNN not found in docs/tickets/`). Multiple matches → stop (ambiguity). Slug = filename minus the `NNN-` prefix and `.md` suffix.

## Phase 2: Read the Ticket (read-only)

Capture from the ticket file:
- Title (from the `# [TICKET-NNN] Title` header) and full body
- `## Status` current value (context only)
- `## Acceptance Criteria` checklist lines (`- [ ]` / `- [x]`)
- `- Requires:` dependencies and their `✅` markers (blocked-by)
- Implementation Notes / Testing sections if present

Also:
- Read the ticket's row in `$MAIN_ROOT/docs/tickets/INDEX.md` (status, depends-on, notes).
- **Reverse dependencies:** grep all files in `$MAIN_ROOT/docs/tickets/` for `#NNN` on lines containing `Requires:` — these are the tickets this one blocks.
- Compute worktree handles: path `$MAIN_ROOT/.worktrees/NNN-<slug>`, branch `ticket-NNN-<slug>`.

## Phase 3: Resolve Code Context (WORK_DIR)

If `WORK_DIR` was not already set by auto-detect:
1. Prefer `$CURRENT_ROOT` when its branch matches `^ticket-NNN-.+$`.
2. Else a registered worktree at `$MAIN_ROOT/.worktrees/NNN-<slug>` (announce in one line).
3. Otherwise `WORK_DIR=$CURRENT_ROOT`.

All code inspection is read-only and runs against `WORK_DIR`.

## Phase 4: Codebase-Grounded Analysis

Explore read-only (grep/glob/read files; safe read-only shell only — never mutating or destructive commands). Ground every claim in evidence you actually found. Produce four buckets plus a verdict.

**Additional context inputs:** when present, also read `$WORK_DIR/docs/PRD.md` and the design source — prefer `$WORK_DIR/docs/DESIGN.md`, else `$WORK_DIR/docs/design/DESIGN.md`, else a `design-system/` folder (commonly `$WORK_DIR/design-system/` or `$WORK_DIR/docs/design-system/`) — and check the ticket against them. Conflicts between the ticket and the PRD/design belong in "Details to confirm" or "Risks" with file references.

### 4.1 Details to confirm
Ambiguities, underspecified requirements, undefined terms, and acceptance criteria that are missing, vague, or untestable — including anything that contradicts `docs/PRD.md` or the design source.

### 4.2 Risks (code-grounded)
For each risk, give a **severity** (`high` / `medium` / `low`) and **evidence** (`path:line`):
- Files/modules the work will most likely touch, and their blast radius
- Conflicting or divergent patterns already in the code
- Missing prerequisites or dependencies (libraries, migrations, feature flags, config)
- Migration / data / backward-compatibility / breaking-change concerns
- Whether each acceptance criterion is actually feasible against the current code

### 4.3 Dependencies
- `- Requires:` dependencies (with `✅` state and each dependency ticket's current status from INDEX.md — is the blocker `done`?)
- Reverse dependencies: the tickets this one blocks
- Code-level prerequisites discovered during analysis

### 4.4 Open questions
What neither the ticket nor the code answers — the questions to resolve before starting.

### 4.5 Readiness verdict
- `ready` — well specified, low or well-understood risk, no unmet dependencies
- `needs-clarification` — one or more open questions or unclear acceptance criteria block a confident start
- `blocked` — a `Requires:` dependency is unsatisfied (no `✅` and the dependency ticket is not `done`), or another hard blocker prevents starting now

## Phase 5: Present the Briefing

Present on screen before any discussion:

```
## Clarification Briefing — TICKET-NNN: <title>
**Readiness:** <ready | needs-clarification | blocked>
**Code context:** <main checkout | .worktrees/NNN-<slug>>

### Details to confirm
- ...

### Risks (code-grounded)
- [high] ... — evidence: `src/...:NN`

### Dependencies
- Requires #NNN (<status>, ✅ / not satisfied) ...
- Blocks #MMM ...

### Open questions
1. ...
```

## Phase 6: Guided Discussion

Walk the open items with the user one topic at a time (use `AskUserQuestion` for crisp choices, prose otherwise). Batch trivial confirmations; surface the substantive items individually. Record each as **resolved here** (the user answered) or **still open** (needs external input).

## Phase 7: Readiness Summary (on-screen only)

Present a final summary. Write nothing to any file or git:

```
## Clarification Summary — TICKET-NNN
**Verdict:** <ready to implement | needs author input | blocked by <...>>

**Resolved**
- ...

**Open questions for the author**
- ... (or "none")

**Key risks to watch during implementation**
- [severity] ...

**Suggested next step**
- /implement-ticket NNN            (optionally: /implement-ticket NNN worktree)
  (or: resolve the blockers/questions above first)
```

## Safety Rules

- **Read-only everywhere.** Never edit ticket files or `INDEX.md`, never change a ticket's status or acceptance-criteria checkboxes, never edit any other repo file, never commit, never run mutating or destructive shell commands.
- Codebase analysis is read-only (grep/glob/read + safe read-only commands only).
- Missing `docs/tickets/` or unresolvable / ambiguous ticket → stop.
- Do not invoke mutating cktk skills (`implement-ticket`, `update-ticket`, `commit-ticket`, `commit-push-pr`, `create-worktree`) — only *suggest* them as next steps.
- No Linear involvement of any kind — that is `/clarify-ticket-linear`.
- Prefer a matching `.worktrees/NNN-<slug>` for code context when present.
- An unrelated dirty working tree does not block analysis, but note it if it muddies code-context reads.
````

- [ ] **Step 2: Verify the frontmatter parses and the description is within the length limit**

Run (same YAML check the repo validator uses):
```bash
RUBYOPT=--disable=gems ruby -e 'require "yaml"; m=YAML.load_file(ARGV[0]); abort("frontmatter not a mapping") unless m.is_a?(Hash); abort("bad name") unless m["name"].is_a?(String) && !m["name"].empty?; abort("bad description") unless m["description"].is_a?(String) && !m["description"].empty?; abort("description too long: #{m["description"].length}") if m["description"].length > 1024; puts "OK name=#{m["name"]} desc_len=#{m["description"].length}"' skills/clarify-ticket/SKILL.md
grep -q '^user-invocable: true$' skills/clarify-ticket/SKILL.md && echo "user-invocable OK"
```
Expected: `OK name=clarify-ticket desc_len=<number ≤ 1024>` followed by `user-invocable OK`.

Note: `scripts/check-codex-skills.sh` will **not** pass yet — the `.agents/skills/` mirror does not exist until Task 2. That is expected; the full validator goes green in Task 2.

- [ ] **Step 3: Commit**

```bash
git add skills/clarify-ticket/SKILL.md
git commit -m "feat(clarify-ticket): add canonical skill

Advisory, read-only markdown-ticket clarifier: read a docs/tickets/ ticket,
run a codebase-grounded clarity/risk analysis, brief the user, discuss open
items, and end with a readiness summary. The markdown twin of
clarify-ticket-linear.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Create the multi-agent mirror, Codex interface, and symlink

**Files:**
- Create: `.agents/skills/clarify-ticket/SKILL.md`
- Create: `.agents/skills/clarify-ticket/agents/openai.yaml`
- Create: `.agent/skills/clarify-ticket` (symlink → `../../skills/clarify-ticket`)

**Interfaces:**
- Consumes: the skill name and contract from Task 1.
- Produces: `skills/` ↔ `.agents/skills/` parity so `scripts/check-codex-skills.sh` passes, and the `.agent/skills/clarify-ticket` path that `catalog.json` references in Task 3.

- [ ] **Step 1: Create the condensed multi-agent variant with this exact content**

````markdown
---
name: "clarify-ticket"
description: "Use when the user explicitly asks to clarify or de-risk a markdown ticket from docs/tickets/ before implementing it (not a Linear issue) — read the ticket, analyze it against the codebase, surface details and risks, discuss interactively, and end with a readiness summary. Strictly read-only: never edits tickets, INDEX.md, or git. Prefer explicit invocation with $clarify-ticket. The markdown-ticket twin of clarify-ticket-linear."
---

# Clarify a Ticket (advisory, read-only)

Read a ticket from `docs/tickets/` and interactively clarify its details and risks against the codebase before implementation. Produce a codebase-grounded briefing, discuss the open items with the user, and end with a readiness summary. **Never** edit tickets, `INDEX.md`, or git — this skill is strictly advisory.

**Source of truth is `docs/tickets/`.** No Linear, no MCP. For Linear issues use `$clarify-ticket-linear`.

If the user included a ticket number after `$clarify-ticket`, use it. Empty args mean auto-detect.

## Prerequisites

1. A git repo containing `docs/tickets/`. No MCP or external service required.
2. If `docs/tickets/` is missing, stop with a short hint (use `$clarify-ticket-linear` for Linear issues).

## Argument grammar

| Invocation | Meaning |
| --- | --- |
| `<ticket>` | Clarify that ticket. |
| (empty) | Auto-detect the ticket, then clarify. |

`<ticket>` is `TICKET-007`, `007`, `#7`, or `7`; normalize to 3-digit `NNN`. No status token; extra tokens → stop.

## Phase 1: Parse & Resolve

1. Resolve:
   ```
   MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   CURRENT_ROOT=$(git rev-parse --show-toplevel)
   ```
2. Parse args into a ticket ref (normalize to `NNN`).
3. If no ticket ref, auto-detect:
   - Current branch `^ticket-(\d{3})-` → `NNN`; `WORK_DIR=$CURRENT_ROOT`
   - Else a registered `$MAIN_ROOT/.worktrees/*` whose branch matches `^ticket-(\d{3})-` (1 → use; 2+ → ask; 0 → next)
   - Else INDEX.md fallback: collect tickets marked `` `pending` ``; 1+ → ask (4 lowest-numbered + "Other"); 0 → stop and request a number
4. Glob `$MAIN_ROOT/docs/tickets/NNN-*.md`. No match → stop; multiple → stop. Slug = filename minus `NNN-` and `.md`. Extra tokens → stop.

## Phase 2: Read the Ticket (read-only)

Capture title, `## Status` (context only), body, `## Acceptance Criteria` checkboxes, `- Requires:` deps (+ `✅` markers), Implementation Notes / Testing. Also read the ticket's INDEX.md row, and grep `docs/tickets/` for `#NNN` on `Requires:` lines (reverse deps — the tickets this one blocks). Worktree handles: `$MAIN_ROOT/.worktrees/NNN-<slug>`, branch `ticket-NNN-<slug>`.

## Phase 3: Code Context

1. Prefer `$CURRENT_ROOT` when its branch is `ticket-NNN-*`.
2. Else a registered worktree at `$MAIN_ROOT/.worktrees/NNN-<slug>`.
3. Else `WORK_DIR=$CURRENT_ROOT`.

## Phase 4: Codebase-Grounded Analysis

Read-only exploration only (grep/glob/read + safe read-only commands). When present, also read `$WORK_DIR/docs/PRD.md` and the design source (`docs/DESIGN.md` → `docs/design/DESIGN.md` → `design-system/`) and check the ticket against them. Produce four buckets + a verdict:
- **Details to confirm** — ambiguities, underspecified requirements, missing/untestable acceptance criteria, ticket-vs-PRD/design conflicts.
- **Risks** — files/modules touched, conflicting patterns, missing prerequisites, migration/breaking-change/blast-radius, acceptance-criteria feasibility. Tag each with severity (`high`/`medium`/`low`) + evidence (`path:line`).
- **Dependencies** — `Requires:` deps (+ `✅` state and dependency status), reverse deps (tickets this one blocks), code prerequisites.
- **Open questions** — what neither the ticket nor the code answers.
- **Verdict** — `ready` / `needs-clarification` / `blocked` (an unsatisfied `Requires:` dep → `blocked`).

## Phase 5: Briefing

Present the four buckets + verdict + code-context source on screen.

## Phase 6: Guided Discussion

Walk open items one topic at a time (AskUserQuestion / prose). Record each as resolved-here or still-open. Batch trivial confirmations.

## Phase 7: Readiness Summary (on-screen only)

Verdict, resolved decisions, open questions for the author, key risks to watch, and a suggested next step (`$implement-ticket NNN`, optionally `worktree`, or resolve blockers first). No writes anywhere.

## Safety Rules

- Strictly read-only: never edit tickets / `INDEX.md`, never change status or acceptance-criteria checkboxes, never edit files, never commit, never run mutating/destructive commands.
- Missing `docs/tickets/` or unresolvable ticket → stop.
- Do not call `$implement-ticket`, `$update-ticket`, `$commit-ticket`, `$commit-push-pr`, or `$create-worktree` — only suggest them.
- No Linear involvement — that is `$clarify-ticket-linear`.
- Prefer matching ticket worktrees for code context when present.
````

- [ ] **Step 2: Create the Codex interface file with this exact content**

`.agents/skills/clarify-ticket/agents/openai.yaml`:

```yaml
interface:
  display_name: "Clarify Ticket"
  short_description: "Read a docs/tickets/ ticket and clarify its details and risks before implementation (read-only)"
  default_prompt: "Read the ticket from docs/tickets/, analyze it against the codebase (and PRD/design source when present), surface details to confirm and code-grounded risks, discuss the open items interactively, and end with a readiness summary. Strictly read-only — never edit tickets, INDEX.md, or git."

policy:
  allow_implicit_invocation: false
```

- [ ] **Step 3: Create the symlink in the `.agent/skills/` tree**

```bash
ln -s ../../skills/clarify-ticket .agent/skills/clarify-ticket
```

- [ ] **Step 4: Verify the symlink resolves and the validator passes**

```bash
ls -l .agent/skills/clarify-ticket
test -e .agent/skills/clarify-ticket/SKILL.md && echo "symlink resolves OK"
bash scripts/check-codex-skills.sh
```
Expected: the `ls -l` line ends with `-> ../../skills/clarify-ticket`; then `symlink resolves OK`; then `Validated 28 Codex skill(s).` (exit 0).

- [ ] **Step 5: Commit**

```bash
git add .agents/skills/clarify-ticket .agent/skills/clarify-ticket
git commit -m "feat(clarify-ticket): mirror to multi-agent tree + symlink

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
- Consumes: the skill name, the `.agent/skills/clarify-ticket` path (Task 2), and the description text (Task 1).
- Produces: user-facing registration/discovery. Nothing later depends on it.

The governing rule: everywhere, insert `clarify-ticket` **immediately before `clarify-ticket-linear`**.

- [ ] **Step 1: Add the `catalog.json` entry immediately before `clarify-ticket-linear`**

Edit `catalog.json` — replace this block:
```json
    {
      "name": "clarify-ticket-linear",
      "path": ".agent/skills/clarify-ticket-linear",
      "description": "Fetch a Linear issue and interactively clarify its details and risks against the codebase before implementation — read-only (requires Linear MCP)"
    },
```
with:
```json
    {
      "name": "clarify-ticket",
      "path": ".agent/skills/clarify-ticket",
      "description": "Read a docs/tickets/ ticket and interactively clarify its details and risks against the codebase before implementation — read-only (markdown twin of clarify-ticket-linear)"
    },
    {
      "name": "clarify-ticket-linear",
      "path": ".agent/skills/clarify-ticket-linear",
      "description": "Fetch a Linear issue and interactively clarify its details and risks against the codebase before implementation — read-only (requires Linear MCP)"
    },
```

- [ ] **Step 2: Add the keyword in `.claude-plugin/plugin.json`**

Edit `.claude-plugin/plugin.json` — in the `keywords` array, replace:
```
"implement-ticket", "clarify-ticket-linear"
```
with:
```
"implement-ticket", "clarify-ticket", "clarify-ticket-linear"
```

- [ ] **Step 3: Add the README description bullet**

Edit `README.md` — replace:
```
- `clarify-ticket-linear` — fetch a Linear issue (via Linear MCP) and interactively clarify its details and risks against the codebase before implementation; read-only, does not use `docs/tickets/`, and never modifies Linear or git
```
with:
```
- `clarify-ticket` — read a ticket from `docs/tickets/` and interactively clarify its details and risks against the codebase before implementation; read-only, never edits tickets, `INDEX.md`, or git (the markdown-ticket twin of `clarify-ticket-linear`)
- `clarify-ticket-linear` — fetch a Linear issue (via Linear MCP) and interactively clarify its details and risks against the codebase before implementation; read-only, does not use `docs/tickets/`, and never modifies Linear or git
```

- [ ] **Step 4: Bump the installer-count wording**

Edit `README.md` — replace:
```
Use one installer request with all twenty-three installer-compatible skill paths:
```
with:
```
Use one installer request with all twenty-four installer-compatible skill paths:
```

- [ ] **Step 5: Add to the install-all path list**

Edit `README.md` — replace:
```
.agents/skills/clarify-ticket-linear
```
with:
```
.agents/skills/clarify-ticket
.agents/skills/clarify-ticket-linear
```

- [ ] **Step 6: Add the per-skill installer command**

Edit `README.md` — replace:
```
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/clarify-ticket-linear
```
with:
```
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/clarify-ticket
$skill-installer install https://github.com/savourylie/cktk/tree/main/.agents/skills/clarify-ticket-linear
```

- [ ] **Step 7: Add the `$`-prefixed usage example**

Edit `README.md` — replace:
```
$clarify-ticket-linear ENG-42
```
with:
```
$clarify-ticket 007
$clarify-ticket-linear ENG-42
```

- [ ] **Step 8: Add `clarify-ticket` to the Codex explicit-only policy sentence**

Edit `README.md` — replace:
```
`implement-ticket`, `clarify-ticket-linear`, `implement-ticket-linear`
```
with:
```
`implement-ticket`, `clarify-ticket`, `clarify-ticket-linear`, `implement-ticket-linear`
```

- [ ] **Step 9: Add the `/`-prefixed usage example**

Edit `README.md` — replace:
```
/clarify-ticket-linear ENG-42                # Fetch, analyze vs. code, discuss risks (read-only, Linear MCP)
```
with:
```
/clarify-ticket 007                          # Read ticket, analyze vs. code, discuss risks (read-only, docs/tickets/)
/clarify-ticket-linear ENG-42                # Fetch, analyze vs. code, discuss risks (read-only, Linear MCP)
```

- [ ] **Step 10: Add to the `for s in …` install loop**

Edit `README.md` — replace:
```
for s in create-tickets implement-ticket clarify-ticket-linear implement-ticket-linear review-ticket update-ticket update-ticket-linear commit-ticket commit-push-pr create-worktree merge-worktree feature-catalog cktk-upgrade codex-handoff grok-handoff opencode-handoff takeover readme-builder design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign cinematic-design-system gen-image-codex gen-image-agy; do
```
with:
```
for s in create-tickets implement-ticket clarify-ticket clarify-ticket-linear implement-ticket-linear review-ticket update-ticket update-ticket-linear commit-ticket commit-push-pr create-worktree merge-worktree feature-catalog cktk-upgrade codex-handoff grok-handoff opencode-handoff takeover readme-builder design-system-extractor design-system-web-applier design-system-mobile-applier wcag-accessibility-checker ux-design ux-redesign cinematic-design-system gen-image-codex gen-image-agy; do
```

- [ ] **Step 11: Verify JSON validity, README coverage, and the validator**

```bash
python3 -m json.tool catalog.json > /dev/null && echo "catalog.json valid"
python3 -m json.tool .claude-plugin/plugin.json > /dev/null && echo "plugin.json valid"
echo "clarify-ticket-linear occurrences (expect 7, unchanged): $(grep -o 'clarify-ticket-linear' README.md | wc -l | tr -d ' ')"
echo "clarify-ticket total occurrences (expect 14 = 7 linear + 7 new): $(grep -o 'clarify-ticket' README.md | wc -l | tr -d ' ')"
grep -q 'twenty-four installer-compatible' README.md && echo "count wording OK"
bash scripts/check-codex-skills.sh
```
Expected: both JSON files valid; `clarify-ticket-linear` occurrences = **7** (unchanged); total `clarify-ticket` occurrences = **14** (the 7 linear ones each contain the substring, plus 7 new non-linear mentions); `count wording OK`; validator prints `Validated 28 Codex skill(s).` (exit 0). If the total is not 14, an insertion was missed or duplicated — reconcile against Steps 3–10 (7 add a `clarify-ticket` mention: bullet, path list, installer command, `$`-example, policy sentence, `/`-example, `for` loop; Step 4 only changes the count wording).

- [ ] **Step 12: Commit**

```bash
git add catalog.json .claude-plugin/plugin.json README.md
git commit -m "feat(clarify-ticket): register in catalog, keywords, and README

Catalog entry, plugin keyword, and all README lists/examples placed
immediately before clarify-ticket-linear.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Local behavioral verification (acceptance gate)

Unlike the Linear twin, this dry-run needs no external service — it runs against a throwaway `docs/tickets/` fixture. This task is a controller/manual acceptance run (it involves interactive discussion), executed by driving the merged `skills/clarify-ticket/SKILL.md` phases.

**Files:** none (verification only; the fixture lives in a scratch directory, never in this repo).

- [ ] **Step 1: Build a throwaway fixture repo**

```bash
FIX="$(mktemp -d)/clarify-fixture"
mkdir -p "$FIX" && cd "$FIX" && git init -q && mkdir -p docs/tickets src
cat > docs/tickets/003-add-csv-export.md <<'EOF'
# [TICKET-003] Add CSV export to the report page

## Status
`pending`

## Description
Let users export the current report table as a CSV file.

- Requires: #001

## Acceptance Criteria
- [ ] An "Export CSV" button appears on the report page
- [ ] Clicking it downloads a .csv of the currently filtered rows
- [ ] Column order matches the on-screen table

## Testing
Manual: click the button, open the file.
EOF
cat > docs/tickets/005-add-xlsx-export.md <<'EOF'
# [TICKET-005] Add XLSX export

## Status
`pending`

## Description
Second export format.

- Requires: #003
EOF
cat > docs/tickets/INDEX.md <<'EOF'
# Ticket Index
Last updated: 2026-07-24

| # | Title | Status | Depends On |
|---|---|---|---|
| #001 | Report page | `done` | — |
| #003 | Add CSV export | `pending` | #001 ✅ |
| #005 | Add XLSX export | `pending` | #003 |
EOF
printf 'export function ReportTable(){ return null }\n' > src/report.tsx
git add -A && git commit -q -m "fixture" && echo "FIXTURE=$FIX"
```

- [ ] **Step 2: Run the skill's phases against the fixture and confirm the output**

Drive the `skills/clarify-ticket/SKILL.md` phases with `WORK_DIR=$FIX` and argument `003`. Confirm:
- Phase 2 reads TICKET-003, sees `Requires: #001` (satisfied — `#001` is `done`/✅) and the reverse dep TICKET-005 (`Requires: #003`).
- Phase 4 grounds risks in the fixture (e.g., `src/report.tsx` is the touch point; "currently filtered rows" is underspecified).
- Phase 5 briefing has the four buckets, a `**Readiness:**` verdict, and a `**Code context:**` line.
- Phase 6 engages the user on the open items; Phase 7 prints the summary with a suggested `/implement-ticket 003` next step.

- [ ] **Step 3: Confirm zero side effects on the fixture**

```bash
cd "$FIX"
git status --porcelain
md5 -q docs/tickets/003-add-csv-export.md docs/tickets/INDEX.md 2>/dev/null || md5sum docs/tickets/003-add-csv-export.md docs/tickets/INDEX.md
```
Expected: `git status --porcelain` empty (no writes); the ticket file and INDEX.md are byte-for-byte unchanged (the skill must not edit them).

- [ ] **Step 4: Verify auto-detect (branch + INDEX fallback)**

```bash
cd "$FIX"
git checkout -q -b ticket-003-add-csv-export
```
Run `/clarify-ticket` with **no argument** and confirm it auto-detects `003` from the branch. Then `git checkout -q main` (or the fixture's default branch) and run `/clarify-ticket` with no argument again; confirm the INDEX.md fallback lists the `pending` tickets (003, 005) for selection.

- [ ] **Step 5: Verify the missing-tracker guardrail**

In a directory with **no** `docs/tickets/` (e.g. a fresh `mktemp -d` git repo), run `/clarify-ticket 003` and confirm it stops with the hint pointing to `/clarify-ticket-linear`, without inventing a fallback.

- [ ] **Step 6: Clean up the fixture**

```bash
rm -rf "$(dirname "$FIX")"
echo "fixture removed"
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-07-24-clarify-ticket-design.md`):
- Identity & contract (name, `user-invocable`, advisory/read-only, no MCP) → Task 1 frontmatter + body + Safety Rules.
- Argument grammar + auto-detect incl. INDEX.md pending fallback (delta 2) → Task 1 Phase 1; verified Task 4 Step 4.
- Read the ticket, INDEX row, reverse-dep grep (delta 3) → Task 1 Phase 2; verified Task 4 Step 2.
- Code context resolution → Task 1 Phase 3.
- Codebase-grounded analysis + PRD/design cross-check (delta 4) → Task 1 Phase 4.
- Briefing / discussion / summary → Task 1 Phases 5–7; verified Task 4 Step 2.
- Local-files source (delta 1) + safety → Task 1 Prerequisites + Safety Rules; verified Task 4 Steps 3 & 5.
- Packaging (canonical, mirror + openai.yaml, symlink, catalog/plugin/README, placement before clarify-ticket-linear) → Tasks 2 & 3.
- Validation (validator 28, JSON, README coverage, local dry-run, auto-detect) → Task 2 Step 4, Task 3 Step 11, Task 4.
- Out-of-scope (no ticket edits, no Linear, no prep-note) → honored throughout; Safety Rules forbid writes.

**Placeholder scan:** none — all SKILL.md, YAML, JSON, README, and fixture content is literal; every verification step has an exact command and expected output.

**Name/verdict consistency:** `clarify-ticket` is identical across both frontmatters, the symlink, `catalog.json`, `plugin.json`, and all README entries. Placement ("immediately before `clarify-ticket-linear`") is uniform. Verdict vocabulary (`ready`/`needs-clarification`/`blocked`) matches between variants and the spec. Ticket-ref normalization (`TICKET-007`/`007`/`#7`/`7` → `NNN`) and branch pattern (`^ticket-(\d{3})-`) match `update-ticket`/`implement-ticket`.
