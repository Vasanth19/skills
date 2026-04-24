---
name: pipeline-gfx-batch
description: Batch GFX creation pipeline. Creates multiple HTML infographic overlay graphics from a script, screenshots them pixel-perfectly, and optionally converts to video clips with Ken Burns zoom.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [script-path]"
allowed-tools: Bash, Read, Write
---

# pipeline-gfx-batch — Batch GFX Production

Create multiple GFX overlay graphics from a script in one batch run.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| script_path | Yes | — | Path to script to generate GFX from |
| gfx_dir | Yes | — | Output directory |
| num_graphics | No | auto | Number of GFX (derived from script if not set) |
| size | No | `1920x1080` | `1920x1080` or `1080x1920` |
| make_clips | No | `false` | Also convert each PNG to MP4 |
| clip_duration | No | `5s` | Duration of each clip |
| zoom | No | `1.15x` | Ken Burns zoom for clips |

## Steps

### Step 1 — Plan GFX from Script

Read `$script_path`. Identify `$num_graphics` segments that benefit from visual support:
- Stats, numbers, comparisons → `hero-stat` or `comparison-table`
- Process steps → `pipeline-diagram`
- Costs or tables → `cost-table`
- Single key point → `callout-card`
- Terminal/code → `terminal-sim`

Output plan: `{gfx_dir}/gfx-plan.md` (index, type, content per GFX)

### Step 2 — Create HTML

→ Skill: `html-gfx` → create HTML file for each GFX
→ Dark studio theme, brand color palette
→ `<meta charset="UTF-8">` in every file

### Step 3 — Screenshot (Batch)

→ Skill: `html-gfx` → headless Chrome per file
→ Window: `{width}x{height+140}` → crop to `{width}x{height}`
→ Unicode check after every render

Output: `{gfx_dir}/{N:02d}-{desc}.png`

### Step 4 — Verify

→ ffprobe verify dimensions for each PNG

### Step 5 — Visual Review ⛔ CHECKPOINT

Present all PNGs.
**Gate: User approves or requests changes to specific GFX.**

Iterate on rejected GFX before converting to clips.

### Step 6 — Convert to Clips (if `make_clips: true`)

→ Skill: `ffmpeg` → image-to-clip per PNG
→ Ken Burns: `zoompan=z='min(zoom+0.001,{zoom_val})':d={frames}:s={size}`
→ Duration: `$clip_duration`
→ Output: `{gfx_dir}/{N:02d}-{desc}.mp4`
