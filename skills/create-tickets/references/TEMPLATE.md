# Ticket format

Use `NNN-kebab-case-title.md` and the structure below. Replace example text with the actual ticket. Keep Status, Dependencies, Description, Acceptance Criteria, and Testing. Include the other sections only when they add useful context.

Choose one status: `pending`, `in-progress`, `done`, `deferred`, or `blocked`. New tickets are `pending` when there are no unfinished prerequisites, otherwise `blocked`.

Dependencies use `- Requires: None` or individual IDs such as `- Requires: #001 ✅, #002`. Add ` ✅` only to prerequisites recorded as `done`; this marker is used by status-update skills to unblock dependents. Mirror the same IDs and markers in the index.

```markdown
# [TICKET-NNN] Title

## Status
`pending`

## Dependencies
- Requires: None

## Description
The outcome, why it matters, and any context needed to understand its scope.

## Acceptance Criteria
- [ ] An observable, testable completion condition.

## Design Reference
Relevant design sections, supplied URLs, file paths, or document pages.

## Visual Reference
What the user should see or experience, including relevant interaction states.

## References
- An existing code or document path — the specific pattern or constraint to take from it.

## Implementation Notes
- Required constraints: agreed decisions or project requirements.
- Suggested approach: useful implementation options that may be adjusted.

## Testing
How to verify acceptance: relevant commands, interactions, and expected results.
```

Acceptance criteria cover the necessary behavior without a numerical quota. Description length follows the context needed. For UI work, include applicable design sources and observable visual or interaction outcomes; do not invent a design reference when none was supplied.

Verify paths cited as existing references. Identify proposed new files as proposals in Implementation Notes. Keep established constraints separate from suggestions, and omit speculative steps or empty sections.

## Checkpoint variant

Create a checkpoint only when the breakdown calls for a separate verification gate.

- **Filename:** `NNN-test-checkpoint-N-kebab-description.md` or `NNN-test-phaseN-checkpoint.md`.
- **Header:** `# [TICKET-NNN] TEST: Checkpoint N — What's Being Tested` or `# [TICKET-NNN] TEST: Phase N Checkpoint — Phase Summary`.
- **Description:** Why this needs separate verification, what it covers, and which work waits for the result.
- **Dependencies:** The tickets whose outcomes are required for the verification.
- **Acceptance Criteria:** Observable pass/fail results.
- **Testing:** Suitable automated checks, manual checks, or both, including necessary setup and where results should be recorded. Specify any user acceptance required.
- **Implementation Notes:** Relevant test setup, constraints, or missing verification support when useful. Do not assume every checkpoint is manual or that it cannot include test code.
