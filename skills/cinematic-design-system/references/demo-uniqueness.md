# Demo Uniqueness Protocol

Use this protocol whenever the same user has already produced one or more cinematic sites or design-system bundles with this skill (or a sibling cinematic skill) in the same workspace.

The goal is simple: **a new bundle must differ at the wireframe level, not only at the paint level.** If a prior demo and the new demo would look similar after removing color, typography, and decorative effects, the new bundle has failed the uniqueness test.

## When to Run It

- **Always, in Phase 1, before writing `RESEARCH.md`.**
- When prior outputs exist: inspect them and run the full audit.
- When prior outputs do not exist: still write a shell-ban list against the most common fallback templates you might otherwise drift toward.

## Three Required Artifacts

Write these into `docs/RESEARCH.md`'s *Demo Uniqueness Audit* section.

### 1. Previous-work audit

Name the recurring shell traits most likely to repeat across the user's prior work. Be specific about *shell*, not surface:

- left-copy right-object hero
- top nav plus stacked framed panels
- repeated rounded premium cards
- pill metadata row
- dark luxury palette with thin borders
- centered hero with gradient wash
- 3-column feature grid with icon plus label plus body

### 2. Shell-ban list

Layout traits **explicitly forbidden** for the new project because they would make it too similar to prior work. These are hard constraints for Phase 2 (UX_DESIGN.md) and Phase 3 (DESIGN.md).

- e.g. "No left-copy right-object hero"
- e.g. "No 3-column card matrix as main page composition"
- e.g. "No dark luxury palette with thin borders and pill metadata"

### 3. Primary composition family

A structural commitment for the new project's dominant composition. **Must differ from the user's most recent comparable output** unless the user explicitly asks for an intentional sequel.

Examples:

- full-bleed stage
- corridor
- vertical tower
- archive wall
- panoramic slab
- cutaway monolith

## The Uniqueness Test

Before treating Phase 2 as done, apply this test:

> **A new demo fails if its wireframe would still look like a previous demo after removing color, type styling, and decorative effects.**

Check uniqueness across these wireframe-level dimensions, not surface:

- site shell
- hero posture
- section rhythm
- navigation posture
- density pattern
- dominant geometry

Paint-level variation (different palette, different fonts, different accent color) does **not** count as uniqueness. The structural skeleton must differ.

## No History Available

If the user has no prior outputs in the workspace, still write the shell-ban list. Target the most common fallback templates you would otherwise drift into unconsciously:

- generic centered hero with gradient wash
- Hero → Features → Stats → Testimonials → CTA section sequence
- 2×2 or 3-column feature card matrix
- stat tile strip (three big numbers in a row)
- repeated card hover lift with subtle shadow

Your Phase 2 output should actively avoid those defaults even without a specific prior work to compare against.

## Cross-Project Uniqueness vs Cross-Page Uniqueness

This protocol is the *cross-project* enforcement mechanism. A separate rule — from `anti-convergence.md` — enforces *cross-page* uniqueness: the same archetype id may appear at most 2× across a whole site. Run both. They catch different failures.
