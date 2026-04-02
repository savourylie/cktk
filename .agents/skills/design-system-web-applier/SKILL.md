---
name: "design-system-web-applier"
description: "Convert design token JSON into web theme files. Generates CSS custom properties, SCSS variables, Tailwind CSS config, React themes (styled-components, Emotion, Chakra UI), CSS Modules + TypeScript, or Vue 3 composables. Use for requests like generate CSS from tokens, create Tailwind theme, build React theme, or apply design tokens to web project."
---

# Design System Web Applier

Convert design token JSON into production-ready theme files for any web stack.

`$ARGUMENTS` is the path to a token JSON file, a Markdown file containing a JSON code block, or inline JSON pasted in the request.

## Workflow

1. Receive tokens from `$ARGUMENTS` — a JSON file path, a Markdown file with a JSON code block, or inline JSON.
2. Detect the target stack by inspecting the project (see Stack Detection below). If ambiguous, ask the user.
3. Read the appropriate reference file for the target stack.
4. Generate font imports — extract `typography.font-source` URLs and emit `@import url(...)` declarations. Skip entries with value `"system"`.
5. Generate output — run `scripts/generate_css.py` for CSS/SCSS; follow reference templates for Tailwind, React, and Vue.
6. Write files to the project and provide integration guidance, including font loading instructions.

## Stack Detection

Inspect the project to determine the target stack before generating output:

| Indicator | Stack | Reference | Output File |
|---|---|---|---|
| `tailwind.config.{js,ts,mjs}` or `@tailwindcss` in deps | Tailwind CSS | references/tailwind-config.md | `tailwind.config.{js,ts}` (extend) |
| `styled-components` or `@emotion` in deps | styled-components / Emotion | references/react-theme.md | `src/theme.ts` |
| `@chakra-ui/react` in deps | Chakra UI | references/react-theme.md | `src/theme.ts` |
| `*.module.css` files + TypeScript | CSS Modules + TS | references/react-theme.md | `src/tokens.css` + `src/tokens.ts` |
| `vue` in deps | Vue 3 | references/react-theme.md | `src/tokens.css` + `src/composables/useTheme.ts` |
| `.scss` files or `sass` in deps | SCSS | references/css-variables.md | `src/styles/_tokens.scss` |
| No framework detected / plain HTML | CSS Custom Properties | references/css-variables.md | `src/tokens.css` |

If multiple stacks are detected (e.g., Tailwind + React), generate for both.

## Token Input Formats

Accept tokens in any of these forms:

1. **JSON file path** — `tokens.json` or any `.json` file containing the token schema.
2. **Markdown with JSON block** — extract the JSON from the fenced code block.
3. **Inline JSON** — pasted directly in the request.

Validate the JSON has the required sections (`meta`, `color`, `typography`, `spacing`, `borderRadius`, `shadow`) before proceeding. See references/token-schema.md for the full schema.

## Conversion Rules

### px to rem

Divide by 16: `4px` becomes `0.25rem`, `16px` becomes `1rem`, `32px` becomes `2rem`.

**Exceptions:**
- `9999px` stays as `9999px` (used for `border-radius: full`).
- `0px` becomes `0` (no unit).

### Passthrough Values

These token types are not converted:
- Colors (`#2563EB`)
- Font families (`'Inter', sans-serif`)
- Font sources (URLs or `"system"`)
- Font weights (`600`)
- Line heights (`1.5`)
- Shadows (full CSS shadow syntax)
- Letter spacing (em values)

## Output Rules

### Header comments

Every generated file starts with a header comment containing the design system name (`meta.name`), source (`meta.source`), version (`meta.version`), and generation date.

### Component references

Resolve `{token.path}` references from the `components` section:
- `{color.primary}` becomes `var(--color-primary)` in CSS.
- `{spacing.6}` becomes `var(--space-6)` in CSS.
- `{borderRadius.md}` becomes `var(--radius-md)` in CSS.

### Semantic component classes

If the token JSON includes a `components` section, offer to generate utility classes such as `.btn-primary` that reference the CSS custom properties.

## Using the Script

For CSS and SCSS output, use the deterministic conversion script:

```bash
# CSS to stdout
python3 scripts/generate_css.py tokens.json

# SCSS to file
python3 scripts/generate_css.py tokens.json --format scss --output src/styles/_tokens.scss

# CSS to file
python3 scripts/generate_css.py tokens.json --format css --output src/tokens.css

# CSS with component utility classes
python3 scripts/generate_css.py tokens.json --components --output src/tokens.css

# SCSS with component mixins
python3 scripts/generate_css.py tokens.json --format scss --components --output src/styles/_tokens.scss
```

For Tailwind, React themes, and Vue composables, follow the templates in the corresponding reference files.

## Resources

### scripts/
- `generate_css.py` — Deterministic token to CSS/SCSS converter

### references/
- `token-schema.md` — Design token JSON schema (input format)
- `css-variables.md` — CSS custom properties and SCSS generation guide
- `tailwind-config.md` — Tailwind CSS config generation guide
- `react-theme.md` — React (styled-components, Emotion, Chakra UI, CSS Modules) and Vue 3 theme guides
