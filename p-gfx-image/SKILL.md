---
name: p-gfx-image
description: Generate one or many HTML-GFX explainer images (brand-styled, navy/green) from a topic or script via c-html-gfx — single cards, multi-image batches, or platform banners (c-banner; replaces p-banner). Trigger on "make explainer image", "graphic post", "GFX image", "infographic post", "make a banner", "channel art".
when-to-use: Use when the user wants ONE or a FEW brand-styled static images (not a video, not a multi-step carousel PDF). Each image is a self-contained HTML composition rendered to PNG/JPG.
version: 0.1.0
kind: pipeline
visibility: catalog
produces:
  dish: GFX Image Post
  format: image (single or multi)
  duration: n/a
inputs: [topic, count]
dependsOn: [c-html-gfx, c-ffmpeg, c-banner]
---

# p-gfx-image-posts — HTML-GFX Explainer Images

**SCAFFOLD — NOT YET AUTHORED.** Will be authored in the per-recipe review pass.

## Inputs (intake)
1. `topic` — what the image is about
2. `count` — 1 by default; can request a small batch (e.g. 3 variants or a 4-pack)

## Output
- One or many 1080×1080 (or 1080×1920) brand-styled images (PNG), navy/green palette.
