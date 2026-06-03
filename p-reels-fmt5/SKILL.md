---
name: p-reels-fmt5
description: Make a vertical reel from an UPLOADED talking-head video as a bottom picture-in-picture over a transcript-synced background — the background is built beat-by-beat from the speaker's own words: matching UPLOADED b-roll clips where they fit the wording, and generated HyperFrames/Remotion motion graphics where they don't. The talking head's own voice is the audio bed. Trigger on "make a reel from my talking-head video", "PIP reel from my uploaded video", "talking head over b-roll matched to what I say", "transcribe my video and cut b-roll to the words", "trim my b-rolls to the transcript cues", "my video as the PIP with b-roll background", "talking-head PIP with b-roll + graphics background", "uploaded talking head reel".
when-to-use: Use when the user UPLOADS their own talking-head clip (their real face + real voice — NOT a HeyGen avatar) and wants a 9:16 reel where that clip sits as a bottom PIP over a background that follows what they're saying: their uploaded b-roll where it matches the words, generated motion graphics where it doesn't. This is the "uploaded video, not generated avatar" sibling of p-reels-fmt2.
version: 1.0.0
kind: pipeline
visibility: catalog
providers: elevenlabs
produces:
  dish: Uploaded Talking-Head PIP Reel
  format: 9:16 vertical video
  duration: 20-60s
inputs: [talking_head_video, broll_media]
dependsOn: [c-audio, c-broll, c-ffmpeg, f-hyperframes, c-cloud-media]
---

# p-reels-fmt5 — Uploaded Talking-Head PIP over Transcript-Synced Background

Produces one 9:16 (1080×1920) MP4 reel: the user's **own uploaded talking-head video** composited as a
rounded-square picture-in-picture pinned bottom-center, over a **full-frame background that is built
from the speaker's own transcript** — a beat-by-beat sequence that uses the user's **uploaded b-roll
clips where they match the wording**, and **generated HyperFrames/Remotion motion graphics where no
clip fits**. The talking head's own voice is the audio bed.

**This is the "uploaded video" sibling of `p-reels-fmt2`.** fmt2 uses a HeyGen-generated avatar over a
graphics background. fmt5 uses the **user's uploaded clip** (real face + real voice, NOT HeyGen) and a
**transcript-synced hybrid background** (uploaded b-roll matched to the words + generated graphics to
fill gaps). It reuses fmt2's exact PIP geometry, scale-to-COVER background fit, mask, and audio path —
read `p-reels-fmt2/SKILL.md` for the canonical PIP compositing primitives and
`c-ffmpeg/references/portrait-layouts.md` for the filter details. **Do not re-derive the ffmpeg
pipeline from scratch** — that improvisation is exactly what this recipe exists to replace.

## The one failure this recipe is built to prevent

**A reel where the background renders all-black and only the PIP shows.** This happens when the
background track is dropped from / mis-ordered in the `filter_complex`, the b-roll layer fails to
decode, or the PIP is overlaid onto a bare black canvas instead of the built background. fmt5 makes
the background a **separately-built, separately-verified track** (Step 5: build `$W/bg-all.mp4` and
ffprobe + brightness-check it BEFORE compositing) and a **MANDATORY Visual QA Gate** (Step 8) that
reads sample frames and **rejects any frame whose background zone is black**. ffprobe passing is not
"done" — a reel that was never looked at is not done.

## Inputs

- `talking_head_video` (REQUIRED) — the user's uploaded talking-head clip. Real face + real voice.
  This is BOTH the PIP foreground AND the audio + duration master. **Never** replace it with a HeyGen
  avatar or TTS — it is the owner's actual voice.
