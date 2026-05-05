---
name: c-studio-audio
description: Audio production for the creative studio. Use for text-to-speech voiceover generation (ElevenLabs via Floe API), SFX generation, audio chunk splitting, speech-to-text transcription (MLX Whisper on Apple Silicon), and audio loudness normalization.
when_to_use: Trigger on TTS, voiceover, ElevenLabs, script-to-audio, SFX, sound effect, transcribe, whisper, MLX, loudnorm, audio chunk, audio split, LUFS, voiceover generation.
allowed-tools: Bash
---

# Studio Audio — TTS, SFX, Transcription

## Priority Order
1. **Check SFX library first** — `sfx/sfx-library.md` at `creative-studio/sfx/`. Preview: `afplay sfx/{category}/{file}.mp3`.
2. **TTS via Floe API** (primary). Direct ElevenLabs API as fallback only.
3. **MLX Whisper** for transcription — local, Apple Silicon, no API cost.

## TTS — Floe API (Primary)

```bash
RESULT=$(curl -s -X POST "https://floe-production.up.railway.app/api/v1/script-to-audio" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $FLOE_API_KEY" \
  -d "{
    \"execution_id\": \"tts-$(date +%s)\",
    \"task_name\": \"voiceover\",
    \"input_fields\": {
      \"script\": \"$SCRIPT_TEXT\",
      \"voice_id\": \"$VOICE_ID\",
      \"language\": \"english\"
    }
  }")
AUDIO_URL=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['output_fields']['audio_url'])")
curl -s -o "$OUTPUT_PATH" "$AUDIO_URL"
```

## Voice Presets

| Voice | ID | Style |
|-------|----|-------|
| Crystal | `pq3wL6Xv3fuEM14W6ZCg` | Clear, professional female |
| Layla | `ujoCPuNXFKVxZSRRrMHv` | Warm, conversational female |
| Vasanth | `$ELEVENLABS_DEFAULT_VOICE_ID` | Owner's voice clone |

## TTS — Direct ElevenLabs (Fallback)

Model: `eleven_turbo_v2_5`

```bash
curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"$SCRIPT_TEXT\",
    \"model_id\": \"eleven_turbo_v2_5\",
    \"voice_settings\": {\"stability\": 0.5, \"similarity_boost\": 0.75, \"style\": 0.0}
  }" --output "$OUTPUT_PATH"
```

## MLX Whisper Transcription

```bash
mlx_whisper \
  --model mlx-community/whisper-large-v3-turbo \
  --output-format all \
  --output-dir "$OUTPUT_DIR" \
  "$INPUT_AUDIO"
```
SRT is ground truth — always use SRT timecodes for b-roll plans.

## Audio Chunk Split (Speed Adjustment)

```bash
ffmpeg -i "$AUDIO" -filter:a "atempo=$SPEED" -y "$OUTPUT"
```
atempo: 0.5–2.0 only. Chain for values outside: 2.5x = `atempo=2.0,atempo=1.25`

## SFX Library

```
creative-studio/sfx/: whoosh/ ding/ transition/ tension/ swell/ ambient/
```
Check `sfx-library.md` before generating. New SFX → `sfx/{category}/` (NEVER in production `audio/`).

## Output Paths

- Voiceover: `{production}/interim/audio/{name}.mp3`
- SFX: `creative-studio/sfx/{category}/{name}.mp3`
- Transcription: `{production}/interim/audio/{name}.srt`
