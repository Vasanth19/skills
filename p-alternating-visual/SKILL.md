---
name: p-alternating-visual
description: "Produce one 9:16 Short with alternating segments: avatar talking → Remotion/NanoBanana visual → avatar → visual → avatar → outro. MGG tutorial/explainer recipe."
kind: pipeline
visibility: catalog
providers: heygen, kie
produces:
  dish: Alternating-Visual Short
  format: 9:16 vertical video
  duration: 30-40s
inputs: [script]
dependsOn: [c-heygen, f-remotion, c-ai-media, c-ffmpeg]
---

# p-alternating-visual

> Produces one 9:16 Short (or 16:9 long-form) with alternating segments: avatar talking → visual (Remotion or NanoBanana image) → avatar → visual → avatar → outro.

**Brand:** Mr Growth Guide (B-GROWTHGUIDE) — tutorial/explainer recipe
**Paperclip ticket:** VAS-8
**Sibling recipes:** `p-bottom-avatar-pip` (default PIP-over-broll Shorts), `p-screen-rec-vo` (no-face VO-only)

## Sub-documents

| File | Contents |
|---|---|
| [`segments.md`](segments.md) | 6-segment pattern table + HeyGen render notes |
| [`pipeline.md`](pipeline.md) | Full skill sequence (steps 1-17) |
| [`heygen-workflow.md`](heygen-workflow.md) | HeyGen mode decision (human / mcp / api) |
| [`acceptance.md`](acceptance.md) | Definition of Done checklist |

## When to Use

- Tutorial breakdowns where the avatar explains, then cuts to graphics/screenshots/AI-gen images, then back to avatar
- Step-by-step walkthroughs with visual evidence per step
- Duration: 30-40s

## Before You Start

1. Read `CLAUDE.md` + `.config/brand.yaml` — brand identity, voice, avatar/voice IDs, b-roll policy
2. Confirm HeyGen browser session is logged in on `app.heygen.com`
3. On first run per machine: `npx remotion install-browser` (Remotion needs Chrome for Testing)

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `script` | Yes | — | Full script; will be split into 3 HeyGen chunks |
| `segment4Type` | No | `nanobanana` | `remotion` or `nanobanana` for the second visual segment |
| `avatarLookId` | No | from `brand.yaml` | Override preferred avatar |
| `voiceId` | No | from `brand.yaml` | Override brand voice |
| `targetDuration` | No | 35s | Typical 30-40s |

## Output

- **Canvas:** 1080×1920 (9:16 default; configurable to 1920×1080 for long-form)
- **Duration:** 30-40s (6 segments)
- **Final file:** `creatives/productions/MM.DD-<title>/final/short.mp4`

## Dependencies

- `nanobanana-image-gen` — wraps `mcp__mcp-image__generate_image` (Gemini). Saves PNG to `production/gfx/nano/`.
- `remotion-render` — renders via `@remotion/cli`. Scaffold from `creative-studio/_scratch/gsai-test-20s-clip/` on first use.
- Remotion needs Chrome for Testing: `npx remotion install-browser` once per machine.
