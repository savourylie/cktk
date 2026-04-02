#!/usr/bin/env python3
"""Generate Swift theme files (SwiftUI or UIKit) from a design token JSON file.

Usage:
    python3 generate_swift.py <token-json> [--swiftui|--uikit] [--output <dir>]

Exit codes:
    0 - Success
    1 - Validation error (missing required sections)
    2 - File/parse error
"""

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path


REQUIRED_SECTIONS = ["meta", "color", "typography", "spacing", "borderRadius", "shadow"]

PX_RE = re.compile(r"^(-?\d+(?:\.\d+)?)px$")


def px_to_cgfloat(value: str) -> str:
    """Convert px value to CGFloat numeric string. Non-px values pass through."""
    m = PX_RE.match(value)
    if not m:
        return value
    px = float(m.group(1))
    if px == int(px):
        return str(int(px))
    return str(px)


def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    """Convert #RRGGBB to (r, g, b) ints."""
    h = hex_str.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def validate_required_sections(data: dict) -> list[str]:
    """Check for required sections. Returns list of errors."""
    errors = []
    for section in REQUIRED_SECTIONS:
        if section not in data:
            errors.append(f"Missing required section: '{section}'")
    meta = data.get("meta", {})
    for field in ["name", "source", "version", "generated"]:
        if field not in meta:
            errors.append(f"Missing required meta field: '{field}'")
    return errors


def generate_header_comment(meta: dict, target: str) -> str:
    """Generate a Swift file header comment."""
    name = meta.get("name", "Design System")
    source = meta.get("source", "Unknown")
    version = meta.get("version", "1.0.0")
    generated = date.today().isoformat()
    return (
        f"//\n"
        f"// {name}\n"
        f"// Source: {source}\n"
        f"// Version: {version}\n"
        f"// Generated: {generated}\n"
        f"// Format: {target}\n"
        f"//\n"
    )


def token_name_to_swift(name: str) -> str:
    """Convert token name like 'primary-light' to camelCase 'primaryLight'."""
    parts = name.split("-")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def collect_colors(data: dict) -> list[tuple[str, str]]:
    """Collect (swiftName, hexValue) pairs from color section."""
    colors = []
    for key, val in data.get("color", {}).items():
        if isinstance(val, dict) and "value" in val:
            colors.append((token_name_to_swift(key), val["value"]))
    return colors


def collect_font_families(data: dict) -> list[tuple[str, str]]:
    """Collect (swiftName, familyName) pairs from typography section."""
    families = []
    typo = data.get("typography", {})
    for key in ["font-family-heading", "font-family-body", "font-family-mono"]:
        val = typo.get(key)
        if val and isinstance(val, dict) and "value" in val:
            # Extract just the font name (strip quotes and fallback)
            raw = val["value"]
            font_name = raw.split(",")[0].strip().strip("'\"")
            short = key.replace("font-family-", "")
            families.append((short, font_name))
    return families


def collect_font_sizes(data: dict) -> list[tuple[str, str]]:
    """Collect (swiftName, cgfloatValue) pairs from font-size section."""
    sizes = []
    fs = data.get("typography", {}).get("font-size", {})
    for key, val in fs.items():
        if isinstance(val, dict) and "value" in val:
            sizes.append((token_name_to_swift(key), px_to_cgfloat(val["value"])))
    return sizes


def collect_font_weights(data: dict) -> list[tuple[str, str]]:
    """Collect (swiftName, numericWeight) pairs."""
    weights = []
    fw = data.get("typography", {}).get("font-weight", {})
    for key, val in fw.items():
        if isinstance(val, dict) and "value" in val:
            weights.append((token_name_to_swift(key), val["value"]))
    return weights


def collect_line_heights(data: dict) -> list[tuple[str, str]]:
    """Collect (swiftName, value) pairs."""
    lhs = []
    lh = data.get("typography", {}).get("line-height", {})
    for key, val in lh.items():
        if isinstance(val, dict) and "value" in val:
            lhs.append((token_name_to_swift(key), val["value"]))
    return lhs


def collect_spacing(data: dict) -> list[tuple[str, str]]:
    """Collect (swiftName, cgfloatValue) pairs from spacing section."""
    spacings = []
    for key, val in data.get("spacing", {}).items():
        if isinstance(val, dict) and "value" in val:
            spacings.append((f"space{key}", px_to_cgfloat(val["value"])))
    return spacings


