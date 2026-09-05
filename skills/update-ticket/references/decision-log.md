# Optional cross-cutting decision record

Use when this work establishes a decision affecting another named issue or project/business boundary, or when recovering a known unfinished record of such a decision. Read the [bindings contract](../../init-project/references/project-schema.md). The Notion binding and `preferences.write_decision_log` are independent of Project Context sync; disabling that sync does not disable this action.

## Establish an eligible, authorized record

Use only a compatible, validated decision-log binding for the issue's project. A read-only/unresolved/missing binding yields a draft or concise report, not a setup question or permission probe. Honor existing authorization and this action's own `always` / `ask` / `never` preference. Context-sync consent alone does not authorize a Notion write. Prepare the concrete entry before asking for missing consent; do not hold the issue's supported Done transition for it.

Record an actual decision from the evidence, with its named affected issue or boundary and implications. Routine status changes and issue-local implementation details do not automatically qualify. Do not infer a new decision solely because an issue is Done or a document is stale. A known qualifying decision can be recorded or recovered even if no status transition occurred in this run.

Preserve the one-automatic-entry-per-issue contract. Read the issue's comments, following pagination, for the exact `cktk:decision-logged` marker and linked entry. If present, do not create another entry; report the existing record and draft any additional decision for the user. Do not load or keyword-scan the decision log for duplicate detection: mention of an issue in arbitrary prose is not an entry identity.

A missing marker does not prove a previous uncertain Notion write failed. Use any known operation receipt and exact entry URL to verify that result and repair its missing marker instead of appending again. For a queued async result, follow the provided operation to completion. If the outcome cannot be established, leave this optional action unresolved and report the uncertainty; do not gamble on a duplicate write.

## Append to the verified destination

Immediately before writing, verify the live destination shape against the binding, including database property names and types. A mismatch stops this optional write with a concrete explanation. Do not add schema properties or change an existing human entry.

Discover the host's actual Notion schemas. For a database log, create one page under the bound data source with its actual property mapping. For a page log, insert new content at the configured start/end position and heading level. The supported operations are `notion-create-pages` or `notion-update-page` with `command: "insert_content"`; do not use `update_content` or `replace_content` on the log.

Include the decision, named referent, issue backlink, `cktk:<ISSUE-ID>:<slug>` key, and attribution to the workflow rather than inventing a human author. Optional mapped properties stay optional; put needed content in the entry text when the schema has no matching property.

After confirmed creation/insertion, verify the specific result and post the issue marker `cktk:decision-logged <ISSUE-ID> → <entry URL>`. Record the receipt/URL before that comment so a marker failure can be recovered. If the comment fails, report that the entry exists and only the marker remains; retry the marker after checking current comments, not the Notion append.

Report the entry URL, named impact, and any unresolved write or marker. A failed log action does not undo the issue status or prevent an independently authorized Project Context sync. Keep a draft available when a write is declined or unavailable; show its full text only when useful or requested.
