---
name: demo-to-short-distribution
description: "Use when turning raw demo clips, existing long-form explainer assets, OBS screen recordings, or product walkthrough footage into high-retention short-form videos with a clear hook, value delivery, proof/demo, interactive Remotion B-roll, reused demo clips, captions, optional HyperFrames composition, and explicit CTA."
metadata:
  short-description: Turn demo assets into valuable shorts
---

# Demo to Short Distribution

Use this skill for shorts, reels, TikToks, and vertical clips made from existing demo assets. The goal is not to crop a long video. The goal is to create a new short-form argument using the existing demo clips as proof.

## Core Rule

Do not make a short by simply trimming the final long-form video and adding big text. Reuse demo clips, but create new short-form moments around them:

- Remotion-generated prompt typing
- animated cursor/click/path callouts
- before/after cards
- step counters
- split-screen proof
- highlighted UI regions
- motion captions tied to the narration
- CTA card with a clear keyword or action

Use HyperFrames when the short needs an overall product-video style composition or polished HTML-based scene. Use Remotion for interactive B-roll, timing, text animation, captions, demo inserts, and final vertical rendering.

## Required Structure

Every short must have:

1. Hook: a claim or proof in the first 1-2 seconds.
2. Value: one practical insight, workflow, rule, or repeatable takeaway.
3. Proof: demo clip, generated Remotion simulation, screen recording, or final artifact.
4. CTA: one concrete next action.

If any of these are missing, the short is not ready.

## Workflow

1. Inventory the available assets.
   - List demo clips, final videos, extracted B-roll, voiceover, transcripts, stills, and brand assets.
   - Prefer original demo/B-roll clips over the final long-form export.
   - Use the final long-form only for proof shots when the original B-roll is not available.

2. Pick one idea per short.
   - Do not combine setup, permissions, plugins, rendering, and voiceover into one short.
   - Each short should answer one viewer question or make one viewer believe one thing.

3. Write the short-form beat sheet.
   - Use this sequence: `0-2s hook`, `2-7s setup`, `7-18s value/proof`, `18-25s payoff`, `last 2-4s CTA`.
   - The spoken or on-screen hook must be specific.
   - CTA must be explicit: comment keyword, save this, ask for the setup, or watch the full walkthrough.

4. Create new interactive B-roll in Remotion.
   - If the narration says "I gave one prompt", show a Remotion prompt box with typing.
   - If the narration says "Codex created files", show generated file cards or a folder tree animation, then cut to the real demo clip.
   - If the narration says "plugins", show animated tool chips before the plugin footage.
   - If the narration says "voice upgrade", show waveform/voice model cards before the ElevenLabs clip.
   - Use real demo clips as proof, not as the whole short.

5. Compose vertical video.
   - Default: `1080x1920`, `30fps`.
   - Keep the main proof/demo readable.
   - Use motion to guide attention: cursor, underline, zoom target, highlight box, or step labels.
   - Do not leave the bottom half empty unless it is reserved for CTA or captions.
   - Do not cover important UI with persistent text.

6. Create captions from the final audio.
   - Captions are required for shorts.
   - When generating ElevenLabs audio, read the brand's local config first, especially `.config/brand.yaml` `elevenlabs.voiceId` and `elevenlabs.modelId`.
   - Use the brand-configured ElevenLabs model. For Mr Growth Guide, the default is `eleven_multilingual_v2`; do not substitute `eleven_v3` unless the user explicitly asks for that production.
   - Generate captions from the actual final voiceover, not from the draft script.
   - Save timed captions in `captions/` as composition-ready JSON plus `.srt` or `.vtt` when possible.
   - Use kinetic or motion captions for the hook, value line, proof turn, and CTA.
   - Keep captions to one or two lines and time them to spoken phrases.
   - Put captions in safe areas where they do not hide the demo, cursor, prompt box, or CTA.

7. Render and QA.
   - Render stills for hook, value/proof, and CTA frames before final export.
   - Verify dimensions, duration, frame rate, audio sample rate, audio peak, caption readability, and caption timing.
   - Watch for: missing CTA, weak value, unreadable UI, too much empty space, text overlap, and captions covering proof.
   - Save scripts and delivery checks in the production folder.

## CTA Rules

Good CTAs:

- "Comment CODEX and I will share the prompt."
- "Comment STACK and I will share the setup."
- "Save this before building your next AI workflow."
- "Watch the full walkthrough if you want the exact build."

Weak CTAs:

- "Follow for more."
- "Let me know what you think."
- "This is cool."

## Visual Rules

- Hook should appear before or with the first proof shot.
- Use real demo clips for credibility, but create Remotion overlays that teach the point.
- Prefer short, active overlay copy: "Prompt", "Files", "Voice", "Render".
- For screen recordings, use controlled zooms only when the UI remains readable.
- Use a CTA end card if the final frame does not naturally carry the CTA.

## Caption Rules

- Every short needs burned-in captions unless the user explicitly asks for a no-caption version.
- Captions should teach the point, not transcribe filler.
- The hook caption must be readable with sound off in the first 1-2 seconds.
- Do not use a persistent dimming layer behind captions across the whole short.
- If the caption competes with the demo, shorten it or move it before/after the proof shot.

## Reference

Use `references/patterns.md` for reusable short-form formats and Remotion scene ideas.
