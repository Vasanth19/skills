---
name: c-kie-ai
description: Kie.ai video and image generation. Use for Hailuo i2v, Sora-2, Kling, WAN, Seedance, Veo-3, GPT Image, Imagen 4, Z-Image, Grok-imagine, and InfiniTalk via kie.ai API. Replaces FloeAPI as primary i2v provider.
when_to_use: Trigger on kie.ai, KIE_AI_API_KEY, Hailuo video, hailuo i2v, Sora-2 video, Kling avatar, InfiniTalk, WAN video kie, Seedance kie, GPT image kie, Imagen 4 kie, Z-image, grok-imagine, image-to-video production.
allowed-tools: Bash
---

# Kie.ai — Direct API

## Step 0 — Always run first (model cache auto-sync)

```bash
bash /Users/vasanth/Code/skills/c-kie-ai/sync-models.sh
```

Refreshes `models.jsonl` if > 4 days old. Query available models:

```bash
# List all active models
tail -n +2 /Users/vasanth/Code/skills/c-kie-ai/models.jsonl | python3 -c "
import sys,json
for line in sys.stdin:
    m=json.loads(line)
    if not m.get('deprecated'):
        print(f\"{m['key']:<45} {m['api_model']}\")
"

# Filter by operation (e.g. image-to-video)
tail -n +2 /Users/vasanth/Code/skills/c-kie-ai/models.jsonl | python3 -c "
import sys,json
for line in sys.stdin:
    m=json.loads(line)
    if 'image-to-video' in m['operation'] and not m.get('deprecated'):
        print(m['api_model'])
"
```

---

**Base:** `https://api.kie.ai/api/v1`
**Auth:** `Authorization: Bearer $KIE_AI_API_KEY`
**Key source:** `~/.gsai/secrets.env` → `KIE_AI_API_KEY`

```bash
source ~/.gsai/secrets.env
```

⚠️ **Kie.ai cannot fetch external URLs.** All `image_url` fields must be base64 data URIs:
```bash
IMAGE_B64=$(python3 -c "import base64; print('data:image/png;base64,' + base64.b64encode(open('$IMG','rb').read()).decode())")
```

---

## Create Task (standard endpoint)

```bash
RESULT=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
  -H "Authorization: Bearer $KIE_AI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$MODEL\", \"input\": $INPUT_JSON}")
TASK_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['taskId'])")
```

## Poll Status

```bash
while true; do
  RESP=$(curl -s "https://api.kie.ai/api/v1/jobs/recordInfo?taskId=$TASK_ID" \
    -H "Authorization: Bearer $KIE_AI_API_KEY")
  STATE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['state'])")
  case "$STATE" in
    success|completed|done) break ;;
    fail|failed|error) echo "FAILED: $STATE" && exit 1 ;;
  esac
  sleep 5
done
VIDEO_URL=$(echo "$RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)['data']
import json as j2
print(j2.loads(d['resultJson'])['resultUrls'][0])
")
```

---

## Model Reference

| Key | `model` value | Use for | Required input fields |
|-----|--------------|---------|----------------------|
| Hailuo t2v | `hailuo/02-text-to-video-pro` | MiniMax text→video | `prompt` |
| Hailuo i2v | `hailuo/02-image-to-video-pro` | MiniMax image→video (labubu-shorts) | `prompt`, `image_url` (base64) |
| Sora-2 t2v | `sora-2-text-to-video` | Sora 2 text→video | `prompt`, `aspect_ratio`, `n_frames` |
| Sora-2 i2v | `sora-2-image-to-video` | Sora 2 image→video | `prompt`, `image_urls` (array, base64), `aspect_ratio` |
| Kling i2v | `kling/v2-5-turbo-image-to-video-pro` | Kling 2.5 i2v | `prompt`, `image_url`, `duration`, `aspect_ratio` |
| Kling avatar | `kling/ai-avatar-v1-pro` | Kling AI avatar | `prompt`, `image_url` |
| WAN t2v | `wan/2-6-text-to-video` | WAN 2.6 | `prompt`, `aspect_ratio` |
| WAN i2v | `wan/2-6-image-to-video` | WAN 2.6 i2v | `prompt`, `image_url`, `aspect_ratio` |
| Seedance | `bytedance/seedance-1.5-pro` | Seedance 1.5 | `prompt`, `image_url`, `aspect_ratio` |
| GPT Image | `gpt-image/1.5-text-to-image` | GPT image gen | `prompt`, `aspect_ratio` |
| GPT Image i2i | `gpt-image/1.5-image-to-image` | GPT image edit | `prompt`, `input_urls` (array, base64) |
| Imagen 4 | `google/imagen4` | Imagen 4 | `prompt`, `aspect_ratio` |
| Imagen 4 fast | `google/imagen4-fast` | Imagen 4 fast | `prompt`, `aspect_ratio`, `num_images` |
| Z-Image | `z-image` | Z-Image gen | `prompt`, `aspect_ratio` |
| Grok i2v | `grok-imagine/image-to-video` | Grok i2v | `prompt`, `image_url` |
| InfiniTalk | `infinitalk/from-audio` | Talking head from audio | `image_url`, `audio_url` |
| Seedream 4.5 | `seedream/4.5-text-to-image` | Seedream image | `prompt`, `aspect_ratio` |
| MiniMax music | `music-01` | Text→music | `prompt` |

### Hailuo i2v — Full Example (labubu-shorts pipeline)

```bash
IMG_B64=$(python3 -c "import base64; print('data:image/png;base64,' + base64.b64encode(open('$PNG','rb').read()).decode())")

RESULT=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
  -H "Authorization: Bearer $KIE_AI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"hailuo/02-image-to-video-pro\", \"input\": {\"prompt\": \"$PROMPT\", \"image_url\": \"$IMG_B64\"}}")

TASK_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['taskId'])")
echo "Task: $TASK_ID"
```

### Sora-2 aspect_ratio mapping

| UI aspect | Sora-2 value |
|-----------|-------------|
| 16:9 | `landscape` |
| 9:16 | `portrait` |

### n_frames (Sora-2 duration)

| Duration | n_frames |
|----------|---------|
| ~5s | `"10"` |
| ~10s | `"15"` |

---

## Veo 3 (different endpoint)

Veo 3 uses `/veo/generate` and `/veo/record-info`:

```bash
# Create
curl -s -X POST "https://api.kie.ai/api/v1/veo/generate" \
  -H "Authorization: Bearer $KIE_AI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"veo3_fast","prompt":"...","generationType":"TEXT_2_VIDEO","aspectRatio":"16:9"}'

# Poll
curl -s "https://api.kie.ai/api/v1/veo/record-info?taskId=$TASK_ID" \
  -H "Authorization: Bearer $KIE_AI_API_KEY"
# successFlag: 0=generating, 1=success, 2/3=failed
# output: data.response.resultUrls[0]
```

---

## Gotchas

- `image_url` must be base64 data URI — kie.ai **cannot** fetch external URLs
- `sora-2-*` model names use hyphens, NOT slashes (unlike other models)
- Polling state: `success`/`completed`/`done` → done; `fail`/`failed`/`error` → failed
- Error code `402` = insufficient credits; `401` = bad API key
- Full model registry: `/Users/vasanth/Code/video-apps/floe/src/integrations/ai/c-kie-ai/models/index.ts`
- DISCONTINUED: `google/nano-banana-pro` returns 422 since 2026-02-20
