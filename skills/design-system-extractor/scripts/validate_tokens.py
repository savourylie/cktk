#!/usr/bin/env python3
"""Validate a design token JSON file against the expected schema.

Usage:
    python3 validate_tokens.py <path-to-json-file>

Exit codes:
    0 - Valid
    1 - Validation errors found
    2 - File/parse error
"""

import json
import re
import sys
from pathlib import Path


REQUIRED_SECTIONS = ["meta", "color", "typography", "spacing", "borderRadius", "shadow"]
REQUIRED_META_FIELDS = ["name", "source", "version", "generated"]

HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")
PX_RE = re.compile(r"^-?\d+(\.\d+)?px$")
EM_RE = re.compile(r"^-?\d+(\.\d+)?em$")
SHADOW_RE = re.compile(r"^(\d+\s+){2,3}\d+px\s+rgba\(.+\)$|^none$")
TOKEN_REF_RE = re.compile(r"\{[\w.-]+\}")
URL_RE = re.compile(r"^https?://.+$")
VALID_TYPES = {"color", "dimension", "fontFamily", "fontWeight", "fontSource", "number", "shadow"}


def validate(data: dict) -> list[str]:
    errors = []

    # Check required top-level sections
    for section in REQUIRED_SECTIONS:
        if section not in data:
            errors.append(f"Missing required section: '{section}'")

    # Validate meta
    meta = data.get("meta", {})
    for field in REQUIRED_META_FIELDS:
        if field not in meta:
            errors.append(f"Missing required meta field: '{field}'")

    # Validate color tokens
    colors = data.get("color", {})
    for name, token in colors.items():
        if not isinstance(token, dict):
            errors.append(f"color.{name}: expected object, got {type(token).__name__}")
            continue
        if "value" not in token:
            errors.append(f"color.{name}: missing 'value'")
        elif not HEX_RE.match(token["value"]):
            errors.append(f"color.{name}: value '{token['value']}' is not a valid 6-digit hex")
        if "type" not in token:
            errors.append(f"color.{name}: missing 'type'")
        elif token["type"] != "color":
            errors.append(f"color.{name}: type should be 'color', got '{token['type']}'")

    # Validate typography
    typo = data.get("typography", {})
    if "font-size" in typo:
        for name, token in typo["font-size"].items():
            if isinstance(token, dict) and "value" in token:
                if not PX_RE.match(token["value"]):
                    errors.append(f"typography.font-size.{name}: value '{token['value']}' should be in px")
    if "font-weight" in typo:
        for name, token in typo["font-weight"].items():
            if isinstance(token, dict) and "value" in token:
                try:
                    w = int(token["value"])
                    if w < 100 or w > 900 or w % 100 != 0:
                        errors.append(f"typography.font-weight.{name}: value '{token['value']}' should be 100-900 in increments of 100")
                except ValueError:
                    errors.append(f"typography.font-weight.{name}: value '{token['value']}' should be numeric")

    if "font-source" in typo:
        for name, token in typo["font-source"].items():
            if not isinstance(token, dict):
                errors.append(f"typography.font-source.{name}: expected object, got {type(token).__name__}")
                continue
            if "value" not in token:
                errors.append(f"typography.font-source.{name}: missing 'value'")
            elif token["value"] != "system" and not URL_RE.match(token["value"]):
                errors.append(f"typography.font-source.{name}: value must be a valid URL or 'system'")
            if "type" not in token:
                errors.append(f"typography.font-source.{name}: missing 'type'")
            elif token["type"] != "fontSource":
                errors.append(f"typography.font-source.{name}: type should be 'fontSource', got '{token['type']}'")

    # Validate spacing
    spacing = data.get("spacing", {})
    for name, token in spacing.items():
        if isinstance(token, dict) and "value" in token:
            if not PX_RE.match(token["value"]):
                errors.append(f"spacing.{name}: value '{token['value']}' should be in px")

    # Validate borderRadius
    radii = data.get("borderRadius", {})
    for name, token in radii.items():
        if isinstance(token, dict) and "value" in token:
            if not PX_RE.match(token["value"]):
                errors.append(f"borderRadius.{name}: value '{token['value']}' should be in px")

    # Validate shadow
    shadows = data.get("shadow", {})
    for name, token in shadows.items():
        if isinstance(token, dict):
            if "type" in token and token["type"] != "shadow":
                errors.append(f"shadow.{name}: type should be 'shadow', got '{token['type']}'")

    # Validate component references
    components = data.get("components", {})
    all_tokens = _collect_token_paths(data)
    for comp_name, comp in components.items():
        if not isinstance(comp, dict):
            continue
        for prop, value in comp.items():
            if not isinstance(value, str):
                continue
            refs = TOKEN_REF_RE.findall(value)
            for ref in refs:
                ref_path = ref.strip("{}")
                if ref_path not in all_tokens:
                    errors.append(f"components.{comp_name}.{prop}: reference '{ref}' not found in tokens")

    return errors


def _collect_token_paths(data: dict, prefix: str = "") -> set[str]:
    """Collect all token paths (dot-separated) from the data, excluding meta and components."""
    paths = set()
    skip = {"meta", "components"}
    for key, value in data.items():
        if key in skip:
            continue
        current = f"{prefix}{key}" if not prefix else f"{prefix}.{key}"
        if isinstance(value, dict):
            if "value" in value and "type" in value:
                paths.add(current)
            else:
                paths.update(_collect_token_paths(value, current))
    return paths


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 validate_tokens.py <path-to-json-file>")
        sys.exit(2)

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"Error: File not found: {path}")
        sys.exit(2)

    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON: {e}")
        sys.exit(2)

    errors = validate(data)

    if errors:
        print(f"Validation failed with {len(errors)} error(s):\n")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("Validation passed. All tokens conform to the schema.")
        sys.exit(0)


if __name__ == "__main__":
    main()
