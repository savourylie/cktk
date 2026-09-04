# Design: Repository Project Bindings and Linear/Notion Sync

**Date:** 2026-09-04
**Status:** Draft — awaiting review

## Context

Teams that run Linear alongside Notion split authority four ways:

| Information | Owner |
| --- | --- |
| Product intent, methodology, rationale, cross-ticket decisions | Notion |
| Executable scope, acceptance criteria, status, verification evidence | Linear issues |
| Current phase, next checkpoint, milestones, navigation | Linear project description |
| Schemas, code, tests, commands | The repository |

Conflict rules: Linear wins for execution state, the repository wins for technical
behavior, Notion wins for product and governance intent. The third row is a
convention, not a Linear feature — a team designates the project description as its
required first read and calls it the **Project Context**. Section names are that
team's choice and are never hardcoded here.

Two standing rules constrain any automation: do not create a second live task
tracker in Notion, and do not copy repository truth into prose that will drift. A
decision local to one issue belongs in that issue; a decision affecting multiple
issues, product boundaries, methodology, governance, or future versions belongs in
the Notion decision log.

### The three failures

**Execution state goes stale.** The Linear project description drifts on almost
every status change and nothing prompts anyone to fix it. In one observed session
it claimed a milestone was "under way" at 100%, called a merged pull request "open,
mergeable, and green", and named two Done issues as "unblocked and may proceed".
After a human corrected all of it, the correction went stale within the same
session — it said ten tickets had not been created, and then they were.

**Cross-cutting decisions never reach Notion.** In the same session, closing an
issue settled which authentication method the product would use, explicitly flagged
as affecting downstream issues. It was recorded in a Linear comment and never
reached the decision log. Nothing asked.

**Neither can be automated today, because nothing knows where anything is.** The
Linear project, the Notion hub, and the decision log are not discoverable from the
repository. Any sync feature must either interrogate the user on every run — which
is how the manual process already fails — or guess.

## Decisions (from brainstorming)

1. **The binding skill is `init-project`, not `init`.** A bare `init` collides with
   Claude Code's built-in `/init`, which writes `CLAUDE.md`.

2. **The Project Context sync stays inside `/update-ticket-linear`** rather than
   becoming a standalone `/sync-project-context`. The failure being fixed is
   forgetting; a sync that must be remembered separately is remembered exactly as
   well as the manual edit it replaces. The "a focused status tool should not also
   be a document editor" objection assumes the skill is not one already — it is.
   `skills/update-ticket-linear/SKILL.md:170-171` already rewrites the issue
   description's checkboxes and posts a comment on every completing run. The change
   is which document, not which category of tool.

   Accepted cost: declining consent leaves no way to sync later without staging
   another status change. Mitigated by printing the exact patch operations in the
   summary when consent is declined, rather than by adding a fourth Linear-side
   skill across three trees. If the standalone entry point is later wanted, the
   logic lives in a `references/` file the phase reads, so adding it is cheap.

3. **Skills consume the bindings through one shared reference document.**
   `skills/init-project/references/project-schema.md` is the single normative
   description of the file; `init-project` writes to it and `update-ticket-linear`
   reads by linking to it. Describing the schema in both skills would let the two
   descriptions drift, reproducing this feature's own bug inside the feature. A
   runtime helper script was rejected: it would make these skills stop being pure
   documentation artifacts and add an executable dependency to all three trees for
   a file read about twice per session.

4. **The Notion write is automatic, with a stated precondition.** Append-only is
   structurally guaranteed (see below). Idempotency is guaranteed only when the
   preconditions in section 4 hold; otherwise the entry is drafted into the summary
   and the failed precondition is named. A failed Notion write never fails the
   status update.

5. **Cross-cutting detection must name a referent** (hardening, section 4.2).

6. **At most one automatic Notion entry per issue, ever** (hardening, section 4.3).

7. **`init-project` proves write access, not just read access** (hardening,
   section 2.4).

