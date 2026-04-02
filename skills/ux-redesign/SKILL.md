---
name: ux-redesign
description: >
  UX redesign skill that audits an existing codebase against its UX design spec and PRD,
  produces a comprehensive audit report at docs/reports/UX_DESIGN_REPORT.md, then rewrites
  docs/UX_DESIGN.md with layout improvements using 6 forced designer mindset passes adapted
  for redesign context. Requires docs/PRD.md, docs/FEATURES.md, and docs/UX_DESIGN.md to
  already exist. Inspects the actual codebase routes, layouts, and components (code only) to
  compare implementation against spec. Use when the user wants to audit their UX implementation,
  redesign an existing UX spec, compare their codebase against UX design, improve an existing
  UX_DESIGN.md, or run a UX gap analysis. Triggers on: "redesign UX", "audit UX implementation",
  "compare code to UX spec", "improve UX design", "UX gap analysis", "UX audit", or any mention
  of evaluating or improving an existing UX design based on codebase implementation.
---

# UX Redesign: Audit & Improve

Audit an existing codebase against its UX spec, then redesign. Uses the same **6 forced designer mindset passes** as `/ux-design`, adapted for evaluating what was built and deciding what should change.

## The Iron Law

```
NO REDESIGN UNTIL AUDIT IS COMPLETE
NO VISUAL SPECS UNTIL ALL 6 PASSES COMPLETE
```

**Two gates, both non-negotiable:**

1. **Gate 1:** Write the full audit report before starting any redesign pass
2. **Gate 2:** Complete all 6 redesign passes before generating visual specifications

**No exceptions:**
- "Just fix the obvious stuff" -- The audit catches non-obvious stuff too
- "The code is close enough to spec" -- Then the audit will confirm that quickly
- "Skip the audit, I know what's wrong" -- You know what's VISIBLE. The audit finds what's hidden.
- "The PRD hasn't changed" -- The implementation may have drifted from both PRD and spec

## Input

All four inputs are **required:**

- **`docs/PRD.md`** -- Product requirements. The ground truth for what matters.
- **`docs/FEATURES.md`** -- Structured feature catalog with categorized features.
- **`docs/UX_DESIGN.md`** -- Existing UX design spec (created by `/ux-design` or manually). This is what you evaluate against.
- **Current codebase** -- Routes, layouts, page components, shared components. Code only.

**Gate check:** If any of the three docs are missing, STOP and tell the user which files need to exist. Suggest running `/ux-design` first if `docs/UX_DESIGN.md` does not exist.

## Output

Two files, written in order:

1. **`docs/reports/UX_DESIGN_REPORT.md`** -- Full audit report. Written first, during Step 5. This is a permanent artifact.
2. **Updated `docs/UX_DESIGN.md`** -- Redesigned UX spec. Written second, after all 6 passes. The redesign can be dramatically different from the original.

Create the `docs/reports/` directory if it does not exist.

## Workflow

| Step | Phase | What Happens |
|------|-------|-------------|
| 1 | Read | Read `docs/PRD.md` |
| 2 | Read | Read `docs/FEATURES.md` |
| 3 | Read | Read `docs/UX_DESIGN.md` |
| 4 | Inspect | **Codebase Inspection** -- discover framework, routes, layouts, components (see `references/codebase-inspection.md`) |
| 5 | Audit | **Gap Analysis** -- compare implementation against spec and PRD. Write `docs/reports/UX_DESIGN_REPORT.md` (see `references/audit-report-template.md`) |
| 6 | Redesign | **Execute all 6 passes** sequentially using audit findings as input (see `references/redesign-passes.md`) |
| 7 | Assemble | Generate visual specifications from pass outputs. Write updated `docs/UX_DESIGN.md` |

## Codebase Inspection (Step 4)

Three sub-phases. Full details in `references/codebase-inspection.md`.

1. **Framework Detection** -- identify the routing framework (Next.js, React Router, Vue, SvelteKit, Remix, etc.)
2. **Route Discovery** -- enumerate all pages/routes, dynamic routes, layouts, middleware
3. **Component Analysis** -- read layouts, shared components, navigation, state management

**Scope:** Read page components, layouts, shared UI, navigation, forms, state management. Skip API internals, tests, config, node_modules, .pen files.

## The 6 Redesign Passes (Step 6)

Same 6 passes as `/ux-design`, adapted for redesign context. Each pass evaluates what exists before deciding what should change.

