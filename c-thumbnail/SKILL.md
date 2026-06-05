---
name: c-thumbnail
description: Render YouTube/social thumbnail variants from an avatar (or generated) frame + topic — bold HTML-GFX layouts at 1280x720 through headless Chrome, compressed under 2 MB. Produces N variants for selection. Reusable component invoked by image recipes; not an owner-facing pipeline.
when_to_use: Trigger on c-thumbnail, make thumbnail, YouTube thumbnail, thumbnail variants, click-through image, video cover, thumbnail from frame.
allowed-tools: Bash, Read, Write
kind: component
visibility: internal
requires: ffmpeg, chromium
dependsOn: [c-html-gfx, c-ffmpeg]
---

# c-thumbnail — Thumbnail Rendering

Bold, high-contrast HTML-GFX thumbnails from a face/avatar frame + topic. Renders
N variants at 1280x720 and compresses each under 2 MB. The recipe owns variant
SELECTION (presenting + picking a winner); this component owns the render mechanics.

## Inputs

| Input | Required | Default | Notes |
|-------|----------|---------|-------|
| topic | Yes | — | Drives the headline copy |
| frame | Yes | — | PNG face/avatar frame (or a generated image) |
| num_variants | No | `3` | How many layouts to render |
| style | No | brand-ref.md | `text-heavy`, `face-focus`, or `split` |

## Steps

### 1 — Plan variants
Read `brand-ref.md` for the thumbnail style guide (colors, font, any CTR notes).
Plan `num_variants` layouts, e.g.:
- A: face left, text right
- B: full face, text overlay bottom
- C: split — before/after or comparison

Write 3 headline options per variant (shock / curiosity / result-first).

### 2 — Render each variant
→ LOAD: `c-html-gfx` — author HTML per variant at 1280x720: the frame embedded as
  a positioned image, dark/bold brand-palette background, headline 80px+ bold high
  contrast. Screenshot with `--window-size=1280,860` cropped to 1280x720. Run a
  Unicode check after every render. Output `interim/broll/gfx/thumb-{A/B/C}-v1.png`.

### 3 — Compress
→ LOAD: `c-ffmpeg` — JPEG `-q:v 2`; verify each is < 2 MB (YouTube limit). Output
  `interim/broll/gfx/thumb-{A/B/C}-v1.jpg`.

### 4 — Return variants
Return all variant paths to the calling recipe for presentation/selection. On an
iteration request, adjust copy/layout and re-render that variant only. The winner
is delivered by the recipe as `final/ls-tnail01-{topic-slug}.jpg` (1280x720, <2 MB).
