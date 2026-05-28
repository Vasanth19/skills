---
name: p-reels-fmt4
description: Turn a script into a fully rendered explainer reel with no talking head — one purpose-built BRAND graphic per beat (animated charts, diagrams, stick figures, explainer cards) plus voiceover. NO stock/AI b-roll. Trigger on "make an explainer reel from this script", "faceless animated short with VO", "no-avatar explainer video", "script to animated reel with voiceover".
when-to-use: Use when the user wants a faceless explainer reel — numbered/listicle or beat-by-beat brand motion-graphics with a voiceover, NO talking-head avatar and NO random b-roll.
version: 2.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Faceless Explainer Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [script]
dependsOn: [c-audio, c-html-gfx, c-ffmpeg, f-hyperframes]
---

# p-reels-fmt4 — Script → Faceless Explainer Reel (No Talking Head)

A 9:16 vertical reel built from a SCRIPT: voiceover (TTS) + **one purpose-built BRAND
graphic per beat** — animated charts, diagrams, stick figures, terminal/UI mockups, and
explainer cards authored in the brand's HTML/HyperFrames/Remotion style — optional brand
outro. **No HeyGen, no avatar. No stock or AI b-roll.**

**v2 fix (2026-05-27):** the original recipe overlaid text cards on a darkened *random AI
b-roll bed*. That was wrong — generic clips don't illustrate the point and look off-brand.
The visual for each beat is now a FULL-FRAME brand graphic purpose-built to illustrate
THAT specific beat: skill #1 "/terminal" gets a terminal-window mockup running a command;
"parallel tool calls" gets two bars filling side-by-side with a `2×` badge; "todo.md" gets
a live checklist; "Read → Edit" gets a flow diagram. The graphic IS the frame — there is no
photo/video bed underneath it.

