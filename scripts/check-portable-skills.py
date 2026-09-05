#!/usr/bin/env python3
"""Validate portable payloads without pinning workflow prose."""
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
catalog = json.loads((root / "catalog.json").read_text())
errors = []
count = 0
for entry in catalog["skills"]:
    name = entry["name"]
    canonical = root / "skills" / name
    codex = root / ".agents/skills" / name
    portable = entry.get("portable", False)
    if not portable:
        if codex.is_symlink() or (codex / "SKILL.md").is_symlink():
            errors.append(f"unmigrated skill must retain its Codex document: {name}")
        continue
    count += 1
    if not codex.is_symlink() or codex.resolve() != canonical:
        errors.append(f"portable Codex folder must link to canonical: {name}")
    metadata = canonical / "agents/openai.yaml"
    if not metadata.is_file():
        errors.append(f"missing canonical Codex metadata: {name}")
    text = (canonical / "SKILL.md").read_text()
    header = text.split("---", 2)[1]
    keys = set(re.findall(r"^([a-z][a-z-]*):", header, re.M))
    if not {"name", "description"} <= keys or keys - {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}:
        errors.append(f"nonstandard frontmatter in portable skill: {name}")
    if "$ARGUMENTS" in text:
        errors.append(f"host substitution in portable body: {name}")
    # Resolve relative resource links from their real document locations.
    documents = [canonical / "SKILL.md"] + list((canonical / "references").glob("*.md"))
    for document in documents:
        prose = re.sub(r"^```[^\n]*\n.*?^```[^\n]*$", "", document.read_text(), flags=re.M | re.S)
        for target in re.findall(r"\[[^\]]+\]\(([^)\s]+)\)", prose):
            if re.match(r"[a-z][a-z0-9+.-]*:|#", target, re.I):
                continue
            target = target.split("#", 1)[0]
            if not (document.resolve().parent / target).is_file():
                errors.append(f"missing reference from {document}: {target}")
        if document.is_symlink() and not document.exists():
            errors.append(f"broken resource link: {document}")

for error in errors:
    print(f"ERROR: {error}", file=sys.stderr)
print(f"Validated {count} portable skill(s) from one source each.")
sys.exit(bool(errors))