8. **The sync is not atomic with the status change, and says so** (section 3.5).

9. **Schema drift detection compares property types, not only names**
   (section 4.4).

## What this design can and cannot guarantee

The five hardening decisions above exist because a first pass over this design
claimed more than the underlying APIs deliver. This section is the honest ledger.

| Claim | Mechanism | What it does not cover |
| --- | --- | --- |
| Never edits an existing Notion entry | Only `notion-create-pages` (database) and `notion-update-page` with `command: "insert_content"`, `position: {"type":"end"}` (page) are ever emitted. The destructive command values `update_content` and `replace_content` are named as forbidden. | Nothing. This one is structural. |
| Never writes a duplicate automatically | At most one automatic entry per issue identifier, enforced by an exact-prefix query. | A second, genuinely distinct decision on the same issue is drafted, not written. Deliberate. |
| Never writes a partial entry | Both write paths are single calls carrying properties and body together. | Nothing. There is no create-then-populate sequence to strand. |
| Detects a schema change before writing | Re-fetches the data source and compares recorded property names **and types**. | A property whose name and type are unchanged but whose meaning changed. |
| A typo fails at `init-project`, not later | Every binding is fetched, and the decision log is write-probed. | A permission revoked between `init-project` and a later run. Caught then, and reported rather than retried. |
| The Project Context is kept true | `save_project` `patch`, applied after the status write and the cascade. | **Not guaranteed.** The sync cannot be atomic with the status change; see 3.5. The promise is "usually syncs, always reports". |
| Cross-cutting decisions are detected | A named-referent gate; see 4.2. | **Not guaranteed.** This is model judgment on every run. The gate makes the judgment falsifiable, not correct. |

The last two rows are the parts of this feature most likely to underdeliver. They
are stated here so the reader is not surprised by them later.

## Design

### 1. The contract file

`.ai/cktk/project.json`, committed to the repository. It is shared team
configuration, unlike `.ai/cktk/delegation/`, which is local diagnostics.

```json
{
  "schema_version": 1,
  "generated_by": "cktk/init-project",
  "generated_at": "2026-09-04T09:15:00Z",
  "linear": {
    "team": { "key": "TAI", "id": "…", "status": "validated" },
    "project": {
      "id": "…",
      "name": "…",
      "url": "https://linear.app/…/project/…",
      "status": "validated",
      "validated_at": "2026-09-04T09:15:00Z"
    },
    "project_context": {
      "enabled": true,
      "state_section": "## Current State",
      "milestone_section": "## Milestones",
      "last_synced_marker": "_Last synced:",
      "status": "validated"
    }
  },
  "notion": {
    "hub": { "id": "…", "url": "…", "status": "validated" },
    "decision_log": {
      "shape": "database",
      "data_source_url": "collection://…",
      "database_url": "https://www.notion.so/…",
      "properties": {
        "title": "Decision",
        "idempotency_key": "cktk Key",
        "backlink": "Linear issue",
        "referent": "Affects",
        "date": "Decided"
      },
      "property_types": {
        "Decision": "title",
        "cktk Key": "text",
        "Linear issue": "url",
        "Affects": "text",
        "Decided": "date"
      },
      "status": "validated",
      "write_probe": { "at": "2026-09-04T09:15:00Z", "result": "passed" }
    }
  },
  "repository": {
    "product_requirements": ["docs/PRD.md"],
    "decisions": ["docs/decisions/"],
    "tickets": { "kind": "linear" }
  },
  "preferences": {
    "sync_project_context": "ask",
    "write_decision_log": "ask"
  }
}
```

**Status values are per binding, inline.** `validated` means resolved and — for the
decision log — write-probed. `read-only` means the fetch succeeded but write access
was refused or the probe was declined. `unresolved` means the binding could not be
fetched and carries a `reason`. Nothing unvalidated is ever recorded as if it were
confirmed, and a separate status block was rejected so status cannot drift away
from the thing it describes.

