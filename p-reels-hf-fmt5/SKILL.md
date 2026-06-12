---
name: p-reels-hf-fmt5
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
dependsOn: [c-audio, c-broll, c-ffmpeg, f-hyperframes, c-cloud-media, c-reel-premium]
---

# p-reels-hf-fmt5 — Uploaded Talking-Head PIP over Transcript-Synced Background

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

### 2 — Transcribe everything (talking head + b-roll cues) — feeds the plan

Transcribe `$TH`'s audio to word/segment timestamps (`c-audio` → whisper) → write `$W/th_transcript.json`
(`[{start,end,text}]`). **Beat segmentation is NOT done here — Opus does it in Step 3** from this
transcript (don't guess boundaries).

Also build the **b-roll cue index** so Opus can match footage to the wording: for each uploaded clip
that carries audio, transcribe it too (run these in parallel — independent) and write
`$W/broll_cues.json` = `[{ "clip":"<filename>", "cues":[{start,end,text}] }]`. Silent clips get an
entry with `cues:[]` (Opus then matches them by filename/label only). No b-roll supplied → write `[]`.

### 3 — PLAN the reel with OPUS (the brain — curated per-beat specs; kimi fallback)

This is the BRAIN step (plan-on-Opus, execute-on-Ollama — see
`.claude/knowledge/decisions/plan-opus-execute-ollama-render-architecture.md`). A capable model
(**Opus**, via the owner's Claude Max OAuth token = flat cost) reads the transcript + brand + the
b-roll's own cues and writes a CURATED plan, so the cheap executor never invents anything. This skill
subprocess runs on Ollama kimi; spawn a NESTED `claude --print` that UNSETS the Ollama routing so it
reaches Opus on the OAuth token:

```bash
# Build a b-roll cue index (each clip's own transcript) so Opus can match footage to the wording.
# (Transcribe clips that have audio in Step 2; write {clip,cues:[{in,out,text}]} into broll_cues.json.)
COVERAGE=0.30   # default; override from the brief (CD "more"/"less"/explicit %); 0 if no clips or "no b-roll"/"graphics only"
PLAN_PROMPT="You are planning a 9:16 vertical talking-head PIP reel. Output STRICT JSON ONLY (an array, no prose).
Talking-head transcript (timestamps): $(cat "$W/th_transcript.json")
Brand palette/type: <from brief; default MGG slate #0F172A + orange #F97316, Barlow Condensed 900 titles, JetBrains Mono eyebrows>.
Available b-roll + their own cues: $(cat "$W/broll_cues.json" 2>/dev/null || echo '[]')
broll_coverage=$COVERAGE (fraction of total seconds that may be b-roll; the REST is graphics).
Segment the VO into 3-6 beats covering the FULL duration. Each beat object:
{ \"start\":<s>, \"end\":<s>, \"kind\":\"graphics\"|\"broll\",
  \"eyebrow\":\"<short UPPERCASE mono label>\",
  \"ghost\":\"<ONE huge faint background word>\",
  \"title_html\":\"<punchy UPPERCASE headline; wrap the KEY word in <span class=accent>WORD</span>>\",
  \"broll\": {\"clip\":\"<filename>\",\"in\":<s>,\"out\":<s>} or null }
RULES: MOST beats are graphics. Total b-roll seconds <= broll_coverage*total_duration (0 => all graphics).
For a broll beat, pick the clip+window whose OWN cue text matches that line. Keep titles short."

# Opus via OAuth — unset the Ollama routing for THIS call only.
PLAN_JSON=$(env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u CLAUDE_CODE_SUBAGENT_MODEL \
  timeout 180 claude --print "$PLAN_PROMPT" --dangerously-skip-permissions 2>/dev/null \
  | python3 -c "import sys,re,json; m=re.search(r'\[.*\]', sys.stdin.read(), re.S); print(m.group(0) if m else '')")

# FALLBACK: Opus unavailable (OAuth fail / rate-limit / empty JSON) → plan on kimi (this subprocess's
# own model). Degraded but the render still completes; the job was never lost (Redis stream PEL).
if ! echo "$PLAN_JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "[fmt5] Opus planning unavailable — falling back to kimi planning"
  PLAN_JSON=$(claude --print "$PLAN_PROMPT" --dangerously-skip-permissions 2>/dev/null \
    | python3 -c "import sys,re; m=re.search(r'\[.*\]', sys.stdin.read(), __import__('re').S); print(m.group(0) if m else '')")
fi
echo "$PLAN_JSON" > "$W/plan.json"
python3 -c "import json; assert len(json.load(open('$W/plan.json')))>=1" || { echo "PLAN FAILED — no beats"; exit 1; }
```
The plan enforces the **coverage budget**: most beats `kind:"graphics"`; b-roll only up to
`broll_coverage × total_duration` (default 0.30; **0** → 100% graphics when no clips or a no-b-roll
instruction). Opus writes the exact graphics text per beat and picks the b-roll moment whose own cue
matches the line — so the executor never decides what to show.

### 3.5 — EXECUTE every beat IN PARALLEL on kimi (FILL the template / CUT the clip — never author)

Each beat is now FULLY SPECIFIED by `plan.json`. Render them concurrently (cores-1). A `graphics`
beat = **fill the shipped motion-card template** (zero authoring); a `broll` beat = cut the planned
cue window. Because every value is in the plan, the cheap executor **cannot** shortcut a graphics beat
into "just use the b-roll" or fabricate a URL — it has one mechanical job per beat:

```bash
SKILL_DIR=$(find "$HOME/.claude/skills" -maxdepth 2 -type d -name p-reels-hf-fmt5 2>/dev/null | head -1)
TPL="$SKILL_DIR/templates/motion-card.html"     # the parameterized card this skill ships
NPROC=$(nproc 2>/dev/null || echo 4); MAXJOBS=$(( NPROC > 1 ? NPROC - 1 : 1 ))

build_beat() {   # $1 = beat index
  python3 - "$1" "$W/plan.json" "$TPL" "$W" "$FF" <<'PY'
import json,sys,os,subprocess,html
i=int(sys.argv[1]); beat=json.load(open(sys.argv[2]))[i]; tpl=sys.argv[3]; W=sys.argv[4]; FF=sys.argv[5]
dur=round(float(beat["end"])-float(beat["start"]),2); out=f"{W}/bg_beat{i}.mp4"
if beat["kind"]=="broll" and beat.get("broll"):
    b=beat["broll"]
    subprocess.run([FF,"-ss",str(b["in"]),"-to",str(b["out"]),"-i",f'{W}/src/{b["clip"]}',
      "-vf","scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p",
      "-an","-c:v","libx264","-preset","medium","-crf","20","-y",out],check=True)
else:
    gdir=f"{W}/gfx_beat{i}"; os.makedirs(gdir,exist_ok=True)
    h=(open(tpl).read().replace("{{DURATION}}",str(dur))
       .replace("{{EYEBROW}}",html.escape(beat.get("eyebrow","")))
       .replace("{{GHOST}}",html.escape(beat.get("ghost","")))
       .replace("{{TITLE_HTML}}",beat.get("title_html","")))   # title_html raw — carries the <span class=accent>
    open(f"{gdir}/index.html","w").write(h)
    subprocess.run("npx hyperframes lint >/dev/null 2>&1; npx hyperframes render --output "+out+" --quality high --fps 30",
                   shell=True,cwd=gdir,check=True)
PY
}

N=$(python3 -c "import json;print(len(json.load(open('$W/plan.json'))))")
for i in $(seq 0 $((N-1))); do
  build_beat "$i" &
  while [ "$(jobs -r | wc -l)" -ge "$MAXJOBS" ]; do wait -n; done
done
wait     # barrier: every beat built
# sanity: every bg_beatN.mp4 exists + is non-trivial
for i in $(seq 0 $((N-1))); do [ -s "$W/bg_beat$i.mp4" ] || { echo "beat $i did not render"; exit 1; }; done
```
> **This is the whole point.** The model NEVER authors HTML or decides a background at runtime — Opus
> wrote the curated spec, the template carries the creative, kimi just fills + renders. A graphics beat
> can't silently become "use the clip instead," and a code model can't fabricate a URL — each beat is a
> mechanical fill-or-cut. Parallelized to cores-1 (HyperFrames/chromium is the heavy pole). For the
> b-roll beats, the planned window is the cue where the clip's own audio matched the words.

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

**Scale-to-FIT into a SMALL card; position by the upload's aspect.** ffprobe `$TH` `w,h`. Fit it into
a small card box (`force_original_aspect_ratio=decrease` → whole face, never cropped), then place it:
- **Portrait upload (h > w)** → **bottom-LEFT** (out of the way of the top-half text/graphics).
- **Square or landscape upload (w ≥ h)** → **bottom-CENTER**.

Uploaded clips are opaque → NO chroma-key. The template already keeps all text/graphics in the TOP
~52% so the PIP never blocks them:
```bash
read TW TH_H < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=' ' "$TH")
CARD_W=400; CARD_H=540; MARGIN=80     # SMALL card (owner: "make the PIP smaller")
if [ "$TH_H" -gt "$TW" ]; then XPOS="$MARGIN"; else XPOS="(W-w)/2"; fi   # portrait→left, else→center
$FF -i "$W/bg-all.mp4" -i "$TH" \
  -filter_complex "\
[1:v]scale=${CARD_W}:${CARD_H}:force_original_aspect_ratio=decrease,setsar=1[thfit]; \
[0:v]format=yuv420p[bg]; \
[bg][thfit]overlay=${XPOS}:(H-h-${MARGIN}):format=auto:shortest=1[v]" \
  -map "[v]" -map "1:a" \
  -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -movflags +faststart -y "$W/composed.mp4"
```
- `force_original_aspect_ratio=decrease` GUARANTEES the whole face is visible (scaled to fit, never
  cropped). A portrait phone clip fits to ~304×540; a landscape clip to ~400×225.
- Portrait → `overlay=80:(H-h-80)` (bottom-left); square/landscape → `overlay=(W-w)/2:(H-h-80)`
  (bottom-center). 80px margins so it's fully on-screen, never flush.
- Because the card is small + low and the text lives in the top ~52% (template `.content` top:7%,
  max-height:52%), **the PIP no longer blocks the words/graphics.**
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

### 8.5 — Premium polish pass (captions + SFX + grade) — DEFAULT ON

→ Skill: `c-reel-premium` — follow its Steps P1–P4 over `$OUT`:

```bash
PREMIUM_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" -maxdepth 4 -type d -name c-reel-premium 2>/dev/null | head -1)
# REEL_IN="$OUT"  REEL_OUT="$OUT"  WORDS_JSON="$W/th_transcript.json"  (already produced in Step 2)
# CAP_TOP=1020   <- the caption band MUST clear the bottom PIP card
# CAPTIONS=on  SFX=on  GRADE=<planner picks>
```

Format defaults: **CAP_TOP=1020** (bottom-PIP clearance), captions ON (word-synced kinetic
captions, brand-accent keyword pops), SFX ON, grade ON. The pass never extends/trims the reel and
never re-touches the audio mastering — the talking head's own voice stays exactly as mastered.

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
