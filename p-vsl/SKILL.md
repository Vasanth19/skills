---
name: p-vsl
description: Full VSL longform production pipeline. Produces one 16:9 landscape video with avatar PIP, b-roll overlay, SFX, captions, and loudness normalization. Orchestrates script → HeyGen → transcription → b-roll plan → GFX → composite → delivery.
disable-model-invocation: true
argument-hint: "[brand] [production-name]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: catalog
produces:
  dish: VSL
  format: 16:9 video
  duration: 5-20 min
inputs: [script]
dependsOn: [c-script, t-heygen, c-broll, c-html-gfx, c-audio, c-production, c-ffmpeg, c-ai-media]
---

# p-vsl — VSL Longform Production


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

Produces a 16:9 landscape VSL with avatar PIP composite, b-roll overlay, SFX, and captions.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug (e.g., `cfw-social`, `mr-growth-guide`) |
| production_name | Yes | — | Folder name under `productions/` |
| script | Yes | — | Path to `.txt` TTS-clean script OR path to draft `.md` |
| source_video | No | — | Existing green-screen render to reuse (skips HeyGen) |
| speed | No | `1.0` | TTS speed multiplier (1.0–1.25) |
| broll_coverage | No | `80%` | Minimum b-roll coverage target |
| num_images | No | `4` | AI images to generate |
| num_gfx | No | `6` | HTML GFX cards to create |
| sfx | No | `true` | Include SFX mix |
| captions | No | `false` | Burn word-level captions |

## Setup

Read brand path from `~/.gsai/ecosystem.yaml`. Create production folder:
```
{brand_path}/creatives/productions/{production_name}/
  interim/scripts/ audio/ c-broll/segments/ c-broll/gfx/ broll-plan/
  video/base/ video/compositing/
  final/
```

---

## Step 1 — Script ⛔ CHECKPOINT

If `script` points to a draft `.md`: present to user for approval before proceeding.
If `.txt` TTS-clean already: skip approval, confirm word count and estimated duration.

→ Skill: `c-script` (duration calc, TTS preprocessing if needed)
→ Save TTS-clean to: `interim/scripts/{name}-tts.txt`

**Gate: User approves script before render.**

---

## Step 2 — Avatar Render ⛔ CHECKPOINT

If `source_video` provided: skip to Step 3.

→ Skill: `t-heygen` → browser render path
→ Script: full TTS-clean script, one render
→ Background: `#00FF00` solid

**Gate: User manually triggers HeyGen render and confirms job ID.**

---

## Step 3 — Poll & Download

→ Skill: `t-heygen` → poll via Floe API (60s interval)
→ Download to: `interim/video/base/{name}-green-screen.mp4`
→ Verify green screen quality

If `speed != 1.0`: apply speed adjust → `interim/video/base/{name}-green-screen-{speed}x.mp4`

---

## Step 4 — Transcription

→ Skill: `c-audio` → MLX Whisper
→ Input: downloaded avatar audio (or extracted audio from green-screen MP4)
→ Output: `interim/audio/{name}.srt` + `.txt`

**SRT is ground truth for all b-roll timecodes.**

---

## Step 5 — B-Roll Planning ⛔ CHECKPOINT

→ Skill: `c-broll` → check library first, match to script
→ Use SRT timecodes for all segment boundaries
→ Create landscape PIP placement plan
→ Every row has: timecode | Speaker Says | Layout | B-Roll File | Zoom

Check library for reusable assets before generating anything new.
Plan quality guard: ≥4 unique assets, ≥80% b-roll coverage.

**Gate: User reviews b-roll plan and approves before generating assets.**

---

## Step 6 — Asset Generation

Run in parallel where possible:

**6a. AI Images** (if needed):
→ Skill: `c-ai-media` → read `brand-ref.md` first → generate `num_images` images
→ Output: `{brand_path}/creatives/brolls/images/`

**6b. HTML GFX Cards**:
→ Skill: `c-html-gfx` → dark studio theme, `num_gfx` cards matching script segments
→ Screenshot to PNG, convert to 5s clips with 1.15x Ken Burns
→ Output: `interim/broll/gfx/`

**6c. Website Scroll** (if in plan):
→ Skill: `c-broll` → long-form preset (1920x1080, 12s)
→ Output: `interim/broll/segments/`

---

## Step 7 — Contextual Background

→ Skill: `c-ai-media` → generate contextual background matching brand/topic
→ Save to: `interim/video/base/{name}-bg.png`

---

## Step 8 — Composite

→ Skill: `c-ffmpeg` → `references/landscape-pip.md`
1. Pre-render: avatar on background → `video/base/avatar-on-bg.mp4` (with `-g 25`)
2. Build segment list per b-roll plan (AVATAR FULL / PIP / FULLSCREEN)
3. Each segment carries its own synced audio
4. Concat all segments → `video/compositing/composite-v1.mp4`
5. Verify output (ffprobe)

If verify fails: fix and recomposite before proceeding.

---

## Step 9 — Post-Processing

**9a. SFX Mix** (if `sfx: true`):
→ Skill: `c-ffmpeg` → `references/audio-processing.md`
→ Check SFX library first → mix at -18 dB moderate

**9b. Loudness Normalize**:
→ Two-pass volume adjust → -14 LUFS

**9c. Captions** (if `captions: true`):
→ Burn word-level captions from SRT → top-center, yellow active word

---

## Step 10 — Delivery ⛔ CHECKPOINT

→ Skill: `c-production` → run 12-point delivery checklist
→ Name final: `ls-{category}01-{description}.mp4` → copy to `final/`

**Gate: All 12 checks pass. User reviews final before marking done.**

---

## Step 11 — Archive

→ Skill: `c-broll` → archive reusable clips from `interim/broll/` to `{brand_path}/creatives/brolls/`
→ Update relevant library `.md` files
→ Run `/deliver` to mark production complete

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

