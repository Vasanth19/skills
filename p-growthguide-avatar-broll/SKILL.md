---
name: p-growthguide-avatar-broll
description: "Assemble a 20s portrait 9:16 Short: HeyGen avatar at bottom, b-roll switching every 3-5s on top. Human-in-loop HeyGen render (subprocess agents cannot hit premium_credits). Caches avatar render to avoid re-burning credits."
brand: B-GROWTHGUIDE
version: "2.0"
created: "2026-04-17"
revised: "2026-04-18"
issue: VAS-7
revision_note: "v2.0 — Step 2 rewritten for human-in-loop HeyGen per brand.yaml heygenWorkflow. Direct API calls (mcp__heygen__create_video_from_avatar, heygen-browser-render) are forbidden from subprocess adapters — they fail with MOVIO_PAYMENT_INSUFFICIENT_CREDIT."
move-to: .claude/skills/p-growthguide-avatar-broll/
kind: pipeline
visibility: catalog
produces:
  dish: GrowthGuide Avatar B-roll Short
  format: 9:16 vertical video
  duration: 20s
inputs: [script]
dependsOn: [t-heygen, c-broll, c-ffmpeg]
---

# p-growthguide-avatar-broll

> Assemble a 20-second 1080×1920 Short: HeyGen Cozy Tech Guru avatar anchored at the bottom, b-roll clips cycling in the top 60% zone. Avatar render is cached by script hash — re-running with the same script does NOT burn fresh credits.

## Signature

### Inputs

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `script` | Yes | — | Voiceover text. ~55-65 words for ~20s at natural pace. |
| `brollTheme` | No | `ai` | Subfolder under `creatives/brolls/`. Options: `ai`, `app`, `gfx`, `images`, `recordings`. |
| `avatarLookId` | No | `7bf32c75b0cf4a518661d75d44e01c32` | HeyGen look ID. Default: Cozy Tech Guru. |
| `aspectRatio` | No | `9:16` | `9:16` (Shorts default) or `16:9`. |
| `outputPath` | No | auto | `creatives/productions/{MM.DD}-{title}/final/short.mp4` |

### Output

| File | Description |
|------|-------------|
| `final/short.mp4` | 1080×1920, 20s ±2s, h264+aac, faststart |
| `renders/avatar-{hash}.mp4` | Cached green-screen HeyGen render (do not delete) |
| `brief.md` | Production brief at production root |
| `script.md` | Original + TTS-preprocessed script |

## Layout

```
+---------------------------+
|                           |   y=0
|   B-ROLL (top 60%)        |
|   1080 × 1152             |   (clips cycle every 3-5s)
|   scale-fill, no bars     |
|                           |
+---------------------------+   y=1152
|   brand navy #0F172A      |   (~160px visual separator gap)
+---------------------------+   y≈1312
|   AVATAR (flush bottom)   |
|   1080 wide, ~608 tall    |   (green-screen keyed, always visible)
|   Cozy Tech Guru          |
+---------------------------+   y=1920
        1080 × 1920
```

**Rules:**
- Avatar is ALWAYS the last layer (on top of everything)
- B-roll overlays in the top zone with time-based enable windows
- Dark navy `#0F172A` fills canvas including the gap between b-roll and avatar

## Pipeline

### Step 0: Production folder setup

```bash
BRAND_ROOT="/Users/vasanth/vasanth-hq/mr-growth-guide"
# Production folder naming: MM.DD-<title> (month.day + kebab-title). Old ord-YYYYMMDD-NNN-slug retired.
MMDD=$(date +%m.%d)
SLUG=$(echo "$SCRIPT" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | cut -c1-30 | sed 's/-$//')
ORD_ID="${MMDD}-${SLUG}"
# Collision suffix: if a folder with this name already exists, append -2, -3, ...
base="$ORD_ID"; n=2
while [ -d "$BRAND_ROOT/creatives/productions/$ORD_ID" ]; do ORD_ID="${base}-${n}"; n=$((n+1)); done
PROD_DIR="$BRAND_ROOT/creatives/productions/$ORD_ID"
mkdir -p "$PROD_DIR/renders" "$PROD_DIR/final" "$PROD_DIR/broll"
```

