# React Theme Generation Guide

How to convert design tokens into theme files for React ecosystems: styled-components/Emotion, Chakra UI, CSS Modules, and Vue 3.

## styled-components / Emotion

### Theme Definition

```ts
// theme.ts
export const theme = {
  colors: {
    primary: '#2563EB',
    primaryLight: '#60A5FA',
    primaryDark: '#1D4ED8',
    secondary: '#7C3AED',
    accent: '#F59E0B',
    background: '#F9FAFB',
    surface: '#FFFFFF',
    textPrimary: '#111827',
    textSecondary: '#6B7280',
    textTertiary: '#9CA3AF',
    border: '#E5E7EB',
    borderLight: '#F3F4F6',
    error: '#EF4444',
    warning: '#F59E0B',
    success: '#10B981',
    info: '#3B82F6',
  },
  fonts: {
    heading: "'Inter', sans-serif",
    body: "'Inter', sans-serif",
    mono: "'JetBrains Mono', monospace",
  },
  fontSizes: {
    xs: '0.75rem',
    sm: '0.875rem',
    base: '1rem',
    lg: '1.125rem',
    xl: '1.25rem',
    '2xl': '1.5rem',
    '3xl': '1.875rem',
    '4xl': '2.25rem',
  },
  fontWeights: {
    regular: 400,
    medium: 500,
    semibold: 600,
    bold: 700,
  },
  lineHeights: {
    tight: 1.25,
    normal: 1.5,
    relaxed: 1.75,
  },
  letterSpacings: {
    tight: '-0.025em',
    normal: '0',
    wide: '0.05em',
  },
  space: {
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
  radii: {
    sm: '0.25rem',
    md: '0.5rem',
    lg: '0.75rem',
    xl: '1rem',
    full: '9999px',
  },
  shadows: {
    sm: '0 1px 2px rgba(0,0,0,0.05)',
    md: '0 4px 6px -1px rgba(0,0,0,0.07)',
    lg: '0 10px 15px -3px rgba(0,0,0,0.1)',
    xl: '0 20px 25px -5px rgba(0,0,0,0.1)',
  },
} as const;

export type Theme = typeof theme;
```

### ThemeProvider Setup

```tsx
// App.tsx
import { ThemeProvider } from 'styled-components';
import { theme } from './theme';

function App() {
  return (
    <ThemeProvider theme={theme}>
      {/* app content */}
    </ThemeProvider>
  );
}
```

### Type Augmentation

```ts
// styled.d.ts
import 'styled-components';
import type { Theme } from './theme';

declare module 'styled-components' {
  export interface DefaultTheme extends Theme {}
}
```

### Usage

```ts
const Card = styled.div`
  background: ${({ theme }) => theme.colors.surface};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: ${({ theme }) => theme.radii.lg};
  padding: ${({ theme }) => theme.space[6]};
  box-shadow: ${({ theme }) => theme.shadows.sm};
`;
```

## Chakra UI

Map tokens to Chakra's `extendTheme()` format:

```ts
// theme.ts
import { extendTheme } from '@chakra-ui/react';

const theme = extendTheme({
  colors: {
    primary: {
      50: '#EFF6FF',   // derive or leave out if not in tokens
      100: '#DBEAFE',
      300: '#60A5FA',  // primary-light
      500: '#2563EB',  // primary (DEFAULT)
      700: '#1D4ED8',  // primary-dark
      900: '#1E3A8A',
    },
    secondary: {
      500: '#7C3AED',
    },
    accent: {
      500: '#F59E0B',
    },
    success: {
      500: '#10B981',
    },
    error: {
      500: '#EF4444',
    },
    warning: {
      500: '#F59E0B',
    },
    info: {
      500: '#3B82F6',
    },
  },
  fonts: {
    heading: "'Inter', sans-serif",
    body: "'Inter', sans-serif",
    mono: "'JetBrains Mono', monospace",
  },
  fontSizes: {
    xs: '0.75rem',
    sm: '0.875rem',
    md: '1rem',      // Chakra uses 'md' instead of 'base'
    lg: '1.125rem',
    xl: '1.25rem',
    '2xl': '1.5rem',
    '3xl': '1.875rem',
    '4xl': '2.25rem',
  },
  fontWeights: {
    normal: 400,      // Chakra uses 'normal' instead of 'regular'
    medium: 500,
    semibold: 600,
    bold: 700,
  },
  lineHeights: {
    tight: 1.25,
    normal: 1.5,
    relaxed: 1.75,
  },
  letterSpacings: {
    tight: '-0.025em',
    normal: '0',
    wide: '0.05em',
  },
  space: {
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
  radii: {
    sm: '0.25rem',
    md: '0.5rem',
    lg: '0.75rem',
    xl: '1rem',
    full: '9999px',
  },
  shadows: {
    sm: '0 1px 2px rgba(0,0,0,0.05)',
    md: '0 4px 6px -1px rgba(0,0,0,0.07)',
    lg: '0 10px 15px -3px rgba(0,0,0,0.1)',
    xl: '0 20px 25px -5px rgba(0,0,0,0.1)',
  },
});

export default theme;
```

