---
name: cinematic-design-system
description: "Generate a cinematic design system bundle (4 Markdown docs + 2 HTML previews) from a director + film using a 4-phase film-driven workflow. Use for prompts like cinematic design system, film-inspired design system, director-driven design, design system from Blade Runner, or 電影風格設計系統."
---

# Cinematic Design System

Generates a full cinematic design system bundle — **four Markdown docs plus two HTML previews** — by running a film-driven workflow derived from the cinematic-ui skill. Writes to `docs/` in the user's project.

## THE IRON LAW

> **DO NOT write `docs/DESIGN.md` until `docs/UX_DESIGN.md` is LOCKED.**

The shared design system is **back-derived** from per-page compositions in Phase 3. Writing DESIGN.md before Phase 2 completes front-loads a shared component system, which flattens the pages into a template. That is the exact failure mode this skill exists to prevent. If you find yourself reaching for DESIGN.md tokens during Phase 2, stop and go back.

## Inputs

Answers to a start questionnaire (see *Phase 0* below). No other inputs required.

Optional: visual references (screenshot, URL, mood board). If supplied, they are decomposed — never copied — per `references/reference-protocol.md`.

## Outputs

Six files in `docs/` in the user's project:

| File | Phase | Purpose |
|---|---|---|
| `docs/RESEARCH.md` | Phase 1 | Director/film research, demo uniqueness audit, reference decomposition |
| `docs/UX_DESIGN.md` | Phase 2 | Director brief, site cinematic grammar, per-page scene theses, signature compositions, motion orchestration, library citations |
| `docs/INFO_ARCHITECTURE.md` | Phase 2 | Site map, page roles, navigation hierarchy, per-page beat sequences, cross-page anti-convergence report |
| `docs/DESIGN.md` | Phase 3 | Back-derived design system in the FILM_TEMPLATE 9-section format |
| `docs/preview.html` | Phase 4 | Light-mode visual verification of DESIGN.md tokens |
| `docs/preview-dark.html` | Phase 4 | Dark-mode visual verification of DESIGN.md tokens |

## The Four Phases (non-negotiable order)

```
Phase 0 — Start Questionnaire
   ↓
Phase 1 — Decisions ────────────▶ docs/RESEARCH.md
   ↓
Phase 2 — Storyboard ───────────▶ docs/UX_DESIGN.md + docs/INFO_ARCHITECTURE.md
   ↓
Phase 3 — Back-derive design ──▶ docs/DESIGN.md
   ↓
Phase 4 — Render previews ─────▶ docs/preview.html + docs/preview-dark.html
```

Inside Phase 2 and Phase 3, follow this internal order without skipping:

1. Define the site-wide cinematic grammar.
2. Write one independent scene thesis for each major page role.
3. Lock one irreplaceable signature composition per page.
4. Derive the shared system only in Phase 3, back from locked page compositions.

## Phase 0 — Start Questionnaire

Run this on every invocation. Phase 1 is blocked until it completes.

The skill has **two distinct operating modes** with different questionnaires. Pick the right mode before asking anything:

- **Extraction mode** (`Screenshot`) — the user has an existing URL or screenshot and wants to **document its design system**. The reference IS the subject. Niche and page list are derived from the reference, not asked.
- **Build modes** (`Step-by-step`, `Surprise me`) — the user wants to **design a new project** using a film as research input. The reference (if any) is inspiration for the new project. Niche and page list are supplied by the user.

**Auto-detect extraction mode**: if the user's first argument is a URL or an image path (e.g. `/cinematic-design-system https://example.com/some/page`), treat it as Screenshot entry mode automatically. Do not ask the user to pick an entry mode first.

**Always**:
- Mirror the user's language in every question and deliverable.
- Ask only one blocking question at a time.
- If the user pre-answers items in their initial request, confirm what they said and only ask for what's missing.
- If a structured-form environment is available, use it.

### Extraction mode questionnaire (Screenshot)

When the user provides a URL or screenshot, the reference IS the site. Do not ask "what niche and pages should the new site cover" — there is no new site.

