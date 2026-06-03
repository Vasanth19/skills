---
name: p-reels-fmt5
description: Make a vertical reel from an UPLOADED talking-head video as a bottom picture-in-picture (the COMPLETE face shown, fitted into the layout — never cropped) over a GRAPHICS-FORWARD, transcript-synced background — built beat-by-beat from the speaker's own words, primarily as generated Remotion/HyperFrames motion graphics, with at most 1–2 of the user's uploaded b-roll clips trimmed in where they genuinely fit. The talking head's own voice is the audio bed. Trigger on "make a reel from my talking-head video", "PIP reel from my uploaded video", "talking head over motion graphics matched to what I say", "transcribe my video and build graphics to the words", "trim my b-rolls to the transcript cues", "my video as the PIP with a graphics background", "talking-head PIP with HyperFrames + b-roll background", "uploaded talking head reel".
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
- `broll_media[]` (optional) — the user's uploaded b-roll clips, used only up to the **coverage
  budget** (`broll_coverage`, default 0.30 of the reel — see Step 3), trimmed tight to where they
  genuinely fit the wording. The background is graphics-forward (Remotion/HyperFrames); b-roll is the
  supplement, not the bed. **Clips with their own audio are transcribed too** — the cue timeline
  confirms the match and drives the trim window. NEVER concatenate full clips as the background.
  **When none are supplied, the reel is 100% graphics (0% coverage) — that is a valid, complete
  output, not a degraded one.**
- `broll_coverage` (optional, default **0.30**) — fraction of the reel filled by uploaded b-roll; the
  rest is authored graphics. The Creative Director sets this in the brief (more/less/explicit %).
  **Forced to 0** when no clips are supplied OR the brief says no b-roll ("graphics only", etc.).
- `brand` — palette + typography for the generated-graphics beats (resolve via the Visual Identity
  Gate: Brand Brief → DESIGN.md → named style → dark-premium. Never hard-code).
- `music_bed` (optional) — dark/moody instrumental under the VO at ≈ −18 LUFS; master to −14 LUFS.
- `pip_spec` (optional) — defaults to the proven bottom-center rounded square below.

## Parameter Table (inherits fmt2; deltas marked ★)

| Parameter | Default | Notes |
|---|---|---|
| Canvas | 1080×1920, 30 fps | 9:16 portrait |
| Canvas color | `#0F172A` | Only ever visible where a source has letterbox gaps — which the cover-crop removes |
| ★ Background source | **GRAPHICS-FORWARD** (Remotion/HyperFrames primary) | Most of the reel = authored motion graphics. Uploaded b-roll only fills the coverage budget below, trimmed tight — never all the clips, never full-length, never a montage. Never a bare black canvas. |
| ★ B-roll coverage | **`broll_coverage` = 0.30** (CD-overridable; **0** when no clips / no-b-roll instruction) | Fraction of total reel duration filled by uploaded b-roll; the rest is graphics. `broll_seconds = round(broll_coverage × total_duration)`. CD brief overrides ("more"/"less"/explicit %). 0% → 100% graphics. |
| Background fit | scale-to-COVER + center crop | `scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920` — fills the full frame, no pillarbox, no stretch. **Never `pad`/letterbox, never a distorting bare `scale=1080:1920`.** |
| ★ PIP source | **uploaded talking-head video** | NOT HeyGen. Opaque by default → no chroma-key. |
| ★ PIP fit | **scale-to-FIT — NEVER crop the face** | `scale=CARD_W:CARD_H:force_original_aspect_ratio=decrease` → the COMPLETE face shows, scaled down to fit. **Never** square-crop the face off (fmt5 v1 cut the chin). ffprobe the upload first. |
| ★ PIP card | portrait box ≤ 560×760 | Sized to the talking head's aspect so the whole frame fits un-cropped. Rounded corners optional (mask at the scaled size, not a fixed 540²). |
| ★ PIP position | bottom-center + **110px margin** | `overlay=(W-w)/2:(H-h-110)` — fully on-screen, NOT flush to the edge (fmt5 v1 buried it at y=1380 flush bottom). Keep background "real content" in the top ~60%. |
| ★ Audio | **talking head's own track** (primary VO) | Optional music bed at −18 LUFS under it; master loudnorm −14 LUFS. NO TTS. |
| Target duration | = talking-head length | The VO is the master; the background sequence is built to cover exactly it (`shortest=1`). |
| Encode | H.264, yuv420p, CRF 19, `+faststart` | aac stereo 48k 192k |

## PIP rounded corners (OPTIONAL — sized to the scaled card, not a fixed square)

fmt5's PIP is scale-to-FIT (so the whole face shows) → the card is **portrait, not a 540² square**, so
fmt2's fixed `pip-mask-540.png` does NOT apply. Rounded corners are optional; if wanted, generate a
rounded-rect RGBA mask at the SCALED `[thfit]` dimensions (PIL, white rounded rect r≈40 on
transparent) and `alphamerge` it in Step 5. Sharp corners are acceptable — the hard requirements are
the **complete face** and the **on-screen margin**, not the corner radius.

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

