---
name: pipeline-snap-bg-swap
description: Finger-snap background swap reel pipeline. Detects snap points in audio, composites the avatar on alternating backgrounds, and assembles a viral snap-transition format short.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [source-video]"
allowed-tools: Bash, Read, Write
---

# pipeline-snap-bg-swap — Snap Background Swap Reel

Viral format: avatar snaps fingers → background changes. Each snap = new scene.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| source_video | Yes | — | Green-screen avatar video with snap audio |
| bg_images | No | — | Array of background image paths (auto-generated if empty) |
| num_snaps | No | auto-detect | Override snap count |
| format | No | `9:16` | `9:16` or `16:9` |

## Steps

### Step 1 — Snap Detection ⛔ CHECKPOINT

→ Skill: `studio-production` → snap point detection
→ Audio peak analysis (RMS threshold 0.7, min gap 0.5s, 50ms chunks)
→ Returns list of timestamps (seconds)
→ Output: `interim/broll-plan/snap-points.json`

**Gate: User verifies snap count and timestamps. Adjust threshold if too many/few detected.**

### Step 2 — Background Selection ⛔ CHECKPOINT

If `$bg_images` provided: use them.
If not:
→ Skill: `ai-media` → generate `num_snaps + 1` contextual backgrounds
→ Each bg: different color palette / scene / mood
→ Brand-consistent style from `brand-ref.md`
→ Output: `interim/broll/gfx/bg-{N}.png`

**Gate: User approves backgrounds.**

### Step 3 — Segment Composite

For each snap interval (snap[N] to snap[N+1]):
→ Skill: `ffmpeg` → colorkey composite
→ Two-pass: `colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01`
→ Overlay avatar on `bg-{N}.png`
→ Trim to interval duration
→ Output: `interim/video/compositing/seg-{N}.mp4`

Final segment: snap[last] to end of video → `bg-{N+1}.png`

### Step 4 — Concat

→ Skill: `ffmpeg` → concat all segments (codec copy if same params)
→ Output: `video/compositing/snap-bg-swap-v1.mp4`

### Step 5 — Verify

→ ffprobe verify → confirm dimensions, duration, codec

### Step 6 — Delivery ⛔ CHECKPOINT

→ `final/pr-snap01-{desc}.mp4` (portrait) or `final/ls-snap01-{desc}.mp4` (landscape)
**Gate: User reviews snap transitions.**
