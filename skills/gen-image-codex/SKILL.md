---
name: gen-image-codex
user-invocable: true
description: "Generate images, illustrations, icons, logos, banners, sprites, textures, or avatars with OpenAI's gpt-image-2 via the locally installed Codex CLI — billed through the user's ChatGPT subscription, with no API key or per-image API billing. Shells out to `codex exec` with the built-in $imagegen tool and saves the PNG into the project (default ./images/). Use whenever the user asks to generate, create, make, draw, render, or design an image / icon / logo / banner / graphic / asset — even if they don't name a model — or when a UI, landing page, or game needs art generated and wired in. Also edits an existing image via --image. Triggers on: /gen-image-codex, generate an image, create an illustration, make an icon, design a logo, render a banner, app icon, game sprite, hero image, placeholder art, og:image. Do NOT use for: full design systems or tokens (use the design-system / cinematic-design-system skills), UX specs (ux-design), or flat vector icons better as inline SVG."
---

**Argument:** `$ARGUMENTS`

# gen-image-codex — image generation via Codex CLI (gpt-image-2)

Generate raster images with **gpt-image-2** by shelling out to the locally installed **Codex CLI**, which runs its built-in `$imagegen` tool under the user's **ChatGPT subscription**. No OpenAI API key, no separate API billing — usage counts against the user's existing ChatGPT/Codex limits.

The user's description **is** the prompt. gpt-image-2 follows detailed instructions well, so pass the wording through verbatim — rewriting or "improving" it loses intent.

If `$ARGUMENTS` is non-empty, treat it as the image description (and/or an explicit output path); otherwise take the request from the surrounding conversation.

## When this applies (and when it doesn't)

Use this for **generated raster art** — a rendered image, illustration, icon, logo, banner, sprite, texture, avatar, photo-like asset, or placeholder art dropped into a project.

Reach for a different tool when the user wants a **design system** or **design tokens** (`cinematic-design-system`, `design-system-extractor`, the `*-applier` skills), a **UX spec** (`ux-design`), or a **simple flat vector icon / diagram** that is cleaner as inline SVG or code. When a request is genuinely for a generated image, do **not** silently substitute an SVG or an HTML/CSS mock — generate the real image, or ask first.

## Prerequisites

Check once at the start. If either fails, **stop and tell the user** — do not work around it, and do not attempt to log in on their behalf.

1. **Codex CLI installed** — `codex --version` succeeds. If not, tell the user to install it (`brew install codex` on macOS, or https://github.com/openai/codex) and stop.
2. **Authenticated via ChatGPT** — `codex login status` reports a **ChatGPT** session (not an API-key session) and exits `0`. If not, tell the user to run `codex login` (browser OAuth with their ChatGPT account) and stop. An API-key session would bill separately, which defeats the purpose.

## Procedure

1. **Decide the output path.** Default to `./images/` in the current working directory; create it with `mkdir -p ./images`. Derive a filename slug from the request, e.g. `./images/dark-mode-dashboard-banner.png`. Honor any path or filename the user specifies.

2. **Build the prompt from the user's words, verbatim.** Do not rewrite, embellish, translate, or "improve" the description. If the user asked for a specific size, aspect ratio, or format, append that instruction plainly.

3. **Run, from the working directory.** Escape `\$imagegen` so bash passes the literal trigger through to Codex (inside double quotes, an unescaped `$imagegen` expands to nothing):

   ```bash
   OUT="./images/<slug>.png"
   mkdir -p "$(dirname "$OUT")"
   codex exec \
     --skip-git-repo-check \
     --sandbox workspace-write \
     --output-last-message /tmp/gen-image-codex-last.txt \
     "<USER PROMPT VERBATIM>. \$imagegen. Save the PNG to ${OUT}" </dev/null
   ```

   Flags: `exec` is Codex's non-interactive mode — it runs to completion autonomously and exits (no TUI; approval defaults to `never`, so no approval flag is needed — current Codex no longer accepts `--ask-for-approval`); `--sandbox workspace-write` lets it write the PNG into the working directory; `--skip-git-repo-check` allows running in any folder; `--output-last-message` captures Codex's final message, which states the saved path. The trailing `</dev/null` keeps the unattended run from blocking on stdin.

4. **Confirm and recover.** The PNG should be at `$OUT`. If it isn't, read `/tmp/gen-image-codex-last.txt` — Codex's final message states where it actually saved the file — and move it into `./images/`. Left to its own defaults, `$imagegen` saves to `~/.codex/generated_images/`; pinning the path in the prompt (step 3) is the reliable lever.

5. **Report the saved path.** If this is part of a larger build (a UI, a game, a web page), reference the file directly in the code you're writing.

## Editing an existing image

To modify an existing image instead of generating a fresh one, pass the source with `--image <path.png>` (repeatable for multiple inputs) and describe the change in the prompt. Everything else about the command is the same.

## Notes & failure modes

- **Model is gpt-image-2.** Do not silently substitute DALL·E, a different model, or an HTML/SVG mock unless the user approves.
- **Limits.** Generation counts toward the user's ChatGPT/Codex usage, and image turns burn limits ~3–5× faster than text turns. Only surface this if a run fails on limits.
- **API-key fallback.** If Codex reports it needs an API key, it fell through to its `scripts/image_gen.py` path (used for fine-grained control like masks or batches), which requires `OPENAI_API_KEY`. Simplify the request so the built-in tool applies, or tell the user that path needs a key set deliberately.

## Checklist

- [ ] Prerequisites verified (codex installed + ChatGPT login), or stopped with a clear message.
- [ ] Output path decided; `./images/` created (or the user's path honored).
- [ ] Prompt taken from the user's description verbatim; `\$imagegen` escaped in the command.
- [ ] PNG confirmed at the target path (or recovered via `/tmp/gen-image-codex-last.txt`).
- [ ] Saved path reported; wired into the code if part of a build.
