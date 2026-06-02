---
name: p-longform
description: Longform video production — unified pipeline for VSL, demo, or tutorial (script → talking-head avatar + b-roll + GFX → finished video). Trigger on "make a VSL", "make a longform", "demo video", "tutorial video", "long-form video".
when-to-use: Use for any longform video (>2 min). Pass `format` to pick the structure — vsl (sales-letter beats: hook→problem→solution→offer→CTA), demo (product/feature walkthrough), or tutorial (step-by-step educational).
version: 0.1.0
kind: pipeline
visibility: catalog
providers: heygen, elevenlabs, kie
produces:
  dish: Longform Video
  format: 16:9 video
  duration: 5-20 min
inputs: [script, format, broll_dir]
dependsOn: [c-script, c-heygen, c-broll, c-html-gfx, c-audio, c-production, c-ffmpeg, c-ai-media]
---

# p-longform — Unified Longform Video

**SCAFFOLD — NOT YET AUTHORED.** This recipe replaces p-vsl, p-demo, and p-longform-visual with a single pipeline parameterized by `format`. Full authoring (param table, step-by-step ffmpeg/HeyGen flow, format-specific structure differences) will be done in the per-recipe review pass.

## Inputs (intake — ask user first)
1. `format` — `vsl` | `demo` | `tutorial`
2. `script` — paste or upload
3. `broll_dir` (optional) — b-roll library or recording

## Format differences (high-level)
- **vsl** — sales beats (hook → problem → agitation → solution → proof → offer → CTA), avatar PIP, GFX cards on key claims.
- **demo** — screen-recording-led, avatar PIP top-right or bottom, callouts on UI.
- **tutorial** — step-by-step structure, numbered chapters, walkthrough visuals.

## Outputs
- 16:9 H.264 mp4, target duration 5–20 min, branded outro appended.
