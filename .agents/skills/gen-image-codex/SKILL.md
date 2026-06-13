---
name: "gen-image-codex"
description: "Generate images, illustrations, icons, logos, banners, sprites, or textures with the built-in $imagegen tool (gpt-image-2) and save the PNG into the project (default ./images/). Use when the user asks to generate, create, make, render, or design an image / icon / logo / banner / graphic / asset, or when a UI or web task needs art generated into the project. Pass the user's description through verbatim. Prefer explicit invocation with $gen-image-codex."
---

# gen-image-codex — image generation with $imagegen (gpt-image-2)

Generate raster images with the built-in **`$imagegen`** tool (gpt-image-2) and drop the PNG into the project. Use `$imagegen` directly — there is no need to shell out to a nested `codex exec`.

## Core rule: pass the prompt through verbatim

The user's description **is** the prompt. gpt-image-2 follows detailed instructions well, so do not rewrite, embellish, or translate the wording. If the user specified a size, aspect ratio, or format, append it plainly.

## Procedure

1. **Decide the output path.** Default to `./images/` in the working directory (`mkdir -p ./images`); derive a slug filename from the request, e.g. `./images/dark-mode-dashboard-banner.png`. Honor any path the user gives.
2. **Generate** with `$imagegen`, passing the user's description verbatim, and **pin the save path** — instruct it to save the PNG to the chosen path. Pinning the path is the reliable lever; left to defaults, `$imagegen` saves to `~/.codex/generated_images/`.
3. **Confirm** the PNG landed at the chosen path; if it didn't, move it from the default location into `./images/`.
4. **Report** the saved path. If this is part of a build, reference the file directly in the code you write.

## Editing an existing image

To edit rather than generate, provide the source image to `$imagegen` and describe the change in the prompt.

## Notes

- Model is gpt-image-2 — do not substitute another model or a vector/HTML mock without the user's OK.
- Image turns consume ChatGPT/Codex limits ~3–5× faster than text turns; mention only if a run fails on limits.
- This skill calls a paid external service, so it stays **explicit-only** (`$gen-image-codex`) by policy.
