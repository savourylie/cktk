# Android Jetpack Compose Theme Generation Guide

Reference for generating Material 3 Compose theme files from the token JSON schema.

## Output Files

| File | Purpose |
|---|---|
| `Color.kt` | Named `Color` constants for all color tokens |
| `Type.kt` | `Typography` definition mapping tokens to Material 3 text styles |
| `Shape.kt` | `Shapes` definition from borderRadius tokens |
| `Theme.kt` | `@Composable fun AppTheme()` wiring colorScheme + typography + shapes |
| `Dimens.kt` | Spacing and radius `.dp` constants |

All files use package `com.example.theme` — adjust to match the project.

## Color.kt

```kotlin
package com.example.theme

import androidx.compose.ui.graphics.Color

val Primary = Color(0xFF2563EB)
val PrimaryLight = Color(0xFF60A5FA)
val PrimaryDark = Color(0xFF1D4ED8)
val Secondary = Color(0xFF7C3AED)
val Accent = Color(0xFFF59E0B)
val Background = Color(0xFFF9FAFB)
val Surface = Color(0xFFFFFFFF)
val TextPrimary = Color(0xFF111827)
val TextSecondary = Color(0xFF6B7280)
val TextTertiary = Color(0xFF9CA3AF)
val Border = Color(0xFFE5E7EB)
val BorderLight = Color(0xFFF3F4F6)
val Error = Color(0xFFEF4444)
val Warning = Color(0xFFF59E0B)
val Success = Color(0xFF10B981)
val Info = Color(0xFF3B82F6)
```

**Naming**: `token-name` → `PascalCase` (e.g., `primary-light` → `PrimaryLight`).

**Hex conversion**: `#RRGGBB` → `Color(0xFFRRGGBB)` (prepend `FF` for full alpha).

## Type.kt

```kotlin
package com.example.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val HeadingFontFamily = FontFamily.Default // Replace with actual font resource
val BodyFontFamily = FontFamily.Default    // Replace with actual font resource
val MonoFontFamily = FontFamily.Default    // Replace with actual font resource

val AppTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = HeadingFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 36.sp
    ),
    displayMedium = TextStyle(
        fontFamily = HeadingFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 30.sp
    ),
    displaySmall = TextStyle(
        fontFamily = HeadingFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 24.sp
    ),
    headlineLarge = TextStyle(
        fontFamily = HeadingFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 24.sp
    ),
    headlineMedium = TextStyle(
        fontFamily = HeadingFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 20.sp
    ),
    headlineSmall = TextStyle(
        fontFamily = HeadingFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 18.sp
    ),
    titleLarge = TextStyle(
        fontFamily = HeadingFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 18.sp
    ),
    titleMedium = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 16.sp
    ),
    titleSmall = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp
    ),
    bodyLarge = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp
    ),
    bodySmall = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp
    ),
    labelLarge = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp
    ),
    labelMedium = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp
    ),
    labelSmall = TextStyle(
        fontFamily = BodyFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp
    )
)
```

**Font size mapping** (token → Material 3):

| Material 3 Style | Token Size | Weight |
|---|---|---|
| displayLarge | `font-size.4xl` | Bold |
| displayMedium | `font-size.3xl` | Bold |
| displaySmall | `font-size.2xl` | Bold |
| headlineLarge | `font-size.2xl` | SemiBold |
| headlineMedium | `font-size.xl` | SemiBold |
| headlineSmall | `font-size.lg` | SemiBold |
| titleLarge | `font-size.lg` | Medium |
| titleMedium | `font-size.base` | Medium |
| titleSmall | `font-size.sm` | Medium |
| bodyLarge | `font-size.base` | Normal |
| bodyMedium | `font-size.sm` | Normal |
| bodySmall | `font-size.xs` | Normal |
| labelLarge | `font-size.sm` | Medium |
| labelMedium | `font-size.xs` | Medium |
| labelSmall | 11.sp (fixed) | Medium |

**px → sp**: 1:1 mapping for standard density (drop `px`, add `.sp`).

**Font weight mapping**: `400` → `FontWeight.Normal`, `500` → `FontWeight.Medium`, `600` → `FontWeight.SemiBold`, `700` → `FontWeight.Bold`.

## Shape.kt

