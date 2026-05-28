---
name: p-reels-fmt1
description: Make a vertical reel where rich animated motion-graphics (charts/diagrams/figures) fill the FULL frame as the background and the recorded person sits as a webcam PIP pinned at the bottom. Transcribe the recording, build the background graphics by content, keep the bottom band clear for the person. Trigger on "make a reel from my footage", "cut my video into a vertical short with motion graphics", "edit my recorded clip into a vertical short", "transcript-driven reel from my recording".
when-to-use: Use when the user has a recorded main video WITH a narration/voice track and wants it edited into a vertical (9:16) reel where animated background graphics carry the visuals and the speaker appears as a bottom webcam inset — graphics driven by what is said, not at fixed intervals.
version: 3.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Footage Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [main_video, broll_clips]
dependsOn: [c-ffmpeg, c-broll, c-audio, f-hyperframes, f-hyperframes-cli]
---

# p-reels-fmt1 — Graphics-Background Reel with Bottom Webcam PIP

Turn a recorded, narrated video into a vertical 9:16 reel where **rich animated motion-graphics
fill the full frame as the background** and **the recorded person is a webcam PIP pinned at the
bottom**. The recording's narration is the single, continuous voice bed for the whole reel. We
**transcribe** the narration and use the transcript to decide, by content, what the background
graphics show at each moment (an animated chart, a hub/flow diagram, a stat). Background content
is chosen **by what is said**, never at fixed intervals.

## Layout (v3 — THE format, read first)

This is a fixed three-zone layout. Build to it; do not improvise a different arrangement.

```
┌──────────────────────────────┐ 1080×1920
│  UPPER ZONE  (y 0 → ~1240)   │  ← motion-graphics overlays: eyebrow,
│                              │     headline, charts, diagrams, figures.
│   [ animated chart / hub /   │     These NEVER enter the bottom band.
│     flow diagram / stat ]    │
│                              │
│  ── reserved line ──         │  (~680px reserved at the bottom)
│                              │
│      ┌──────────────┐        │  BOTTOM ZONE: recorded person as a
│      │  webcam PIP  │        │  webcam inset (green-bordered card),
│      │   (person)   │        │  centered, ~90px from the bottom.
│      └──────────────┘        │
└──────────────────────────────┘
```

- **Background = full-frame rich graphics**, not flat clips. Author a HyperFrames/Remotion
  composition (animated charts, hub/flow diagrams, stick figures, counters, motion VFX) on the
  brand palette. Library b-roll is only a supplement, never the primary background.
- **Person = a PIP pinned at the bottom** (like a webcam inset). If the source recording already
  has a webcam corner (common for slide-deck screen recordings), **crop the webcam region** so the
  PIP shows the person, not the slide.
- **Motion-graphics overlays live in the UPPER zone and MUST NEVER cover the bottom PIP.** The
  background composition reserves the bottom band (≈680px) — all graphic content stays above it.

> **v2 was wrong** (the bug this version fixes): the motion-graphics overlay covered the PIP, and
> the background was the flat recorded picture. v3 inverts it — graphics are the full-frame
> background, the person is a small bottom inset, and the two zones never overlap.

## Transcript usage — clean narration vs. incidental talk (READ FIRST)

A recorded video's audio is one of two cases, handled differently. Decide which applies before step 1:

- **Clean narration** — the person is delivering a coherent take / VO. Its audio CAN be the reel's
  continuous voice bed, and the transcript drives placement. (This is the default path documented below.)
- **Incidental talk** — the person is thinking out loud / narrating their own screen as they record.
  This is **NOT a script.** Do NOT use that audio as the reel's voiceover, and **never paste the raw
  transcript as on-screen captions.** Transcribe it ONLY to understand **what is on screen at each
  moment** — use those clues to (a) place b-roll cutaways on the matching content and (b) write CLEAN,
  *derived* card text (e.g. "Your Creator Operating System"), never the speaker's verbatim words. Here
  the reel's narration comes from a separate clean script/VO (or there is none — captions + music bed),
  and the recorded segments are treated as **silent visual b-roll**.

In BOTH cases, motion-graphics card text is always clean/derived, never raw transcript.

