# iOS SwiftUI Theme Generation Guide

Reference for generating SwiftUI design token files from the token JSON schema.

## Output File

`DesignTokens.swift` — a single file containing all token structs and extensions.

## Color Extension (Hex Initializer)

```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

## DSColors

A struct with static `Color` constants for every token in `color.*`:

```swift
struct DSColors {
    static let primary = Color(hex: "#2563EB")
    static let primaryLight = Color(hex: "#60A5FA")
    static let primaryDark = Color(hex: "#1D4ED8")
    static let secondary = Color(hex: "#7C3AED")
    static let accent = Color(hex: "#F59E0B")
    static let background = Color(hex: "#F9FAFB")
    static let surface = Color(hex: "#FFFFFF")
    static let textPrimary = Color(hex: "#111827")
    static let textSecondary = Color(hex: "#6B7280")
    static let textTertiary = Color(hex: "#9CA3AF")
    static let border = Color(hex: "#E5E7EB")
    static let borderLight = Color(hex: "#F3F4F6")
    static let error = Color(hex: "#EF4444")
    static let warning = Color(hex: "#F59E0B")
    static let success = Color(hex: "#10B981")
    static let info = Color(hex: "#3B82F6")
}
```

**Naming**: `token-name` → `camelCase` (e.g., `primary-light` → `primaryLight`, `text-primary` → `textPrimary`).

## DSTypography

Font family constants + convenience methods for creating fonts:

```swift
struct DSTypography {
    static let fontFamilyHeading = "Inter"
    static let fontFamilyBody = "Inter"
    static let fontFamilyMono = "JetBrains Mono"

    static let fontSizeXs: CGFloat = 12
    static let fontSizeSm: CGFloat = 14
    static let fontSizeBase: CGFloat = 16
    static let fontSizeLg: CGFloat = 18
    static let fontSizeXl: CGFloat = 20
    static let fontSize2xl: CGFloat = 24
    static let fontSize3xl: CGFloat = 30
    static let fontSize4xl: CGFloat = 36

    static let fontWeightRegular: Font.Weight = .regular
    static let fontWeightMedium: Font.Weight = .medium
    static let fontWeightSemibold: Font.Weight = .semibold
    static let fontWeightBold: Font.Weight = .bold

    static let lineHeightTight: CGFloat = 1.25
    static let lineHeightNormal: CGFloat = 1.5
    static let lineHeightRelaxed: CGFloat = 1.75

    // Convenience methods
    static func heading(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("JetBrains Mono", size: size).weight(weight)
    }
}
```

**Conversion**:
- `px` values → `CGFloat` numeric (1:1 mapping, drop `px` suffix)
- Font weights: `400` → `.regular`, `500` → `.medium`, `600` → `.semibold`, `700` → `.bold`
- Font families: extract name before comma, strip quotes

## DSSpacing

An enum with static CGFloat constants:

```swift
enum DSSpacing {
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space8: CGFloat = 32
    static let space10: CGFloat = 40
    static let space12: CGFloat = 48
    static let space16: CGFloat = 64
}
```

**Naming**: `spacing.N` → `spaceN` (e.g., `spacing.4` → `space4`).

## DSRadius

An enum with static CGFloat constants:

```swift
enum DSRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let full: CGFloat = 9999
}
```

## DSShadow

A struct with parsed shadow values + a ViewModifier:

```swift
struct DSShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let sm = DSShadow(
        color: Color(.sRGB, red: 0/255, green: 0/255, blue: 0/255, opacity: 0.05),
        radius: 2,
        x: 0,
        y: 1
    )

    static let md = DSShadow(
        color: Color(.sRGB, red: 0/255, green: 0/255, blue: 0/255, opacity: 0.07),
        radius: 6,
        x: 0,
        y: 4
    )

    static let lg = DSShadow(
        color: Color(.sRGB, red: 0/255, green: 0/255, blue: 0/255, opacity: 0.1),
        radius: 15,
        x: 0,
        y: 10
    )
}
```

**Shadow parsing**: Extract x, y, blur, and rgba values from CSS shadow syntax.

### Shadow ViewModifier

```swift
struct DSShadowModifier: ViewModifier {
    let shadow: DSShadow

    func body(content: Content) -> some View {
        content.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

extension View {
    func dsShadow(_ shadow: DSShadow) -> some View {
        modifier(DSShadowModifier(shadow: shadow))
    }
}
```

## Component Pattern Examples

### ButtonStyle

```swift
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DSSpacing.space6)
            .padding(.vertical, DSSpacing.space3)
            .background(configuration.isPressed ? DSColors.primaryDark : DSColors.primary)
            .foregroundColor(.white)
            .font(DSTypography.body(DSTypography.fontSizeSm, weight: .semibold))
            .cornerRadius(DSRadius.md)
    }
}
```

### CardStyle

```swift
struct DSCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DSSpacing.space6)
            .background(DSColors.surface)
            .cornerRadius(DSRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.lg)
                    .stroke(DSColors.border, lineWidth: 1)
            )
            .dsShadow(.sm)
    }
}
```

## Script Usage

```bash
# Generate SwiftUI tokens to a directory
python3 scripts/generate_swift.py tokens.json --swiftui --output Sources/Theme/

# Generate to stdout
python3 scripts/generate_swift.py tokens.json --swiftui
```

## Font Registration

When `typography.font-source` tokens are present in the design token JSON, use them to set up custom fonts:

1. **Download font files** — Use the `font-source` URL (e.g., Google Fonts) to download the `.ttf` or `.otf` files for each font family. Extract the individual weight files (Regular, Medium, SemiBold, Bold).
2. **Add to Xcode project** — Drag the font files into your Xcode project, ensuring "Copy items if needed" is checked and they are added to the correct target.
3. **Register in Info.plist** — Add an `UIAppFonts` (or `Fonts provided by application`) array entry for each font file:
   ```xml
   <key>UIAppFonts</key>
   <array>
       <string>Inter-Regular.ttf</string>
       <string>Inter-Medium.ttf</string>
       <string>Inter-SemiBold.ttf</string>
       <string>Inter-Bold.ttf</string>
   </array>
   ```
4. **System fonts** — If the `font-source` value is `"system"`, no registration is needed. The generated code will use `.system()` fonts automatically.

The generated `DesignTokens.swift` includes a `// MARK: - Font Registration` comment block listing each non-system font and its source URL for reference.

## Integration Guidance

After generating `DesignTokens.swift`:

1. Add the file to your Xcode project / Swift Package
2. Register custom fonts using the font source URLs (see Font Registration above)
3. Use token structs directly: `DSColors.primary`, `DSSpacing.space4`, etc.
4. Apply shadows with the ViewModifier: `.dsShadow(.md)`
5. Create custom `ButtonStyle` / `ViewModifier` types using the token constants for component patterns
