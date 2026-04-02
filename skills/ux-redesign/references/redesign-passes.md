# UX Redesign Passes -- Detailed Reference

Six forced designer mindset passes adapted for redesign context. Each pass keeps the same designer mindset as the original `/ux-design` passes but adds a comparison layer: "what was specified" vs "what was built" vs "what should be."

Execute in order. Each pass produces required outputs before the next begins.

When `docs/FEATURES.md` is present, integrate it as noted in each pass.

**Input sources for every pass:**
- `docs/PRD.md` -- product requirements (ground truth for what matters)
- `docs/FEATURES.md` -- structured feature catalog
- `docs/UX_DESIGN.md` -- the existing spec (what was designed)
- Audit findings from codebase inspection (what was built)

---

## Pass 1: User Intent & Mental Model Alignment (Redesign)

**Designer mindset:** "What does the user think is happening?"

**Redesign lens:** "Does the current implementation match or mislead the user's mental model?"

**Force these questions:**
- What mental model does the existing UX spec intend?
- What mental model does the implementation actually communicate?
- Where do naming, navigation, or structure in the code contradict the intended model?
- Has the implementation introduced concepts not in the spec? Are they helpful or confusing?
- Has the implementation omitted concepts from the spec? Was this justified?
- What misconceptions does the current implementation create that the spec tried to prevent?

**FEATURES.md integration:** Each feature category represents a mental model cluster. Compare how features are categorized in the spec vs how they are organized in the code.

**Required output:**

```markdown
### 1. User Intent & Mental Model

**Primary user intent:** [One sentence -- from PRD, unchanged]

**Intended mental model (from spec):**
[Summary of what UX_DESIGN.md section 1 specified]

**Implemented mental model (from code):**
[What the codebase actually communicates to users]

**Mental model drift:**

| Aspect | Spec Intent | Code Reality | Drift | Verdict |
|--------|-------------|--------------|-------|---------|
| [aspect] | [what spec said] | [what code does] | [how they differ] | Beneficial / Harmful / Neutral |

**Likely misconceptions (updated):**
- [Misconception 1]: [Why it's wrong] --> [How to correct via UX]
- [Misconception 2]: [Why it's wrong] --> [How to correct via UX]

**Redesign decisions:**
- [Keep/Change]: [aspect] -- [rationale]

**Mental model diagram (redesigned):**
[ASCII diagram showing the redesigned conceptual map]
```

**Redesign-specific mistake:** Assuming the original mental model was correct. The codebase may reveal a better model that emerged during implementation -- evaluate before discarding.

---

## Pass 2: Information Architecture (Redesign)

**Designer mindset:** "What exists, and how is it organized?"

**Redesign lens:** "Does the implemented IA match the spec? Where has it drifted?"

**Force these actions:**
1. Pull the concept inventory from the existing UX_DESIGN.md
2. Pull the route/component structure from the codebase inspection
3. Compare: what concepts exist in both? Only in spec? Only in code?
4. For each divergence, decide: keep spec's IA, keep code's IA, or design something new

**FEATURES.md integration:** Feature categories are the canonical concept groups. Compare against both the spec's grouping and the code's grouping.

**Required output:**

```markdown
### 2. Information Architecture

**IA Comparison:**

| Concept | In Spec? | In Code? | Spec Group | Code Location | Delta | Action |
|---------|----------|----------|------------|---------------|-------|--------|
| [name]  | Yes/No   | Yes/No   | [group]    | [route/component] | [description] | Keep/Modify/Add/Remove |

**New concept inventory (redesigned):**

| Concept | Group | Classification | Source | Rationale |
|---------|-------|----------------|--------|-----------|
| [name]  | [group] | Primary/Secondary/Hidden | Spec/Code/New | [why] |

**Grouped structure (redesigned):**

#### [Group Name]
- [Concept]: [Primary/Secondary/Hidden]
- Rationale: [One sentence why this grouping]
- Delta from previous: [What changed and why]

**IA hierarchy diagram (redesigned):**
[ASCII tree showing redesigned concept hierarchy]
```

