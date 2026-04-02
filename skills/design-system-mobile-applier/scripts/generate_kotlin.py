#!/usr/bin/env python3
"""Generate Kotlin (Jetpack Compose) or Android XML resource files from a design token JSON file.

Usage:
    python3 generate_kotlin.py <token-json> [--compose|--xml] [--output <dir>]

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


def px_to_dp(value: str) -> str:
    """Convert px value to numeric dp string. Non-px values pass through."""
    m = PX_RE.match(value)
    if not m:
        return value
    px = float(m.group(1))
    if px == int(px):
        return str(int(px))
    return str(px)


def hex_to_argb(hex_str: str) -> str:
    """Convert #RRGGBB to 0xFFRRGGBB format for Compose."""
    h = hex_str.lstrip("#").upper()
    return f"0xFF{h}"


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
    """Generate a Kotlin/XML file header comment."""
    name = meta.get("name", "Design System")
    source = meta.get("source", "Unknown")
    version = meta.get("version", "1.0.0")
    generated = date.today().isoformat()
    return (
        f"/**\n"
        f" * {name}\n"
        f" * Source: {source}\n"
        f" * Version: {version}\n"
        f" * Generated: {generated}\n"
        f" * Format: {target}\n"
        f" */\n"
    )


def generate_xml_header(meta: dict, target: str) -> str:
    """Generate an XML file header comment."""
    name = meta.get("name", "Design System")
    source = meta.get("source", "Unknown")
    version = meta.get("version", "1.0.0")
    generated = date.today().isoformat()
    return (
        f"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        f"<!--\n"
        f"  {name}\n"
        f"  Source: {source}\n"
        f"  Version: {version}\n"
        f"  Generated: {generated}\n"
        f"  Format: {target}\n"
        f"-->\n"
    )


def token_name_to_kotlin(name: str) -> str:
    """Convert token name like 'primary-light' to PascalCase 'PrimaryLight'."""
    parts = name.split("-")
    return "".join(p.capitalize() for p in parts)


def token_name_to_xml(name: str) -> str:
    """Convert token name like 'primary-light' to snake_case 'primary_light'."""
    return name.replace("-", "_")


def collect_colors(data: dict) -> list[tuple[str, str]]:
    """Collect (tokenName, hexValue) pairs from color section."""
    colors = []
    for key, val in data.get("color", {}).items():
        if isinstance(val, dict) and "value" in val:
            colors.append((key, val["value"]))
    return colors


def collect_font_families(data: dict) -> list[tuple[str, str]]:
    """Collect (shortName, familyName) pairs from typography section."""
    families = []
    typo = data.get("typography", {})
    for key in ["font-family-heading", "font-family-body", "font-family-mono"]:
        val = typo.get(key)
        if val and isinstance(val, dict) and "value" in val:
            raw = val["value"]
            font_name = raw.split(",")[0].strip().strip("'\"")
            short = key.replace("font-family-", "")
            families.append((short, font_name))
    return families


def collect_font_sizes(data: dict) -> list[tuple[str, str]]:
    """Collect (name, pxValue) pairs from font-size section."""
    sizes = []
    fs = data.get("typography", {}).get("font-size", {})
    for key, val in fs.items():
        if isinstance(val, dict) and "value" in val:
            sizes.append((key, px_to_dp(val["value"])))
    return sizes


def collect_font_weights(data: dict) -> list[tuple[str, str]]:
    """Collect (name, numericWeight) pairs."""
    weights = []
    fw = data.get("typography", {}).get("font-weight", {})
    for key, val in fw.items():
        if isinstance(val, dict) and "value" in val:
            weights.append((key, val["value"]))
    return weights


def collect_line_heights(data: dict) -> list[tuple[str, str]]:
    """Collect (name, value) pairs."""
    lhs = []
    lh = data.get("typography", {}).get("line-height", {})
    for key, val in lh.items():
        if isinstance(val, dict) and "value" in val:
            lhs.append((key, val["value"]))
    return lhs


