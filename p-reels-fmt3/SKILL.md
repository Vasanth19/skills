---
name: p-reels-fmt3
description: Turn a topic or script into a full vertical reel combining a HeyGen talking head with Remotion or HyperFrames b-roll/animation. Trigger on "make a full reel from this topic", "script to talking-head reel with brolls", "generate an avatar video with animated b-roll", "full produced short from a script".
when-to-use: Use when the user gives a topic or script and wants a complete reel assembled from a HeyGen talking head PLUS rendered b-roll/animation (Remotion and/or HyperFrames).
version: 0.2.0
kind: pipeline
visibility: catalog
produces:
  dish: Avatar + Animation Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script]
dependsOn: [c-script, t-heygen, f-remotion, f-hyperframes, c-ffmpeg, c-broll]
---

# p-reels-fmt3 — Avatar + Animation Reel

A vertical 9:16 reel that **alternates** between an avatar talking-head segment and a
full-frame animation / b-roll segment: `avatar → animation → avatar → animation → avatar
→ outro`. Avatar audio plays over the avatar segments; the animation segments are silent
(or carry their own clip audio). Sibling of `p-alternating-visual` (which keeps continuous
avatar audio and overlays visuals on top); fmt3 instead **cuts** between full-frame avatar
and full-frame animation segments — simpler, ffmpeg-only, no Remotion required.

**Proven basis:** `p-alternating-visual/SKILL.md` (avatar↔visual alternation) +
`c-ffmpeg/SKILL.md` (chroma/layout/concat) + `c-broll/SKILL.md` (clip sourcing). Verified
end-to-end 2026-05-27 — see **Verified render** below.

## When to Use

- A script/topic that benefits from cutting between a person explaining and animated
  visuals illustrating the point.
- You want a fast, deterministic ffmpeg assembly (no Remotion project setup).
- Duration 30-60s.

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `avatar` | Yes | — | Talking-head MP4 (with audio). HeyGen render, or any reused avatar clip. |
| `animation_clips[]` | Yes | — | 3-5 animation / b-roll MP4s (AI clips, motion gfx). Source from `creatives/brolls/ai/` + `gfx/` or generate via `c-broll`. |
| `outro` | No | — | Brand outro MP4 (e.g. `brand-assets/outros/<brand>-outro-vertical-5s.mp4`). |
| `avatar_layout` | No | `letterbox` | `letterbox` (avatar centered on navy canvas) or `fill` (scale-to-cover + crop) or `pip` (avatar PIP over an animation). |
| `target_duration` | No | 30-45s | Final reel length. |
| `bg_color` | No | `0x0F172A` | Dark-navy canvas behind a letterboxed avatar. |
| `captions` | No | off | Burn SRT captions on avatar segments (optional — see Captions). |
| `topic` / `script` | Conditional | — | If producing a fresh avatar via `t-heygen`, the script source (use `c-script` to write/clean). For a reused avatar, not needed. |

## Output

One 9:16 (1080×1920) H.264 + AAC MP4: avatar talking-head segments intercut with full-frame
animation/b-roll segments, optional brand outro. Path:
`{production}/final/avatar-animation-reel.mp4` (or a caller-specified path).

## Recipe (alternating-segment assembly)

All segments are normalized to a **common spec** before concat: `1080×1920, 30fps, SAR 1,
yuv420p, AAC stereo 48 kHz`. Identical specs make the concat clean (and allow stream-copy
concat if you skip the final re-encode).

Set up variables:

```bash
AVATAR="<path to avatar mp4>"
OUTRO="<path to outro mp4 or empty>"
WORK="{production}/interim/fmt3" ; mkdir -p "$WORK"
OUT="{production}/final/avatar-animation-reel.mp4" ; mkdir -p "$(dirname "$OUT")"
BG="0x0F172A"
```

### Step 1 — Source the avatar

