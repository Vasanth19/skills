---
name: p-avatar-short
description: Avatar-based 9:16 short production pipeline. Produces a portrait short with chroma-keyed avatar, b-roll overlay, captions, SFX, and brand outro. Supports individual render per production OR shared batch render across multiple productions to save HeyGen credits.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [--shared-render scripts...] [--source-video path] [layout?]"
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
| shared_render | No | — | Array of TTS-clean `.txt` paths for batch render |
| layout | No | `bottom-avatar` | Portrait layout: `bottom-avatar`, `split-broll`, `pip-broll`, `split-equal`, `popout` |
| speed | No | — | TTS speed multiplier |
| num_images | No | `4` | AI images to generate |
| num_gfx | No | `3` | HTML GFX cards |
| captions | No | `true` | Burn captions |
| sfx | No | `false` | Include SFX |

## Mode A: Individual Render (Default)

### Step 1 — Script ⛔ CHECKPOINT
→ Skill: `c-studio-script` → short-form (75–150 words, 30–60s)
→ TTS preprocess → `interim/scripts/{name}-tts.txt`
**Gate: User approves script.**

### Step 2 — Avatar Render ⛔ CHECKPOINT
If `source_video` provided: skip.
→ Skill: `c-heygen` → browser render, `#00FF00` background
**Gate: User triggers render, provides job ID.**

### Step 3 — Poll & Download
→ Skill: `c-heygen` → Floe API poll (60s)
→ Download → `interim/video/base/{name}-green-screen.mp4`
→ Verify green screen
→ If `speed` set: apply speed adjust

### Step 4 — Transcription
→ Skill: `c-studio-audio` → MLX Whisper
→ Output SRT → `interim/audio/{name}.srt`

### Step 5 — B-Roll Planning ⛔ CHECKPOINT
→ Skill: `c-broll` → check library → match to script → portrait placement plan
→ Use SRT timecodes. Layout: `$layout`.
→ Guard: ≥4 unique assets, ≥80% coverage, ≤6s per PIP segment.
**Gate: User reviews plan.**

### Step 6 — Asset Generation
→ AI images: `c-ai-media` → `brolls/images/` (read `brand-ref.md` first)
→ GFX cards: `c-html-gfx` → `interim/broll/gfx/`
→ Website scroll: `c-web-capture` (if in plan) → `interim/broll/segments/`

### Step 7 — Contextual Background
→ Skill: `c-ai-media` → contextual bg for avatar segments
→ `interim/video/base/{name}-bg.png`

### Step 8 — Composite
→ Skill: `c-ffmpeg` → `references/portrait-layouts.md` → use `$layout` layout
→ Audio-per-segment: every segment carries synced audio
→ Output: `video/compositing/composite-v1.mp4`

### Step 9 — Post-Processing
→ SFX: `c-ffmpeg` audio-processing (if `sfx: true`)
→ Captions: burn bottom-center, yellow active word (if `captions: true`)
→ Loudness: -14 LUFS two-pass

### Step 10 — Outro
→ Skill: `c-studio-production` → append brand outro
→ CFW: `cfw-outro-cta-vertical.mp4` | MGG: `mgg-outro-cta-vertical.mp4`

### Step 11 — Delivery ⛔ CHECKPOINT
→ 12-point checklist → `final/pr-{cat}01-{desc}.mp4`
**Gate: All checks pass.**

### Step 12 — Archive
→ `c-broll` skill → archive reusable clips → update library

---

## Mode B: Shared Render (Credit Saver)

One HeyGen render, many productions. Combine all TTS scripts → render once → split by timecode.

### Step 1 — Combine TTS
Concatenate all `$scripts` into one combined TTS-clean file with spacer lines between segments.
Mark segment boundaries: `[SEGMENT: {script_name}]`
→ Output: `interim/scripts/combined-tts.txt`

Verify total word count and estimated duration:
- Duration = word_count / 2.5 words/second
- HeyGen limit: ~10 min per render; split if needed

### Step 2 — Preprocess
→ Skill: `c-studio-script` → TTS preprocessing pass on combined script
→ Verify: no markdown, no stage directions, no abbreviations, clean sentences

### Step 3 — HeyGen Render ⛔ CHECKPOINT
→ Skill: `c-heygen` → browser render path
→ Background: `#00FF00` solid
→ Submit combined-tts.txt as ONE render

**Gate: User manually triggers render and confirms job ID.**

### Step 4 — Poll & Download
→ Skill: `c-heygen` → Floe API poll (60s, up to 30 attempts — long renders take 15-20 min)
→ Download → `interim/video/base/shared-render-green-screen.mp4`
→ Verify output (dimensions, codec, duration)

### Step 5 — Green Screen Verify
→ Skill: `c-heygen` → verify green screen quality
→ Confirm `#00FF00` background throughout
→ Generate contextual background for avatar segments

### Step 6 — Speed Adjust (if `speed != 1.0`)
→ Skill: `c-ffmpeg` → apply speed: `setpts + atempo`
→ Output: `interim/video/base/shared-render-{speed}x.mp4`

### Step 7 — Transcription + Segment Mapping
→ Skill: `c-studio-audio` → MLX Whisper on the avatar's audio
→ Output: `interim/audio/shared-render.srt`

Parse SRT to find timecode boundaries for each `[SEGMENT: ...]` marker.
Build segment map:

| Script | SRT Start | SRT End | Duration |
|--------|-----------|---------|---------|
| script-a.txt | 00:00:00 | 00:02:34 | 154s |
| script-b.txt | 00:02:36 | 00:03:58 | 82s |

Save to: `interim/broll-plan/segment-map.md`

Each downstream production can now reference:
- `source_video`: path to shared render
- SRT window: the mapped timecode range for their segment

### Step 8 — Per-Production Assembly
For each production in the batch:
→ Use the mapped SRT window to cut the shared render
→ Follow Mode A Steps 5–12 (b-roll planning → composite → delivery)
