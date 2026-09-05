# Design: Repository Project Bindings and Linear/Notion Sync

**Date:** 2026-09-04
**Status:** Draft — awaiting review

## Context

Teams that run Linear alongside Notion split authority four ways:

| Information | Owner |
| --- | --- |
| Product intent, methodology, rationale, cross-ticket decisions | Notion |
| Executable scope, acceptance criteria, status, verification evidence | Linear issues |
| Current phase, next checkpoint, open questions, navigation | Linear Project Context document |
| Schemas, code, tests, commands | The repository |

Conflict rules: Linear wins for execution state, the repository wins for technical
behavior, Notion wins for product and governance intent. The third row is a
convention, not a Linear feature — a team keeps a Linear **Document** attached to
the project, calls it the **Project Context**, and makes it the required first read.
It exists partly because a repository's `AGENTS.md` is not always shareable: it
mixes project context with technical development rules that often should not leave
the repository. Section names are that team's choice and are never hardcoded here.

**The project description is a different object and is out of scope.** It says what
the project is — goal, guardrails, success criteria — and changes occasionally. The
Project Context document is what a team iterates on, and is where execution state
goes stale. Skills read the description; they never write it.

Two standing rules constrain any automation: do not create a second live task
tracker in Notion, and do not copy repository truth into prose that will drift. A
decision local to one issue belongs in that issue; a decision affecting multiple
issues, product boundaries, methodology, governance, or future versions belongs in
the Notion decision log.

### The three failures

**Execution state goes stale.** The Linear Project Context drifts on almost
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

7. **The write probe is opt-in and states its residue** (hardening, section 2.4).
   An earlier draft made it mandatory and promised to delete the probe entry
   afterwards. The Notion MCP has no delete and no archive operation, so that
   promise was unimplementable; against a decision log with real entries it would
   have left permanent litter.

8. **The sync is not atomic with the status change, and says so** (section 3.5).

9. **Schema drift detection compares property types, not only names**
   (section 4.4).

9a. **A run that writes no status still reaches Phase 8** (section 3.7). The status
    write is one-way, so without this a sync whose patch was wrong, or whose
    consent was declined, could never be retried through this command — the
    idempotent stop would end the run before the sync. This is the recovery hole
    decision 2 accepted on the assumption that printing the patch was enough
    compensation; a live run showed it was not.

