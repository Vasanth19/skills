---
name: demo-to-long-distribution
description: "Use when converting raw screen recordings, OBS demos, rough voice explanations, product walkthroughs, or long-form demo footage into a complete long-form distribution asset: YouTube explainer, transcript, hook/value/CTA structure, B-roll map, ElevenLabs voiceover, captions, HyperFrames or Remotion composition, final render, speed-adjusted export, and delivery QA."
metadata:
  short-description: Turn raw demos into polished long-form videos
---

# Demo to Long Distribution

Use this skill when a raw demo needs to become a polished long-form explainer or product walkthrough. The job is not just to edit footage. The job is to turn rough proof into a coherent story with voice, B-roll, captions, render checks, and delivery-ready exports.

## Default Output

Create a production folder with:

- `script/`: full transcript, clean TTS script, narration timing, caption script
- `audio/`: ElevenLabs outputs and model logs
- `captions/`: timed caption files such as `.srt`, `.vtt`, and composition-ready JSON
- `broll/` or `segments/`: extracted clips with timestamp notes
- `renders/`: HyperFrames or Remotion project
- `interim/`: still checks and temporary exports
- `final/`: master, requested speed-adjusted final, thumbnails
- `logs/`: transcript, generation logs, delivery checklist

## Workflow

1. Read local project instructions first.
   - Read `AGENTS.md`, `CLAUDE.md`, brand guidelines, and creative director instructions the user mentions.
   - If the repo says to use a project/task system, note whether the current request maps to an issue. Continue unless the user asks for governance work first.

2. Analyze the source material.
   - Inspect source duration, dimensions, audio, and obvious visual sections.
   - Transcribe voiceover with MLX Whisper when available.
   - Create a B-roll inventory from the source video: timestamp, file name, visual content, and likely narration fit.
   - Extract B-roll clips only where they support the story.

3. Write the long-form story before editing.
   - Use a direct hook, value delivery, proof/demo, build process, and CTA.
   - The hook must say what the viewer gets, not just describe the tool.
   - Prefer founder/operator language for Mr Growth Guide: practical, specific, first-person, no hype.
   - Create a clean TTS script and a visual beat map before generating the final voiceover.

4. Generate voiceover intentionally.
   - Use ElevenLabs only when the user asks or the workflow requires TTS.
   - Read the brand's local config first when available, especially `.config/brand.yaml` `elevenlabs.voiceId` and `elevenlabs.modelId`.
   - Read the API key from the configured local secrets file, but never print the key.
   - Use the brand-configured ElevenLabs model. For Mr Growth Guide, the default is `eleven_multilingual_v2`; do not substitute `eleven_v3` unless the user explicitly asks for that production.
   - Save a generation log with at least `voice_id`, `model_id`, output path, and byte count.
   - After generation, run MLX transcription on the actual final voiceover and retime visual scenes to that transcript.

5. Create captions from the final audio.
   - Generate captions from the actual final voiceover, not from the draft script.
   - Save timed captions in `captions/` as composition-ready JSON plus `.srt` or `.vtt` when possible.
   - For long-form videos, use selective burned-in captions by default: hook, section turns, key claims, important terms, and CTA.
   - Use full burned-in captions only when the user requests them or the platform/version needs them.
   - Keep captions away from important UI. Do not stack captions on top of callouts or persistent overlays.

6. Compose the video.
   - Use HyperFrames for HTML-based product-video scenes, animated text, and polished visual sections.
   - Use Remotion for editorial composition, B-roll sequencing, captions/callouts, audio sync, speed changes, and export control.
   - Keep overlays short. Do not dim B-roll continuously while narration is explaining the screen.
   - Put callouts in the top-right unless the screen content requires another safe area.
   - For screen-recording B-roll, default to a quick punch-in up to `1.2x`, then settle back near full-frame immediately. Do not crop away important UI.
   - Use stronger zooms only when the frame has been visually checked and the important UI remains visible.

7. Render and verify.
   - Render the master first.
   - Apply requested final speed changes after the master render.
   - Verify final dimensions, frame rate, duration, audio sample rate, audio peak, first-frame brightness, and caption readability.
   - Save still checks for risky sections: hook, plugin settings, folder sections, product proof, captions, and CTA.
   - Watch the sections where narration and B-roll previously drifted; alignment must match the actual spoken topic.

## Caption Rules

- Captions must be timed to spoken phrases, not arbitrary sentence blocks.
- Keep burned-in captions to one or two lines.
- Do not leave a dimming overlay active while the audience needs to follow the demo.
- Caption styling should improve comprehension without becoming the main visual layer.
- If captions overlap the demo, move them to a safe area or reduce the caption moment.

## Quality Rules

- Fail fast on API, render, or missing-file errors. Report the exact error and stop instead of masking it.
- Do not claim a TTS model was used unless it is in a saved generation log or visible request.
- Do not use persistent overlays that make the demo hard to follow.
- Do not leave large unused screen real estate if a gentle crop can help, but readability wins over style.
- Always update a delivery checklist with final paths and verification numbers.

## Reference

Use `references/long-form-patterns.md` for reusable long-form structures, caption patterns, and QA checks.
