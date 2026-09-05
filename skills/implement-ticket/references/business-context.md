# Business context before implementation

Read this for every ticket. The required outcome is an evidence-backed understanding of the ticket's place in the project, sufficient to make business-correct implementation decisions. A long report or a complete backlog audit is not required.

## Find the governing context

Start with the ticket and the project's stated purpose, users, business scope, and current goals. Follow relevant product requirements, project context, architecture/domain documents, and recorded decisions. Read the code to understand what is implemented today, while distinguishing current behavior from intended behavior.

Use sources already identified in the conversation and ticket. If `.ai/cktk/project.json` exists in the selected checkout or main repository, read the [project bindings contract](../../init-project/references/project-schema.md) before using it. Check schema version and each relevant binding's status. Use compatible validated or read-only bindings for discovery; respect read-only restrictions. A binding for a different project does not override the issue's actual project. Do not initialize or rewrite bindings as part of implementation.

Read the relevant project description, Project Context document, canonical product specification, and decision records when they govern this ticket. Follow linked decisions or search for the affected business concept; avoid loading an entire decision log. Without bindings, use ticket links, repository documents, and focused project searches. Missing a particular document is not a blocker if other evidence establishes the required context.

## Trace direct and indirect ticket relationships

Find relationships from both recorded links and the business flow:

- **Direct:** prerequisites and dependents, parent/sub-issues, explicit related issues, and tickets that supply or consume this ticket's output. Explain the relationship and what it means for the change.
- **Indirect:** follow those connections and search for work sharing the affected business process, entity, state transition, permission rule, data contract, or user journey. A ticket can constrain this change even when no tracker relation was added.
- Include relevant completed work and its decisions, not just open tickets. A canceled issue is not proof that its promised capability was delivered.
- Distinguish formal blocker edges from contextual relationships and inferred impact. Name the evidence for inference; do not invent links or convert every related ticket into a blocking dependency.

For local tickets, use relevant tracker entries, ticket bodies, `Requires:` references, and reverse references with exact identifier boundaries. For Linear, inspect issue relations and parents/sub-issues, then perform focused searches in the relevant project or team. Follow pagination when relevant results extend beyond the first page. Open full bodies and comments where they affect the requirement; matching a title alone is not enough.

Expand until the relevant business flow, upstream assumptions, and downstream effects can be explained, and no unresolved relationship materially changes behavior, acceptance, or prerequisites. There is no fixed ticket count or hop limit. Do not recursively read unrelated work. If no direct or indirect relationships are found, say what was checked rather than claiming the ticket is universally independent.

## Explain the role and check consistency

Before coding, give a concise account of:

- the project/business goal and whose workflow this ticket changes;
- the outcome this ticket owns, and the boundaries owned by other tickets;
- directly and indirectly related ticket IDs, the relationship paths or shared business rules, and implementation implications;
- the acceptance behavior, consequential assumptions, and any unresolved evidence gaps.

Compare the ticket's definitions and acceptance criteria against this context. Look for differences in business meaning, scope, ownership, permissions, lifecycle states, data interpretation, or the intended end-to-end experience. Separate requirements from optional implementation suggestions.

**A substantive contradiction requires user clarification before implementation continues.** Show the ticket statement and the conflicting source, explain the competing behaviors and their consequences, and ask for the decision that resolves them. An explicit resolution already given by the user remains valid; a generic instruction to implement does not authorize choosing a side. Pause dependent code changes, delegation, state changes, and completion actions until resolved. Preserve work already done if the conflict appears later.

If available evidence cannot establish the ticket's business role or a consequential related-ticket constraint, identify the missing information and ask rather than inventing context. Nonessential gaps can be disclosed while proceeding. Carry the agreed context into the implementation, delegated task, review, and final explanation; do not expand the implementation to neighboring tickets without authorization.
