---
name: pipeline-viral-reel
description: Viral reel recreation pipeline. Downloads a viral source video, transcribes it, adapts the script to brand voice, renders avatar PIP composite, and delivers a 9:16 short in the viral format.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [source-url]"
allowed-tools: Bash, Read, Write
---

# pipeline-viral-reel — Viral Reel Recreation

Take a viral format → adapt to brand → deliver with avatar PIP.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| source_url | Yes | — | YouTube/social URL of viral video |
| section | No | `middle` | `opening`, `middle`, or `full` — which section to adapt |
| cover_style | No | `card-holding` | `card-holding` or `faceless-card` |
| cta | No | — | Custom CTA for the end |

## Steps

### Step 1 — Download + Transcribe

```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio" \
  --merge-output-format mp4 -o "source.mp4" "$SOURCE_URL"
```
→ Skill: `studio-audio` → MLX Whisper → `interim/audio/source.srt`

Identify viral format type: hook structure, pacing, visual rhythm.

### Step 2 — PIP Detection

→ Skill: `studio-production` → circle PIP detection
→ Identify if source has PIP element (size, position)
→ Returns: center_x, center_y, diameter, overlay_diameter (115% for coverage)

### Step 3 — Script Adaptation ⛔ CHECKPOINT

→ Skill: `studio-script` → voice adaptation
→ Match word count ±10% to preserve timing (150 wpm baseline)
→ Apply brand vocabulary, CTA swap, phonetic readiness
→ Output: `interim/scripts/{name}-adapted.txt`

**Gate: User approves adapted script.**

### Step 4 — Avatar Render

→ Skill: `heygen` → browser render or human delegation
→ Script: adapted `.txt`
→ Background: `#00FF00` solid

### Step 5 — TTS Voiceover (if no avatar)

→ Skill: `studio-audio` → ElevenLabs TTS
→ `interim/audio/{name}-vo.mp3`

### Step 6 — Cover Frame

Generate `cover_style` thumbnail from avatar frame.
→ Skill: `html-gfx` → brand card design at 1080x1920

### Step 7 — Split-Screen Composite

→ Skill: `ffmpeg` → composite-split-screen
→ Source video (top) + avatar (bottom) or PIP overlay at detected position
→ Output: `video/compositing/composite-v1.mp4`

### Step 8 — Outro + Delivery ⛔ CHECKPOINT

→ Append brand outro
→ 12-point checklist → `final/pr-viral01-{desc}.mp4`
**Gate: All checks pass.**
