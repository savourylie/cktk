# Phase 3 — Back-derive the Design System

**Output**: `docs/DESIGN.md` (copy `assets/FILM_TEMPLATE/DESIGN.md` and fill it in)

**Read at entry**: this file, `anti-garbage.md`, `implementation-guardrails.md` (motion and citation rules apply; the build-specific rules apply loosely).

Then progressively load the Phase 3 data libraries, **only what each FILM_TEMPLATE section needs**:

- `data/color-grades.md` — film palette to UI token translations (→ DESIGN.md §2)
- `data/font-moods.md` — font pairings by tone (→ DESIGN.md §3)
- `data/typography-cinema.md` — text performance treatments (→ DESIGN.md §3 principles)
- `data/interaction-effects-50.md` — component hover/focus states (→ DESIGN.md §4, partial)
- `data/background-techniques.md` — hero atmospheres and decorative depth (→ DESIGN.md §6 decorative depth)
- `data/textures.md` — grain, grids, dust, scan lines (→ DESIGN.md §6 shadow philosophy / decorative depth)
- `data/compositions.md` — layout grid logic (→ DESIGN.md §5 grid & container)
- `data/visual-elements.md` — frames, badges, glows, halos (→ DESIGN.md §4 optional sub-sections)

**Do not read at entry**: Phase 1 files (directors-200.md) or Phase 2 files (hero-archetypes, narrative-beats, section-functions, section-archetypes, dna-index, design-dna-db, camera-shots-50). Their content already landed in `RESEARCH.md` / `UX_DESIGN.md` / `INFO_ARCHITECTURE.md`.

## Goal

Turn the locked `UX_DESIGN.md` (site grammar + per-page scene theses + signature compositions + motion orchestration) into a **back-derived shared design system** following the FILM_TEMPLATE 9-section structure. Write to `docs/DESIGN.md`.

This is the phase cinematic-ui normally skips or inverts. The shared system comes **last** here, not first.

## The Iron Law

> **DO NOT write DESIGN.md until UX_DESIGN.md is locked.**

Writing DESIGN.md before Phase 2 completes front-loads a shared component system, which flattens the per-page scenes into a template. That is the exact failure mode this skill exists to prevent.

If you find yourself wanting to sketch DESIGN.md tokens during Phase 2 "just to see how it'll feel", stop. Go back. Finish Phase 2 first.

## Back-Derivation Mapping

The FILM_TEMPLATE DESIGN.md has 9 sections. Each section has a defined upstream source inside `UX_DESIGN.md` (and, for a few, `RESEARCH.md`). Work the sections in order:

### §1 Visual Theme & Atmosphere

**Upstream source**: Director Brief (UX_DESIGN.md) + Film Research Notes (RESEARCH.md) + Primary Composition Family (RESEARCH.md).

**How to derive**:

- Prose paragraphs describe the dominant visual mood, the design philosophy, the signature typography approach, the color story, the hierarchy mechanism, and the notable technical approach.
- These come directly from the Director Brief's one-sentence visual thesis + the three signature techniques, elaborated with the film research palette/lighting/framing notes.
- Key Characteristics bullets (7-10 items) must be concrete: hex codes, font names, radius values, design principles. No vague adjectives.
- **Do not leak** director name, film title, or workflow metadata into the prose. Write the mood without naming the source.

### §2 Color Palette & Roles

**Upstream source**: Film Research Notes → Film palette (RESEARCH.md) + `data/color-grades.md`.

**How to derive**:

- Match the film's palette to entries in `data/color-grades.md`. Each color-grade entry maps film palette characteristics to UI token translations.
- Fill the universal H3 groups: *Primary*, *Surface & Background*, *Neutrals & Text*.
- Add optional H3 groups only if the film warrants: *Interactive*, *Semantic*, *Shadows*, *Gradients*, *Film-specific*.
- **Preserve "brand color" as a CTA term of art** in the role descriptions. *"Primary brand color. CTA backgrounds, link text, focus highlights."* is the canonical phrasing regardless of whether the source is a brand or a film.
- Name the colors by the film's language when it's distinctive. For example, a Blade Runner 2049 spec might have a *"Replicant Orange #F47B27"*, a *"Los Angeles Smog #C4A878"*. A generic "Primary Blue" is a failure of specificity.

### §3 Typography Rules

**Upstream source**: Director Brief → Typography direction (UX_DESIGN.md) + `data/font-moods.md` + `data/typography-cinema.md`.

