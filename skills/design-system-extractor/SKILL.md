---
name: design-system-extractor
description: >
  Extract structured, cross-platform design systems from UI screenshots. Analyzes one or more
  screenshots of websites, apps, or mockups to reverse-engineer design tokens — colors, typography,
  spacing, border radii, shadows, and component patterns — into a structured Markdown + JSON artifact.
  Use this skill when a user provides screenshot(s) and wants to: (1) extract a design system or
  design tokens from visual UI, (2) reverse-engineer the design language of an existing product,
  (3) document an implicit design system from production screenshots or mockups, (4) create a single
  source of truth token file from visual references. Do NOT use for: building UIs from screenshots
  (use frontend-design), generating new design systems from scratch, applying existing themes
  (use theme-factory), debugging CSS, or answering design system knowledge questions.
---

# Design System Extractor

Analyze UI screenshots to produce a structured design token artifact (Markdown tables + JSON).

## Workflow

1. **Receive screenshots** — one or more images from the user
2. **Analyze visuals** — read references/extraction-guide.md, then systematically extract design elements
3. **Structure tokens** — format per references/token-schema.md
4. **Output artifact** — Markdown file with tables and embedded JSON (see references/example-output.md for a complete example)
5. **Validate** — run `scripts/validate_tokens.py` on the JSON block to check conformance

## Extraction Process

### Read the screenshot(s)

Use the Read tool to view each screenshot. If multiple screenshots are provided, analyze all of them to find the **unified** set of tokens — look for patterns that repeat across screens.

### Systematic extraction

Analyze in this order (read references/extraction-guide.md for detailed heuristics):

1. **Colors** — sample every distinct color visible: backgrounds, text, borders, buttons, accents, status colors (error/warning/success/info)
2. **Typography** — identify font families (or closest match), size scale, weights, line heights, and font sources (Google Fonts URLs or `"system"` for system fonts)
3. **Spacing** — infer the spacing scale from padding, margins, gaps between elements
4. **Border radii** — buttons, cards, inputs, avatars, badges
5. **Shadows/elevation** — depth levels visible on cards, modals, dropdowns
6. **Component patterns** — button styles, card styles, input styles, nav patterns
7. **Layout** — max widths, grid structure, breakpoints (if multiple viewport sizes provided)
8. **Iconography** — outlined vs filled, approximate size grid, stroke weight

### Confidence annotations

When uncertain about a value, annotate it rather than guessing silently:

```
| font.family.body | "Inter" or similar geometric sans-serif | Body text | ~80% confidence |
```

Use `~90%`, `~80%`, `~70%` confidence markers. Below 60%, note "unable to determine" and explain why.

### Multiple screenshots

When the user provides multiple screenshots, unify the tokens:
- Colors that appear across multiple screens are higher confidence
- Note screen-specific colors (e.g., "only seen on settings page") separately
- Look for the superset of the typography scale across all screens

## Output Format

Produce a single Markdown file structured as:

```
# Design System: [Name or Source]
Extracted from: [source description]
Generated: [date]

## Color Tokens        (table: Token | Hex | Usage)
## Typography          (table: Token | Value | Usage)
## Spacing Scale       (table: Token | Value)
## Border Radius       (table: Token | Value)
## Shadows             (table: Token | Value)
## Component Patterns  (table: Component | Styles)
## Design Tokens (JSON)  (machine-readable JSON block)
```

For the canonical JSON schema and a complete example, see:
- **Schema**: references/token-schema.md
- **Full example**: references/example-output.md

### Key output rules

- Use **platform-agnostic px values** in the canonical format — consumers convert to rem/pt/dp as needed
- Include a `components` section in JSON that references primitive tokens with `{token.path}` syntax
- Keep Markdown tables as the quick-reference view; JSON as the machine-readable source of truth
- Always include the `meta` object in JSON with `name`, `source`, `version`, and `generated` fields

## Validation

After generating the JSON block, extract it and run:

```bash
python3 scripts/validate_tokens.py <path-to-json-file>
```

This checks required sections, token format, and reference integrity. Fix any reported issues before delivering.