10. **The sync target is the Project Context document, not the project
    description.** Verified against a live workspace after the first pass was
    written: the description held only stable intent — goal, guardrails, success
    criteria — every line of which section 3.2 forbids touching, while the prose
    that actually goes stale ("as of <date>, TAI-72 is complete; the next step is
    TAI-73") lived in the document. A sync aimed at the description would have
    edited the wrong object, and found nothing it was permitted to change there.

    A project keeping its Project Context in the description is misconfigured, not
    a variant to support. `init-project` reports it and offers to move it.

    `save_document` exposes the same `patch` parameter as `save_project` — same
    operations, same exactly-once anchor rule, same atomic abort, same 50-operation
    cap — so only the call and the target id change.

11. **The decision-log idempotency marker lives on the Linear issue, not in
    Notion** (section 4.3). Reading a real 58,000-character log on every run to
    check for a duplicate is not affordable, and keyword-narrowing is unsound
    because issue identifiers appear throughout such a log's prose.

12. **`init-project` may migrate a Project Context out of the description**, behind
    a `y/N` prompt (section 2.5). This is the one place a cktk skill writes the
    project description, and it is a one-time consented migration rather than
    routine operation.

13. **Notion is the decision log; the Linear Project Context document's own
    decision-log section is not a write target.** Some teams keep both. Writing to
    both would create the divergence this feature exists to prevent, so automation
    writes one and only one.

14. **`state_sections` is a list, not a single heading.** The document this design
    was validated against has at least two sections that go stale independently —
    a research-handoff section carrying "as of <date>, TAI-72 is complete" and an
    open-questions section the document itself says must be emptied as questions
    resolve. A single-heading field would force a team to pick one and leave the
    others to rot.

## What this design can and cannot guarantee

The hardening decisions above exist because a first pass over this design claimed
more than the underlying APIs deliver, and aimed at the wrong Linear object. This
section is the honest ledger.

| Claim | Mechanism | What it does not cover |
| --- | --- | --- |
| Never edits an existing Notion entry | Only `notion-create-pages` (database) and `notion-update-page` with `command: "insert_content"`, `position: {"type":"end"}` (page) are ever emitted. The destructive command values `update_content` and `replace_content` are named as forbidden. | Nothing. This one is structural. |
| Never writes a duplicate automatically | At most one automatic entry per issue, enforced by a `cktk:decision-logged` marker comment on the Linear issue. | A second, genuinely distinct decision on the same issue is drafted, not written (deliberate); an entry a human logged by hand carries no marker; a marker write that fails after a successful Notion write is reported, not silently retried. |
| Never writes a partial entry | Both write paths are single calls carrying properties and body together. | Nothing. There is no create-then-populate sequence to strand. |
| Detects a schema change before writing | Re-fetches the data source and compares recorded property names **and types**. | A property whose name and type are unchanged but whose meaning changed. |
| A wrong id or path fails at `init-project`, not later | Every binding is fetched and every repository path is stat'd. | **Write permission**, unless the opt-in probe is run. Notion exposes no delete, so proving write access costs an undeletable entry; skipping it costs one clean report on the first real write. |
| The Project Context is kept true | `save_document` `patch` on the bound document, applied after the status write and the cascade. | **Not guaranteed.** The sync cannot be atomic with the status change; see 3.5. The promise is "usually syncs, always reports". |
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
    "team": { "key": "TAI", "id": "…", "status": "validated", "validated_at": "…" },
    "project": {
      "id": "…",
      "name": "…",
      "url": "https://linear.app/…/project/…",
      "status": "validated",
      "validated_at": "2026-09-04T09:15:00Z"
    },
    "project_context": {
      "enabled": true,
      "document_id": "595b2a61-d373-4212-8541-e8b46fb8e2e5",
      "document_slug": "df5459f01ca1",
      "document_url": "https://linear.app/acme/document/project-context-df5459f01ca1",
      "title": "專案脈絡 / Project Context",
      "state_sections": [
        "## 目前研究交接 / Current research handoff",
        "## 尚待決定的問題 / Open questions"
      ],
      "last_synced_marker": null,
      "status": "validated",
      "validated_at": "2026-09-04T09:15:00Z"
    }
  },
  "notion": {
    "hub": { "id": "…", "url": "…", "status": "validated", "validated_at": "…" },
    "product_spec": { "id": "…", "url": "…", "title": "…", "status": "validated", "validated_at": "…" },
    "decision_log": {
      "shape": "database",
      "data_source_url": "collection://…",
      "database_url": "https://www.notion.so/…",
      "properties": {
        "title": "Decision",
        "key": "cktk Key",
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
      "validated_at": "2026-09-04T09:15:00Z",
      "write_probe": { "at": "2026-09-04T09:15:00Z", "result": "passed" }
    }
  },
  "repository": {
    "product_requirements": ["docs/PRD.md"],
    "decisions": ["docs/decisions/"],
    "tickets": { "kind": "linear" },
    "status": "validated",
    "validated_at": "2026-09-04T09:15:00Z"
  },
  "preferences": {
    "sync_project_context": "ask",
    "write_decision_log": "ask"
  }
}
```

**A canonical product spec is usually not in the repository.** A Linear project
description commonly names one — "if an older ticket conflicts with the canonical
specification, update or retire the ticket" — and it lives in Notion. Recording
only `repository.product_requirements` would hand a downstream skill two repo files
and leave it unaware of the source the project itself says wins. Both are recorded,
and which is canonical is explicit.

**Timestamps are per binding, inline, and only a revalidated binding is
restamped.** Scoped re-runs (`/init-project repository`) are the normal way this
file is maintained, so bindings age independently: after a few, one section may
have been checked weeks before another while both read `"validated"`. A single
file-level timestamp cannot express that, and a tool built to prevent staleness
should not be blind to its own.

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

#### 2.4 Validate

Fetch the Linear project. Fetch the Notion hub and decision log. Confirm the
decision log's live properties match what is about to be recorded. Stat every
repository path.

**Fetching proves read access only**, and the requirement was that a typo fail here
rather than at 2am inside an unrelated command. A wrong id, a wrong URL, a missing
path, or a renamed property all fail here. **Write permission does not**, and it
cannot be made to without a cost worth naming.

A write probe would prove it, but the Notion MCP exposes no delete and no archive
operation — `notion-create-pages`, `notion-update-page`, `notion-move-pages`, and
`notion-duplicate-page` are the write surface, and none removes a page. A probe
entry is therefore permanent until a human deletes it in Notion. In a decision log
that already holds real entries, that is a worse outcome than the problem.

So the probe is **offered, never the default**, and the offer states the residue.
Skipped (the default) records `write_probe: { "result": "not attempted" }` and
leaves `status: "validated"`. Passed records the probe entry's URL so the user can
remove it. Refused by Notion records `status: "read-only"` and
`preferences.write_decision_log: "never"`.

**Skipping is safe because section 4 already fails soft.** A refused Notion write
is drafted into the run summary and reported, never retried and never fatal. The
cost of not probing is one clean report on the first real write. Section 4 refuses
to auto-write only against `read-only` and `unresolved` bindings — never merely
because write access is unproven.

**A database-shaped log needs two properties that may not exist**: one queryable
text or URL property to hold the idempotency key (section 4.3) and one to hold the
named referent (section 4.2). Where either is missing, `init-project` describes it
and offers to add it — a schema change to a shared database, so never automatic.
Declined, it records `status: "read-only"`, and Phase 9 drafts instead of writing
for that repository from then on.

#### 2.5 Migrating a Project Context out of the description

A project whose Project Context sits in its description is misconfigured (decision
10). `init-project` detects it — no Project Context document exists, and the
description carries context-shaped headings or an explicit `# Project Context`
title — and offers a migration behind a `y/N` prompt defaulting to no:

