# Segment Pattern — r-alternating-visual

## 6-Segment Structure

| # | Type | Duration | Purpose |
|---|---|---|---|
| 1 | **HeyGen** | 5-7s | Hook + problem statement |
| 2 | **Remotion** | 3-5s | Graphic/animation illustrating the concept |
| 3 | **HeyGen** | 6-10s | Main explanation |
| 4 | **Remotion OR NanoBanana image** | 3-5s | Screenshot evidence, tool demo, or AI-gen image via Gemini |
| 5 | **HeyGen** | 5-7s | Takeaway + CTA |
| 6 | **Outro** | 2-3s | Brand card / subscribe |

Total: 30-40s.

---

## HeyGen Render Notes — Square Avatar, Centered

All MGG HeyGen renders use the **square digital twin** `Vas-Sq-0417-101` (1280×1280 native). HeyGen's API only accepts 9:16 or 16:9 — render at **9:16 (1080×1920)** so the avatar's square content is preserved within, then center-crop to 1080×1080 square in post.

**Display for alternating HeyGen segments:**
- Canvas: 1080×1920 (9:16 Short)
- Avatar square: crop center 1080×1080 from the 1080×1920 HeyGen render
- Position: **centered vertically** on dark-navy canvas (y=420 to y=1500) — 420px nav bars top + bottom
- Background behind avatar bars: `#0F172A` (dark navy) — NOT the green-screen color
- Chroma-key the green first (make background transparent), then overlay the square center-crop on navy canvas

**ffmpeg sketch (per HeyGen segment):**
```bash
ffmpeg -i <heygen-raw-1080x1920>.mp4 \
  -vf "crop=1080:1080:0:420,colorkey=0x00FF00:0.25:0.05,format=yuva420p" \
  segment-N-keyed-1080square.mov

ffmpeg -i background-1080x1920-navy.mp4 -i segment-N-keyed-1080square.mov \
  -filter_complex "[0][1]overlay=0:420" segment-N-composed.mp4
```

All 3 HeyGen segments share the same avatar + voice + aspect + background. Render each as a separate clip; do NOT try to split a single render in post (lip-sync breaks on trim boundaries).

**Batching:** For mcp/api paths, fire all 3 segment renders back-to-back (async on HeyGen's side). For the human path, one render per segment.

**Settings per segment:**
- `avatar_id`: `brand.yaml.heygen.preferredAvatar.lookId`
- `voice_id`: `brand.yaml.heygen.brandVoice.voiceId`
- aspect: 9:16, resolution: 1080p, background: `#00FF00`

---

## Compose Strategy by HeyGen Mode

### Default — `heygen_mode: "human"` (ONE continuous render)

Write the script as a **single continuous narrative** — hook through CTA, natural sentences, no segment markers. Human renders ONE video in HeyGen web UI (unlimited on Creator plan, no credit pressure). Human replies with ONE `heygen_video_id: <id>`.

Pipeline: `heygen-poll-download` → single `production/heygen/raw-avatar.mp4` → `heygen-green-screen-verify`.

**Do NOT trim the HeyGen video into pieces.** The audio stays continuous. Visual b-roll (Remotion/NanoBanana) is **overlaid ON TOP** of the avatar at beat timestamps — audio keeps playing underneath. When a visual is on screen, the avatar goes to a PIP or steps aside; when no visual is up, avatar is full-canvas center.

### Opt-in — `heygen_mode: "mcp"` or `"api"` (segment-specific renders to save credits)

Pre-split the script into 3 segment-specific chunks (the script parts where the avatar is on screen). Fire `heygen-mcp-request` / `heygen-api-request` THREE times — passing ONLY the segment text.

3× `heygen-poll-download` → `production/heygen/segment-<N>.mp4`. `heygen-green-screen-verify` on each.

This exists because metered credits bill per render duration — don't pay for non-avatar gaps. Segments are stitched end-to-end with visuals cut-in (NOT the continuous-audio compose pattern above).

**Never** render the full combined script via mcp/api — wastes credits on non-avatar gaps.
