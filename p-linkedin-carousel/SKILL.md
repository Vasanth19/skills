---
name: p-linkedin-carousel
description: LinkedIn carousel PDF pipeline. Writes slide content, generates AI images per slide, assembles into a PDF carousel, and drafts the LinkedIn caption copy.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [topic]"
allowed-tools: Bash, Read, Write
---

# pipeline-linkedin-carousel — LinkedIn PDF Carousel


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

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

→ Skill: `c-ai-media` → read `brand-ref.md` first
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

→ Skill: `c-studio-script` → write LinkedIn post copy:
- Hook line (matches cover slide)
- Tease slides 2–3 (don't give it all away)
- CTA: "Save this + follow for more"
- 3–5 relevant hashtags

### Step 6 — Deliver ⛔ CHECKPOINT

Deliver: PDF + caption `.txt`
**Gate: User approves caption before scheduling.**

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

