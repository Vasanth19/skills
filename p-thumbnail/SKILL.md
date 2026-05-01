---
name: p-thumbnail
description: YouTube thumbnail production pipeline. Generates multiple thumbnail variants from an avatar frame and topic, presents for user selection, and delivers the winner.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [topic]"
allowed-tools: Bash, Read, Write
---

# pipeline-thumbnail — YouTube Thumbnail

Produces 3 thumbnail variants for user selection. Delivers winner as JPEG < 2MB.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| topic | Yes | — | Video topic (drives headline copy) |
| avatar_frame | Yes | — | Path to PNG avatar frame (face + expression) |
| num_variants | No | `3` | Number of variants to generate |
| style | No | brand-ref.md | Thumbnail style: `text-heavy`, `face-focus`, `split` |

## Steps

### Step 1 — Variant Planning

Read `brand-ref.md` for thumbnail style guide (colors, font, existing CTR data).
Plan `$num_variants` layout variants:
- Variant A: Face left, text right
- Variant B: Full face, text overlay bottom
- Variant C: Split — before/after or comparison

Headline copy: write 3 options (shock, curiosity, result-first) for each variant.

### Step 2 — Generate Thumbnails

→ Skill: `c-html-gfx` → create HTML for each variant (1280x720)
→ Avatar frame embedded as positioned image
→ Dark/bold background matching brand palette
→ Headline: 80px+ bold, high contrast
→ Screenshot: `--window-size=1280,860` → crop to 1280x720
→ Output: `interim/broll/gfx/thumb-{A/B/C}-v1.png`

Unicode check after every screenshot render.

### Step 3 — Compress

→ Skill: `c-ffmpeg` → JPEG compression `-q:v 2`
→ Verify: < 2MB (YouTube limit)
→ Output: `interim/broll/gfx/thumb-{A/B/C}-v1.jpg`

### Step 4 — User Picks Winner ⛔ CHECKPOINT

Present all variants.
**Gate: User selects winner (or requests iteration).**

If iteration: adjust copy/layout → repeat Steps 2–3 for that variant only.

### Step 5 — Deliver

→ Copy winner to: `final/ls-tnail01-{topic-slug}.jpg`
→ Verify dimensions: 1280x720, < 2MB