### Chakra Color Mapping Rules

| Token | Chakra Shade | Rationale |
|---|---|---|
| `color.primary` | `primary.500` | Main shade |
| `color.primary-light` | `primary.300` | Lighter variant |
| `color.primary-dark` | `primary.700` | Darker variant |

If only a single color is provided (no `-light`/`-dark`), place it at `500`.

## CSS Modules + TypeScript

For projects using CSS Modules without a CSS-in-JS library.

### CSS Variables File

Generate using `scripts/generate_css.py`:

```css
/* tokens.css */
:root {
  --color-primary: #2563EB;
  /* ... all variables ... */
}
```

### TypeScript Constants

```ts
// tokens.ts
export const tokens = {
  colors: {
    primary: 'var(--color-primary)',
    primaryLight: 'var(--color-primary-light)',
    primaryDark: 'var(--color-primary-dark)',
    secondary: 'var(--color-secondary)',
    accent: 'var(--color-accent)',
    background: 'var(--color-background)',
    surface: 'var(--color-surface)',
    textPrimary: 'var(--color-text-primary)',
    textSecondary: 'var(--color-text-secondary)',
    textTertiary: 'var(--color-text-tertiary)',
    border: 'var(--color-border)',
    borderLight: 'var(--color-border-light)',
    error: 'var(--color-error)',
    warning: 'var(--color-warning)',
    success: 'var(--color-success)',
    info: 'var(--color-info)',
  },
  fonts: {
    heading: 'var(--font-heading)',
    body: 'var(--font-body)',
    mono: 'var(--font-mono)',
  },
  fontSizes: {
    xs: 'var(--font-size-xs)',
    sm: 'var(--font-size-sm)',
    base: 'var(--font-size-base)',
    lg: 'var(--font-size-lg)',
    xl: 'var(--font-size-xl)',
  },
  space: {
    1: 'var(--space-1)',
    2: 'var(--space-2)',
    3: 'var(--space-3)',
    4: 'var(--space-4)',
    6: 'var(--space-6)',
    8: 'var(--space-8)',
  },
  radii: {
    sm: 'var(--radius-sm)',
    md: 'var(--radius-md)',
    lg: 'var(--radius-lg)',
    xl: 'var(--radius-xl)',
    full: 'var(--radius-full)',
  },
  shadows: {
    sm: 'var(--shadow-sm)',
    md: 'var(--shadow-md)',
    lg: 'var(--shadow-lg)',
    xl: 'var(--shadow-xl)',
  },
} as const;
```

Import `tokens.css` in your entry point and use `tokens.ts` for type-safe references:

```tsx
import './tokens.css';
import { tokens } from './tokens';
import styles from './Card.module.css';

function Card({ children }) {
  return <div className={styles.card}>{children}</div>;
}
```

## Vue 3

### CSS Variables + Composable

Generate the CSS file with `scripts/generate_css.py`, then create a composable for typed access:

```ts
// composables/useTheme.ts
export function useTheme() {
  return {
    colors: {
      primary: 'var(--color-primary)',
      primaryLight: 'var(--color-primary-light)',
      primaryDark: 'var(--color-primary-dark)',
      secondary: 'var(--color-secondary)',
      accent: 'var(--color-accent)',
      background: 'var(--color-background)',
      surface: 'var(--color-surface)',
      textPrimary: 'var(--color-text-primary)',
      textSecondary: 'var(--color-text-secondary)',
      border: 'var(--color-border)',
      error: 'var(--color-error)',
      warning: 'var(--color-warning)',
      success: 'var(--color-success)',
      info: 'var(--color-info)',
    },
    fonts: {
      heading: 'var(--font-heading)',
      body: 'var(--font-body)',
      mono: 'var(--font-mono)',
    },
    space: (n: number) => `var(--space-${n})`,
    radius: (size: 'sm' | 'md' | 'lg' | 'xl' | 'full') => `var(--radius-${size})`,
    shadow: (size: 'sm' | 'md' | 'lg' | 'xl') => `var(--shadow-${size})`,
    fontSize: (size: string) => `var(--font-size-${size})`,
  } as const;
}
```

### Usage in SFC

```vue
<script setup lang="ts">
import { useTheme } from '@/composables/useTheme';

const theme = useTheme();
</script>

<template>
  <div :style="{ color: theme.colors.primary, padding: theme.space(4) }">
    Themed content
  </div>
</template>
```

## Component Tokens

If the token JSON includes a `components` section, convert component tokens into framework-appropriate styles.

### styled-components / Emotion

Create styled components that resolve `{token.path}` references to theme accessors:

```ts
// components.ts
import styled from 'styled-components';

export const ButtonPrimary = styled.button`
  background: ${({ theme }) => theme.colors.primary};
  color: #FFFFFF;
  border: none;
  border-radius: ${({ theme }) => theme.radii.md};
  padding: ${({ theme }) => theme.space[3]} ${({ theme }) => theme.space[6]};
  font-weight: ${({ theme }) => theme.fontWeights.semibold};
  font-size: ${({ theme }) => theme.fontSizes.sm};

  &:hover {
    background: ${({ theme }) => theme.colors.primaryLight};
  }
`;

export const Card = styled.div`
  background: ${({ theme }) => theme.colors.surface};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: ${({ theme }) => theme.radii.lg};
  padding: ${({ theme }) => theme.space[6]};
  box-shadow: ${({ theme }) => theme.shadows.sm};
`;

export const Input = styled.input`
  background: ${({ theme }) => theme.colors.surface};
  border: 1px solid ${({ theme }) => theme.colors.border};
  border-radius: ${({ theme }) => theme.radii.md};
  padding: ${({ theme }) => theme.space[3]} ${({ theme }) => theme.space[4]};
  font-size: ${({ theme }) => theme.fontSizes.sm};
  color: ${({ theme }) => theme.colors.textPrimary};

  &::placeholder {
    color: ${({ theme }) => theme.colors.textTertiary};
  }

  &:focus {
    border-color: ${({ theme }) => theme.colors.primary};
    outline: none;
  }
`;
```

### Chakra UI

Map component tokens to Chakra's component style overrides:

```ts
// theme.ts (add to extendTheme)
const theme = extendTheme({
  // ... token values ...
  components: {
    Button: {
      variants: {
        primary: {
          bg: 'primary.500',
          color: 'white',
          borderRadius: 'md',
          fontWeight: 'semibold',
          fontSize: 'sm',
          px: 6,
          py: 3,
          _hover: { bg: 'primary.300' },
        },
        secondary: {
          bg: 'transparent',
          color: 'gray.900',
          border: '1px solid',
          borderColor: 'gray.200',
          borderRadius: 'md',
          fontWeight: 'semibold',
          fontSize: 'sm',
          px: 6,
          py: 3,
        },
      },
    },
    Card: {
      baseStyle: {
        bg: 'white',
        border: '1px solid',
        borderColor: 'gray.200',
        borderRadius: 'lg',
        p: 6,
        shadow: 'sm',
      },
    },
    Input: {
      variants: {
        themed: {
          field: {
            bg: 'white',
            borderColor: 'gray.200',
            borderRadius: 'md',
            fontSize: 'sm',
            _placeholder: { color: 'gray.400' },
            _focus: { borderColor: 'primary.500' },
          },
        },
      },
    },
  },
});
```

### CSS Modules

Generate a CSS file with component classes using `var()` references, then import in modules:

```css
/* components.module.css */
.btnPrimary {
  background-color: var(--color-primary);
  color: #FFFFFF;
  border: none;
  border-radius: var(--radius-md);
  padding: var(--space-3) var(--space-6);
  font-weight: var(--font-weight-semibold);
  font-size: var(--font-size-sm);
}

.btnPrimary:hover {
  background-color: var(--color-primary-light);
}

.card {
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
  box-shadow: var(--shadow-sm);
}
```

Use `generate_css.py --components` to auto-generate these classes from the token JSON.

## Font Loading

All framework variants need to load the actual font files. The `typography.font-source` tokens provide the URLs. Skip any entry with value `"system"`.

### styled-components / Emotion

Add font imports to your global styles using `createGlobalStyle`:

```ts
import { createGlobalStyle } from 'styled-components';

const GlobalStyle = createGlobalStyle`
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
  @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap');
`;

// Include <GlobalStyle /> at the top of your App alongside <ThemeProvider>
```

### Chakra UI

Add font `<link>` tags in your HTML `<head>` or use `@fontsource` packages:

```bash
npm install @fontsource/inter @fontsource/jetbrains-mono
```

```ts
// In your entry point (e.g., main.tsx)
import '@fontsource/inter/400.css';
import '@fontsource/inter/500.css';
import '@fontsource/inter/600.css';
import '@fontsource/inter/700.css';
import '@fontsource/jetbrains-mono/400.css';
```

### CSS Modules

Import font URLs at the top of your `tokens.css` file (handled automatically by `generate_css.py`):

```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

:root {
  --font-heading: 'Inter', sans-serif;
  /* ... */
}
```

### Vue 3

Add font imports to your main CSS file or `App.vue`:

```css
/* src/assets/main.css */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap');
```

Or use `<link>` tags in `index.html`.

## Key Conversion Rules (All Frameworks)

- Convert `px` → `rem` (÷16) for all dimension values
- Exception: `9999px` stays as-is
- camelCase property names in JS/TS objects (`text-primary` → `textPrimary`)
- Font weights are numeric in JS/TS (not strings)
- Line heights are unitless numbers
- Keep original shadow syntax strings