**Page-shaped decision logs** replace `data_source_url` / `properties` /
`property_types` with `page_id` and `append_under_heading`.

**Schema version.** `schema_version: 1`. A reader that finds a higher version
reports and skips, never guesses.

### 2. `init-project`

Interactive, re-runnable, and it reads before it asks.

#### 2.1 Discover

Read `README.md`, `docs/PRD.md`, and any design, architecture, or requirements
documents present. Harvest Linear and Notion URLs; infer the team key and project
slug from URL structure. Most repositories already carry these in prose.

#### 2.2 Fill gaps by listing, not asking

Where discovery finds nothing, query the connected MCP servers — `list_teams`,
`list_projects`, Notion search — and offer results as labeled choices. Never ask
for a raw identifier.

#### 2.3 Propose prefilled, then confirm

Present every field with its source, e.g. `README.md:12`. A user correcting three
prefilled fields finishes; a user facing an empty questionnaire does not. The
Project Context section names are read from the fetched description and offered as
choices — never hardcoded, never invented.

#### 2.4 Validate, including write access

Fetch the Linear project. Fetch the Notion hub and decision log. Confirm the
decision log's live properties match what is about to be recorded. Stat every
repository path.

**Fetching proves read access only.** The stated requirement is that a typo fails
here rather than at 2am inside an unrelated command, and a read-only fetch does not
meet it: a connector with no write permission on the decision log passes every
check and fails weeks later. So `init-project` additionally performs a **write
probe** — with explicit consent, it creates a probe entry in the decision log and
then archives or deletes it, recording the outcome in `write_probe`.

Declining the probe is allowed and records `status: "read-only"`. Section 4 refuses
to auto-write against any binding that is not `validated`.

**A database-shaped log needs two properties that may not exist**: one queryable
text or URL property to hold the idempotency key (section 4.3) and one to hold the
named referent (section 4.2). Where either is missing, `init-project` describes it
and offers to add it — a schema change to a shared database, so never automatic.
Declined, it records `status: "read-only"`, and Phase 9 drafts instead of writing
for that repository from then on.

#### 2.5 Offer to create what is missing

If there is no Linear project or no decision log, describe what is needed and
create it only on an explicit yes. Populate structure only. Never invent product
content: an empty field the owner fills is correct, a plausible invention is not.

#### 2.6 Report and re-run

Report what resolved, what did not and why, and what was created. On a re-run,
detect the existing file and offer per-binding correction — a moved Notion page is
a one-field fix, not a fresh interrogation.

#### 2.7 Repository hygiene

`.ai/cktk/delegation/` is currently excluded from version control by convention
only; the implement skills instruct "never stage them" but nothing enforces it.
Since `init-project` is about to add a *tracked* file in the same directory, it
offers to add that ignore line to the target repository's `.gitignore`.

### 3. `update-ticket-linear` Phase 8 — Sync the Project Context

Phases 1 through 7 are unchanged except that **Phase 1 additionally loads
`.ai/cktk/project.json`**. A missing or higher-versioned file is recorded and the
run continues; it never blocks a status update. What was Phase 8 (Summary) becomes
Phase 10.

The sync runs **after** Phase 7's cascade, not immediately after the Phase 6 status
write, because statements of the form "blocked by X" can only be corrected once the
cascade has determined what actually moved.

Skip the entire phase when no status was written, when the bindings are absent, or
when `project_context.enabled` is false.

#### 3.1 What it may change

Only content the transition provably affects:

- The issue's own line, where the description mentions it.
- Statements the transition falsified: an issue named "in progress", "next", or
  "not started" that is now Done; a "blocked by X" where X just closed.
- Milestone completion where stated, read from real Linear numbers. Percentages
  move when issues are **added** to a milestone, not only when they complete — a
  falling percentage usually means scope grew, not that work was lost. Where the
  description explains a number, the explanation must stay truthful.