```
Redbeak's Project Context looks like it lives in the project description.
Move it into a Linear Document?

  - creates a document "Project Context" attached to Redbeak, with the
    description's current content
  - replaces the description with a link to it
  - you write the new description yourself; I will not invent one

Move it? [y/N]
```

On yes: create the document with `save_document` (`project` parameter, `title`,
`content`), confirm it by fetching it back, and only then replace the description
with a pointer line. Ordering matters — a failure after the description is cleared
would lose the content.

**This is the one place a cktk skill writes the project description**, and the
relaxation is deliberate: the standing rule forbids writing it during *routine
operation*, which a one-time explicitly consented migration is not. The replacement
is a link and nothing else. Writing a summary of the project would be inventing
product content, which section 2.6 forbids.

Declining leaves everything as it is and records `project_context.enabled: false`,
with the misconfiguration named in the final report so it is not silently
forgotten.

**Inbound references are part of the migration.** Repository documents commonly
link the project URL and call it the Project Context; after a migration those point
at a stub. The offer lists every hit as `file:line` so the cost is visible before
the decision, and a successful migration offers once more to repoint them — a plain
URL substitution, never a rewrite of the surrounding sentence. A migration that
leaves three files pointing at a stub only half happened.

**Re-validation audits the selection, not just its existence.** A section recorded
in `state_sections` by mistake passes an existence check forever, so a re-run that
only confirms headings are still present can never correct a bad selection — the
mistake is permanent and unreachable. Re-validation therefore re-applies the
selection test to each recorded section and scans for sections that now pass but
are unrecorded, reporting both and offering to fix them.

#### 2.6 Offer to create what is missing

If there is no Linear project or no decision log, describe what is needed and
create it only on an explicit yes. Populate structure only. Never invent product
content: an empty field the owner fills is correct, a plausible invention is not.

#### 2.7 Report and re-run

Report what resolved, what did not and why, and what was created. On a re-run,
detect the existing file and offer per-binding correction — a moved Notion page is
a one-field fix, not a fresh interrogation.

