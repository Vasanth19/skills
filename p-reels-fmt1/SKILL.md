---
name: p-reels-fmt1
description: Make a vertical reel from a recorded video plus b-roll clips the user supplies. Trigger on "make a reel from my footage", "cut my video with brolls into a reel", "edit my recorded clip into a vertical short", "composite my video with b-roll".
when-to-use: Use when the user already has a recorded main video AND one or more b-roll clips, and wants them composited/edited into a single vertical (9:16) reel.
version: 1.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Footage Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [main_video, broll_clips]
dependsOn: [c-ffmpeg, c-broll]
---

# p-reels-fmt1 — Manual Video + B-Rolls → Vertical Reel

Cut a recorded main video together with user-supplied b-roll into one vertical 9:16 reel.
**ffmpeg only — no avatar, no API cost.** The main footage is the spine and the *only*
voice/audio source; b-roll clips are full-frame visual cutaways that borrow the main
audio underneath them, so the voice bed stays continuous across cuts.

Verified end-to-end on real assets (see **Verified render** below).

## Inputs

- `main_video` — the user's recorded primary footage (any aspect; normalized to 9:16). Its
  audio is the single voice bed for the whole reel.
- `broll_clips[]` — one or more b-roll video clips. Treated as **silent** — any audio they carry
  is discarded; the main video's audio plays underneath. (Most b-roll here — AI clips, screen
  recordings — has no audio track at all.)
- `placement_plan` (optional) — ordered list of `{ source, start, duration }` segments. If absent,
  derive a simple sequential plan: alternate main-footage talking-head segments with b-roll
  cutaways at fixed ~6s intervals (see step 2).
- `target_duration` (optional) — desired reel length; default 30–45s. Append outro adds ~5s.
- `outro` (optional) — a pre-made vertical outro clip (keeps its own audio).

## Parameters

| Param | Default | Notes |
|---|---|---|
| Canvas | `1080x1920` | 9:16 portrait |
| FPS | `30` | uniform across all segments — required for clean concat |
| Pixel format | `yuv420p` | broad player compatibility |
| Video codec | `libx264`, `-preset veryfast -crf 20` | H.264 |
| Audio codec | `aac`, `48000 Hz`, stereo, `192k` | uniform sample rate across segments |
| Letterbox fit | `force_original_aspect_ratio=decrease` + `pad` (black) | never stretch/distort source |
| Loudness | `loudnorm I=-14 TP=-1.5 LRA=11` | per-segment on the voice bed |
| Segment length | ~6s main / ~4s b-roll | tune to `target_duration` |
| `+faststart` | on | web/mobile streaming |

## The normalize filter (every segment uses this exact chain)

```
scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30,format=yuv420p
```

Landscape source (1920x1080) gets letterboxed top/bottom; portrait-ish source gets pillarboxed.
No stretching — preserves the source aspect ratio inside the 9:16 canvas.

## Steps

### 1. Probe every input
Get width/height/fps/duration and whether each clip has audio:
```bash
ffprobe -v error -show_entries format=duration \
  -show_entries stream=codec_type,codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$CLIP"
```
Note which b-roll clips are silent (most are) — they will borrow main audio.

### 2. Plan b-roll placement
If no `placement_plan` supplied, build a sequential one alternating main + b-roll. Each row is
`{ source, start_in_source, duration, audio_start }`. For b-roll segments `audio_start` is the
position in the **main** video the borrowed voice bed comes from — advance it so the bed plays
forward continuously, no repeats. Example (≈38s + 5s outro):

| Seg | Source | Dur | Main-audio window |
|---|---|---|---|
| A | main @ 6s | 6s | own (6–12) |
| B | screen-rec b-roll | 6s | 12–18 |
| C | main @ 18s | 6s | own (18–24) |
| D | AI b-roll | 4s | 24–28 |
| E | screen-rec b-roll | 6s | 28–34 |
| F | AI b-roll | 4s | 34–38 |
| G | main @ 40s | 6s | own (40–46) |
| Outro | outro clip | 5s | own |

### 3. Build each MAIN-footage segment (own synced audio)
```bash
ffmpeg -y -ss "$START" -i "$MAIN" -t "$DUR" \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30,format=yuv420p" \
  -af "loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000" \
  -r 30 -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
  -c:a aac -ar 48000 -ac 2 -b:a 192k "$SEG"
```

