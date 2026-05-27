---
name: p-reels-fmt2
description: Make a vertical reel from b-roll plus a HeyGen talking-head avatar, composited as a bottom picture-in-picture. Trigger on "make a reel with an avatar over brolls", "brolls with a talking head PIP", "HeyGen avatar reel with b-roll background", "bottom-avatar short".
when-to-use: Use when the user wants b-roll media as the background and a HeyGen-generated talking head as a picture-in-picture overlay in a vertical (9:16) reel.
version: 0.1.0
kind: pipeline
visibility: catalog
dependsOn: t-heygen, c-ffmpeg, c-broll
---

# p-reels-fmt2 — B-Rolls + HeyGen Talking Head → PIP Vertical Reel

## Status

**SCAFFOLD — NOT YET VERIFIED as a standalone pipeline.** This is the **closest to working** of
the four formats: a bottom-avatar PIP recipe already runs end-to-end on Fly today
(`r-bottom-avatar-pip` and the upload variant `r-bottom-avatar-pip-upload`). Those use **ffmpeg
b-roll PIP — NOT Remotion** — and should be the implementation basis for this format. This
scaffold has not itself been wired up or rendered; treat it as a draft that wraps the proven
recipe. Do not claim it works until validated.

## Inputs

- `broll_media[]` — b-roll clips and/or AI-generated stills for the full-frame background.
- `script` or `avatar_video` — either a script to drive a HeyGen render, or (upload variant) a
  talking-head video the user already has.
- `avatar_config` — HeyGen avatar id / voice (green-screen render for chroma key).
- `pip_spec` (optional) — PIP size/position; default to the proven bottom-center placement.

## Steps

1. **Render / receive talking head** — `t-heygen`: render a green-screen avatar from the script
   (or, upload variant, take the user's uploaded talking-head video as the PIP source).
2. **Plan + assemble b-roll background** — `c-broll` + `c-ffmpeg`: beat-plan the b-roll to the
   script/transcript, assemble a 9:16 background (stills with Ken Burns + crossfades, or clips).
3. **Chroma-key the avatar** — `c-ffmpeg`: green-screen key the HeyGen render; crop/scale to the
   PIP size (the proven recipe uses a rounded bottom-pinned PIP).
4. **Composite PIP over background** — `c-ffmpeg`: overlay the keyed avatar onto the b-roll
   background, pinned flush bottom-center.
5. **Captions + audio** — `c-ffmpeg`: burn captions; use the avatar's voice as the audio bed.
6. **Encode + verify** — `c-ffmpeg`: export 9:16 MP4; ffprobe verify.

## Output

One 9:16 (1080×1920) MP4 reel: b-roll background with a chroma-keyed HeyGen talking head as a
bottom picture-in-picture, captions burned in.

## TODO before production

- Decide: does this format SUBSUME the existing `r-bottom-avatar-pip` recipes, or wrap/delegate
  to them? If wrapping, this pipeline should call into that recipe rather than re-implement the
  ffmpeg PIP composite.
- Pin the PIP spec (size, rounding, position) — copy from the working recipe's `brand-params.md`.
- HeyGen rendering needs API/MCP/human-delegation config (`t-heygen` mode decision table).
- Confirm whether the default is HeyGen-rendered avatar (`r-bottom-avatar-pip`) or user-uploaded
  talking head (`r-bottom-avatar-pip-upload`) — they have different first steps.
- Not validated as a distinct skill — render once against real inputs before production.