1. **Fetch or inspect the reference.** For a URL: fetch the page; inspect the `<title>`, H1, nav, meta tags, visible palette, typography. When possible, crawl a few linked pages from the nav to discover the full page list. For an image: inspect it via multimodal reading.
2. **Derive all five identity fields** from the reference:
   - **Film** — infer from URL path hints first (e.g. `/demo/cloud-atlas` → *Cloud Atlas*, `/projects/blade-runner` → *Blade Runner*). If the path has no hint, infer from visible content and aesthetic signature.
   - **Director** — look up from the film via web research or `references/data/directors-200.md`.
   - **Genre** — derived from the film.
   - **Niche** — what kind of project is this site? (Editorial magazine, architecture firm, record label, film portfolio, etc.) Infer from content.
   - **Page list** — actual pages discovered in the nav or visible in the reference.
3. **Present the full derivation in a single confirmation message**:
   > *"I'll extract the design system describing this reference as: **{film}** ({director}) — **{niche}** — pages: **{page list}**. Proceed?"*
4. **Accept corrections in a single reply** — the user can rewrite any field. If the reference is genuinely ambiguous on a field and you cannot infer it with confidence, ask explicitly for that field only.
5. **Ask only one other blocker question**: image placeholders y/n.
6. **Do NOT ask** a niche-and-pages questionnaire. The reference IS the site.

### Build mode questionnaire (Step-by-step, Surprise me)

When the user is designing a new project (no URL/image supplied, or the user explicitly picks Step-by-step or Surprise me):

1. **Entry mode**: `Step-by-step` or `Surprise me`.
2. **Image placeholders**: yes/no.
3. **Site context**: the niche and the page list the new project should cover. Required.

Build modes use the Entry Specification Rules below to resolve `(director, film, genre)` from whatever the user supplies.

### Entry Specification Rules (build modes only)

In build modes, Phase 0 must accept or block combinations according to this table. If the user's step-by-step answer is ambiguous or invalid, ask a follow-up.

| User supplies | Skill does |
|---|---|
| *film only* | **Derive** director and genre from the film (web research when available, otherwise look up in `references/data/directors-200.md`) |
| *director only* | Pick a film from the director's filmography; record the implicit genre |
| *genre only* | Pick a director appropriate for the genre, then pick a film |
| *director + genre* | Pick a film in that genre, ideally from the director's filmography |
| *director + film* | Use both as given — **allowed even if the director did not make that film** (director becomes the lens, film becomes the reference) |
| *genre + film* | **DISALLOWED**. Film implies genre. Block the combination at selection time. If both arrive anyway, keep the film and discard the genre with a one-line note in RESEARCH.md |
| *nothing* (Surprise me) | Pick genre → director → film, or pick a film and derive the rest, honoring the Demo Uniqueness Protocol shell-ban list |

In extraction mode, these rules do not apply — the identity fields are derived directly from the reference content (see above).

## Phase 1 — Decisions → `docs/RESEARCH.md`

**Read at entry**: `references/phase-1-decisions.md`, `references/demo-uniqueness.md`, `references/anti-convergence.md`, `references/reference-protocol.md` (only in build mode if user supplied a reference), `references/data/directors-200.md`.

1. **Lock the identity fields.**
   - In **extraction mode**, the five fields `(director, film, genre, niche, pages)` were already derived and confirmed in Phase 0. Copy them forward into `docs/RESEARCH.md`.
   - In **build modes**, apply the Entry Specification Rules from Phase 0 to determine `(director, film, genre)` from whatever the user supplied.
2. **Run the anti-convergence 3-question film test** from `references/anti-convergence.md`.
   - In **build modes**, this is a *gate*: if any answer is unsatisfactory, pick a different film.
   - In **extraction mode**, the film is given by the reference — the three questions become *descriptive analysis* of why the existing film fits the existing niche. Record the answers, but do not re-pick the film.
