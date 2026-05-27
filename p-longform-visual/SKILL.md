---
name: p-longform-visual
description: Longform visual composite pipeline. Produces a tutorial/walkthrough video with layered visuals: Remotion GFX, HTML explainer slides, demo screen recordings, and optional avatar PIP. Designed for YouTube-format educational content.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [main-video]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: catalog
produces:
  dish: Longform Visual
  format: 16:9 video
  duration: 5-20 min
inputs: [main_video]
dependsOn: [c-audio, c-html-gfx, c-ffmpeg, f-remotion]
---

# pipeline-longform-visual — Longform Visual Composite


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

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

→ Skill: `c-audio` → MLX Whisper on `$main_video`
→ Output: `interim/audio/main.srt`

Analyze SRT → build section map:
| Section | Start | End | Type | Visual Plan |
|---------|-------|-----|------|-------------|
| Intro | 00:00 | 00:30 | talking-head | None |
| Concept 1 | 00:30 | 02:00 | screen | Remotion diagram |
| Demo | 02:00 | 04:30 | demo-recording | Side-by-side |

**Gate: User approves section map.**

### Step 2 — Process Videos

→ Skill: `c-ffmpeg` → scale main video to square (1:1) if needed
→ If `$demo_video`: trim to `$demo_trim`, normalize codec
→ Output: `interim/video/base/main-scaled.mp4`, `interim/video/base/demo-trimmed.mp4`

### Step 3 — Design Remotion Compositions ⛔ CHECKPOINT

For each section marked `Remotion diagram`:
→ Skill: `c-html-gfx` → Remotion component design (TSX + Tailwind)
→ Composition type: animated diagram, stat reveal, step progression

**Gate: User approves Remotion composition designs.**

### Step 4 — Build HTML Slides

For conceptual sections:
→ Skill: `c-html-gfx` → animated explainer slides
→ Progressive reveal, Poppins font, one idea per slide

### Step 5 — Render Remotion

→ Skill: `c-html-gfx` → Remotion render
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

→ Skill: `c-ffmpeg` → assemble per section map:
- Talking-head sections: main video as-is
- Demo sections: side-by-side (`vstack` or `hstack`)
- GFX sections: overlay or replace video track

→ Output: `video/compositing/composite-v1.mp4`

**Gate: User reviews first composite before final post-processing.**

### Step 8 — Deliver

→ Loudness: -14 LUFS → `final/ls-tutorial01-{desc}.mp4`

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