def collect_radii(data: dict) -> list[tuple[str, str]]:
    """Collect (swiftName, cgfloatValue) pairs from borderRadius section."""
    radii = []
    for key, val in data.get("borderRadius", {}).items():
        if isinstance(val, dict) and "value" in val:
            radii.append((token_name_to_swift(key), px_to_cgfloat(val["value"])))
    return radii


def collect_font_sources(data: dict) -> list[tuple[str, str]]:
    """Collect (shortName, sourceURL) pairs from typography.font-source section."""
    sources = []
    fs = data.get("typography", {}).get("font-source", {})
    for key in ["heading", "body", "mono"]:
        val = fs.get(key)
        if val and isinstance(val, dict) and "value" in val:
            sources.append((key, val["value"]))
    return sources


def collect_shadows(data: dict) -> list[tuple[str, dict]]:
    """Collect (swiftName, parsed_shadow) pairs from shadow section."""
    shadows = []
    shadow_re = re.compile(
        r"(-?\d+(?:\.\d+)?)(?:px)?\s+"   # x offset
        r"(-?\d+(?:\.\d+)?)(?:px)?\s+"   # y offset
        r"(-?\d+(?:\.\d+)?)(?:px)?"      # blur
        r"(?:\s+(-?\d+(?:\.\d+)?)(?:px)?)?"  # optional spread
        r"\s+rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)"
    )
    for key, val in data.get("shadow", {}).items():
        if isinstance(val, dict) and "value" in val:
            m = shadow_re.search(val["value"])
            if m:
                shadows.append((token_name_to_swift(key), {
                    "x": m.group(1),
                    "y": m.group(2),
                    "blur": m.group(3),
                    "r": m.group(5),
                    "g": m.group(6),
                    "b": m.group(7),
                    "a": m.group(8),
                }))
    return shadows


# --- SwiftUI Generation ---

