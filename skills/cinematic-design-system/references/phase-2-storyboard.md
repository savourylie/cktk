# Phase 2 — Storyboard

**Outputs**: `docs/UX_DESIGN.md` and `docs/INFO_ARCHITECTURE.md` (copy `assets/FILM_TEMPLATE/UX_DESIGN.md` and `assets/FILM_TEMPLATE/INFO_ARCHITECTURE.md` and fill them in, in parallel)

**Read at entry**: this file, `anti-convergence.md`, `premium-calibration.md`. Then progressively load one data file at a time as the workflow needs it:

- `data/hero-archetypes.md`
- `data/narrative-beats.md`
- `data/section-functions.md`
- `data/section-archetypes.md`
- `data/dna-index.tsv` (and only open `data/design-dna-db.txt` if the index surfaces a promising hit)

**Do not read at entry**: Phase 3 data files (camera-shots, interaction-effects, compositions, visual-elements, background-techniques, typography-cinema, color-grades, font-moods, textures). Those load in `phase-3-compile.md`.

## Goal

Turn the committed director + film + niche from `RESEARCH.md` into a site-wide cinematic grammar, per-page scene theses, signature compositions, narrative arcs, entrance maps, and motion budgets — all written to `docs/UX_DESIGN.md`, with structural metadata (site map, page roles, nav hierarchy, beat sequences) written in parallel to `docs/INFO_ARCHITECTURE.md`.

Phase 2 does **not** write DESIGN.md. The shared design system is back-derived in Phase 3 from this phase's locked page compositions.

## The Non-Negotiable Ordering Rule

Work the four sub-steps in this order. **Do not skip forward.**

1. **Define the site-wide cinematic grammar.** (UX_DESIGN.md → Site Cinematic Grammar)
2. **Write one independent scene thesis for each major page role.** (UX_DESIGN.md → Page blocks, each standalone)
3. **Lock one irreplaceable signature composition per page.** (UX_DESIGN.md → Page → Signature composition)
4. **Derive the shared system only in Phase 3.** Explicitly *hold back* shared component rules in UX_DESIGN.md → Shared system holdback.

Inverting this order — defining shared components before page compositions — flattens the pages into a template. That is the exact failure mode this skill exists to prevent.

## Sub-step 1: Site-Wide Cinematic Grammar

Before touching any individual page, commit the shared film language that will apply to every page. Write into `UX_DESIGN.md` → *Site Cinematic Grammar*:

- **Page-shell logic** (e.g. "corridor — narrow content column framed by wide negative margins")
- **Navigation posture** (minimal/dominant, flush-left/centered, sticky/floating)
- **Framing rules** (aspect ratios, crop logic, bleed behavior)
- **Density cadence** (which pages breathe, which pages load up)
- **Recurring material/atmospheric layers** (grain, haze, scan lines, fog — and which pages they appear on)
- **Composition families allowed** (from Phase 1 Primary Composition Family — this is the structural constraint)
- **What varies between pages** vs **what repeats across pages**

The shell-ban list from `RESEARCH.md` Phase 1 is a hard constraint here. The site-wide grammar cannot violate it.

## Sub-step 2: Director Brief

Write the Director Brief into `UX_DESIGN.md` → *Director Brief*:

- One-sentence visual thesis
- Three signature techniques with web translations
- **Which of the three is the dominant move**, versus the two that are echoes
- Motion rules
- Typography direction

The **signature/support asymmetry** matters. In a film, three techniques might be equally iconic; on a website, only one can be the dominant move per page, with the other two as echoes. Pick now.

## Sub-step 3: Premium Calibration Gate

Before writing per-page scene theses, run `premium-calibration.md`. It requires twelve specific outputs before Phase 3 can begin:

1. Site cinematic grammar *(from sub-step 1)*
2. One big idea per page
3. Page scene thesis
4. Hero dominance statement
5. Restraint statement ("what we will NOT do")
6. Material thesis
7. Typography thesis *(from Director Brief)*
8. Page-role scene
9. Signature composition
10. Grid fallback test
11. Shared system holdback
12. Uniqueness guardrail *(from RESEARCH.md shell-ban list)*

Mark each one in `UX_DESIGN.md` → *Premium Calibration Gate* as it's completed. Phase 3 is blocked until all twelve are marked.

**Rejection criteria** from `premium-calibration.md`: reject any page that feels like *a Framer template with a movie color palette*, *a motion showcase with no hierarchy*, *a SaaS page wearing cinematic makeup*, *a pile of beautiful parts with no dominant idea*, *a reference collage*, or *a page that leaks internal process language into the public UI*.

## Sub-step 4: Per-Page Work

For every major page role in `INFO_ARCHITECTURE.md`, write a page block in `UX_DESIGN.md` containing:

### 1. Scene thesis

Each page is **treated as a standalone scene first**. Write the scene thesis before defining any shared components. Do not let a shared card rule flatten page-specific identity.

### 2. One big idea

The single dominant visual concept for the page. Everything else supports this. Examples: monumental type, sculptural light, editorial framing, void plus glow, object-as-stage.

### 3. Hero dominance statement

Why does this hero feel commanding or expensive? One sentence. No generic gradients, no generic app UI.

### 4. Restraint statement

What you will deliberately **NOT** do on this page. This is where restraint becomes actionable rather than abstract.