#### 2.8 Repository hygiene

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

- The issue's own line, where the document mentions it.
- Statements the transition falsified: an issue named "in progress", "next", or
  "not started" that is now Done; a "blocked by X" where X just closed.
- Milestone completion **only where the document states it in prose**. Linear
  computes milestone progress itself and shows it in its own UI, so there is
  usually nothing to mirror and nothing to sync. Where a team does write a number
  into the document, read the real one from Linear: percentages move when issues
  are **added** to a milestone, not only when they complete, so a falling
  percentage usually means scope grew rather than work being lost. Where the
  document explains a number, the explanation must stay truthful.

  **Every stated figure is checked, not only the one belonging to this issue's
  milestone** — and a figure used as part of an anchor is still checked. A first
  live run corrected one percentage and left another wrong in the same sentence,
  having used the stale number as anchor text without ever verifying it.

  **A changed figure can strand the sentence that explains it**, and the sync
  reports rather than repairs. "Both fell because ten design tickets joined their
  denominators" stops explaining anything once one of those numbers rises, without
  ever becoming false — it is dated, and true of a moment that has passed.
  Rewriting it would mean reconstructing a rationale nobody witnessed, so the
  summary quotes it instead and a human decides. This is where "leave ambiguity
  alone" and "an explanation must stay truthful" meet: the resolution is an
  obligation to report, not a licence to edit.

- **Amend rather than replace.** Where a sentence is falsified only in part — "A, B
  and C have not started" and only B is done — the fix carves out the exception and
  keeps the true remainder. Replacing the sentence with a different
  characterisation loses information the document had before the sync.
- A "last synced" marker, **only where one already exists.** When
  `last_synced_marker` is `null` the document has none, and the sync does not
  invent one: adding a line to a shared document nobody asked for is exactly the
  kind of uninvited edit section 3.2 exists to prevent. A team that wants a marker
  adds it and re-runs `init-project`.

#### 3.2 What it may never change

Anything outside `state_sections`. Everything else, and in particular anything Notion or the repository owns. Purpose,
methodology, guardrails, invariants, and architecture contracts appear in the
Project Context for navigation; editing them from here would put two sources into
conflict. **Ambiguous effect means report and change nothing.**

#### 3.3 How it writes

`save_document` with the `patch` parameter, never a whole-content replace. The
tool schema confirms two properties this design depends on: every anchor "must
match the current content exactly once", and operations apply "in order and
atomically (one failing operation aborts the whole save)". A stale anchor therefore
fails the sync cleanly instead of half-applying it. Maximum 50 operations.

#### 3.4 Two confirmed Linear behaviours

Both were observed by hand; the second is also visible in the live document this
design was validated against, where every inline reference is stored as
`<issue id="…" href="…">TAI-5</issue>` rather than as the text `TAI-5`.

1. **Linear re-serializes the description on save.** A round trip normalized
   malformed markdown — bold markers spanning an inline issue mention were dropped.
   Content survived, formatting did not. The summary notes this so a cosmetic diff
   is not read as data loss.
2. **Plain-text issue identifiers become inline mention markup after a save.**
   Anchors are therefore drawn from ordinary prose and never from identifier
   substrings, which would fail to match on the next run.

#### 3.5 The sync is not atomic with the status change

Phase 6 writes the status, Phase 7 cascades, Phase 8 syncs. If Phase 8's anchors no
longer match — someone edited the document by hand — the patch aborts cleanly and
the workspace is left with the status moved, dependents moved, and the Project
Context stale. **That is the original bug.** The difference is that Phase 10 now
reports it.

This cannot be fixed by reordering; the two writes are separate API calls against
separate objects. The skill documents the promise as "usually syncs, always
reports".

#### 3.6 A run that writes no status

When the issue already holds the target state, Phase 5 reports the transition as
idempotent and skips the status write and the cascade — but the run continues into
this phase. The question changes from *what did this transition falsify?* to *what
does the document state about this issue, its blockers, or its milestones that
Linear now contradicts?* The bounds, anchor rules, consent, and the obligation to
leave ambiguity alone are all unchanged.

