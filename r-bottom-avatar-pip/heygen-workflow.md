# HeyGen Workflow — r-bottom-avatar-pip

Updated 2026-04-18.

## Mode Decision Table

| Mode | Skill | Credit Pool | When to Use |
|---|---|---|---|
| `human` (default) | `heygen-request-human` | none | Default for ALL orders |
| `mcp` | `heygen-mcp-request` | premium_credits (OAuth) or api_credits (stdio) | Only when `order.input.heygen_mode: "mcp"` explicitly set |
| `api` | `heygen-api-request` | api_credits | Only when `order.input.heygen_mode: "api"` explicitly set |

**Default is human.** Autonomous paths are opt-in only.

On `MOVIO_PAYMENT_INSUFFICIENT_CREDIT` from mcp/api → fall through to `heygen-request-human`. Never retry.

`heygen-browser-render` has been removed (unusable in subprocess runtime).

## Render Parameters

- `avatar_id`: from `brand.yaml.heygen.preferredAvatar.lookId`
- `voice_id`: from `brand.yaml.heygen.brandVoice.voiceId`
- Aspect: 16:9 or 9:16 — either works (recipe handles both in post)
- Resolution: 1080p
- Background: `#00FF00` preferred for cleanest compose; non-green also works (see `brand-params.md`)

## Caching

Re-running the recipe with the same script should cache-hit the avatar render at `production/heygen/raw-avatar.mp4`. Do NOT re-render HeyGen just because compose filter values changed. Skip to step 8 on cache hit.

## Speed Adjustment (Step 6.5 — MANDATORY)

After download, run `ffmpeg-speed-adjust` at 1.1x:

```bash
SPEED=1.1
PTS_FACTOR=$(python3 -c "print(round(1/$SPEED, 6))")  # 0.909091
ffmpeg -y -i heygen/raw-avatar.mp4 \
  -filter_complex "[0:v]setpts=PTS*${PTS_FACTOR}[v];[0:a]atempo=${SPEED}[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 48000 \
  heygen/avatar_1.1x.mp4
```

Verify: `new_duration ≈ raw_duration / SPEED ± 0.1s`. If off, STOP.

**Skip ONLY if `speed=1.0` was explicitly passed.** Silently skipping = VAS-34 bug (nemoclaw shipped at 1.0x).

`heygen/avatar_1.1x.mp4` is the active source for ALL downstream steps — never use `raw-avatar.mp4` in compose.