**Redesign-specific mistake:** Forcing the code back to match the original spec's IA when the code's organization is actually better. Evaluate each divergence on its merits.

---

## Pass 3: Affordances & Action Clarity (Redesign)

**Designer mindset:** "What actions are obvious without explanation?"

**Redesign lens:** "Which affordances in the code are ambiguous, missing, or misleading?"

**Force explicit evaluation:**
- Pull the affordance inventory from existing UX_DESIGN.md
- Examine actual interactive elements found during codebase inspection
- For each affordance: Is it implemented? Is it clear? Does it match the spec?
- Identify new affordances in the code that weren't in the spec

**FEATURES.md integration:** Feature descriptions clarify what users DO with each feature. Compare intended actions against implemented interactive elements.

**Required output:**

```markdown
### 3. Affordances & Action Clarity

**Affordance gap analysis:**

| Element | Spec Action | Implemented Action | Match? | Issue | Resolution |
|---------|------------|-------------------|--------|-------|------------|
| [name]  | [spec says] | [code does]       | Full/Partial/Missing/Extra | [what's wrong] | [fix] |

**Redesigned affordance inventory:**

| Element | Action | Type | Visual/Interaction Signal |
|---------|--------|------|--------------------------|
| [name]  | [what user does] | Clickable/Editable/Read-only/Final/In-progress | [what makes it obvious] |

**Affordance rules (redesigned):**
- If user sees X, they should assume Y
- [Rule 2]

**Ambiguous affordances to resolve:**
- [Element]: [Why it's ambiguous] --> [Resolution]
```

**Redesign-specific mistake:** Preserving affordances just because they exist in code. If an affordance is confusing, it needs to change regardless of implementation effort.

---

## Pass 4: Cognitive Load & Decision Minimization (Redesign)

**Designer mindset:** "Where will the user hesitate?"

**Redesign lens:** "Where does the implementation add unnecessary friction?"

**Force identification of:**
- Friction points the spec tried to eliminate -- were they actually eliminated in code?
- New friction points introduced by the implementation that weren't in the spec
- Decision counts per flow: spec's target vs code's reality
- Progressive disclosure: was it implemented as specified?

**FEATURES.md integration:** Feature count per category reveals cognitive density. Compare spec's simplification strategy against what was actually built.

**Required output:**

```markdown
### 4. Cognitive Load & Decision Minimization

**Friction point comparison:**

| Friction Point | In Spec? | Addressed in Code? | Current State | Redesign Action |
|---------------|----------|-------------------|---------------|-----------------|
| [description] | Yes/No   | Yes/No/Partially  | [how it works now] | [what to change] |

**New friction points (from implementation):**

| Moment | Location | Type | Simplification |
|--------|----------|------|----------------|
| [when] | [where]  | Choice/Uncertainty/Waiting | [how to reduce] |

**Defaults (redesigned):**
- [Default 1]: [Rationale] -- [Changed from spec? Why?]

**Progressive disclosure plan (redesigned):**
- Show first: [What's visible immediately]
- Show on demand: [What appears on interaction]
- Show on advanced: [What's behind settings/config]
- Delta from spec: [What changed and why]

**Decision count per flow (redesigned):**

| Flow | Spec Target | Code Reality | Redesign Target | How |
|------|-------------|--------------|-----------------|-----|
| [flow] | [N decisions] | [N decisions] | [N decisions] | [reduction strategy] |
```

**Redesign-specific mistake:** Only looking at spec-specified friction points. The implementation likely introduced new friction the spec couldn't anticipate. Inspect the actual code flows.

---

## Pass 5: State Design & Feedback (Redesign)

**Designer mindset:** "How does the system talk back?"

**Redesign lens:** "Which states are missing, broken, or inadequate in the implementation?"

**Force enumeration:**
- Pull the state matrix from existing UX_DESIGN.md
- Check actual components for Empty, Loading, Success, Partial, Error handling
- For each element: which states are implemented? Which are missing? Which are wrong?
- Identify state handling that exists in code but wasn't in the spec