```kotlin
package com.example.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

val RadiusSm = RoundedCornerShape(4.dp)
val RadiusMd = RoundedCornerShape(8.dp)
val RadiusLg = RoundedCornerShape(12.dp)
val RadiusXl = RoundedCornerShape(16.dp)
val RadiusFull = RoundedCornerShape(9999.dp)

val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(4.dp),
    medium = RoundedCornerShape(8.dp),
    large = RoundedCornerShape(12.dp),
    extraLarge = RoundedCornerShape(16.dp)
)
```

**px → dp**: 1:1 mapping (drop `px`, add `.dp`).

**Material 3 shape mapping**: `sm` → extraSmall/small, `md` → medium, `lg` → large, `xl` → extraLarge.

## Theme.kt

```kotlin
package com.example.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColorScheme = lightColorScheme(
    primary = Primary,
    primaryContainer = PrimaryLight,
    secondary = Secondary,
    tertiary = Accent,
    background = Background,
    surface = Surface,
    onBackground = TextPrimary,
    onSurface = TextPrimary,
    onSurfaceVariant = TextSecondary,
    outline = Border,
    outlineVariant = BorderLight,
    error = Error
)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = AppTypography,
        shapes = AppShapes,
        content = content
    )
}
```

**Color scheme mapping** (token → Material 3):

| Material 3 Role | Token |
|---|---|
| `primary` | `color.primary` |
| `primaryContainer` | `color.primary-light` |
| `secondary` | `color.secondary` |
| `tertiary` | `color.accent` |
| `background` | `color.background` |
| `surface` | `color.surface` |
| `onBackground` | `color.text-primary` |
| `onSurface` | `color.text-primary` |
| `onSurfaceVariant` | `color.text-secondary` |
| `outline` | `color.border` |
| `outlineVariant` | `color.border-light` |
| `error` | `color.error` |

## Dimens.kt

```kotlin
package com.example.theme

import androidx.compose.ui.unit.dp

object Dimens {
    // Spacing
    val space1 = 4.dp
    val space2 = 8.dp
    val space3 = 12.dp
    val space4 = 16.dp
    val space5 = 20.dp
    val space6 = 24.dp
    val space8 = 32.dp
    val space10 = 40.dp
    val space12 = 48.dp
    val space16 = 64.dp

    // Border Radius
    val radiusSm = 4.dp
    val radiusMd = 8.dp
    val radiusLg = 12.dp
    val radiusXl = 16.dp
    val radiusFull = 9999.dp
}
```

## Script Usage

```bash
# Generate Compose theme files to a directory
python3 scripts/generate_kotlin.py tokens.json --compose --output app/src/main/java/com/example/theme/

# Generate to stdout
python3 scripts/generate_kotlin.py tokens.json --compose
```

## Font Setup

When `typography.font-source` tokens are present in the design token JSON, use them to set up custom fonts:

1. **Download font files** — Use the `font-source` URL (e.g., Google Fonts) to download the `.ttf` files for each font family.
2. **Place in resources** — Add font files to `app/src/main/res/font/` (create the directory if needed). Use lowercase snake_case names (e.g., `inter_regular.ttf`, `inter_bold.ttf`).
3. **Replace FontFamily.Default** — The generated `Type.kt` includes `FontFamily.Default` placeholders with comments showing the source URL. Replace them with actual font resources:
   ```kotlin
   val HeadingFontFamily = FontFamily(
       Font(R.font.inter_regular, FontWeight.Normal),
       Font(R.font.inter_medium, FontWeight.Medium),
       Font(R.font.inter_semibold, FontWeight.SemiBold),
       Font(R.font.inter_bold, FontWeight.Bold)
   )
   ```
4. **System fonts** — If the `font-source` value is `"system"`, no font files are needed. Keep `FontFamily.Default`.

## Integration Guidance

After generating the Compose theme files:

1. Place files in your theme package (e.g., `com.example.theme`)
2. Update `package` declarations if needed
3. Set up custom fonts using the font source URLs (see Font Setup above)
4. Wrap your app content with `AppTheme { ... }`
5. Access theme values via `MaterialTheme.colorScheme`, `MaterialTheme.typography`, `MaterialTheme.shapes`
6. Use `Dimens` object for spacing: `Modifier.padding(Dimens.space4)`
