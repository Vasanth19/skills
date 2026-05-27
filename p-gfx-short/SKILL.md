---
name: p-gfx-short
description: Faceless GFX short production pipeline. Produces a 9:16 short with ElevenLabs voiceover narration, HTML infographic GFX cards, Ken Burns zoom, captions, and brand outro. No avatar required.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [topic]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: catalog
produces:
  dish: Faceless GFX Short
  format: 9:16 vertical video
  duration: 30-60s
inputs: [topic]
dependsOn: [c-script, c-audio, c-html-gfx, c-production, c-ffmpeg]
---

# pipeline-gfx-short — Faceless GFX Short (9:16)


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

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
→ Skill: `c-script` → short-form (75–150 words)
→ Hook styles: pattern-interrupt, math-hook, result-first
→ TTS preprocess → `interim/scripts/{name}-tts.txt`
**Gate: User approves script.**

### Step 2 — Voiceover
→ Skill: `c-audio` → ElevenLabs via Floe API
→ Voice: `$voice_id` (from brand-ref.md if not specified)
→ Output: `interim/audio/{name}-vo.mp3`

### Step 3 — Transcription
→ Skill: `c-audio` → MLX Whisper on voiceover
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
→ `c-production` → append brand outro

### Step 10 — Delivery ⛔ CHECKPOINT
→ 12-point checklist → `final/pr-gfx01-{desc}.mp4`
**Gate: All checks pass.**

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