Reuse an existing avatar render (no new HeyGen credits) OR produce one via `t-heygen`
(`c-script` to write the script first). The avatar may be any aspect — it gets normalized in
Step 3. Note its duration (`ffprobe -v error -show_entries format=duration -of csv=p=0 "$AVATAR"`).

### Step 2 — Source the animation / b-roll clips

Pick 3-5 clips from `{brand_path}/creatives/brolls/ai/` (AI/animated `pr-clip-*.mp4`) and
`/gfx/`, or generate via `c-broll`. **Always check `brolls/` before generating** (c-broll
rule). These clips are typically silent — Step 4 adds a silent audio track so concat keeps
A/V aligned.

### Step 3 — Build avatar segments (`letterbox` default)

Cut the avatar into N talking chunks (N = number of animation clips), each scaled to 1080
width and centered on a navy canvas with audio preserved. Use **output-level seeking with
audio kept** (c-ffmpeg rule #3: audio travels with each segment):

```bash
avatar_seg () {  # start dur out
  ffmpeg -y -ss "$1" -t "$2" -i "$AVATAR" \
    -vf "scale=1080:-2,pad=1080:1920:0:(1920-ih)/2:color=$BG,setsar=1,fps=30" \
    -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 "$3"
}
avatar_seg 0    6.5 "$WORK/av1.mp4"
avatar_seg 9    6.5 "$WORK/av2.mp4"
avatar_seg 18   6.5 "$WORK/av3.mp4"
```

Pick chunk windows that land on natural sentence boundaries; leave gaps (the skipped seconds)
so the alternation feels like cuts between thoughts. `fill` layout instead:
`scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920` (crops the avatar to
fill — only if the framing survives a center crop). `pip` layout: overlay the keyed avatar as
a corner PIP on an animation segment (see `c-ffmpeg` references/portrait-layouts.md).

### Step 4 — Build animation segments (full-frame, silent audio added)

Scale each clip to **cover** 1080×1920, center-crop, add a silent stereo track so every
segment has both streams:

```bash
broll_seg () {  # src out [dur]
  local dur="${3:-4}"
  ffmpeg -y -i "$1" -f lavfi -t "$dur" -i anullsrc=channel_layout=stereo:sample_rate=48000 \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
    -map 0:v:0 -map 1:a:0 -shortest \
    -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 "$2"
}
broll_seg "$AID/pr-clip-01-tunnel.mp4" "$WORK/br1.mp4"
broll_seg "$AID/pr-clip-03-glow.mp4"   "$WORK/br2.mp4"
broll_seg "$AID/pr-clip-05-colony.mp4" "$WORK/br3.mp4"
```

If a clip has its own audio you want to keep, drop the `anullsrc` input and `-map 1:a:0`,
and instead `-map 0:a:0?` (the `?` tolerates clips with no audio).

### Step 5 — Normalize the outro (if any)

```bash
ffmpeg -y -i "$OUTRO" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 "$WORK/outro.mp4"
```

### Step 6 — Concat in alternating order

Order: `av1 → br1 → av2 → br2 → av3 → br3 → outro`. Since all segments share the common spec,
the filter-concat re-encode is robust (handles any residual timebase differences):

```bash
ffmpeg -y \
  -i "$WORK/av1.mp4" -i "$WORK/br1.mp4" -i "$WORK/av2.mp4" -i "$WORK/br2.mp4" \
  -i "$WORK/av3.mp4" -i "$WORK/br3.mp4" -i "$WORK/outro.mp4" \
  -filter_complex "[0:v][0:a][1:v][1:a][2:v][2:a][3:v][3:a][4:v][4:a][5:v][5:a][6:v][6:a]concat=n=7:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 \
  -movflags +faststart "$OUT"
```

(If you skip the outro, use `n=6` and drop the last input + its `[6:v][6:a]` pair.)

### Step 7 — Captions (optional)

Burn captions only on avatar segments before Step 6 (the talking parts have speech). Generate
an SRT from the avatar audio (MLX Whisper, per `c-broll` SRT-first workflow), then add
`subtitles=av.srt:force_style='Alignment=2,FontSize=42,MarginV=120'` to each avatar segment's
`-vf` chain. Skipped here for the format preview.

### Step 8 — Verify (mandatory, c-ffmpeg delivery rule)

```bash
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height,channels,r_frame_rate -of json "$OUT"
ffmpeg -v error -i "$OUT" -f null -    # full decode → must report zero errors
```

Confirm: 1080×1920, video **and** audio stream present, duration in target range, decode
clean. Pull sample frames at an avatar timestamp and an animation timestamp to eyeball the
alternation (`ffmpeg -ss <t> -i "$OUT" -vframes 1 frame.jpg`).

## Verified render (2026-05-27)

First successful end-to-end run (format preview — topical match not required):

- **Output:** `/Users/vasanth/vasanth-hq/mr-growth-guide/creatives/tests/reels-preview-2026-05-27/fmt3/avatar-animation-reel.mp4`
- **Spec:** 1080×1920, 30fps, H.264 + AAC stereo, **36.65s**, ~14.9 MB. Full decode: zero errors.
- **Avatar (reused, no HeyGen credits):** `…/productions/ord-20260502-003-mgg-day11-built-brief-makecom/heygen/avatar_1.1x.mp4` (1280×720, 27.16s) — sliced into 3 × 6.5s talking chunks (0-6.5s, 9-15.5s, 18-24.5s), letterboxed centered on `#0F172A`.
- **Animation:** `creatives/brolls/ai/` AI clips `pr-clip-01-tunnel`, `pr-clip-03-glow`, `pr-clip-05-colony` (834×1112, 4s each, silent) → scaled-to-cover + center-cropped to full-frame 1080×1920, silent stereo track added.
- **Outro:** `brand-assets/outros/mgg-outro-vertical-5s.mp4` (already 1080×1920, 5s).
- **Segment structure:** `avatar(6.5s) → animation(4s) → avatar(6.5s) → animation(4s) → avatar(6.5s) → animation(4s) → outro(5s)` = 7 segments, 36.65s.
- **Note:** the `gfx/` folder was empty (`.DS_Store` only) — all animation came from `ai/`. Avatar source had a white room background within its own 16:9 frame, so letterbox bars show navy top/bottom with the avatar's own white room behind it. For a cleaner navy-only avatar background, source a green-screen HeyGen render and chroma-key per `p-alternating-visual/segments.md` before the pad step.

## Notes & gotchas

- **Common-spec normalization is the whole trick.** Mismatched fps / SAR / audio layout is the
  usual concat failure — normalize every segment to 1080×1920 / 30fps / SAR 1 / AAC stereo
  48 kHz first, then concat is trivial.
- **Audio travels with the avatar segment** (c-ffmpeg rule #3 — never strip then re-add one
  global audio strip; drift accumulates). Animation segments get a generated silent track.
- **No `#` comments inside `filter_complex`** (c-ffmpeg rule #4) — if a command grows complex,
  save it as a `.sh`.
- **Reuse before you render.** Check `creatives/brolls/` (and any prior avatar render) before
  generating new assets or calling HeyGen.
- **HeyGen path (fresh avatar):** if no reusable avatar exists, `c-script` → `t-heygen`
  (green-screen, 9:16 1080×1920) → chroma-key per `p-alternating-visual/segments.md` →
  Step 3. Prefer the `mcp`/`api` HeyGen modes only when credits are a concern; otherwise the
  `human` continuous-render mode is cheapest.
- **Remotion / HyperFrames variant:** this recipe uses pre-rendered animation clips. To
  generate bespoke motion-graphic segments instead, render them via `f-remotion` /
  `f-hyperframes` to 1080×1920 MP4s and feed them as `animation_clips[]` into Step 4.
