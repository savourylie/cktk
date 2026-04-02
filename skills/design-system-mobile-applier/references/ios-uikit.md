# iOS UIKit Theme Generation Guide

Reference for generating UIKit design token files from the token JSON schema.

## Output File

`Theme.swift` — a single file with a `Theme` enum namespace containing all token constants.

## UIColor Hex Extension

```swift
import UIKit

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
```

## Theme Namespace

All constants live under a `Theme` enum:

```swift
enum Theme {

    enum Colors {
        static let primary = UIColor(hex: "#2563EB")
        static let primaryLight = UIColor(hex: "#60A5FA")
        static let primaryDark = UIColor(hex: "#1D4ED8")
        static let secondary = UIColor(hex: "#7C3AED")
        static let accent = UIColor(hex: "#F59E0B")
        static let background = UIColor(hex: "#F9FAFB")
        static let surface = UIColor(hex: "#FFFFFF")
        static let textPrimary = UIColor(hex: "#111827")
        static let textSecondary = UIColor(hex: "#6B7280")
        static let textTertiary = UIColor(hex: "#9CA3AF")
        static let border = UIColor(hex: "#E5E7EB")
        static let borderLight = UIColor(hex: "#F3F4F6")
        static let error = UIColor(hex: "#EF4444")
        static let warning = UIColor(hex: "#F59E0B")
        static let success = UIColor(hex: "#10B981")
        static let info = UIColor(hex: "#3B82F6")
    }

    enum Fonts {
        static let fontFamilyHeading = "Inter"
        static let fontFamilyBody = "Inter"
        static let fontFamilyMono = "JetBrains Mono"

        static let sizeXs: CGFloat = 12
        static let sizeSm: CGFloat = 14
        static let sizeBase: CGFloat = 16
        static let sizeLg: CGFloat = 18
        static let sizeXl: CGFloat = 20
        static let size2xl: CGFloat = 24
        static let size3xl: CGFloat = 30
        static let size4xl: CGFloat = 36

        static let weightRegular: UIFont.Weight = .regular
        static let weightMedium: UIFont.Weight = .medium
        static let weightSemibold: UIFont.Weight = .semibold
        static let weightBold: UIFont.Weight = .bold

        static let lineHeightTight: CGFloat = 1.25
        static let lineHeightNormal: CGFloat = 1.5
        static let lineHeightRelaxed: CGFloat = 1.75

        // Convenience methods
        static func heading(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            if let font = UIFont(name: "Inter", size: size) {
                return font
            }
            return UIFont.systemFont(ofSize: size, weight: weight)
        }

        static func body(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            if let font = UIFont(name: "Inter", size: size) {
                return font
            }
            return UIFont.systemFont(ofSize: size, weight: weight)
        }

        static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            if let font = UIFont(name: "JetBrains Mono", size: size) {
                return font
            }
            return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    enum Spacing {
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

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let full: CGFloat = 9999
    }
}
```

**Naming**: Same camelCase convention as SwiftUI — `primary-light` → `primaryLight`.

**Conversion**:
- `px` values → `CGFloat` numeric (1:1)
- Font weights: `400` → `.regular`, `500` → `.medium`, `600` → `.semibold`, `700` → `.bold`
- Font families: extract name before comma, strip quotes
- Font convenience methods: try custom font first, fall back to system font

## UIKit Usage Patterns

### Applying Colors

```swift
view.backgroundColor = Theme.Colors.background
label.textColor = Theme.Colors.textPrimary
button.tintColor = Theme.Colors.primary
```

### Applying Fonts

```swift
titleLabel.font = Theme.Fonts.heading(Theme.Fonts.size2xl, weight: .bold)
bodyLabel.font = Theme.Fonts.body(Theme.Fonts.sizeSm)
codeLabel.font = Theme.Fonts.mono(Theme.Fonts.sizeSm)
```

### Applying Spacing & Radius

```swift
// Auto Layout constraints
NSLayoutConstraint.activate([
    contentView.topAnchor.constraint(equalTo: view.topAnchor, constant: Theme.Spacing.space4),
    contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Spacing.space4),
])

// Corner radius
cardView.layer.cornerRadius = Theme.Radius.lg
cardView.layer.borderWidth = 1
cardView.layer.borderColor = Theme.Colors.border.cgColor
```

### Shadow Application

For UIKit shadows, apply using `CALayer` properties:

```swift
cardView.layer.shadowColor = UIColor.black.cgColor
cardView.layer.shadowOpacity = 0.05
cardView.layer.shadowOffset = CGSize(width: 0, height: 1)
cardView.layer.shadowRadius = 2
```

## Script Usage

```bash
# Generate UIKit theme to a directory
python3 scripts/generate_swift.py tokens.json --uikit --output Sources/Theme/

# Generate both SwiftUI and UIKit
python3 scripts/generate_swift.py tokens.json --swiftui --uikit --output Sources/Theme/
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
4. **System fonts** — If the `font-source` value is `"system"`, no registration is needed. The generated convenience methods will fall back to `UIFont.systemFont(ofSize:weight:)` automatically.

The generated `Theme.swift` includes a `// MARK: - Font Registration` comment block listing each non-system font and its source URL for reference.

## Integration Guidance

After generating `Theme.swift`:

1. Add the file to your Xcode project
2. Register custom fonts using the font source URLs (see Font Registration above)
3. Use `Theme.Colors.primary`, `Theme.Fonts.heading(...)`, etc. throughout your views
4. For shadows, apply `CALayer` shadow properties using the token values
5. Consider creating `UIView` subclasses for common component patterns (cards, buttons)