### 3 — Assign a background to each beat — GRAPHICS-FORWARD with a b-roll COVERAGE BUDGET

The background is **motion-graphics-forward**. The split between uploaded b-roll and authored graphics
is governed by a **coverage budget**, not a clip count:

- **DEFAULT: `broll_coverage = 0.30`** → uploaded b-roll fills ≈ **30%** of the total reel duration
  (the single most-appropriate moments); the other ≈ **70%** is authored Remotion/HyperFrames graphics.
- **The Creative Director overrides the default in the brief** — "more coverage", "less", or an
  explicit percentage. Honor whatever the CD specifies; otherwise use 0.30.
- **Force `broll_coverage = 0` (100% graphics) when EITHER:**
  - **no b-roll is supplied**, OR
  - **the brief/CD says no b-roll** ("no b-roll, just create the graphics", "all motion graphics",
    "0% coverage", "graphics only"). Ignore any clips and build the whole reel from graphics.

Compute the budget ONCE: `broll_seconds = round(broll_coverage × total_duration)`. Then per beat,
choose the background:

1. **Generated motion graphic — THE DEFAULT (≈70%+ of the reel).** Author an animated HyperFrames
   composition (or Remotion scene) **appropriate to that line** — a counter, a key-phrase callout, a
   diagram, brand ambient/VFX — at native 1080×1920, matching the Visual Identity Gate palette/type.
   This is Kyle's HyperFrames/Remotion path (see `f-hyperframes` / `f-remotion` and fmt2 Step 2; font
   gotcha: never put `var(--font-*)` in `font-family`). Render to MP4 ≥ the beat length.
2. **Uploaded b-roll — only up to the `broll_seconds` budget, trimmed tight.** Spend the budget on the
   beat(s) where uploaded footage genuinely fits the wording AND beats a graphic. **Stop once the
   budget is spent** — never exceed the coverage target (unless the CD raised it), never a full-length
   clip, never a montage of all clips. Trim each TIGHT:
   - If the clip carries its own audio, transcribe it (`c-audio`) and trim to the cue window where its
     audio lines up with the talking-head's words (`clip_in`→`clip_out`).
   - If silent, match by `c-broll` visual/label metadata and cut a SHORT relevant window (≈ the beat
     length — a few seconds, not the whole file).
   - Scale-to-COVER into 9:16; drop the clip's audio (`-an`) — the talking head's VO is the only voice.

**Doctrine: the background is RICH MOTION GRAPHICS governed by the coverage budget — NOT a reel of raw
clips.** Stringing together the user's entire b-roll videos is WRONG (the fmt5 v1 failure). At the 0.30
default, ~⅓ of the reel is trimmed b-roll moments and ~⅔ is authored graphics; with no clips or a
no-b-roll instruction it is **100% graphics**. The ONLY hard rule remains: **every beat has a real,
non-black background.**

Per-beat b-roll cover-cut (for the budgeted b-roll beat(s) only — `clip_in`/`clip_out` = the cue window
from the clip's own transcript when it has audio, else a short matched visual window → 9:16, audio stripped):
```bash
$FF -ss <clip_in> -to <clip_out> -i "$W/src/<clip>" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p" \
  -an -c:v libx264 -preset medium -crf 20 -y "$W/bg_beatN.mp4"
```
> If the cue window is shorter than the beat, loop/slow-mo or extend with the next-best section to
> cover the beat; if longer, trim to the cue's tightest relevant span. Never pad to black.

### 3.5 — Build all per-beat backgrounds IN PARALLEL (bounded to cores)

The per-beat background builds are **independent** — beat 1's b-roll cut/render does not depend on
beat 2's. Build them **concurrently** to cut wall-clock (a serial build of 5 beats is the slow path
that flirts with the runtime cap). Launch each beat's build (the Step-3 cover-cut, or the HyperFrames
render) as a background subprocess, bounded to the worker's core count (the VPS has 4 cores → cap at
3–4 in flight), then `wait` for all:

```bash
NPROC=$(nproc 2>/dev/null || echo 4); MAXJOBS=$(( NPROC > 1 ? NPROC - 1 : 1 ))
build_beat() {                  # $1 = beat index; resolves to a b-roll cut OR a graphics render
  case "${BG_KIND[$1]}" in
    broll)    $FF -ss "${CLIP_IN[$1]}" -to "${CLIP_OUT[$1]}" -i "${CLIP_SRC[$1]}" \
                -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p" \
                -an -c:v libx264 -preset medium -crf 20 -y "$W/bg_beat$1.mp4" ;;
    graphics) ( cd "$W/gfx_beat$1" && npx hyperframes render --output "$W/bg_beat$1.mp4" --quality high --fps 30 ) ;;
  esac
}
for i in "${!BG_KIND[@]}"; do
  build_beat "$i" &                                   # background subprocess per beat
  while [ "$(jobs -r | wc -l)" -ge "$MAXJOBS" ]; do wait -n; done   # throttle to MAXJOBS in flight
done
wait                                                   # barrier: all beats built
```

