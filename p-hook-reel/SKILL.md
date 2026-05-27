---
name: p-hook-reel
description: Hook-jacked reel production pipeline. Takes a 4-7s hook clip from a famous creator, adds brand continuation (avatar or GFX), and stitches into a 9:16 short. The creator's hook audio is NEVER speed-adjusted.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [hook-source-url]"
allowed-tools: Bash, Read, Write
kind: pipeline
visibility: catalog
produces:
  dish: Hook-Jacked Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [hook_source_url, script]
dependsOn: [c-script, c-broll, c-production, c-ffmpeg]
---

# pipeline-hook-reel — Hook-Jacked Reel (9:16)


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

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
→ Skill: `c-production` → hook extract
→ Download with yt-dlp (windowed: `hook_start` to `hook_end`)
→ Extract punch-point clip (4–7s only)
→ NEVER speed-adjust hook — creator's voice stays natural
→ Output: `interim/broll/segments/hook-clip.mp4`

**Gate: User verifies clean audio cut and visual quality.**

### Step 2 — Continuation Script ⛔ CHECKPOINT
→ Skill: `c-script` → short-form continuation (picks up from hook's implied promise)
→ Duration: 30–45s (to keep total < 60s)
→ Hook's final line becomes the bridge into continuation
**Gate: User approves script.**

### Step 3 — Continuation Production
Delegate to sub-pipeline based on `$continuation_style`:

**If `avatar`:** Follow `pipeline-avatar-short` steps 2–9 (skip script/outro steps)
**If `gfx`:** Follow `pipeline-gfx-short` steps 2–9 (skip script/outro steps)

Output: `video/compositing/continuation-v1.mp4`

### Step 4 — Stitch Assembly
→ Skill: `c-ffmpeg` → `c-production` separate-tracks-mux
1. Extract audio tracks separately (hook + continuation)
2. Concat audio independently
3. Concat video independently
4. Mux together
→ This prevents rogue audio artifacts from mixed codec concat
→ Output: `video/compositing/stitched-v1.mp4`

### Step 5 — Outro
→ `c-production` → append brand outro

### Step 6 — Delivery ⛔ CHECKPOINT
→ 12-point checklist → `final/pr-hook01-{desc}.mp4`
**Gate: All checks pass.**

### Step 7 — Archive
→ `c-broll` skill → archive reusable continuation assets

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

