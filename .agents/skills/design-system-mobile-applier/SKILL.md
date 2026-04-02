---
name: "design-system-mobile-applier"
description: "Convert design token JSON into native mobile theme files. Supports iOS (SwiftUI, UIKit), Android (Jetpack Compose, XML resources), Flutter (ThemeData), and React Native (theme.ts). Use for requests like generate Swift theme from tokens, create Android theme, build Flutter theme, or apply design tokens to mobile project."
---

# Design System Mobile Applier

Convert design token JSON into native mobile theme files for iOS, Android, Flutter, and React Native.

`$ARGUMENTS` is the path to a token JSON file, a Markdown file containing a JSON code block, or inline JSON pasted in the request.

## Workflow

1. Receive tokens from `$ARGUMENTS` — a JSON file path, a Markdown file with a JSON code block, or inline JSON.
2. Detect the target platform by inspecting the project (see Platform Detection below). If ambiguous, ask the user.
3. Read the appropriate reference file for the target platform.
4. Generate output — run `scripts/generate_swift.py` for iOS, `scripts/generate_kotlin.py` for Android; follow reference templates for Flutter and React Native.
5. Generate font setup guidance — if `typography.font-source` tokens are present, include platform-specific instructions for downloading and registering non-system fonts (see each platform reference for details).
6. Write files to the project and provide integration guidance.

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

1. **JSON file path** — `tokens.json` or any `.json` file containing the token schema.
2. **Markdown with JSON block** — extract the JSON from the fenced code block.
3. **Inline JSON** — pasted directly in the request.

Validate the JSON has the required sections (`meta`, `color`, `typography`, `spacing`, `borderRadius`, `shadow`) before proceeding. See references/token-schema.md for the full schema.

## Conversion Rules

### px to platform units

| Platform | Conversion | Example |
|---|---|---|
| iOS (SwiftUI / UIKit) | px to pt (CGFloat, 1:1) | `16px` becomes `16` |
| Android (Compose) | px to dp (1:1 at standard density) | `16px` becomes `16.dp` |
| Android (XML spacing) | px to dp | `16px` becomes `16dp` |
| Android (XML font sizes) | px to sp | `16px` becomes `16sp` |
| Flutter | px to logical pixels (1:1) | `16px` becomes `16` |
| React Native | px to density-independent pixels (1:1) | `16px` becomes `16` |

### Hex to platform color format

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

- **Letter spacing**: React Native uses pixel values, not `em`. Convert: `em_value * 16 = px_value` (e.g., `-0.025em` becomes `-0.4`).
- **Shadows**: Parse CSS shadow syntax into platform-native structures (SwiftUI ViewModifier, Compose shadow modifier, Flutter BoxShadow, RN shadow props).
- **Font weights**: Map numeric to platform enum (`400` becomes `.regular` / `FontWeight.Normal` / `FontWeight.w400` / `'400'`).

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

### Flutter and React Native

For Flutter and React Native, follow the templates in the corresponding reference files. These require structural decisions that scripts do not handle. Read the reference file and generate the output directly.

## Resources

### scripts/
- `generate_swift.py` — Token to Swift (SwiftUI + UIKit) converter
- `generate_kotlin.py` — Token to Kotlin (Compose) + XML resource converter

### references/
- `token-schema.md` — Design token JSON schema (input format)
- `ios-swiftui.md` — SwiftUI Color/Font/Spacing extensions guide
- `ios-uikit.md` — UIKit UIColor/UIFont constants guide
- `android-compose.md` — Jetpack Compose Theme.kt, Color.kt, Type.kt, Shape.kt guide
- `android-xml.md` — XML resources: colors.xml, dimens.xml, styles.xml, themes.xml guide
- `flutter.md` — Flutter ThemeData generation guide
- `react-native.md` — React Native theme.ts generation guide