> **Concurrency notes.** ffmpeg is itself multi-threaded, so cap at `cores-1` to avoid thrash — more
> parallel encodes than cores is slower, not faster. Transcribing several b-roll clips' own audio
> (Step 3) is also independent → run those `c-audio` calls in the same bounded-parallel pattern. The
> HyperFrames/chromium renders are the heavy pole; if there are several graphics beats, parallelizing
> them is the biggest win. (A heavier alternative — fan the beats out to parallel CFW **sub-agents**
> via `consult_specialist` — exists, but for deterministic ffmpeg/render steps this in-skill shell
> parallelism is simpler, cheaper, and has no extra LLM cost.)

### 4 — Build + VERIFY the background track (before any compositing)

Concat the per-beat background segments (now all built) into one full-frame track that covers the whole VO:
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

### 5 — Composite the uploaded talking-head PIP over the background (FULL FACE, in-layout)

> **Two fmt5 v1 bugs this step fixes (owner-flagged):** (a) a top-anchored SQUARE crop
> (`crop=S:S:Xoff:0`) cut the chin → the complete face didn't show; (b) `overlay=270:1380` put the PIP
> flush at the very bottom edge → buried/clipped. **The fix: scale-to-FIT (never crop the face) +
> overlay with a margin (never flush).**

**Scale-to-FIT the talking head into a portrait card — the WHOLE face shows, no crop.** ffprobe `$TH`
`w,h`. Then fit it inside a card box (`force_original_aspect_ratio=decrease` → preserves aspect, fits
entirely, nothing cropped), and overlay bottom-center leaving a margin so the **entire card is
on-screen**. Uploaded clips are opaque → NO chroma-key:
```bash
CARD_W=560; CARD_H=760; MARGIN=110   # card box (portrait) + bottom/side safe margin
$FF -i "$W/bg-all.mp4" -i "$TH" \
  -filter_complex "\
[1:v]scale=${CARD_W}:${CARD_H}:force_original_aspect_ratio=decrease,setsar=1[thfit]; \
[0:v]format=yuv420p[bg]; \
[bg][thfit]overlay=(W-w)/2:(H-h-${MARGIN}):format=auto:shortest=1[v]" \
  -map "[v]" -map "1:a" \
  -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -movflags +faststart -y "$W/composed.mp4"
```
- `force_original_aspect_ratio=decrease` GUARANTEES the entire face is visible (the talking head is
  scaled down to fit the card, never cropped). For a portrait phone source the card ends up tall and
  narrow (e.g. 428×760); for a landscape source, short and wide — either way nothing is cut.
- `overlay=(W-w)/2:(H-h-110)` centers horizontally and leaves a **110px bottom margin** → the full PIP
  is on-screen, not buried at the edge.
- **Rounded corners (optional):** if a rounded look is wanted, generate a mask at the SCALED `[thfit]`
  dimensions (PIL rounded rect) and `alphamerge` it before the overlay — NOT the fixed 540² mask
  (the card is no longer square). Sharp corners are acceptable; full face + margin are the hard reqs.
- `shortest=1` clips to the talking head — the audio + duration master.

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
- [ ] **(b) The COMPLETE face shows in the PIP** — the whole head is visible: forehead to chin, not
      cropped at top OR bottom, not stretched. A cut-off chin/face = the scale-to-FIT failed (someone
      reintroduced a square crop) → fix Step 5 and re-render. **(fmt5 v1 bug — owner-flagged.)**
- [ ] **(c) The PIP is fully ON-SCREEN with a margin** — the entire PIP card sits inside the frame
      with a clear gap below it; it is NOT flush against / clipped by the bottom edge, NOT "buried."
      Flush/clipped = the margin was dropped → fix the `overlay=(W-w)/2:(H-h-110)` in Step 5. **(fmt5
      v1 bug — owner-flagged.)**
- [ ] **(d) Background respects the coverage budget** — graphics-forward: at the 0.30 default, only
      ~⅓ of the reel is trimmed b-roll and ~⅔ is authored graphics (or whatever % the CD set; **0%
      b-roll → 100% graphics** when none supplied / no-b-roll instruction). If the whole reel is the
      user's raw clips strung together, the background logic regressed → fix Step 3.
- [ ] **(e) Background fills the full width** — no pillarbox bars, no letterbox, no distortion.
- [ ] **(f) Brand colors correct** on the graphics beats — palette per the Visual Identity Gate, not
      washed out, not defaulted to white-on-black.

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