| Pass | Designer Mindset | Redesign Key Question |
|------|-----------------|----------------------|
| 1. User Intent & Mental Model | "What does the user think is happening?" | Does the implementation match or mislead the user's mental model? |
| 2. Information Architecture | "What exists, and how is it organized?" | Does the implemented IA match the spec? Where has it drifted? |
| 3. Affordances & Action Clarity | "What actions are obvious without explanation?" | Which affordances are ambiguous, missing, or misleading? |
| 4. Cognitive Load & Decision Minimization | "Where will the user hesitate?" | Where does the implementation add unnecessary friction? |
| 5. State Design & Feedback | "How does the system talk back?" | Which states are missing, broken, or inadequate? |
| 6. Flow Integrity Check | "Does this feel inevitable?" | Where do the implemented flows break, dead-end, or confuse? |

For full procedures, required outputs, and redesign-specific guidance for each pass, read `references/redesign-passes.md`.

## Execution Rules

- **Show progress.** At each phase transition, show:
  - `[Phase: Reading Inputs]`
  - `[Phase: Codebase Inspection]`
  - `[Phase: Audit]`
  - `[Pass N/6: Pass Name]`
  - `[Phase: Visual Specifications]`
- **Write audit BEFORE redesign.** Gate 1 is enforced -- `docs/reports/UX_DESIGN_REPORT.md` must be written before Pass 1 starts.
- **No per-pass feedback.** Complete all 6 passes before presenting work.
- **Write to file.** Both outputs go to files, not conversation.
- **Single review checkpoint.** After both files are written, present a summary and ask the user if they want revisions.
- **Preserve what works.** The redesign should amplify implementation improvements found during the audit, not just fix gaps.

## Output Template (UX_DESIGN.md)

```markdown
# UX Design: [Product Name]

> Redesigned from: docs/UX_DESIGN.md (previous version)
> Audit report: docs/reports/UX_DESIGN_REPORT.md
> Sources: docs/PRD.md, docs/FEATURES.md, codebase inspection
> Date: [date]

---

## Part I: UX Foundations

### 1. User Intent & Mental Model
[Pass 1 output]

### 2. Information Architecture
[Pass 2 output]

### 3. Affordances & Action Clarity
[Pass 3 output]

### 4. Cognitive Load & Decision Minimization
[Pass 4 output]

### 5. State Design & Feedback
[Pass 5 output]

### 6. Flow Integrity Check
[Pass 6 output]

---

## Part II: Visual Specifications

### 7. Sitemap & Navigation Structure
[ASCII sitemap and navigation hierarchy]

### 8. User Flows
[ASCII flow diagrams for key journeys]

### 9. Screen Wireframes
[ASCII wireframes for key screens]
- Content priority per screen
- Component identification
- Responsive considerations

### 10. Annotated Wireframes
[ASCII wireframes with numbered callouts]
- Error states
- Loading states
- Edge cases
- Design rationale
```

## Red Flags -- STOP and Restart

If you catch yourself doing any of these, STOP and return to the correct phase:

| Violation | What You're Skipping |
|-----------|---------------------|
| Redesigning before audit is written | Gate 1: the entire codebase analysis |
| Describing colors/fonts before Pass 6 | All foundational passes |
| "The main screen shows..." before Pass 1-2 | Mental model and IA analysis |
| Designing components before actions mapped | Pass 3 (affordances) |
| No friction point analysis | Pass 4 (cognitive load) |
| States only in component specs | Pass 5 (holistic state design) |
| No "where could they fail?" | Pass 6 (flow integrity) |
| Ignoring existing implementation | The point of this skill -- redesign is grounded in reality |
| Copy-pasting original UX_DESIGN.md | Every section should reflect audit findings |
| Skipping codebase inspection | Can't compare spec to reality without reading reality |

## ASCII Visual Conventions

Use these conventions for all diagrams and wireframes in Part II:

```
Boxes:        +---------------+    Arrows:    -->  ==>
              |  Content      |               |
              +---------------+               v

Wireframe:    +----------------------------+
              | +------+  Logo    [Nav]    |
              | +------+                   |
              | +------------------------+ |
              | |    Hero Section        | |
              | +------------------------+ |
              | [CTA Button]              |
              +----------------------------+

Flow:         [Start] --> [Step 1] --> [Decision?]
                                          |    |
                                         Yes   No
                                          |    |
                                          v    v
                                        [A]   [B]

Sitemap:      Home
              +-- About
              +-- Products
              |   +-- Category A
              |   +-- Category B
              +-- Contact
```