3. **Research the committed director and film** (web, when available). Gather palette, lighting behavior, cinematography, framing logic, production design, signature techniques. In **build modes**, also gather 2-3 premium sites in the same niche. In **extraction mode**, also study the reference site itself in depth (scroll, interactions, materials). Required when web access is available; when not, mark the research pass as weaker and continue.
4. **Run the Demo Uniqueness Protocol** from `references/demo-uniqueness.md`. Write the previous-work audit, shell-ban list, and primary composition family. Always do this — even without prior work, write a shell-ban list against common fallback templates. In **extraction mode**, the "primary composition family" is whatever the reference *already uses*, and the shell-ban list checks whether this extraction is meaningfully different from prior extractions rather than preventing new-site convergence.
5. **Reference decomposition** (build mode only). If the user supplied an *additional* visual reference alongside a build-mode project (Step-by-step with an attached mood board URL, etc.), decompose it per `references/reference-protocol.md`. In extraction mode, the reference IS the subject — skip this step.
6. **Copy `assets/FILM_TEMPLATE/RESEARCH.md`** to `docs/RESEARCH.md` and fill in every section.

**Gate**: Phase 2 blocked until `docs/RESEARCH.md` contains director + film + genre + niche + pages + 3-question film test (descriptive in extraction mode) + research notes + (in build mode) 2-3 niche references or weak-pass marker + demo uniqueness audit + shell-ban list + primary composition family.

## Phase 2 — Storyboard → `docs/UX_DESIGN.md` + `docs/INFO_ARCHITECTURE.md`

**Mode framing**:
- In **extraction mode**, Phase 2 is *observational*: describe what the reference already does — its cinematic grammar, its per-page scene theses, its signature compositions, its motion orchestration. The same fields and gates apply, but the content is derived from inspection rather than from invention.
- In **build modes**, Phase 2 is *generative*: design the cinematic grammar, scene theses, and signature compositions for the new project using the film as research input.

**Read at entry**: `references/phase-2-storyboard.md`, `references/premium-calibration.md`, `references/anti-convergence.md`. Then progressively load one data file at a time as needed:

- `references/data/hero-archetypes.md`
- `references/data/narrative-beats.md`
- `references/data/section-functions.md`
- `references/data/section-archetypes.md`
- `references/data/dna-index.tsv` (open `references/data/design-dna-db.txt` only on a promising hit)

**Do not read at entry**: Phase 3 data files (camera-shots-50, interaction-effects-50, compositions, visual-elements, background-techniques, typography-cinema, color-grades, font-moods, textures).

1. Write the **site-wide cinematic grammar** first — shell logic, navigation posture, framing, density cadence, materials, composition families, what varies vs repeats.
2. Write the **Director Brief** — visual thesis, three signature techniques (name which is the dominant move vs echoes), motion rules, typography direction.
3. Run the **premium calibration gate** from `references/premium-calibration.md`. Twelve required outputs must be present before Phase 3 can begin.
4. For each major page role, write an **independent scene thesis** (each page treated as a standalone scene first, before shared components). Include: one big idea, hero dominance statement, restraint statement, material thesis, page-role scene, signature composition, grid fallback test, narrative arc, entrance map, motion budget, library source citation slots, scene breakdown.
5. In parallel, write `docs/INFO_ARCHITECTURE.md` — site map, page roles with beat sequences, navigation hierarchy, content types, cross-page beat map, anti-convergence report.
6. Run the **anti-convergence cross-check** from `references/anti-convergence.md`: same archetype id max 2× across site, homepage ≠ interior shell, ≥2 sections per page structurally different from default marketing layouts.
7. Copy `assets/FILM_TEMPLATE/UX_DESIGN.md` and `assets/FILM_TEMPLATE/INFO_ARCHITECTURE.md` to `docs/` and fill them in.
8. When the task is collaborative, **get user approval** before moving to Phase 3.

**Gate**: Phase 3 blocked until both files have every required section filled, all 12 premium-calibration outputs marked, and the anti-convergence cross-check passes.

**Interaction budget** (enforced at Phase 2, carried into Phase 3):

- Maximum 1 heavy interaction per page
- Maximum 2 attention-seeking reveals per page
- `fadeUp` / `opacity + translateY` at most 2× per page
- At least 4 distinct entrance types per page when the section count supports it
- No two adjacent sections use the same entrance

