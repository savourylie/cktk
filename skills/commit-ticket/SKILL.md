---
name: commit-ticket
description: "Stage intended changes and create one well-documented git commit, for ticket work or ad hoc edits. Includes unstaged changes and new files in scope. Use for /commit-ticket, commit changes, commit this, or create a commit."
user-invocable: true
---

# Stage and Commit Changes

Create one commit from the user's intended changes. A ticket is optional: small fixes, maintenance, and other ad hoc work are normal inputs. Invoking this skill authorizes staging and committing the selected work; do not require a ticket, a prepared staging area, or another approval round.

## Resolve the checkout and scope

Use the current request first, then the active conversation or caller's work directory and scope. Otherwise use the current checkout's pending changes. Confirm the repository and branch; when following worktree implementation, operate in that worktree. Select the directory explicitly for every shell call, and use absolute file paths. Do not create or switch branches as a routine commit step.

Read applicable repository instructions and the actual staged, unstaged, and untracked content needed to understand the change. File statistics alone do not establish scope or provide a meaningful message. Consult existing commit conventions or recent history only as needed.

**Default: include both already-staged and not-yet-staged changes within the resolved scope**, including intended new files, modifications, and deletions. A staged-only or path-limited request overrides that default. Without a narrower scope or known exclusions, a general commit request covers the checkout's pending changes; lack of a ticket is not ambiguity.

Preserve changes outside that scope, including existing staging selections. If those changes can be isolated, proceed with the intended work. Ask only when ownership, the target checkout, or separation of overlapping changes is unclear. Untracked status alone does not make a file unrelated; ignored output, local diagnostics, and known unrelated work stay excluded unless specifically requested.

## Stage and verify the commit content

Stage the selected changes without requiring the user to do it. Use explicit paths or hunks when scope is limited; a repository-wide add is appropriate only after establishing that every included change belongs to this commit.

Inspect the actual diff that will be committed, including newly staged files, and check for accidental scope changes or formatting errors. Preserve out-of-scope staging and working-tree content. If unrelated changes are already staged, isolate the intended commit instead of running an ordinary commit that includes the entire index. Do not unstage or reset the whole repository to simplify selection.

Honor existing partial staging when requested; do not add an entire file or use a file-content commit path that would pull excluded hunks back in. If safe isolation cannot be established, ask before changing that selection.

Reuse verification already completed for this content. Run checks required by the repository and checks needed for an unresolved concern; do not repeat a full implementation/review workflow merely because a commit was requested.

## Commit message protocol

Use [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) unless an explicit user message or repository convention requires another format:

```text
<type>[(scope)][!]: <summary>

<body explaining the reason and resulting behavior>

[footers]
```

Use `feat` for new capability and `fix` for a bug correction; otherwise choose the repository's appropriate type, such as `refactor`, `docs`, `test`, or `chore`. Scope is an optional affected component. Mark a breaking change with `!` or a `BREAKING CHANGE:` footer.

The following completeness rules are this skill's quality standard; Conventional Commits does not itself require a body:

- **For substantive changes, include a body by default.** Explain the problem or motivation and the resulting behavior. Add the important decisions, trade-offs, compatibility effects, or migration steps that a future reader needs. Describe the final change rather than narrating the work session or listing filenames.
- Include relevant verification evidence and its limits when available. Distinguish checks actually run from suggested or pending checks, and never invent a passing result. Omit empty headings and repetitive boilerplate; prose or bullets are both suitable.
- A self-explanatory typo, formatting correction, or similarly tiny change can use a subject alone. Choose detail by explanatory value, not a fixed line count. Follow the user's requested language, otherwise the repository convention.
- Ticket references are optional. Use a verified `Refs:` footer when useful; do not demand or invent an ID. Use closing keywords only for an intended, authorized completion. Include only warranted attribution/sign-off trailers, and explain any breaking behavior and required adaptation.

If the user supplied an exact message, preserve it; if it is a draft, improve it within their request. Repository-enforced message requirements still need to be satisfied.

## Commit and report

Create one commit with the reviewed content and complete message. For a multi-paragraph message, write a temporary message file with a file tool and pass it through `git commit -F`, preserving real newlines and literal shell characters. Keep that file outside the staged scope.

Inspect commit or hook failures before deciding the next action. If the commit result is uncertain, check HEAD and git state before retrying. A routine fix within the authorized scope can be verified and retried; preserve remaining work and report blockers. Do not bypass hooks, manufacture an empty commit, amend a previous commit, or change author/signing configuration without authorization.

Verify the resulting commit's hash, full message, and contents, then report its hash and subject plus any intentionally remaining changes or incomplete checks. A request with no intended changes is a no-op. This skill's action is a commit; pushing, PR creation, and tracker updates belong to separately authorized follow-up.