def generate_swiftui(data: dict) -> str:
    """Generate SwiftUI DesignTokens.swift."""
    meta = data.get("meta", {})
    lines = [generate_header_comment(meta, "SwiftUI")]
    lines.append("import SwiftUI\n")

    # Color hex extension
    lines.append("// MARK: - Color Hex Extension\n")
    lines.append("extension Color {")
    lines.append("    init(hex: String) {")
    lines.append("        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)")
    lines.append("        var int: UInt64 = 0")
    lines.append("        Scanner(string: hex).scanHexInt64(&int)")
    lines.append("        let r = Double((int >> 16) & 0xFF) / 255.0")
    lines.append("        let g = Double((int >> 8) & 0xFF) / 255.0")
    lines.append("        let b = Double(int & 0xFF) / 255.0")
    lines.append("        self.init(red: r, green: g, blue: b)")
    lines.append("    }")
    lines.append("}\n")

    # Colors
    colors = collect_colors(data)
    lines.append("// MARK: - Colors\n")
    lines.append("struct DSColors {")
    for name, hex_val in colors:
        lines.append(f'    static let {name} = Color(hex: "{hex_val}")')
    lines.append("}\n")

    # Typography
    families = collect_font_families(data)
    sizes = collect_font_sizes(data)
    weights = collect_font_weights(data)
    line_heights = collect_line_heights(data)

    lines.append("// MARK: - Typography\n")
    lines.append("struct DSTypography {")
    for short, font_name in families:
        lines.append(f'    static let fontFamily{short.capitalize()} = "{font_name}"')
    lines.append("")
    # Font size constants
    for name, val in sizes:
        lines.append(f"    static let fontSize{name.capitalize()}: CGFloat = {val}")
    lines.append("")
    # Font weight mapping
    weight_map = {
        "400": ".regular",
        "500": ".medium",
        "600": ".semibold",
        "700": ".bold",
    }
    for name, val in weights:
        swift_weight = weight_map.get(val, ".regular")
        lines.append(f"    static let fontWeight{name.capitalize()}: Font.Weight = {swift_weight}")
    lines.append("")
    # Line height constants
    for name, val in line_heights:
        lines.append(f"    static let lineHeight{name.capitalize()}: CGFloat = {val}")
    lines.append("")
    # Convenience font methods
    for short, font_name in families:
        lines.append(f"    static func {short}(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {{")
        lines.append(f'        .custom("{font_name}", size: size).weight(weight)')
        lines.append("    }")
    lines.append("}\n")

    # Font Registration
    font_sources = collect_font_sources(data)
    non_system = [(name, url) for name, url in font_sources if url != "system"]
    if non_system:
        lines.append("// MARK: - Font Registration\n")
        lines.append("// To use custom fonts, download the font files and add them to your Xcode project.")
        lines.append("// Register each font file in Info.plist under the \"UIAppFonts\" key.")
        lines.append("//")
        for name, url in non_system:
            family_key = f"font-family-{name}"
            family_name = next((fn for s, fn in families if s == name), name)
            lines.append(f"// Font: {family_name}")
            lines.append(f"//   Source: {url}")
            lines.append(f"//   Add to Info.plist UIAppFonts: \"{family_name}-Regular.ttf\", \"{family_name}-Bold.ttf\", etc.")
        system_fonts = [(name, url) for name, url in font_sources if url == "system"]
        if system_fonts:
            lines.append("//")
            for name, _ in system_fonts:
                lines.append(f"// Font: {name} — system font, no registration needed")
        lines.append("")

    # Spacing
    spacings = collect_spacing(data)
    lines.append("// MARK: - Spacing\n")
    lines.append("enum DSSpacing {")
    for name, val in spacings:
        lines.append(f"    static let {name}: CGFloat = {val}")
    lines.append("}\n")

    # Border Radius
    radii = collect_radii(data)
    lines.append("// MARK: - Border Radius\n")
    lines.append("enum DSRadius {")
    for name, val in radii:
        lines.append(f"    static let {name}: CGFloat = {val}")
    lines.append("}\n")

    # Shadows
    shadows = collect_shadows(data)
    lines.append("// MARK: - Shadows\n")
    lines.append("struct DSShadow {")
    lines.append("    let color: Color")
    lines.append("    let radius: CGFloat")
    lines.append("    let x: CGFloat")
    lines.append("    let y: CGFloat")
    lines.append("")
    for name, s in shadows:
        r, g, b = int(s["r"]), int(s["g"]), int(s["b"])
        lines.append(f"    static let {name} = DSShadow(")
        lines.append(f"        color: Color(.sRGB, red: {r}/255, green: {g}/255, blue: {b}/255, opacity: {s['a']}),")
        lines.append(f"        radius: {s['blur']},")
        lines.append(f"        x: {s['x']},")
        lines.append(f"        y: {s['y']}")
        lines.append("    )")
    lines.append("}\n")

    # Shadow ViewModifier
    lines.append("// MARK: - Shadow ViewModifier\n")
    lines.append("struct DSShadowModifier: ViewModifier {")
    lines.append("    let shadow: DSShadow\n")
    lines.append("    func body(content: Content) -> some View {")
    lines.append("        content.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)")
    lines.append("    }")
    lines.append("}\n")
    lines.append("extension View {")
    lines.append("    func dsShadow(_ shadow: DSShadow) -> some View {")
    lines.append("        modifier(DSShadowModifier(shadow: shadow))")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# --- UIKit Generation ---