## Phase 3 — Back-derive the Design System → `docs/DESIGN.md`

**Read at entry**: `references/phase-3-compile.md`, `references/anti-garbage.md`, `references/implementation-guardrails.md` (motion and citation rules apply; build-specific rules apply loosely).

Then progressively load Phase 3 data files **only as each FILM_TEMPLATE section needs them**:

- `references/data/color-grades.md` → DESIGN.md §2
- `references/data/font-moods.md` + `references/data/typography-cinema.md` → DESIGN.md §3
- `references/data/interaction-effects-50.md` → DESIGN.md §4 (component hover/focus states only)
- `references/data/compositions.md` → DESIGN.md §5
- `references/data/textures.md` + `references/data/background-techniques.md` → DESIGN.md §6
- `references/data/visual-elements.md` → DESIGN.md §4 optional sub-sections

1. Copy `assets/FILM_TEMPLATE/DESIGN.md` to `docs/DESIGN.md`.
2. Back-derive each of the 9 FILM_TEMPLATE sections from the locked `docs/UX_DESIGN.md` using the mapping rules in `references/phase-3-compile.md`.
3. **Preserve "brand color" as a CTA term of art** in §2 role descriptions. The template's industry convention is that "brand color" = "the primary CTA color", independent of whether the source is a brand or a film. Do not rename this.
4. **Cite library source ids** for every heavy interaction, standout reveal, signature composition, or hero atmosphere layer referenced in DESIGN.md. Custom moves must be marked `Custom` with a one-line justification.
5. **Do not leak** director name, film title, chapter markers, or workflow jargon (`chapter`, `director`, `film`, `calibrated`, `treatment`, `report build`) into user-facing sections of DESIGN.md. They stay in RESEARCH.md and UX_DESIGN.md.
6. Run the **final filter** from `references/anti-garbage.md`. Reject and rewrite if the result feels like a Framer template with a movie color palette, a motion showcase with no hierarchy, a SaaS page wearing cinematic makeup, a pile of beautiful parts with no dominant idea, a reference collage, or a page that leaks process language into the public UI.

**Gate**: Phase 4 blocked until every DESIGN.md section (§1-§9) is filled, no leaked process language, anti-garbage filter passes.

## Phase 4 — Render Previews → `docs/preview.html` + `docs/preview-dark.html`

**Read at entry**: `references/phase-4-preview.md`, the locked `docs/DESIGN.md`, `assets/FILM_TEMPLATE/preview.html`, `assets/FILM_TEMPLATE/preview-dark.html`.

1. Copy `assets/FILM_TEMPLATE/preview.html` to `docs/preview.html`.
2. Copy `assets/FILM_TEMPLATE/preview-dark.html` to `docs/preview-dark.html`.
3. Replace all `@` placeholders with concrete values from DESIGN.md:
   - `@FILM-NAME` → the committed film title (OK to expose here — this is a dev-facing preview, not user-facing UI)
   - `@FILM-REFERENCE-URL` → IMDb / Wikipedia link, or leave blank
   - `@FONT-IMPORT` → Google Fonts `<link>` matching DESIGN.md §3
   - `@ROOT-VARS` → CSS custom properties for every token in DESIGN.md §2 + §3 + §6
   - `@COLOR-SECTIONS` → one `.color-group-label` + `.color-grid` block per DESIGN.md §2 color group
   - `@TYPE-SAMPLES` → one `.type-sample` row per DESIGN.md §3 Hierarchy row
   - `@BUTTON-VARIANTS` → one `.button-item` per DESIGN.md §4 button variant
   - `@CARD-EXAMPLES` → 2-3 `.card` blocks showing DESIGN.md §4 card treatment
   - `@ELEVATION-CARDS` → one `.elevation-card` per DESIGN.md §6 row
4. For `preview-dark.html`: keep the body byte-identical to `preview.html`, only invert `:root` variable values, `.nav` background, and `.footer`/`.section-divider` borders. Color swatch values stay literal (`#ffffff` stays `#ffffff` even in dark mode — the swatch IS the data).
5. **Do not change class names** (`.color-swatch`, `.type-sample`, `.button-row`, `.card-grid`, `.form-group`, `.spacing-block`, `.radius-box`, `.elevation-card`, `.nav-brand`). They are canonical.

