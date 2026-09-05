# Linear issue content and fields

Use a concise outcome-based title without a hand-assigned ticket number. Adapt the body below to the work. Keep acceptance checkboxes and a verification section so implementation, review, and status-update skills can evaluate completion. Omit optional sections that add no useful context.

```markdown
## Description
The outcome, why it matters, and relevant scope boundaries.

## Acceptance Criteria
- [ ] An observable completion condition.

## Implementation Notes
- Required constraints: agreed decisions or project requirements.
- Suggested approach: useful options the implementing agent may adapt.

## Testing
Relevant checks, expected results, and any manual acceptance needed.

## References
- Source document or existing repository path — what to take from it.
```

For UI work, add relevant design references and observable visual or interaction outcomes. A short `## Dependencies` section may explain why a prerequisite is needed, using real issue identifiers/links once known; the native relation is authoritative. Cite existing sources, use repository-relative paths, and include enough requirement context in the body that an implementer does not need this conversation to understand the issue.

Use the host's current Linear tool schemas. Common capabilities include `list_issues`, `get_issue`, `list_issue_statuses`, and `save_issue`; names and accepted fields may differ by connector.

| Concern | Native representation |
| --- | --- |
| Identity | Linear assigns the internal ID, identifier such as `ENG-42`, and URL. |
| Required creation fields | A resolved team and title; include the prepared description and the project when selected. |
| Create versus update | With `save_issue`, omitting `id` creates; supplying an existing `id` updates. Never mistake a retry for a new creation. |
| Initial state | Team's configured creation default, or a requested/project-conventional state resolved from that team's statuses. State names vary; use returned IDs and types. |
| Prerequisite A, dependent B | B is `blockedBy` A; equivalently A `blocks` B. Set one direction and verify the relation. |
| Hierarchy | `parentId` groups work. It does not establish a blocking prerequisite. |
| Optional planning fields | Resolve real project, assignee, priority, label, cycle, milestone, or parent values when justified; omit invented metadata. |

For a batch, use local planning handles to order creation and map each handle to its returned ID/identifier/URL. Replace dependency placeholders with those actual values. When a tool only supports relations after creation, make a separate relation write and verify it. Read whether relation lists add or replace entries before updating; preserve unrelated edges.

A checkpoint is a normal issue titled `TEST: <outcome to verify>`. Its body states the additional verification, pass/fail criteria, and which work waits for it. Use suitable automated or manual checks; number checkpoints only when following an established project convention. It does not require a new status, label, milestone, or parent issue.
