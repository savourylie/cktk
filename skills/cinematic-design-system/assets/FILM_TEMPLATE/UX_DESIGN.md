# UX Design — [Film]

<!--
TEMPLATE — FILM_TEMPLATE/UX_DESIGN.md, written by the cinematic-design-system
skill in Phase 2. Captures the director brief, site-wide cinematic grammar,
per-page scene theses, signature compositions, motion orchestration, and
library source citations.

This is where the film's *structure* lands — narrative arcs, scene rhythm,
signature compositions, hero dominance, framing logic. The film's *surface*
(palette, type, material) lives in DESIGN.md.

ORDERING RULE (non-negotiable):
  1. Site-wide cinematic grammar
  2. Per-page scene thesis
  3. Per-page signature composition
  4. Shared system → back-derived in DESIGN.md (Phase 3)

DESIGN.md cannot be written until this file is locked. The skill enforces this.

Do not expose director names, film titles, chapter markers, or "calibrated"
jargon in the final user-facing UI. They live in this file and in RESEARCH.md.
-->

## Director Brief

- **One-sentence visual thesis**: [one sentence naming the film's dominant visual idea and how it becomes the site's dominant idea]
- **Signature technique 1** (the heavy move): [name] — web translation: [concrete CSS/layout implication]
- **Signature technique 2** (echo): [name] — web translation: [...]
- **Signature technique 3** (echo): [name] — web translation: [...]
- **Which technique is the dominant move**: [1 / 2 / 3 — only one heavy moment per page]
- **Motion rules**: [e.g. "slow lateral reveals; no adjacent sections use the same entrance; fadeUp ≤2×/page"]
- **Typography direction**: [e.g. "heavy serif display at weight 400; monospace for metadata only"]

## Site Cinematic Grammar

<!-- The shared film language of the whole site. Captured BEFORE any per-page
     work. This sets the constraints every page must honor. -->

- **Page-shell logic**: [e.g. "corridor — narrow content column framed by wide negative margins"]
- **Navigation posture**: [e.g. "minimal top bar, flush-left, no hover underlines"]
- **Framing rules**: [e.g. "all imagery cropped to 1.85:1, never centered, always offset left"]
- **Density cadence**: [e.g. "hero sparse → middle dense → close sparse again, mirroring the film's breath"]
- **Recurring material/atmospheric layers**: [e.g. "fixed subtle grain layer, soft haze in hero only"]
- **Composition families allowed**: [e.g. "corridor, cutaway monolith" — from Phase 1 Primary Composition Family]
- **What varies between pages**: [signature composition, scene rhythm]
- **What repeats across pages**: [shell, navigation, grain, color]

## Premium Calibration Gate (12 required outputs)

<!-- All 12 must be present before Phase 3 can begin. This is the back-pressure
     that forces the page to be *directed*, not decorated. -->

- [x] Site cinematic grammar *(above)*
- [ ] One big idea per page *(per-page sections below)*
- [ ] Page scene thesis *(per-page)*
- [ ] Hero dominance statement *(per-page)*
- [ ] Restraint statement — "what we will NOT do" *(per-page)*
- [ ] Material thesis *(per-page or site-wide if unified)*
- [ ] Typography thesis *(director brief)*
- [ ] Page-role scene *(per-page)*
- [ ] Signature composition *(per-page)*
- [ ] Grid fallback test *(per-page)*
- [ ] Shared system holdback — what repeated UI rules must wait until Phase 3 *(noted here)*
- [ ] Uniqueness guardrail — what must not be inherited from prior work *(from RESEARCH.md shell-ban list)*

---

## Page: [Home]

### Scene thesis

