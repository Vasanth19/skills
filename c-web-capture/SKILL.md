---
name: c-web-capture
description: Playwright-based website scroll capture for b-roll video clips. Use for recording smooth-scrolling website pages, discovering URLs for capture targets, and generating square or landscape b-roll from web pages.
when_to_use: Trigger on web capture, website scroll, Playwright capture, website b-roll, scroll recording, URL discovery, page scroll, website clip, web scroll b-roll, capture website, website screenshot video.
allowed-tools: Bash
---

# Web Capture — Playwright Website Scroll B-Roll


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

## Presets

Two presets cover 99% of web scroll b-roll:

| Flag | Resolution | Target Duration | Use For |
|------|------------|-----------------|---------|
| `--short-form` | 1080×1080 (square) | 6.0s hard cap | PIP inside 9:16 Shorts/Reels/TikTok |
| `--long-form` | 1920×1080 (landscape) | 12.0s hard cap | YouTube long-form, VSL, landscape overlays |

Both presets:
- Default 1.2x playback speed
- Auto-compute scroll speed so full page fits in target window
- Trim 2s of leading load frames (vs default 1s)
- Hard-cap final MP4 via ffmpeg `-t` for exact output duration

Override any preset value by also passing the underlying flag (e.g. `--short-form --target-duration 8`).

## Script: `_scripts/capture-website-broll.mjs`

```bash
# Short-form (square, 6s)
node _scripts/capture-website-broll.mjs \
  --url "https://example.com" \
  --output "$PROD/interim/broll/segments/wbst01-homepage.mp4" \
  --short-form

# Long-form (landscape, 12s)
node _scripts/capture-website-broll.mjs \
  --url "https://example.com" \
  --output "$PROD/interim/broll/segments/wbst01-homepage.mp4" \
  --long-form

# Custom duration override
node _scripts/capture-website-broll.mjs \
  --url "https://example.com/pricing" \
  --output "$PROD/interim/broll/segments/wbst02-pricing.mp4" \
  --short-form --target-duration 8
```

## URL Discovery

When capture targets are unknown, discover pages first:

```bash
# Analyze a domain and emit a pages.json for capture
node _scripts/discover-broll-urls.mjs \
  --topic "brand homepage features pricing" \
  --domain "https://example.com" \
  --output "$PROD/interim/broll-plan/pages.json"
```

`pages.json` format:
```json
[
  {"url": "https://example.com", "label": "homepage", "priority": 1},
  {"url": "https://example.com/pricing", "label": "pricing", "priority": 2}
]
```

## Auth Handling

For pages behind login, save auth state first:

```bash
# Interactive auth save (run once, then reuse)
node _scripts/capture-playwright-auth-save.mjs \
  --url "https://app.example.com/login" \
  --storage-state "$HOME/.playwright/example-auth.json"

# Use saved auth for capture
node _scripts/capture-website-broll.mjs \
  --url "https://app.example.com/dashboard" \
  --storage-state "$HOME/.playwright/example-auth.json" \
  --short-form \
  --output "$PROD/interim/broll/segments/app01-dashboard.mp4"
```

## Visual Quality Check

After capture, verify the clip:

```bash
# Check duration and resolution
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,duration \
  -of default=noprint_wrappers=1 "$OUTPUT"

# Preview first frame
ffmpeg -i "$OUTPUT" -vframes 1 -y /tmp/preview.jpg && open /tmp/preview.jpg
```

Reject and recapture if:
- Black frames at start (page didn't load)
- Scroll movement not visible (speed too fast)
- Content cut off at bottom (scroll didn't reach end)

## Output Paths

- Short-form clips: `{production}/interim/broll/segments/sq-wbst{NN}-{desc}.mp4`
- Long-form clips: `{production}/interim/broll/segments/ls-wbst{NN}-{desc}.mp4`
- After delivery, archive to: `{brand_path}/creatives/brolls/recordings/{id}-{desc}.mp4`
- Update `recordings-broll-library.md` with new entry

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