def collect_letter_spacings(data: dict) -> list[tuple[str, str]]:
    """Collect (name, value) pairs."""
    spacings = []
    ls = data.get("typography", {}).get("letter-spacing", {})
    for key, val in ls.items():
        if isinstance(val, dict) and "value" in val:
            spacings.append((key, val["value"]))
    return spacings


def collect_spacing(data: dict) -> list[tuple[str, str]]:
    """Collect (name, dpValue) pairs from spacing section."""
    spacings = []
    for key, val in data.get("spacing", {}).items():
        if isinstance(val, dict) and "value" in val:
            spacings.append((key, px_to_dp(val["value"])))
    return spacings


def collect_radii(data: dict) -> list[tuple[str, str]]:
    """Collect (name, dpValue) pairs from borderRadius section."""
    radii = []
    for key, val in data.get("borderRadius", {}).items():
        if isinstance(val, dict) and "value" in val:
            radii.append((key, px_to_dp(val["value"])))
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
    """Collect (name, parsed_shadow) pairs from shadow section."""
    shadows = []
    shadow_re = re.compile(
        r"(-?\d+(?:\.\d+)?)(?:px)?\s+"
        r"(-?\d+(?:\.\d+)?)(?:px)?\s+"
        r"(-?\d+(?:\.\d+)?)(?:px)?"
        r"(?:\s+(-?\d+(?:\.\d+)?)(?:px)?)?"
        r"\s+rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)"
    )
    for key, val in data.get("shadow", {}).items():
        if isinstance(val, dict) and "value" in val:
            m = shadow_re.search(val["value"])
            if m:
                shadows.append((key, {
                    "x": m.group(1),
                    "y": m.group(2),
                    "blur": m.group(3),
                    "r": m.group(5),
                    "g": m.group(6),
                    "b": m.group(7),
                    "a": m.group(8),
                }))
    return shadows


# --- Jetpack Compose Generation ---

def generate_compose_color(data: dict) -> str:
    """Generate Color.kt for Jetpack Compose."""
    meta = data.get("meta", {})
    lines = [generate_header_comment(meta, "Jetpack Compose - Colors")]
    lines.append("package com.example.theme\n")
    lines.append("import androidx.compose.ui.graphics.Color\n")

    colors = collect_colors(data)
    for name, hex_val in colors:
        kotlin_name = token_name_to_kotlin(name)
        argb = hex_to_argb(hex_val)
        lines.append(f"val {kotlin_name} = Color({argb})")

    lines.append("")
    return "\n".join(lines)


