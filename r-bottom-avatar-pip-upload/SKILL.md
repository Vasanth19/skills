---
name: r-bottom-avatar-pip-upload
description: "UPLOAD variant of the MGG bottom-avatar PIP Short — user uploads their own talking-head video, the skill transcribes it, beat-plans a topic-matched b-roll background from the video's OWN transcript, assembles that background in ffmpeg (AI-generated cinematic stills + Ken Burns + crossfades + captions), and composites the uploaded video as a 540x540 rounded PIP over it. Fully autonomous — never asks the user for a script."
---

# r-bottom-avatar-pip-upload

> Produces one 9:16 YouTube Short from a **user-uploaded talking-head video**. The uploaded clip becomes the avatar PIP (540×540 rounded, pinned flush bottom-center). The background is a topic-matched b-roll video that the skill generates *from the uploaded video's own transcript* — no script is requested from the user, no avatar is rendered (the user already supplied their face + voice).

**Brand:** Mr Growth Guide (B-GROWTHGUIDE) — Shorts recipe, upload variant
**Sibling recipe:** `r-bottom-avatar-pip` (the HeyGen-rendered avatar variant — that one writes a script + renders an avatar; this one consumes a video the user already has).

This is the **distribution** recipe (`r-` prefix → catalog classifies it as discoverable). cfw-social can expose it to any agent with Discovery on, or curate it into an Agent's allow-list.

## What makes this variant different

| | `r-bottom-avatar-pip` (sibling) | `r-bottom-avatar-pip-upload` (this) |
|---|---|---|
| Avatar source | HeyGen render (script → avatar) | **User-uploaded video** (their real face + voice) |
| Script | Written by the agent | **None — derived from the upload's transcript** |
| Background | B-roll matched to the written script | B-roll matched to the **transcribed** upload |
| HeyGen credits | Burns ~8 premium credits | **Zero** — no avatar render at all |
| User interaction | May ask for topic/script | **Never asks — fully autonomous** |

## The autonomous rule (HARD)

**Proceed autonomously. Never ask the user for a script, a topic, b-roll choices, durations, or confirmation.** The uploaded video IS the brief. Everything downstream (transcript → beats → b-roll → composite) is derived deterministically from it. If something is genuinely missing (e.g. the upload has no audio track), fail fast with the exact error per the global Fail-Fast rule — do not stall waiting for user input mid-pipeline.

## Inputs

| Parameter | Required | Default | Description |
|---|---|---|---|
| `uploadedVideo` | Yes | — | Path / URL to the user's talking-head video. This is the avatar PIP source AND the transcript source. |
| `targetDuration` | No | upload length | The final ships at the uploaded video's natural length. Beat plan total ≈ this. |
| `brollMode` | No | `gen` | `gen` = AI-generate b-roll from beat keywords; `library` = match against `creatives/brolls/<theme>/`. |

## Output

- **Canvas:** 1080×1920 (9:16 portrait), background fill `#0F172A` (dark navy)
- **Background:** topic-matched b-roll video (ffmpeg-assembled from AI-generated cinematic stills) filling the full canvas
- **PIP:** the uploaded video, center-cropped to square, scaled to 540×540, rounded corners r=54, `overlay=270:1380`
- **Audio:** the uploaded video's audio, `loudnorm`-normalized, carries the whole piece (b-roll is silent)
- **Outro:** MGG outro appended (`mgg-outro-vertical-5s.mp4`, audio > -60 dB)
- **Delivery:** uploaded to Cloudflare R2; the skill returns the R2 URL

## MGG brand parameters (reused from `r-bottom-avatar-pip/brand-params.md`)

| Parameter | Value | Notes |
|---|---|---|
| Canvas color | `#0F172A` (dark navy) | Fills any area the b-roll doesn't cover |
| PIP geometry | 540×540, rounded corners r=54, `overlay=270:1380` on 1080×1920 | Identical to the sibling recipe — pin flush bottom-center |
| PIP crop | center-crop uploaded video to square (face-weighted), scale to 540×540, mask via rounded-corner alpha PNG | `short_side = min(w,h); x_offset = (w-short_side)/2; crop={short}:{short}:{x_offset}:0` |
| Outro | `creatives/brolls/outro/mgg-outro-vertical-5s.mp4` | Must have audio > -60 dB |
| Frame rate | 30fps | Beat plan durations are in frames @ 30fps |

