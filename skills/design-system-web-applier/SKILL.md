---
name: design-system-web-applier
description: >
  Generate stack-appropriate theme files from design token JSON. Converts extracted design tokens
  into CSS custom properties, SCSS variables, Tailwind CSS config, React themes (styled-components,
  Emotion, Chakra UI), CSS Modules with TypeScript, or Vue 3 composables. Use this skill when a
  user has a design token JSON artifact (from design-system-extractor or hand-authored) and wants
  to: (1) generate CSS custom properties or SCSS variables from tokens, (2) create a Tailwind
  config extending the default theme with their tokens, (3) build a typed React theme object for
  styled-components, Emotion, or Chakra UI, (4) produce CSS Modules + TypeScript constants, or
  (5) create Vue 3 theme composables. Do NOT use for: extracting tokens from screenshots (use
  design-system-extractor), building mobile themes (React Native, iOS, Android), generating
  generic CSS unrelated to a token file, answering general design system questions, or creating
  new design systems from scratch.
---

# Design System Web Applier

Convert design token JSON into production-ready theme files for any web stack.

## Workflow

1. **Receive tokens** — accept a JSON file path, a Markdown file with a JSON code block, or inline JSON pasted in chat
2. **Detect or ask for stack** — inspect the project for indicators (see Stack Detection below); if ambiguous, ask the user
3. **Read the appropriate reference** — load the reference file for the target stack
4. **Generate font imports** — extract `typography.font-source` URLs and emit `@import url(...)` declarations (skip entries with value `"system"`)
5. **Generate output** — run `scripts/generate_css.py` for CSS/SCSS; follow the reference guide templates for Tailwind/React/Vue
6. **Write files + provide integration guidance** — place output files in the project and explain how to wire them in (including font loading for Tailwind/React/Vue stacks)

## Stack Detection

Inspect the project to determine the target stack before generating output:

| Indicator | Stack | Reference | Output File |
|---|---|---|---|
| `tailwind.config.{js,ts,mjs}` or `@tailwindcss` in deps | Tailwind CSS | references/tailwind-config.md | `tailwind.config.{js,ts}` (extend) |
| `styled-components` or `@emotion` in deps | styled-components/Emotion | references/react-theme.md | `src/theme.ts` |
| `@chakra-ui/react` in deps | Chakra UI | references/react-theme.md | `src/theme.ts` |
| `*.module.css` files + TypeScript | CSS Modules + TS | references/react-theme.md | `src/tokens.css` + `src/tokens.ts` |
| `vue` in deps | Vue 3 | references/react-theme.md | `src/tokens.css` + `src/composables/useTheme.ts` |
| `.scss` files or `sass` in deps | SCSS | references/css-variables.md | `src/styles/_tokens.scss` |
| No framework detected / plain HTML | CSS Custom Properties | references/css-variables.md | `src/tokens.css` |

If multiple stacks are detected (e.g., Tailwind + React), generate for both — a Tailwind config and a CSS variables file.

## Token Input Formats

Accept tokens in any of these forms:

1. **JSON file path** — `tokens.json` or any `.json` file containing the token schema
2. **Markdown with JSON block** — extract the JSON from the fenced code block
3. **Inline JSON** — pasted directly in chat

Validate the JSON has the required sections (`meta`, `color`, `typography`, `spacing`, `borderRadius`, `shadow`) before proceeding. See references/token-schema.md for the full schema.

## Conversion Rules

### px → rem

Divide by 16: `4px` → `0.25rem`, `16px` → `1rem`, `32px` → `2rem`.

**Exceptions:**
- `9999px` → stays as `9999px` (used for `border-radius: full`)
- `0px` → `0` (no unit)

### Passthrough values

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

Every generated file starts with a header comment containing:
- Design system name (`meta.name`)
- Source (`meta.source`)
- Version (`meta.version`)
- Generation date

### Component references

When generating component utility classes, resolve `{token.path}` references from the `components` section:
- `{color.primary}` → `var(--color-primary)` in CSS
- `{spacing.6}` → `var(--space-6)` in CSS
- `{borderRadius.md}` → `var(--radius-md)` in CSS

### Semantic component classes (optional)

If the token JSON includes a `components` section, offer to generate utility classes:

```css
.btn-primary {
  background-color: var(--color-primary);
  color: #FFFFFF;
  border-radius: var(--radius-md);
  padding: var(--space-3) var(--space-6);
  font-weight: var(--font-weight-semibold);
  font-size: var(--font-size-sm);
}
```

## Using the Script

For CSS and SCSS output, use the deterministic conversion script:

```bash
# CSS to stdout
python3 scripts/generate_css.py tokens.json

# SCSS to file
python3 scripts/generate_css.py tokens.json --format scss --output src/styles/_tokens.scss

# CSS to file
python3 scripts/generate_css.py tokens.json --format css --output src/tokens.css

# CSS with component utility classes (from the components section)
python3 scripts/generate_css.py tokens.json --components --output src/tokens.css

# SCSS with component mixins
python3 scripts/generate_css.py tokens.json --format scss --components --output src/styles/_tokens.scss
```

For Tailwind, React themes, and Vue composables, follow the templates in the corresponding reference files — these require structural decisions that the script doesn't handle.

## Resources

### scripts/
- `generate_css.py` — Deterministic token → CSS/SCSS converter

### references/
- `token-schema.md` — Design token JSON schema (input format)
- `css-variables.md` — CSS custom properties and SCSS generation guide
- `tailwind-config.md` — Tailwind CSS config generation guide
- `react-theme.md` — React (styled-components, Emotion, Chakra UI, CSS Modules) and Vue 3 theme guides
