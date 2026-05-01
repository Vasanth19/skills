---
name: demo-with-avatar-via-hgapi
description: "Use when producing a complete demo video for any topic where the pipeline should be automated end-to-end: script, ElevenLabs or provided audio, HeyGen API avatar generation from audio, splitting the combined avatar render back into timed clips, Remotion composition, demo/B-roll sync, captions, final render, and delivery QA."
metadata:
  short-description: Automate demo videos with HeyGen API avatars
---

# Demo With Avatar Via HGAPI

Use this skill when a demo, topic, or rough recording needs to become a finished tutorial or explainer with avatar moments generated through the HeyGen API. This is the automated version of the recent manual workflow: create audio, submit one combined HeyGen render, split it back into avatar clips, and let Remotion assemble the full video.

## Default Output

Create or reuse a production folder with:

- `script/`: full script, avatar snippets, visual beat map, split map
- `audio/`: final narration, avatar audio clips, combined HeyGen audio, generation logs
- `avatar/`: HeyGen request payloads, poll logs, downloaded combined render, split avatar clips
- `captions/`: SRT/VTT plus composition-ready caption JSON from final audio
- `broll/` or `segments/`: source demo clips with timestamp notes
- `renders/`: Remotion project and render artifacts
- `interim/`: previews, still checks, temporary muxes
- `final/`: master, requested speed variant, platform export, delivery note

## Workflow

1. Read the project and brand context.
   - Read `AGENTS.md`, `CLAUDE.md`, brand configs, and any creative-director instructions.
   - Read the brand voice/audio settings before generating TTS.
   - For Mr Growth Guide, default ElevenLabs to voice `6aTgB3K5cvcH2IlnFVSx` and model `eleven_multilingual_v2` unless the user explicitly overrides it.

2. Write the story before rendering.
   - Create a hook, value section, proof/demo section, workflow explanation, and CTA.
   - Decide which lines should be avatar PIP or full avatar moments.
   - Avatar moments should be short: usually 6-12 seconds each, spaced every 60-90 seconds for long-form unless the user asks otherwise.

3. Generate or ingest audio.
   - If the user provides final audio, use it as source of truth.
   - Otherwise generate narration with the brand-configured ElevenLabs voice/model.
   - Generate each avatar snippet as a separate audio file from the final avatar script text.
   - Stitch avatar snippet audio into one HeyGen-ready MP3/WAV with `0.5s` silence between snippets.
   - Save a split map with snippet name, text, audio duration, combined start, combined end, and silence gaps.

4. Render avatar with HeyGen API.
   - Use the HeyGen API with audio as the voice source when possible, not text-to-speech inside HeyGen.
   - Submit one combined avatar video from the stitched avatar audio to save setup time and keep the pipeline automated.
   - Use a green background (`#00FF00`) unless the target composition needs a native background.
   - Poll until completed, download the combined MP4, then split it back using the saved split map.
   - Read [references/heygen-api-workflow.md](references/heygen-api-workflow.md) when implementing the API call, polling, splitting, and chroma key.

5. Build Remotion composition.
   - Remotion is the default assembler for this skill.
   - Use the original demo source or clean extracted clips as continuous media whenever possible.
   - Avoid jitter-prone patterns: repeated video seeking, frame-rate mismatches, post-speed frame dropping, and unnecessary animated zooms on source footage.
   - Use avatar clips as small PIP by default. Use full-screen avatar only for intentional 8-12 second personal beats.
   - Keep callouts short and in safe areas, usually top-right.
   - Use generated Remotion B-roll when the narration references abstract actions such as prompts, tools, files, API calls, timelines, or workflows.

6. Add captions.
   - Captions are required unless the user explicitly asks for no captions.
   - Generate captions from the actual final audio, not the draft script.
   - For long-form, use selective burned-in captions for hooks, section turns, key claims, and CTA.
   - For shorts, use burned-in captions throughout the hook/value/proof/CTA beats.
   - Do not leave a dimming overlay active while the viewer needs to follow the demo.

7. Render and QA.
   - Render a short preview first around the hook and first avatar insert.
   - Verify avatar split timing before the full render.
   - Render final master, then make any requested speed-adjusted export.
   - Check dimensions, duration, frame rate, sample rate, audio peak, caption readability, avatar placement, and B-roll/narration alignment.
   - Save `DELIVERY.md` with final paths, model/voice IDs, HeyGen video ID, verification numbers, and known limitations.

## Composition Rules

- Do not patch a jittery render repeatedly. If timing or motion is unstable, rebuild from the clean source media and a deterministic timeline.
- Use constant frame rate sources in Remotion where practical. Normalize mixed-fps inputs before composition when they cause visual stutter.
- Keep PIP small enough that it feels personal without blocking UI.
- Avoid persistent overlays. Use short callouts, highlight boxes, and captions that disappear quickly.
- Use real demo footage for proof and generated Remotion scenes for concepts the demo cannot visually show.

## Fail-Fast Rules

- Never silently fall back from HeyGen API to browser UI, MCP, or manual rendering. Stop with the exact error and ask before changing the render path.
- Never print API keys or secrets. Load them from `.gsai/secrets.env` or the configured local secret source.
- Do not claim a model, voice, avatar, or HeyGen video ID was used unless it is logged in the production folder.
- Do not overwrite raw source files. Generated files belong under the production folder.

## Related Skills

- Use `demo-to-long-distribution` for long-form story structure and delivery QA.
- Use `demo-to-short-distribution` for short-form hook/value/proof/CTA variants.
- Use `heygen` for lower-level HeyGen details when the API path needs troubleshooting.
- Use `remotion:remotion-best-practices` when implementing or debugging the Remotion composition.