**Gate**: No `@`-prefixed placeholders remain in either file. Both files open in a browser and render correctly. Every visible element traces to a DESIGN.md token.

## Hard Rules

- **Preserve director/film language** through palette, typography, spacing, composition, material. Keep them as the primary source of feeling.
- **Do not expose process language** in user-facing sections of DESIGN.md or in the preview body copy. `chapter`, `director`, `film`, `calibrated`, `treatment`, `report build` all live in RESEARCH.md and UX_DESIGN.md only.
- **Interior pages must feel like new scenes in the same film**, not simplified copies of the homepage.
- **Every major page role needs one signature composition** that cannot collapse into a default grid. If it can, the composition is too weak.
- **Treat grid as infrastructure**, not composition. A visible 2×2 or 3-column card matrix as the main composition is a failure unless the film explicitly supports it.
- **Treat restraint as a design tool**. Remove 20% of obvious moves rather than add 20% more detail.
- **Prefer exact tokens** over vague adjectives.
- **When web research or a reference site is unavailable**, state the constraint explicitly and continue with best-effort inference. Do not stall.
- **Do not skip phases** and do not jump from user request directly to DESIGN.md without writing RESEARCH.md and UX_DESIGN.md first.

## Anti-Patterns (summary; full list in `references/anti-garbage.md`)

- Generic gradient hero with centered copy, unless the source film genuinely supports it
- Watermarking the hero or nav with director/film names as premium microcopy
- Repeating the same hover / reveal / card pattern in every section
- The page becoming a motion demo or effect sampler
- Using references as layout templates instead of extracting borrowable dimensions
- Defining shared components before per-page signature compositions are locked
- Reusing the previous demo's hero posture, navigation posture, section rhythm, or dominant geometry
- Drifting toward social platform aesthetics (Instagram, Pinterest, Behance, feed layouts) when a reference invites it
- Interior pages falling back to generic templates while only the homepage carries the cinematic concept

## Progressive Loading

Keep this SKILL.md lean. Load references only for the current phase.

- **Always read at session start**: `references/library-index.md`, `references/premium-calibration.md`
- **Phase 1**: `references/phase-1-decisions.md`, `references/demo-uniqueness.md`, `references/anti-convergence.md`, `references/reference-protocol.md` (conditional), `references/data/directors-200.md`
- **Phase 2**: `references/phase-2-storyboard.md`, `references/data/hero-archetypes.md`, `references/data/narrative-beats.md`, `references/data/section-functions.md`, `references/data/section-archetypes.md`, `references/data/dna-index.tsv`, `references/data/design-dna-db.txt` (on hit)
- **Phase 3**: `references/phase-3-compile.md`, `references/anti-garbage.md`, `references/implementation-guardrails.md`, plus Phase 3 data files as each DESIGN.md section needs them
- **Phase 4**: `references/phase-4-preview.md`, `docs/DESIGN.md`, `assets/FILM_TEMPLATE/preview.html`, `assets/FILM_TEMPLATE/preview-dark.html`

## Relationship to Other cktk Skills

- **`ux-design`** also produces `docs/UX_DESIGN.md`, from a PRD using a 6-pass designer mindset. Use that when the user has a PRD and wants a general-purpose UX spec, not a film-driven one. This skill and `ux-design` write to the same path and should not be run on top of each other without a reset.
- **`ux-redesign`** audits an existing `docs/UX_DESIGN.md`. It can run against this skill's output, though the cinematic structure differs from ux-design's 6-pass output.
- **`design-system-extractor`** also produces `docs/DESIGN.md`, from screenshots. Use that when the user has a visual reference they want tokenized, not a film they want interpreted.
- **`design-system-web-applier`** / **`-mobile-applier`** convert `docs/DESIGN.md` tokens into framework-specific theme files. They will consume this skill's DESIGN.md output.