The decision-log phase of section 4 is skipped in such a run: a sync-only pass
settles no decision, so there is nothing for it to record.

This makes a repeat invocation converge the document rather than be a no-op, and it
is the only route back to a sync after a declined consent or a bad patch.

#### 3.7 No Project Context exists

Offer to create a minimal Project Context **document**: state section, current
phase, next checkpoint, and the last-synced marker. Never invent purpose,
guardrails, or architecture. Never write the project description instead — that is
the misconfiguration `init-project` reports, not a fallback.

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

#### 4.3 Idempotency: the marker lives on the Linear issue

The obvious check — read the decision log and look for this issue — does not
survive contact with a real log. The one this design was validated against is a
single Notion page of roughly 58,000 characters, and it reports neither `truncated`
nor a non-zero `unknown_block_count`, so the section 4.4 preconditions do not fire.
A scan would simply consume the whole page on every run. Narrowing by keyword does
not help either: issue identifiers appear throughout that log's prose, so "TAI-48
appears somewhere" is true for issues that have no entry of their own.

**So the marker does not live in Notion.** After a successful write, Phase 9 posts a
comment on the Linear issue:

```
cktk:decision-logged <ISSUE-ID> → <notion entry url>
```

The check is then: list the issue's comments — one cheap call against an issue the
run already has open — and look for the literal prefix `cktk:decision-logged`.

- **Absent** — eligible for an automatic write, subject to consent.
- **Present** — never write automatically. Draft into the Phase 10 summary, naming
  the already-logged entry's URL, and let a human decide.

This is exact rather than heuristic, costs nothing that scales with the log, and is
independent of the log's size, shape, and property schema. It also earns its keep
in the other direction: a reader of the issue can now reach the decision it
produced.

**Two failure modes, both stated rather than papered over.** If the Notion write
succeeds and the marker comment then fails, a later run can write a second entry —
so a failed marker write is reported loudly, with the Notion URL, rather than
swallowed. And a decision a human logged by hand carries no marker, so the run may
propose a duplicate of it; the named-referent gate, the per-run consent, and the
Phase 10 report are what keep that visible.

The entry still carries `cktk:<ISSUE-ID>:<slug>` as its recorded key, for a human
scanning the log and for any later reconciliation. Nothing depends on the slug
being stable.

#### 4.4 Pre-write schema check

Immediately before writing, re-fetch the data source and compare the live schema
against `properties` **and** `property_types`. Comparing names alone catches a
rename but misses a retype — a `text` property changed to `select` keeps its name,
passes a name-only check, then fails or coerces badly at write time.

Any mismatch, or any binding that is not `validated`, means: draft into the
summary, name the failed precondition, write nothing.

**The log is never read before writing.** Idempotency comes from the Linear-side
marker (4.3), and the entry is appended at a fixed end of the log rather than under
a located heading, so nothing in this phase scales with the log's size. That is
what makes a 58,000-character decision log a non-issue instead of a context
budget.

#### 4.5 The write

- **Database** — `notion-create-pages` with a `data_source_id` parent. Cannot
  modify a sibling row.
- **Page** — `notion-update-page`, `command: "insert_content"`, with `position`
  taken from the binding's `append_position` (`end` for a log ordered oldest-first,
  `start` for newest-first). Cannot reach existing blocks.

Every entry is backlinked to its Linear issue, carries its key and named referent,
and is attributed to the workflow rather than to a person. A failed Notion write is
reported and never fails the status update.

**Then, and only after the Notion write returns successfully**, post the
`cktk:decision-logged` marker comment on the Linear issue. If that comment fails,
report it prominently with the Notion entry's URL: the entry exists, the marker
does not, and a later run could duplicate it unless a human intervenes.

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
- The Linear project **description** is never written during routine operation.
  `init-project`'s consented migration (section 2.5) is the sole exception, and it
  never runs without an explicit yes.
- The Project Context document's own decision-log section, where a team keeps one,
  is never written by automation. Notion is the single decision-log target.
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
