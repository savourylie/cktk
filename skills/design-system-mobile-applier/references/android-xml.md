# Android XML Resources Theme Generation Guide

Reference for generating Android XML resource files from the token JSON schema.

## Output Files

| File | Purpose |
|---|---|
| `colors.xml` | `<color>` elements for all color tokens |
| `dimens.xml` | `<dimen>` elements for spacing, radius, and font sizes |
| `styles.xml` | Text appearance and component styles |
| `themes.xml` | App theme extending Material 3 |

Place all files in `app/src/main/res/values/`.

## colors.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FF2563EB</color>
    <color name="primary_light">#FF60A5FA</color>
    <color name="primary_dark">#FF1D4ED8</color>
    <color name="secondary">#FF7C3AED</color>
    <color name="accent">#FFF59E0B</color>
    <color name="background">#FFF9FAFB</color>
    <color name="surface">#FFFFFFFF</color>
    <color name="text_primary">#FF111827</color>
    <color name="text_secondary">#FF6B7280</color>
    <color name="text_tertiary">#FF9CA3AF</color>
    <color name="border">#FFE5E7EB</color>
    <color name="border_light">#FFF3F4F6</color>
    <color name="error">#FFEF4444</color>
    <color name="warning">#FFF59E0B</color>
    <color name="success">#FF10B981</color>
    <color name="info">#FF3B82F6</color>
</resources>
```

**Naming**: `token-name` → `snake_case` (e.g., `primary-light` → `primary_light`).

**Hex conversion**: `#RRGGBB` → `#FFRRGGBB` (prepend `FF` for full alpha).

## dimens.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Spacing -->
    <dimen name="space_1">4dp</dimen>
    <dimen name="space_2">8dp</dimen>
    <dimen name="space_3">12dp</dimen>
    <dimen name="space_4">16dp</dimen>
    <dimen name="space_5">20dp</dimen>
    <dimen name="space_6">24dp</dimen>
    <dimen name="space_8">32dp</dimen>
    <dimen name="space_10">40dp</dimen>
    <dimen name="space_12">48dp</dimen>
    <dimen name="space_16">64dp</dimen>

    <!-- Border Radius -->
    <dimen name="radius_sm">4dp</dimen>
    <dimen name="radius_md">8dp</dimen>
    <dimen name="radius_lg">12dp</dimen>
    <dimen name="radius_xl">16dp</dimen>
    <dimen name="radius_full">9999dp</dimen>

    <!-- Font Sizes -->
    <dimen name="font_size_xs">12sp</dimen>
    <dimen name="font_size_sm">14sp</dimen>
    <dimen name="font_size_base">16sp</dimen>
    <dimen name="font_size_lg">18sp</dimen>
    <dimen name="font_size_xl">20sp</dimen>
    <dimen name="font_size_2xl">24sp</dimen>
    <dimen name="font_size_3xl">30sp</dimen>
    <dimen name="font_size_4xl">36sp</dimen>
</resources>
```

**Conversion**:
- Spacing: `px` → `dp` (1:1 at standard density)
- Border radius: `px` → `dp` (1:1)
- Font sizes: `px` → `sp` (1:1, using `sp` for accessibility scaling)

**Naming**: `spacing.N` → `space_N`, `borderRadius.X` → `radius_X`, `font-size.X` → `font_size_X`.

## styles.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="TextAppearance.Heading.Large" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">30sp</item>
        <item name="android:textStyle">bold</item>
    </style>

    <style name="TextAppearance.Heading.Medium" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">24sp</item>
        <item name="android:textStyle">bold</item>
    </style>

    <style name="TextAppearance.Heading.Small" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">20sp</item>
        <item name="android:textStyle">bold</item>
    </style>

    <style name="TextAppearance.Body.Large" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">16sp</item>
        <item name="android:textStyle">normal</item>
    </style>

    <style name="TextAppearance.Body.Medium" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">14sp</item>
        <item name="android:textStyle">normal</item>
    </style>

    <style name="TextAppearance.Body.Small" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">12sp</item>
        <item name="android:textStyle">normal</item>
    </style>

    <style name="TextAppearance.Label.Large" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">14sp</item>
        <item name="android:textStyle">bold</item>
    </style>

    <style name="TextAppearance.Label.Medium" parent="TextAppearance.Material3.BodyMedium">
        <item name="android:textSize">12sp</item>
        <item name="android:textStyle">bold</item>
    </style>

    <style name="Widget.App.Button.Primary" parent="Widget.Material3.Button">
        <item name="backgroundTint">@color/primary</item>
        <item name="cornerRadius">@dimen/radius_md</item>
    </style>

    <style name="Widget.App.Card" parent="Widget.Material3.CardView.Elevated">
        <item name="cardCornerRadius">@dimen/radius_lg</item>
        <item name="contentPadding">@dimen/space_6</item>
    </style>
</resources>
```