- `broll_media[]` (optional) — the user's uploaded b-roll clips. Matched to transcript beats by
  wording (`c-broll` script-match). **Clips that carry their own audio are transcribed too** — their
  cue timeline both confirms the content match and drives the trim window (the clip is cut to the
  moment its audio lines up with the talking-head's words). Any beat with no matching clip falls back
  to a generated graphic.
- `brand` — palette + typography for the generated-graphics beats (resolve via the Visual Identity
  Gate: Brand Brief → DESIGN.md → named style → dark-premium. Never hard-code).
- `music_bed` (optional) — dark/moody instrumental under the VO at ≈ −18 LUFS; master to −14 LUFS.
- `pip_spec` (optional) — defaults to the proven bottom-center rounded square below.

## Parameter Table (inherits fmt2; deltas marked ★)

| Parameter | Default | Notes |
|---|---|---|
| Canvas | 1080×1920, 30 fps | 9:16 portrait |
| Canvas color | `#0F172A` | Only ever visible where a source has letterbox gaps — which the cover-crop removes |
| ★ Background source | **transcript-synced hybrid** | Per beat: matching UPLOADED b-roll (scale-to-COVER) OR a generated HyperFrames/Remotion graphic. Never a bare black canvas. |
| Background fit | scale-to-COVER + center crop | `scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920` — fills the full frame, no pillarbox, no stretch. **Never `pad`/letterbox, never a distorting bare `scale=1080:1920`.** |
| ★ PIP source | **uploaded talking-head video** | NOT HeyGen. Opaque by default → no chroma-key. Run the white-band detect (fmt2 Step 3.5) only if the upload has bright studio side-margins. |
| PIP crop | `crop=S:S:Xoff:0` | `S=min(w,h)`, `Xoff=(w-S)/2`, `Yoff=0` (top-anchored — never clip the head). ffprobe the upload first. |
| PIP size | 540×540, rounded r=54 | Masked via reusable `pip-mask-540.png` (RGBA alpha) |
| PIP position | `overlay=270:1380` | Bottom-center on 1080×1920 (proven). Keep all background "real content" in the top ~65% (above y≈1340). |
| ★ Audio | **talking head's own track** (primary VO) | Optional music bed at −18 LUFS under it; master loudnorm −14 LUFS. NO TTS. |
| Target duration | = talking-head length | The VO is the master; the background sequence is built to cover exactly it (`shortest=1`). |
| Encode | H.264, yuv420p, CRF 19, `+faststart` | aac stereo 48k 192k |

## PIP mask (reuse, don't regenerate)

The 540×540 rounded-corner alpha mask is identical for every reel — reuse fmt2's:
```bash
find <brand>/creatives/productions -name "pip-mask-540.png" | head -1
```
If none exists, generate once with PIL (540×540 RGBA, white rounded rect r=54 on transparent).

## Steps

Set `$TH` = talking-head upload, `$OUT` = final path, `$W` = scratch `work/` dir, `$MASK` = pip mask,
`$FF` = the ffmpeg binary.

### 1 — Localize + probe every input (MANDATORY — never composite from remote URLs)

> **Failure mode this prevents:** a remote URL that fails to fetch mid-render renders as a black/blank
> layer — one of the two ways the background goes black. Download every source to local disk and
> ffprobe it BEFORE building anything.

```bash
# Download $TH and each broll clip into $W/src/ ; then for each:
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration,codec_name -of default=nw=1 "$W/src/<file>"
```
ffprobe `$TH` for `width,height,duration` — `duration` is the **master reel length**, the crop math
driver, and the background-coverage target. A clip that fails to probe is unusable — fail loudly,
don't substitute black.

### 2 — Transcribe the talking head → beat timeline (c-audio)

Transcribe `$TH`'s audio to word/segment timestamps (`c-audio` → MLX Whisper / whisper). From the
transcript, segment the VO into **3–6 beats** by sentence/topic boundary. Each beat = `{start, end,
text}`. This timeline drives BOTH the background selection (Step 3) and any on-screen text. Re-use the
real timestamps — never guess beat boundaries.

### 3 — Assign a background to each beat (uploaded b-roll match → graphics fallback)

For each beat, pick its full-frame background **in this priority order**:

1. **Matching uploaded b-roll, trimmed to its cue** — run `c-broll` script-match against
   `broll_media[]` for the beat's wording. Matching and trimming are **both transcript-cue-driven**:
   - **If the b-roll clip carries its own audio**, transcribe it (`c-audio`, same as Step 2) to get
     the clip's OWN cue timeline. Use that to (a) confirm the content match — the clip is talking
     about / showing what this beat says — and (b) **trim the clip to the relevant cue window**
     (`clip_in`→`clip_out` = the timestamps of the matching phrase inside the clip), not an arbitrary
     window. This is the point: the b-roll is cut to the moment its own audio lines up with the
     talking-head's words.
   - **If the clip has no audio**, match by `c-broll`'s visual/label metadata and cut a window ≥ the
     beat length from the most relevant section.
   - Either way, the chosen `[clip_in, clip_out]` is then scale-to-COVERed into 9:16 (filter below).
     The b-roll's own audio is **dropped** (`-an`) — the talking head's VO is the only voice (Step 5).
2. **Generated motion graphic** — if NO uploaded clip matches the beat, author an animated
   HyperFrames composition (or Remotion scene) **appropriate to that line** — a counter, a short
   phrase callout, a diagram, brand ambient — at native 1080×1920, matching the Visual Identity Gate
   palette/type. (This is Kyle's HyperFrames path; see `f-hyperframes` and fmt2 Step 2 + the font
   gotcha: never put `var(--font-*)` in `font-family`.) Render to MP4 ≥ the beat length.

A reel may freely **mix** uploaded-b-roll beats and generated-graphics beats — that is the expected,
correct output. The ONLY hard rule: **every beat has a real, non-black background.**

Per-beat b-roll cover-cut (`clip_in`/`clip_out` = the cue window from the clip's own transcript when
it has audio, else the matched visual window → 9:16, audio stripped):
```bash
$FF -ss <clip_in> -to <clip_out> -i "$W/src/<clip>" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p" \
  -an -c:v libx264 -preset medium -crf 20 -y "$W/bg_beatN.mp4"
```
> If the cue window is shorter than the beat, loop/slow-mo or extend with the next-best section to
> cover the beat; if longer, trim to the cue's tightest relevant span. Never pad to black.

### 4 — Build + VERIFY the background track (before any compositing)

Concat the per-beat background segments into one full-frame track that covers the whole VO:
```bash
# normalize every bg_beatN.mp4 to 1080x1920/30fps/yuv420p first, then concat via filter (not -c copy
# unless codecs/timebase already match). Result: $W/bg-all.mp4
```
**VERIFY it is not black BEFORE compositing** (this is the cheap mechanical guard for the exact bug):
```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration -of default=nw=1 "$W/bg-all.mp4"
# sample brightness at 3 points — a real background reads YAVG well above black (~>30); ~0 = black bg
for t in 1 $(echo "scale=1;<DUR>/2"|bc) $(echo "scale=1;<DUR>-1"|bc); do
  $FF -ss "$t" -i "$W/bg-all.mp4" -frames:v 1 -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG" -f null - 2>&1 | grep -o 'YAVG=[0-9.]*'
done
```
If any sample is ~0 (all black), the background build failed — fix Step 3/4, do NOT proceed to
composite. Black `bg-all.mp4` is the root cause of "only the PIP shows."

### 5 — Composite the uploaded talking-head PIP over the background (fmt2 path)

Crop the talking head square (top-anchored), scale to 540×540, alphamerge the rounded mask, overlay
bottom-center, map the **talking head's own audio**. Uploaded clips are opaque → NO chroma-key (only
run fmt2 Step 3.5 white-band crop if the upload has bright studio side-margins):
```bash
$FF -i "$W/bg-all.mp4" -i "$TH" -i "$MASK" \
  -filter_complex "\
[1:v]crop=S:S:Xoff:0,scale=540:540,setsar=1[avsq]; \
[avsq][2:v]alphamerge[avpip]; \
[0:v]format=yuv420p[bg]; \
[bg][avpip]overlay=270:1380:format=auto:shortest=1[v]" \
  -map "[v]" -map "1:a" \
  -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -movflags +faststart -y "$W/composed.mp4"
```
(Replace `S`/`Xoff` with the values ffprobed in Step 1. `shortest=1` clips to the talking head — the
audio + duration master.)