Write `brief.md` and `script.md` at `$PROD_DIR/`.

### Step 1: TTS preprocessing

Clean script for HeyGen:
- `"AI"` → `"A-I"`, `"API"` → `"A-P-I"`, `"vs"` → `"versus"`
- Strip markdown, hashtags, brackets
- Numbers: `"5,000"` → `"five thousand"`, `"$200"` → `"two hundred dollars"`
- Ensure final sentence ends with a period

Write to `$PROD_DIR/script-tts.txt`.

### Step 2: Avatar render — HUMAN IN THE LOOP (mandatory)

> **Hard rule:** Subprocess agents (Paperclip heartbeat context) CANNOT render HeyGen avatars directly. The `HEYGEN_API_KEY` hits the public developer API which charges `api_credits` — a separate pool from the Creator plan `premium_credits` (86/mo, used by the web UI and OAuth MCP). Every direct render attempt returns `MOVIO_PAYMENT_INSUFFICIENT_CREDIT`. **Never call `mcp__heygen__create_video_from_avatar` or `heygen-browser-render` from this skill.** Halt and request the render from the human via the canonical workflow in `.config/brand.yaml` → `heygenWorkflow`.

**Step 2a — Check cache first (no render needed on cache hit):**

```bash
CACHE_KEY=$(echo "${SCRIPT_TTS}${AVATAR_LOOK_ID}" | md5 2>/dev/null || \
            echo "${SCRIPT_TTS}${AVATAR_LOOK_ID}" | md5sum | cut -c1-32)
CACHE_PATH="$PROD_DIR/renders/avatar-${CACHE_KEY}.mp4"

if [ -f "$CACHE_PATH" ]; then
  echo "CACHE HIT — skipping request, saving ~8 credits"
  AVATAR_MP4="$CACHE_PATH"
  # Skip directly to Step 3
fi
```

**Step 2b — On cache miss: post structured request to the Paperclip issue via `heygen-request` skill.**

Request payload posted as a comment on the issue driving this production:

```
heygen_request:
  issue_key:       {PAPERCLIP_ISSUE_KEY}           # e.g. VAS-7
  recipe:          bottomAvatarPip
  segment:         1/1                              # Recipe 2 is single-segment
  script_preview:  {first 160 chars of SCRIPT_TTS}
  script_full:     {full SCRIPT_TTS content}
  avatar_look_id:  e661ddf52a234853bd899d3828ce2b8b # brand.yaml preferredAvatar.lookId
  voice_id:        73f2869ebd9948aeb0fa85d33cbc20c3 # brand.yaml preferredAvatar.voiceId
  aspect_ratio:    "16:9"                           # brand.yaml recipe.bottomAvatarPip.avatarRender.aspectRatio
  resolution:      1080p
  background:      "#00FF00"                        # green screen — mandatory for chroma/colorkey
  target_duration: 20
  title:           "{ISSUE_KEY} Recipe 2 avatar — {slug}"
  cache_path:      {CACHE_PATH}                     # where Creative Director expects the MP4 to land
  reply_format:    "heygen_video_id: <id>"
```

Save the full payload to `$PROD_DIR/renders/heygen-request.yaml` for the audit trail.

**Step 2c — Alert the human via OpenClaw** (delegate the ping — do NOT send Discord yourself).

Delegate to OpenClaw (`agent_id: b4c627ff-0f03-49ff-854c-5c32029e7859`) using the `openclaw-notify` skill. Alert payload matches `brand.yaml heygenWorkflow.alertChannel.messageTemplate`:

```
🎬 HeyGen render needed for {issue_key} — bottomAvatarPip, segment 1/1.
Script: {script_preview}
Issue: {issue_url}
Reply on the issue with: heygen_video_id: <id>
```

