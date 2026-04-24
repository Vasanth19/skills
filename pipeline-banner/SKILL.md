---
name: pipeline-banner
description: Social media banner creation pipeline. Creates pixel-perfect banners for YouTube, LinkedIn, or Facebook by rendering HTML files through headless Chrome and compressing to platform specs.
disable-model-invocation: true
argument-hint: "[brand] [platform]"
allowed-tools: Bash, Read, Write
---

# pipeline-banner — Platform Banner Creation

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

→ Skill: `html-gfx` → HTML banner
→ Font: system stack or Google Fonts CDN
→ `<meta charset="UTF-8">` required
→ Target dimensions match platform full size

### Step 3 — Screenshot

→ Skill: `html-gfx` → headless Chrome
→ Window size: `{width}x{height+140}` → crop to exact target
→ Unicode check post-render

### Step 4 — Verify Dimensions

→ ffprobe or `identify` verify: exact pixel dimensions match platform spec

### Step 5 — Compress

→ Skill: `ffmpeg` → JPEG `-q:v 2`
→ Verify size under platform limit

### Step 6 — Deliver

→ `final/ls-bnr01-{platform}-{desc}.jpg`
