---
name: fal-ai
description: fal.ai image and video generation. Use for FLUX image gen, and async queue-based video generation (Kling, Seedance, WAN, Veo, MiniMax). Direct API calls via curl.
when_to_use: Trigger on fal.ai, FAL_KEY, FLUX image, Kling video, Seedance video, WAN video, Veo video, MiniMax video, fal queue, image-to-video fal, text-to-video fal.
allowed-tools: Bash
---

# fal.ai — Direct API

## Step 0 — Always run first (model cache auto-sync)

```bash
bash /Users/vasanth/Code/skills/fal-ai/sync-models.sh
```

Refreshes `models.jsonl` if > 4 days old. Query available models:

```bash
# List all models
tail -n +2 /Users/vasanth/Code/skills/fal-ai/models.jsonl | python3 -c "
import sys,json
for line in sys.stdin:
    m=json.loads(line)
    print(f\"{m['key']:<40} {m['endpoint_id']}\")
"

# Filter by operation (e.g. image-to-video)
tail -n +2 /Users/vasanth/Code/skills/fal-ai/models.jsonl | python3 -c "
import sys,json
for line in sys.stdin:
    m=json.loads(line)
    if 'image-to-video' in m['operation']:
        print(m['endpoint_id'])
"
```

---

**Base:** `https://fal.run` (sync image) / `https://queue.fal.run` (async video)
**Auth:** `Authorization: Key $FAL_KEY`
**Key source:** `~/.gsai/secrets.env` → `FAL_KEY`

```bash
source ~/.gsai/secrets.env
```

---

## Image Generation (synchronous)

```bash
curl -s -X POST "https://fal.run/fal-ai/flux/dev" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "your prompt here",
    "image_size": "landscape_16_9",
    "num_images": 1,
    "output_format": "png"
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['images'][0]['url'])"
```

**Aspect ratio enum** (`image_size`): `square_hd` | `landscape_16_9` | `portrait_16_9` | `landscape_4_3` | `portrait_4_3`

**Image models:** `fal-ai/flux/dev` (quality) · `fal-ai/flux/schnell` (fast)

---

## Video Generation (async queue)

**Pattern: submit → poll status_url → fetch response_url**

### Step 1 — Submit

```bash
RESULT=$(curl -s -X POST "https://queue.fal.run/$MODEL" \
  -H "Authorization: Key $FAL_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")
STATUS_URL=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['status_url'])")
RESPONSE_URL=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['response_url'])")
```

### Step 2 — Poll (every 5s until COMPLETED)

```bash
while true; do
  STATUS=$(curl -s "$STATUS_URL" -H "Authorization: Key $FAL_KEY" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
  [ "$STATUS" = "COMPLETED" ] && break
  [ "$STATUS" = "FAILED" ] && echo "FAILED" && exit 1
  sleep 5
done
```

### Step 3 — Get output URL

```bash
VIDEO_URL=$(curl -s "$RESPONSE_URL" -H "Authorization: Key $FAL_KEY" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('video') or d.get('videos',[{}])[0]).get('url',''))")
```

---

## Model Reference

| Key | fal endpoint | Use for |
|-----|-------------|---------|
| Image | `fal-ai/flux/dev` | Quality image gen |
| Image | `fal-ai/flux/schnell` | Fast image gen |
| Video t2v | `fal-ai/kling-video/v3/pro/text-to-video` | Kling 3 |
| Video i2v | `fal-ai/kling-video/v3/pro/image-to-video` | Kling 3 i2v |
| Video t2v | `fal-ai/veo3` | Veo 3 |
| Video t2v | `fal-ai/veo3.1` | Veo 3.1 |
| Video i2v | `fal-ai/veo3.1/image-to-video` | Veo 3.1 i2v |
| Video t2v | `bytedance/seedance-2.0/text-to-video` | Seedance 2 |
| Video i2v | `bytedance/seedance-2.0/image-to-video` | Seedance 2 i2v |
| Video t2v | `fal-ai/wan/v2.2-a14b/text-to-video` | WAN 2.2 |
| Video i2v | `fal-ai/wan/v2.2-a14b/image-to-video` | WAN 2.2 i2v |
| Video t2v | `fal-ai/minimax/video-01-live` | MiniMax (Hailuo) |

## Common Payload Fields (video)

```json
{
  "prompt": "...",
  "image_url": "https://... or data:image/png;base64,...",
  "aspect_ratio": "16:9",
  "duration": 5,
  "resolution": "720p"
}
```

Seedance duration range: 4–15s. Veo/Kling duration: 5 or 10s.

---

## Gotchas

- `status_url` and `response_url` use `queue.fal.run` domain — same `Authorization: Key` header required
- Seedance 2.0 duration must be passed as a **string** (`"5"` not `5`)
- MiniMax Live model only accepts `prompt` + optional `image_url` — no aspect_ratio/duration overrides
- Full model registry in Floe: `/Users/vasanth/Code/video-apps/floe/src/integrations/ai/fal/media-gen/models.ts`
