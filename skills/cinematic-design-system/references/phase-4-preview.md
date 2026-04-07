# Phase 4 — Render Previews

**Outputs**: `docs/preview.html` and `docs/preview-dark.html`

**Read at entry**: this file, `assets/FILM_TEMPLATE/preview.html`, `assets/FILM_TEMPLATE/preview-dark.html`, and the locked `docs/DESIGN.md`.

**Do not read**: anything else. Phase 4 is a mechanical rendering pass — no research, no storyboarding, no token derivation.

## Goal

Render the locked DESIGN.md as two visual preview HTML files — one light-mode, one dark-mode — that a user can open in a browser to verify the design system's tokens in context.

## Procedure

1. **Copy the templates**:
   - `assets/FILM_TEMPLATE/preview.html` → `docs/preview.html`
   - `assets/FILM_TEMPLATE/preview-dark.html` → `docs/preview-dark.html`

2. **Replace the `@` placeholders** in both files with concrete values pulled from `docs/DESIGN.md`. The placeholders are:

   | Placeholder | Value source |
   |---|---|
   | `@FILM-NAME` | The committed film title from RESEARCH.md (OK to expose here — this is a dev-facing preview file, not the public UI the user's downstream agent will produce) |
   | `@FILM-REFERENCE-URL` | IMDb / Wikipedia link for the film, or leave blank |
   | `@FONT-IMPORT` | Google Fonts `<link>` URL matching DESIGN.md §3 Font Family |
   | `@ROOT-VARS` | CSS custom properties for every token in DESIGN.md §2 (colors) and §3 (fonts) and §6 (shadows) |
   | `@COLOR-SECTIONS` | One `.color-group-label` + `.color-grid` block per color group in DESIGN.md §2 |
   | `@TYPE-SAMPLES` | One `.type-sample` row per Hierarchy table row in DESIGN.md §3 |
   | `@BUTTON-VARIANTS` | One `.button-item` per variant in DESIGN.md §4 → Buttons |
   | `@CARD-EXAMPLES` | 2-3 `.card` examples showing DESIGN.md §4 → Cards treatment |
   | `@ELEVATION-CARDS` | One `.elevation-card` per row in DESIGN.md §6 |

3. **Build the `:root` vars block** in `<style>` from DESIGN.md §2 + §3 + §6. Minimum variables the template expects:
   - Surfaces & text: `--black`, `--white`, `--gray-50`/`-100`/`-400`/`-500`/`-600`
   - Brand & semantic: `--brand-primary`, `--brand-accent`, `--semantic-error`, `--link-blue`, `--focus-ring`, `--badge-bg`, `--badge-text`
   - Shadows: `--shadow-ring`, `--shadow-subtle`, `--shadow-card`, `--shadow-floating`
   - Fonts: `--font-sans`, `--font-mono`

   Add extra vars for anything the film warrants (film-specific accent, atmospheric color, etc.). Name them after the film's language, not generic labels.

4. **Dark mode** — in `preview-dark.html`:
   - Same variable **names**, inverted **values**
   - `--white` becomes near-black (e.g. `#0a0a0a`)
   - `--black` becomes near-white (e.g. `#ededed`)
   - Grays invert their order (gray-50 darkest, gray-600 lightest)
   - Shadows shift from `rgba(0,0,0,...)` to `rgba(255,255,255,...)` when they need to be visible on dark surfaces
   - `--brand-primary` and `--brand-accent` usually stay the same or get slightly adjusted for dark contrast
   - The **body markup is byte-identical** to `preview.html` because the body uses `var()` for everything. Only `:root`, `.nav` background, and `.footer`/`.section-divider` borders change.

## Rules

- **Do not change class names.** `.color-swatch`, `.type-sample`, `.button-row`, `.card-grid`, `.form-group`, `.spacing-block`, `.radius-box`, `.elevation-card`, `.nav-brand` are all canonical. Preserve them exactly.
- **Do not reorder sections.** Canonical order: Nav → Hero → Colors → Typography → Buttons → Cards → Forms → Spacing → Radius → Elevation → Footer.
- **Do not add decorative flourishes beyond what DESIGN.md specifies.** The preview is a token catalog, not a marketing page. Every visible element must trace to a DESIGN.md token.
- **Do not expose director or film metadata in the preview body** beyond `@FILM-NAME` in the header/footer. The `@FILM-NAME` appears in the preview because the preview is a dev verification artifact, not the end-user UI. But don't write "Chapter 2: The Replicant" into the hero copy — the preview body stays generic ("Design System Preview").
- **Color swatches show literal hex values even in dark mode.** A `#ffffff` swatch stays `#ffffff` on dark backgrounds — the swatch IS the data. Do not invert the swatch values themselves, only the page chrome.

## Verification

After rendering both files:

1. Open `docs/preview.html` in a browser. Verify:
   - The header shows the film name
   - All color swatches match DESIGN.md §2
   - All type samples match DESIGN.md §3 (sizes, weights, line heights, letter spacings)
   - All button variants from DESIGN.md §4 render with correct hover/active states
   - Card elevation matches DESIGN.md §6
   - Spacing blocks match the DESIGN.md §5 scale
   - Radius boxes match the DESIGN.md §5 scale

2. Open `docs/preview-dark.html` in a browser. Verify:
   - Same structure as preview.html
   - `:root` vars inverted correctly
   - Color swatches still show literal hex values (not inverted)
   - Text is readable against dark backgrounds
   - Shadows are visible on dark surfaces

3. **Cross-check DESIGN.md**: if the preview is missing a component variant that DESIGN.md §4 describes, update the preview to include it. If the preview has a component that DESIGN.md §4 does not describe, remove it from the preview.

## Phase 4 Completion Gate

- [ ] `docs/preview.html` exists, opens in a browser, renders correctly
- [ ] `docs/preview-dark.html` exists, opens in a browser, renders correctly
- [ ] Both files reference only tokens that exist in `docs/DESIGN.md`
- [ ] No `@`-prefixed placeholders remain in either file
- [ ] Dark variant body markup is byte-identical to light variant (only `:root` + `.nav` background + a few borders differ)

When all boxes are checked, the bundle is complete. The user can open the previews in a browser, and downstream AI agents can ingest the 4 Markdown docs (`RESEARCH.md`, `UX_DESIGN.md`, `INFO_ARCHITECTURE.md`, `DESIGN.md`) as spec input.

## What Phase 4 is NOT

Phase 4 does **not**:

- Build a real website
- Implement JavaScript interactions
- Produce responsive HTML for end users
- Expose the film's metadata in user-facing copy

It is a token verification harness, nothing more. If the user wants a real build, that is a separate downstream workflow (e.g. `design-system-web-applier` or a custom frontend implementation pass), not Phase 4.
