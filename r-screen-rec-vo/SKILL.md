---
name: r-screen-rec-vo
description: "Produce one 9:16 Short with full-frame Remotion screen-rec (no avatar PIP). Avatar is VO-only — HeyGen render's audio is extracted and used as the VO track. Sahil-format adaptation."
---

# r-screen-rec-vo

> Produces one 9:16 YouTube Short with a full-frame Remotion screen-rec (no avatar PIP). The avatar is voiceover-only — its HeyGen render's audio is extracted and used as the VO track. Intended for "Sahil-style" prompt-on-screen reveals, UI walkthroughs, or any reel where the brand deliberately breaks the talking-head pattern.

**Brand:** Mr Growth Guide (B-GROWTHGUIDE) — Sahil-format adaptation recipe
**Paperclip ticket:** VAS-52 (first production using this recipe)
**Sibling recipes:** `r-bottom-avatar-pip` (default MGG Shorts), `r-alternating-visual` (tutorial alternating cuts)

## Sub-documents

| File | Contents |
|---|---|
| [`brand-params.md`](brand-params.md) | MGG-specific parameter table + pipeline overview diagram |
| [`pipeline.md`](pipeline.md) | Step-by-step (Steps 1-9) |
| [`scene-bank.md`](scene-bank.md) | 7 reusable Remotion scenes with frame budgets |
| [`anti-patterns.md`](anti-patterns.md) | What NOT to do + known gotchas |
| [`acceptance.md`](acceptance.md) | Definition of Done + CMO handoff notes |

## When to Use

Pick `r-screen-rec-vo` when:
- The reel is a prompt-on-screen reveal (typing into Claude/ChatGPT UI live) — visual payload is the prompt + result, not the creator's face
- Brand deliberately wants face-off-camera to vary the algo grid
- Creator's voice is still the anchor (no stock VO) — HeyGen render's audio carries
- Duration target: 35-50s (Sahil-strict is 15-30s; MGG's denser voice lands 40-50s, acceptable)

**Do NOT use if** the reel needs visible face reactions, hand gestures, or on-camera delivery. Use `r-bottom-avatar-pip` for those or for news-jacks.

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `script` | Yes | — | Full script for HeyGen VO render |
| `speedMultiplier` | No | `1.25` | atempo multiplier; raw HeyGen usually 50-55s → 1.25× lands 40-44s |
| `targetDuration` | No | 35-46s | Final duration window (not including outro ~5s) |
| `avatarLookId` | No | from `brand.yaml` | Override preferred avatar |
| `voiceId` | No | from `brand.yaml` | Override brand voice |

## Output

- **Canvas:** 1080×1920 (9:16 portrait), 30fps
- **Layout:** Full-frame Remotion scenes, no PIP safe-zone reserved
- **Audio:** Speed-adjusted HeyGen VO, loudnorm'd to -16 LUFS
- **Final file:** `creatives/productions/MM.DD-<title>/final/short.mp4`
- **Cover:** `final/cover.png` (mid-beat frame — money shot, not the Hook scene)
