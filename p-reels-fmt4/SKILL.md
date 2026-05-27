---
name: p-reels-fmt4
description: Turn a script into a fully rendered explainer reel with no talking head — animation plus voiceover only. Trigger on "make an explainer reel from this script", "faceless animated short with VO", "no-avatar explainer video", "script to animated reel with voiceover".
when-to-use: Use when the user wants a faceless explainer reel — animation/motion graphics with a voiceover, NO talking-head avatar.
version: 0.1.0
kind: pipeline
visibility: catalog
produces:
  dish: Faceless Explainer Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script]
dependsOn: [c-script, f-remotion, c-audio, c-ffmpeg]
---

# p-reels-fmt4 — Script → Explainer Reel (No Talking Head)

## Status

**SCAFFOLD — NOT YET VERIFIED.** Never run end-to-end. No assets, no rendered output, no Remotion
project scaffolded. The VO generation and animation render paths are unconfigured. Do not claim
it works.

## Inputs

- `topic` or `script` — the source idea or a full script. If only a topic, generate the script.
- `voice` (optional) — VO voice id for `c-audio` (ElevenLabs via Floe).
- `style` (optional) — visual/animation style for the explainer.
- `target_duration` (optional) — desired reel length.

## Steps

1. **Write / clean script** — `c-script`: produce a short-form explainer script (or clean
   a supplied one); estimate duration; TTS-preprocess.
2. **Generate voiceover** — `c-audio`: TTS the script to a VO track; normalize loudness;
   (optionally) get word/segment timings for caption + animation sync.
3. **Build animation** — `f-remotion`: author the explainer compositions (motion graphics, title
   cards, transitions), 9:16, synced to the VO timings.
4. **Render animation** — `f-remotion`: render the compositions to video (or per-scene clips).
5. **Mux VO + captions** — `c-ffmpeg`: lay the VO track under the rendered animation; burn
   captions synced to the VO.
6. **Assemble + encode** — `c-ffmpeg`: concat scenes, crossfade transitions; export 9:16 MP4;
   ffprobe verify dimensions/duration/audio.

## Output

One 9:16 (1080×1920) MP4 faceless explainer reel: fully rendered animation with a generated
voiceover and synced captions — no talking head.

## TODO before production

- Scaffold the Remotion project (compositions, fps, scene durations, animation style) — none
  exists yet. Decide whether `f-hyperframes` is an acceptable alternate renderer.
- Pin the VO ↔ animation sync contract: does `c-audio` emit word/segment timings that
  `f-remotion` consumes for on-screen text/animation timing?
- `c-audio` TTS config (voice id, ElevenLabs/Floe access) must be set.
- Define the default explainer visual style (templates, palette, typography).
- No render done — validate end-to-end before production.
