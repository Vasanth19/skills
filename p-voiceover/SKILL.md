---
name: p-voiceover
description: Audio production recipe — turn a script into a finished voiceover (ElevenLabs TTS), transcribe an uploaded recording into a clean transcript, or convert a rough voice memo into a structured script. Trigger on "make a voiceover", "voice this script", "turn this into audio", "narrate this", "transcribe this", "transcribe my recording", "turn my voice memo into a script", "what did I say in this clip".
when-to-use: Use when the user wants audio produced or processed — a script read aloud as a voiceover, an uploaded audio/video recording transcribed into clean text, or a rough voice memo turned into a structured short-form script. This is the Voice specialist's (Sage's) primary recipe; it composes c-audio (TTS, transcription, loudness) and c-script (TTS cleaning, structuring) into deliverable outputs.
version: 1.0.0
kind: pipeline
visibility: catalog
providers: elevenlabs
produces:
  dish: Voiceover & Transcript
  format: mp3 audio / structured text
  duration: 15s–10min audio
inputs: [script_text, audio_or_video_upload]
dependsOn: [c-audio, c-script, c-cloud-media, c-eval-runner]
---

# p-voiceover — Voiceover & Transcription Recipe

The audio recipe. Three flows, one skill — pick the flow from what the user gave you:

| Flow | User gives | User gets | Maps to agent flow |
|------|-----------|-----------|--------------------|
| **A. Voiceover** | Script text (or asks you to write one) | Finished `.mp3` voiceover, R2 URL | `voiceover` |
| **B. Transcribe** | Uploaded audio/video | Clean transcript text | `transcribe` |
| **C. Voice-to-script** | Rough voice memo / ramble | Structured short-form script | `voice-to-script` |

**Hard rules (all flows):**
- Return REAL asset URLs and transcripts produced by tools. Never fabricate an audio URL or invent transcript content.
- Confirm the **voice** before synthesizing (Flow A): use the brand's configured voice ID; if none exists, list the available voice presets from `c-audio` and ask.
- Filler removed, structure added, **nothing invented** — a transcript must say what the speaker said.

---

## Flow A — Voiceover (script → mp3)

1. **Clean the script for TTS** → delegate to `c-script` (TTS preprocessing):
   - Strip markdown/formatting, expand numbers and abbreviations, normalize punctuation for natural pauses.
   - If no script was provided and the user asked you to write one, use `c-script` short-form structure (Hook → Core Value → Payoff) first, confirm it with the user, THEN clean it.
2. **Resolve the voice**:
   - Brand voice ID from brand config / voice-clone configuration (the Voice specialist guards this).
   - No brand voice? Present the `c-audio` voice presets and ask the user to pick. Do not guess.
3. **Synthesize** → delegate to `c-audio` TTS (Floe API primary, direct ElevenLabs fallback) with the cleaned script + voice ID.
4. **Normalize loudness** → `c-audio` loudnorm pass (target podcast/social LUFS).
5. **QA gate (MANDATORY — run before delivery):**
   ```bash
   bash .hub/c-eval-runner/scripts/eval-run.sh <FINAL.mp3_or_aac> --recipe-dir "$SKILL_DIR" --brand "$BRAND_SLUG"
   ```
   A `FAIL` (exit 1) means loudness, mean-volume, or duration is out of spec — re-run the loudnorm pass or re-synthesize, then re-gate. Do NOT deliver until verdict is `PASS`.
6. **Deliver** → upload the `.mp3` via `c-cloud-media` to R2 and return the public URL as the output asset. Attach it to the run/composition as an audio output.

**Output contract:** one `.mp3` R2 URL + the final script text used.

## Flow B — Transcribe (recording → clean transcript)

1. **Fetch the upload** — resolve the uploaded audio/video to a local file (use the media URL from the user session's most recent upload event).
2. **Extract/convert audio** if the upload is video → `c-audio` (ffmpeg extract, 16kHz mono wav).
3. **Transcribe** → delegate to `c-audio` transcription.
4. **Clean** → delegate to `c-script`: remove filler words ("um", "like", repeated false starts), fix casing/punctuation, add paragraph breaks at topic shifts. **Do not add, reorder, or rephrase content.**
5. **Deliver** → return the clean transcript as text. If it is long (>2,000 words), also save it as a `.md` file, upload via `c-cloud-media`, and return the URL alongside an inline summary.

**Output contract:** clean transcript text (+ optional `.md` R2 URL for long transcripts).

## Flow C — Voice-to-script (voice memo → structured script)

1. Run **Flow B** (transcribe + clean) on the voice memo.
2. **Structure** → delegate to `c-script`: reshape the cleaned transcript into a short-form script (Hook → Core Value → Payoff), preserving the speaker's ideas, phrasing, and key lines wherever possible — this is the user's voice, not a rewrite.
3. **Estimate duration** → `c-script` duration estimation; flag if it overshoots the target format (30–60s short-form default).
4. **Deliver** → return the structured script + the raw clean transcript (so the user can see what was kept).

**Output contract:** structured script text + the source transcript.

---

## Voice-clone configuration (guard duty)

The Voice specialist owns which ElevenLabs/HeyGen voice belongs to this brand. When asked to
change or set the brand voice:
- Confirm the exact voice (preset name or voice ID) with the user before saving.
- Record it via the brand-context tools so every future Flow A run uses it without asking.
- Never apply one brand's voice clone to another brand's content.

## Production notes

- TTS + transcription run inside the `c-audio` component — provider keys come from the brand
  vault (`providers: elevenlabs`) with environment fallback. If neither has a key, fail loudly
  and tell the user which key is missing; do not silently skip synthesis.
- Heavy/long jobs (10+ min of audio, batch voiceovers) should be enqueued off-turn
  (`enqueue_production`) rather than run inline — same rule as video renders.