**Step 2d — Set issue status to `waiting_on_human` and HALT.**

The skill stops here. The heartbeat agent does NOT poll, does NOT retry, does NOT improvise. Vasanth (or main Claude with OAuth HeyGen MCP) will render in the web UI, then comment on the issue:
```
heygen_video_id: <id>
```
and flip status back to `in_progress`. The next heartbeat resumes at Step 2e.

**Step 2e — On resume: fetch the rendered MP4 via `heygen-fetch` skill.**

The Paperclip wake payload will surface the `heygen_video_id` comment. `heygen-fetch` uses the API key to poll `GET /v1/video_status` (this call DOES work with `api_credits=0` — only `create_video` is blocked) and downloads the MP4 to `$CACHE_PATH`:

```
heygen_video_id: {from latest issue comment}
output_path:     {CACHE_PATH}
timeout:         600s
```

Verify: `ffprobe` the file — must be portrait-rendered, ~18-22s. (HeyGen renders 16:9 internally; the composite step re-crops to the 540×540 PIP.)

**What this step MUST NOT do:**
- Call `mcp__heygen__create_video_from_avatar` — forbidden, fails with `MOVIO_PAYMENT_INSUFFICIENT_CREDIT`
- Retry on `MOVIO_PAYMENT_INSUFFICIENT_CREDIT` — halt immediately and alert via OpenClaw
- Proceed to Step 3 without a real `video_id` — refuse and log to the issue
- Fall back to placeholder avatars — produces broken creative, violates brand integrity
- Send Discord messages directly — always route through OpenClaw

### Step 3: Green-screen verify

```bash
ffmpeg -ss 2 -i "$AVATAR_MP4" -frames:v 1 -q:v 1 "$PROD_DIR/renders/bg-check.jpg" 2>/dev/null
open "$PROD_DIR/renders/bg-check.jpg"
```

