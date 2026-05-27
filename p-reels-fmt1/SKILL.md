---
name: p-reels-fmt1
description: Make a vertical reel from a recorded video by transcribing it, then placing b-roll cutaways and motion-graphics cards on the exact lines they relate to. Trigger on "make a reel from my footage", "cut my video with brolls into a reel", "edit my recorded clip into a vertical short", "transcript-driven reel from my recording".
when-to-use: Use when the user has a recorded main video WITH a narration/voice track and wants it edited into a vertical (9:16) reel where cutaways and animated cards land on the content they illustrate — not at fixed intervals.
version: 2.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Footage Reel
  format: 9:16 vertical video
  duration: 30-60s
inputs: [main_video, broll_clips]
dependsOn: [c-ffmpeg, c-broll, c-audio, f-hyperframes]
---

# p-reels-fmt1 — Transcript-Driven Footage Reel

Turn a recorded, narrated video into a vertical 9:16 reel. **The recorded video is the
MAIN/talking track** — its picture is the spine and its narration audio is the single,
continuous voice bed for the whole reel. We then **transcribe** the narration and use the
transcript to decide, by content, where to cut to a b-roll segment or pop a motion-graphics
card. Placement is **by what is said**, never at fixed intervals.

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
  Normalized to 9:16; its audio is the ONLY voice bed for the whole reel.
- `broll_clips[]` — b-roll for cutaways. Treated as **silent** (audio discarded); the main voice
  bed plays underneath. Sources: segments chopped from the main recording itself, the user's
  screen-recording / AI-clip library, or both.
- `transcript` (derived) — produced by transcribing `main_video` (step 1). Drives placement.
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
| Letterbox fit | `force_original_aspect_ratio=decrease` + `pad` (black) | never stretch/distort |
| Loudness | `loudnorm I=-14 TP=-1.5 LRA=11` | applied ONCE on the spine audio |
| Cutaway/card count | ~4–6 across the reel | chosen by transcript content |
| Card render | Chrome `--headless=new --default-background-color=00000000` → transparent PNG | motion-graphics fallback (see note) |
| `+faststart` | on | web/mobile streaming |

## The normalize filter (spine, every cutaway, outro)

```
scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30,format=yuv420p
```

Landscape source (1920x1080) gets letterboxed; portrait-ish source gets pillarboxed. No stretching.

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

### 2. Parse transcript → choose cutaway/card moments (BY CONTENT)
Read the SRT. Identify ~4–6 lines that each carry a concrete, illustratable idea, and decide for
each whether it wants a **b-roll cutaway** (a thing you can show) or a **motion-graphics card** (a
concept/list/label to spell out). The window for each is the SRT timecode of that line — the
cutaway/card lands ON the line, the main keeps talking elsewhere. Build a placement plan:

| Window (from SRT) | What | Why this line |
|---|---|---|
| 0–6.5s | MAIN talking track | hook — let the speaker land it |
| 6.5–13.5s | **card**: "Your Creator Operating System" | line: "Claude becomes your creator operating system" |
| 13.5–20s | **b-roll**: messy-notes→clean-brief screen rec | line: "turns messy notes into usable assets" |
| 20–27s | MAIN | line: "12 moves that make Claude Desktop useful" |
| 27–34s | **card**: Videos · Newsletters · Offers · Calendars | line: "videos, newsletters, offers, scripts, calendars" |
| 34–41s | **b-roll**: Claude project-containers screen rec | line: "Move 1 — use projects, separate work streams" |
| outro 5s | outro clip | — |