def generate_uikit(data: dict) -> str:
    """Generate UIKit Theme.swift."""
    meta = data.get("meta", {})
    lines = [generate_header_comment(meta, "UIKit")]
    lines.append("import UIKit\n")

    # UIColor hex extension
    lines.append("// MARK: - UIColor Hex Extension\n")
    lines.append("extension UIColor {")
    lines.append("    convenience init(hex: String) {")
    lines.append("        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)")
    lines.append("        var int: UInt64 = 0")
    lines.append("        Scanner(string: hex).scanHexInt64(&int)")
    lines.append("        let r = CGFloat((int >> 16) & 0xFF) / 255.0")
    lines.append("        let g = CGFloat((int >> 8) & 0xFF) / 255.0")
    lines.append("        let b = CGFloat(int & 0xFF) / 255.0")
    lines.append("        self.init(red: r, green: g, blue: b, alpha: 1.0)")
    lines.append("    }")
    lines.append("}\n")

    # Theme namespace
    lines.append("// MARK: - Theme\n")
    lines.append("enum Theme {\n")

    # Colors
    colors = collect_colors(data)
    lines.append("    // MARK: Colors\n")
    lines.append("    enum Colors {")
    for name, hex_val in colors:
        lines.append(f'        static let {name} = UIColor(hex: "{hex_val}")')
    lines.append("    }\n")

    # Fonts
    families = collect_font_families(data)
    sizes = collect_font_sizes(data)
    weights = collect_font_weights(data)
    line_heights = collect_line_heights(data)

    weight_map = {
        "400": ".regular",
        "500": ".medium",
        "600": ".semibold",
        "700": ".bold",
    }

    lines.append("    // MARK: Fonts\n")
    lines.append("    enum Fonts {")
    for short, font_name in families:
        lines.append(f'        static let fontFamily{short.capitalize()} = "{font_name}"')
    lines.append("")
    for name, val in sizes:
        lines.append(f"        static let size{name.capitalize()}: CGFloat = {val}")
    lines.append("")
    for name, val in weights:
        swift_weight = weight_map.get(val, ".regular")
        lines.append(f"        static let weight{name.capitalize()}: UIFont.Weight = {swift_weight}")
    lines.append("")
    for name, val in line_heights:
        lines.append(f"        static let lineHeight{name.capitalize()}: CGFloat = {val}")
    lines.append("")
    # Convenience methods
    for short, font_name in families:
        lines.append(f"        static func {short}(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {{")
        lines.append(f'            if let font = UIFont(name: "{font_name}", size: size) {{')
        lines.append("                return font")
        lines.append("            }")
        lines.append("            return UIFont.systemFont(ofSize: size, weight: weight)")
        lines.append("        }")
    lines.append("    }\n")

    # Font Registration
    font_sources = collect_font_sources(data)
    non_system = [(name, url) for name, url in font_sources if url != "system"]
    if non_system:
        lines.append("    // MARK: Font Registration\n")
        lines.append("    // To use custom fonts, download the font files and add them to your Xcode project.")
        lines.append("    // Register each font file in Info.plist under the \"UIAppFonts\" key.")
        lines.append("    //")
        for name, url in non_system:
            family_name = next((fn for s, fn in families if s == name), name)
            lines.append(f"    // Font: {family_name}")
            lines.append(f"    //   Source: {url}")
            lines.append(f"    //   Add to Info.plist UIAppFonts: \"{family_name}-Regular.ttf\", \"{family_name}-Bold.ttf\", etc.")
        system_fonts = [(name, url) for name, url in font_sources if url == "system"]
        if system_fonts:
            lines.append("    //")
            for name, _ in system_fonts:
                lines.append(f"    // Font: {name} — system font, no registration needed")
        lines.append("")

    # Spacing
    spacings = collect_spacing(data)
    lines.append("    // MARK: Spacing\n")
    lines.append("    enum Spacing {")
    for name, val in spacings:
        lines.append(f"        static let {name}: CGFloat = {val}")
    lines.append("    }\n")

    # Radius
    radii = collect_radii(data)
    lines.append("    // MARK: Radius\n")
    lines.append("    enum Radius {")
    for name, val in radii:
        lines.append(f"        static let {name}: CGFloat = {val}")
    lines.append("    }")

    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate Swift theme files from design tokens")
    parser.add_argument("token_json", help="Path to token JSON file")
    parser.add_argument("--swiftui", action="store_true", default=False, help="Generate SwiftUI output (default)")
    parser.add_argument("--uikit", action="store_true", default=False, help="Generate UIKit output")
    parser.add_argument("--output", "-o", help="Output directory (default: stdout)")
    args = parser.parse_args()

    # Default to swiftui if neither specified
    if not args.swiftui and not args.uikit:
        args.swiftui = True

    path = Path(args.token_json)
    if not path.exists():
        print(f"Error: File not found: {path}", file=sys.stderr)
        sys.exit(2)

    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON: {e}", file=sys.stderr)
        sys.exit(2)

    if not isinstance(data, dict):
        print("Error: Token file must contain a JSON object", file=sys.stderr)
        sys.exit(2)

    errors = validate_required_sections(data)
    if errors:
        print(f"Validation failed with {len(errors)} error(s):", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    outputs = []

    if args.swiftui:
        outputs.append(("DesignTokens.swift", generate_swiftui(data)))

    if args.uikit:
        outputs.append(("Theme.swift", generate_uikit(data)))

    if args.output:
        out_dir = Path(args.output)
        out_dir.mkdir(parents=True, exist_ok=True)
        for filename, content in outputs:
            out_path = out_dir / filename
            out_path.write_text(content)
            print(f"Generated {filename} written to {out_path}")
    else:
        for filename, content in outputs:
            if len(outputs) > 1:
                print(f"// === {filename} ===\n")
            print(content)


if __name__ == "__main__":
    main()