Background must be solid bright green (#00FF00). If not — STOP. Re-render with explicit green bg.

**Critical:** Use `colorkey` (NOT `chromakey` — unavailable in our ffmpeg build). Always hardcode `0x00FF00`.

### Step 4: B-roll selection

Source: `$BRAND_ROOT/creatives/brolls/{brollTheme}/`
Index: `$BRAND_ROOT/creatives/brolls/{brollTheme}-broll-library.md`

Run `scripts/broll-select.sh` to validate clips and build placement plan at `$PROD_DIR/broll/placement-plan.json`.

**Rules for 20s short:**
1. Pick 4-6 clips, each 3-5s. Total b-roll ≥ 16s (80%+ coverage).
2. First sentence (0-3s): avatar only — no b-roll (hook eye contact).
3. Final sentence (~17-20s): avatar only — no b-roll (CTA direct appeal).
4. Don't repeat same clip twice.
5. If theme has < 4 clips, supplement from `ai` theme.

**Default `ai` theme clips (each 4s):**
| Clip | Use when script mentions... |
|------|-----------------------------|
| `pr-clip-01-tunnel.mp4` | journey, start, opening |
| `pr-clip-02-darkness.mp4` | challenge, problem, obstacle |
| `pr-clip-03-glow.mp4` | solution, hope, turning point |
| `pr-clip-04-ants.mp4` | detail, persistence, systems |
| `pr-clip-05-colony.mp4` | ecosystem, automation, scale |
| `pr-hedgehog-final-merged.mp4` | mascot reveal, cinematic (use 4-5s segments) |

### Step 5: Composite

Run `scripts/composite.sh`:

```bash
bash "$BRAND_ROOT/creatives/skills/p-growthguide-avatar-broll/scripts/composite.sh" \
  --avatar "$AVATAR_MP4" \
  --duration 20 \
  --broll-dir "$BRAND_ROOT/creatives/brolls/$BROLL_THEME" \
  --placement-plan "$PROD_DIR/broll/placement-plan.json" \
  --output "$PROD_DIR/final/short.mp4"
```

### Step 6: Verify output

```bash
# Dimensions — must be 1080,1920
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$PROD_DIR/final/short.mp4"

# Duration — must be 18-22s
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$PROD_DIR/final/short.mp4"

# Visual spot checks
ffmpeg -y -ss 1 -i "$PROD_DIR/final/short.mp4" -frames:v 1 -update 1 /tmp/check-hook.jpg 2>/dev/null
ffmpeg -y -ss 10 -i "$PROD_DIR/final/short.mp4" -frames:v 1 -update 1 /tmp/check-broll.jpg 2>/dev/null
ffmpeg -y -ss 18 -i "$PROD_DIR/final/short.mp4" -frames:v 1 -update 1 /tmp/check-cta.jpg 2>/dev/null
open /tmp/check-hook.jpg /tmp/check-broll.jpg /tmp/check-cta.jpg
```

Checklist:
- [ ] 1080×1920
- [ ] 18-22s duration
- [ ] t=1: avatar visible at bottom, no b-roll (dark top zone)
- [ ] t=10: b-roll in top 60%, keyed avatar at bottom, no green fringe
- [ ] t=18: avatar visible, no b-roll
- [ ] Audio audible throughout

### Step 6.5: First-Frame Check (MANDATORY, added 2026-04-19)

**Why this exists:** VAS-22 shipped with a t=0 frame that was mostly black except the PIP. In social feeds the first frame serves as the in-feed thumbnail — a dark first frame reads as broken and kills hook-through-rate. Previously this was documented only as a Gotcha ("first b-roll clip must start ≤ t=3"); that was a recommendation, not a gate. Now it is a gate.

**Required check** (fail-fast, do NOT skip):

```bash
# Global max pixel at t=0 — must be > 0x30
MAX_ALL=$(ffmpeg -ss 0 -i "$PROD_DIR/final/short.mp4" -frames:v 1 -f rawvideo -pix_fmt rgb24 - 2>/dev/null \
  | python3 -c "import sys; d=sys.stdin.buffer.read(1080*1920*3); print(max(d))")

# B-roll-zone max pixel at t=0 (crop above the PIP) — must also be > 0x30
# This guards against the PIP avatar contributing bright pixels while the b-roll canvas is black
MAX_BROLL=$(ffmpeg -ss 0 -i "$PROD_DIR/final/short.mp4" -vf "crop=1080:1380:0:0" -frames:v 1 -f rawvideo -pix_fmt rgb24 - 2>/dev/null \
  | python3 -c "import sys; d=sys.stdin.buffer.read(1080*1380*3); print(max(d))")

if [ "$MAX_BROLL" -le 48 ]; then
  echo "FAIL: first-frame b-roll zone is a dark/solid canvas (max pixel $MAX_BROLL ≤ 0x30)"
  echo "Fix options:"
  echo "  A) Re-author Remotion scenes so frame 0 has visible content (no fade-in from black)"
  echo "  B) Prepend a 0.5s still-frame cover card sourced from t=3 of the b-roll"
  exit 1
fi
```

**How to fix on failure:**

- **Option A (preferred):** Remotion scenes must render visible content at frame 0. Do not fade in from a black or navy canvas — start visible and animate *away* from a visible state. Background cards/labels should be present at frame 0 even if text animates in.
- **Option B (fallback):** Prepend a 0.5s still-frame card using a known-good b-roll frame. Extract frame at t=3 of the first beat, save as `production/first-frame-card.png`, build a 0.5s clip, and concat before the main composite.

### Step 7: Log to MemPalace

```
mempalace_add_drawer(
  wing: "gsai",
  room: "productions",
  name: "{ORD_ID}",
  content: "ORD: {ORD_ID} — p-growthguide-avatar-broll (2026-04-17)
STATUS: done
SCRIPT: {first 60 chars}...
AVATAR: Cozy Tech Guru ({lookId}) — cache {hit|miss}
BROLL: {theme} × {n} clips
OUTPUT: {output_path}
DURATION: {duration}s
LESSONS: {any gotchas encountered}"
)
```

## FFmpeg Filter Reference

```bash
# Canvas: 1080x1920, brand navy
color=c=0x0F172A:s=1080x1920:d={DUR},format=yuv420p[canvas];

# Avatar chain — branch on nativeAspectOutput from brand.yaml.heygen.preferredAvatar:
#
# PATH A — Landscape (16:9) avatar (nativeAspectOutput: "16:9" or absent):
#   1.15x zoom-crop removes chair arms, then colorkey, scale to PIP width
[{avatar_idx}:v]
  scale=2208:1242,crop=1920:1080:144:0,
  colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01,
  scale=1080:-1[avatar_keyed];
#
# PATH B — Square (1:1) avatar (nativeAspectOutput: "1:1", e.g. Vas-Sq-0417-101 1280x1280):
#   Skip landscape zoom-crop — it distorts square input. Colorkey then scale directly to PIP size.
#   The PIP is 540x540 so scale=540:540 fits exactly. No chair-arm crop needed for square.
[{avatar_idx}:v]
  colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01,
  scale=540:540[avatar_keyed];

# B-roll clip: scale-fill top 60% zone (1080x1152, no letterbox)
[{br_idx}:v]trim=start={CLIP_START}:end={CLIP_END},setpts=PTS-STARTPTS+{T_START}/TB,
  scale=-2:1152,crop=1080:1152,format=yuv420p[br{N}];

# Compose: canvas → b-roll segments (timed) → avatar LAST (always on top)
[canvas][br1]overlay=0:0:enable='between(t,{T1},{T1_END})'[l1];
[l1][br2]overlay=0:0:enable='between(t,{T2},{T2_END})'[l2];
...
[lN][avatar_keyed]overlay=0:(H-h),format=yuv420p[vout]
```

## Gotchas

| Issue | Fix |
|-------|-----|
| `MOVIO_PAYMENT_INSUFFICIENT_CREDIT` on direct API call | Expected — subprocess agents cannot render. Use human-in-loop flow (Step 2b–2e). Do NOT retry. |
| No `heygen_video_id` in wake payload | Skill halts at Step 2d. Do NOT invent an id, do NOT fall back to placeholder. |
| `chromakey` filter missing | Use `colorkey` — our ffmpeg build lacks chromakey |
| Never sample green hex | ALWAYS hardcode `0x00FF00` — never sample from video |
| HeyGen renders landscape by default | Request aspect 16:9 then center-crop to square PIP in composite |
| Square/portrait-native avatar ignores orientation toggle | Check `brand.yaml.heygen.preferredAvatar.nativeAspectOutput` — if "1:1" or "9:16", use PATH B ffmpeg chain (no zoom-crop). VAS-20. |
| Avatar IV costs 20% more credits | Request Avatar III motion engine in `heygen-request` payload |
| Dark first frame on social feeds | **MANDATORY — see "First-Frame Check" below.** Not just a warning anymore; the pipeline MUST enforce `MAX_BROLL > 0x30` on the y=0–1380 zone at t=0 and fail-fast otherwise. |
| White bg instead of green | Human renderer must set `#00FF00` — include in request payload |
| Re-render burns ~8 credits | Always check cache before posting `heygen-request` |

## Credits Budget

- Cozy Tech Guru (photo avatar): ~8 `premium_credits` per 20s render (web UI / OAuth pool)
- Monthly pool: 86 `premium_credits` = ~10 renders/month
- `api_credits` pool (REST API): **0** — subprocess agents CANNOT render from this pool
- Cache protects on: re-runs, composition tweaks, b-roll swaps (no HeyGen call)
- Re-render ONLY when: script changes, look changes
- Every cache miss = one human-in-loop cycle (Discord ping + manual render). Budget time, not just credits.
