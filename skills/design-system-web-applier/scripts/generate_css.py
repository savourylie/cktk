#!/usr/bin/env python3
"""Generate CSS custom properties or SCSS variables from a design token JSON file.

Usage:
    python3 generate_css.py <token-json> [--format css|scss] [--output <path>] [--components]

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

# Mapping from token section/path to CSS variable prefix
SECTION_PREFIX = {
    "color": "color",
    "spacing": "space",
    "borderRadius": "radius",
    "shadow": "shadow",
}

TYPOGRAPHY_PREFIX = {
    "font-family-heading": "font-heading",
    "font-family-body": "font-body",
    "font-family-mono": "font-mono",
    "font-size": "font-size",
    "font-weight": "font-weight",
    "line-height": "line-height",
    "letter-spacing": "letter-spacing",
}

# Types whose values pass through without conversion
PASSTHROUGH_TYPES = {"color", "fontFamily", "fontWeight", "fontSource", "number", "shadow"}

PX_RE = re.compile(r"^(-?\d+(?:\.\d+)?)px$")


def px_to_rem(value: str) -> str:
    """Convert px values to rem. Passthrough for non-px values."""
    m = PX_RE.match(value)
    if not m:
        return value
    px = float(m.group(1))
    if px == 9999:
        return "9999px"
    if px == 0:
        return "0"
    rem = px / 16
    # Format without trailing zeros
    if rem == int(rem):
        return f"{int(rem)}rem"
    return f"{rem:g}rem"


def convert_value(value: str, token_type: str) -> str:
    """Convert a token value for CSS output."""
    if token_type in PASSTHROUGH_TYPES:
        return value
    # dimension type — convert px to rem
    if token_type == "dimension":
        if value == "0":
            return "0"
        return px_to_rem(value)
    return value


def build_css_variable_name(section: str, key: str, subkey: str = None) -> str:
    """Build a CSS variable name from token path."""
    if section == "typography":
        if subkey:
            prefix = TYPOGRAPHY_PREFIX.get(key, key)
            return f"--{prefix}-{subkey}"
        else:
            prefix = TYPOGRAPHY_PREFIX.get(key, key)
            return f"--{prefix}"
    prefix = SECTION_PREFIX.get(section, section)
    return f"--{prefix}-{key}"


def build_scss_variable_name(section: str, key: str, subkey: str = None) -> str:
    """Build an SCSS variable name from token path."""
    css_name = build_css_variable_name(section, key, subkey)
    return "$" + css_name.lstrip("-")


def generate_header(meta: dict, fmt: str) -> str:
    """Generate a file header comment."""
    name = meta.get("name", "Design System")
    source = meta.get("source", "Unknown")
    version = meta.get("version", "1.0.0")
    generated = date.today().isoformat()
    lines = [
        f"/* {name}",
        f" * Source: {source}",
        f" * Version: {version}",
        f" * Generated: {generated}",
        f" * Format: {'SCSS' if fmt == 'scss' else 'CSS Custom Properties'}",
        " */",
    ]
    return "\n".join(lines)


def collect_font_sources(data: dict) -> list[str]:
    """Collect unique font source URLs from the typography.font-source group."""
    urls = []
    seen = set()
    font_sources = data.get("typography", {}).get("font-source", {})
    for _key, token in font_sources.items():
        if isinstance(token, dict) and "value" in token:
            url = token["value"]
            if url != "system" and url not in seen:
                urls.append(url)
                seen.add(url)
    return urls


def collect_tokens(data: dict) -> list[tuple[str, str, str, str]]:
    """Collect (css_var_name, scss_var_name, value, section) tuples from token data."""
    tokens = []
    section_order = ["color", "typography", "spacing", "borderRadius", "shadow"]

    for section in section_order:
        if section not in data:
            continue
        section_data = data[section]

        if section == "typography":
            for key, val in section_data.items():
                # Skip font-source — handled separately as @import declarations
                if key == "font-source":
                    continue
                if isinstance(val, dict) and "value" in val and "type" in val:
                    # Top-level typography token (font-family-*)
                    css_name = build_css_variable_name(section, key)
                    scss_name = build_scss_variable_name(section, key)
                    converted = convert_value(val["value"], val["type"])
                    tokens.append((css_name, scss_name, converted, section))
                elif isinstance(val, dict):
                    # Nested group (font-size, font-weight, etc.)
                    for subkey, subval in val.items():
                        if isinstance(subval, dict) and "value" in subval and "type" in subval:
                            css_name = build_css_variable_name(section, key, subkey)
                            scss_name = build_scss_variable_name(section, key, subkey)
                            converted = convert_value(subval["value"], subval["type"])
                            tokens.append((css_name, scss_name, converted, section))
        else:
            for key, val in section_data.items():
                if isinstance(val, dict) and "value" in val and "type" in val:
                    css_name = build_css_variable_name(section, key)
                    scss_name = build_scss_variable_name(section, key)
                    converted = convert_value(val["value"], val["type"])
                    tokens.append((css_name, scss_name, converted, section))

    return tokens


SECTION_LABELS = {
    "color": "Colors",
    "typography": "Typography",
    "spacing": "Spacing",
    "borderRadius": "Border Radius",
    "shadow": "Shadows",
}


def generate_font_imports(data: dict) -> str:
    """Generate @import declarations for font sources."""
    urls = collect_font_sources(data)
    if not urls:
        return ""
    lines = []
    for url in urls:
        lines.append(f"@import url('{url}');")
    return "\n".join(lines)


def generate_css(data: dict) -> str:
    """Generate CSS custom properties output."""
    tokens = collect_tokens(data)
    header = generate_header(data.get("meta", {}), "css")

    font_imports = generate_font_imports(data)
    lines = [header, ""]
    if font_imports:
        lines.append(font_imports)
        lines.append("")
    lines.append(":root {")
    current_section = None
    for css_name, _, value, section in tokens:
        if section != current_section:
            if current_section is not None:
                lines.append("")
            lines.append(f"  /* {SECTION_LABELS.get(section, section)} */")
            current_section = section
        lines.append(f"  {css_name}: {value};")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def generate_scss(data: dict) -> str:
    """Generate SCSS variables and maps output."""
    tokens = collect_tokens(data)
    header = generate_header(data.get("meta", {}), "scss")

    font_imports = generate_font_imports(data)
    lines = [header, ""]
    if font_imports:
        lines.append(font_imports)
        lines.append("")

    # Group tokens by section for maps
    section_tokens = {}
    current_section = None
    for _, scss_name, value, section in tokens:
        if section != current_section:
            if current_section is not None:
                lines.append("")
            lines.append(f"// {SECTION_LABELS.get(section, section)}")
            current_section = section
        lines.append(f"{scss_name}: {value};")
        section_tokens.setdefault(section, []).append((scss_name, value))

    # Generate maps
    lines.append("")
    lines.append("// Maps")
    for section in ["color", "typography", "spacing", "borderRadius", "shadow"]:
        if section not in section_tokens:
            continue
        map_name = {
            "color": "$colors",
            "typography": "$typography",
            "spacing": "$spacing",
            "borderRadius": "$radii",
            "shadow": "$shadows",
        }.get(section, f"${section}")
        lines.append(f"{map_name}: (")
        for scss_name, value in section_tokens[section]:
            # Extract the key part after the prefix
            key = scss_name.lstrip("$")
            lines.append(f'  "{key}": {value},')
        lines.append(");")

    lines.append("")
    return "\n".join(lines)


TOKEN_REF_RE = re.compile(r"\{([^}]+)\}")


def build_token_map(data: dict) -> dict[str, str]:
    """Build a map from token paths (e.g. 'color.primary') to CSS variable references."""
    token_map = {}
    for section in ["color", "spacing", "borderRadius", "shadow"]:
        if section not in data:
            continue
        for key, val in data[section].items():
            if isinstance(val, dict) and "value" in val:
                css_name = build_css_variable_name(section, key)
                token_map[f"{section}.{key}"] = f"var({css_name})"
    if "typography" in data:
        for key, val in data["typography"].items():
            if isinstance(val, dict) and "value" in val and "type" in val:
                css_name = build_css_variable_name("typography", key)
                token_map[f"typography.{key}"] = f"var({css_name})"
            elif isinstance(val, dict):
                for subkey, subval in val.items():
                    if isinstance(subval, dict) and "value" in subval:
                        css_name = build_css_variable_name("typography", key, subkey)
                        token_map[f"typography.{key}.{subkey}"] = f"var({css_name})"
    return token_map


def resolve_token_ref(value: str, token_map: dict[str, str]) -> str:
    """Resolve {token.path} references to var(--css-name) calls."""
    def replacer(m):
        path = m.group(1)
        return token_map.get(path, m.group(0))
    return TOKEN_REF_RE.sub(replacer, value)


# CSS properties that map to pseudo-elements or states (not direct properties)
COMPONENT_STATE_PROPS = {
    "hover-background": ("&:hover", "background"),
    "hover-color": ("&:hover", "color"),
    "focus-border": ("&:focus", "border-color"),
    "active-color": ("&.active, &[aria-current]", "color"),
    "active-background": ("&.active, &[aria-current]", "background"),
    "placeholder-color": ("&::placeholder", "color"),
}


def generate_component_classes(data: dict, token_map: dict[str, str], fmt: str) -> str:
    """Generate component utility classes from the components section."""
    components = data.get("components")
    if not components:
        return ""

    lines = []
    if fmt == "scss":
        lines.append("// Component Mixins")
    else:
        lines.append("/* Component Utility Classes */")
    lines.append("")

    for comp_name, props in components.items():
        # Separate regular props from state/pseudo props
        regular_props = {}
        state_props = {}
        for prop, value in props.items():
            if prop in COMPONENT_STATE_PROPS:
                selector, css_prop = COMPONENT_STATE_PROPS[prop]
                state_props.setdefault(selector, []).append(
                    (css_prop, resolve_token_ref(value, token_map))
                )
            elif prop == "shadow":
                regular_props["box-shadow"] = resolve_token_ref(value, token_map)
            else:
                regular_props[prop] = resolve_token_ref(value, token_map)

        if fmt == "scss":
            lines.append(f"@mixin {comp_name} {{")
            for prop, value in regular_props.items():
                lines.append(f"  {prop}: {value};")
            for selector, decls in state_props.items():
                lines.append(f"  {selector} {{")
                for css_prop, value in decls:
                    lines.append(f"    {css_prop}: {value};")
                lines.append("  }")
            lines.append("}")
        else:
            lines.append(f".{comp_name} {{")
            for prop, value in regular_props.items():
                lines.append(f"  {prop}: {value};")
            for selector, decls in state_props.items():
                # For CSS, nest as a separate rule
                css_selector = selector.replace("&", f".{comp_name}")
                lines.append("}")
                lines.append("")
                lines.append(f"{css_selector} {{")
                for css_prop, value in decls:
                    lines.append(f"  {css_prop}: {value};")
            lines.append("}")

        lines.append("")

    return "\n".join(lines)


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


def main():
    parser = argparse.ArgumentParser(description="Generate CSS/SCSS from design tokens")
    parser.add_argument("token_json", help="Path to token JSON file")
    parser.add_argument("--format", choices=["css", "scss"], default="css", help="Output format (default: css)")
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)")
    parser.add_argument("--components", action="store_true", help="Generate component utility classes (CSS) or mixins (SCSS)")
    args = parser.parse_args()

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

    if args.format == "scss":
        output = generate_scss(data)
    else:
        output = generate_css(data)

    if args.components:
        token_map = build_token_map(data)
        comp_output = generate_component_classes(data, token_map, args.format)
        if comp_output:
            output = output.rstrip("\n") + "\n\n" + comp_output

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output)
        print(f"Generated {args.format.upper()} written to {out_path}")
    else:
        print(output)


if __name__ == "__main__":
    main()
