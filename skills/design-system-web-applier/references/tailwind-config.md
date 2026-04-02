# Tailwind Config Generation Guide

How to convert design tokens into a Tailwind CSS configuration that extends the default theme.

## Token-to-Tailwind Mapping

| Token Section | Tailwind Key | Notes |
|---|---|---|
| `color.*` | `colors` | Group by prefix (primary → `primary: { DEFAULT, light, dark }`) |
| `typography.font-family-*` | `fontFamily` | `heading`, `body`, `mono` |
| `typography.font-size.*` | `fontSize` | Tuples with line-height |
| `typography.font-weight.*` | `fontWeight` | Numeric values |
| `typography.line-height.*` | `lineHeight` | Unitless ratios |
| `typography.letter-spacing.*` | `letterSpacing` | em values |
| `spacing.*` | `spacing` | px → rem conversion |
| `borderRadius.*` | `borderRadius` | px → rem (except `9999px`) |
| `shadow.*` | `boxShadow` | Full shadow syntax |

## JavaScript Output

```js
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#2563EB',
          light: '#60A5FA',
          dark: '#1D4ED8',
        },
        secondary: '#7C3AED',
        accent: '#F59E0B',
        background: '#F9FAFB',
        surface: '#FFFFFF',
        'text-primary': '#111827',
        'text-secondary': '#6B7280',
        'text-tertiary': '#9CA3AF',
        border: '#E5E7EB',
        'border-light': '#F3F4F6',
        error: '#EF4444',
        warning: '#F59E0B',
        success: '#10B981',
        info: '#3B82F6',
      },
      fontFamily: {
        heading: ["'Inter'", 'sans-serif'],
        body: ["'Inter'", 'sans-serif'],
        mono: ["'JetBrains Mono'", 'monospace'],
      },
      fontSize: {
        xs: ['0.75rem', { lineHeight: '1.25' }],
        sm: ['0.875rem', { lineHeight: '1.5' }],
        base: ['1rem', { lineHeight: '1.5' }],
        lg: ['1.125rem', { lineHeight: '1.5' }],
        xl: ['1.25rem', { lineHeight: '1.25' }],
        '2xl': ['1.5rem', { lineHeight: '1.25' }],
        '3xl': ['1.875rem', { lineHeight: '1.25' }],
        '4xl': ['2.25rem', { lineHeight: '1.25' }],
      },
      fontWeight: {
        regular: '400',
        medium: '500',
        semibold: '600',
        bold: '700',
      },
      lineHeight: {
        tight: '1.25',
        normal: '1.5',
        relaxed: '1.75',
      },
      letterSpacing: {
        tight: '-0.025em',
        normal: '0',
        wide: '0.05em',
      },
      spacing: {
        1: '0.25rem',
        2: '0.5rem',
        3: '0.75rem',
        4: '1rem',
        5: '1.25rem',
        6: '1.5rem',
        8: '2rem',
        10: '2.5rem',
        12: '3rem',
        16: '4rem',
      },
      borderRadius: {
        sm: '0.25rem',
        md: '0.5rem',
        lg: '0.75rem',
        xl: '1rem',
        full: '9999px',
      },
      boxShadow: {
        sm: '0 1px 2px rgba(0,0,0,0.05)',
        md: '0 4px 6px -1px rgba(0,0,0,0.07)',
        lg: '0 10px 15px -3px rgba(0,0,0,0.1)',
        xl: '0 20px 25px -5px rgba(0,0,0,0.1)',
      },
    },
  },
};
```

## TypeScript Output

```ts
// tailwind.config.ts
import type { Config } from 'tailwindcss';

const config: Config = {
  theme: {
    extend: {
      // ... same structure as JS
    },
  },
};

export default config;
```

## Color Grouping Rules

Colors with shared prefixes are grouped into nested objects:

| Token | Tailwind Key | Usage |
|---|---|---|
| `color.primary` | `primary.DEFAULT` | `bg-primary`, `text-primary` |
| `color.primary-light` | `primary.light` | `bg-primary-light` |
| `color.primary-dark` | `primary.dark` | `bg-primary-dark` |
| `color.secondary` | `secondary` | `bg-secondary` (no variants → flat) |

Only group when there are actual `-light`/`-dark` variants present.

## Font Size Tuples

Tailwind fontSize supports tuples with line-height for cohesive typography:

```js
fontSize: {
  xs: ['0.75rem', { lineHeight: '1.25' }],
  sm: ['0.875rem', { lineHeight: '1.5' }],
}
```

Map `line-height.tight` to headings (xl+), `line-height.normal` to body text (base and smaller). This is a reasonable default; adjust if the token data suggests otherwise.

## CSS Variables Hybrid Approach

For runtime theme switching (dark mode, user preferences), combine CSS variables with Tailwind:

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: 'var(--color-primary)',
          light: 'var(--color-primary-light)',
          dark: 'var(--color-primary-dark)',
        },
        surface: 'var(--color-surface)',
        background: 'var(--color-background)',
        // ...
      },
    },
  },
};
```

Then define the actual values in CSS:

```css
:root {
  --color-primary: #2563EB;
  --color-surface: #FFFFFF;
  --color-background: #F9FAFB;
}

.dark {
  --color-primary: #60A5FA;
  --color-surface: #1F2937;
  --color-background: #111827;
}
```

This lets Tailwind classes like `bg-primary` resolve dynamically at runtime.

## Component Tokens

If the token JSON includes a `components` section, map each component to Tailwind's `@layer components` using `@apply` directives.

### CSS File (e.g. `src/components.css`)

```css
@layer components {
  .btn-primary {
    @apply bg-primary text-white rounded-md px-6 py-3 font-semibold text-sm;
  }

  .card {
    @apply bg-surface border border-border rounded-lg p-6 shadow-sm;
  }

  .input {
    @apply bg-surface border border-border rounded-md px-4 py-3 text-sm text-text-primary
           placeholder:text-text-tertiary focus:border-primary;
  }

  .badge {
    @apply rounded-sm px-2 py-1 text-xs font-semibold;
  }
}
```

### Mapping Rules

| Component Property | Tailwind Equivalent |
|---|---|
| `background: {color.primary}` | `bg-primary` |
| `color: {color.text-primary}` | `text-text-primary` |
| `border-radius: {borderRadius.md}` | `rounded-md` |
| `padding: {spacing.3} {spacing.6}` | `px-6 py-3` |
| `font-weight: {typography.font-weight.semibold}` | `font-semibold` |
| `font-size: {typography.font-size.sm}` | `text-sm` |
| `shadow: {shadow.sm}` | `shadow-sm` |
| `focus-border: {color.primary}` | `focus:border-primary` |
| `placeholder-color: {color.text-tertiary}` | `placeholder:text-text-tertiary` |

Resolve `{token.path}` references to the corresponding Tailwind utility class. For state properties (`hover-*`, `focus-*`, `active-*`, `placeholder-*`), use Tailwind's variant prefix syntax.

## Font Loading

Tailwind config defines font family names but doesn't load the font files. You must add font imports to your global CSS file (e.g., `src/globals.css` or `src/app.css`):

```css
/* Global CSS — load fonts before Tailwind directives */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;
```

Alternatively, use `<link>` tags in your HTML `<head>`:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
```

The font URLs come from the `typography.font-source` tokens. Skip any entry with value `"system"` — system fonts don't need imports.

## Key Principles

- Always use `theme.extend` (not `theme`) to preserve Tailwind's built-in defaults
- Convert all px values to rem (÷16), except `9999px`
- Keep string values for font weights so Tailwind handles them correctly
- Quote font family names that contain spaces
