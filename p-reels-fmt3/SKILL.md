---
name: p-reels-fmt3
description: Turn a topic or script into a full vertical reel combining a HeyGen talking head with Remotion or HyperFrames b-roll/animation. Trigger on "make a full reel from this topic", "script to talking-head reel with brolls", "generate an avatar video with animated b-roll", "full produced short from a script".
when-to-use: Use when the user gives a topic or script and wants a complete reel assembled from a HeyGen talking head PLUS rendered b-roll/animation (Remotion and/or HyperFrames).
version: 0.1.0
kind: pipeline
visibility: catalog
dependsOn: c-studio-script, t-heygen, f-remotion, f-hyperframes, c-ffmpeg
---

# p-reels-fmt3 — Script → Full Video (Talking Head + B-Rolls) → Reel

## Status

**SCAFFOLD — NOT YET VERIFIED.** Never run end-to-end. No assets, no rendered output. The
Remotion/HyperFrames b-roll rendering path and the HeyGen avatar render are both unconfigured
here. Do not claim it works.

## Inputs

- `topic` or `script` — the source idea or a full script. If only a topic, generate the script.
- `avatar_config` — HeyGen avatar id / voice.
- `style` (optional) — b-roll rendering preference: Remotion (`f-remotion`), HyperFrames
  (`f-hyperframes`), or a mix.
- `target_duration` (optional) — desired reel length.

## Steps

1. **Write / clean script** — `c-studio-script`: produce a short-form script from the topic (or
   clean a supplied script); extract hook; TTS-preprocess for HeyGen.
2. **Render talking head** — `t-heygen`: green-screen avatar render driven by the script.
3. **Render b-roll / animation** — `f-remotion` and/or `f-hyperframes`: build animated b-roll
   segments (title cards, motion graphics, captions) keyed to the script beats. Pick one renderer
   or mix per `style`.
4. **Chroma-key + size avatar** — `c-ffmpeg`: green-screen key the avatar; size it for its layout
   (full-frame intervals or PIP over the animated b-roll — decide in TODO).
5. **Assemble timeline** — `c-ffmpeg`: interleave talking-head segments with the rendered b-roll
   per the script's beat plan; crossfade transitions.
6. **Audio + captions + encode** — `c-ffmpeg`: avatar voice as bed; burn captions; export 9:16
   MP4; ffprobe verify.

## Output

One 9:16 (1080×1920) MP4 reel: a HeyGen talking head intercut/composited with Remotion- and/or
HyperFrames-rendered animated b-roll, driven by a generated or supplied script.

## TODO before production

- Decide the renderer default: Remotion (`f-remotion`) vs HyperFrames (`f-hyperframes`) for b-roll
  — and define how a "mix" is split. They are different toolchains.
- Define the layout: talking head full-frame intercut with b-roll, or avatar PIP over animated
  b-roll throughout (or both, per beat).
- HeyGen render config (`t-heygen` mode table) + Remotion/HyperFrames project scaffolding
  (compositions, fps, durations) are not set up.
- Define the beat-plan contract that maps script segments → avatar vs b-roll vs animation.
- No render done — validate end-to-end before production.
