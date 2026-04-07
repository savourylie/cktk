---
name: "cinematic-design-system"
description: "Generate a cinematic design system bundle (4 Markdown docs + 2 HTML previews) from a director + film using a 4-phase film-driven workflow. Use for prompts like cinematic design system, film-inspired design system, director-driven design, design system from Blade Runner, or 電影風格設計系統."
---

# Cinematic Design System

Generate a cinematic design system bundle — **four Markdown docs plus two HTML previews** — by running a film-driven workflow. The shared design system is **back-derived** from per-page compositions, never front-loaded.

## Argument Parsing

Parse any text that follows `$cinematic-design-system`. No arguments required. If the user's message already contains a director, film, genre, or niche, record them and skip those questionnaire items.

## Inputs

No file inputs. The skill takes its inputs from a start questionnaire (see *Phase 0*).

Optional: visual references (screenshot, URL, mood board). If supplied, they are decomposed — never copied — per `references/reference-protocol.md`.

## Outputs

| File | Phase | Purpose |
|---|---|---|
| `docs/RESEARCH.md` | 1 | Director/film research, demo uniqueness audit, reference decomposition |
| `docs/UX_DESIGN.md` | 2 | Scene theses, signature compositions, motion orchestration |
| `docs/INFO_ARCHITECTURE.md` | 2 | Site map, page roles, nav hierarchy, beat sequences |
| `docs/DESIGN.md` | 3 | Back-derived design system in FILM_TEMPLATE 9-section format |
| `docs/preview.html` | 4 | Light-mode token preview |
| `docs/preview-dark.html` | 4 | Dark-mode token preview |

## The Iron Law

**DO NOT write `docs/DESIGN.md` until `docs/UX_DESIGN.md` is LOCKED.**

The shared design system is derived last, back from locked page compositions. Writing DESIGN.md first flattens pages into a template. That is the failure mode this skill exists to prevent.

## The 4 Phases

| # | Phase | Output | Read references |
|---|---|---|---|
| 0 | Start Questionnaire | — | (this file) |
| 1 | Decisions | `docs/RESEARCH.md` | `phase-1-decisions.md`, `demo-uniqueness.md`, `anti-convergence.md`, `reference-protocol.md`, `data/directors-200.md` |
| 2 | Storyboard | `docs/UX_DESIGN.md` + `docs/INFO_ARCHITECTURE.md` | `phase-2-storyboard.md`, `premium-calibration.md`, `anti-convergence.md`, Phase 2 data files |
| 3 | Back-derive design | `docs/DESIGN.md` | `phase-3-compile.md`, `anti-garbage.md`, `implementation-guardrails.md`, Phase 3 data files |
| 4 | Render previews | `docs/preview.html` + `docs/preview-dark.html` | `phase-4-preview.md`, `assets/FILM_TEMPLATE/preview*.html`, `docs/DESIGN.md` |

Read `references/phase-1-decisions.md`, `references/phase-2-storyboard.md`, `references/phase-3-compile.md`, and `references/phase-4-preview.md` for full procedural details — including loading order, gates, and completion criteria.

### Phase 0: Start Questionnaire

Run on every invocation before Phase 1. Mirror the user's language. One blocking question at a time.

Three required items:

1. **Entry mode**: `Screenshot` / `Step-by-step` / `Surprise me`
2. **Image placeholders**: yes / no
3. **Site context**: niche + page list

### Entry Specification Rules

| User supplies | Skill does |
|---|---|
| *film only* | Derive director + genre from the film |
| *director only* | Pick a film from filmography; record implicit genre |
| *genre only* | Pick director → pick film |
| *director + genre* | Pick film in that genre, from director's filmography if possible |
| *director + film* | Use both — allowed even if mismatched (director = lens, film = reference) |
| *genre + film* | **DISALLOWED** — film implies genre. Block at selection. If both arrive, keep film, discard genre |
| *nothing* (Surprise me) | Pick genre → director → film, honoring the shell-ban list |

### Phase 1: Decisions

1. Derive `(director, film, genre)` per Entry Specification Rules
2. Run anti-convergence 3-question film selection test (`anti-convergence.md`)
3. Web-research the committed director and film when possible; mark weaker pass when not
4. Run Demo Uniqueness Protocol (`demo-uniqueness.md`)
5. Decompose user-supplied references per `reference-protocol.md`
6. Copy `assets/FILM_TEMPLATE/RESEARCH.md` → `docs/RESEARCH.md`, fill in every section