def generate_compose_type(data: dict) -> str:
    """Generate Type.kt for Jetpack Compose."""
    meta = data.get("meta", {})
    lines = [generate_header_comment(meta, "Jetpack Compose - Typography")]
    lines.append("package com.example.theme\n")
    lines.append("import androidx.compose.material3.Typography")
    lines.append("import androidx.compose.ui.text.TextStyle")
    lines.append("import androidx.compose.ui.text.font.Font")
    lines.append("import androidx.compose.ui.text.font.FontFamily")
    lines.append("import androidx.compose.ui.text.font.FontWeight")
    lines.append("import androidx.compose.ui.unit.sp\n")

    families = collect_font_families(data)
    sizes = collect_font_sizes(data)
    weights = collect_font_weights(data)
    line_heights = collect_line_heights(data)
    font_sources = collect_font_sources(data)

    # Build source lookup
    source_map = {name: url for name, url in font_sources}

    # Font families
    for short, font_name in families:
        pascal = short.capitalize()
        source_url = source_map.get(short)
        if source_url and source_url != "system":
            font_res = font_name.lower().replace(" ", "_")
            lines.append(f"// Source: {source_url}")
            lines.append(f"// Download font files and place in res/font/ (e.g., {font_res}_regular.ttf)")
            lines.append(f"// Then replace FontFamily.Default with:")
            lines.append(f"//   FontFamily(Font(R.font.{font_res}_regular, FontWeight.Normal), ...)")
            lines.append(f"val {pascal}FontFamily = FontFamily.Default")
        elif source_url == "system":
            lines.append(f"val {pascal}FontFamily = FontFamily.Default // System font — no setup needed")
        else:
            lines.append(f"val {pascal}FontFamily = FontFamily.Default // Replace with actual font resource")

    lines.append("")

    # Font weight mapping
    weight_map = {
        "400": "FontWeight.Normal",
        "500": "FontWeight.Medium",
        "600": "FontWeight.SemiBold",
        "700": "FontWeight.Bold",
    }

    # Typography object
    # Map token sizes to Material 3 text styles
    body_family = "BodyFontFamily" if any(s == "body" for s, _ in families) else "FontFamily.Default"
    heading_family = "HeadingFontFamily" if any(s == "heading" for s, _ in families) else "FontFamily.Default"

    lines.append("val AppTypography = Typography(")

    # Build size lookup
    size_map = {name: val for name, val in sizes}

    type_styles = [
        ("displayLarge", heading_family, size_map.get("4xl", "36"), "FontWeight.Bold"),
        ("displayMedium", heading_family, size_map.get("3xl", "30"), "FontWeight.Bold"),
        ("displaySmall", heading_family, size_map.get("2xl", "24"), "FontWeight.Bold"),
        ("headlineLarge", heading_family, size_map.get("2xl", "24"), "FontWeight.SemiBold"),
        ("headlineMedium", heading_family, size_map.get("xl", "20"), "FontWeight.SemiBold"),
        ("headlineSmall", heading_family, size_map.get("lg", "18"), "FontWeight.SemiBold"),
        ("titleLarge", heading_family, size_map.get("lg", "18"), "FontWeight.Medium"),
        ("titleMedium", body_family, size_map.get("base", "16"), "FontWeight.Medium"),
        ("titleSmall", body_family, size_map.get("sm", "14"), "FontWeight.Medium"),
        ("bodyLarge", body_family, size_map.get("base", "16"), "FontWeight.Normal"),
        ("bodyMedium", body_family, size_map.get("sm", "14"), "FontWeight.Normal"),
        ("bodySmall", body_family, size_map.get("xs", "12"), "FontWeight.Normal"),
        ("labelLarge", body_family, size_map.get("sm", "14"), "FontWeight.Medium"),
        ("labelMedium", body_family, size_map.get("xs", "12"), "FontWeight.Medium"),
        ("labelSmall", body_family, "11", "FontWeight.Medium"),
    ]

    for i, (style, family, size, weight) in enumerate(type_styles):
        comma = "," if i < len(type_styles) - 1 else ""
        lines.append(f"    {style} = TextStyle(")
        lines.append(f"        fontFamily = {family},")
        lines.append(f"        fontWeight = {weight},")
        lines.append(f"        fontSize = {size}.sp")
        lines.append(f"    ){comma}")

    lines.append(")")
    lines.append("")

    return "\n".join(lines)


def generate_compose_shape(data: dict) -> str:
    """Generate Shape.kt for Jetpack Compose."""
    meta = data.get("meta", {})
    lines = [generate_header_comment(meta, "Jetpack Compose - Shapes")]
    lines.append("package com.example.theme\n")
    lines.append("import androidx.compose.foundation.shape.RoundedCornerShape")
    lines.append("import androidx.compose.material3.Shapes")
    lines.append("import androidx.compose.ui.unit.dp\n")

    radii = collect_radii(data)

    # Individual shape constants
    for name, val in radii:
        kotlin_name = token_name_to_kotlin(name)
        lines.append(f"val Radius{kotlin_name} = RoundedCornerShape({val}.dp)")

    lines.append("")

    # Map to Material 3 Shapes
    radii_map = {name: val for name, val in radii}
    lines.append("val AppShapes = Shapes(")
    lines.append(f"    extraSmall = RoundedCornerShape({radii_map.get('sm', '4')}.dp),")
    lines.append(f"    small = RoundedCornerShape({radii_map.get('sm', '4')}.dp),")
    lines.append(f"    medium = RoundedCornerShape({radii_map.get('md', '8')}.dp),")
    lines.append(f"    large = RoundedCornerShape({radii_map.get('lg', '12')}.dp),")
    lines.append(f"    extraLarge = RoundedCornerShape({radii_map.get('xl', '16')}.dp)")
    lines.append(")")
    lines.append("")

    return "\n".join(lines)


