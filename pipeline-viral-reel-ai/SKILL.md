---
name: pipeline-viral-reel-ai
description: AI tool viral reel recreator pipeline. Downloads an AI tool demo viral video, builds a segment map, generates new cinematic scenes with Higgsfield, overlays a Veo talking head, and delivers a 9:16 short in the same viral format.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [source-url]"
allowed-tools: Bash, Read, Write
---

# pipeline-viral-reel-ai — AI Tool Viral Reel (Higgsfield + Veo)

Recreate AI tool demo reels with brand cinematic footage + talking head.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug (default: `mr-growth-guide`) |
| production_name | Yes | — | Folder name |
| source_url | Yes | — | Viral AI tool demo URL |
| cta | No | — | Custom CTA |
| reference_images | No | — | Brand reference images for Higgsfield |

## Steps

### Step 1 — Download + Analyze

```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio" \
  --merge-output-format mp4 -o "source.mp4" "$SOURCE_URL"
```
→ Skill: `studio-audio` → MLX Whisper → `interim/audio/source.srt`

Analyze: identify the AI tool being shown, demo flow, key moments, hook.

### Step 2 — Segment Map ⛔ CHECKPOINT

Build segment map: timestamp | description | visual type | replacement plan

Replacement plan options:
- `higgsfield`: replace with Higgsfield cinematic scene
- `screen-recording`: keep original (if brand-appropriate)
- `veo-talking-head`: replace with Veo talking head clip

**Gate: User approves segment map.**

### Step 3 — Higgsfield Scenes

For each segment marked `higgsfield`:
→ Skill: `ai-media` → Higgsfield Cinema Studio
→ Genre: General, camera: Auto
→ Duration: match segment timing
→ Output: `interim/broll/segments/scene-{N}-higgsfield.mp4`

### Step 4 — Veo Talking Head

For segments marked `veo-talking-head`:
→ Skill: `ai-media` → Veo generation
→ Reference brand avatar image
→ Match script timing
→ Output: `interim/broll/segments/scene-{N}-veo.mp4`

**Gate: User provides Veo talking head if required.**

### Step 5 — Assembly

→ Skill: `ffmpeg` → composite-split-screen or vertical concat
→ Assemble per segment map order
→ Mux audio from source (adapted) or new voiceover
→ Output: `video/compositing/composite-v1.mp4`

### Step 6 — Outro + Delivery ⛔ CHECKPOINT

→ Append brand outro
→ 12-point checklist → `final/pr-viral01-{desc}.mp4`
**Gate: User reviews final.**
