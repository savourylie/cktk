# [TICKET-NNN] Title

## Status
`pending` | `in-progress` | `done` | `deferred` | `blocked`

## Dependencies
- Requires: #NNN, #NNN (or "None")

## Description
Explain what this ticket accomplishes and why it matters at this point in the sequence:
- What is being built or verified
- Why it comes at this position (what it unlocks or depends on)
- The most critical aspect or risk, if any

1 paragraph for straightforward tickets; up to 2–3 short paragraphs when context is needed (e.g., tickets that gate progress, bridge multiple concerns, or have non-obvious sequencing).

## Acceptance Criteria
- [ ] Criterion 1 — a specific, testable statement
- [ ] Criterion 2
- [ ] Criterion 3

## Design Reference
> Relevant sections from design inputs. Can cite DESIGN.md headings, directory file paths (`system-design/screenshots/hero.png`), page references (`design.pdf p.4`), or Claude Design artifact IDs. Delete this section for non-UI tickets.

- **Tokens**: § Tokens > Colors, Typography
- **Components**: § Components > Buttons
- **Layout**: § Layout > Section Patterns > Hero

## Visual Reference
> Describe what the user should see when this ticket is done. Delete for non-UI tickets.

Example: "The landing page hero section is visible at `/`. Left side shows the heading in Outfit 800 with a yellow circle behind it. Right side shows a placeholder image with blob clip-path. A dot-grid pattern fills the background. The primary CTA button uses the Candy Button style and responds to hover/active with shadow shifts."

## References
> Existing code or documents to imitate, each with a note on what to take from it. Delete this section when the project has no relevant exemplar.

- `src/components/SettingsModal.tsx` — focus trap and escape handling to reuse for the new modal
- `docs/DESIGN.md` § Forms — validation error copy pattern

## Implementation Notes
- Key files to create or modify
- Architectural decisions or assumptions made
- Gotchas or edge cases to watch for

## Testing
- How to verify this ticket is complete (e.g., `npm run dev` and navigate to `/`, run `npm test`, visual check in browser)

---

## Checkpoint Ticket Variant

Checkpoint tickets use the same structure with these modifications:

- **Header**: `# [TICKET-NNN] TEST: Checkpoint N — What's Being Tested` or `# [TICKET-NNN] TEST: Phase N Checkpoint — Phase Summary`
- **Description**: What tests to execute, that this is a gate, and what must pass before proceeding. 2–3 paragraphs: context on what was just built, what this checkpoint verifies, and what is gated by it.
- **Acceptance Criteria**: Specific pass/fail test cases — not code changes. Each criterion is a concrete verification (e.g., "Navigate to `/` — page loads with no console errors").
- **Implementation Notes**: "This is a manual test execution ticket — no code changes unless bugs are found during testing." Include common failure modes, test commands, and environment setup.
- **Testing**: The full verification checklist — this section IS the ticket's primary deliverable. Summarize what must pass and where results should be recorded.