**How to derive**:

- **Font Family**: pick from `data/font-moods.md` by matching the film's typographic mood. Always include a fallback chain.
- **Hierarchy**: fill the 11-row table with actual sizes, weights, line heights, letter spacings. Use negative letter-spacing for tight tracking at display sizes.
- **Principles** (3-6 bullets): derive from `data/typography-cinema.md` and the film's typographic signature. Be specific about weight choices, letter-spacing scaling, and monospace usage.

### §4 Component Stylings

**Upstream source**: Every per-page UX_DESIGN.md block's library citations (hover states, focus rings, card treatments) + `data/interaction-effects-50.md` for component-level effects + `data/visual-elements.md` for optional component primitives (badges, frames, halos).

**How to derive**:

- Start with the four universal sub-sections: Buttons → Cards & Containers → Inputs & Forms → Navigation. Do not reorder.
- For buttons, include Primary, Secondary, Tertiary/Ghost variants — even if the film's signature only uses one, document the others for implementation completeness.
- Hover/focus/active states should reference the film's signature restraint. If the film is high-contrast, use high-contrast hover. If the film is restrained, use subtle hover.
- Add optional sub-sections (Image Treatment, Modals, Badges, Tabs, Distinctive Components) only when the film warrants a notable treatment.
- **Skip JS-required interactions** from `interaction-effects-50.md` — this phase produces specs, not runtime. If the user later builds, those interactions become relevant again.

### §5 Layout Principles

**Upstream source**: Site Cinematic Grammar → density cadence, framing rules (UX_DESIGN.md) + `data/compositions.md` for grid logic reference.

**How to derive**:

- **Spacing System**: base unit (usually 8px, sometimes 4px or 12px depending on film rhythm) + full scale + section padding + component padding.
- **Grid & Container**: max content width, gutter, column system, hero layout type.
- **Whitespace Philosophy**: 1-2 prose paragraphs. This is where the Site Cinematic Grammar's density cadence becomes explicit — how generous or compact is the layout, what does the whitespace communicate, how is section rhythm established.
- **Border Radius Scale**: 0, 4, 8, 12, 9999 — each with usage notes. The film's geometric language dictates which of these dominates.

### §6 Depth & Elevation

**Upstream source**: Material thesis (UX_DESIGN.md per-page) + `data/textures.md` + `data/background-techniques.md`.

**How to derive**:

- **Shadow table** (Level 0 → Level 3+): each level is a CSS-ready treatment (shadow string, border definition, backdrop filter). Typical row count: 3-6.
- **Shadow Philosophy** (prose, 2-4 paragraphs): this is where the film's *material thesis* lands. How does this film's world handle depth? Flat? Multi-layer? Shadow-as-border? Color-tinted? Why?
- **Decorative Depth** (optional H3): non-shadow techniques the film warrants — gradient overlays, atmospheric blur, grain, scan lines, photographic layering. Pull concrete techniques from `data/textures.md` and `data/background-techniques.md`.

### §7 Do's and Don'ts

**Upstream source**: Restraint statements (UX_DESIGN.md per-page) + `anti-garbage.md` rules that specifically apply.

**How to derive**:

- **Do** (7-15 items): prescriptive rules with concrete values. These often come from the signature techniques — "Use weight 300 for all headlines and body — lightness is the signature" is the kind of specific, actionable rule this section wants.
- **Don't** (7-15 items): negations with reasons. This is where per-page restraint statements become actionable site-wide rules. "Don't scatter the brand color across the interface — it's a CTA signal, not a theme" is canonical.
- **Don't leak** director/film metadata into the don'ts. *Don't* write "Don't break the Tarkovsky silence" — write "Don't add hover motion to static sections; the silence is the design".

### §8 Responsive Behavior

**Upstream source**: Responsive structure notes (INFO_ARCHITECTURE.md) + general web conventions.

**How to derive**:

- **Breakpoints** table (4-6 rows): name, width range, key changes.
- **Touch Targets**: minimum size, spacing between adjacent targets, primary CTA behavior on mobile.
- **Collapsing Strategy**: nav, hero, multi-column sections, tables. What does each do as the viewport shrinks.

### §9 Agent Prompt Guide

**Upstream source**: everything above, synthesized for downstream agent consumption.

**How to derive**:

