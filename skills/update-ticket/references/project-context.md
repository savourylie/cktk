# Optional Linear Project Context reconciliation

Use only for an eligible Project Context sync. Read the [bindings contract](../../init-project/references/project-schema.md); it owns schema/version rules, per-binding status, document identity, and write boundaries. Use the binding for the issue's actual project. Missing, incompatible, unvalidated, disabled, or read-only bindings do not block the issue status update and are not an invitation to initialize anything.

## Scope and authorization

This follows `preferences.sync_project_context`, independently of `write_decision_log`. Honor existing authorization; `always` permits the scoped sync, `never` prevents it, and `ask` requires consent only if not already granted for this work. Prepare the actual proposed patch before asking. A clear Done transition proceeds first and does not need another confirmation.

Read only as much of the bound document as needed to locate and assess its permitted `state_sections`. The Project Context is a Linear **Document**, never the project description. Do not create a substitute document, reparent it, or write the project description. Sections owned by repository or Notion content remain outside this sync even if listed in the binding.

Update statements in those state sections that verified current Linear facts contradict: the issue's own status, actual blocker/readiness changes, and recorded milestone progress. A repeat invocation may reconcile stale content even when the issue status did not change this time.

Verify every stated milestone figure in a touched state section against actual Linear data, including figures used as anchors. Preserve surrounding true information. A changed percentage does not by itself establish why it changed; do not invent a rationale or rewrite an unsupported explanation. Name a stale or disconnected explanation in the summary with the relevant figure. Leave ambiguous claims unchanged.

Update an existing last-synced marker only when its binding is non-null and a sync warrants it. Never add an unconfigured marker. No meaningful difference means no write, not a forced cosmetic update.

## Patch and read back

Discover the current document tool schema. For `save_document`, use its existing document ID and `patch`, never a whole `content` replacement. Follow the bindings contract's unique-anchor, ordered/atomic operation, and 50-operation bounds. Keep every operation inside the allowed sections.

Build anchors from the live serialized text. Issue mentions may serialize as `<issue ...>…</issue>` rather than a bare identifier; use stable ordinary prose instead of anchoring on an issue ID. Use explicit markdown links for issue references in replacements. Preserve actual newlines and supported markup.

If an anchor is stale or a result uncertain, re-fetch the document, identify which requested edits remain, and prepare only those patches. Never retry a write blindly or substitute the project description when patching is unavailable. Read back the result and verify the intended content and untouched section boundaries. Linear may normalize formatting; report a material formatting change if it actually occurred rather than printing a warning on every run.

Report what changed and any unresolved claims or failed operations concisely. If consent is declined, the preference is `never`, or a capability is unavailable, keep the proposed patch available and summarize the unapplied change; print the full patch when useful or requested. Failure here does not undo a successful issue update or block an independently authorized decision-log action.
