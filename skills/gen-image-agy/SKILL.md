---
name: gen-image-agy
user-invocable: true
description: "Generate images, illustrations, icons, logos, banners, sprites, textures, or avatars with Google's Nano Banana (Gemini image) model via the locally installed Antigravity CLI (`agy`), run headless inside a PTY — billed to the user's Google AI Pro subscription over OAuth, with no Gemini API key and no per-image API billing. Saves the PNG into the project (default ./images/). Use whenever the user wants to generate, create, make, draw, render, or design an image / icon / logo / banner / graphic / asset on their Google / Gemini / Nano Banana / Antigravity / AI Pro quota — even if they don't name the model. Triggers on: /gen-image-agy, generate an image with agy, nano banana image, use my Google AI Pro to make a picture, antigravity image, gemini image. Prefer gen-image-codex when the user names OpenAI / gpt-image / ChatGPT / Codex. Do NOT use for: design systems or tokens (design-system / cinematic-design-system), UX specs (ux-design), or flat vector icons better as inline SVG."
---

**Argument:** `$ARGUMENTS`

# gen-image-agy — image generation via Antigravity CLI (Nano Banana, on the AI Pro subscription)

Generate **real generated images** (not code-drawn) with Google's **Nano Banana** image model by shelling out to the locally installed **Antigravity CLI** (`agy`) in headless mode. Billing goes to the user's **Google AI Pro subscription** over OAuth — no Gemini API key, no per-image API billing.

A bundled script (`scripts/gen-image.sh`) does the fiddly part: it wraps `agy` in a PTY (required — see below), pins the output path, injects a guard that forces the real image-generation tool, and verifies a genuine raster file landed before returning. Treat its one-line stdout as the result.

If `$ARGUMENTS` is non-empty, treat it as the image description (and/or an explicit output path); otherwise take the request from the surrounding conversation.

## When this applies (and when it doesn't)

Use this for **generated raster art** on the Google/Antigravity path — a rendered image, illustration, icon, logo, banner, sprite, texture, avatar, photo-like asset, or placeholder art dropped into a project, when the user wants it billed to their Google AI Pro subscription rather than a paid API.

Choosing between the two image skills: if the user names **OpenAI / gpt-image / ChatGPT / Codex**, use `gen-image-codex` instead. If they name **Google / Gemini / Nano Banana / Antigravity / AI Pro / agy**, use this skill. If the request is generic ("generate an image of…") and the choice is genuinely open, either works — pick one and mention the other exists rather than stalling.

Reach for a different kind of skill entirely when the user wants a **design system** or **design tokens** (`cinematic-design-system`, `design-system-extractor`, the `*-applier` skills), a **UX spec** (`ux-design`), or a **simple flat vector icon / diagram** that is cleaner as inline SVG or code. When a request is genuinely for a generated image, do **not** silently substitute an SVG or an HTML/CSS mock — generate the real image, or ask first.

## Prerequisites

Check once at the start. If a prerequisite is unmet, **stop and tell the user** — do not work around it, and do not attempt to log in on their behalf.

1. **`agy` installed and on PATH** — `agy --version` succeeds. If not, tell the user to install the Antigravity CLI and stop.
2. **Signed in once, interactively** — the user must have run `agy` interactively at least once, completed the Google OAuth, and quit. The headless calls reuse that cached keyring token. If runs fail with an auth/login error, ask the user to do this one-time interactive login.
3. **Never set or ask for a Gemini/Google API key.** This path is OAuth-only and that is the entire point — an API key would route to the paid `generativelanguage.googleapis.com` endpoint and bill separately.
4. macOS is the primary target (BSD `script`); the wrapper also handles Linux (`script -c`). `brew install expect` (provides `unbuffer`) is optional but more reliable than `script`.

## Procedure

1. **Decide the output path.** Default to `./images/` in the working directory; the script creates the directory. Derive a filename slug from the request, e.g. `./images/dark-mode-dashboard-banner.png`. Honor any path or filename the user specifies.

2. **Run the bundled script** with the user's description and the explicit in-project output path. Width/height are optional (default 1024×1024):

   ```bash
   scripts/gen-image.sh "<plain description of the image>" "./images/<slug>.png" [width] [height]
   ```

   Example:
   ```bash
   scripts/gen-image.sh "a photorealistic red apple on a rustic wooden table, soft window light" "./images/hero-apple.png" 1024 1024
   ```

   - **On success** the script prints the **absolute path** of the PNG and exits `0`. That one line is the result — capture it; do not parse `agy`'s prose.
   - **On failure** it exits non-zero and prints `agy`'s output to stderr (exit `1` = no file produced; exit `3` = a suspiciously tiny file, likely fake).

3. **Report the saved path.** If this is part of a larger build (a UI, a web page, a game), reference the returned file directly in the code you write.

## Rules (do not deviate)

1. **Always pass an explicit output path inside the project** (e.g. `./images/…`). Never rely on a default/temp location — `agy`'s own output lands in a temp workspace the OS purges, so the file would "disappear."
2. **Do not strip or soften the script's prompt guard.** The script forces the image-generation tool and forbids drawing with code; without it, `agy` (a coding agent) may write PIL code and return a fake image that never touched Nano Banana.

## Budget awareness

One image consumes roughly **5 subscription requests** (agent reasoning + generation + format conversion). The AI Pro cap is about **200 requests / 24h** — so ≈ **40 images/day**. Plenty for a hero image or a few assets; tight for bulk asset runs. If the user asks for many images in one go, warn them about the cap before batch-generating.

## Troubleshooting

- **Empty output / no file (exit 1)** → the PTY wrapper didn't take on this `agy` build (known stdout-in-non-TTY bug, antigravity-cli#76). Confirm `script` or `unbuffer` is present; `brew install expect` and retry.
- **Exit 3 (tiny file), or a `.py`/`.js` warning** → likely a code-drawn fake; regenerate. If it recurs, `agy`'s headless image tool may be unavailable on this build — fall back to a paid API + image MCP path (which needs a key and bills).
- **Quota lockout** ("resume at <time>" / long cooldown) → the subscription cap is exhausted; wait for reset, or fall back to API + MCP.

## Durability note

This OAuth path works **today** because `agy` headless hits the Cloud Code endpoint (`daily-cloudcode-pa.googleapis.com`), not the public API. If a future `agy` starts requiring an API key, or changes its output rendering so the PTY can no longer recover stdout, this skill needs to fall back to API + MCP. Treat it as "currently works," not a long-term guarantee.

## Checklist

- [ ] Prerequisites verified (`agy` installed + one-time interactive login done), or stopped with a clear message.
- [ ] Output path decided inside the project; passed explicitly to the script.
- [ ] Bundled script called with the user's description; prompt guard left intact.
- [ ] PNG confirmed at the target path (script exit `0`, one-line absolute path).
- [ ] Saved path reported; wired into the code if part of a build.
