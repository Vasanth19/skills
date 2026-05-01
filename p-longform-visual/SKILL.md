---
name: pipeline-longform-visual
description: Longform visual composite pipeline. Produces a tutorial/walkthrough video with layered visuals: Remotion GFX, HTML explainer slides, demo screen recordings, and optional avatar PIP. Designed for YouTube-format educational content.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [main-video]"
allowed-tools: Bash, Read, Write
---

# pipeline-longform-visual — Longform Visual Composite

Educational/tutorial video: main recording + Remotion GFX + HTML slides + demo footage.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| main_video | Yes | — | Path to main recording (talking head or screen) |
| demo_video | No | — | Path to supplementary demo recording |
| demo_trim | No | — | Trim range for demo: `start-end` |
| script_topic | Yes | — | Topic (drives GFX and slides content) |

## Steps

### Step 1 — Transcribe + Section Map ⛔ CHECKPOINT

→ Skill: `studio-audio` → MLX Whisper on `$main_video`
→ Output: `interim/audio/main.srt`

Analyze SRT → build section map:
| Section | Start | End | Type | Visual Plan |
|---------|-------|-----|------|-------------|
| Intro | 00:00 | 00:30 | talking-head | None |
| Concept 1 | 00:30 | 02:00 | screen | Remotion diagram |
| Demo | 02:00 | 04:30 | demo-recording | Side-by-side |

**Gate: User approves section map.**

### Step 2 — Process Videos

→ Skill: `ffmpeg` → scale main video to square (1:1) if needed
→ If `$demo_video`: trim to `$demo_trim`, normalize codec
→ Output: `interim/video/base/main-scaled.mp4`, `interim/video/base/demo-trimmed.mp4`

### Step 3 — Design Remotion Compositions ⛔ CHECKPOINT

For each section marked `Remotion diagram`:
→ Skill: `html-gfx` → Remotion component design (TSX + Tailwind)
→ Composition type: animated diagram, stat reveal, step progression

**Gate: User approves Remotion composition designs.**

### Step 4 — Build HTML Slides

For conceptual sections:
→ Skill: `html-gfx` → animated explainer slides
→ Progressive reveal, Poppins font, one idea per slide

### Step 5 — Render Remotion

→ Skill: `html-gfx` → Remotion render
→ Shared Chromium: `$REMOTION_BROWSER_EXECUTABLE`
→ `npm ci --omit=optional` first
→ Output: `interim/broll/gfx/{composition}.mp4`

### Step 6 — GFX Clips (Extend to Section Duration)

If Remotion clip shorter than section: freeze-frame extend:
```bash
# Freeze last frame for remaining duration
ffmpeg -i remotion-clip.mp4 -vf "tpad=stop_mode=clone:stop_duration={extra}s" \
  -c:v libx264 -c:a aac -y extended-clip.mp4
```

### Step 7 — Stitch Composite ⛔ CHECKPOINT

→ Skill: `ffmpeg` → assemble per section map:
- Talking-head sections: main video as-is
- Demo sections: side-by-side (`vstack` or `hstack`)
- GFX sections: overlay or replace video track

→ Output: `video/compositing/composite-v1.mp4`

**Gate: User reviews first composite before final post-processing.**

### Step 8 — Deliver

→ Loudness: -14 LUFS → `final/ls-tutorial01-{desc}.mp4`
