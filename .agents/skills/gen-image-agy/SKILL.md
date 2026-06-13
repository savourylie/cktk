---
name: "gen-image-agy"
description: "Generate images, illustrations, icons, logos, banners, sprites, or textures with Google's Nano Banana (Gemini image) model via the locally installed Antigravity CLI (`agy`), billed to the user's Google AI Pro subscription over OAuth — no Gemini API key and no per-image API billing. Runs the bundled scripts/gen-image.sh (which wraps `agy` headless in a PTY, pins the output path, and verifies a real raster landed) and saves the PNG into the project (default ./images/). Use when the user asks to generate, create, make, render, or design an image / icon / logo / banner / graphic / asset on their Google / Gemini / Nano Banana / Antigravity / AI Pro quota. Prefer gen-image-codex when the user names OpenAI / gpt-image / ChatGPT. Prefer explicit invocation with $gen-image-agy."
---

# gen-image-agy — image generation via Antigravity CLI (Nano Banana, on the AI Pro subscription)

Generate **real generated images** (not code-drawn) with Google's **Nano Banana** model by running the bundled `scripts/gen-image.sh`, which shells out to the locally installed **Antigravity CLI** (`agy`) in headless mode. Billing goes to the user's **Google AI Pro subscription** over OAuth — no Gemini API key, no per-image API billing.

## Prerequisites

Check once. If a prerequisite is unmet, **stop and tell the user** — do not work around it or log in on their behalf.

1. **`agy` installed and on PATH** (`agy --version` succeeds).
2. **Signed in once, interactively** — the user ran `agy` interactively, completed Google OAuth, and quit; headless reuses that cached token. If a run fails on auth, ask the user to do this one-time login.
3. **Never set or ask for a Gemini/Google API key** — this path is OAuth-only by design; a key would route to the paid endpoint and bill separately.
4. macOS primary (BSD `script`); the wrapper also handles Linux. `brew install expect` (for `unbuffer`) is optional but more reliable than `script`.

## Procedure

1. **Decide the output path.** Default to `./images/` in the working directory; the script creates it. Derive a slug filename from the request, e.g. `./images/dark-mode-dashboard-banner.png`. Honor any path the user gives.

2. **Run the bundled script** with the user's description and the explicit output path (width/height optional, default 1024×1024):

   ```bash
   scripts/gen-image.sh "<plain description of the image>" "./images/<slug>.png" [width] [height]
   ```

   The script wraps `agy` in a PTY (required — `agy --print` drops stdout in a non-TTY), injects a guard that forces the real image-generation tool (so `agy` doesn't write code to draw a fake), pins the absolute output path (its default temp location is purged by the OS), and verifies a genuine raster landed.

   - **On success** it prints the PNG's **absolute path** and exits `0`. Capture that one line; do not parse `agy`'s prose.
   - **On failure** it exits non-zero with `agy`'s output on stderr (`1` = no file; `3` = suspiciously tiny file, likely fake).

3. **Report the saved path.** If this is part of a build, reference the returned file directly in the code you write.

## Rules

- **Always pass an explicit in-project output path** (e.g. `./images/…`). Never rely on a default/temp location — `agy`'s own output lands in a temp workspace the OS purges.
- **Do not strip or soften the script's prompt guard** — without it, `agy` (a coding agent) may write PIL code and return a fake image that never touched Nano Banana.

## Notes

- **Budget.** One image ≈ 5 subscription requests; the AI Pro cap is ~200/24h (≈ 40 images/day). Warn the user before batch-generating many images.
- **Code-drawn fake (exit 3 / `.py`,`.js` warning)** → regenerate; if it recurs, `agy`'s headless image tool may be unavailable — fall back to a paid API + image MCP path (needs a key, bills).
- **Empty output (exit 1)** → the PTY wrapper didn't take (antigravity-cli#76); ensure `script` or `unbuffer` is present, `brew install expect`, retry.
- This skill calls an external service on the user's subscription, so it stays **explicit-only** (`$gen-image-agy`) by policy.
