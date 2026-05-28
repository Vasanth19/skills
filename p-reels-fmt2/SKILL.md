---
name: p-reels-fmt2
description: Make a vertical reel from a full-frame rich-graphics background (animated HyperFrames/Remotion charts/figures/diagrams; b-roll optional supplement) plus a HeyGen talking-head avatar, composited as a bottom picture-in-picture. Trigger on "make a reel with an avatar over graphics", "make a reel with an avatar over brolls", "brolls with a talking head PIP", "HeyGen avatar reel with rich-graphics background", "bottom-avatar short".
when-to-use: Use when the user wants a full-frame animated-graphics (or b-roll) background with a HeyGen-generated talking head as a picture-in-picture overlay in a vertical (9:16) reel.
version: 1.1.0
kind: pipeline
visibility: catalog
produces:
  dish: Avatar PIP Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script, broll]
dependsOn: [t-heygen, c-ffmpeg, c-broll]
---

# p-reels-fmt2 — Rich-Graphics Background + HeyGen Talking Head → PIP Vertical Reel

Produces one 9:16 (1080×1920) MP4 reel: a **full-frame rich-graphics background** (animated
HyperFrames/Remotion charts, figures, diagrams, VFX) with a HeyGen talking-head avatar composited
as a rounded square picture-in-picture pinned flush bottom-center, the avatar's own voice as the
audio bed, and an optional brand outro appended.

**Background = rich motion graphics, NOT flat random clips.** The full-frame layer behind the PIP
must be authored HyperFrames/Remotion graphics (animated counters, bar charts, flow diagrams, ghost
watermarks, glow/grid ambient layers) matching the brand graphics bar — see the reference
compositions in `f-hyperframes` and the MGG productions. Library b-roll may *supplement* a
graphics-forward background but must never be the whole bed.

**Two hard rules for the background (both fixed in v3, 2026-05-27):**
1. **Scale-to-COVER, never pad/letterbox/stretch.** Whatever the source (graphics render or b-roll),
   it must fill the full 1080×1920 canvas and crop the overflow — never pillarbox, never distort:
   `scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920`. (In v2 the background was
   stretched and didn't fill the phone width — `force_original_aspect_ratio=increase` + `crop` is
   the fix. Do NOT use `pad`, `force_original_aspect_ratio=decrease`, or a bare `scale=1080:1920`
   that distorts a landscape source.)
2. **Graphics-forward.** Generate the background as HyperFrames/Remotion (see Step 2 below). A
   1080×1920 HyperFrames render is already 9:16 so the cover-crop is a no-op for it — the filter
   still applies for any supplemental landscape b-roll.

This recipe is the **same ffmpeg compositing path** that `p-bottom-avatar-pip` runs end-to-end
(ffmpeg PIP — **NOT Remotion**). The difference is the framing: this format is the longer
"reel" variant (30-60s) with b-roll that fills the full frame, where `p-bottom-avatar-pip` is the
20s Shorts recipe. Read `p-bottom-avatar-pip/brand-params.md` for the canonical PIP geometry and
`c-ffmpeg/references/portrait-layouts.md` for the filter primitives.

**Verified (v3):** 2026-05-27 — rendered end-to-end with a HyperFrames rich-graphics background
(4-scene: title → animated counters → bar chart → flow diagram) scale-to-COVERed full-frame, a
reused MGG avatar PIP (no new HeyGen credits), and the brand outro appended. Reference output:
`mr-growth-guide/creatives/tests/reels-preview-2026-05-27/fmt2-v3/avatar-pip-reel-v3.mp4`
(32.17s, 1080×1920, H.264 yuv420p, AAC stereo 48k; bg fills full width, no bars/stretch, PIP over it).
The HyperFrames source is in that folder's `work/bg-graphics/index.html`.

## Inputs

- `bg_graphics` — the full-frame background. **Default: author rich HyperFrames/Remotion motion
  graphics** (animated charts/figures/diagrams/VFX) at native 1080×1920, then render to MP4 (see
  Step 2). Match the brand graphics bar (palette navy `#0f172a` / green `#22c55e` / light `#f1f5f9`;
  reference compositions in `f-hyperframes`).
- `broll_media[]` (optional supplement) — b-roll clips and/or AI stills to *supplement* a
  graphics-forward background (landscape recordings, AI clips, or screenshots; this recipe
  scale-to-covers them into 9:16). Never the whole bed on its own.
- `avatar_video` — a talking-head video (HeyGen-rendered, or any existing talking head). When
  driving from a script instead, render via `t-heygen` first (mode table:
  `p-bottom-avatar-pip/heygen-workflow.md`). **Reuse a cached render when available — never burn
  HeyGen credits for a layout change.**