### 3. Build the motion-graphics cards (transparent overlays)
Author each card as a self-contained 1080×1920 HTML file on a `background:transparent` body, using
brand colors (read the brand's VISUAL-STANDARDS / DESIGN). For richer animated cards use
`f-hyperframes` (Remotion/HyperFrames compositions). **Motion-graphics fallback** when Remotion /
Chromium render is too slow for a preview: render a still transparent card with headless Chrome and
hard-cut it in with ffmpeg `overlay … enable='between(t,…)'` (the fmt4 transparent-card technique):
```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --default-background-color=00000000 --window-size=1080,1920 \
  --screenshot="card1.png" "card1.html"
ffprobe -v error -show_entries stream=pix_fmt -of default=noprint_wrappers=1 card1.png  # expect rgba
```
The `--default-background-color=00000000` flag is what gives a true transparent (rgba) PNG — without
it the card has an opaque white background and won't composite.

### 4. Build cutaway b-roll segments
Chop the cutaway clips from the main recording and/or library. They are full-frame 9:16, **silent**
(audio discarded — the spine's voice bed plays underneath). Normalize each to the canvas; trim to its
window length. You do NOT need per-segment audio here because the spine carries one continuous track
(step 5).

### 5. Composite: spine + overlays (continuous audio, one pass)
The spine is the normalized main video for the whole span, with its narration loudnormed **once**.
Layer each card PNG and each b-roll clip on top with `overlay … enable='between(t, START, END)'` so
they appear only on their planned window — a hard cut to full-frame. Because the spine audio is never
cut, **the voice bed stays perfectly continuous across every cutaway and card** (no per-segment audio,
no drift). Inputs: `0`=main(excerpt), then b-roll clips, then card PNGs.

```bash
NORM="scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30,format=yuv420p"
FC="[0:v]${NORM}[spine];[1:v]${NORM},trim=duration=6.5,setpts=PTS-STARTPTS[b1];[2:v]${NORM},trim=duration=7,setpts=PTS-STARTPTS[b2];[3:v]scale=1080:1920,setsar=1,fps=30,format=rgba[c1];[4:v]scale=1080:1920,setsar=1,fps=30,format=rgba[c2];[spine][c1]overlay=0:0:enable='between(t,6.5,13.5)'[s1];[s1][b1]overlay=0:0:enable='between(t,13.5,20)'[s2];[s2][c2]overlay=0:0:enable='between(t,27,34)'[s3];[s3][b2]overlay=0:0:enable='between(t,34,41)'[v];[0:a]loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]"
ffmpeg -y -ss 0 -t 41 -i "$MAIN" -i "$BR1" -i "$BR2" -i card1.png -i card2.png \
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
frames at a main-track moment, a b-roll window, and a card window and eyeball them:
```bash
ffmpeg -y -ss 2  -i "$OUTPUT" -frames:v 1 frame_main.png
ffmpeg -y -ss 16 -i "$OUTPUT" -frames:v 1 frame_broll.png
ffmpeg -y -ss 10 -i "$OUTPUT" -frames:v 1 frame_card.png
```

## Output

One 9:16 (1080×1920) H.264 MP4 reel: the recorded video as the spine and single continuous voice
bed; b-roll cutaways and motion-graphics cards hard-cut in on the transcript lines they relate to;
optional outro appended. `+faststart` for streaming.

## Notes & gotchas

- **Placement is by content, never by clock.** A cutaway/card lands on the SRT line it illustrates.
  Fixed-interval alternation (the old v1 behavior) is wrong for this format.
- **One continuous audio bed.** The spine audio is loudnormed ONCE and never cut, so the narration
  is seamless across every overlay. Do NOT rebuild audio per segment (that's the v1 concat model and
  it can drift / re-trigger loudnorm pumping).
- **Overlay, not concat, for cutaways/cards.** Overlaying on a continuous spine is what keeps the
  voice bed unbroken. Reserve concat for appending the outro.
- **Transparent cards need `--default-background-color=00000000`.** Without it the PNG is opaque and
  the card hides the spine behind a white box.
- **Whisper loops on long/low audio.** Read the SRT; trim the excerpt to the coherent span before
  planning. SRT timecodes are ground truth (c-audio rule).
- **Uniform fps + sample rate are mandatory.** `fps=30` on every video lane and `aresample=48000`
  on the audio prevent A/V desync at the outro boundary.
- **No `#` comments inside `filter_complex`**, and **no embedded newlines** — both cause parse errors.
- Richer animation: swap the still-PNG fallback for an `f-hyperframes` composition (animated entrance,
  GSAP) rendered to a transparent video, overlaid the same way, when render time allows.

## Verified render

Rendered end-to-end on 2026-05-27 (ffmpeg 8.1, mlx_whisper whisper-large-v3-turbo, Chrome headless):

- **Main:** `mr-growth-guide/.../ls-prod01-mrgg-claude-cowork-longform-v2-reference.mp4`
  (1920x1080, has narration — verified `max_volume -4.7 dB`, `mean_volume -22.3 dB`). Excerpt 0–41s.
- **Transcription:** MLX Whisper → SRT. Clean span 0–41s (Whisper looped "Create a Claude" after
  ~1:30, so the excerpt was trimmed to the coherent intro→Move 1 span).
- **Placement (by content):**
  - 0–6.5s — MAIN — hook "Most people use Claude like a smarter search box…"
  - 6.5–13.5s — **card** "Your Creator Operating System" — on "Claude becomes your creator operating system"
  - 13.5–20s — **b-roll** `ls-scrn07-messy-notes-to-clean-brief` — on "turns messy notes into usable assets"
  - 20–27s — MAIN — "12 moves that make Claude Desktop actually useful"
  - 27–34s — **card** "Videos · Newsletters · Offers & Scripts · Content Calendars" — on that exact list line
  - 34–41s — **b-roll** `ls-scrn04-claude-project-workstreams` — on "Move 1 — use projects, separate work streams"
  - outro — `mgg-outro-vertical-5s.mp4`
- **Technique:** continuous spine (main video normalized + loudnorm-once audio) with b-roll and
  transparent-PNG cards composited via `overlay … enable='between(t,…)'`; outro appended via concat.
  Cards rendered with Chrome `--headless=new --default-background-color=00000000` (the fmt4
  transparent-card fallback) — Remotion not needed for the preview.
- **Result:** `creatives/tests/reels-preview-2026-05-27/fmt1-v2/footage-reel-v2.mp4` — 1080x1920,
  30fps, 46.0s, H.264 + AAC stereo, ~2.0 MB, clean decode. Frame spot-checks confirmed main-track,
  both b-roll cutaways, and both cards land on their lines. Transcript SRT + card HTML saved alongside.