def generate_compose_theme(data: dict) -> str:
    """Generate Theme.kt for Jetpack Compose."""
    meta = data.get("meta", {})
    lines = [generate_header_comment(meta, "Jetpack Compose - Theme")]
    lines.append("package com.example.theme\n")
    lines.append("import androidx.compose.material3.MaterialTheme")
    lines.append("import androidx.compose.material3.lightColorScheme")
    lines.append("import androidx.compose.runtime.Composable\n")

    # Collect colors for color scheme mapping
    color_map = {}
    for key, val in data.get("color", {}).items():
        if isinstance(val, dict) and "value" in val:
            color_map[key] = token_name_to_kotlin(key)

    lines.append("private val LightColorScheme = lightColorScheme(")
    # Map token colors to Material 3 color scheme
    scheme_mapping = [
        ("primary", "primary"),
        ("onPrimary", None),  # typically white
        ("primaryContainer", "primary-light"),
        ("secondary", "secondary"),
        ("secondaryContainer", None),
        ("tertiary", "accent"),
        ("background", "background"),
        ("surface", "surface"),
        ("onBackground", "text-primary"),
        ("onSurface", "text-primary"),
        ("onSurfaceVariant", "text-secondary"),
        ("outline", "border"),
        ("outlineVariant", "border-light"),
        ("error", "error"),
    ]

    entries = []
    for m3_name, token_key in scheme_mapping:
        if token_key and token_key in color_map:
            entries.append(f"    {m3_name} = {color_map[token_key]}")
    lines.append(",\n".join(entries))
    lines.append(")\n")

    lines.append("@Composable")
    lines.append("fun AppTheme(content: @Composable () -> Unit) {")
    lines.append("    MaterialTheme(")
    lines.append("        colorScheme = LightColorScheme,")
    lines.append("        typography = AppTypography,")
    lines.append("        shapes = AppShapes,")
    lines.append("        content = content")
    lines.append("    )")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def generate_compose_dimens(data: dict) -> str:
    """Generate Dimens.kt for Jetpack Compose."""
    meta = data.get("meta", {})
    lines = [generate_header_comment(meta, "Jetpack Compose - Dimensions")]
    lines.append("package com.example.theme\n")
    lines.append("import androidx.compose.ui.unit.dp\n")

    # Spacing
    lines.append("// Spacing")
    spacings = collect_spacing(data)
    for name, val in spacings:
        lines.append(f"val Space{name.replace('space', '').capitalize() if not name[0].isdigit() else 'Space' + name} = {val}.dp"
                     if not name.startswith("space") else f"val {token_name_to_kotlin(name)} = {val}.dp")

    # Clean up: simpler naming
    lines_clean = [generate_header_comment(meta, "Jetpack Compose - Dimensions")]
    lines_clean.append("package com.example.theme\n")
    lines_clean.append("import androidx.compose.ui.unit.dp\n")

    lines_clean.append("object Dimens {")
    lines_clean.append("    // Spacing")
    for name, val in spacings:
        # name is like "space1", "space2", etc.
        lines_clean.append(f"    val {name} = {val}.dp")

    radii = collect_radii(data)
    lines_clean.append("")
    lines_clean.append("    // Border Radius")
    for name, val in radii:
        kotlin_name = "radius" + token_name_to_kotlin(name)
        lines_clean.append(f"    val {kotlin_name} = {val}.dp")

    lines_clean.append("}")
    lines_clean.append("")

    return "\n".join(lines_clean)


