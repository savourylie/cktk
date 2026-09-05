# Index format

Use the table columns and status spelling below. This example has two tickets; replace its content and counts with the actual backlog. A small set can use one work table; add phase or theme sections when they help navigation.

```markdown
# Ticket Index

> **Last updated**: YYYY-MM-DD

## Summary

| Status | Count |
| --- | --- |
| ✅ Done | 0 |
| 🔧 In Progress | 0 |
| 📋 Pending | 1 |
| 🚫 Blocked | 1 |
| ⏸️ Deferred | 0 |

## Phase 1 — Account access

| # | Ticket | Status | Depends On | Notes |
| --- | --- | --- | --- | --- |
| 001 | [Account recovery](./001-account-recovery.md) | `pending` | — | |
| 002 | [Recovery audit trail](./002-recovery-audit-trail.md) | `blocked` | #001 | |

## Status Key

| Status | Meaning |
| --- | --- |
| `pending` | Ready to start; all dependencies met |
| `in-progress` | Currently being implemented |
| `done` | Implemented and verified |
| `blocked` | Waiting on a dependency |
| `deferred` | Intentionally postponed; reason noted |
```

Use relative ticket links and backtick-wrapped statuses. In new rows, mirror the ticket's individual dependency IDs and completed markers, for example `#001 ✅, #002`. A dependent remains `blocked` until all prerequisites are `done`.

When a checkpoint is needed, make its linked title bold and put its actual gate scope in Notes, such as `Gate: Phase N`, `Gate: Final`, or `Gate: Account recovery release`. Only tickets that depend on that verification wait for it. Omit checkpoint commentary when no checkpoints exist.

On append, preserve existing sections, rows, statuses, notes, the status key, and commentary. Add the new rows or sections, recount all status totals, and update the date. Do not reformat an existing tracker merely to match this example.