- `outro` (optional) — brand outro clip to append (must carry audio).
- `pip_spec` (optional) — defaults to the proven bottom-center placement below.

## Parameter Table

| Parameter | Default | Notes |
|---|---|---|
| Canvas | 1080×1920, 25 fps | 9:16 portrait |
| Canvas color | `#0F172A` (dark navy) | Shows through only where b-roll has letterbox gaps |
| Background | rich HyperFrames/Remotion motion graphics, full-frame | Animated charts/figures/diagrams/VFX matching the brand bar (palette navy/green/light). Library b-roll may supplement but graphics-forward. |
| Background fit | scale-to-COVER + center crop | `scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920` — fills the full frame, no pillarbox, no stretch. **Never `pad`/letterbox, never a distorting bare `scale=1080:1920`.** (v3 fix) |
| Avatar background | auto-detect (see Step 3) | Green `#00FF00` → chroma-key out; opaque (studio/white) → keep, show in square PIP card |
| Chroma-key (green only) | `colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01` | Two-pass. `chromakey` filter is NOT in this build — use `colorkey`. Skip entirely for opaque avatars. |
| Avatar square crop | `crop=S:S:Xoff:0` | `S = min(w,h)`, `Xoff = (w-S)/2` — face-weighted center crop. ffprobe the avatar first; HeyGen renders 1280×720 or 1920×1080. |
| PIP size | 540×540, rounded corners r=54 | Masked via reusable `pip-mask-540.png` (RGBA alpha) |
| PIP position | `overlay=270:1380` | Bottom-center on 1080×1920 |
| Audio | avatar's own track | stereo, 48 kHz, AAC 192k |
| Outro | optional, appended | Normalize to 1080×1920 / 25fps / stereo 48k first; concat via **filter** not demuxer |
| Target duration | 30-45s | Driven by avatar length + outro; trim/extend b-roll to cover |
| Encode | H.264, yuv420p, CRF 19, `+faststart` | |

## PIP mask (reuse, don't regenerate)

The 540×540 rounded-corner alpha mask is identical for every reel. Reuse an existing one:
```bash
find <brand>/creatives/productions -name "pip-mask-540.png" | head -1
```
If none exists, generate once with PIL (540×540 RGBA, white rounded rect r=54 on transparent).

## Steps

Set `$AV` = avatar video, `$OUT` = final path, `$W` = a scratch `work/` dir, `$MASK` = pip mask.

1. **Receive / render avatar.** Reuse an existing talking-head render if given (no HeyGen call).
   To drive from a script: `t-heygen` per `p-bottom-avatar-pip/heygen-workflow.md`. ffprobe the
   avatar for `width,height,duration` — this drives the crop math and the b-roll coverage length.

2. **Build the rich-graphics background (graphics-forward).** Author a full-frame 1080×1920
   HyperFrames composition (or Remotion scene set) of animated graphics — counters, bar charts,
   flow diagrams, ghost watermark, glow + grid ambient layers — matching the brand bar (palette
   navy `#0f172a` / green `#22c55e` / light `#f1f5f9`; reference: the `ord-*-mgg-4s-hf-promo`
   `hyperframes/index.html` and the `why-gsai` Remotion scenes). Make it **≥ avatar duration**; the
   composite trims to the avatar via `shortest=1`. Keep all real content in the **top ~65%** of the
   frame (above y≈1340) — the PIP card occupies the bottom-center 540×540 zone at `overlay=270:1380`.

   - **Author + lint + render** (HyperFrames):
     ```bash
     npx hyperframes init bg-graphics --non-interactive   # then author index.html
     npx hyperframes lint                                  # 0 errors required
     npx hyperframes render --output bg-graphics.mp4 --quality high --fps 25
     ```
     **Font gotcha:** the compiler resolves `font-family` literally — do NOT put `var(--font-*)` in
     `font-family` (it falls back to a generic face). Use a mapped name (`'Oswald'`, `'JetBrains Mono'`,
     `'Inter'`, `'Montserrat'`, …) directly in the `font-family` value.
   - A native 1080×1920 graphics render is already 9:16 — the cover-crop below is a no-op for it.
   - **Supplemental b-roll only** (optional, never the whole bed): cut windows and scale-to-COVER
     into 9:16, normalize to 25fps, strip audio, then concat with the graphics:
     ```bash
     ffmpeg -ss 2 -t 7 -i "$CLIP" \
       -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=25,format=yuv420p" \
       -an -c:v libx264 -preset medium -crf 20 -y "$W/bgNN.mp4"
     ```
   The final background is `$W/bg-all.mp4` (the graphics render, optionally concatenated with
   supplemental b-roll via demuxer `-c copy` when codecs match).

