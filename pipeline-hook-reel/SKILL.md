---
name: pipeline-hook-reel
description: Hook-jacked reel production pipeline. Takes a 4-7s hook clip from a famous creator, adds brand continuation (avatar or GFX), and stitches into a 9:16 short. The creator's hook audio is NEVER speed-adjusted.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [hook-source-url]"
allowed-tools: Bash, Read, Write
---

# pipeline-hook-reel — Hook-Jacked Reel (9:16)

Viral hook + brand continuation format. Creator's hook clip is the scroll-stop; brand picks up from there.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| hook_url | Yes | — | YouTube/social URL for hook source |
| hook_start | Yes | — | Start time in source (e.g., `0:04`) |
| hook_end | Yes | — | End time in source (e.g., `0:10`) |
| continuation_style | No | `avatar` | `avatar` or `gfx` |
| layout | No | `bottom-avatar` | Portrait layout for continuation |

## Steps

### Step 1 — Hook Extraction ⛔ CHECKPOINT
→ Skill: `studio-production` → hook extract
→ Download with yt-dlp (windowed: `hook_start` to `hook_end`)
→ Extract punch-point clip (4–7s only)
→ NEVER speed-adjust hook — creator's voice stays natural
→ Output: `interim/broll/segments/hook-clip.mp4`

**Gate: User verifies clean audio cut and visual quality.**

### Step 2 — Continuation Script ⛔ CHECKPOINT
→ Skill: `studio-script` → short-form continuation (picks up from hook's implied promise)
→ Duration: 30–45s (to keep total < 60s)
→ Hook's final line becomes the bridge into continuation
**Gate: User approves script.**

### Step 3 — Continuation Production
Delegate to sub-pipeline based on `$continuation_style`:

**If `avatar`:** Follow `pipeline-avatar-short` steps 2–9 (skip script/outro steps)
**If `gfx`:** Follow `pipeline-gfx-short` steps 2–9 (skip script/outro steps)

Output: `video/compositing/continuation-v1.mp4`

### Step 4 — Stitch Assembly
→ Skill: `ffmpeg` → `studio-production` separate-tracks-mux
1. Extract audio tracks separately (hook + continuation)
2. Concat audio independently
3. Concat video independently
4. Mux together
→ This prevents rogue audio artifacts from mixed codec concat
→ Output: `video/compositing/stitched-v1.mp4`

### Step 5 — Outro
→ `studio-production` → append brand outro

### Step 6 — Delivery ⛔ CHECKPOINT
→ 12-point checklist → `final/pr-hook01-{desc}.mp4`
**Gate: All checks pass.**

### Step 7 — Archive
→ `broll` skill → archive reusable continuation assets
