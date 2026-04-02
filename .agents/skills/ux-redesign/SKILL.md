---
name: "ux-redesign"
description: "Audit a codebase against its UX spec and PRD, then redesign the UX using 6 adapted passes. Use for prompts like redesign the UX, audit UX implementation, or update UX spec from code."
---

# UX Redesign

Audit an existing codebase against its UX spec and PRD, produce a gap report, then rewrite the UX design specification using six redesign-adapted passes.

## Argument Parsing

Parse any text that follows `$ux-redesign`. No arguments are required.

## Inputs

| File | Required | Purpose |
|------|----------|---------|
| `docs/PRD.md` | Yes | Product requirements — ground truth for what matters |
| `docs/FEATURES.md` | Yes | Structured feature catalog |
| `docs/UX_DESIGN.md` | Yes | Existing UX spec — what was designed |
| Current codebase | Yes | What was actually built |

**Gate check:** Verify all four inputs exist before proceeding. If any are missing, list what is missing and stop. Do not proceed without all four.

## Outputs

1. **Audit report:** `docs/reports/UX_DESIGN_REPORT.md`
2. **Updated UX spec:** `docs/UX_DESIGN.md` (overwritten)

## Two Iron Gates

1. **No redesign until the audit is complete.** Do not modify `docs/UX_DESIGN.md` until `docs/reports/UX_DESIGN_REPORT.md` is written and the user has seen the summary.
2. **No visual specs until all 6 redesign passes are complete.** Same rule as `$ux-design`: passes produce UX foundations only.

## Workflow

| Phase | Name | Action |
|-------|------|--------|
| 1 | Read | Read all four inputs: PRD, FEATURES, UX_DESIGN, codebase |
| 2 | Inspect | Discover framework, routes, layouts, components, and state management |
| 3 | Audit | Compare spec against implementation across all 6 UX dimensions |
| 4 | Redesign | Run 6 redesign-adapted passes informed by audit findings |
| 5 | Assemble | Write updated `docs/UX_DESIGN.md` |

## Phase 1 — Read

Read these files in full:

1. `docs/PRD.md`
2. `docs/FEATURES.md`
3. `docs/UX_DESIGN.md`

## Phase 2 — Inspect Codebase

Systematically discover what was built. Read `./references/codebase-inspection.md` for the full procedure.

### Framework Detection

Check in priority order, stop at first match:

| File/Pattern | Framework |
|-------------|-----------|
| `app/layout.tsx` or `app/page.tsx` | Next.js App Router |
| `pages/_app.tsx` or `pages/_document.tsx` | Next.js Pages Router |
| `createBrowserRouter` or `<Routes>` in source | React Router |
| `nuxt.config.*` and `pages/*.vue` | Nuxt.js |
| `svelte.config.*` and `src/routes/+page.svelte` | SvelteKit |
| `remix.config.*` or `app/routes/*.tsx` | Remix |

### Route Discovery

Enumerate all routes for the detected framework. Build a route inventory table.

### Component Analysis

Read root layouts, nested layouts, page components, shared components, and state management patterns. For each, extract: purpose, key UI elements, navigation links, states handled.

## Phase 3 — Audit

Compare the UX spec against the codebase across all six UX dimensions. For each dimension, identify:

- **Gaps:** spec says X, code does not.
- **Divergences:** spec says X, code does Y instead.
- **Additions:** code does X, spec does not mention it.
- **Positive divergences:** code improved on the spec.

Write the audit report to `docs/reports/UX_DESIGN_REPORT.md`. Use the template from `./references/audit-report-template.md`.

The report includes:
1. Executive summary with alignment score and finding counts.
2. Implementation inventory (routes, components, navigation).
3. Gap analysis by UX dimension (6 sections, one per dimension).
4. Positive divergences to preserve.
5. PRD and feature compliance check.
6. Prioritized recommendations (critical, major, minor, preserve).

After writing the report, print a summary to the console: alignment score, finding counts by severity, and the report path. Pause here. The user must see the audit before redesign begins.

## Phase 4 — Redesign

Run six redesign-adapted passes. Each pass keeps the same designer mindset as the original `$ux-design` passes but adds a comparison layer: what was specified vs what was built vs what should be.

Read `./references/redesign-passes.md` for full pass details and output templates.

### The 6 Redesign Passes

| # | Pass | Designer Mindset | Redesign Key Question |
|---|------|-----------------|----------------------|
| 1 | User Intent & Mental Model | "What does the user think is happening?" | Does the implementation match or mislead the user's mental model? |
| 2 | Information Architecture | "What exists, and how is it organized?" | Does the implemented IA match the spec? Where has it drifted? |
| 3 | Affordances & Action Clarity | "What actions are obvious without explanation?" | Which affordances in the code are ambiguous, missing, or misleading? |
| 4 | Cognitive Load & Decision Minimization | "Where will the user hesitate?" | Where does the implementation add unnecessary friction? |
| 5 | State Design & Feedback | "How does the system talk back?" | Which states are missing, broken, or inadequate in the implementation? |
| 6 | Flow Integrity Check | "Does this feel inevitable?" | Where do the implemented flows break, dead-end, or confuse? |

For each pass:

1. Print a progress header: `## Redesign Pass N/6: [Name]`
2. Pull the relevant section from the existing `docs/UX_DESIGN.md`.
3. Pull the relevant audit findings from the report.
4. Evaluate divergences: keep spec, keep code, or design something new.
5. Produce the redesigned output for that pass.
6. Move to the next pass immediately. Do not pause between passes.

After all six passes, pause for a single review checkpoint.

## Phase 5 — Assemble

Write the updated `docs/UX_DESIGN.md` with the same two-part structure:

```
# UX Design Specification (Redesigned)

## Part I: UX Foundations
### 1. User Intent & Mental Model
### 2. Information Architecture
### 3. Affordances & Action Clarity
### 4. Cognitive Load & Decision Minimization
### 5. State Design & Feedback
### 6. Flow Integrity Check

## Part II: Visual Specifications
### Screen-by-Screen Specs
### Component Library
### Responsive Behavior
### Interaction Patterns
```

Every section must reflect audit findings. If a section is unchanged from the original spec, explicitly state: "Preserved from original spec: implementation matches intent."

## Behavior Rules

- Respect the two iron gates. No redesign before audit. No visuals before passes.
- If an implementation improved on the spec, preserve it. Do not force the code back to match an inferior spec.
- Factor engineering complexity into redesign decisions. A buildable UX beats a perfect UX that will not ship.
- Do not copy-paste from the original spec. Every section must show evidence of audit-informed reasoning.
- Show pass progress headers so the user can follow along.
- After writing the final spec, print a summary: changes from original spec, preserved sections, and both output file paths.
