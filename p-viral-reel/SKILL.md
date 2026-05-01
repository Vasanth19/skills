---
name: pipeline-viral-reel
description: Viral reel recreation pipeline. Downloads a viral source video, transcribes it, adapts the script to brand voice, and delivers a 9:16 short in the viral format. Two styles — avatar PIP (HeyGen green-screen) or AI-generated (Higgsfield cinematic + Veo talking head).
disable-model-invocation: true
argument-hint: "[brand] [production-name] [source-url] [--style avatar|ai-generated]"
allowed-tools: Bash, Read, Write
---

# pipeline-viral-reel — Viral Reel Recreation

> **`--style ai-generated` BACKEND STALE** — Higgsfield and Veo references in Steps 3 and 5 need updating to current model APIs before use. `--style avatar` (HeyGen green-screen path) is fully current.

Take a viral format → adapt to brand → deliver 9:16 short.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| source_url | Yes | — | YouTube/social URL of viral video |
| style | No | `avatar` | `avatar` (HeyGen PIP) or `ai-generated` (Higgsfield + Veo) |
| section | No | `middle` | `opening`, `middle`, or `full` — which section to adapt |
| cover_style | No | `card-holding` | `card-holding` or `faceless-card` (avatar style only) |
| reference_images | No | — | Brand reference images for Higgsfield (ai-generated style only) |
| cta | No | — | Custom CTA for the end |

---

## Step 1 — Download + Transcribe (both styles)

```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio" \
  --merge-output-format mp4 -o "source.mp4" "$SOURCE_URL"
```
→ Skill: `studio-audio` → MLX Whisper → `interim/audio/source.srt`

Identify viral format type: hook structure, pacing, visual rhythm.

---

## Step 2 — Segment Map / Script Adaptation ⛔ CHECKPOINT

**If `--style avatar`:**
→ Skill: `studio-script` → voice adaptation
→ Match word count ±10% to preserve timing (150 wpm baseline)
→ Apply brand vocabulary, CTA swap, phonetic readiness
→ Output: `interim/scripts/{name}-adapted.txt`

**If `--style ai-generated`:**
Build segment map: `timestamp | description | visual type | replacement plan`

Replacement plan options per segment:
- `higgsfield` — replace with Higgsfield cinematic scene
- `screen-recording` — keep original (if brand-appropriate)
- `veo-talking-head` — replace with Veo talking head clip

**Gate: User approves adapted script (avatar) or segment map (ai-generated).**

---

## Step 3 — Footage Generation

**If `--style avatar`:**

→ Skill: `heygen` → browser render or human delegation
→ Script: adapted `.txt`, background: `#00FF00` solid

→ Skill: `studio-production` → circle PIP detection
→ Identify PIP position in source video (size, center, overlay_diameter at 115%)

→ Cover frame: `html-gfx` → brand card at 1080×1920 (`$cover_style`)

**If `--style ai-generated`:**

For segments marked `higgsfield`:
→ Skill: `ai-media` → Higgsfield Cinema Studio
→ Genre: General, camera: Auto — match segment timing
→ Output: `interim/broll/segments/scene-{N}-higgsfield.mp4`

For segments marked `veo-talking-head`:
→ Skill: `ai-media` → Veo generation, reference brand avatar image
→ Output: `interim/broll/segments/scene-{N}-veo.mp4`

**Gate (ai-generated only): User reviews all generated scenes before assembly.**

---

## Step 4 — TTS Voiceover (avatar style only — if no HeyGen)

→ Skill: `studio-audio` → ElevenLabs TTS
→ `interim/audio/{name}-vo.mp3`

---

## Step 5 — Assembly

**If `--style avatar`:**
→ Skill: `ffmpeg` → composite-split-screen (source top + avatar bottom, or PIP at detected position)
→ Two-pass colorkey: `0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01`

**If `--style ai-generated`:**
→ Skill: `ffmpeg` → vertical concat per segment map order
→ Mux adapted audio from source (or new voiceover)

→ Output: `video/compositing/composite-v1.mp4`

---

## Step 6 — Outro + Delivery ⛔ CHECKPOINT

→ Append brand outro
→ Skill: `ffmpeg` → 12-point delivery checklist
→ Output: `final/pr-viral01-{desc}.mp4`

**Gate: All delivery checks pass.**
