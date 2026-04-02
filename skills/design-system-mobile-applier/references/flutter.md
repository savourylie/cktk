# Flutter Theme Generation Guide

Reference for generating Flutter `ThemeData` from the token JSON schema.

This is a **template-based** generation — no script needed. Follow the patterns below when converting tokens to Dart code.

## Output File

`lib/theme/app_theme.dart` — a single file containing the complete theme.

## Template

```dart
// {meta.name}
// Source: {meta.source}
// Version: {meta.version}
// Generated: {date}
// Format: Flutter ThemeData

import 'package:flutter/material.dart';

// ============================================================================
// Colors
// ============================================================================

class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF1D4ED8);
  static const secondary = Color(0xFF7C3AED);
  static const accent = Color(0xFFF59E0B);
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const info = Color(0xFF3B82F6);
}

// ============================================================================
// Typography
// ============================================================================

class AppTypography {
  static const fontFamilyHeading = 'Inter';
  static const fontFamilyBody = 'Inter';
  static const fontFamilyMono = 'JetBrains Mono';
}

// ============================================================================
// Spacing
// ============================================================================

class AppSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;
}

// ============================================================================
// Border Radius
// ============================================================================

class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;

  static final smRadius = BorderRadius.circular(sm);
  static final mdRadius = BorderRadius.circular(md);
  static final lgRadius = BorderRadius.circular(lg);
  static final xlRadius = BorderRadius.circular(xl);
  static final fullRadius = BorderRadius.circular(full);
}

// ============================================================================
// Shadows
// ============================================================================

class AppShadows {
  static final sm = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static final md = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

  static final lg = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 15,
      offset: const Offset(0, 10),
    ),
  ];
}

// ============================================================================
// Theme
// ============================================================================

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamilyBody,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
        displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, fontFamily: 'Inter'),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, fontFamily: 'Inter'),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space6,
            vertical: AppSpacing.space3,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
      ),
    );
  }
}
```

## Conversion Rules

| Token Type | Dart Equivalent |
|---|---|
| Color `#RRGGBB` | `Color(0xFFRRGGBB)` |
| Dimension `Npx` | `N` (plain double, logical pixels) |
| Font weight `400` | `FontWeight.w400` |
| Font weight `500` | `FontWeight.w500` |
| Font weight `600` | `FontWeight.w600` |
| Font weight `700` | `FontWeight.w700` |
| Shadow | `BoxShadow(color:, blurRadius:, offset:)` |
| Border radius | `BorderRadius.circular(N)` |

**Naming**: `token-name` → `camelCase` (e.g., `primary-light` → `primaryLight`).

## Material 3 Mapping

Same as Android Compose — see `android-compose.md` for the full color scheme and typography mapping tables.

## Font Registration

When `typography.font-source` tokens are present in the design token JSON, use them to set up custom fonts:

1. **Download font files** — Use the `font-source` URL (e.g., Google Fonts) to download the `.ttf` files for each font family. Extract the individual weight files (Regular, Medium, SemiBold, Bold).
2. **Place in assets** — Add font files to `assets/fonts/` in your project.
3. **Register in pubspec.yaml** — Declare each font family and its weight variants:
   ```yaml
   fonts:
     - family: Inter
       fonts:
         - asset: assets/fonts/Inter-Regular.ttf
         - asset: assets/fonts/Inter-Medium.ttf
           weight: 500
         - asset: assets/fonts/Inter-SemiBold.ttf
           weight: 600
         - asset: assets/fonts/Inter-Bold.ttf
           weight: 700
   ```
4. **System fonts** — If the `font-source` value is `"system"`, no font files or `pubspec.yaml` registration is needed.

## Integration Guidance

After generating `app_theme.dart`:

1. Place in `lib/theme/`
2. Register custom fonts using the font source URLs (see Font Registration above)
3. Apply in `MaterialApp`:
   ```dart
   MaterialApp(
     theme: AppTheme.light,
     // ...
   )
   ```
4. Use token classes directly: `AppColors.primary`, `AppSpacing.space4`, etc.
5. Access Material theme values via `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, etc.
6. Apply shadows with `Container(decoration: BoxDecoration(boxShadow: AppShadows.md))`