### 6 — Audio mix (optional music bed)

The talking head's voice is already the primary track from Step 5. If a `music_bed` is supplied, mix
it UNDER the VO at ≈ −18 LUFS and master the result to −14 LUFS loudnorm (`c-audio`/`c-ffmpeg`). No
music bed → `$W/composed.mp4` audio is final. **Never** replace the VO — it is the owner's real voice.

### 7 — On-screen text (optional)

If the brief calls for text beats, burn them over `$W/composed.mp4` from the Step-2 transcript timing
(top ~55% so they never overlap the bottom PIP). Skip for plain b-roll-over-VO reels.

### 8 — Visual QA Gate (MANDATORY — uses your vision)

> A render that was never looked at is NOT done. The black-background failure is INVISIBLE to ffprobe
> — it only shows when you LOOK. This gate is non-negotiable.

Mechanical checks first:
```bash
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -show_entries format=duration -of default=nw=1 "$OUT"
$FF -v error -i "$OUT" -f null -            # clean decode = no output
```
Assert 1080×1920 (9:16), both video+audio streams, duration ≈ the talking-head length.

Extract 6 frames at 5/20/40/60/80/95% of the duration and **READ each one with your vision**:
```bash
for pct in 05 20 40 60 80 95; do $FF -y -ss <t_pct> -i "$OUT" -frames:v 1 qa_frame_$pct.png; done
```
For each frame, CHECK:
- [ ] **(a) The BACKGROUND IS NOT BLACK** — behind/around the bottom PIP there is real footage or a
      real motion graphic filling the full frame. A black/empty background = the build failed → fix
      Step 3/4 and re-render. **This is the primary check — the bug this recipe exists to kill.**
