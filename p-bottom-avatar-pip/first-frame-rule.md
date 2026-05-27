# First-Frame Rule — r-bottom-avatar-pip

Canonical as of 2026-04-19. Cover-prepend is the default for every production.

## Why

YouTube Shorts / IG Reels / TikTok / LinkedIn all use the video's **first frame** as the feed thumbnail. Custom cover APIs are disabled, unreliable, or unsupported in the uploader. A blank/dark first frame kills hook-through-rate; a random b-roll frame is incidental; only a designed cover is intentional.

## Rule

Every production prepends `final/cover.png` (from `cover-frame-generate`) as a **0.4s opening card**. Audio is adelay'd 400ms to preserve sync. Not a fallback — the default.

### Why 0.4s

- **< 0.3s:** platform thumbnails may not register before playback starts
- **0.3–0.5s:** designed opening; matches pattern used by high-performing creators (Saraev, Hormozi)
- **> 0.5s:** reads as freeze/broken video; retention drops

### Cover card contents

`cover-frame-generate` produces: brand colors, hook text (3-7 words matching script hook), avatar headshot keyed onto card. If the cover doesn't show visible brand content at max brightness, the skill is broken — fix at source, don't patch the pipeline.

## Prepend Command (Single-pass, canonical)

```bash
ffmpeg -y \
  -loop 1 -t 0.4 -i final/cover.png \
  -f lavfi -t 0.4 -i anullsrc=r=48000:cl=stereo \
  -i <composed-with-outro>.mp4 \
  -filter_complex "\
    [0:v]scale=1080:1920,format=yuv420p,fps=30,setpts=PTS-STARTPTS[v0]; \
    [2:v]fps=30,setpts=PTS-STARTPTS[v1]; \
    [v0][v1]concat=n=2:v=1:a=0,setpts=PTS-STARTPTS[outv]; \
    [1:a]asetpts=PTS-STARTPTS[a0]; \
    [2:a]asetpts=PTS-STARTPTS[a1]; \
    [a0][a1]concat=n=2:v=0:a=1,asetpts=PTS-STARTPTS[outa]" \
  -map "[outv]" -map "[outa]" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -r 30 -fps_mode cfr \
  -bf 0 \
  -video_track_timescale 30000 \
  -c:a aac -b:a 128k -ar 48000 \
  -movflags +faststart \
  final/short.mp4
```

### Critical flags

| Flag | Why |
|---|---|
| `-bf 0` | Disables B-frames. Without it libx264 emits 66ms decoder pre-roll → `start_time=0.066s` → QuickTime shows black for ~66ms. Costs ~10-15% larger file but guarantees `start_time=0.000`. |
| `-fps_mode cfr` | Constant frame rate. Prevents VFR metadata that makes QT display frame counts instead of seconds. |
| `-video_track_timescale 30000` | Standard 30fps timescale. Prevents `1/15360` oddity that also triggers frame-count display. |
| `-ar 48000` | Standard 48kHz audio. |

## Verification (REQUIRED after `ffmpeg-verify-output`)

```bash
ffprobe -show_entries stream=time_base,start_time final/short.mp4
# Must show: time_base=1/30000, start_time=0.000000 on video stream
```

### First-frame brightness check

```bash
MAX=$(ffmpeg -ss 0 -i final/short.mp4 -frames:v 1 -f rawvideo -pix_fmt rgb24 - 2>/dev/null \
  | python3 -c "import sys; d=sys.stdin.buffer.read(1080*1920*3); print(max(d))")
# Must return > 0x30 (48)
```

A single max-pixel check is insufficient — PIP avatar contributes bright pixels at bottom even when the upper canvas is black. Also check the b-roll zone (y=0–1380):

```bash
MAX_BROLL=$(ffmpeg -ss 0 -i final/short.mp4 -vf "crop=1080:1380:0:0" -frames:v 1 -f rawvideo -pix_fmt rgb24 - 2>/dev/null \
  | python3 -c "import sys; d=sys.stdin.buffer.read(1080*1380*3); print(max(d))")
# Must return > 0x30
```

If either check fails → `cover.png` is broken → regenerate with `cover-frame-generate`, don't patch around it.

## Never Acceptable

- Shipping without running `cover-frame-generate`
- Shipping with `cover.png` whose `MAX_BROLL` at frame 0 ≤ 48
- Duplicating `cover.png` as a separate thumbnail while the video still has a dark first frame

## QuickTime Black Flash Note

If you see a ~66-100ms black flash on first play in QuickTime, that's QT's playback buffer — NOT video content. Verify frame 0 IS the cover:

```bash
ffmpeg -ss 0 -i final/short.mp4 -frames:v 1 /tmp/f0.png
```

Platforms (YouTube/IG/TikTok) don't use QT's buffer behavior. The cover WILL display as the thumbnail. If the flash is too noticeable even on platforms, extend cover duration from 0.4s to 0.8-1.0s.
