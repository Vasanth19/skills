---
name: c-gfx-batch
description: Batch GFX creation pipeline. Creates multiple HTML infographic overlay graphics from a script, screenshots them pixel-perfectly, and optionally converts to video clips with Ken Burns zoom.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [script-path]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: internal
dependsOn: [c-ffmpeg, c-html-gfx]
---

# pipeline-gfx-batch — Batch GFX Production


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

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

→ Skill: `c-html-gfx` → create HTML file for each GFX
→ Dark studio theme, brand color palette
→ `<meta charset="UTF-8">` in every file

### Step 3 — Screenshot (Batch)

→ Skill: `c-html-gfx` → headless Chrome per file
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

→ Skill: `c-ffmpeg` → image-to-clip per PNG
→ Ken Burns: `zoompan=z='min(zoom+0.001,{zoom_val})':d={frames}:s={size}`
→ Duration: `$clip_duration`
→ Output: `{gfx_dir}/{N:02d}-{desc}.mp4`

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

