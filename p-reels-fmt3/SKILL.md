---
name: p-reels-fmt3
description: Turn a topic or script into a full vertical reel where a HeyGen avatar narrates CONTINUOUSLY (its audio is the single never-interrupted voice bed) while rich full-frame HyperFrames/Remotion graphics periodically take over the picture. Trigger on "make a full reel from this topic", "script to talking-head reel with animated graphics", "generate an avatar video with animated b-roll", "full produced short from a script", "avatar + animation reel".
when-to-use: Use when the user gives a topic or script and wants a complete reel where the avatar's voiceover never stops (continuous audio bed) and rich animated full-frame graphics (HyperFrames and/or Remotion) periodically take over the frame on top of the avatar.
version: 0.4.0
kind: pipeline
visibility: catalog
produces:
  dish: Avatar + Animation Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script]
dependsOn: [c-script, c-heygen, f-remotion, f-hyperframes, c-ffmpeg, c-broll]
---

# p-reels-fmt3 — Avatar + Animation Reel (continuous-audio bed)

A vertical 9:16 reel built on **one continuous voice bed**: the avatar's narration audio
plays unbroken for the entire reel and is **never cut or silenced**. Visually it alternates —
the avatar talking-head is shown, then a rich full-frame animation/graphics segment **takes
over the whole picture** (covering the avatar visually) — but underneath, the avatar's audio
keeps playing the whole time. Think of the avatar as always "playing in the background"
(audio), with rich full-frame HyperFrames/Remotion graphics periodically taking over the
frame on top of it.

```
audio:   ████████████████████████████████████████████████  ← avatar VO, ONE unbroken bed
video:   [avatar][== GFX ==][avatar][== GFX ==][avatar][GFX]  +  [outro]
                  takeover            takeover           takeover
```

**The whole trick:** keep the avatar as a single base layer (video+audio) for its full
duration, then **overlay** the graphics on top during "takeover windows" using ffmpeg
`overlay=enable='between(t,a,b)'`. The avatar audio is loudnormed **once** at the start and
passed straight through to the final mux — it is the only audio source, so there is physically
no way for it to gap. This is the v3 fix for the v2 bug (v2 *cut* between full-frame avatar
and full-frame silent animation segments, so narration stopped during the animation — wrong).

**Proven basis:** `p-alternating-visual/SKILL.md` (continuous avatar audio + overlaid visuals)
+ `c-ffmpeg/SKILL.md` (chroma/layout/overlay/concat) + `f-hyperframes` (rich graphics) +
`c-broll/SKILL.md` (supplemental clip sourcing). Verified end-to-end 2026-05-27 — see
**Verified render** below.

## ⚠️ The one rule that defines fmt3

**The avatar narration audio is the single, never-interrupted voice bed.** Graphics take over
the *picture*, never the *sound*. If at any timestamp during a graphics takeover the audio
track is silent, the reel is broken. Verify with `astats`/`volumedetect` on the takeover
windows (see Step 7) — the avatar VO must be present across the entire duration.

## When to Use

- A script/topic where a person explains and rich animated graphics illustrate the point —
  **without the voiceover ever stopping**.
