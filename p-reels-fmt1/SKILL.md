---
name: p-reels-fmt1
description: Make a vertical reel from a recorded video plus b-roll clips the user supplies. Trigger on "make a reel from my footage", "cut my video with brolls into a reel", "edit my recorded clip into a vertical short", "composite my video with b-roll".
when-to-use: Use when the user already has a recorded main video AND one or more b-roll clips, and wants them composited/edited into a single vertical (9:16) reel.
version: 0.1.0
kind: pipeline
visibility: catalog
produces:
  dish: Footage Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [main_video, broll_clips]
dependsOn: [c-ffmpeg, c-broll]
---

# p-reels-fmt1 — Manual Video + B-Rolls → Vertical Reel

## Status

**SCAFFOLD — NOT YET VERIFIED.** This pipeline has never been run end-to-end. No assets, no
rendered output, no parameter table. It needs the inputs/config in the TODO section wired up
before it can produce anything. Do not claim it works.

## Inputs

- `main_video` — the user's recorded primary footage (any aspect; will be normalized to 9:16).
- `broll_clips[]` — one or more b-roll video clips the user supplies.
- `placement_plan` (optional) — where each b-roll cut goes on the timeline; if absent, derive a
  simple sequential plan (b-roll over the main clip at fixed intervals or at user-marked beats).
- `target_duration` (optional) — desired reel length; default to the main video's length.

## Steps

1. **Normalize main video** — `c-ffmpeg`: scale/crop `main_video` to 1080×1920 (9:16), fix fps,
   normalize audio loudness (loudnorm).
2. **Plan b-roll placement** — `c-broll`: build a placement plan matching `broll_clips[]` to
   timeline segments of the main video (sequential or user-marked cut points).
3. **Prep b-roll clips** — `c-ffmpeg`: scale/crop each b-roll clip to the same 9:16 canvas; trim
   to its planned segment length.
4. **Composite / cut** — `c-ffmpeg`: assemble the timeline — overlay or hard-cut b-roll segments
   onto the main video per the placement plan; crossfade transitions between cuts.
5. **Mix audio** — `c-ffmpeg`: keep the main video's voice track as the bed; duck/mute b-roll
   audio under it.
6. **Encode + verify** — `c-ffmpeg`: export final 9:16 MP4; ffprobe verify dimensions, duration,
   audio presence.

## Output

One 9:16 (1080×1920) MP4 reel: the user's recorded video as the spine with their b-roll clips
cut/overlaid in, single voice bed, transitions between segments.

## TODO before production

- Define the b-roll placement contract: does the user supply explicit cut timecodes, or does the
  pipeline auto-place? `c-broll` placement-plan format needs to be pinned for *user-supplied*
  (not library) clips.
- Decide overlay vs. hard-cut default for b-roll (PIP overlay or full-frame replacement).
- Confirm `c-ffmpeg` transition/crossfade params and the canvas/background spec for portrait
  letterboxing of landscape source clips.
- No render has been done — validate end-to-end on a real `main_video` + `broll_clips[]` set.