**FEATURES.md integration:** Every feature needs at least Empty, Success, and Error states. Check coverage against the feature catalog.

**Required output:**

```markdown
### 5. State Design & Feedback

**State coverage matrix:**

| Screen/Element | State | In Spec? | In Code? | Quality | Redesign Action |
|---------------|-------|----------|----------|---------|-----------------|
| [name] | Empty | Yes/No | Yes/No | Good/Adequate/Poor/Missing | [action] |
| [name] | Loading | Yes/No | Yes/No | Good/Adequate/Poor/Missing | [action] |
| [name] | Success | Yes/No | Yes/No | Good/Adequate/Poor/Missing | [action] |
| [name] | Partial | Yes/No | Yes/No | Good/Adequate/Poor/Missing | [action] |
| [name] | Error | Yes/No | Yes/No | Good/Adequate/Poor/Missing | [action] |

#### [Screen/Element Name] (Redesigned)

| State | User Sees | User Understands | User Can Do |
|-------|-----------|------------------|-------------|
| Empty | [description] | [what they think] | [actions] |
| Loading | [description] | [what they think] | [actions] |
| Success | [description] | [what they think] | [actions] |
| Partial | [description] | [what they think] | [actions] |
| Error | [description] | [what they think] | [actions] |

**Feedback mechanisms (redesigned):**
- [Mechanism 1]: [When it fires, what it communicates]

**State transition diagram (redesigned):**
[ASCII diagram showing state transitions for key elements]
```

**Redesign-specific mistake:** Treating "has a loading spinner" as "Loading state is handled." Evaluate state QUALITY -- does the user understand what's happening and what they can do?

---

## Pass 6: Flow Integrity Check (Redesign)

**Designer mindset:** "Does this feel inevitable?"

**Redesign lens:** "Where do the implemented flows break, dead-end, or confuse?"

**Final sanity check:**
- Trace actual navigation paths through the route/component tree
- Identify dead ends, missing back-navigation, broken cross-flow dependencies
- Compare spec's intended flows against actual implemented flows
- Check: can a first-time user complete every core flow without getting lost?

**FEATURES.md integration:** Features spanning multiple categories indicate cross-flow dependencies. Verify these transitions are actually implemented.

**Required output:**

```markdown
### 6. Flow Integrity Check

**Flow breakage report:**

| Risk | Where | Spec Intent | Code Reality | Impact | Mitigation |
|------|-------|-------------|-------------|--------|------------|
| [risk] | [screen/flow] | [what spec said] | [what code does] | [what goes wrong] | [fix] |

**Visibility decisions (redesigned):**
- Must be visible: [List with rationale]
- Can be implied: [List with rationale]

**Cross-flow dependencies (redesigned):**
- [Feature A] --> [Feature B]: [What must carry across] -- [Currently works? Y/N]

**Dead ends found in implementation:**
- [Route/screen]: [Why it's a dead end] --> [How to fix]

**UX constraints for visual phase:**
- [Constraint 1]: [Why non-negotiable]
- [Constraint 2]: [Why non-negotiable]
```

**Redesign-specific mistake:** Rubber-stamping existing flows. Just because a flow exists and "works" doesn't mean it's good. Evaluate whether each flow feels inevitable, not just functional.

---

## Common Mistakes (Redesign-Specific)

**Redesigning everything just because you can.** If the implementation improved on the spec, keep those improvements. The "Positive Divergences" section in the audit report flags these.

**Ignoring implementation constraints.** The codebase reveals what's hard to build. Factor engineering complexity into redesign decisions -- a slightly less optimal UX that's buildable beats a perfect UX that won't ship.

**Treating the audit as optional.** The audit IS the foundation. Without it, you're just generating a second spec from scratch -- use `/ux-design` for that instead.

**Copy-pasting from the original spec.** Every section in the redesigned UX_DESIGN.md should reflect audit findings. If a section is unchanged, explicitly state why -- "Spec section preserved: implementation matches intent."

**Only fixing problems.** The redesign should also amplify what works well. Strengthen good patterns found in the implementation, not just patch gaps.
