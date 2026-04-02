#!/usr/bin/env bash
# scan_codebase.sh — Static grep-based accessibility analysis for JSX/TSX files
# Outputs JSON array of issues with file, line, rule, wcag, principle, and snippet.
#
# Usage: bash scan_codebase.sh <project-root>
#
# Excludes: node_modules/, .next/, dist/, build/, __tests__/, *.test.*, *.spec.*

set -euo pipefail

PROJECT_ROOT="${1:-.}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "Error: Directory '$PROJECT_ROOT' does not exist" >&2
  exit 1
fi

# Common exclusion patterns for grep
EXCLUDE_DIRS="--exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=__mocks__ --exclude-dir=coverage"
INCLUDE_FILES="--include=*.tsx --include=*.jsx"

ISSUES="[]"

add_issue() {
  local file="$1" line="$2" rule="$3" wcag="$4" principle="$5" snippet="$6"
  # Make file path relative to project root
  file="${file#$PROJECT_ROOT/}"
  # Escape special JSON chars in snippet
  snippet=$(echo "$snippet" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ' | head -c 200)
  ISSUES=$(echo "$ISSUES" | python3 -c "
import sys, json
issues = json.load(sys.stdin)
issues.append({
  'file': '''$file''',
  'line': $line,
  'rule': '$rule',
  'wcag': '$wcag',
  'principle': '$principle',
  'snippet': '''$snippet'''
})
json.dump(issues, sys.stdout)
" 2>/dev/null || echo "$ISSUES")
}

# Helper: run grep and process matches
# Uses grep -rn with includes/excludes, pipes to processing function
run_check() {
  local pattern="$1" rule="$2" wcag="$3" principle="$4"
  grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES "$pattern" "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
    add_issue "$file" "$lineno" "$rule" "$wcag" "$principle" "$content"
  done || true
}

echo "Scanning $PROJECT_ROOT for accessibility issues..." >&2

# ─────────────────────────────────────────────────────────────
# Rule 1: missing-alt — <img> or <Image> without alt attribute
# WCAG 1.1.1 (A) — Perceivable
# ─────────────────────────────────────────────────────────────
echo "  Checking: missing-alt (1.1.1)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES '<(img|Image)\b' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  # Check if this line or nearby lines have alt attribute
  if ! echo "$content" | grep -qE '\balt\s*='; then
    add_issue "$file" "$lineno" "missing-alt" "1.1.1" "Perceivable" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 2: missing-form-label — <input>/<select>/<textarea> without label association
# WCAG 1.3.1 (A) — Perceivable
# ─────────────────────────────────────────────────────────────
echo "  Checking: missing-form-label (1.3.1)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES '<(input|select|textarea)\b' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  # Skip if hidden or submit/button type
  if echo "$content" | grep -qE 'type\s*=\s*"(hidden|submit|button|reset|image)"'; then
    continue
  fi
  # Check for aria-label, aria-labelledby, or id (which may be referenced by label)
  if ! echo "$content" | grep -qE '(aria-label|aria-labelledby|id)\s*='; then
    add_issue "$file" "$lineno" "missing-form-label" "1.3.1" "Perceivable" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 3: missing-html-lang — <html> or <Html> without lang attribute
# WCAG 3.1.1 (A) — Understandable
# ─────────────────────────────────────────────────────────────
echo "  Checking: missing-html-lang (3.1.1)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES '<(html|Html)\b' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  if ! echo "$content" | grep -qE '\blang\s*='; then
    add_issue "$file" "$lineno" "missing-html-lang" "3.1.1" "Understandable" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 4: heading-hierarchy — Multiple h1 tags in same file; skip levels detected
# WCAG 1.3.1 (A) — Perceivable
# ─────────────────────────────────────────────────────────────
echo "  Checking: heading-hierarchy (1.3.1)" >&2
# Find files with multiple h1 tags
grep -rlE $EXCLUDE_DIRS $INCLUDE_FILES '<h1[\s>]' "$PROJECT_ROOT" 2>/dev/null | while read -r file; do
  h1_count=$(grep -cE '<h1[\s>]' "$file" 2>/dev/null || echo 0)
  if [ "$h1_count" -gt 1 ]; then
    first_line=$(grep -nE '<h1[\s>]' "$file" 2>/dev/null | head -1)
    lineno=$(echo "$first_line" | cut -d: -f1)
    content=$(echo "$first_line" | cut -d: -f2-)
    add_issue "$file" "${lineno:-0}" "heading-hierarchy" "1.3.1" "Perceivable" "Multiple h1 tags found ($h1_count instances): $content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 5: click-without-keyboard — onClick on non-button/link without keyboard handler
# WCAG 2.1.1 (A) — Operable
# ─────────────────────────────────────────────────────────────
echo "  Checking: click-without-keyboard (2.1.1)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES '<(div|span|li|td|tr|p|section|article)\b[^>]*onClick' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  if ! echo "$content" | grep -qE '(onKeyDown|onKeyUp|onKeyPress)\s*='; then
    add_issue "$file" "$lineno" "click-without-keyboard" "2.1.1" "Operable" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 6: non-semantic-interactive — <div>/<span> with onClick but no role/tabIndex
# WCAG 4.1.2 (A) — Robust
# ─────────────────────────────────────────────────────────────
echo "  Checking: non-semantic-interactive (4.1.2)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES '<(div|span)\b[^>]*onClick' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  if ! echo "$content" | grep -qE '(role|tabIndex)\s*='; then
    add_issue "$file" "$lineno" "non-semantic-interactive" "4.1.2" "Robust" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 7: positive-tabindex — tabIndex > 0
# WCAG 2.4.3 (A) — Operable
# ─────────────────────────────────────────────────────────────
echo "  Checking: positive-tabindex (2.4.3)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES 'tabIndex\s*=\s*\{?\s*[1-9]' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  add_issue "$file" "$lineno" "positive-tabindex" "2.4.3" "Operable" "$content"
done || true

# ─────────────────────────────────────────────────────────────
# Rule 8: non-descriptive-link — Links with generic text
# WCAG 2.4.4 (A) — Operable
# ─────────────────────────────────────────────────────────────
echo "  Checking: non-descriptive-link (2.4.4)" >&2
grep -rnEi $EXCLUDE_DIRS $INCLUDE_FILES '>\s*(click here|read more|learn more|here|more|link|details)\s*</' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  # Only flag if it's inside an <a> or <Link> tag
  if echo "$content" | grep -qEi '<(a|Link)\b'; then
    add_issue "$file" "$lineno" "non-descriptive-link" "2.4.4" "Operable" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 9: autoplay-media — <video>/<audio> with autoPlay without muted
# WCAG 1.4.2 (A) — Perceivable
# ─────────────────────────────────────────────────────────────
echo "  Checking: autoplay-media (1.4.2)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES '<(video|audio)\b[^>]*autoPlay' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  if ! echo "$content" | grep -qE '\bmuted\b'; then
    add_issue "$file" "$lineno" "autoplay-media" "1.4.2" "Perceivable" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Rule 10: missing-htmlfor — <label> without htmlFor (or for)
# WCAG 1.3.1 (A) — Perceivable
# ─────────────────────────────────────────────────────────────
echo "  Checking: missing-htmlfor (1.3.1)" >&2
grep -rnE $EXCLUDE_DIRS $INCLUDE_FILES '<label\b' "$PROJECT_ROOT" 2>/dev/null | while IFS=: read -r file lineno content; do
  # Skip if self-closing or has htmlFor/for or wraps an input (can't detect wrapping with single-line grep)
  if ! echo "$content" | grep -qE '(htmlFor|for)\s*='; then
    # Check if it's not a self-closing label with aria-label (edge case)
    add_issue "$file" "$lineno" "missing-htmlfor" "1.3.1" "Perceivable" "$content"
  fi
done || true

# ─────────────────────────────────────────────────────────────
# Output results as JSON
# ─────────────────────────────────────────────────────────────
ISSUE_COUNT=$(echo "$ISSUES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
echo "" >&2
echo "Scan complete. Found $ISSUE_COUNT potential issues." >&2

# Pretty-print the JSON output
echo "$ISSUES" | python3 -m json.tool 2>/dev/null || echo "$ISSUES"