- A "last synced" marker.

#### 3.2 What it may never change

Everything else, and in particular anything Notion or the repository owns. Purpose,
methodology, guardrails, invariants, and architecture contracts appear in the
Project Context for navigation; editing them from here would put two sources into
conflict. **Ambiguous effect means report and change nothing.**

#### 3.3 How it writes

`save_project` with the `patch` parameter, never a whole-description replace. The
tool schema confirms two properties this design depends on: every anchor "must
match the current content exactly once", and operations apply "in order and
atomically (one failing operation aborts the whole save)". A stale anchor therefore
fails the sync cleanly instead of half-applying it. Maximum 50 operations.

#### 3.4 Two confirmed Linear behaviours

1. **Linear re-serializes the description on save.** A round trip normalized
   malformed markdown — bold markers spanning an inline issue mention were dropped.
   Content survived, formatting did not. The summary notes this so a cosmetic diff
   is not read as data loss.
2. **Plain-text issue identifiers become inline mention markup after a save.**
   Anchors are therefore drawn from ordinary prose and never from identifier
   substrings, which would fail to match on the next run.

#### 3.5 The sync is not atomic with the status change

Phase 6 writes the status, Phase 7 cascades, Phase 8 syncs. If Phase 8's anchors no
longer match — someone edited the description by hand — the patch aborts cleanly
and the workspace is left with the status moved, dependents moved, and the
description stale. **That is the original bug.** The difference is that Phase 10
now reports it.

This cannot be fixed by reordering; the two writes are separate API calls against
separate objects. The skill documents the promise as "usually syncs, always
reports".

#### 3.6 No Project Context exists

Offer to create a minimal one: state section, current phase, next checkpoint, and
the last-synced marker. Never invent purpose, guardrails, or architecture.

### 4. `update-ticket-linear` Phase 9 — Notion decision log

Runs after Phase 8, skipped under the same conditions, plus skipped when
`decision_log.status` is not `validated`.

#### 4.1 What qualifies

A decision whose reach exceeds the issue it was made in: it changes what another
issue must do, moves a product or governance boundary, or settles something future
versions inherit.

#### 4.2 The named-referent gate

Whether a decision is cross-cutting is model judgment made fresh on every run with
different context each time. Writing "keep detection conservative" into a document
is an instruction with no enforcement — structurally the same as "someone should
keep the Project Context current", which is the failure this feature exists to fix.
Left unenforced, the phase fails in exactly the two ways that kill it: flagging
every routine close until the user switches it off, or flagging nothing.

So a decision is eligible **only if the run can name the concrete thing it
affects** — another Linear issue identifier, or a named product or governance
boundary that appears in the Project Context or in a bound requirements document.
If no referent can be named, the decision is issue-local and nothing is written.
The named referent is recorded on the entry in the `referent` property.

This does not make the judgment correct. It makes it falsifiable: a reader can
check whether the named issue exists and whether it is genuinely affected.

#### 4.3 Idempotency: at most one automatic entry per issue

The key is `cktk:<ISSUE-ID>:<slug>`. The `<slug>` is model-generated and therefore
not stable across runs, so **the duplicate check never depends on it** — it exists
only so a human scanning the log can tell two keys apart at a glance. The check
queries for entries whose key begins with the exact prefix `cktk:<ISSUE-ID>:`,
which is deterministic.

- **Zero hits** — eligible for an automatic write, subject to consent.
- **One or more hits** — never write automatically. Draft the entry into the
  Phase 10 summary and let a human decide.

An earlier draft of this design proposed writing when the new decision "is clearly
distinct" from existing ones. That reintroduces the unstable judgment at the one
point where a wrong call is unrecoverable: judging "distinct" incorrectly produces
a duplicate in a shared document. One automatic entry per issue is a rule that can
actually be kept.