**No chroma-key here.** The sibling recipe keys a green HeyGen background out; an uploaded real-world video has a real background, so the PIP shows the uploaded frame as-is inside the rounded square (no `colorkey` step).

## Pipeline (5 stages)

```
uploaded video
   │
   ▼
[1] ffmpeg extract audio ──────────────► audio.wav
   │
   ▼
[2] cfw-transcribe (Gemini) ───────────► transcript.txt  (+ duration)
   │
   ▼
[3] beat-plan (GLM-5.1) ───────────────► beats.json  ({scenes:[{text,keywords[],durationInFrames}]})
   │                                       see beat-planner.md for the prompt
   ▼
[4a] cfw-broll-source (kie.ai/ffmpeg) ──► one cinematic still per beat
[4b] cfw-broll-assemble (ffmpeg) ───────► broll-bg.mp4  (1080×1920, Ken Burns + xfade + captions, 30fps)
   │
   ▼
[5] cfw-bottom-avatar-pip (ffmpeg) ────► composite + loudnorm + outro ─► R2 upload ─► cleanup ─► URL
```

### Stage 1 — Extract audio

Pull the audio track from the uploaded video to feed transcription. Fail fast if there is no audio stream.

```bash
ffmpeg -y -i "$UPLOAD" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$WORK/audio.wav"
# also capture the video duration — drives the beat-plan total and the final length
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$UPLOAD")
```

### Stage 2 — Transcribe (`cfw-transcribe` helper, Gemini)

Run the `cfw-transcribe` helper (Gemini speech-to-text) on `audio.wav`. Returns a plain-text transcript of what the speaker says. This transcript is the ONLY brief — it drives the entire b-roll background.

```bash
cfw-transcribe --input "$WORK/audio.wav" --out "$WORK/transcript.txt"
```

### Stage 3 — Beat-plan (GLM-5.1)

Feed the transcript + duration to GLM-5.1 using the prompt in **[`beat-planner.md`](beat-planner.md)**. It returns STRICT JSON:

```json
{ "scenes": [ { "text": "short on-screen phrase", "keywords": ["concrete","visual","noun"], "durationInFrames": 90 } ] }
```

- 30fps; each `durationInFrames` ∈ [60, 120] (2–4s per beat).
- `Σ durationInFrames ≈ DURATION * 30`.
- `text` = a punchy on-screen phrase derived from that slice of transcript.
- `keywords` = the visual emphasis terms Remotion / the b-roll generator uses to pick or generate imagery.

