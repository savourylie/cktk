---
name: "ux-design"
description: "Transform a PRD into a UX design specification using 6 forced designer mindset passes. Use for prompts like design the UX, create UX spec, or generate UX design."
---

# UX Design

Transform a PRD into a structured UX design specification by executing six forced designer mindset passes before producing any visual specs.

## Argument Parsing

Parse any text that follows `$ux-design`. No arguments are required. If the user specifies a path to a PRD, use that instead of the default.

## Inputs

| File | Required | Purpose |
|------|----------|---------|
| `docs/PRD.md` | Yes | Product requirements — the ground truth |
| `docs/FEATURES.md` | No | Structured feature catalog — enriches every pass |

**Gate check:** If `docs/PRD.md` does not exist, stop and tell the user. Do not proceed without it.

If `docs/FEATURES.md` exists, read it and integrate it into every pass as described below. If absent, derive all feature information from the PRD alone.

## Output

Write the final spec to `docs/UX_DESIGN.md`.

## The Iron Law

**No visual specifications until all 6 passes are complete.** Do not describe screens, layouts, colors, typography, spacing, or component visuals during Passes 1-6. The passes produce UX foundations only. Visual specs come after.

## Execution

Run all six passes in a single uninterrupted sequence. For each pass:

1. Print a progress header: `## Pass N/6: [Name]`
2. Execute the pass using the designer mindset and forced questions below.
3. Produce the required output for that pass.
4. Move to the next pass immediately. Do not pause for feedback between passes.

After all six passes, pause for a single review checkpoint. Present a summary of key decisions from each pass and ask the user to confirm before proceeding to visual specs.

Read `./references/passes.md` for full pass details, output templates, and common mistakes.

## The 6 Passes

| # | Pass | Designer Mindset | Key Question |
|---|------|-----------------|--------------|
| 1 | User Intent & Mental Model | "What does the user think is happening?" | What wrong mental models are likely? |
| 2 | Information Architecture | "What exists, and how is it organized?" | What concepts does the user encounter, and how are they grouped? |
| 3 | Affordances & Action Clarity | "What actions are obvious without explanation?" | What is clickable, editable, read-only, or in-progress? |
| 4 | Cognitive Load & Decision Minimization | "Where will the user hesitate?" | Where can decisions be collapsed, delayed, or defaulted? |
| 5 | State Design & Feedback | "How does the system talk back?" | What does the user see for empty, loading, success, partial, and error states? |
| 6 | Flow Integrity Check | "Does this feel inevitable?" | Where could a first-time user get lost or hit a dead end? |

### Pass 1: User Intent & Mental Model

Identify the user's primary intent, expected mental model, likely misconceptions, and UX principles to reinforce. Produce a mental model diagram.

**FEATURES.md integration:** Feature categories represent mental model clusters. Feature names reveal gaps between naming and user expectations.

### Pass 2: Information Architecture

Enumerate all concepts the user encounters. Group them into logical buckets. Classify each as Primary (always visible), Secondary (on demand), or Hidden (progressive disclosure). Produce an IA hierarchy diagram.

**FEATURES.md integration:** Feature categories become logical buckets. Feature names become concepts. Feature descriptions reveal relationships.

### Pass 3: Affordances & Action Clarity

Map every interactive element to its action type: clickable, editable, read-only, final, or in-progress. Define affordance rules. Identify and resolve ambiguous affordances.

**FEATURES.md integration:** Feature descriptions clarify what users do with each feature.

### Pass 4: Cognitive Load & Decision Minimization

Identify friction points: moments of choice, uncertainty, and waiting. Apply: collapse decisions, delay complexity, introduce defaults. Produce a decision count per flow.

**FEATURES.md integration:** Feature count per category reveals cognitive density. Dense categories need simplification.

### Pass 5: State Design & Feedback

For each major element, enumerate all five states: empty, loading, success, partial, error. For each state, answer: what does the user see, understand, and do next? Produce a state transition diagram.

**FEATURES.md integration:** Every feature needs at least empty, success, and error states mapped.

### Pass 6: Flow Integrity Check

Trace every user flow end-to-end. Identify dead ends, missing back-navigation, and cross-flow dependencies. Decide what must be visible vs implied. Produce UX constraints for the visual phase.

**FEATURES.md integration:** Features spanning multiple categories indicate cross-flow dependencies.

## Output Structure

After the review checkpoint, assemble `docs/UX_DESIGN.md` with this structure:

```
# UX Design Specification

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

Part I contains the outputs from all six passes. Part II translates those foundations into concrete visual specs, respecting every constraint and decision from Part I.

## Behavior Rules

- Show pass progress headers so the user can follow along.
- Do not ask for per-pass feedback. Run all six passes, then pause once.
- Write the complete spec to `docs/UX_DESIGN.md` as a single file.
- If the PRD is ambiguous on a point, make a decision, document the assumption, and move on. Do not stop to ask.
- After writing the file, print a summary: number of concepts mapped, friction points identified, states designed, and the output file path.