# --- Android XML Generation ---

def generate_xml_colors(data: dict) -> str:
    """Generate colors.xml."""
    meta = data.get("meta", {})
    lines = [generate_xml_header(meta, "Android XML - Colors")]
    lines.append("<resources>")

    colors = collect_colors(data)
    for name, hex_val in colors:
        xml_name = token_name_to_xml(name)
        # Android colors.xml uses #AARRGGBB format
        hex_upper = hex_val.lstrip("#").upper()
        lines.append(f'    <color name="{xml_name}">#FF{hex_upper}</color>')

    lines.append("</resources>")
    lines.append("")
    return "\n".join(lines)


def generate_xml_dimens(data: dict) -> str:
    """Generate dimens.xml with spacing, radius, and font sizes."""
    meta = data.get("meta", {})
    lines = [generate_xml_header(meta, "Android XML - Dimensions")]
    lines.append("<resources>")

    # Spacing
    lines.append("    <!-- Spacing -->")
    spacings = collect_spacing(data)
    for name, val in spacings:
        xml_name = name.replace("space", "space_")
        lines.append(f'    <dimen name="{xml_name}">{val}dp</dimen>')

    # Border Radius
    lines.append("")
    lines.append("    <!-- Border Radius -->")
    radii = collect_radii(data)
    for name, val in radii:
        xml_name = "radius_" + token_name_to_xml(name)
        lines.append(f'    <dimen name="{xml_name}">{val}dp</dimen>')

    # Font Sizes
    lines.append("")
    lines.append("    <!-- Font Sizes -->")
    sizes = collect_font_sizes(data)
    for name, val in sizes:
        xml_name = "font_size_" + token_name_to_xml(name)
        lines.append(f'    <dimen name="{xml_name}">{val}sp</dimen>')

    lines.append("</resources>")
    lines.append("")
    return "\n".join(lines)


def generate_xml_styles(data: dict) -> str:
    """Generate styles.xml with component styles."""
    meta = data.get("meta", {})
    lines = [generate_xml_header(meta, "Android XML - Styles")]
    lines.append("<resources>")

    # Font source comments
    font_sources = collect_font_sources(data)
    non_system = [(name, url) for name, url in font_sources if url != "system"]
    if non_system:
        lines.append("    <!-- Font Sources -->")
        for name, url in non_system:
            families_list = collect_font_families(data)
            font_name = next((fn for s, fn in families_list if s == name), name)
            lines.append(f"    <!-- {font_name}: {url} -->")
            lines.append(f"    <!-- Download .ttf files and place in res/font/ -->")
        lines.append("")

    # Text styles
    families = collect_font_families(data)
    sizes = collect_font_sizes(data)
    weights = collect_font_weights(data)

    size_map = {name: val for name, val in sizes}

    text_styles = [
        ("TextAppearance.Heading.Large", size_map.get("3xl", "30"), "bold"),
        ("TextAppearance.Heading.Medium", size_map.get("2xl", "24"), "bold"),
        ("TextAppearance.Heading.Small", size_map.get("xl", "20"), "bold"),
        ("TextAppearance.Body.Large", size_map.get("base", "16"), "normal"),
        ("TextAppearance.Body.Medium", size_map.get("sm", "14"), "normal"),
        ("TextAppearance.Body.Small", size_map.get("xs", "12"), "normal"),
        ("TextAppearance.Label.Large", size_map.get("sm", "14"), "bold"),
        ("TextAppearance.Label.Medium", size_map.get("xs", "12"), "bold"),
    ]

    for style_name, size, text_style in text_styles:
        lines.append(f'    <style name="{style_name}" parent="TextAppearance.Material3.BodyMedium">')
        lines.append(f'        <item name="android:textSize">{size}sp</item>')
        lines.append(f'        <item name="android:textStyle">{text_style}</item>')
        lines.append("    </style>")
        lines.append("")

    # Button style
    lines.append('    <style name="Widget.App.Button.Primary" parent="Widget.Material3.Button">')
    lines.append('        <item name="backgroundTint">@color/primary</item>')
    lines.append('        <item name="cornerRadius">@dimen/radius_md</item>')
    lines.append("    </style>")
    lines.append("")

    # Card style
    lines.append('    <style name="Widget.App.Card" parent="Widget.Material3.CardView.Elevated">')
    lines.append('        <item name="cardCornerRadius">@dimen/radius_lg</item>')
    lines.append('        <item name="contentPadding">@dimen/space_6</item>')
    lines.append("    </style>")

    lines.append("</resources>")
    lines.append("")
    return "\n".join(lines)


