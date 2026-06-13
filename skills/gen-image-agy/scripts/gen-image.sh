#!/usr/bin/env bash
#
# gen-image.sh — generate an image via Antigravity CLI (agy) headless mode,
# on the user's Google AI Pro subscription (OAuth). No paid Gemini API.
#
# Usage:  gen-image.sh "<prompt>" "<output_path.png>" [width] [height]
#   <prompt>       plain description of the image (anti-code-draw guard is added automatically)
#   <output_path>  where the PNG MUST land (absolute or relative; dir is created)
#   width/height   optional, default 1024 1024
#
# Exit:  0 -> PNG produced at <output_path> (its absolute path is printed)
#        1 -> no image produced;  3 -> file suspiciously small (likely fake)
#
set -uo pipefail

PROMPT_IN="${1:?usage: gen-image.sh \"<prompt>\" \"<output_path>\" [w] [h]}"
OUT_RAW="${2:?usage: gen-image.sh \"<prompt>\" \"<output_path>\" [w] [h]}"
W="${3:-1024}"; H="${4:-1024}"

# Make OUT absolute; ensure its directory exists (sips writes here).
mkdir -p "$(dirname "$OUT_RAW")"
OUT="$(cd "$(dirname "$OUT_RAW")" && pwd)/$(basename "$OUT_RAW")"

# Scratch workspace so agy's intermediate artifacts don't pollute the project.
WORK="$(mktemp -d -t agy-genimg)"
LOG="$WORK/agy.log"
cd "$WORK" || exit 1
trap 'rm -rf "$WORK"' EXIT

# Force the image-GENERATION path; forbid code-drawing (agy is a coding agent
# and will otherwise write PIL code, yielding a fake result that ignores Nano Banana).
PROMPT="Use your built-in image generation capability (Nano Banana / Gemini image) to generate this image: ${PROMPT_IN}. Aim for about ${W}x${H}. Do NOT write or run any code to draw it; use the image generation tool directly. Save the result as a PNG to the EXACT absolute path ${OUT} (use sips to convert if the generator emits JPEG). Print only that absolute path when done."

# PTY wrapper defeats agy #76 (stdout dropped in non-TTY). $1=logfile, rest=command.
run_in_pty() {
  local log="$1"; shift
  if command -v unbuffer >/dev/null 2>&1; then
    unbuffer "$@" >"$log" 2>&1
  elif [ "$(uname)" = "Darwin" ]; then
    script -q "$log" "$@" >/dev/null 2>&1
  else
    script -q -c "$(printf '%q ' "$@")" "$log" >/dev/null 2>&1
  fi
}

run_in_pty "$LOG" \
  agy --dangerously-skip-permissions --print-timeout 180s -p "$PROMPT"

# Verify a real raster image actually landed at OUT.
if [ -f "$OUT" ] && file -b "$OUT" | grep -qiE 'image data'; then
  bytes=$(wc -c < "$OUT" | tr -d ' ')
  if [ "${bytes:-0}" -lt 10240 ]; then
    echo "gen-image: $OUT is only ${bytes}B — suspiciously small, likely not a real generation." >&2
    sed -e 's/\r$//' "$LOG" >&2
    exit 3
  fi
  if ls "$WORK"/*.py "$WORK"/*.js >/dev/null 2>&1; then
    echo "gen-image: WARNING — code files in agy workspace; verify it wasn't code-drawn." >&2
  fi
  echo "$OUT"; exit 0
else
  echo "gen-image: no image produced at $OUT. agy output:" >&2
  sed -e 's/\r$//' "$LOG" >&2
  exit 1
fi