### Phase 2: Storyboard

**Order** (non-negotiable): site-wide cinematic grammar → per-page scene theses → per-page signature compositions → hold back shared system for Phase 3.

1. Write Site Cinematic Grammar (shell, navigation, framing, density, materials)
2. Write Director Brief (thesis, 3 techniques with dominant/echo assignment, motion rules, typography direction)
3. Run Premium Calibration (12 required outputs)
4. For each major page: scene thesis, one big idea, hero dominance, restraint, material thesis, page-role scene, signature composition, grid fallback test, narrative arc, entrance map, motion budget, library citations, scene breakdown
5. Write `docs/INFO_ARCHITECTURE.md` in parallel (site map, page roles, nav, beat sequences, anti-convergence report)
6. Run anti-convergence cross-check: same archetype id ≤2× across site, interior pages ≠ homepage shell, ≥2 structurally distinct sections per page
7. Copy `assets/FILM_TEMPLATE/UX_DESIGN.md` and `assets/FILM_TEMPLATE/INFO_ARCHITECTURE.md` → `docs/`
8. Get user approval when collaborative

**Interaction budget** (enforced in Phase 2, carried into Phase 3): ≤1 heavy interaction per page, ≤2 attention-seeking reveals, `fadeUp`/`opacity+translateY` ≤2× per page, ≥4 distinct entrance types per page, no adjacent repeats.

### Phase 3: Back-derive the Design System

1. Copy `assets/FILM_TEMPLATE/DESIGN.md` → `docs/DESIGN.md`
2. Back-derive each of the 9 FILM_TEMPLATE sections from locked UX_DESIGN.md using mapping rules in `phase-3-compile.md`
3. Preserve **"brand color"** as a CTA term of art in §2 — industry convention, do not rename
4. Cite library source ids for every heavy interaction, signature composition, atmosphere layer; mark custom moves as `Custom` with justification
5. Do not leak process language (`chapter`, `director`, `film`, `calibrated`, `treatment`, `report build`) into user-facing sections
6. Run final anti-garbage filter

### Phase 4: Render Previews

1. Copy `assets/FILM_TEMPLATE/preview.html` → `docs/preview.html`
2. Copy `assets/FILM_TEMPLATE/preview-dark.html` → `docs/preview-dark.html`
3. Replace `@` placeholders with concrete values from DESIGN.md tokens: `@FILM-NAME`, `@FILM-REFERENCE-URL`, `@FONT-IMPORT`, `@ROOT-VARS`, `@COLOR-SECTIONS`, `@TYPE-SAMPLES`, `@BUTTON-VARIANTS`, `@CARD-EXAMPLES`, `@ELEVATION-CARDS`
4. Dark variant: byte-identical body, only `:root` vars + `.nav` background + `.footer`/`.section-divider` borders change. Color swatch values stay literal (`#ffffff` stays `#ffffff`).
5. Do not rename class names (`.color-swatch`, `.type-sample`, `.button-row`, `.card-grid`, `.form-group`, `.spacing-block`, `.radius-box`, `.elevation-card`, `.nav-brand`)

## Behavior Rules

- Preserve director + film as the primary source of feeling. Use palette, typography, material, composition, and motion.
- Keep film metadata (director, film title, chapter markers) inside `RESEARCH.md` and `UX_DESIGN.md`. **Do not expose them in DESIGN.md or the preview body copy.**
- Interior pages must feel like new scenes in the same film, not simplified copies of the homepage.
- Every major page needs one signature composition that breaks if replaced by a default grid.
- Treat grid as infrastructure, not composition. A visible 2×2 or 3-column card matrix as the main composition is a failure.
- Remove 20% of obvious moves rather than add 20% more detail.
- Do not read the entire references library at once. Progressive loading per phase (see the Phases table above).
- Do not jump to DESIGN.md without writing RESEARCH.md and UX_DESIGN.md first.
- When web research is unavailable, state the constraint explicitly and continue with best-effort inference.

## Relationship to Other Skills

- `ux-design` also writes `docs/UX_DESIGN.md` from a PRD. Use that for non-cinematic projects. Both skills should not be run on top of each other without a reset.
- `ux-redesign` can audit the `docs/UX_DESIGN.md` written by this skill.
- `design-system-extractor` writes `docs/DESIGN.md` from screenshots. Use that when the user has a visual reference to tokenize.
- `design-system-web-applier` / `-mobile-applier` consume `docs/DESIGN.md` and produce framework-specific theme files.