**ffmpeg + Whisper + motion-graphics. No avatar, no HeyGen, no API cost.**

Verified end-to-end on real assets (see **Verified render** below).

## Intake — ask the user FIRST (when running this recipe)

Before doing anything else, ask the user to **upload the two videos separately**:

1. **Main recorded video** — their primary footage / screen recording (becomes the spine).
2. **B-roll video(s)** — the clip(s) to cut away to.

Do NOT assume these, pull from a library, or start any step until BOTH are provided as separate
uploads. Confirm you have both files, then proceed. (If the user explicitly says "use my library
b-roll", that satisfies #2 — otherwise wait for the upload.)

## Inputs

- `main_video` — the user's recorded primary footage with a narration/voice track. **Must have a
  speech audio stream** (verify with ffprobe + `volumedetect`; if silent, stop or swap source).
  Its audio is the ONLY voice bed for the whole reel; its picture becomes the **bottom webcam PIP**
  (crop the webcam region if the source is a slide-deck recording with a webcam corner).
- `background_graphics` (built) — a full-frame 1080×1920 HyperFrames/Remotion composition of
  animated charts/diagrams/figures, authored by transcript content (step 3). This is the visual
  spine of the reel, not the recorded picture.
- `broll_clips[]` — OPTIONAL supplement to the graphics background. Treated as **silent** (audio
  discarded); the main voice bed plays underneath. Use only when a real screen-recording shows
  something the graphics can't. Sources: the user's screen-recording / AI-clip library.
- `transcript` (derived) — produced by transcribing `main_video` (step 1). Drives the graphics.
- `target_duration` (optional) — default 30–45s. Append outro adds ~5s.
- `outro` (optional) — a pre-made vertical outro clip (keeps its own audio).

## Parameters

| Param | Default | Notes |
|---|---|---|
| Canvas | `1080x1920` | 9:16 portrait |
| FPS | `30` | uniform across spine + cutaways + outro |
| Pixel format | `yuv420p` (final), `rgba` (cards before overlay) | broad player compat |
| Video codec | `libx264 -preset veryfast -crf 20` | H.264 |
| Audio codec | `aac`, `48000 Hz`, stereo, `192k` | one continuous voice bed |
| Letterbox fit | `force_original_aspect_ratio=decrease` + `pad` (black) | outro/supplemental b-roll only |
| Loudness | `loudnorm I=-14 TP=-1.5 LRA=11` | applied ONCE on the recording's audio |
| Background-graphics scenes | ~5–6 across the reel | one per transcript beat |
| PIP band reserved | ≈680px at the bottom | graphics never enter it |
| PIP geometry | ~600×520 card, centered, ~90px from bottom, ~8px green border | webcam inset |
| Graphics render | `npx hyperframes render --quality draft` (fast; ~17s for 41s @ draft) | real motion graphics |
| Card fallback | Chrome `--headless=new --default-background-color=00000000` → transparent PNG | only if hyperframes render fails |
| `+faststart` | on | web/mobile streaming |

## The background composition (the visual spine)

The background is a full-frame 1080×1920 HyperFrames composition with `data-duration` = the reel's
body length (e.g. 41s). It reserves the bottom band so nothing lands under the PIP — bake this into
the CSS:

```css
:root { --pip-band: 680px; }              /* reserved for the bottom webcam PIP */
.scene { position: absolute; top: 0; left: 0; right: 0; bottom: var(--pip-band);
         display: flex; flex-direction: column; justify-content: center; padding: 130px 80px 40px; }
```

Author one scene per transcript beat (hook, the concept, a pipeline/flow, a counter, a chart, a
diagram), crossfade between them, and follow `f-hyperframes` house style (brand palette, entrance
animations on every element, no exit animations except the final scene). Render it to a plain
1080×1920 MP4 (no audio):

```bash
npx hyperframes init bg --non-interactive   # scaffold; author index.html
npx hyperframes lint                        # 0 errors before render
npx hyperframes render --output bg-graphics.mp4 --fps 30 --quality draft
```

## The normalize filter (outro / supplemental b-roll only)

```
scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30,format=yuv420p
```

Landscape source (1920x1080) gets letterboxed; portrait-ish source gets pillarboxed. No stretching.
(The background-graphics MP4 is already 1080×1920 and needs no padding.)

## Steps

### 1. Verify + excerpt + transcribe the main video
First confirm the main video actually has speech — do not transcribe silence:
```bash
ffprobe -v error -show_entries stream=index,codec_type,codec_name -of default=noprint_wrappers=1 "$MAIN"
ffmpeg -y -i "$MAIN" -t 60 -af volumedetect -f null - 2>&1 | grep -E "mean_volume|max_volume"
```
`max_volume` near 0 dB / `mean_volume` around -20 dB indicates real speech. A silent track is
~ -90 dB → STOP and pick another source, or report there is no narration.

Pick a coherent ~40s span (for a preview). Extract 16 kHz mono WAV and transcribe with MLX Whisper
(local, Apple Silicon, no cost) per `c-audio/SKILL.md`:
```bash
ffmpeg -y -i "$MAIN" -ss "$START" -t "$LEN" -vn -acodec pcm_s16le -ar 16000 -ac 1 main.wav
mlx_whisper --model mlx-community/whisper-large-v3-turbo --output-format srt --output-dir . main.wav
```
**SRT is ground truth** — its timecodes are the line boundaries you place against. Whisper can
loop/hallucinate on long or low-content audio; read the SRT and trim your excerpt to the clean,
coherent span before planning.

### 2. Parse transcript → choose ONE background-graphic per beat (BY CONTENT)
Read the SRT. Identify ~5–6 lines that each carry a concrete, illustratable idea, and decide what
animated background graphic each beat wants — a hub/flow diagram, a counter, a bar chart, a
project-container grid, a stick-figure/VFX motif. The window for each is the SRT timecode of that
line — the background scene changes ON the line; the narration keeps playing underneath. Build a
scene plan (real example, verified):

| Window (from SRT) | Background graphic | Why this line |
|---|---|---|
| 0–6.5s | strike-through "a smarter search box" | hook: "Most people use Claude like a smarter search box… the slow way" |
| 6.5–13.5s | **hub diagram**: CLAUDE core + orbit nodes | "Claude becomes your creator operating system" |
| 13.5–20s | **flow diagram**: messy notes → finished asset | "turns messy notes into usable assets" |
| 20–27s | **counter + 12-cell grid** | "12 moves that make Claude actually useful" |
| 27–34s | **animated bar chart**: Videos/Newsletters/Offers/Calendars | "videos, newsletters, offers, scripts, calendars" |
| 34–41s | **project-container grid** | "Move 1 — use projects, separate work streams" |
| outro 5s | outro clip | — |

The recorded person is the bottom webcam PIP across the WHOLE reel — it does not change per beat.

### 3. Build the full-frame background-graphics composition (HyperFrames)
Author ONE 1080×1920 HyperFrames composition (`data-duration` = body length) with one scene per
beat from step 2, crossfading between them. Reserve the bottom band (`--pip-band: 680px`) in CSS so
nothing lands under the PIP. Follow `f-hyperframes` house style: brand palette (navy `#0f172a`,
green `#22c55e`, light `#f1f5f9`), entrance animation on every element, persistent decoratives
(glow, grid), no exit animations except the final scene. Build animated charts/diagrams with
GSAP+CSS/SVG — never a chart library. Then lint and render to a plain MP4 (no audio):
```bash
npx hyperframes init bg --non-interactive   # scaffold
# author index.html (scenes, GSAP timeline, reserved bottom band)
npx hyperframes lint                         # 0 errors before render
npx hyperframes render --output bg-graphics.mp4 --fps 30 --quality draft   # ~17s for 41s @ draft
ffprobe -v error -show_entries stream=width,height -of default=noprint_wrappers=1 bg-graphics.mp4  # 1080x1920
```
**`hyperframes add data-chart`** installs a ready animated-chart block if you'd rather wire one in
than hand-author it (see `f-hyperframes-registry`). **Fallback** (only if the hyperframes render
fails or is too slow): author still transparent cards with headless Chrome
(`--default-background-color=00000000` → rgba PNG) and overlay them on a flat background — but
PREFER the real motion-graphics composition.

### 4. (Optional) supplemental b-roll
Only if a beat needs a real screen-recording the graphics can't convey, chop a clip from the
library, normalize to 1080×1920, treat it as **silent**, and overlay it full-frame on the
background for that window (`overlay=0:0:enable='between(t,START,END)'`) — keeping it above the PIP
band. Most reels need none; the graphics composition IS the background.

### 5. Composite: graphics background + bottom webcam PIP (continuous audio, one pass)
Input `0` = the background-graphics MP4 (full-frame, no audio). Input `1` = the recording. Crop the
recording's **webcam region** (the person) — for a slide-deck recording with a webcam corner,
`crop=W:H:X:Y` that corner; otherwise center-crop. Scale it to the PIP card, seat it on a green
border card, and overlay it pinned at the bottom. The recording's narration is loudnormed **once**
and is the single continuous voice bed — the PIP is never cut, so audio stays seamless.

```bash
PIP_W=600; PIP_H=520; PIP_X=240; PIP_Y=1310; BW=8   # card ~600x520, centered, 90px from bottom
# crop=360:340:1560:740 = the webcam corner of THIS source; re-measure per recording
FC="[0:v]scale=1080:1920,setsar=1,fps=30,format=yuv420p[bg];[1:v]crop=360:340:1560:740,scale=${PIP_W}:${PIP_H},setsar=1,fps=30,format=yuv420p[pip];color=c=0x22c55e:s=$((PIP_W+2*BW))x$((PIP_H+2*BW)):d=41,fps=30[card];[card][pip]overlay=${BW}:${BW}[pipc];[bg][pipc]overlay=$((PIP_X-BW)):$((PIP_Y-BW))[v];[1:a]loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]"
ffmpeg -y -i bg-graphics.mp4 -ss 0 -t 41 -i "$MAIN" \
  -filter_complex "$FC" -map "[v]" -map "[a]" -t 41 \
  -r 30 -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
  -c:a aac -ar 48000 -ac 2 -b:a 192k body.mp4
```
**The whole `filter_complex` must be one line** (no embedded newlines / indentation) — ffmpeg 8.x
parses a stray whitespace token as an empty filter and errors `No such filter: ''`. Keep it in a
shell variable or a `.sh` script.

### 6. Append the outro (concat filter)
Normalize the outro (keep its own audio), then concat body + outro:
```bash
ffmpeg -y -i "$OUTRO" -vf "$NORM" -af "aresample=48000" -r 30 -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 -b:a 192k outro.mp4
ffmpeg -y -i body.mp4 -i outro.mp4 -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]" -map "[v]" -map "[a]" -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -movflags +faststart -c:a aac -ar 48000 -ac 2 -b:a 192k "$OUTPUT"
```

### 7. Verify (ffprobe + decode integrity + frame spot-checks)
```bash
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1 "$OUTPUT"
ffmpeg -v error -i "$OUTPUT" -f null -    # empty output = clean decode
```
Confirm width=1080, height=1920, video+audio present, duration ≈ plan total, clean decode. Then pull
frames at several scenes and **eyeball the three-zone layout**: full-frame graphics filling the
upper area, the webcam PIP visible at the bottom, and overlays NOT covering the PIP:
```bash
ffmpeg -y -ss 9  -i "$OUTPUT" -frames:v 1 frame_hub.png    # bg diagram + PIP
ffmpeg -y -ss 30 -i "$OUTPUT" -frames:v 1 frame_chart.png  # bg chart + PIP
ffmpeg -y -ss 43 -i "$OUTPUT" -frames:v 1 frame_outro.png  # outro
```

## Output

One 9:16 (1080×1920) H.264 MP4 reel: full-frame animated motion-graphics as the background
(charts/diagrams/figures driven by transcript content), the recorded person as a webcam PIP pinned
at the bottom, and the narration as a single continuous voice bed; optional outro appended.
`+faststart` for streaming.

## Notes & gotchas

- **The layout is fixed: graphics background + bottom PIP.** Graphics fill the full frame in the
  upper zone; the person is a webcam inset at the bottom; the two NEVER overlap. v2 had this
  inverted (overlay over PIP, flat picture background) — that was the bug.
- **Background content is by content, never by clock.** Each background scene maps to the SRT line
  it illustrates. Fixed-interval changes are wrong for this format.
- **Reserve the bottom band in the composition CSS** (`--pip-band: 680px`) so no graphic ever lands
  under the PIP. Verify with a frame spot-check.
- **Crop the person, not the slide.** Slide-deck recordings put the webcam in a corner — `crop` that
  corner so the PIP shows the person. Re-measure `crop=W:H:X:Y` per recording (pull a full frame
  first). Center-crop only if the source is a clean talking-head.
- **One continuous audio bed.** The recording's audio is loudnormed ONCE and never cut, so the
  narration is seamless. Honor the incidental-talk principle (top of this file): transcript =
  screen-content clues, derived card text only, never verbatim captions.
- **HyperFrames render is fast enough for previews.** `--quality draft` renders 41s in ~17s on a
  14-core Mac — no need for the still-PNG fallback in normal cases. Lint (0 errors) before render.
- **Uniform fps + sample rate are mandatory.** `fps=30` on every video lane and `aresample=48000`
  on the audio prevent A/V desync at the outro boundary.
- **No `#` comments inside `filter_complex`**, and **no embedded newlines** — both cause parse errors.
  Keep the filter in a shell variable or `.sh` script.
- **Fallback only if hyperframes fails:** Chrome still transparent cards
  (`--default-background-color=00000000` → rgba PNG) overlaid on a flat background. Prefer real
  motion graphics.

## Verified render (v3)

Rendered end-to-end on 2026-05-27 (ffmpeg 8.1, mlx_whisper whisper-large-v3-turbo, hyperframes 0.6.52):

- **Recording (→ bottom webcam PIP):** `mr-growth-guide/.../ls-prod01-mrgg-claude-cowork-longform-v2-reference.mp4`
  (1920x1080, slide-deck recording with a webcam corner — narration verified `max_volume -4.7 dB`,
  `mean_volume -22.3 dB`). Webcam cropped `crop=360:340:1560:740` → scaled to a 600×520 green-bordered
  card, centered, 90px from bottom. Excerpt 0–41s.
- **Transcription:** MLX Whisper → SRT. Clean span 0–41s (Whisper looped "One project for YouTube"
  after ~0:55, so the excerpt was trimmed to the coherent intro→Move 1 span).
- **Background graphics (HyperFrames, one scene per beat, by content):**
  - 0–6.5s — strike-through "a smarter search box" — hook
  - 6.5–13.5s — **hub diagram** CLAUDE core + 4 orbit nodes — "creator operating system"
  - 13.5–20s — **flow diagram** messy notes → finished asset — "turns messy notes into usable assets"
  - 20–27s — **counter "12" + 12-cell grid** — "12 moves that make Claude actually useful"
  - 27–34s — **animated bar chart** Videos/Newsletters/Offers & Scripts/Content Calendars — that list line
  - 34–41s — **project-container grid** (YouTube/Newsletter/Offers) — "Move 1 — use projects, separate work streams"
  - outro — `mgg-outro-vertical-5s.mp4`
- **Technique:** full-frame HyperFrames composition (brand palette, GSAP entrances, crossfades,
  reserved 680px bottom band) rendered to `bg-graphics.mp4` (1080×1920, 41s, ~17s @ draft); recorded
  webcam composited as a bottom PIP over it via ffmpeg `crop`+`overlay`; narration loudnormed once as
  the continuous bed; outro appended via concat.
- **Result:** `creatives/tests/reels-preview-2026-05-27/fmt1-v3/footage-reel-v3.mp4` — 1080x1920,
  30fps, 46.02s, H.264 + AAC stereo, ~7.7 MB, clean decode. Frame spot-checks confirmed: full-frame
  background graphics in the upper zone, webcam PIP visible at the bottom, overlays not covering the
  PIP, outro present. Composition `index.html` + SRT saved under `fmt1-v3/work/`.
