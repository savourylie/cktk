# Reconcile local ticket documents

Read this for `update-ticket` after selecting the exact ticket, checkout, and target. Ticket files own their requirements and status; `INDEX.md`, dependency success marks, counts, and graph markers are projections of that information.

## Limit the write scope

Record the initial staged and working changes, including human edits in files this update may touch. Use exact numeric identifier boundaries so `#007` cannot match `#0070`. Locate the ticket in `WORK_DIR`; do not require a second canonical copy in another checkout. A missing ticket is a blocker; if a required index is missing, report it rather than inventing a new tracker layout.

Update the target status and only acceptance boxes justified by the assessment. Preserve descriptions, implementation notes, meaningful dependency sub-bullets, and user edits. Reopening alone does not invalidate every checked criterion; change a box only when the new evidence or agreed scope requires it.

## Recompute affected dependencies

Read tickets that directly require the target and their actual prerequisite statuses. Existing `✅` marks do not decide readiness. Preserve the original individual, range, and `All` notation while evaluating the referenced set from its documented meaning. If a range or `All` is ambiguous, report that uncertainty and do not invent a dependency set.

Reconcile derived success marks in ticket `Requires:` lines and corresponding index cells: add them for completed prerequisites and clear stale ones when a prerequisite is no longer satisfied. Do not rewrite a range as individual IDs or decorate a whole range as complete based on one ticket.

Move a dependent from `blocked` to `pending` only when all its required prerequisites are satisfied and those dependencies explain its blocked state. If reopening invalidates a pending ticket's actual readiness, restore its dependency block. Do not automatically regress in-progress, done, or deferred tickets; report any concrete impact that requires a decision. Contextual/indirect relations inform this assessment but do not become new blocker edges automatically.

## Refresh the index in place

Reconcile the affected rows, dependency cells, existing graph status markers, and summary counts from the ticket files. Preserve the repository's layout and notation. Update the last-updated date when content changes; an otherwise unchanged invocation does not need a timestamp-only edit.

Check ticket/index status agreement, dependency readiness, and summary counts. Re-read the affected content after edits. Fix projections within scope without rewriting unrelated prose or performing a whole-project reprioritization.

## Resume and commit only owned changes

A matching target status is not an early exit. Reconcile stale projections and inspect known uncommitted tracker changes left by a failed earlier attempt. Use the conversation and before/after evidence to identify that scope; do not adopt every dirty ticket file.

Return the exact owned document paths/hunks to the active host's `commit-ticket` workflow. It must preserve unrelated index and working content, including implementation code already staged. Reuse valid verification and let that workflow create one meaningful documentation commit when an intended diff exists.

After a commit error or uncertain result, inspect HEAD and the relevant staged/working content before retrying. If the documents were already committed and all projections agree, report a no-op. Report actual changed/unblocked/reblocked tickets and the commit result; a full list of all pending tickets is optional.
