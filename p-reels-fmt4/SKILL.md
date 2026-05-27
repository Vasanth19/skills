---
name: p-reels-fmt4
description: Turn a script into a fully rendered explainer reel with no talking head — animated GFX/text cards plus voiceover over a b-roll bed. Trigger on "make an explainer reel from this script", "faceless animated short with VO", "no-avatar explainer video", "script to animated reel with voiceover".
when-to-use: Use when the user wants a faceless explainer reel — numbered/listicle or beat-by-beat motion graphics with a voiceover over b-roll, NO talking-head avatar.
version: 1.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Faceless Explainer Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script]
dependsOn: [c-audio, c-html-gfx, c-ffmpeg]
---

# p-reels-fmt4 — Script → Faceless Explainer Reel (No Talking Head)

A 9:16 vertical reel built from a SCRIPT: voiceover (TTS) + animated GFX/text cards
composited over a b-roll bed, optional brand outro. **No HeyGen, no avatar.**

Verified end-to-end 2026-05-27 (MGG "Top 20 Claude Code Skills" listicle preview, hook + #1–#6,
45s, 1080×1920 H.264+AAC). The recipe below is exactly what produced it.

## Inputs / Params

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `$SCRIPT` | Yes | — | Path to the script (markdown). HOOK + listicle beats. |
| `$OUT_DIR` | Yes | — | Output folder (mkdir -p). |
| `$VOICE_ID` | No | `$ELEVENLABS_DEFAULT_VOICE_ID` | ElevenLabs voice (c-audio presets). |
| `$BROLL_DIR` | No | brand `creatives/brolls/ai/` | Source b-roll clips for the bed. |
| `$OUTRO` | No | brand outro 5s | Appended tail clip (must be 1080×1920 w/ audio). |
| `$TARGET` | No | 30–45s | Reel length; pick beat count to fit. |

## Tooling (verified available)

- **TTS:** ElevenLabs direct API (`eleven_turbo_v2_5`) — key `ELEVENLABS_API_KEY` in `~/.gsai/secrets.env`.
  Floe API is the documented primary in `c-audio` but `FLOE_API_KEY` may be unset; ElevenLabs direct is the working fallback.
- **Timings:** `mlx_whisper` (`whisper-large-v3-turbo`) → SRT. SRT timecodes are ground truth for card windows.
- **Cards:** headless **Chrome `--headless=new`** (transparent PNG via `--default-background-color=00000000`).
  Old `--headless` renders a WHITE background — must use `--headless=new` for transparency.
- **Composite:** `ffmpeg` (`/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg`).

## Steps (runnable)

