---
name: p-ai-image-posts
description: Generate one or many AI images for social posts via Gemini/Nanobanana (c-ai-media), fal.ai/kie.ai FLUX (c-kie-ai), or Replicate (c-replicate). Trigger on "make an AI image", "generate image", "AI image post", "single image", "image batch".
when-to-use: Use when the user wants ONE or a small batch of generated/AI images (a photo-style scene, an illustration, a character). Not for HTML/explainer graphics (use p-gfx-image-posts) and not for video.
version: 0.1.0
kind: pipeline
visibility: catalog
produces:
  dish: AI Image Post
  format: image (single or multi)
  duration: n/a
inputs: [prompt, count, provider]
dependsOn: [c-ai-media, c-kie-ai, c-replicate, c-ffmpeg]
---

# p-ai-image-posts — AI Image Post(s)

**SCAFFOLD — NOT YET AUTHORED.** Will be authored in the per-recipe review pass.

## Inputs (intake)
1. `prompt` — natural-language image description
2. `count` — 1 by default; or a small batch (2–6)
3. `provider` (optional) — `gemini` (default, c-ai-media) | `fal` / `kie` (c-kie-ai) | `replicate` (c-replicate)

## Output
- One or many AI-generated images, brand-aspect (square / portrait / landscape per request).
