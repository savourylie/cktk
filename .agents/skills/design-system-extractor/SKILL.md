---
name: "design-system-extractor"
description: "Extract structured design tokens from UI screenshots. Reverse-engineers colors, typography, spacing, border radii, shadows, and component patterns into Markdown tables + JSON. Use for requests like extract design system, get tokens from screenshots, reverse-engineer design language, or document design tokens from UI."
---

# Design System Extractor

Analyze UI screenshots to reverse-engineer design tokens into a structured Markdown + JSON artifact. Describe what is visually present, not what might be intended.

## Workflow

1. Receive one or more UI screenshots from the user.
2. Read [references/extraction-guide.md](./references/extraction-guide.md) for extraction heuristics.
3. Systematically extract design elements from the screenshots (see Extraction Process below).
4. Structure tokens per [references/token-schema.md](./references/token-schema.md).
5. Output a single Markdown file with tables and embedded JSON (see [references/example-output.md](./references/example-output.md) for a complete example).
6. Validate the JSON block by running `python3 scripts/validate_tokens.py <path-to-json-file>`. Fix any reported issues before delivering.

## Extraction Process

Use the Read tool to view each screenshot. When multiple screenshots are provided, analyze all of them to find the unified token set — patterns that repeat across screens are higher confidence.

Extract in this order:

1. **Colors** — every distinct color: backgrounds, text, borders, buttons, accents, status colors (error, warning, success, info).
2. **Typography** — font families (or closest match), size scale, weights, line heights, font sources (Google Fonts URLs or `"system"`).
3. **Spacing** — infer the spacing scale from padding, margins, and gaps between elements.
4. **Border radii** — buttons, cards, inputs, avatars, badges.
5. **Shadows / elevation** — depth levels on cards, modals, dropdowns.
6. **Component patterns** — button styles, card styles, input styles, nav patterns.
7. **Layout** — max widths, grid structure, breakpoints (if multiple viewport sizes provided).
8. **Iconography** — outlined vs filled, approximate size grid, stroke weight.

### Confidence Annotations

Annotate uncertain values rather than guessing silently:

```
| font.family.body | "Inter" or similar geometric sans-serif | Body text | ~80% confidence |
```

Use `~90%`, `~80%`, `~70%` markers. Below 60%, note "unable to determine" and explain why.

### Multiple Screenshots

When unifying tokens across multiple screenshots:

- Colors appearing across multiple screens get higher confidence.
- Note screen-specific colors separately (e.g., "only seen on settings page").
- Use the superset of the typography scale across all screens.

## Output Format

Produce a single Markdown file:

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

### Output Rules

- Use platform-agnostic px values in the canonical format. Consumers convert to rem/pt/dp as needed.
- Include a `components` section in JSON that references primitive tokens with `{token.path}` syntax.
- Keep Markdown tables as the quick-reference view; JSON as the machine-readable source of truth.
- Always include the `meta` object in JSON with `name`, `source`, `version`, and `generated` fields.

For the canonical JSON schema and a complete example, see:
- **Schema**: references/token-schema.md
- **Full example**: references/example-output.md

## Validation

After generating the JSON block, extract it to a file and run:

```bash
python3 scripts/validate_tokens.py <path-to-json-file>
```

This checks required sections, token format, and reference integrity. Fix any reported issues before delivering.