### 1 — Write the VO script
Extract HOOK + the listicle beats you want (e.g. #1–#6 for ~40s). Write ONE continuous VO line —
spell tricky tokens for TTS (`/terminal` → "slash terminal", `todo.md` → "todo dot m d", `2x` → "twice as fast").
Save to `$WORK/vo-script.txt`.

### 2 — Generate voiceover (c-audio)
```bash
source ~/.gsai/secrets.env
curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" -H "Content-Type: application/json" \
  -d "$(python3 -c "import json;print(json.dumps({'text':open('$WORK/vo-script.txt').read().strip(),'model_id':'eleven_turbo_v2_5','voice_settings':{'stability':0.5,'similarity_boost':0.75,'style':0.0}}))")" \
  --output "$WORK/vo.mp3"
```
Verify it's a real MP3 (`file vo.mp3`) and check duration fits `$TARGET`.

### 3 — Transcribe for card timing (c-audio)
```bash
mlx_whisper --model mlx-community/whisper-large-v3-turbo --output-format srt \
  --output-dir "$WORK" "$WORK/vo.mp3"
```
Read `vo.srt`. Map each beat (hook, #1, #2 …) to its `[start → end]` window. These are the overlay enable windows.

### 4 — Build GFX/text cards (c-html-gfx)
One transparent 1080×1920 PNG per beat. Hook = big centered headline + green sub. Each item = giant
green number + dark rounded card (title + one-line sub). Palette: bg `#0f172a`, accent green `#22c55e`,
text `#f1f5f9`. Render each HTML then **crop to exactly 1080×1920**:
```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --screenshot="card.png" --window-size=1080,2060 \
  --hide-scrollbars --no-sandbox --default-background-color=00000000 \
  --force-device-scale-factor=1 "file://$PWD/card.html"
ffmpeg -y -i card.png -vf "crop=1080:1920:0:0" card-crop.png
```
(macOS reserves ~140px of window chrome → render 2060 tall, crop top 1920.) Verify transparency:
corner pixel alpha must be 0. Note: Poppins via CDN won't load offline — system sans is an acceptable fallback.

### 5 — Build the b-roll bed (c-ffmpeg)
Scale+crop each source clip to 1080×1920, darken so cards read, 30fps, strip audio; concat to cover the VO length:
```bash
ffmpeg -y -i "$CLIP" -an \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,eq=brightness=-0.18:saturation=1.05,fps=30" \
  -c:v libx264 -pix_fmt yuv420p -t "$SEG_DUR" "bed-NN.mp4"
# concat list MUST use absolute paths
ffmpeg -y -f concat -safe 0 -i bedlist.txt -c copy bed-full.mp4
```

### 6 — Composite cards over bed + mux VO (c-ffmpeg)
Overlay each card on its SRT window with `overlay=0:0:enable='between(t,START,END)'`, chained per card,
then map the VO as audio. **Do NOT use `fade=…:alpha` keyed to main-timeline timestamps** — a static image
input's fade clock is its own 0-based PTS, not the overlay enable window, so the card never appears. Hard
cuts via `enable` are reliable. Save the chain as a `.sh` (no `#` comments inside `filter_complex`).
```bash
ffmpeg -y -i bed-full.mp4 -i card-00.png ... -i card-06.png -i vo.mp3 \
  -filter_complex "[0][1]overlay=0:0:enable='between(t,0,3.2)'[v0];[v0][2]overlay=0:0:enable='between(t,3.3,8.1)'[v1]; … [v5][7]overlay=0:0:enable='between(t,34.6,40)'[vout]" \
  -map "[vout]" -map "8:a" -c:v libx264 -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k -shortest body.mp4
```
(VO is the LAST input — its index = number of image inputs + 1.)

### 7 — Append outro + final encode (c-ffmpeg)
Outro fps/sample-rate usually differ (25fps / 48k mono) — normalize via filter concat:
```bash
ffmpeg -y -i body.mp4 -i "$OUTRO" -filter_complex "\
[0:v]scale=1080:1920,fps=30,setsar=1[v0];[1:v]scale=1080:1920,fps=30,setsar=1[v1];\
[0:a]aresample=48000,aformat=channel_layouts=stereo[a0];[1:a]aresample=48000,aformat=channel_layouts=stereo[a1];\
[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.0 \
  -c:a aac -b:a 192k -movflags +faststart "$OUT_DIR/faceless-explainer-reel.mp4"
```

### 8 — Verify
```bash
ffprobe -v error -show_entries stream=codec_type,width,height -show_entries format=duration -of default=nw=1 OUT.mp4
ffmpeg -v error -i OUT.mp4 -f null -   # decode integrity: no output = clean
```
Assert 1080×1920 (9:16), both video+audio streams, duration in `$TARGET`, decodes without errors.

## Output

One 9:16 (1080×1920) H.264+AAC MP4 faceless explainer reel: b-roll bed + animated numbered GFX
cards + generated voiceover + optional brand outro. No talking head.

## Fallbacks

- **No TTS available:** skip VO, use the b-roll's own audio or a music bed; cards + cuts still read.
- **No Remotion/animation engine:** static-image cards with hard `enable` cuts (this recipe) are the
  reliable path — no Remotion project required. Ken Burns (`zoompan`) on cards is optional polish.
- **Fail fast:** if TTS returns non-MP3 (check `file`), or a card PNG isn't transparent (corner alpha ≠ 0),
  stop and report — don't ship a broken bed.
