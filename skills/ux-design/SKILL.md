---
name: ux-design
description: >
  UX design specification generator that transforms a PRD into a comprehensive UX design document
  using a 6-pass forced designer mindset. Reads docs/PRD.md (required) and docs/FEATURES.md (optional
  structured feature catalog) as inputs, writes docs/UX_DESIGN.md as output. Use when the user wants
  to create UX design documentation, UX specifications, wireframes, user flows, or design artifacts
  from a PRD. Triggers on requests like "create UX design", "generate UX spec from PRD", "UX
  foundations from requirements", "turn PRD into UX design", or any mention of translating product
  requirements into UX deliverables.
---

# UX Design Specification Generator

Transform a PRD into a UX design specification using **6 forced designer mindset passes**. Each pass asks different questions that visual-first approaches skip. UX foundations come BEFORE visual specifications.

## The Iron Law

```
NO VISUAL SPECS UNTIL ALL 6 PASSES COMPLETE
```

**Not negotiable:**
- Don't mention colors, typography, or spacing until Pass 6 is done
- Don't describe screen layouts until information architecture is explicit
- Don't design components until affordances are mapped

**No exceptions for urgency:**
- "I'm in a hurry" -- Passes take minutes; fixing bad UX takes days
- "Just give me screens" -- Screens without foundations need rework
- "Skip the analysis" -- Analysis IS the value; screens are just output
- "The PRD is simple enough" -- Simple PRDs still need mental model analysis

Skipping passes to "save time" produces specs that need redesign. The 6 passes ARE the shortcut.

## Input

- **`docs/PRD.md`** (required) -- The product requirements document. Read as-is.
- **`docs/FEATURES.md`** (optional) -- A structured feature catalog with categorized features and descriptions. When present, it provides granular, categorized feature data that feeds directly into the passes -- especially Pass 2 (IA) and Pass 3 (Affordances).

## Output

**Write the UX specification to `docs/UX_DESIGN.md`.** Do not output to conversation. Always write to file so the spec is persistent and can be passed to mockup tools.

## Workflow

1. Read `docs/PRD.md`
2. Read `docs/FEATURES.md` if present
3. Execute all 6 passes sequentially (see `references/passes.md` for full details)
4. After all passes complete, generate visual specifications using pass outputs as foundation
5. Assemble everything into `docs/UX_DESIGN.md`

## The 6 Passes

Execute IN ORDER. Each pass produces required outputs before the next begins.

| Pass | Designer Mindset | Key Question |
|------|-----------------|--------------|
| 1. User Intent & Mental Model | "What does the user think is happening?" | Misconceptions, mental model alignment |
| 2. Information Architecture | "What exists, and how is it organized?" | Concept inventory, grouping, classification |
| 3. Affordances & Action Clarity | "What actions are obvious without explanation?" | Clickable, editable, read-only, final vs in-progress |
| 4. Cognitive Load & Decision Minimization | "Where will the user hesitate?" | Friction points, simplifications, defaults |
| 5. State Design & Feedback | "How does the system talk back?" | Empty, Loading, Success, Partial, Error per element |
| 6. Flow Integrity Check | "Does this feel inevitable?" | Flow risks, visibility decisions, UX constraints |

For the full procedure, required outputs, and examples for each pass, read `references/passes.md`.

## Execution Rules

- **Show progress.** At the start of each pass, show: `[Pass N/6: Pass Name]`
- **No per-pass feedback.** Complete all 6 passes before presenting work. The passes build on each other -- interrupting creates incomplete analysis.
- **Write to file.** Output goes to `docs/UX_DESIGN.md`, not conversation.
- **Single review checkpoint.** After the full spec is written, present a summary and ask the user if they want revisions.

## Output Template

```markdown
# UX Design: [Product Name]

> Generated from: docs/PRD.md
> Feature catalog: docs/FEATURES.md | N/A
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

If you catch yourself doing any of these, STOP and return to the passes:

| Violation | What You're Skipping |
|-----------|---------------------|
| Describing colors/fonts | All foundational passes |
| "The main screen shows..." | Pass 1-2 (mental model, IA) |
| Designing components before actions mapped | Pass 3 (affordances) |
| No friction point analysis | Pass 4 (cognitive load) |
| States only in component specs | Pass 5 (holistic state design) |
| No "where could they fail?" | Pass 6 (flow integrity) |
| "User is in a hurry" | ALL passes -- urgency is a trap |
| "Just this once, skip to visuals" | ALL passes -- exceptions become habits |
| "The PRD is simple enough" | ALL passes -- simple PRDs still need mental model analysis |

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
