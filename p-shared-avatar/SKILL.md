---
name: p-shared-avatar
description: Shared avatar render pipeline. Renders ONE HeyGen green-screen video from combined TTS scripts (longform + multiple shorts), then maps SRT timecodes back to each script. Reduces HeyGen credit usage by batching all renders into one video.
disable-model-invocation: true
argument-hint: "[brand] [scripts...]"
allowed-tools: Bash, Read, Write
---

# pipeline-shared-avatar — Shared Avatar Render

One HeyGen render, many productions. Combine all TTS scripts → render once → split by timecode.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| scripts | Yes | — | Array of TTS-clean `.txt` paths (combined in order) |
| production_name | Yes | — | Folder name for the shared render |
| speed | No | `1.0` | Speed multiplier applied after download |
| avatar_name | No | brand-ref.md | Avatar ID |

## Steps

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

Each downstream production (p-vsl, p-avatar-short) can now reference:
- `source_video`: path to shared render
- SRT window: the mapped timecode range for their segment
