---
name: pipeline-avatar-short
description: Avatar-based 9:16 short production pipeline. Produces a portrait short with chroma-keyed avatar, b-roll overlay, captions, SFX, and brand outro. Orchestrates script → HeyGen → transcription → portrait b-roll plan → composite → captions → delivery.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [layout?]"
allowed-tools: Bash, Read, Write
---

# pipeline-avatar-short — Avatar Short (9:16)

Produces a 9:16 portrait short with chroma-keyed avatar composite.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| script | Yes | — | Path to draft `.md` or TTS-clean `.txt` |
| source_video | No | — | Reuse existing green-screen render |
| layout | No | `bottom-avatar` | Portrait layout: `bottom-avatar`, `split-broll`, `pip-broll`, `split-equal`, `popout` |
| speed | No | — | TTS speed multiplier |
| num_images | No | `4` | AI images to generate |
| num_gfx | No | `3` | HTML GFX cards |
| captions | No | `true` | Burn captions |
| sfx | No | `false` | Include SFX |

## Steps

### Step 1 — Script ⛔ CHECKPOINT
→ Skill: `studio-script` → short-form (75–150 words, 30–60s)
→ TTS preprocess → `interim/scripts/{name}-tts.txt`
**Gate: User approves script.**

### Step 2 — Avatar Render ⛔ CHECKPOINT
If `source_video` provided: skip.
→ Skill: `heygen` → browser render, `#00FF00` background
**Gate: User triggers render, provides job ID.**

### Step 3 — Poll & Download
→ Skill: `heygen` → Floe API poll (60s)
→ Download → `interim/video/base/{name}-green-screen.mp4`
→ Verify green screen
→ If `speed` set: apply speed adjust

### Step 4 — Transcription
→ Skill: `studio-audio` → MLX Whisper
→ Output SRT → `interim/audio/{name}.srt`

### Step 5 — B-Roll Planning ⛔ CHECKPOINT
→ Skill: `broll` → check library → match to script → portrait placement plan
→ Use SRT timecodes. Layout: `$layout`.
→ Guard: ≥4 unique assets, ≥80% coverage, ≤6s per PIP segment.
**Gate: User reviews plan.**

### Step 6 — Asset Generation
→ AI images: `ai-media` → `brolls/images/` (read `brand-ref.md` first)
→ GFX cards: `html-gfx` → `interim/broll/gfx/`
→ Website scroll: `web-capture` (if in plan) → `interim/broll/segments/`

### Step 7 — Contextual Background
→ Skill: `ai-media` → contextual bg for avatar segments
→ `interim/video/base/{name}-bg.png`

### Step 8 — Composite
→ Skill: `ffmpeg` → `references/portrait-layouts.md` → use `$layout` layout
→ Audio-per-segment: every segment carries synced audio
→ Output: `video/compositing/composite-v1.mp4`

### Step 9 — Post-Processing
→ SFX: `ffmpeg` audio-processing (if `sfx: true`)
→ Captions: burn bottom-center, yellow active word (if `captions: true`)
→ Loudness: -14 LUFS two-pass

### Step 10 — Outro
→ Skill: `studio-production` → append brand outro
→ CFW: `cfw-outro-cta-vertical.mp4` | MGG: `mgg-outro-cta-vertical.mp4`

### Step 11 — Delivery ⛔ CHECKPOINT
→ 12-point checklist → `final/pr-{cat}01-{desc}.mp4`
**Gate: All checks pass.**

### Step 12 — Archive
→ `broll` skill → archive reusable clips → update library