[One paragraph — what is this page's scene inside the film of the site? What kind of moment is it?]

### One big idea

[The single dominant visual concept. Everything on this page supports this idea rather than competing with it. Examples: "monumental type", "sculptural light", "editorial framing", "void plus glow", "object-as-stage".]

### Hero dominance statement

[One sentence — why does this hero feel commanding or expensive, without relying on generic gradients or generic app UI? Cite the film moment it comes from if applicable.]

### Restraint statement

[What you will deliberately NOT do on this page. E.g. "No decorative hover states, no carousel, no gradient overlays, no stat tiles."]

### Material thesis

[What makes surfaces feel tactile or atmospheric on this page. E.g. "Paper grain + soft ink bleed on headers; all other surfaces are flat."]

### Page-role scene

[What kind of scene is this page inside the film of the site? Examples: "opening establishing shot", "quiet interior monologue", "final payoff".]

### Signature composition

- **Description**: [one layout move this page owns that cannot collapse into a generic default grid]
- **Source id**: [library entry id from `references/data/compositions.md`, or `Custom` with justification]
- **Grid fallback test**: [If this page were reduced to a generic 2×2 or 3-column grid, what essential idea would break?]

### Narrative arc

<!-- Not the default Hero → Features → Stats → CTA. Pull from the director's
     arc template in `references/data/narrative-beats.md`. Name the beats in
     order. -->

1. [Beat 1 — function — archetype]
2. [Beat 2 — ...]
3. [Beat 3 — ...]
4. [...]

### Entrance map

<!-- Before writing section specs, commit the entrance sequence. Rules:
     - Max 1 heavy interaction per page
     - Max 2 attention-seeking reveals per page
     - fadeUp / opacity+translateY at most 2× per page
     - At least 4 distinct entrance types per page when section count supports it
     - No two adjacent sections use the same entrance -->

- Scene 1: [entrance type, e.g. "clip-wipe-right"]
- Scene 2: [entrance type]
- Scene 3: [entrance type]
- Scene 4: [entrance type]
- Scene 5: [entrance type]

### Motion budget

- **Heavy interaction** (max 1): [what it is, why it earned the slot, source id from `interaction-effects-50.md`]
- **Attention-seeking reveals** (max 2): [list with source ids]
- **Baseline motion**: [subordinate motion — stays below the visual thesis]

### Library source citations

- **Camera / reveal behavior**: [source id from `camera-shots-50.md`]
- **Interaction behavior**: [source id from `interaction-effects-50.md`]
- **Composition**: [source id from `compositions.md`]
- **Typography treatment**: [source id from `typography-cinema.md`]
- **Atmospheric/background technique**: [source id from `background-techniques.md`] (if used)

### Scene breakdown

<!-- One sub-block per section in the page. Each scene gets its own beat,
     function, archetype, composition reference, camera reference, interaction
     reference, and reason to exist. -->

#### Scene 1 — [name]

- **Beat**: [from narrative arc above]
- **Function**: [from `section-functions.md`]
- **Archetype**: [from `section-archetypes.md`]
- **Composition ref**: [source id]
- **Camera ref**: [source id]
- **Interaction ref**: [source id or `none`]
- **Visual elements** (3+ for hero, 1-2 for standard): [list]
- **Why it exists in the arc**: [one sentence]

#### Scene 2 — [name]

- **Beat**: ...
- ...

### Shared system holdback

<!-- UI rules that you are deliberately NOT defining yet. These wait for
     Phase 3 so they get back-derived from all pages, not front-loaded. -->

- [e.g. "Button hover state — holdback until all pages are locked"]
- [e.g. "Card padding — holdback"]

---

## Page: [Next page]

<!-- Repeat the same block structure for every major page role. Each page is
     treated as a standalone scene first. -->

### Scene thesis
...

<!-- Continue for all pages in the INFO_ARCHITECTURE.md page list. -->

---

## Anti-Convergence Cross-Check

<!-- After writing all pages, verify these cross-page rules from
     `references/anti-convergence.md`. -->

- [ ] Same archetype id appears at most 2× across the whole site
- [ ] Same function type prefers different archetype on different pages
- [ ] Homepage and interior pages do not reuse the same shell with only superficial changes
- [ ] At least 2 sections per page structurally different from default marketing layouts
- [ ] Beat sequences match the director's template, not a generic marketing flow
- [ ] Every section has a camera ref and an interaction ref, or an intentional `none`

## Phase 2 Completion Gate

- [ ] Director brief complete
- [ ] Site cinematic grammar complete
- [ ] Premium calibration 12 outputs all marked
- [ ] Every major page has: scene thesis, one big idea, hero dominance, restraint, material, page-role, signature composition, grid fallback, arc, entrance map, motion budget, library citations, scene breakdown
- [ ] Anti-convergence cross-check passed
- [ ] User approval received (when task is collaborative)
- [ ] `INFO_ARCHITECTURE.md` written in parallel (site map, page roles, nav hierarchy, beat sequences)

**DESIGN.md (Phase 3) is BLOCKED until all boxes above are checked.**