There is no upsert, so the check is query-then-write with a race window of seconds.
The trigger is a human running a slash command; concurrent runs against one issue
are not a realistic case, and the window is stated rather than papered over.

#### 4.4 Pre-write schema check

Immediately before writing, re-fetch the data source and compare the live schema
against `properties` **and** `property_types`. Comparing names alone catches a
rename but misses a retype — a `text` property changed to `select` keeps its name,
passes a name-only check, then fails or coerces badly at write time.

Any mismatch, any binding not `validated`, or a `notion-fetch` that reports
`truncated` or a non-zero `unknown_block_count` on a page-shaped log (which makes
"the key is absent" unsound) means: draft into the summary, name the failed
precondition, write nothing.

#### 4.5 The write

- **Database** — `notion-create-pages` with a `data_source_id` parent. Cannot
  modify a sibling row.
- **Page** — `notion-update-page`, `command: "insert_content"`,
  `position: {"type":"end"}`. Cannot reach existing blocks.

Every entry is backlinked to its Linear issue, carries its idempotency key and
named referent, and is attributed to the workflow rather than to a person. A failed
Notion write is reported and never fails the status update.

### 5. Consent

Both writes touch a document others read as authoritative, while today's skill
writes only one issue. Ask once per run, covering both writes, defaulting to no.
Honor `preferences.sync_project_context` and `preferences.write_decision_log` when
`init-project` recorded `always` or `never`, so a team that wants this always-on
says so once.

**A user who declines every prompt ends up exactly where they are today**, with one
addition: the summary prints the patch operations and the drafted Notion entry that
were not applied.

### 6. Safety rules to add

- A carve-out for the project-description write naming only the sections it may
  touch, sourced from the bindings.
- Notion-owned and repository-owned content is never edited from Linear.
- The Notion write is append-only: only `notion-create-pages` and
  `insert_content` at `position: end` are permitted; `update_content` and
  `replace_content` are forbidden by name.
- At most one automatic decision-log entry per issue identifier.
- No auto-write against a binding that is not `validated`.
- A failed Notion write never fails the status update.

## Files

**New**

- `skills/init-project/SKILL.md`
- `skills/init-project/references/project-schema.md`
- `.agents/skills/init-project/SKILL.md` (Codex-native document, not a copy)
- `.agents/skills/init-project/references` → symlink
- `.agent/skills/init-project` → symlink

**Modified**

- `skills/update-ticket-linear/SKILL.md` — Phase 1 binding load; new Phases 8 and
  9; Summary renumbered to Phase 10; Safety Rules.
- `.agents/skills/update-ticket-linear/SKILL.md` — same, Codex phrasing.
- `skills/implement-ticket-linear/SKILL.md:332` and
  `.agents/skills/implement-ticket-linear/SKILL.md:181` — both describe what
  `/update-ticket-linear` does for the reader.
- `catalog.json`, `README.md`.

## Verification

These are documentation artifacts, so structural checks stand in for unit tests:

1. `scripts/check-codex-skills.sh` passes — three trees consistent, frontmatter
   valid.
2. `catalog.json` and `.claude-plugin/marketplace.json` parse.
3. Symlinks resolve.
4. **Part A behavioural dry run against a real Linear and Notion workspace** before
   Part B is written: discovery on a repository with URLs in `README.md`,
   validation including the write probe, a deliberately wrong Notion URL failing at
   `init-project`, and a re-run correcting one field.
5. Part B dry run: a status change producing a correct patch; a hand-edited
   description producing a clean abort and a report; a second run on the same issue
   producing a draft rather than a duplicate.

## Out of scope

- A standalone `/sync-project-context`. See decision 2.
- A `docs/tickets/` twin. `/update-ticket` works on markdown tickets and has no
  Linear project.
- Reading the bindings from any skill other than `update-ticket-linear` in this
  pass, though the contract is written to serve others later.
- Migrating existing repositories. `init-project` is run once per repository by
  hand.
