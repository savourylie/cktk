# UX Design Passes -- Detailed Reference

Six forced designer mindset passes. Execute in order. Each pass produces required outputs before the next begins.

When `docs/FEATURES.md` is present, integrate it as noted in each pass. When absent, derive feature information solely from the PRD.

---

## Pass 1: User Intent & Mental Model Alignment

**Designer mindset:** "What does the user think is happening?"

**Force these questions:**
- What does the user believe this system does?
- What are they trying to accomplish in one sentence?
- What wrong mental models are likely?
- Where might feature names mislead users about actual behavior?

**FEATURES.md integration:** Each feature category represents a mental model cluster. Feature descriptions reveal gaps between what a feature is named and what users expect it to do.

**Required output:**

```markdown
### 1. User Intent & Mental Model

**Primary user intent:** [One sentence]

**User's mental model:**
[Describe what the user believes the system is and how it works]

**Likely misconceptions:**
- [Misconception 1]: [Why it's wrong] --> [How to correct via UX]
- [Misconception 2]: [Why it's wrong] --> [How to correct via UX]

**UX principles to reinforce:**
- [Principle 1]: [How it applies]
- [Principle 2]: [How it applies]

**Mental model diagram:**
[ASCII diagram showing user's conceptual map of the system]
```

---

## Pass 2: Information Architecture

**Designer mindset:** "What exists, and how is it organized?"

**Force these actions:**
1. Enumerate ALL concepts the user will encounter
2. Group into logical buckets
3. Classify each as: Primary (always visible) / Secondary (available on demand) / Hidden (progressive disclosure)

**FEATURES.md integration:** This is the primary consumer. Feature categories become logical buckets. Feature names become concepts. Feature descriptions reveal data objects and relationships between concepts.

**Required output:**

```markdown
### 2. Information Architecture

**Concept inventory:**

| Concept | Source | Group | Classification | Rationale |
|---------|--------|-------|----------------|-----------|
| [Name]  | PRD/FEATURES | [Group] | Primary/Secondary/Hidden | [Why] |

**Grouped structure:**

#### [Group Name]
- [Concept]: [Primary/Secondary/Hidden]
- Rationale: [One sentence why this grouping]

#### [Group Name]
...

**IA hierarchy diagram:**
[ASCII tree showing concept hierarchy and relationships]
```

**This is where most AI UX attempts fail.** If you skip explicit IA, your visual specs will be disorganized.

---

## Pass 3: Affordances & Action Clarity

**Designer mindset:** "What actions are obvious without explanation?"

**Force explicit decisions:**
- What is clickable?
- What looks editable?
- What looks like output (read-only)?
- What looks final vs in-progress?

**FEATURES.md integration:** Feature descriptions clarify what users DO with each feature -- read, edit, trigger, configure, or monitor. Each feature translates to one or more user actions.

**Required output:**

```markdown
### 3. Affordances & Action Clarity

**Affordance inventory:**

| Element | Action | Type | Visual/Interaction Signal |
|---------|--------|------|--------------------------|
| [Name]  | [What user does] | Clickable/Editable/Read-only/Final/In-progress | [What makes it obvious] |

**Affordance rules:**
- If user sees X, they should assume Y
- [Rule 2]
- [Rule 3]

**Ambiguous affordances to resolve:**
- [Element]: [Why it's ambiguous] --> [Resolution]
```

No visuals required -- just clarity on what signals what.

---

## Pass 4: Cognitive Load & Decision Minimization

**Designer mindset:** "Where will the user hesitate?"

**Force identification of:**
- Moments of choice (decisions required)
- Moments of uncertainty (unclear what to do)
- Moments of waiting (system processing)

**Then apply:**
- Collapse decisions (fewer choices)
- Delay complexity (progressive disclosure)
- Introduce defaults (reduce decision burden)

**FEATURES.md integration:** Feature count per category reveals cognitive density. Categories with many features need simplification via progressive disclosure, grouping, or smart defaults.

**Required output:**

```markdown
### 4. Cognitive Load & Decision Minimization

**Friction points:**

| Moment | Location | Type | Simplification |
|--------|----------|------|----------------|
| [When] | [Where/Screen] | Choice/Uncertainty/Waiting | [How to reduce] |

**Defaults introduced:**
- [Default 1]: [Rationale]
- [Default 2]: [Rationale]

**Progressive disclosure plan:**
- Show first: [What's visible immediately]
- Show on demand: [What appears on interaction]
- Show on advanced: [What's behind settings/config]

**Decision count per flow:**
| Flow | Decisions before | Decisions after | Reduction |
|------|-----------------|-----------------|-----------|
| [Flow name] | [N] | [N] | [How] |
```

---

## Pass 5: State Design & Feedback

**Designer mindset:** "How does the system talk back?"

**Force enumeration of states for EACH major element:**
- Empty (no data yet)
- Loading (fetching/processing)
- Success (happy path)
- Partial (incomplete data)
- Error (something went wrong)

**For each state, answer:**
- What does the user see?
- What do they understand?
- What can they do next?

**FEATURES.md integration:** Ensures complete feature coverage for state analysis. Every feature needs at least Empty, Success, and Error states mapped.

**Required output:**

```markdown
### 5. State Design & Feedback

#### [Screen/Element Name]

| State | User Sees | User Understands | User Can Do |
|-------|-----------|------------------|-------------|
| Empty | [Description] | [What they think] | [Available actions] |
| Loading | [Description] | [What they think] | [Available actions] |
| Success | [Description] | [What they think] | [Available actions] |
| Partial | [Description] | [What they think] | [Available actions] |
| Error | [Description] | [What they think] | [Available actions] |

#### [Next Screen/Element]
...

**Feedback mechanisms:**
- [Mechanism 1]: [When it fires, what it communicates]

**State transition diagram:**
[ASCII diagram showing state transitions for key elements]
```

This prevents "dead UX" -- screens with no feedback.

---

## Pass 6: Flow Integrity Check

**Designer mindset:** "Does this feel inevitable?"

**Final sanity check:**
- Where could users get lost?
- Where would a first-time user fail?
- What must be visible vs can be implied?
- Are there dead ends or missing back-navigation?

**FEATURES.md integration:** Features that span multiple categories indicate cross-flow dependencies. Ensure transitions between feature areas are covered.

**Required output:**

```markdown
### 6. Flow Integrity Check

**Flow risks:**

| Risk | Where | Impact | Mitigation |
|------|-------|--------|------------|
| [Risk] | [Screen/Flow] | [What goes wrong] | [Guardrail/Nudge] |

**Visibility decisions:**
- Must be visible: [List with rationale]
- Can be implied: [List with rationale]

**Cross-flow dependencies:**
- [Feature A] --> [Feature B]: [What must carry across]

**UX constraints for visual phase:**
- [Constraint 1]: [Why this is non-negotiable]
- [Constraint 2]: [Why this is non-negotiable]
```

---

## Common Mistakes

**Merging passes:** "I'll cover mental model while doing IA" -- You won't. Separate passes force separate thinking.

**Skipping to visuals:** "The PRD is clear, I can design screens" -- The 6 passes catch gaps that visual-first approaches miss.

**Implicit affordances:** "Buttons are obviously clickable" -- Map EVERY action explicitly. What's obvious to you isn't obvious to users.

**Scattered state design:** "I'll add states to each component" -- Holistic state table in Pass 5 catches gaps that per-component state design misses.

**Ignoring FEATURES.md:** When present, FEATURES.md provides a structured feature inventory that prevents concept gaps. Don't treat it as redundant to the PRD -- it's a complementary input with different structure.
