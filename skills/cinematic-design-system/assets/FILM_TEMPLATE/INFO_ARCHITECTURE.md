# Information Architecture — [Film]

<!--
TEMPLATE — FILM_TEMPLATE/INFO_ARCHITECTURE.md, written by the
cinematic-design-system skill in Phase 2, in parallel with UX_DESIGN.md.

This file captures the site's structural skeleton: page list, roles,
navigation hierarchy, and per-page narrative beat sequences. It is the
"where things live" companion to UX_DESIGN.md's "what things feel like".

Ordering: write this alongside UX_DESIGN.md. Do not derive the shared
nav/footer system here — that is back-derived in DESIGN.md §4 Navigation.
This file names the roles and the beats; DESIGN.md names the styling.
-->

## Site Map

<!-- Tree view. Depth reflects the navigation hierarchy. Do not invent pages
     the user didn't ask for. Do add functional pages (404, legal) only if
     the user's niche clearly needs them. -->

```
[Home]
├── [Page A]
│   ├── [Sub-page A1]
│   └── [Sub-page A2]
├── [Page B]
├── [Page C]
└── [Contact]
```

## Page Roles

<!-- One entry per major page. "Role" is the page's job inside the site's
     narrative — not its URL. Roles drive Phase 2's per-page scene theses. -->

### [Home]

- **Role**: [e.g. "opening establishing shot — commit to the film's thesis in one page"]
- **Primary audience**: [e.g. "first-time visitor who needs to decide whether this firm is serious in 8 seconds"]
- **Success criterion**: [e.g. "visitor clicks into [Work] or saves the contact"]
- **Narrative beat sequence** (from `references/data/narrative-beats.md`, following the director's arc template — not generic marketing flow):
  1. [beat name — function type]
  2. [beat name — function type]
  3. [beat name — function type]
  4. [...]
- **Cinematic grammar notes**: [anything specific to this page that differs from the site-wide grammar in UX_DESIGN.md]

### [Page A]

- **Role**: [e.g. "quiet interior monologue — depth, not breadth"]
- **Primary audience**: [...]
- **Success criterion**: [...]
- **Narrative beat sequence**:
  1. [...]
  2. [...]
- **Cinematic grammar notes**: [...]

<!-- Repeat for every major page in the site map. -->

## Navigation Hierarchy

### Top-level nav

<!-- What appears in the primary nav bar. Keep this disciplined — a long nav
     bar is a composition failure before the page is even written. -->

- [Nav item 1] → [destination]
- [Nav item 2] → [destination]
- [Nav item 3] → [destination]
- [CTA / utility item] → [destination]

### Secondary navigation

<!-- Breadcrumbs, in-page anchors, footer links, sidebar nav if any. -->

- **Footer**:
  - Column 1: [items]
  - Column 2: [items]
  - Column 3: [items]
- **In-page anchors**: [pages that use them]
- **Breadcrumbs**: [pages that show them, or "none"]

### Navigation posture

<!-- One or two sentences describing the nav's behavior — sticky, floating,
     dissolves on scroll, full-bleed, flush-left, etc. This mirrors the
     Navigation posture in UX_DESIGN.md's Site Cinematic Grammar. -->

[e.g. "Sticky top bar with backdrop-blur; collapses to hamburger under 768px; nav links flush-left; no hover underlines; CTA is flush-right and reserved for the primary film accent color"]

## Content Types

<!-- Categorical content types the site shows. Each type gets a short
     description of its structure (what fields it has) and where it appears.
     Delete this section if the site has only static content. -->

### [Content type A — e.g. "Project case study"]

- **Structure**: [field list — title, year, client, excerpt, hero image, body sections, related projects]
- **Appears on**: [Page A index, Page A/[slug] detail]
- **Narrative role**: [where this content type lands in the site's arc]

### [Content type B]

- **Structure**: [...]
- **Appears on**: [...]
- **Narrative role**: [...]

## Cross-page Beat Map

<!-- A single view of beat sequences across all pages so convergence is easy
     to spot. Anti-convergence rule: the same archetype id may appear at most
     2× across the whole site. -->

| Page | Beat 1 | Beat 2 | Beat 3 | Beat 4 | Beat 5 |
|---|---|---|---|---|---|
| Home | [beat] | [beat] | [beat] | [beat] | [beat] |
| [Page A] | [beat] | [beat] | [beat] | [beat] | [beat] |
| [Page B] | [beat] | [beat] | [beat] | [beat] | [beat] |
| [Contact] | [beat] | [beat] | — | — | — |

## Anti-Convergence Report

<!-- Fill this after the beat map above is complete. -->

- **Most-repeated archetype**: [name] — appears [N] times — [OK if ≤2, FLAG if ≥3]
- **Homepage vs interior shell similarity**: [low / medium / high — should be low]
- **Pages structurally distinct from default marketing layouts**: [≥2 per page]

## Responsive Structure Notes

<!-- If the site has meaningful responsive breakpoint behavior at the IA level
     (e.g. certain pages hide on mobile, certain nav items collapse), note it
     here. Component-level responsive behavior lives in DESIGN.md §8. -->

- **Mobile**: [what changes in IA, not just layout]
- **Tablet**: [what changes]
- **Desktop**: [base case]
