---
name: pipeline-linkedin-carousel
description: LinkedIn carousel PDF pipeline. Writes slide content, generates AI images per slide, assembles into a PDF carousel, and drafts the LinkedIn caption copy.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [topic]"
allowed-tools: Bash, Read, Write
---

# pipeline-linkedin-carousel — LinkedIn PDF Carousel

Produces a LinkedIn-optimized carousel PDF with AI images and caption copy.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| topic | Yes | — | Carousel topic / hook |
| num_slides | No | `7` | Number of slides (cover + content + CTA) |
| style | No | `whiteboard` | `whiteboard` or `corporate` |
| aspect_ratio | No | `4:5` | `4:5` or `1:1` |

## Steps

### Step 1 — Outline ⛔ CHECKPOINT

Write carousel outline:
- Slide 1: Cover (hook headline)
- Slides 2–N-1: Content (one insight per slide, progressive reveal)
- Slide N: CTA (follow + offer)

Headline copy: short, scroll-stopping, value-front.
**Gate: User approves outline.**

### Step 2 — Slide Content

Write full copy for each slide:
- Headline: ≤8 words
- Body: 2–3 sentences max
- Visual cue: what image/graphic supports this slide

### Step 3 — AI Image Generation ⛔ CHECKPOINT

→ Skill: `ai-media` → read `brand-ref.md` first
→ Generate one image per slide based on visual cue
→ Style: `$style` (whiteboard/corporate)
→ Aspect: `$aspect_ratio`
→ Output: `interim/broll/gfx/slide-{N}.png`

**Gate: User reviews all slide images.**

Regenerate any rejected images before PDF assembly.

### Step 4 — PDF Assembly

→ ImageMagick: combine text overlay + AI image per slide
```bash
for N in $(seq 1 $num_slides); do
  convert -size {W}x{H} xc:white \
    slide-{N}.png -geometry +0+0 -composite \
    -font "brand-font.ttf" -pointsize 48 \
    -draw "text 60,80 '{headline}'" \
    -pointsize 28 -draw "text 60,160 '{body}'" \
    slide-{N}-final.png
done

# Combine to PDF
convert slide-*.png carousel.pdf
```
→ Output: `final/sq-carousel01-{topic-slug}.pdf`

### Step 5 — LinkedIn Caption

→ Skill: `studio-script` → write LinkedIn post copy:
- Hook line (matches cover slide)
- Tease slides 2–3 (don't give it all away)
- CTA: "Save this + follow for more"
- 3–5 relevant hashtags

### Step 6 — Deliver ⛔ CHECKPOINT

Deliver: PDF + caption `.txt`
**Gate: User approves caption before scheduling.**
