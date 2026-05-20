---
name: p-banner
description: Social media banner creation pipeline. Creates pixel-perfect banners for YouTube, LinkedIn, or Facebook by rendering HTML files through headless Chrome and compressing to platform specs.
disable-model-invocation: true
argument-hint: "[brand] [platform]"
allowed-tools: Bash, Read, Write
---

# pipeline-banner — Platform Banner Creation


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

HTML → headless Chrome screenshot → compressed platform banner.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| platform | Yes | — | `youtube`, `linkedin`, or `facebook` |
| style | No | brand-ref.md | Visual style notes |

## Platform Specs

| Platform | Full Size | Safe Zone | Max Size |
|----------|-----------|-----------|---------|
| YouTube | 2560x1440 | 1546x423 centered | 6MB |
| LinkedIn | 1584x396 | Full (no safe zone) | 4MB |
| Facebook | 820x312 | Full | 2MB |

## Steps

### Step 1 — Plan Layout

Read `brand-ref.md` for brand colors, fonts, existing banner style.

Design layout:
- Primary message (1–5 words)
- Brand logo position
- Background: gradient, solid, or image
- For YouTube: all key content in safe zone (1546x423 center)

### Step 2 — Create HTML

→ Skill: `c-html-gfx` → HTML banner
→ Font: system stack or Google Fonts CDN
→ `<meta charset="UTF-8">` required
→ Target dimensions match platform full size

### Step 3 — Screenshot

→ Skill: `c-html-gfx` → headless Chrome
→ Window size: `{width}x{height+140}` → crop to exact target
→ Unicode check post-render

### Step 4 — Verify Dimensions

→ ffprobe or `identify` verify: exact pixel dimensions match platform spec

### Step 5 — Compress

→ Skill: `c-ffmpeg` → JPEG `-q:v 2`
→ Verify size under platform limit

### Step 6 — Deliver

→ `final/ls-bnr01-{platform}-{desc}.jpg`

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