### 4. Build each B-ROLL segment (silent video + borrowed main audio)
Input 0 = b-roll (video only); input 1 = main video seeked to `$AUDIO_START` (audio only). Trim
both to the segment duration so video and audio stay in lockstep:
```bash
ffmpeg -y \
  -i "$BROLL" \
  -ss "$AUDIO_START" -i "$MAIN" \
  -filter_complex "[0:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30,format=yuv420p,trim=duration=$DUR,setpts=PTS-STARTPTS[v];[1:a]atrim=duration=$DUR,asetpts=PTS-STARTPTS,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]" \
  -map "[v]" -map "[a]" -t "$DUR" \
  -r 30 -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
  -c:a aac -ar 48000 -ac 2 -b:a 192k "$SEG"
```
(If a b-roll clip is shorter than `$DUR`, either shorten the segment or loop the video with
`-stream_loop`; never loop the *audio* — let the voice bed run.)

### 5. Normalize the outro (keep its own audio)
```bash
ffmpeg -y -i "$OUTRO" \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30,format=yuv420p" \
  -af "aresample=48000" \
  -r 30 -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
  -c:a aac -ar 48000 -ac 2 -b:a 192k "$SEG_OUTRO"
```

### 6. Concatenate via filter (re-encode → uniform params)
All segments already share codec/fps/SAR/sample-rate, so the concat filter joins them cleanly
with synced audio per segment (no drift — c-ffmpeg rule #3):
```bash
ffmpeg -y \
  -i segA.mp4 -i segB.mp4 -i segC.mp4 -i segD.mp4 \
  -i segE.mp4 -i segF.mp4 -i segG.mp4 -i segOutro.mp4 \
  -filter_complex "[0:v][0:a][1:v][1:a][2:v][2:a][3:v][3:a][4:v][4:a][5:v][5:a][6:v][6:a][7:v][7:a]concat=n=8:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -movflags +faststart \
  -c:a aac -ar 48000 -ac 2 -b:a 192k "$OUTPUT"
```

### 7. Verify (ffprobe + decode integrity)
```bash
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -of json "$OUTPUT"
ffmpeg -v error -i "$OUTPUT" -f null -    # empty output = clean decode
```
Confirm: width=1080, height=1920, both a video and an audio stream present, duration ≈ plan total,
clean decode (no errors). Optionally sample a mid-reel frame's `signalstats.YAVG` to confirm it
isn't black.

## Output

One 9:16 (1080×1920) H.264 MP4 reel: the user's recorded video as the spine, b-roll clips
cut in full-frame as silent cutaways, a single continuous voice bed from the main footage,
optional outro appended. `+faststart` for streaming.

## Notes & gotchas

- **Hard cuts, not overlays, by default.** Full-frame b-roll replacement is the simplest robust
  layout for a footage reel. PIP/overlay layouts are available via `c-ffmpeg` portrait layouts
  (`pip-broll`, `bottom-avatar`) if the caller asks — but those need a foreground subject; for
  plain footage+b-roll, full-frame cutaways are the right default.
- **Audio-per-segment (c-ffmpeg rule #3):** every segment carries its own synced audio *before*
  concat. Never concat video-only segments and lay one audio strip over the top — drift
  accumulates over a multi-minute timeline.
- **Uniform fps + sample rate are mandatory** before a filter-concat. Mixed source fps (24 vs 25)
  or sample rates cause A/V desync at segment boundaries. The `fps=30` + `aresample=48000` in every
  segment recipe handles this.
- **No `#` comments inside `filter_complex` strings** — ffmpeg parse error. Keep complex commands
  in a `.sh` script (this skill ships its render as a script in the production `_work/` dir).
- Crossfade transitions (`xfade`/`acrossfade`) are optional polish; hard cuts are the verified
  default and read fine for fast-paced reels.

## Verified render

Rendered end-to-end on 2026-05-27 (ffmpeg 8.1):
- **Main:** `mr-growth-guide/.../ls-prod01-mrgg-claude-cowork-longform-v2-reference.mp4` (1920x1080, has audio)
- **B-roll:** 2 screen recordings (`ls-scrn17`, `ls-scrn18`; 1920x1080, silent) + 2 AI clips
  (`pr-clip-01-tunnel`, `pr-clip-03-glow`; 834x1112, silent)
- **Outro:** `mgg-outro-vertical-5s.mp4` (1080x1920, has audio)
- **Result:** `creatives/tests/reels-preview-2026-05-27/fmt1/footage-reel.mp4` — 1080x1920, 30fps,
  43.1s, H.264 + AAC stereo, clean decode. Demonstrates the footage+b-roll composite with a
  continuous voice bed and appended outro.