**Text style mapping** (token → style):

| Style | Token Size | Text Style |
|---|---|---|
| TextAppearance.Heading.Large | `font-size.3xl` | bold |
| TextAppearance.Heading.Medium | `font-size.2xl` | bold |
| TextAppearance.Heading.Small | `font-size.xl` | bold |
| TextAppearance.Body.Large | `font-size.base` | normal |
| TextAppearance.Body.Medium | `font-size.sm` | normal |
| TextAppearance.Body.Small | `font-size.xs` | normal |
| TextAppearance.Label.Large | `font-size.sm` | bold |
| TextAppearance.Label.Medium | `font-size.xs` | bold |

## themes.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.App" parent="Theme.Material3.Light.NoActionBar">
        <!-- Primary -->
        <item name="colorPrimary">@color/primary</item>
        <item name="colorOnPrimary">#FFFFFF</item>
        <item name="colorPrimaryContainer">@color/primary_light</item>

        <!-- Secondary -->
        <item name="colorSecondary">@color/secondary</item>

        <!-- Tertiary -->
        <item name="colorTertiary">@color/accent</item>

        <!-- Background & Surface -->
        <item name="android:colorBackground">@color/background</item>
        <item name="colorSurface">@color/surface</item>
        <item name="colorOnBackground">@color/text_primary</item>
        <item name="colorOnSurface">@color/text_primary</item>
        <item name="colorOnSurfaceVariant">@color/text_secondary</item>

        <!-- Outline -->
        <item name="colorOutline">@color/border</item>
        <item name="colorOutlineVariant">@color/border_light</item>

        <!-- Error -->
        <item name="colorError">@color/error</item>
    </style>
</resources>
```

**Material 3 theme mapping** (token → theme attribute):

| Theme Attribute | Token |
|---|---|
| `colorPrimary` | `color.primary` |
| `colorOnPrimary` | `#FFFFFF` (hardcoded) |
| `colorPrimaryContainer` | `color.primary-light` |
| `colorSecondary` | `color.secondary` |
| `colorTertiary` | `color.accent` |
| `android:colorBackground` | `color.background` |
| `colorSurface` | `color.surface` |
| `colorOnBackground` | `color.text-primary` |
| `colorOnSurface` | `color.text-primary` |
| `colorOnSurfaceVariant` | `color.text-secondary` |
| `colorOutline` | `color.border` |
| `colorOutlineVariant` | `color.border-light` |
| `colorError` | `color.error` |

## Script Usage

```bash
# Generate XML resources to res/values/
python3 scripts/generate_kotlin.py tokens.json --xml --output app/src/main/res/values/

# Generate to stdout
python3 scripts/generate_kotlin.py tokens.json --xml
```

## Font Setup

When `typography.font-source` tokens are present in the design token JSON, use them to set up custom fonts:

1. **Download font files** — Use the `font-source` URL (e.g., Google Fonts) to download the `.ttf` files for each font family.
2. **Place in resources** — Add font files to `app/src/main/res/font/` (create the directory if needed). Use lowercase snake_case names (e.g., `inter_regular.ttf`, `inter_bold.ttf`).
3. **Reference in styles** — Add `android:fontFamily` to text appearance styles:
   ```xml
   <style name="TextAppearance.Heading.Large" parent="TextAppearance.Material3.BodyMedium">
       <item name="android:fontFamily">@font/inter_bold</item>
       <item name="android:textSize">30sp</item>
       <item name="android:textStyle">bold</item>
   </style>
   ```
4. **System fonts** — If the `font-source` value is `"system"`, no font files are needed. Omit the `android:fontFamily` attribute to use the system default.

The generated `styles.xml` includes XML comments with the font source URL for each font family.

## Integration Guidance

After generating XML resource files:

1. Place all files in `app/src/main/res/values/`
2. Set the theme in `AndroidManifest.xml`:
   ```xml
   <application android:theme="@style/Theme.App" ...>
   ```
3. Reference colors: `@color/primary`, `R.color.primary`
4. Reference dimensions: `@dimen/space_4`, `R.dimen.space_4`
5. Apply text styles: `android:textAppearance="@style/TextAppearance.Heading.Large"`
6. Apply button style: `style="@style/Widget.App.Button.Primary"`
7. Set up custom fonts using the font source URLs (see Font Setup above)