- [ ] **(b) The talking-head PIP is present** bottom-center, rounded, the face intact (not clipped at
      the top), not stretched.
- [ ] **(c) Background fills the full width** — no pillarbox bars, no letterbox, no distortion
      (scale-to-COVER working).
- [ ] **(d) Brand colors correct** on any generated-graphics beats — palette per the Visual Identity
      Gate, not washed out, not defaulted to white-on-black.

Also confirm the **VO is the clear audio foreground** and **no static-only stretch > 3s**.

**If ANY check on ANY frame fails: fix and RE-RENDER. Re-extract the frames and look again. Repeat
until every frame passes. NEVER upload a reel that fails this gate** (the all-black-background reel
that prompted this recipe would fail check (a) immediately).

### 9 — Upload to R2 and print the URL (LAST LINE)

The local file is NOT the deliverable — the worker scrapes your reply for an R2/CDN URL. No uploaded
URL = the job reports "finished without producing an asset" and FAILS.
```bash
bash _scripts/upload-to-recordings.sh "$OUT"   # → r2-upload (c-cloud-media); returns the public CDN URL
```
Clean up `$W` after the URL is confirmed. **Print the R2 public URL as the final line of output.**
NEVER print an input URL (the talking-head upload, a b-roll source) as the result — the result is the
freshly rendered, uploaded reel.

## Output

One 9:16 (1080×1920) H.264 MP4: a full-frame transcript-synced background (uploaded b-roll where it
matched the words + generated motion graphics where it didn't), the user's uploaded talking-head clip
as a rounded bottom-center PIP, the owner's real voice as the audio bed, optional music + text.

## Notes & gotchas

- **The PIP is the UPLOADED clip, not a HeyGen avatar.** No HeyGen call, no TTS — the owner's real
  face and voice. (This is the whole point of fmt5 vs fmt2.)
- **The background follows the words.** Match uploaded b-roll to the transcript beats; fill gaps with
  generated graphics. Mixing both per-beat is correct, not a compromise.
- **Black background = the build failed, never ship it.** Build `bg-all.mp4` as a separate, brightness-
  verified track (Step 4) and reject black in the Visual QA Gate (Step 8a). Both guards exist because
  ffprobe cannot see a black frame.
- **Scale-to-COVER, never pad/stretch.** `scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920`.
- **Talking head is the audio + duration master.** `shortest=1` clips the composite to it; build the
  background to cover at least its full length.
- **No `#` comments inside `filter_complex`** — parse error. Save long graphs as `.sh`.
- **HyperFrames font gotcha:** never use `var(--font-*)` inside a `font-family` value — use a mapped
  name (`'Oswald'`, `'JetBrains Mono'`, `'Inter'`).
- **Relationship to `p-reels-fmt2`:** same PIP/cover/mask/audio engine; fmt2 = generated avatar over
  graphics, fmt5 = uploaded clip over transcript-synced b-roll+graphics. Neither subsumes the other.