### 5. Signature composition

One layout move that cannot collapse into a generic default grid. Cite the source id from `data/compositions.md` or mark as `Custom` with justification.

**Grid fallback test**: *If this section survives unchanged as a 2×2 or 3-column grid, the composition is too weak.* If the test fails, rewrite the composition.

### 6. Narrative arc

Map the page to a narrative arc, not the default `Hero → Features → Stats → CTA`. Load `data/narrative-beats.md` and pick beats that match the director's arc template. Load `data/section-functions.md` to classify each beat's function.

### 7. Hero archetype & section archetypes

Load `data/hero-archetypes.md` and pick a hero skeleton. Load `data/section-archetypes.md` for each non-hero scene. Apply `anti-convergence.md` — hash-based selection, cross-page rules (same archetype id max 2× across the site).

### 8. Entrance map

Before writing section specs, commit the entrance sequence:

- Maximum 1 heavy interaction per page
- Maximum 2 attention-seeking reveals per page
- `fadeUp` / `opacity + translateY` at most 2× per page
- At least 4 distinct entrance types per page when section count supports it
- No two adjacent sections use the same entrance

### 9. Motion budget

- Heavy interaction: 1, with a clear reason why this moment earns it
- Attention-seeking reveals: ≤2
- Baseline motion: subordinate, never competing with the visual thesis

### 10. Scene breakdown

One sub-block per section: beat, function, archetype, composition ref, camera ref, interaction ref, visual elements, reason to exist in the arc. Library source id citations are optional at Phase 2 (they become mandatory in Phase 3), but the structural slots should already exist.

## DNA Casting (Optional, High-Value)

Use `data/dna-index.tsv` to find 2-3 design DNA sources that match the committed film on mood, typography, motion, shape language, density, and material richness. Only open `data/design-dna-db.txt` when the index surfaces a promising host worth expanding.

Record the DNA matches as supporting reference material — not as copy sources. They sharpen the site-wide grammar without providing compositions to borrow wholesale.

## Writing INFO_ARCHITECTURE.md in Parallel

While writing `UX_DESIGN.md`, maintain `docs/INFO_ARCHITECTURE.md` in parallel. Its sections correspond to structural metadata rather than scene/motion content:

- **Site map** — tree of pages
- **Page roles** — each page's job in the site's narrative (one paragraph per page) + its beat sequence
- **Navigation hierarchy** — nav items, footer, secondary nav, posture
- **Content types** — categorical content types (projects, articles, products) with their field structure
- **Cross-page beat map** — a single table showing beat sequences across all pages so cross-page convergence is easy to spot
- **Anti-convergence report** — most-repeated archetype (must be ≤2), homepage-vs-interior shell similarity (should be low)
- **Responsive structure notes** — IA-level responsive behavior only; component styling lives in DESIGN.md §8

`INFO_ARCHITECTURE.md` is how the skill catches cross-page convergence — the beat map makes repetitions visually obvious.

## Anti-Convergence Cross-Check

Before closing Phase 2, run these checks from `anti-convergence.md`:

- [ ] Same archetype id appears at most 2× across the whole site (excluding footer-like repeats)
- [ ] Same function type prefers different archetype on different pages
- [ ] Homepage and interior pages do not reuse the same shell with only superficial changes
- [ ] At least 2 sections per page structurally different from default marketing layouts
- [ ] Beat sequences match the director's arc template, not a generic marketing flow
- [ ] Every section has a camera ref and an interaction ref, or an intentional `none`

If any fail, re-roll the archetype selection for the offending section(s) before moving to Phase 3.

## Sub-Agent Delegation

If the environment supports sub-agents, delegate per-page work once the site-wide grammar is locked:

- One sub-agent per major page role, drafting that page's scene thesis, signature composition, narrative arc, entrance map, and scene breakdown
- One sub-agent for `INFO_ARCHITECTURE.md` drafting the site map and page roles

The lead agent retains:

- Site-wide grammar committing
- Director brief committing
- Premium calibration gating
- Anti-convergence cross-check
- Final merge review

Do not let sub-agents independently redefine the director, film, or site-wide visual thesis.

## User Approval

When the task is collaborative or exploratory, get user approval on `UX_DESIGN.md` and `INFO_ARCHITECTURE.md` **before** moving to Phase 3. Phase 3 back-derives the design system from these files — if they change after Phase 3, DESIGN.md has to be re-derived.

## Phase 2 Completion Gate

Phase 3 is blocked until:

- [ ] UX_DESIGN.md Director Brief complete
- [ ] UX_DESIGN.md Site Cinematic Grammar complete
- [ ] UX_DESIGN.md Premium Calibration Gate has all 12 boxes checked
- [ ] Every major page in UX_DESIGN.md has all 10 per-page items (scene thesis, one big idea, hero dominance, restraint, material, page-role, signature composition, grid fallback, arc, entrance map, motion budget, library citation slots, scene breakdown)
- [ ] INFO_ARCHITECTURE.md has site map, page roles with beat sequences, navigation hierarchy, content types (if applicable), cross-page beat map, anti-convergence report
- [ ] Anti-convergence cross-check passed
- [ ] User approval received (when task is collaborative)

When all boxes are checked, close Phase 2 and move to `phase-3-compile.md`.
