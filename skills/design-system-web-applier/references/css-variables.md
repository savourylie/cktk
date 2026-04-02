# CSS Custom Properties Generation Guide

How to convert design tokens into CSS custom properties (`:root` variables) and SCSS variables.

## Naming Convention

Token paths map to CSS variable names as follows:

| Token Path | CSS Variable | Rule |
|---|---|---|
| `color.primary` | `--color-primary` | `--color-{name}` |
| `color.text-primary` | `--color-text-primary` | `--color-{name}` |
| `typography.font-family-heading` | `--font-heading` | `--font-{heading\|body\|mono}` |
| `typography.font-family-body` | `--font-body` | `--font-{heading\|body\|mono}` |
| `typography.font-family-mono` | `--font-mono` | `--font-{heading\|body\|mono}` |
| `typography.font-size.xs` | `--font-size-xs` | `--font-size-{scale}` |
| `typography.font-weight.bold` | `--font-weight-bold` | `--font-weight-{name}` |
| `typography.line-height.normal` | `--line-height-normal` | `--line-height-{name}` |
| `typography.letter-spacing.tight` | `--letter-spacing-tight` | `--letter-spacing-{name}` |
| `spacing.1` | `--space-1` | `--space-{n}` |
| `borderRadius.sm` | `--radius-sm` | `--radius-{name}` |
| `shadow.md` | `--shadow-md` | `--shadow-{name}` |

## Value Conversion Rules

| Token Type | Conversion | Example |
|---|---|---|
| `color` | Passthrough | `#2563EB` → `#2563EB` |
| `dimension` (px) | px → rem (÷16) | `16px` → `1rem`, `4px` → `0.25rem` |
| `dimension` (em) | Passthrough | `-0.025em` → `-0.025em` |
| `fontFamily` | Passthrough | `'Inter', sans-serif` |
| `fontWeight` | Passthrough | `600` → `600` |
| `number` | Passthrough | `1.5` → `1.5` |
| `shadow` | Passthrough | full shadow syntax |

**Special cases:**
- `0px` → `0` (no unit)
- `9999px` → `9999px` (stays as px — used for `border-radius: full`)

## CSS Output Template

```css
/* {meta.name}
 * Source: {meta.source}
 * Version: {meta.version}
 * Generated: {date}
 * Format: CSS Custom Properties
 */

@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap');

:root {
  /* Colors */
  --color-primary: #2563EB;
  --color-primary-light: #60A5FA;
  --color-primary-dark: #1D4ED8;
  /* ... */

  /* Typography */
  --font-heading: 'Inter', sans-serif;
  --font-body: 'Inter', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  --font-size-xs: 0.75rem;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  /* ... */
  --font-weight-regular: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
  --line-height-tight: 1.25;
  --line-height-normal: 1.5;
  --line-height-relaxed: 1.75;
  --letter-spacing-tight: -0.025em;
  --letter-spacing-normal: 0;
  --letter-spacing-wide: 0.05em;

  /* Spacing */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  /* ... */

  /* Border Radius */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 6px -1px rgba(0,0,0,0.07);
  /* ... */
}
```

## SCSS Variant

SCSS uses `$variable` syntax instead of `--variable`, plus generates maps per section:

```scss
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap');

// Colors
$color-primary: #2563EB;
$color-primary-light: #60A5FA;
// ...

// Typography
$font-heading: 'Inter', sans-serif;
$font-size-xs: 0.75rem;
// ...

// Maps
$colors: (
  "color-primary": #2563EB,
  "color-primary-light": #60A5FA,
  // ...
);

$spacing: (
  "space-1": 0.25rem,
  "space-2": 0.5rem,
  // ...
);
```

Maps enable iteration with `@each`:
```scss
@each $name, $value in $colors {
  .bg-#{$name} { background-color: $value; }
}
```

## Component Utility Classes (Optional)

Generate semantic component classes using `var()` references:

```css
.btn-primary {
  background-color: var(--color-primary);
  color: #FFFFFF;
  border-radius: var(--radius-md);
  padding: var(--space-3) var(--space-6);
  font-weight: var(--font-weight-semibold);
  font-size: var(--font-size-sm);
}

.card {
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
  box-shadow: var(--shadow-sm);
}
```

Resolve `{token.path}` references from the `components` section of the token JSON into the corresponding `var(--name)` calls.

## Using the Script

For deterministic CSS/SCSS output, run the conversion script:

```bash
# CSS output to stdout
python3 scripts/generate_css.py tokens.json

# SCSS output to file
python3 scripts/generate_css.py tokens.json --format scss --output src/styles/_tokens.scss

# CSS output to file
python3 scripts/generate_css.py tokens.json --format css --output src/styles/tokens.css

# CSS with component utility classes
python3 scripts/generate_css.py tokens.json --components --output src/styles/tokens.css

# SCSS with component mixins
python3 scripts/generate_css.py tokens.json --format scss --components --output src/styles/_tokens.scss
```
