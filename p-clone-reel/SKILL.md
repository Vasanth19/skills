---
name: p-clone-reel
description: Clone-a-viral pipeline — adapt a winning viral video into your brand voice on your topic. Downloads a viral source video, transcribes it, adapts the script to brand voice, and delivers a 9:16 short in the viral format using an avatar PIP (HeyGen green-screen).
disable-model-invocation: true
argument-hint: "[brand] [production-name] [source-url]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: catalog
providers: heygen, elevenlabs
produces:
  dish: Viral Reel Recreation
  format: 9:16 vertical video
  duration: 30-60s
inputs: [source_url]
dependsOn: [c-script, c-heygen, c-html-gfx, c-audio, c-production, c-ffmpeg]
---

# p-clone-reel — Viral Reel Recreation


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Take a viral format → adapt to brand → deliver 9:16 short (avatar PIP).

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| source_url | Yes | — | YouTube/social URL of viral video |
| section | No | `middle` | `opening`, `middle`, or `full` — which section to adapt |
| cover_style | No | `card-holding` | `card-holding` or `faceless-card` |
| cta | No | — | Custom CTA for the end |

---

## Step 1 — Download + Transcribe

```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio" \
  --merge-output-format mp4 -o "source.mp4" "$SOURCE_URL"
```
→ Skill: `c-audio` → MLX Whisper → `interim/audio/source.srt`

Identify viral format type: hook structure, pacing, visual rhythm.

---

## Step 2 — Script Adaptation ⛔ CHECKPOINT

→ Skill: `c-script` → voice adaptation
→ Match word count ±10% to preserve timing (150 wpm baseline)
→ Apply brand vocabulary, CTA swap, phonetic readiness
→ Output: `interim/scripts/{name}-adapted.txt`

**Gate: User approves adapted script.**

---

## Step 3 — Footage Generation

→ Skill: `c-heygen` → browser render or human delegation
→ Script: adapted `.txt`, background: `#00FF00` solid

→ Skill: `c-production` → circle PIP detection
→ Identify PIP position in source video (size, center, overlay_diameter at 115%)

→ Cover frame: `c-html-gfx` → brand card at 1080×1920 (`$cover_style`)

---

## Step 4 — TTS Voiceover (if no HeyGen)

→ Skill: `c-audio` → ElevenLabs TTS
→ `interim/audio/{name}-vo.mp3`

---

## Step 5 — Assembly

→ Skill: `c-ffmpeg` → composite-split-screen (source top + avatar bottom, or PIP at detected position)
→ Two-pass colorkey: `0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01`

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
