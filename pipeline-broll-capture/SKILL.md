---
name: pipeline-broll-capture
description: Website b-roll capture pipeline. Discovers scroll-worthy URLs for a topic, captures them with Playwright scroll automation, verifies quality, and registers clips in the brand b-roll library.
disable-model-invocation: true
argument-hint: "[brand] [topic-or-urls...]"
allowed-tools: Bash, Read, Write
---

# pipeline-broll-capture — Website B-Roll Capture

Capture website scroll recordings → add to brand b-roll library.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| topic | No | — | Topic to discover URLs for |
| urls | No | — | Explicit URLs (overrides discovery) |
| mode | No | `short-form` | `short-form` (1080x1080, 6s) or `long-form` (1920x1080, 12s) |
| prefix | No | auto | Clip ID prefix (e.g., `wbst`) |

## Steps

### Step 1 — URL Discovery

If `$urls` provided: skip discovery.
If `$topic` provided:
→ Skill: `web-capture` → discover 2–4 canonical URLs:
  - Announcement/blog post
  - GitHub repo (if technical)
  - Product page
  - Docs page

Quality filter: visually interesting, publicly accessible, no loading spinners above fold.
→ Output: `interim/broll-plan/pages.json`

### Step 2 — Capture

→ Skill: `web-capture` → Playwright scroll capture
→ Mode: `$mode` preset
→ Input: `pages.json` (multi-URL) or single URL
→ Output: `interim/broll/segments/{prefix}{NN}-{label}.mp4`

Settings: 1.2x playback speed, 2s trim-start (4s with preset).

### Step 3 — Visual Quality Check

For each captured clip:
1. No loading spinners in first 2 frames
2. Content fully rendered (no skeleton/placeholder)
3. Scroll motion smooth (no jumps)
4. Correct aspect ratio for mode

If quality fails: recapture with `--wait` flag or longer trim-start.

### Step 4 — Verify

→ Skill: `ffmpeg` → ffprobe verify each clip (dimensions, duration, codec)

### Step 5 — Library Update

→ Skill: `broll` → add each clip to `recordings-broll-library.md`:
  - ID: `wbst{NN}` (next available number)
  - File: `recordings/{prefix}{NN}-{label}.mp4`
  - Zoom: `none`
  - Status: `Created`
  - Source: production name

→ Copy clips to: `{brand_path}/creatives/brolls/recordings/`