Strip any ```json fences before parsing. Validate: JSON parses, every scene's duration is 60–120, and the sum is within one scene-length of the target. If validation fails, re-call once with a stricter directive; if it still fails, fail fast.

### Stage 4 — Assemble the topic b-roll background (ffmpeg, no browser)

For each beat, source one cinematic still, then assemble them into a full-frame background with Ken Burns motion, crossfades, and burned captions — all in **ffmpeg, no Remotion/headless browser**. Renders a ~15s background in ~2–3s on shared-cpu-1x.

**4a. Source one still per beat — `cfw-broll-source`** (kie.ai `z-image`, on-brand cinematic stills; auto-falls back to a clean concept card if generation fails, so it never hard-stops):

```bash
# for each beat i in beats.json (generate in parallel to cut wall-clock):
cfw-broll-source --keywords "<beat.keywords, comma-joined>" --text "<beat.text>" --out "$WORK/broll/$i.png"
```
~0.8 kie credits + ~15–40s per still; the fallback card is instant.

**4b. Build the assembler plan** — convert beats to the assembler schema (frames → seconds @30fps):

```json
{ "fps": 30, "segments": [ { "src": "broll/0.png", "durationSec": 3.0, "caption": "<beat.text>" } ] }
```

**4c. Assemble — `cfw-broll-assemble`** (pure ffmpeg: cover-scale to 1080×1920, Ken Burns `zoompan` on stills, ~0.5s `xfade` crossfades, `drawtext` captions in the TOP safe zone only):

```bash
cfw-broll-assemble --plan "$WORK/broll-plan.json" --out "$WORK/renders/broll-bg.mp4"
```

- Output: 1080×1920 @30fps, silent (audio comes from the avatar PIP in Stage 5). Captions are kept clear of the bottom 540px PIP zone, and the first frame is a real cover-scaled still (first-frame rule satisfied automatically).

> **Why ffmpeg, not Remotion:** Remotion renders every frame through a headless Chrome browser (software-GL on a CPU-only VM) — minutes per clip plus ~293 MB of node deps. This ffmpeg path produces the same length in ~2–3s with no browser, which is why the whole recipe runs comfortably on `shared-cpu-1x`. (Remotion stays available via the `f-remotion` skill only for genuinely animated graphics / kinetic typography — not footage behind a talking head.)

### Stage 5 — Composite PIP + loudnorm + outro + upload (`cfw-bottom-avatar-pip` helper)

The `cfw-bottom-avatar-pip` ffmpeg helper composites the uploaded video as the PIP over the b-roll background:

1. Base canvas 1080×1920, fill `#0F172A`.
2. Overlay `broll-bg.mp4` full-frame.
3. Center-crop the **uploaded video** to square (face-weighted), scale to 540×540, round corners r=54 via alpha mask, overlay at `270:1380` — always the LAST (topmost) layer.
4. Audio = the uploaded video's audio, `loudnorm`-normalized (the b-roll background is silent).
5. Append the MGG outro (`mgg-outro-vertical-5s.mp4`). Re-encode the outro to stereo 48kHz and stitch with the **concat filter** (not the demuxer + `-c copy`) to avoid the channel-layout jitter artifact. Verify outro audio mean_volume > -60 dB.
6. Upload final + cover to Cloudflare R2 (`cfw-r2-upload` / `cloud-r2-upload` helper) and **return the R2 URL**.
7. **Clean up (REQUIRED — disk hygiene):** once the R2 URL is confirmed, delete the per-run working directory (downloaded upload, `audio.wav`, sourced stills, `broll-bg.mp4`, intermediate renders). The cfw-agent volume is small (~1 GB); leaving working files behind fills it within a handful of runs. `rm -rf "$WORK"`. (The `cfw-*` helpers already self-clean their own temp dirs; this removes the orchestration-level working dir.)

```bash
cfw-bottom-avatar-pip \
  --background "$WORK/renders/broll-bg.mp4" \
  --pip "$UPLOAD" \
  --canvas 0x0F172A \
  --pip-size 540 --pip-radius 54 --pip-overlay 270:1380 \
  --loudnorm \
  --outro creatives/brolls/outro/mgg-outro-vertical-5s.mp4 \
  --upload-r2 \
  --out "$PROD_DIR/final/short.mp4"
```

## Acceptance

- [ ] Final is 1080×1920, ≈ uploaded video duration + outro, h264+aac faststart.
- [ ] PIP is 540×540 rounded (r=54) at `270:1380`, shows the uploaded talking-head, audio in sync.
- [ ] Background b-roll is topic-matched to the transcript (scenes follow the spoken narrative in order).
- [ ] First frame (y=0–1380 zone) is NOT a dark/solid canvas (max pixel > 0x30).
- [ ] Outro appended with audible audio (mean_volume > -60 dB); no concat-boundary jitter.
- [ ] R2 URL returned.
- [ ] At NO point was the user asked for a script, topic, or confirmation.

## Installation note

Skills install onto the agent from the repo via the `production.txt` allowlist at the repo root (`/Users/vasanth/Code/skills/production.txt`). For this recipe to be available in production, `r-bottom-avatar-pip-upload` must be added to that allowlist alongside `r-bottom-avatar-pip`. (Flagged for integration — not edited by this skill.)
