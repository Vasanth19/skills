---
name: r-bottom-avatar-pip
description: "Produce one 9:16 YouTube Short: b-roll full-frame on dark-navy canvas, brand avatar chroma-keyed as a 540×540 rounded PIP pinned flush to the bottom. Default MGG Shorts recipe."
---

# r-bottom-avatar-pip

> Produces one 9:16 YouTube Short with b-roll centered vertically on a dark-navy canvas and the brand avatar chroma-keyed, full-width (1080px), pinned flush to the bottom edge of the canvas.

**Brand:** Mr Growth Guide (B-GROWTHGUIDE) — default Shorts recipe
**Paperclip ticket:** VAS-7
**Sibling recipes:** `r-alternating-visual` (tutorial alternating cuts), `r-screen-rec-vo` (no-face VO-only)

## Sub-documents

| File | Contents |
|---|---|
| [`brand-params.md`](brand-params.md) | MGG-specific parameter table — canvas color, avatar speed, PIP spec, outro path |
| [`pipeline.md`](pipeline.md) | Full 24-step skill sequence |
| [`heygen-workflow.md`](heygen-workflow.md) | HeyGen mode decision table (human / mcp / api) |
| [`first-frame-rule.md`](first-frame-rule.md) | Cover-prepend canonical spec + verification commands |
| [`acceptance.md`](acceptance.md) | Definition of Done checklist |

## When to Use

- Order type: `shorts` with avatar voiceover
- Visual walkthrough where b-roll (screen recordings, AI-gen clips, images) is the primary focus
- Avatar needed throughout for voice + face continuity
- Duration: 20s ±2s

## Before You Start

1. Read `.config/brand.yaml` — avatar look ID, voice ID, defaults
2. Read `creatives/brolls/<theme>-broll-library.md` — available clips, status, zoom policy
3. Confirm runtime has `mcp__heygen__*` tools OR `HEYGEN_API_KEY` for autonomous render; otherwise falls to `heygen-request-human`

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `script` | Yes | — | Write for effective post-speed duration (20s target × 1.1x → script targets 22s natural-pace) |
| `brollTheme` | No | `ai` | Folder under `creatives/brolls/` |
| `avatarLookId` | No | from `brand.yaml` | Override preferred avatar |
| `voiceId` | No | from `brand.yaml` | Override brand voice |
| `targetDuration` | No | 20s | ±2s tolerance, AFTER speed adjustment |
| `speed` | No | **1.1** | Never `1.0` for MGG without explicit override |

## Output

- **Canvas:** 1080×1920 (9:16 portrait)
- **Layout:** b-roll fills full canvas (safe zone y=0–1380), avatar PIP 540×540 rounded flush bottom-center
- **Final file:** `creatives/productions/MM.DD-<title>/final/short.mp4`

## Reference Render

VAS-7 (2026-04-17): `creatives/productions/ord-20260417-003-vas7-recipe2-e2e/final/short-pip-natural.mp4`

## To adapt for another brand

Copy `.claude/skills/r-bottom-avatar-pip/` into `vasanth-hq/<brand>/.claude/skills/r-bottom-avatar-pip/`, update `brand-params.md`, change "Brand:" line in this file.
