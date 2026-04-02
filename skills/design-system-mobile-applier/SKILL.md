---
name: design-system-mobile-applier
description: >
  Converts design token JSON into native mobile theme files. Supports iOS (SwiftUI extensions, UIKit
  constants), Android (Jetpack Compose MaterialTheme, XML resources), Flutter (ThemeData), and React
  Native (theme.ts). Use when a user has a design token JSON artifact (from design-system-extractor
  or hand-authored) and wants to generate mobile-native theme code. Do NOT use for web themes (use
  design-system-web-applier), extracting tokens from screenshots (use design-system-extractor), or
  creating new design systems from scratch.
---

# Design System Mobile Applier

Convert design token JSON into native mobile theme files for iOS, Android, Flutter, and React Native.

## Workflow

1. **Receive tokens** — accept a JSON file path, a Markdown file with a JSON code block, or inline JSON pasted in chat
2. **Detect or ask for platform** — inspect the project for indicators (see Platform Detection below); if ambiguous, ask the user
3. **Read the appropriate reference** — load the reference file for the target platform
4. **Generate output** — run `scripts/generate_swift.py` for iOS, `scripts/generate_kotlin.py` for Android; follow reference templates for Flutter/React Native
5. **Generate font setup guidance** — if `typography.font-source` tokens are present, include platform-specific instructions for downloading and registering non-system fonts (see each platform reference for details)
6. **Write files + provide integration guidance** — place output files in the project and explain how to wire them in

## Platform Detection

Inspect the project to determine the target platform before generating output:

| Indicator | Platform | Reference | Output |
|---|---|---|---|
| `.swift` files or `Package.swift` | iOS (SwiftUI) | references/ios-swiftui.md | `DesignTokens.swift` |
| `UIKit` imports in Swift files | iOS (UIKit) | references/ios-uikit.md | `Theme.swift` |
| `build.gradle.kts` + Compose deps | Android (Compose) | references/android-compose.md | `Color.kt`, `Type.kt`, `Shape.kt`, `Theme.kt`, `Dimens.kt` |
| `build.gradle` + no Compose | Android (XML) | references/android-xml.md | `colors.xml`, `dimens.xml`, `styles.xml`, `themes.xml` |
| `pubspec.yaml` with `flutter` | Flutter | references/flutter.md | `app_theme.dart` |
| `react-native` in package.json | React Native | references/react-native.md | `theme.ts` |

If multiple platforms are detected (e.g., shared token set for iOS + Android), generate for both.

## Token Input Formats

Accept tokens in any of these forms:

1. **JSON file path** — `tokens.json` or any `.json` file containing the token schema
2. **Markdown with JSON block** — extract the JSON from the fenced code block
3. **Inline JSON** — pasted directly in chat

Validate the JSON has the required sections (`meta`, `color`, `typography`, `spacing`, `borderRadius`, `shadow`) before proceeding. See references/token-schema.md for the full schema.

## Conversion Rules

### px → platform units

| Platform | Conversion | Example |
|---|---|---|
| iOS (SwiftUI/UIKit) | px → pt (CGFloat, 1:1) | `16px` → `16` |
| Android (Compose) | px → dp (1:1 at standard density) | `16px` → `16.dp` |
| Android (XML spacing) | px → dp | `16px` → `16dp` |
| Android (XML font sizes) | px → sp | `16px` → `16sp` |
| Flutter | px → logical pixels (1:1) | `16px` → `16` |
| React Native | px → density-independent pixels (1:1) | `16px` → `16` |

### Hex → platform color format

| Platform | Conversion | Example |
|---|---|---|
| SwiftUI | `Color(hex: "#RRGGBB")` | `Color(hex: "#2563EB")` |
| UIKit | `UIColor(hex: "#RRGGBB")` | `UIColor(hex: "#2563EB")` |
| Compose | `Color(0xFFRRGGBB)` | `Color(0xFF2563EB)` |
| Android XML | `#FFRRGGBB` | `<color name="primary">#FF2563EB</color>` |
| Flutter | `Color(0xFFRRGGBB)` | `Color(0xFF2563EB)` |
| React Native | `'#RRGGBB'` (string) | `'#2563EB'` |

### Naming conventions

| Platform | Convention | Example |
|---|---|---|
| Swift | camelCase | `primaryLight`, `textPrimary` |
| Kotlin (Compose) | PascalCase | `PrimaryLight`, `TextPrimary` |
| Android XML | snake_case | `primary_light`, `text_primary` |
| Dart (Flutter) | camelCase | `primaryLight`, `textPrimary` |
| TypeScript (RN) | camelCase | `primaryLight`, `textPrimary` |

### Passthrough values

These token types are not unit-converted:
- Colors (hex strings)
- Font families (name strings)
- Font sources (URL strings or `"system"`)
- Font weights (numeric)
- Line heights (unitless ratios)

### Special conversions

- **Letter spacing**: React Native uses pixel values, not `em`. Convert: `em_value × 16 = px_value` (e.g., `-0.025em` → `-0.4`)
- **Shadows**: Parse CSS shadow syntax into platform-native structures (SwiftUI ViewModifier, Compose shadow modifier, Flutter BoxShadow, RN shadow props)
- **Font weights**: Map numeric → platform enum (`400` → `.regular`/`FontWeight.Normal`/`FontWeight.w400`/`'400'`)

## Using the Scripts

### Swift (iOS)

```bash
# SwiftUI (default)
python3 scripts/generate_swift.py tokens.json --output Sources/Theme/

# UIKit
python3 scripts/generate_swift.py tokens.json --uikit --output Sources/Theme/

# Both
python3 scripts/generate_swift.py tokens.json --swiftui --uikit --output Sources/Theme/
```

### Kotlin / XML (Android)

```bash
# Jetpack Compose (default)
python3 scripts/generate_kotlin.py tokens.json --output app/src/main/java/com/example/theme/

# Android XML resources
python3 scripts/generate_kotlin.py tokens.json --xml --output app/src/main/res/values/
```

### Flutter & React Native

For Flutter and React Native, follow the templates in the corresponding reference files — these require structural decisions that scripts don't handle. Read the reference file and generate the output directly.

## Resources

### scripts/
- `generate_swift.py` — Token → Swift (SwiftUI + UIKit) converter
- `generate_kotlin.py` — Token → Kotlin (Compose) + XML resource converter

### references/
- `token-schema.md` — Design token JSON schema (input format)
- `ios-swiftui.md` — SwiftUI Color/Font/Spacing extensions guide
- `ios-uikit.md` — UIKit UIColor/UIFont constants guide
- `android-compose.md` — Jetpack Compose Theme.kt, Color.kt, Type.kt, Shape.kt guide
- `android-xml.md` — XML resources: colors.xml, dimens.xml, styles.xml, themes.xml guide
- `flutter.md` — Flutter ThemeData generation guide
- `react-native.md` — React Native theme.ts generation guide