- **Quick Color Reference**: fenced code block with 6-10 most important hex codes, each labeled by role.
- **Example Component Prompts** (2-5 ready-to-paste prompts): each specific enough to produce pixel-accurate output. Include hex codes, font specs, padding, state behavior.
- **Iteration Guide** (5-10 numbered steps): build/refine order for a downstream agent generating UI in this style. Earliest steps establish the foundation, later steps refine.

This section is what makes DESIGN.md *executable* for a downstream AI. It should be rich enough that a fresh agent reading only §9 can produce recognizable UI.

## Motion Discipline (From `implementation-guardrails.md`)

Even though Phase 3 produces specs and not runtime code, the motion rules from `implementation-guardrails.md` still apply when describing component hover/focus/active states:

- Maximum 1 heavy interaction per page (the docs-mode interpretation: mention at most one signature interaction in DESIGN.md §4 Distinctive Components)
- Maximum 2 attention-seeking reveal patterns per page
- `fadeUp` / `opacity + translateY` described at most as 2× per page in any motion guidance
- No two adjacent sections should use the same entrance (relevant when DESIGN.md §9 Iteration Guide recommends entrance sequences)

## Library Source-ID Citations

Every heavy interaction, standout reveal, signature composition, or hero atmosphere layer mentioned in DESIGN.md **must cite** its library entry id from the Phase 3 data files. If a move is custom, mark it explicitly as `Custom` with a one-line justification.

The citations are what let a downstream agent trace moves back to a reference entry instead of reinventing from memory.

## Final Filter (`anti-garbage.md`)

Before treating DESIGN.md as complete, run the filter from `anti-garbage.md`. Reject and rewrite if any of these hold:

- A Framer template with a movie color palette
- A motion showcase with no hierarchy
- A SaaS page wearing cinematic makeup
- A pile of beautiful parts with no dominant idea
- A reference collage
- Leaks internal process language into the public UI (no "chapter", "director", "film", "calibrated", "treatment", "report build" tags)
- Generic gradient hero + centered copy without film justification
- Repeating `translateY + fade` on every section
- Visible 2×2 or 3-column card matrix as the main page composition
- Interior pages fall back to generic templates while only homepage carries the cinematic concept

Also run the final ten+ review questions from `anti-garbage.md` → *Final Review*. Key ones for docs-mode:

- If the logo were removed, would the page still feel like the chosen film?
- Does the page feel expensive because of editing and control, not extra decoration?
- Is there any section that looks like a stock creative template dropped in?
- Would this page have a unique identity if every card border and color treatment were removed?
- If the user's last demo sat beside this one in grayscale wireframe form, would they still feel clearly different?

## Sub-Agent Delegation

Phase 3 can be delegated per FILM_TEMPLATE section once UX_DESIGN.md is locked:

- One sub-agent drafts §1 Visual Theme + §2 Colors (tightly coupled)
- One sub-agent drafts §3 Typography + §4 Components
- One sub-agent drafts §5 Layout + §6 Depth
- One sub-agent drafts §7 Do's and Don'ts + §8 Responsive + §9 Agent Prompt Guide

The lead agent runs the final anti-garbage filter and writes the review before closing Phase 3.

## Phase 3 Completion Gate

Phase 4 (preview rendering) is blocked until `docs/DESIGN.md` has:

- [ ] All 9 sections filled in
- [ ] Section 1 has 2-4 prose paragraphs + 7-10 key characteristic bullets (all concrete, no vague adjectives)
- [ ] Section 2 has Primary + Surface & Background + Neutrals & Text filled, plus any optional groups the film warrants
- [ ] Section 3 has Font Family + 11-row Hierarchy table + 3-6 Principles bullets
- [ ] Section 4 has Buttons (all variants) + Cards & Containers + Inputs & Forms + Navigation
- [ ] Section 5 has Spacing + Grid & Container + Whitespace Philosophy + Border Radius Scale
- [ ] Section 6 has shadow table + Shadow Philosophy prose (2-4 paragraphs)
- [ ] Section 7 has Do and Don't with 7-15 items each
- [ ] Section 8 has Breakpoints + Touch Targets + Collapsing Strategy
- [ ] Section 9 has Quick Color Reference + 2-5 Example Component Prompts + 5-10 Iteration Guide steps
- [ ] No leaked process language (chapter, director, film, calibrated, treatment, report build) in user-facing sections
- [ ] Anti-garbage filter passed
- [ ] Final review questions answered satisfactorily

When all boxes are checked, close Phase 3 and move to `phase-4-preview.md`.
