# React Native Theme Generation Guide

Reference for generating React Native theme files from the token JSON schema.

This is a **template-based** generation — no script needed. Follow the patterns below when converting tokens to TypeScript.

## Output File

`src/theme/theme.ts` — a single typed theme object with RN-compatible values.

## Template

```typescript
// {meta.name}
// Source: {meta.source}
// Version: {meta.version}
// Generated: {date}
// Format: React Native

// ============================================================================
// Colors
// ============================================================================

export const colors = {
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
} as const;

// ============================================================================
// Typography
// ============================================================================

export const fonts = {
  heading: 'Inter',
  body: 'Inter',
  mono: 'JetBrains Mono',
} as const;

export const fontSizes = {
  xs: 12,
  sm: 14,
  base: 16,
  lg: 18,
  xl: 20,
  '2xl': 24,
  '3xl': 30,
  '4xl': 36,
} as const;

export const fontWeights = {
  regular: '400' as const,
  medium: '500' as const,
  semibold: '600' as const,
  bold: '700' as const,
};

export const lineHeights = {
  tight: 1.25,
  normal: 1.5,
  relaxed: 1.75,
} as const;

export const letterSpacings = {
  tight: -0.4,
  normal: 0,
  wide: 0.8,
} as const;

// ============================================================================
// Spacing
// ============================================================================

export const spacing = {
  1: 4,
  2: 8,
  3: 12,
  4: 16,
  5: 20,
  6: 24,
  8: 32,
  10: 40,
  12: 48,
  16: 64,
} as const;

// ============================================================================
// Border Radius
// ============================================================================

export const radii = {
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  full: 9999,
} as const;

// ============================================================================
// Shadows (iOS + Android)
// ============================================================================

export const shadows = {
  sm: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  md: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.07,
    shadowRadius: 6,
    elevation: 3,
  },
  lg: {
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.1,
    shadowRadius: 15,
    elevation: 6,
  },
} as const;

// ============================================================================
// Combined Theme
// ============================================================================

export const theme = {
  colors,
  fonts,
  fontSizes,
  fontWeights,
  lineHeights,
  letterSpacings,
  spacing,
  radii,
  shadows,
} as const;

export type Theme = typeof theme;
```

## Conversion Rules

| Token Type | React Native Equivalent |
|---|---|
| Color `#RRGGBB` | `'#RRGGBB'` (string, same hex) |
| Dimension `Npx` | `N` (plain number, density-independent pixels) |
| Font weight `400` | `'400'` (string, RN requires string font weights) |
| Line height `1.5` | `1.5` (number, used as multiplier) |
| Letter spacing `-0.025em` | `-0.4` (convert em to px: `-0.025 * 16 = -0.4`) |
| Shadow | Object with `shadowColor`, `shadowOffset`, `shadowOpacity`, `shadowRadius` + `elevation` |

**Naming**: `token-name` → `camelCase` (e.g., `primary-light` → `primaryLight`).

### Letter Spacing Conversion

React Native uses numeric letter spacing in pixels, not `em`. Convert by multiplying by the base font size (16):

- `-0.025em` → `-0.4` (= -0.025 × 16)
- `0` → `0`
- `0.05em` → `0.8` (= 0.05 × 16)

### Shadow Conversion

React Native shadows differ between iOS and Android:

- **iOS**: Uses `shadowColor`, `shadowOffset`, `shadowOpacity`, `shadowRadius`
- **Android**: Uses `elevation` (single number)

Include both in the shadow object. Map shadow sizes to elevation values:

| Shadow | Elevation |
|---|---|
| sm | 1 |
| md | 3 |
| lg | 6 |
| xl | 10 |

## StyleSheet.create Patterns

### Component Styles

