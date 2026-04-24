---
name: pipeline-infinite-talk
description: RunPod InfiniteTalk talking head pipeline. Generates ElevenLabs voiceover, uploads audio to R2, submits to RunPod InfiniteTalk to animate a portrait image, polls for completion, and delivers an animated talking head video.
disable-model-invocation: true
argument-hint: "[brand] [production-name] [avatar-image]"
allowed-tools: Bash, Read, Write
---

# pipeline-infinite-talk — Animated Talking Head (RunPod)

Animates a portrait image with audio: ElevenLabs TTS → R2 → RunPod InfiniteTalk.

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| brand | Yes | — | Brand slug |
| production_name | Yes | — | Folder name |
| avatar_image | Yes | — | URL or path to portrait image |
| script | Yes | — | TTS-clean script text or `.txt` path |
| voice_id | No | brand-ref.md | ElevenLabs voice ID |
| size | No | `720p` | `480p`, `720p`, or `1080p` |
| speed | No | `1.1` | Playback speed (applied after download) |

**Audio limit: max 5 min per job.** For longer content: chunk audio, run multiple jobs, concat.

## Steps

### Step 1 — TTS Voiceover

→ Skill: `studio-audio` → ElevenLabs via Floe API
→ Voice: `$voice_id`
→ Output: `interim/audio/{name}-vo.mp3`

If script > 5 min estimated: split into chunks first (`studio-audio` chunk split).

### Step 2 — Upload Audio to R2

→ Skill: `cloud-media` → R2 upload
→ Path: `brolls/{brand}/audio/{name}-vo.mp3`
→ CDN URL: `https://{R2_PUBLIC_DOMAIN}/brolls/{brand}/audio/{name}-vo.mp3`

InfiniteTalk requires a public URL — local paths don't work.

### Step 3 — Submit to RunPod

→ Skill: `ai-media` → RunPod InfiniteTalk submit
```bash
curl -s -X POST "https://api.runpod.ai/v2/infinitetalk/run" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"input\": {
      \"image_url\": \"$AVATAR_IMAGE_URL\",
      \"audio_url\": \"$AUDIO_CDN_URL\",
      \"size\": \"$size\"
    }
  }"
```
→ Save `job_id`

Processing estimates: 3 min audio @ 720p → ~20 min. 5 min → ~33 min.

### Step 4 — Poll for Completion

→ Skill: `ai-media` → RunPod poll
→ Interval: 60s, max 30 attempts
→ Status flow: `IN_QUEUE` → `IN_PROGRESS` → `COMPLETED`
→ Download output MP4 to: `interim/video/base/{name}-infinitetalk.mp4`

If `FAILED`: check error, adjust parameters, resubmit.

### Step 5 — Speed Adjust (if `speed != 1.0`)

→ Skill: `ffmpeg` → `setpts + atempo`
→ Output: `interim/video/base/{name}-{speed}x.mp4`

### Step 6 — Multi-Chunk Concat (if chunked)

If audio was split:
→ Skill: `ffmpeg` → concat all chunk outputs → `video/compositing/combined.mp4`

### Step 7 — Deliver ⛔ CHECKPOINT

→ ffprobe verify → `final/pr-talk01-{desc}.mp4`
**Gate: User reviews talking head quality.**
