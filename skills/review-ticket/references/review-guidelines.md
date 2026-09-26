# Code Review Guidelines

## Bug Detection Criteria

Flag an issue only when ALL of the following hold:

1. It meaningfully impacts the accuracy, performance, security, or maintainability of the code.
2. The bug is discrete and actionable (not a general issue with the codebase or a combination of multiple issues).
3. Fixing the bug does not demand a level of rigor absent from the rest of the codebase (e.g., one doesn't need very detailed comments and input validation in a repository of one-off scripts).
4. The bug was introduced in the diff (pre-existing bugs should not be flagged).
5. The author would likely fix the issue if they were made aware of it.
6. The bug does not rely on unstated assumptions about the codebase or author's intent.
7. It is not enough to speculate that a change may disrupt another part of the codebase — to be considered a bug, one must identify the other parts of the code that are provably affected.
8. The bug is clearly not just an intentional change by the original author.

## Comment Construction Guidelines

1. The comment should be clear about why the issue is a bug.
2. The comment should appropriately communicate the severity of the issue. It should not claim that an issue is more severe than it actually is.
3. The comment should be brief. The body should be at most 1 paragraph. Do not introduce line breaks within the natural language flow unless necessary for a code fragment.
4. The comment should not include any chunks of code longer than 3 lines. Any code chunks should be wrapped in markdown inline code tags or a code block.
5. The comment should clearly and explicitly communicate the scenarios, environments, or inputs necessary for the bug to arise. It should immediately indicate that the issue's severity depends on these factors.
6. The comment's tone should be matter-of-fact and not accusatory or overly positive. It should read as a helpful suggestion without sounding too much like a human reviewer.
7. The comment should be written such that the original author can immediately grasp the idea without close reading.
8. The comment should avoid excessive flattery and comments that are not helpful. Avoid phrasing like "Great job ...", "Thanks for ...".

## Quantity and Style

- Output all findings that the author would fix if they knew about it.
- Do not stop at the first qualifying finding. Continue until you've listed every qualifying finding.
- Ignore trivial style unless it obscures meaning or violates documented standards.
- Use one comment per distinct issue.
- Use `suggestion` blocks ONLY for concrete replacement code (minimal lines; no commentary inside the block).
- In every `suggestion` block, preserve the exact leading whitespace of the replaced lines.
- Keep line ranges as short as possible for interpreting the issue — avoid ranges longer than 5-10 lines; pick the most suitable subrange that pinpoints the problem.

## Priority Definitions

- **P0** — Drop everything to fix. Blocking release, operations, or major usage. Only use for universal issues that do not depend on any assumptions about the inputs.
- **P1** — Urgent. Should be addressed in the next cycle.
- **P2** — Normal. To be fixed eventually.
- **P3** — Low. Nice to have.

## False Positive Avoidance

Do NOT flag any of the following:

- **Pre-existing issues** — bugs that existed before the diff; only flag issues introduced in the change.
- **Linter/typechecker-catchable issues** — missing imports, type errors, formatting issues, pedantic style (newlines, spacing). Assume CI will catch these.
- **Intentional changes** — changes in functionality that are likely intentional or directly related to the broader change.
- **Pure style or naming preferences** — nits that change no behavior, test result, or reader's understanding.
- **Issues on unmodified lines** — real issues on lines the author did not modify.
- **Lint-ignored code** — issues explicitly silenced with lint-ignore or equivalent comments.
- **General code quality** — lack of test coverage, general security posture, poor documentation, unless explicitly required in CLAUDE.md.
- **Speculative breakage** — speculation that a change "might" break something without identifying the provably affected code.