```typescript
import { StyleSheet } from 'react-native';
import { theme } from './theme';

export const componentStyles = StyleSheet.create({
  buttonPrimary: {
    backgroundColor: theme.colors.primary,
    paddingHorizontal: theme.spacing[6],
    paddingVertical: theme.spacing[3],
    borderRadius: theme.radii.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonPrimaryText: {
    color: '#FFFFFF',
    fontFamily: theme.fonts.body,
    fontSize: theme.fontSizes.sm,
    fontWeight: theme.fontWeights.semibold,
  },
  card: {
    backgroundColor: theme.colors.surface,
    borderRadius: theme.radii.lg,
    borderWidth: 1,
    borderColor: theme.colors.border,
    padding: theme.spacing[6],
    ...theme.shadows.sm,
  },
  input: {
    backgroundColor: theme.colors.surface,
    borderWidth: 1,
    borderColor: theme.colors.border,
    borderRadius: theme.radii.md,
    paddingHorizontal: theme.spacing[4],
    paddingVertical: theme.spacing[3],
    fontSize: theme.fontSizes.sm,
    color: theme.colors.textPrimary,
  },
  badge: {
    borderRadius: theme.radii.sm,
    paddingHorizontal: theme.spacing[2],
    paddingVertical: theme.spacing[1],
  },
  badgeText: {
    fontSize: theme.fontSizes.xs,
    fontWeight: theme.fontWeights.semibold,
  },
});
```

### Text Styles

```typescript
export const textStyles = StyleSheet.create({
  h1: {
    fontFamily: theme.fonts.heading,
    fontSize: theme.fontSizes['4xl'],
    fontWeight: theme.fontWeights.bold,
    lineHeight: theme.fontSizes['4xl'] * theme.lineHeights.tight,
    color: theme.colors.textPrimary,
  },
  h2: {
    fontFamily: theme.fonts.heading,
    fontSize: theme.fontSizes['3xl'],
    fontWeight: theme.fontWeights.bold,
    lineHeight: theme.fontSizes['3xl'] * theme.lineHeights.tight,
    color: theme.colors.textPrimary,
  },
  body: {
    fontFamily: theme.fonts.body,
    fontSize: theme.fontSizes.base,
    fontWeight: theme.fontWeights.regular,
    lineHeight: theme.fontSizes.base * theme.lineHeights.normal,
    color: theme.colors.textPrimary,
  },
  bodySmall: {
    fontFamily: theme.fonts.body,
    fontSize: theme.fontSizes.sm,
    fontWeight: theme.fontWeights.regular,
    lineHeight: theme.fontSizes.sm * theme.lineHeights.normal,
    color: theme.colors.textSecondary,
  },
  label: {
    fontFamily: theme.fonts.body,
    fontSize: theme.fontSizes.sm,
    fontWeight: theme.fontWeights.medium,
    color: theme.colors.textPrimary,
  },
  mono: {
    fontFamily: theme.fonts.mono,
    fontSize: theme.fontSizes.sm,
    fontWeight: theme.fontWeights.regular,
    color: theme.colors.textPrimary,
  },
});
```

## Font Loading

When `typography.font-source` tokens are present in the design token JSON, use them to set up custom fonts:

### Expo Projects

1. **Use `expo-google-fonts`** (recommended) — Install the package for each Google Font:
   ```bash
   npx expo install @expo-google-fonts/inter expo-font
   ```
   Then load in your app entry:
   ```typescript
   import { useFonts, Inter_400Regular, Inter_500Medium, Inter_600SemiBold, Inter_700Bold } from '@expo-google-fonts/inter';
   ```
2. **Or use `expo-font`** — Download `.ttf` files from the `font-source` URL, place in `assets/fonts/`, and load with `Font.loadAsync()`.

### Bare React Native Projects

1. **Download font files** — Use the `font-source` URL (e.g., Google Fonts) to download the `.ttf` files.
2. **Place in assets** — Add files to `assets/fonts/`.
3. **Link fonts** — Run `npx react-native-asset` to link the fonts to the native projects.

### System Fonts

If the `font-source` value is `"system"`, no font loading is needed. Remove the `fontFamily` property from styles to use the platform default.

## Integration Guidance

After generating `theme.ts`:

1. Place in `src/theme/`
2. Import and use throughout the app:
   ```typescript
   import { theme } from '../theme/theme';
   ```
3. Load custom fonts using the font source URLs (see Font Loading above)
4. Consider creating a `ThemeProvider` with React Context for dynamic theming
5. Use the spread operator for shadows: `...theme.shadows.md`
6. React Native line heights are absolute values (not multipliers), so compute: `fontSize * lineHeightMultiplier`
7. Font weights in React Native must be strings (`'600'`), not numbers