Verified end-to-end (v3) 2026-05-27 (MGG "Top 20 Claude Code Skills" listicle preview, hook
+ #1–#6, 44.2s, 1080×1920 H.264+AAC). The recipe below is exactly what produced it. Output:
`creatives/tests/reels-preview-2026-05-27/fmt4-v3/faceless-explainer-reel-v3.mp4`.

## Visual doctrine (the load-bearing rule)

- **One purpose-built graphic per beat**, driven by the script line + its whisper-timed window.
- **Brand graphics only** — author HTML/HyperFrames/Remotion compositions in the brand
  explainer style. Charts that draw on, stick figures, animated diagrams, UI/terminal mockups,
  numbered explainer cards. Palette (MGG): navy `#0f172a`, accent green `#22c55e`, light
  `#f1f5f9`. Glow + faint grid behind the content so the navy never reads flat; a giant faint
  "ghost" number/glyph behind each card for depth.
- **NEVER** drop random stock footage or AI-generated b-roll clips behind the cards. If a beat
  needs a visual you don't have, build the diagram — don't reach for a clip.
- **Source the style** from the brand's existing explainer compositions, e.g.
  `creatives/tests/explainer-style-template.html`, `creatives/productions/hermes-infographic-v2.html`,
  and the HyperFrames promo at `…/ord-20260511-001-mgg-4s-hf-promo/hyperframes/index.html`
  (GSAP timeline + Barlow Condensed / mono, big numbers, staggered entrances).

## Inputs / Params

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `$SCRIPT` | Yes | — | Path to the script (markdown). HOOK + listicle beats. |
| `$OUT_DIR` | Yes | — | Output folder (mkdir -p). |
| `$VOICE_ID` | No | `$ELEVENLABS_DEFAULT_VOICE_ID` | ElevenLabs voice (c-audio presets). |
| `$PALETTE` | No | navy/green/light | Brand palette for the graphics (MGG: `#0f172a` / `#22c55e` / `#f1f5f9`). |
| `$OUTRO` | No | brand outro 5s | Appended tail clip (must be 1080×1920 w/ audio). |
| `$TARGET` | No | 30–45s | Reel length; pick beat count to fit. |

## Tooling (verified available)

- **TTS:** ElevenLabs direct API (`eleven_turbo_v2_5`) — key `ELEVENLABS_API_KEY` in `~/.gsai/secrets.env`.
  Floe API is the documented primary in `c-audio` but `FLOE_API_KEY` may be unset; ElevenLabs direct is the working fallback.
- **Timings:** `mlx_whisper` (`whisper-large-v3-turbo`) → SRT. SRT timecodes are ground truth for beat windows.
- **Graphics:** author per-beat brand compositions (HTML / HyperFrames / Remotion). Two render paths:
  - *Full motion (preferred):* HyperFrames (`hyperframes add data-chart` for charts; author HTML
    compositions with GSAP timelines for diagrams/figures/VFX) or a Remotion project → MP4 per beat.
  - *PNG fallback (acceptable, what v3 used):* render each composition with headless
    **Chrome `--headless=new`** to an OPAQUE PNG, then animate it in ffmpeg with a Ken Burns
    `zoompan` (slow zoom) so it isn't a static frame. Since the graphic is the full frame, render
    the navy background opaque (do NOT pass `--default-background-color=00000000` — that's only for
    the old transparent-overlay path, which fmt4 no longer uses).
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
Read `vo.srt`. Map each beat (hook, #1, #2 …) to its `[start → end]` window. These windows
are the duration of each beat's graphic — the graphic for beat N plays exactly while its
VO line is spoken.

### 4 — Author one brand graphic per beat (c-html-gfx / f-hyperframes)
Build a FULL-FRAME 1080×1920 composition per beat, purpose-built to illustrate THAT beat's
script line. The graphic IS the frame — opaque brand background, no photo bed underneath.

- **Hook:** big number + headline + green sub, centered (e.g. `20 / CLAUDE CODE SKILLS / never use`).
- **Per item:** giant green number + title, a one-line sub, **and a diagram that shows the point**:
  - `/terminal` → a terminal-window mockup running a real command + green `✓` output
  - `/new` → old cluttered session (dim bars) → arrow → clean `/new` session (one short bar)
  - `Read → Edit` → two icon cards joined by a green arrow + a red `✕ no hallucinated lines` row
  - `Parallel tool calls` → two full bars (`grep`,`glob`) side-by-side vs a dim serial row + `2×` badge
  - `todo.md` → a checklist (☑ done, ▶ in-progress, ☐ todo)
  - `Diff view` → a diff window with red `-` / green `+` lines + Approve/Reject chips

Shared CSS for every card: opaque navy `#0f172a` bg, a radial green glow, a faint grid, and a
giant faint "ghost" number behind the content (see the v3 generator at
`creatives/tests/reels-preview-2026-05-27/fmt4-v3/work/gen-cards.py` for the exact authored style).
Render each composition to an OPAQUE PNG and **crop to exactly 1080×1920**:
```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --screenshot="card.png" --window-size=1080,2060 \
  --hide-scrollbars --no-sandbox --force-device-scale-factor=1 "file://$PWD/card.html"
ffmpeg -y -i card.png -vf "crop=1080:1920:0:0" card-crop.png
```
(macOS reserves ~140px of window chrome → render 2060 tall, crop top 1920. NO `--default-background-color`
flag — the background is meant to be opaque navy.) Spot-check a frame: must be a brand graphic
(navy/green diagram), never a photo. Poppins/Barlow via CDN won't load offline — system sans is an
acceptable fallback; the layout and palette carry the brand, not the exact font.

### 5 — Turn each graphic into an animated beat segment (c-ffmpeg)
Each beat = its graphic, held for its SRT window, with a slow Ken Burns zoom so it isn't a dead
still. Build one MP4 segment per beat at 30fps, then concat (absolute paths in the list):
```bash
frames=$(python3 -c "print(int(round($DUR*30)))")
ffmpeg -y -loop 1 -i card-crop.png \
  -vf "scale=2160:3840,zoompan=z='min(zoom+0.0008,1.06)':d=$frames:s=1080x1920:fps=30,fps=30,format=yuv420p" \
  -t "$DUR" -c:v libx264 -pix_fmt yuv420p -r 30 seg-NN.mp4
ffmpeg -y -f concat -safe 0 -i seglist.txt -c copy body-video.mp4
```
(Upscale to 2160×3840 before `zoompan` so the zoom stays crisp.) For full-motion instead of Ken
Burns, render each beat from a HyperFrames/Remotion timeline (GSAP entrances, drawing charts) to
MP4 and concat those — the segment durations still come from the SRT windows.

### 6 — Mux the VO onto the body (c-ffmpeg)
The graphics carry no audio — map the VO straight onto the concatenated body video:
```bash
ffmpeg -y -i body-video.mp4 -i vo.mp3 \
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest body.mp4
```

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

One 9:16 (1080×1920) H.264+AAC MP4 faceless explainer reel: one purpose-built brand graphic per
beat (charts / diagrams / stick figures / UI mockups / numbered explainer cards) + generated
voiceover + optional brand outro. No talking head, no stock/AI b-roll.

## Fallbacks

- **No TTS available:** skip VO, use a music bed; the beat graphics + cuts still carry the listicle.
- **No HyperFrames/Remotion engine:** the opaque-PNG-per-beat + Ken Burns `zoompan` path (this
  recipe, what v3 shipped) is the reliable fallback — no animation project required. Full HyperFrames/
  Remotion motion (drawing charts, GSAP entrances) is the upgrade when render time allows.
- **Fail fast:** if TTS returns non-MP3 (check `file`), or a rendered beat is a photo/stock clip
  instead of a brand graphic, stop and report — never ship random b-roll. The whole point of v2 was
  to remove it.