3. **Detect avatar background, branch chroma-key.** Sample edge pixels at a mid frame
   (`p-bottom-avatar-pip/brand-params.md` § "Avatar Background Detection"):
   - Dominant edge ≈ `#00FF00` → `bg_type=green_screen`: add the two-pass `colorkey` to the avatar
     filter chain before scaling.
   - Anything else (studio/white/cream) → `bg_type=opaque`: **skip chroma-key**; the avatar shows
     as-is inside the square PIP card. Never halt on a non-green background.

4. **Composite PIP over background.** Crop the avatar square (face-weighted), scale to 540×540,
   alphamerge the rounded mask, overlay bottom-center, map the avatar's audio. Opaque-avatar form
   (insert the `colorkey=...,` chain right after `[1:v]` for green-screen sources):
   ```bash
   ffmpeg -i "$W/bg-all.mp4" -i "$AV" -i "$MASK" \
     -filter_complex "\
   [1:v]crop=720:720:280:0,scale=540:540,setsar=1[avsq]; \
   [avsq][2:v]alphamerge[avpip]; \
   [0:v]format=yuv420p[bg]; \
   [bg][avpip]overlay=270:1380:format=auto:shortest=1[v]" \
     -map "[v]" -map "1:a" \
     -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 25 \
     -c:a aac -b:a 192k -ar 48000 -ac 2 \
     -movflags +faststart -y "$W/composed.mp4"
   ```
   (Crop `720:720:280` is for a 1280×720 avatar — recompute `S`/`Xoff` from the ffprobe in step 1.)

5. **Captions (optional).** Burn word-level captions over `$W/composed.mp4` via `c-ffmpeg` if a
   transcript/SRT is available. Skipped for layout previews.

6. **Append outro (optional).** Normalize the outro to match the composite, then concat via the
   **filter** (demuxer `-c copy` causes channel-config jitter at the boundary):
   ```bash
   ffmpeg -i "$OUTRO" -vf "scale=1080:1920,setsar=1,fps=25,format=yuv420p" \
     -af "aformat=sample_rates=48000:channel_layouts=stereo" \
     -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 25 -fps_mode cfr \
     -c:a aac -b:a 192k -ar 48000 -ac 2 -y "$W/outro-norm.mp4"

   ffmpeg -i "$W/composed.mp4" -i "$W/outro-norm.mp4" \
     -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]" \
     -map "[v]" -map "[a]" \
     -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 25 \
     -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart -y "$OUT"
   ```
   No outro → `$W/composed.mp4` is the final.

7. **Verify (ffprobe).** Confirm 1080×1920, h264/yuv420p, aac stereo 48k, expected duration, and
   that the outro tail carries audio (`mean_volume > -60 dB`):
   ```bash
   ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1 "$OUT"
   ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels -of default=noprint_wrappers=1 "$OUT"
   ffmpeg -sseof -4 -i "$OUT" -af volumedetect -f null - 2>&1 | grep mean_volume
   ```

## Output

One 9:16 (1080×1920) H.264 MP4: full-frame b-roll background, rounded square talking-head PIP
pinned bottom-center, avatar audio bed, optional captions + outro.

## Notes & gotchas

- **Background is RICH motion graphics, not flat clips.** Author HyperFrames/Remotion (animated
  charts/figures/diagrams) matching the brand bar; supplement with b-roll only if needed.
- **Scale-to-COVER, never pad/stretch.** `scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920`.
  A bare `scale=1080:1920` distorts landscape sources; `pad` / `force_original_aspect_ratio=decrease`
  letterboxes. Both are wrong — the bg must fill the full phone width and crop the overflow.
- **HyperFrames font gotcha:** never use `var(--font-*)` inside a `font-family` value — the compiler
  resolves it literally and falls back to a generic face. Use a mapped name (`'Oswald'`, `'JetBrains Mono'`).
- **No `#` comments inside `filter_complex`** — parse error. Save complex graphs as `.sh` if long.
- **Avatar is the audio + duration master.** `shortest=1` on the overlay clips the composite to the
  avatar; ensure b-roll background is at least as long.
- **Opaque vs green-screen is auto-detected, not assumed.** A studio/white-room HeyGen render is
  valid — it just keeps its background inside the PIP card.
- **Reuse `pip-mask-540.png`** across productions (PIL may not be on PATH).
- **Relationship to `p-bottom-avatar-pip`:** same compositing engine, different framing (30-60s reel
  vs 20s Short, full-cover b-roll vs the Shorts safe-zone layout). This recipe does not subsume that
  one; both share the proven ffmpeg path documented in `c-ffmpeg/references/portrait-layouts.md`.
