---
name: "implement-ticket"
description: "Use when the user explicitly asks to implement one or more backlog tickets from docs/tickets. Prefer explicit invocation with $implement-ticket."
---

# Implement Backlog Tickets

Work through the project's ticket tracker and implement the requested ticket or tickets end to end. Treat this as an explicit workflow skill because it writes code, runs checks, and may commit changes.

If the user included a ticket identifier after `$implement-ticket`, implement only that ticket. Otherwise work through the pending backlog in order until you hit a blocker or finish the remaining tickets.

## Phase 1: Understand the Project

1. Read `docs/PRD.md`.
2. Read `docs/DESIGN.md`.
3. Build a working mental model of the product requirements, architecture, constraints, and acceptance criteria before changing code.

## Phase 2: Pick the Ticket

1. Read `docs/tickets/INDEX.md`.
2. If the user named a ticket, select it even if it is out of order.
3. Otherwise pick the next ticket that is not done, respecting ordering and dependencies.
4. Read the full ticket file before you start coding.
5. If the selected ticket is already done, report that and stop.

## Phase 3: Implement

1. State what you are about to implement, which files you expect to touch, and the main risks.
2. Implement the ticket fully against the ticket requirements and `docs/DESIGN.md`.
3. Follow project conventions and add tests whenever the repo has a test suite or the ticket implies testable behavior.
4. Handle edge cases and integration details before moving on.

## Phase 4: Validate

1. Run the relevant lint, type-check, test, and build commands for the repo.
2. Fix every regression introduced by the ticket.
3. Perform a review pass against the same rubric used by the review workflow:
   - read `../review-ticket/references/review-guidelines.md`
   - review only the diff introduced by the ticket
   - look for correctness issues, missing acceptance criteria, risky edge cases, and regressions
4. If the review pass finds issues, fix them and rerun the checks.

## Phase 5: Commit

1. Stage the files for the ticket.
2. Create one commit with a clear conventional message such as:

```text
feat(TICKET-ID): short summary

- key change
- key change
```

3. Do not mix unrelated changes into the ticket commit.

## Phase 6: Update Ticket Status Directly

Perform the ticket status update yourself instead of delegating to another skill:

1. Update the ticket file status under `## Status`.
2. If marking the ticket done, check all acceptance criteria in that ticket file.
3. Refresh `docs/tickets/INDEX.md`:
   - update the target ticket row
   - mark satisfied single-ticket dependencies
   - update any newly unblocked tickets from `blocked` to `pending`
   - refresh summary counts
   - refresh any existing dependency graph markers already present in the file
   - update the "Last updated" date
4. Verify the index is internally consistent before you finish.

## Phase 7: Loop or Stop

- If the user named a specific ticket, stop after Phase 6.
- Otherwise continue with the next pending ticket until all tickets are done or you hit a real blocker.

## Safety Rules

- If `docs/PRD.md`, `docs/DESIGN.md`, or the ticket tracker files are missing, stop and report the missing inputs.
- If a dependency is unresolved, do not implement a blocked ticket out of order.
- If unrelated user changes conflict with the ticket, stop and ask how to proceed instead of overwriting them.