- You want the avatar's narration to carry the whole reel as one unbroken audio bed.
- You want rich, on-brand motion graphics (charts/figures/diagrams/VFX), not flat clips.
- Duration 30-60s.

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `avatar` | Yes | — | Talking-head MP4 (with audio). HeyGen render, or any reused avatar clip. **Its audio is the continuous voice bed for the whole reel.** Reused 16:9 studio renders often carry baked-in **white/cream side bands** (the studio room frame) — Step 1.5 detects and crops them (left/right only, never the top) before the avatar becomes the base layer. |
| `gfx_segments[]` | Yes | — | Rich full-frame animated graphics, 1080×1920, one per takeover window. Prefer HyperFrames/Remotion renders (charts/diagrams/figures/VFX); AI/library clips only as a supplement. |
| `outro` | No | — | Brand outro MP4 (e.g. `brand-assets/outros/<brand>-outro-vertical-5s.mp4`). The ONLY place a different audio is allowed (it's appended after the bed ends). |
| `avatar_layout` | No | `fill` | `fill` (band-clean → scale-to-cover, **default** — person fills the 9:16 frame, no navy bars) or `letterbox` (cleaned avatar centered on navy canvas). |
| `takeover_windows[]` | Yes | — | List of `(start, end)` times during the avatar's runtime when a graphics segment covers the picture. Audio underneath keeps playing. |
| `target_duration` | No | 36-44s | Final reel length (avatar bed + outro). |
| `bg_color` | No | `0x0F172A` | Dark-navy canvas behind a letterboxed avatar (palette navy). |
| `captions` | No | off | Burn SRT captions over the whole bed (optional — see Captions). |
| `topic` / `script` | Conditional | — | If producing a fresh avatar via `c-heygen`, the script source (`c-script`). For a reused avatar, not needed. |

## Output

One 9:16 (1080×1920) H.264 + AAC MP4: the avatar talking-head as a continuous base layer with
its narration playing the entire time, rich full-frame graphics overlaid during takeover
windows, optional brand outro appended. Path:
`{production}/final/avatar-animation-reel.mp4` (or a caller-specified path).

## Recipe (continuous-bed overlay assembly)

The base layer (avatar) and every overlay are normalized to a **common spec**: `1080×1920,
30fps, SAR 1, yuv420p`. The avatar audio is loudnormed **once** and is the sole audio source
through the bed — it cannot gap. Graphics are overlaid with `overlay=enable='between(t,a,b)'`.

Set up variables:

```bash
AVATAR="<path to avatar mp4>"
OUTRO="<path to outro mp4 or empty>"
WORK="{production}/interim/fmt3" ; mkdir -p "$WORK"
OUT="{production}/final/avatar-animation-reel.mp4" ; mkdir -p "$(dirname "$OUT")"
BG="0x0F172A"
```

### Step 1 — Source the avatar (the voice bed)

Reuse an existing avatar render (no new HeyGen credits) OR produce one via `c-heygen`
(`c-script` first). Note its duration — this sets the bed length:
`ffprobe -v error -show_entries format=duration -of csv=p=0 "$AVATAR"`.

Confirm the narration is continuous before building (no long silent stretches you'd be
covering with graphics anyway):

```bash
ffmpeg -hide_banner -i "$AVATAR" -af "silencedetect=noise=-35dB:d=0.5" -f null - 2>&1 \
  | grep -E "silence_(start|end)" || echo "narration continuous"
```

### Step 1.5 — Detect & crop the avatar's white side bands (NEW in v0.4 — do this BEFORE compositing)

Reused 16:9 HeyGen / studio renders frequently carry baked-in **white/cream bands** down the
left and right (the studio-room frame). Shown full-frame those bands are ugly. So before the
avatar becomes the base layer, **measure** the side margins and, if white bands exist, **crop
them off the LEFT and RIGHT only**. **NEVER crop the top** — the head must not be cut (sides,
and bottom if you must, never the top).

**1. Measure — sample thin edge columns vs the centre.** Downscale a 1px-wide region to 1×1 and
read its grey value (the true average luma of that column). Scan from each edge inward to find
where the white band ends and the person/room content begins. A white band reads `luma ≈ 255`;
content reads well below (`< 245`, typically 40–150). Sample at a few timestamps to confirm the
bands are static (they almost always are — they're a baked frame border):

```bash
W=$(ffprobe -v error -select_streams v -show_entries stream=width -of csv=p=0 "$AVATAR")
H=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$AVATAR")
col_luma () {  # x  (returns avg luma 0-255 of a 2px-wide column at the mid-frame)
  v=$(ffmpeg -hide_banner -loglevel error -ss 13 -i "$AVATAR" -vframes 1 \
        -vf "crop=2:$H:$1:0,scale=1:1,format=gray" -f rawvideo - 2>/dev/null | xxd -p)
  echo $((16#$v))
}
LEFT=0;  for x in $(seq 0 5 $((W/2)));    do [ "$(col_luma $x)" -lt 245 ] && { LEFT=$x;  break; }; done
RIGHT=$W; for x in $(seq $((W-2)) -5 $((W/2))); do [ "$(col_luma $x)" -lt 245 ] && { RIGHT=$((x+2)); break; }; done
echo "content spans x=$LEFT … x=$RIGHT  (white bands: left 0–$LEFT, right $RIGHT–$W)"
```

**2. Decide & crop.** If `LEFT > a few px` or `RIGHT < W−few px`, white bands exist → crop to the
content span (**left/right only, full height — y offset stays 0 so the top is untouched**). Round
the crop width to an even number for yuv420p. If `LEFT≈0` **and** `RIGHT≈W`, skip the crop —
no bands:

```bash
CW=$(( RIGHT - LEFT )); CW=$(( CW - CW % 2 ))      # even width
if [ "$LEFT" -gt 4 ] || [ "$RIGHT" -lt $((W-4)) ]; then
  AVATAR_CLEAN="$WORK/avatar-clean.mp4"
  ffmpeg -y -i "$AVATAR" -vf "crop=$CW:$H:$LEFT:0,setsar=1" \
    -c:v libx264 -pix_fmt yuv420p -c:a copy "$AVATAR_CLEAN"   # crop=W:H:X:0  → Y=0 keeps the top
else
  AVATAR_CLEAN="$AVATAR"                                       # no bands — use as-is
fi
```

`crop=$CW:$H:$LEFT:0` — width `CW`, **full source height `$H`**, x-offset `$LEFT`, **y-offset `0`**.
The `0` y-offset is the guarantee that the top edge (and head) is preserved; only the sides are
removed. Verify the new edges are no longer white (`col_luma 2` on the cropped clip should read
content, not 255) and eyeball one frame to confirm the head still has headroom.

> **Worked example (mr-growth-guide `avatar_1.1x.mp4`, v4):** 1280×720 source. Edge scan: content
> spans **x=280…995** (left band 0–280, right band 995–1280, both pure `luma=255`, stable across
> t=1…25s). Crop applied: **`crop=712:720:282:0`** (x=282 trims 2px of anti-aliased fringe, width
> 712 even, full height 720, y=0). Result: no white at the new edges (luma 40–115), head fully
> preserved.

### Step 2 — Build the avatar base (full length, band-clean → scale-to-cover, loudnormed once)

Take the **band-cleaned** avatar (`$AVATAR_CLEAN` from Step 1.5) and normalize the **whole** clip
to 1080×1920. **Default (`fill`):** scale-to-cover so the cleaned person fills the frame (no navy
bars, no white room visible) — because the bands are already gone the cover-crop only trims the
near-square cleaned content symmetrically, and the full source height keeps the head safe.
Loudnorm the audio **once** here so the entire bed has consistent loudness and is never re-touched:

```bash
ffmpeg -y -i "$AVATAR_CLEAN" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 "$WORK/base.mp4"
```

`letterbox` layout instead (cleaned avatar centered on navy, e.g. if cropping made it too tall):
`scale=1080:-2,pad=1080:1920:0:(1920-ih)/2:color=$BG`. Either way the input is the **cleaned**
avatar — never the band-laden original.
**Do not slice the avatar into chunks** — the whole point is one unbroken audio bed. The
talking-head simply shows through whenever no graphics overlay is enabled.

> **Why crop-then-cover (not letterbox the raw 16:9):** v3 letterboxed the raw avatar on navy,
> which left the white studio room visible inside the avatar's own frame (v3's documented
> limitation). v4's Step 1.5 removes the room's white border first, so scale-to-cover yields a
> clean full-frame talking-head with the head intact.

### Step 3 — Generate the rich full-frame graphics (HyperFrames / Remotion)

Author one composition per takeover window. These must be **rich motion graphics matching the
brand bar** — count-up stats, animated charts, figures, diagrams, motion VFX — on the navy
canvas with green/light accents. See `f-hyperframes` (composition authoring) +
`f-hyperframes-cli` (render). Pattern per composition:

```bash
# Author <name>/index.html as a 1080×1920 composition (navy #0f172a, green #22c55e,
# light #f1f5f9), then:
( cd "$WORK/<name>" && npx hyperframes render --output gfx-<name>.mp4 --quality high )
```

For data charts specifically: `hyperframes add data-chart` scaffolds an animated chart
composition you can edit. Author bespoke HTML for figures/diagrams/VFX. Each render is a
1080×1920 MP4 (silent — audio is irrelevant, it's an overlay only). Normalize the spec to
match the base:

```bash
gfx_norm () {  # src out
  ffmpeg -y -i "$1" \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
    -an -c:v libx264 -pix_fmt yuv420p "$2"
}
gfx_norm "$WORK/g1/gfx.mp4" "$WORK/g1.mp4"
gfx_norm "$WORK/g2/gfx.mp4" "$WORK/g2.mp4"
gfx_norm "$WORK/g3/gfx.mp4" "$WORK/g3.mp4"
```

**Library AI clips as a supplement only** — if HyperFrames render fails or you need filler,
fall back to `{brand_path}/creatives/brolls/ai/pr-clip-*.mp4` normalized the same way. A
transparent-PNG/title-card fallback is acceptable but real motion graphics are strongly
preferred.

### Step 4 — Overlay graphics on the bed during takeover windows

This is the core of fmt3. The base supplies **both** the video-when-no-overlay and the
**single audio stream**. Each graphics clip is overlaid only during its window via
`overlay=enable='between(t,a,b)'`. To make the picture cut to the graphic at its window start,
offset each overlay's PTS with `setpts=PTS-STARTPTS+a/TB` so the clip plays from its own t=0
at window start:

```bash
# Windows: g1 6.5–11.5s, g2 15–20s, g3 23.5–27s (within the ~27.16s bed)
ffmpeg -y -i "$WORK/base.mp4" -i "$WORK/g1.mp4" -i "$WORK/g2.mp4" -i "$WORK/g3.mp4" \
  -filter_complex "\
[1:v]setpts=PTS-STARTPTS+6.5/TB[o1]; \
[2:v]setpts=PTS-STARTPTS+15/TB[o2]; \
[3:v]setpts=PTS-STARTPTS+23.5/TB[o3]; \
[0:v][o1]overlay=enable='between(t,6.5,11.5)'[v1]; \
[v1][o2]overlay=enable='between(t,15,20)'[v2]; \
[v2][o3]overlay=enable='between(t,23.5,27)'[vout]" \
  -map "[vout]" -map 0:a \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 \
  -movflags +faststart "$WORK/bed.mp4"
```

`-map 0:a` is the whole guarantee: the final audio is the avatar bed, untouched and unbroken,
regardless of how many graphics overlay the picture. The graphics are full-frame (1080×1920)
so they completely cover the avatar visually during their window.

**No `#` comments inside `filter_complex`** (c-ffmpeg rule #4). If overlay clips are shorter
than their window, either loop them (`-stream_loop`) or trim the window to the clip length.

### Step 5 — Append the outro (concat)

The bed and outro are both video+audio at the common spec, so concat is clean. The outro's
own audio (brand sting) plays after the voice bed ends — that's allowed; the bed itself is
never interrupted:

```bash
# normalize outro to spec first
ffmpeg -y -i "$OUTRO" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 "$WORK/outro.mp4"

ffmpeg -y -i "$WORK/bed.mp4" -i "$WORK/outro.mp4" \
  -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 \
  -movflags +faststart "$OUT"
```

(No outro: `$WORK/bed.mp4` is the final `$OUT`.)

### Step 6 — Captions (optional)

Because the bed is one continuous track, captions span the whole reel. Transcribe the avatar
audio once (`npx hyperframes transcribe`, or MLX Whisper per `c-broll`), then burn over the
bed before Step 5:
`subtitles=av.srt:force_style='Alignment=2,FontSize=42,MarginV=120'`. Skipped for the format
preview.

### Step 7 — Verify (mandatory — includes the continuity proof)

```bash
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height,channels,r_frame_rate -of json "$OUT"
ffmpeg -v error -i "$OUT" -f null -    # full decode → zero errors

# CONTINUITY PROOF — audio must be present during every takeover window:
for w in "6.5 5" "15 5" "23.5 3.5"; do set -- $w; \
  echo "window $1 +$2s:"; \
  ffmpeg -hide_banner -ss "$1" -t "$2" -i "$OUT" -af volumedetect -f null - 2>&1 \
    | grep -E "mean_volume|max_volume"; done
# Each window must report a real (non -inf) mean_volume → the avatar VO is playing under the graphics.
```

Confirm: 1080×1920, video **and** audio present, duration in target range, decode clean, and
**every takeover window shows the avatar VO present** (non-silent). Pull sample frames at an
avatar-visible timestamp and a graphics-takeover timestamp to eyeball the picture alternation
(`ffmpeg -ss <t> -i "$OUT" -vframes 1 frame.jpg`).

## Verified render (v4 — 2026-05-27, continuous-bed + white-band crop)

v4 = v3's continuous-audio-bed technique with the **avatar white-band crop** (Step 1.5) added.
Everything else (continuous VO bed, rich HyperFrames takeovers, overlay windows, outro) is the
proven v3 recipe — this pass only cleans the avatar.

- **Output:** `/Users/vasanth/vasanth-hq/mr-growth-guide/creatives/tests/reels-preview-2026-05-27/fmt3-v4/avatar-animation-reel-v4.mp4`
- **Spec:** 1080×1920, 30fps, H.264 + AAC stereo 48 kHz, **36.59s**, ~7.8 MB. Full decode: zero errors.
- **White-band measurement (Step 1.5):** source `avatar_1.1x.mp4` is 1280×720 with pure-white
  (`luma=255`) bands left **0–280** and right **995–1280**; content spans **x=280…995**, stable
  across t=1…25s. **Crop applied: `crop=712:720:282:0`** (left/right only, **full height 720,
  y=0 → top preserved**; x=282 trims 2px anti-aliased fringe, width 712 even). Cropped edges read
  luma 40–115 (no white). Then scale-to-cover to 1080×1920 (`fill`).
- **Top/head preserved:** y-offset 0 in the crop + full source height + scale-to-cover-on-height;
  spot-frame at 3s confirms full headroom, scalp not clipped, no white at any edge (edge luma 107–138).
- **Avatar / voice bed (reused, no HeyGen credits):** same source as v3 → **band-cropped** →
  scale-to-cover 1080×1920 → **loudnormed once** (`I=-16`) → slowed `setpts/0.86 + atempo=0.86`
  to a **31.57s continuous bed**. `-map 0:a` carries the avatar audio through the overlay pass untouched.
- **Graphics takeovers:** the same three rich HyperFrames compositions rendered for v3
  (g1 bar-chart "OUTPUT TRIPLED" 5s, g2 3-step flow 5s, g3 "70%" VFX 3.2s), re-normalized to spec
  and overlaid full-frame.
- **Overlay windows (over the 31.57s bed):** g1 `8–13s`, g2 `17.5–22.5s`, g3 `27.5–30.7s` via
  `overlay=enable='between(t,a,b)'` + `setpts=PTS-STARTPTS+start/TB`.
- **Outro:** `brand-assets/outros/mgg-outro-vertical-5s.mp4` (1080×1920, 5s) appended via concat.
- **Continuity proof:** `volumedetect` per window — g1 −17.5 dB, g2 −20.6 dB, g3 −17.7 dB, all
  matching the avatar-visible segment (−18.3 dB) → the VO plays at full loudness under every
  graphics takeover. `silencedetect d=0.4` on the final bed flags only ~0.4s pauses at
  13.34/23.84/27.79s — **byte-for-byte identical to the bare base bed** (proven by running
  silencedetect on `base.mp4`: same start/end timestamps), i.e. natural inter-sentence breaths in
  the source speech, NOT gaps introduced by the crop or the overlay. The crop touches video only;
  audio is untouched.

## Verified render (v3 — 2026-05-27, continuous-bed)

v3 end-to-end run proving the continuous-audio-bed technique (format preview — topical match
not required):

- **Output:** `/Users/vasanth/vasanth-hq/mr-growth-guide/creatives/tests/reels-preview-2026-05-27/fmt3-v3/avatar-animation-reel-v3.mp4`
- **Spec:** 1080×1920, 30fps, H.264 + AAC stereo 48 kHz, **36.62s**, ~2.7 MB. Full decode: zero errors.
- **Avatar / voice bed (reused, no HeyGen credits):** `…/ord-20260502-003-mgg-day11-built-brief-makecom/heygen/avatar_1.1x.mp4` (1280×720, 27.16s) → letterboxed on `#0f172a`, **loudnormed once** (`I=-16`), then slowed `setpts/0.86 + atempo=0.86` to a **31.6s continuous bed** (still gap-free at d=0.5). The avatar audio is the sole audio source through the whole bed — `-map 0:a` carries it through the overlay pass untouched.
- **Graphics takeovers (rich HyperFrames, authored fresh):** three 1080×1920 compositions rendered with `npx hyperframes render --quality high` (all lint-clean, 0 warnings):
  - **g1** (5s) — animated bar chart, count-up `12h → 37h`, "OUTPUT TRIPLED", ghost "3X", glow.
  - **g2** (5s) — 3-step numbered flow diagram with flowing connector pulses, "ONE PROMPT. FULL PIPELINE."
  - **g3** (3.2s) — VFX big-stat: `70%` count-up with radial rings + 12-spoke burst, green glow.
  - Palette navy `#0f172a` / green `#22c55e` / light `#f1f5f9`. (Headlines use heavy Inter — auto-resolved by the HyperFrames compiler; Barlow Condensed isn't, so it was swapped to avoid wrong-font fallback.)
- **Overlay windows (over the 31.6s bed):** g1 `8–13s`, g2 `17.5–22.5s`, g3 `27.5–30.7s` via `overlay=enable='between(t,a,b)'` + `setpts=PTS-STARTPTS+start/TB`. Avatar talking-head shows through the rest (0–8, 13–17.5, 22.5–27.5, 30.7–31.6).
- **Outro:** `brand-assets/outros/mgg-outro-vertical-5s.mp4` (1080×1920, 5s) appended via concat.
- **Continuity proof:** `volumedetect` per window — g1 −17.8 dB, g2 −20.8 dB, g3 −17.8 dB, all matching the avatar-visible segments (−17.8 to −19.7 dB) → the VO plays at full loudness under every graphics takeover. `silencedetect d=0.4` flags only ~0.4s pauses at 13.34/23.84/27.80s — **identical to the bare base bed before overlay** (proven by running silencedetect on `base.mp4`), i.e. natural inter-sentence breaths in the source speech, NOT gaps introduced by the technique. The outro sting (−32.3 dB, after the bed ends) is the only different audio.
- **Note (v3 limitation, fixed in v4):** the avatar source has white/cream studio-room bands inside its own 16:9 frame, so v3's letterbox showed the white room behind the navy bars. **v4 fixes this** with Step 1.5 (detect → crop left/right → scale-to-cover) — the person now fills the frame with no white bands. For a navy-only avatar background instead, source a green-screen HeyGen render and chroma-key before the pad step.

## Notes & gotchas

- **The avatar audio is the single voice bed — never cut it.** This is the v3 fix for the v2
  bug (v2 *concatenated* full-frame avatar segments with full-frame silent animation segments,
  so the narration stopped during animation). In v3 the avatar is ONE continuous base layer;
  graphics overlay the *picture* via `overlay=enable='between(t,a,b)'` while `-map 0:a` keeps
  the avatar audio flowing. There is physically no way to gap the audio because there is only
  one audio source through the entire bed.
- **Loudnorm the bed ONCE** (Step 2). Don't re-apply loudnorm/atempo on later passes — it
  recompresses and can introduce pumping. The overlay pass (Step 4) copies audio through.
- **Graphics must fully cover the frame** (1080×1920) during their window, or the avatar will
  show through underneath. Scale-to-cover + center-crop; verify the composition canvas is
  exactly 1080×1920.
- **Common-spec normalization** still matters for the outro concat — 1080×1920 / 30fps / SAR 1
  / AAC stereo 48 kHz on both the bed and the outro.
- **No `#` comments inside `filter_complex`** (c-ffmpeg rule #4) — if a command grows complex,
  save it as a `.sh`.
- **Rich graphics > flat clips.** The takeover segments are the visual payload — author real
  HyperFrames/Remotion motion graphics (count-up stats, animated charts, figures, diagrams,
  VFX). Library AI clips are a supplement/fallback only.
- **Reuse before you render.** Check any prior avatar render before calling HeyGen; check
  `creatives/brolls/` before sourcing supplemental clips.
- **HeyGen path (fresh avatar):** if no reusable avatar exists, `c-script` → `c-heygen`
  (9:16 1080×1920) → Step 2. The continuous bed wants the avatar's audio intact, so render the
  full narration in one pass (don't stitch multiple HeyGen clips with gaps).
- **HyperFrames render tips:** `npx hyperframes lint` before render; `--quality draft` while
  iterating, `--quality high` for delivery. If a render fails, run `npx hyperframes doctor`
  (Chrome/FFmpeg/memory). Transparent-PNG/title-card fallback is acceptable but real motion
  graphics are strongly preferred.
