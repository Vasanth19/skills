# HeyGen Workflow — r-alternating-visual

Same policy as `r-bottom-avatar-pip`. See `.config/brand.yaml` for `heygen.heygenWorkflow`.

## Mode Priority

Try in order:
1. `heygen-mcp-request` — if `heygen_mode: "mcp"` explicitly set
2. `heygen-api-request` — if `heygen_mode: "api"` explicitly set
3. `heygen-request-human` — **default for all orders**

Never call `mcp__heygen__create_video_from_avatar` directly (api_credits pool is empty on Creator plan).

## Render Parameters (per segment)

- `avatar_id`: `brand.yaml.heygen.preferredAvatar.lookId`
- `voice_id`: `brand.yaml.heygen.brandVoice.voiceId`
- aspect: 9:16, resolution: 1080p
- background: `#00FF00`

## Human vs Autonomous Path

See `segments.md` → "Compose Strategy by HeyGen Mode" for the full continuous-audio vs segmented-render decision.

Key rule: **never render the full combined script via mcp/api** — that bills credits for non-avatar gap time. Only the human path uses a single continuous render.
