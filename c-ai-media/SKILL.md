---
name: c-ai-media
description: AI image and video generation for the creative studio. Use for generating AI images (Gemini/Nanobanana), cinematic video scenes (Higgsfield), talking-head animation from image+audio (RunPod InfiniteTalk), and Veo talking-head generation.
when_to_use: Trigger on AI image, generate image, Gemini image, Nanobanana, whiteboard image, cinematic scene, Higgsfield, RunPod, InfiniteTalk, talking head animation, Veo, character reference, character scene, AI b-roll generation.
allowed-tools: Bash
---

# AI Media Generation

## Mandatory Pre-Generation Check

**Before generating ANY image for a brand:**
1. Read `brands/{brand-slug}/brand-ref.md` — check style guide / prompt template
2. Use brand's prompt template as BASE prompt
3. Pass reference image via `inputImagePath` for style consistency
4. Output → `brolls/images/` (NOT interim/)

## Image Generation — Nanobanana (Primary)

Tool: `mcp__mcp-image__generate_image` (Gemini 2.5 Flash Image)

Use Gemini (NOT openai image-to-image — has quality param bug).

```
mcp__mcp-image__generate_image:
  prompt: "{brand_base_prompt} {scene_description}"
  inputImagePath: "{reference_image}"
  aspectRatio: "16:9" | "9:16" | "1:1"
  outputPath: "{brand_path}/creatives/brolls/images/{id}-{desc}.png"
```

### MGG Whiteboard Style
Orange pixel-art 8-bit octopus, white bg, stick figures, blue label boxes. NOT purple, NOT smooth.
Zoom: **1.1x max** (not 1.3x — labels at edges).

### Gemini Character Reference (Pro Model)

```bash
python3 _scripts/gemini-character.py --prompt "$PROMPT" --model pro --output "$OUT"
```
**Always `--model pro`** — flash has consistency issues. Pass reference image to EVERY call.

## Video Generation — Higgsfield Cinema Studio

Browser automation. ~24 credits per generation.
Genre: General/Action/Horror/Comedy/Western/Suspense. Camera: Handheld/Auto/Dolly/Crane/Orbit/Tracking.
See **[references/higgsfield.md](references/higgsfield.md)** for Chrome steps.

## Video Generation — RunPod InfiniteTalk

Animates portrait image with audio track.

```bash
# Submit
curl -s -X POST "https://api.runpod.ai/v2/infinitetalk/run" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" -H "Content-Type: application/json" \
  -d "{\"input\": {\"image_url\": \"$IMAGE_URL\", \"audio_url\": \"$AUDIO_URL\", \"size\": \"720p\"}}"

# Poll (60s interval, max 30 attempts)
curl -s "https://api.runpod.ai/v2/infinitetalk/status/$JOB_ID" -H "Authorization: Bearer $RUNPOD_API_KEY"
```
Status: `IN_QUEUE` → `IN_PROGRESS` → `COMPLETED`. Max 5 min audio per job.

## Zoom Presets

| Asset type | Zoom |
|-----------|------|
| AI whiteboard | `1.1x` |
| AI cinematic/photo | `1.15x` |
| App/screen/mobile | `none` |
| Static graphics | `1.15x` |
| Motion graphics | `none` |

## Output Paths

- AI images: `{brand_path}/creatives/brolls/images/{id}-{desc}.png`
- AI clips: `{brand_path}/creatives/brolls/ai/{id}-{desc}.mp4`
