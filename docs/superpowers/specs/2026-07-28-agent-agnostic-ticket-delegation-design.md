# Agent-Agnostic Ticket Delegation Design

## Goal

Allow `implement-ticket` and `implement-ticket-linear` to delegate the implementation phase to a supported CLI coding agent while retaining the invoking host as the verifier, ticket reviewer, and landing coordinator.

## Scope

The first release supports Codex, Claude Code, and Grok Build as target executors. It applies only to the two implement-ticket skill families and their three host trees. Existing invocations without delegation keep their current behavior.

## Invocation

Both skills accept an explicit trailing executor clause:

```
<ticket> [worktree] [base] via <codex|claude|grok>
```

Examples:

```
implement-ticket 123 worktree via claude
implement-ticket-linear ABC-123 dev via codex
```

`via` is reserved and case-insensitive. A missing executor after `via`, an unknown executor, duplicate executor clauses, or tokens after the executor name are invocation errors. The explicit clause prevents executor names from being interpreted as base branches.

## Architecture

A shared, host-neutral delegation adapter owns CLI discovery, request construction, invocation, bounded waiting, and local run-record creation. The two implementation skills own their tracker-specific setup and resume their existing lifecycle after the adapter returns.

Each executor adapter declares:

- CLI discovery and version check;
- a non-interactive invocation contract;
- the prompt format and supported working-directory argument;
- exit-status normalization;
- a bounded wait policy; and
- a sanitized local record containing executor name, start/end state, exit outcome, and captured output location.

The adapter never commits, pushes, changes ticket status, deletes worktrees, or changes branches.

## Workflow

1. The calling skill parses the ticket and optional `via` clause, then performs its normal repository, branch, and worktree setup.
2. Before implementation, it asks the adapter to verify that the requested target CLI is installed and usable. Delegation to the currently running host is rejected, because the native implementation path already covers that case.
3. The adapter creates a task package from the selected ticket, PRD, design source, project conventions, working directory, and a strict implementation-only contract. The target agent must not commit, push, land, change ticket status, or modify unrelated files.
4. The adapter launches the target CLI inside the pinned working directory and waits for it to exit within the configured bound.
5. On a normal completion, the host inspects the working tree and resumes the existing build, ticket review, fix-and-rereview, as-built-notes, and landing phases.
6. On a non-zero exit, timeout, unavailable CLI, or no reviewable change, the host reports the outcome and stops without discarding or committing changes. It may still point the user to the preserved worktree and execution record.

## Verification and Review

The host never accepts a delegated result solely from the target agent's report. It independently runs the project build/type/lint checks and invokes the existing ticket-specific review skill with the ticket identifier. Findings are fixed by the host using its normal process, or surfaced as a blocker when they require a user decision.

## Safety and Failure Handling

- The adapter uses only an explicit allowlist of executor names and invocation templates.
- CLI availability is checked before any task file or command is created.
- Output is stored locally and treated as diagnostic material, not as authoritative task state.
- No automatic retry occurs after a target agent failure or timeout.
- The user retains the existing land choices; delegation does not broaden authority to commit, push, merge, or update ticket status.

## Testing

Automated tests will cover parser compatibility, `via` placement and errors, discovery failures, target-host rejection, invocation construction, successful handoff/resume, non-zero exit, timeout, and unchanged-worktree behavior. The existing skill-tree consistency checker must pass after matching Claude, Codex, and Antigravity files and documentation are updated.

## Out of Scope

This release does not delegate other mutating skills, provide remote agent orchestration, create a general plugin protocol, or allow arbitrary shell commands as executors. New coding agents are added later through a reviewed adapter entry rather than free-form command text.
