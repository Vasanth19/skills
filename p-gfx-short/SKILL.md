---
name: p-gfx-short
description: Faceless GFX short production pipeline. Produces a 9:16 short with ElevenLabs voiceover narration, HTML infographic GFX cards, Ken Burns zoom, captions, and brand outro. No avatar required.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [topic]"
allowed-tools: Bash, Read, Write
---

# pipeline-gfx-short — Faceless GFX Short (9:16)

Produces a faceless portrait short: voiceover + HTML GFX cards + Ken Burns motion.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| topic | Yes | — | Topic/hook for the short |
| script | No | — | Existing script path (skips writing) |
| voice_id | No | brand-ref.md | ElevenLabs voice ID |
| num_scenes | No | `5` | Number of GFX scenes |
| speed | No | `1.0` | Playback speed |
| duration_target | No | `45-60s` | Target duration |
| sfx | No | `false` | Include SFX |
| captions | No | `true` | Burn captions |

## Steps

### Step 1 — Script ⛔ CHECKPOINT
→ Skill: `c-studio-script` → short-form (75–150 words)
→ Hook styles: pattern-interrupt, math-hook, result-first
→ TTS preprocess → `interim/scripts/{name}-tts.txt`
**Gate: User approves script.**

### Step 2 — Voiceover
→ Skill: `c-studio-audio` → ElevenLabs via Floe API
→ Voice: `$voice_id` (from brand-ref.md if not specified)
→ Output: `interim/audio/{name}-vo.mp3`

### Step 3 — Transcription
→ Skill: `c-studio-audio` → MLX Whisper on voiceover
→ Output: `interim/audio/{name}.srt`

### Step 4 — Scene Planning ⛔ CHECKPOINT
Plan `$num_scenes` GFX scenes timed to SRT segments.
Each scene: GFX type | content | timecode window

GFX types (dark studio theme): `hero-stat`, `callout-card`, `pipeline-diagram`, `comparison-table`, `cost-table`
**Gate: User approves scene plan.**

### Step 5 — GFX Creation
→ Skill: `c-html-gfx` → create HTML for each scene
→ Screenshot via headless Chrome (1080x1920 window → 1080x1920 viewport)
→ Unicode check after every render
→ Output: `interim/broll/gfx/{N}-{desc}.png`

### Step 6 — Image-to-Clip ⛔ CHECKPOINT
→ Skill: `c-ffmpeg` → `zoompan` 1.15x Ken Burns per clip
→ Duration: match SRT window for each scene
→ Output: `interim/broll/gfx/{N}-{desc}.mp4`
**Gate: User reviews clips before concat.**

### Step 7 — Concat with Voiceover
→ Skill: `c-ffmpeg` → concat all GFX clips → mux with voiceover
→ Output: `video/compositing/composite-v1.mp4`

### Step 8 — Post-Processing
→ Speed: `ffmpeg setpts + atempo` (if `speed != 1.0`)
→ SFX: (if `sfx: true`) → check sfx-library first
→ Captions: bottom-center, yellow active word (if `captions: true`)
→ Loudness: -14 LUFS two-pass

### Step 9 — Outro
→ `c-studio-production` → append brand outro

### Step 10 — Delivery ⛔ CHECKPOINT
→ 12-point checklist → `final/pr-gfx01-{desc}.mp4`
**Gate: All checks pass.**
