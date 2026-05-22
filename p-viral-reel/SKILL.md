---
name: p-viral-reel
description: Viral reel recreation pipeline. Downloads a viral source video, transcribes it, adapts the script to brand voice, and delivers a 9:16 short in the viral format. Two styles — avatar PIP (HeyGen green-screen) or AI-generated (Higgsfield cinematic + Veo talking head).
disable-model-invocation: true
argument-hint: "[brand] [production-name] [source-url] [--style avatar|ai-generated]"
allowed-tools: Bash, Read, Write
---

# p-viral-reel — Viral Reel Recreation


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

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
→ Skill: `c-studio-audio` → MLX Whisper → `interim/audio/source.srt`

Identify viral format type: hook structure, pacing, visual rhythm.

---

## Step 2 — Segment Map / Script Adaptation ⛔ CHECKPOINT

**If `--style avatar`:**
→ Skill: `c-studio-script` → voice adaptation
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

→ Skill: `t-heygen` → browser render or human delegation
→ Script: adapted `.txt`, background: `#00FF00` solid

→ Skill: `c-studio-production` → circle PIP detection
→ Identify PIP position in source video (size, center, overlay_diameter at 115%)

→ Cover frame: `c-html-gfx` → brand card at 1080×1920 (`$cover_style`)

**If `--style ai-generated`:**

For segments marked `higgsfield`:
→ Skill: `c-ai-media` → Higgsfield Cinema Studio
→ Genre: General, camera: Auto — match segment timing
→ Output: `interim/broll/segments/scene-{N}-higgsfield.mp4`

For segments marked `veo-talking-head`:
→ Skill: `c-ai-media` → Veo generation, reference brand avatar image
→ Output: `interim/broll/segments/scene-{N}-veo.mp4`

**Gate (ai-generated only): User reviews all generated scenes before assembly.**

---

## Step 4 — TTS Voiceover (avatar style only — if no HeyGen)

→ Skill: `c-studio-audio` → ElevenLabs TTS
→ `interim/audio/{name}-vo.mp3`

---

## Step 5 — Assembly

**If `--style avatar`:**
→ Skill: `c-ffmpeg` → composite-split-screen (source top + avatar bottom, or PIP at detected position)
→ Two-pass colorkey: `0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01`

**If `--style ai-generated`:**
→ Skill: `c-ffmpeg` → vertical concat per segment map order
→ Mux adapted audio from source (or new voiceover)

→ Output: `video/compositing/composite-v1.mp4`

---

## Step 6 — Outro + Delivery ⛔ CHECKPOINT

→ Append brand outro
→ Skill: `c-ffmpeg` → 12-point delivery checklist
→ Output: `final/pr-viral01-{desc}.mp4`

**Gate: All delivery checks pass.**

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