def generate_xml_themes(data: dict) -> str:
    """Generate themes.xml."""
    meta = data.get("meta", {})
    lines = [generate_xml_header(meta, "Android XML - Theme")]
    lines.append("<resources>")
    lines.append("")
    lines.append('    <style name="Theme.App" parent="Theme.Material3.Light.NoActionBar">')
    lines.append('        <!-- Primary -->')
    lines.append('        <item name="colorPrimary">@color/primary</item>')
    lines.append('        <item name="colorOnPrimary">#FFFFFF</item>')
    lines.append('        <item name="colorPrimaryContainer">@color/primary_light</item>')
    lines.append("")
    lines.append('        <!-- Secondary -->')
    lines.append('        <item name="colorSecondary">@color/secondary</item>')
    lines.append("")
    lines.append('        <!-- Tertiary -->')
    lines.append('        <item name="colorTertiary">@color/accent</item>')
    lines.append("")
    lines.append('        <!-- Background & Surface -->')
    lines.append('        <item name="android:colorBackground">@color/background</item>')
    lines.append('        <item name="colorSurface">@color/surface</item>')
    lines.append('        <item name="colorOnBackground">@color/text_primary</item>')
    lines.append('        <item name="colorOnSurface">@color/text_primary</item>')
    lines.append('        <item name="colorOnSurfaceVariant">@color/text_secondary</item>')
    lines.append("")
    lines.append('        <!-- Outline -->')
    lines.append('        <item name="colorOutline">@color/border</item>')
    lines.append('        <item name="colorOutlineVariant">@color/border_light</item>')
    lines.append("")
    lines.append('        <!-- Error -->')
    lines.append('        <item name="colorError">@color/error</item>')
    lines.append("    </style>")
    lines.append("")
    lines.append("</resources>")
    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate Kotlin/XML theme files from design tokens")
    parser.add_argument("token_json", help="Path to token JSON file")
    parser.add_argument("--compose", action="store_true", default=False, help="Generate Jetpack Compose output (default)")
    parser.add_argument("--xml", action="store_true", default=False, help="Generate Android XML resources")
    parser.add_argument("--output", "-o", help="Output directory (default: stdout)")
    args = parser.parse_args()

    # Default to compose if neither specified
    if not args.compose and not args.xml:
        args.compose = True

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

    if args.compose:
        outputs.append(("Color.kt", generate_compose_color(data)))
        outputs.append(("Type.kt", generate_compose_type(data)))
        outputs.append(("Shape.kt", generate_compose_shape(data)))
        outputs.append(("Theme.kt", generate_compose_theme(data)))
        outputs.append(("Dimens.kt", generate_compose_dimens(data)))

    if args.xml:
        outputs.append(("colors.xml", generate_xml_colors(data)))
        outputs.append(("dimens.xml", generate_xml_dimens(data)))
        outputs.append(("styles.xml", generate_xml_styles(data)))
        outputs.append(("themes.xml", generate_xml_themes(data)))

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
