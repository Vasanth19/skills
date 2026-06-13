---
name: p-reels-pip
description: Turn an uploaded talking-head video into a premium 9:16 reel where the speaker sits as a rounded bottom-center picture-in-picture over a full-frame transcript-synced background (uploaded b-roll where the words match, generated HyperFrames motion graphics elsewhere). The clip's own voice is the single audio bed — never cut, never replaced. Trigger on "make a reel from my talking-head video", "PIP reel from my uploaded video", "bottom PIP reel", "my video as the PIP with a graphics background", "talking head over motion graphics matched to what I say", "transcript-synced background with my face as PIP".
when-to-use: Use when the user UPLOADS their own talking-head clip (real face + real voice — NOT a HeyGen avatar) and wants a 9:16 reel where that clip sits as a rounded bottom-center PIP over a transcript-synced background. The background uses uploaded b-roll where clips match the spoken words, and generated HyperFrames motion graphics everywhere else. Use p-reels-spotlight for full-frame (speaker fills frame) and p-reels-faceless for no talking head. Provider wrappers (p-reels-pip-heygen) delegate to this skill — do NOT use those when the user has already uploaded a clip.
version: 1.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Uploaded Talking-Head PIP Reel
  format: 9:16 vertical video
  duration: 20-60s
inputs: [talking_head_video, broll, known_transcript, outro]
dependsOn: [c-ffmpeg, c-audio, c-reel-premium, c-broll-sync, c-typing-ui, f-hyperframes, f-hyperframes-cli, f-gsap]
metadata:
  hermes:
    vendored: [c-reel-premium, c-broll-sync, c-typing-ui, c-ffmpeg, c-audio, f-hyperframes, f-hyperframes-cli, f-gsap]
---

# p-reels-pip — Bottom PIP Reel from Uploaded Talking-Head Video

Produces one 9:16 (1080×1920) H.264 MP4: the user's **own uploaded talking-head clip** composited
as a **rounded bottom-center PIP** over a **full-frame transcript-synced background** — uploaded
b-roll where the words match, generated HyperFrames motion graphics everywhere else. The clip's
own voice is the single continuous audio bed.

**This is the merged core for two retired formats:**

| Old format | Maps to `p-reels-pip` how |
|---|---|
| `p-reels-fmt1` (webcam PIP, 100% motion graphics) | `broll=[]` → `broll_coverage_pct=0` → every beat is `graphics`. Degenerate case = fmt1. |
| `p-reels-hf-fmt5` (uploaded PIP, transcript-synced bg) | `broll=[...]` + coverage knobs → fmt5 behavior. The full general case. |

The degenerate case (no b-roll) is **valid and complete** — not degraded. The background is
100% motion graphics, which is exactly what fmt1 produced. With b-roll clips supplied, `c-broll-sync`
places them where the transcript matches, and generated graphics fill the gaps.

**Provider wrappers (`p-reels-pip-heygen`) delegate to this skill after generating the avatar.
All compositing logic lives here — the wrapper does provider work only (anti-drift law).**

## Layout — three zones, fixed

```
┌──────────────────────────────┐ 1080×1920
│  UPPER ZONE  (y 0 → ~1240)   │  ← full-frame background: b-roll (scale-to-COVER) or
│                              │     HyperFrames motion graphics. Content lives here.
│   [ transcript-synced bg ]   │     Graphics templates use pip-safe variant — content
│                              │     stays in top 55% (above y≈1040) so the PIP never
│  ── pip safe line ──          │     collides with on-screen text.
│                              │
│      ┌──────────────┐        │  BOTTOM ZONE: talking-head as a
│      │  TALKING-HEAD│        │  rounded bottom-center PIP card.
│      │   PIP card   │        │  Position: overlay=(W-w)/2:(H-h-110)
│      └──────────────┘        │  (110px bottom margin — never flush)
└──────────────────────────────┘
```

**v1 bug fixed:** overlays and graphics content MUST NOT enter the bottom PIP zone. Every
`c-typing-ui` call uses `VARIANT=pip-safe`. Every HyperFrames composition reserves the bottom
band in CSS (`--pip-band: 680px`).

---

## Inputs

| Param | Required | Default | Notes |
|---|---|---|---|
| `talking_head_video` | YES | — | Uploaded clip (real face + real voice). BOTH the PIP foreground AND the audio/duration master. Never replace with HeyGen or TTS. Download to local disk first. |
| `broll[]` | No | `[]` | Uploaded b-roll clips. Placed by `c-broll-sync` where the transcript matches. When empty → 100% graphics background (fmt1 degenerate). |
| `known_transcript` | No | — | Pre-computed word-level transcript `[{text,start,end}]`. Provided by wrapper skills (e.g. `p-reels-pip-heygen`) to skip re-transcription. |
| `outro` | No | off | Optional outro mp4 appended via concat. See Step 8. |

### c-broll-sync coverage params (passthrough)

| Param | Default | Meaning |
|---|---|---|
| `broll_coverage_pct` | `30` | Target % of bed covered by b-roll (rest is graphics). Set `0` for 100% graphics (fmt1 mode). |
| `broll_clip_seconds` | `4` | Default on-screen duration per b-roll window. |
| `broll_min_seconds` | `2` | Min window clamp. |
| `broll_max_seconds` | `6` | Max window clamp. |
| `broll_order` | `transcript-match` | `transcript-match` / `as-given` / `even`. |
| `broll_reuse` | `false` | Whether clips may be reused to hit the coverage target. |

---

## Parameter Table

| Parameter | Default | Notes |
|---|---|---|
| Canvas | 1080×1920, 30 fps | 9:16 portrait |
| Canvas color | `#0F172A` | Dark navy — visible only in letterbox gaps (scale-to-COVER removes them) |
| Background fit | FIT + BLURRED-FILL | Clip shown whole (no crop); heavy-blurred zoomed copy fills frame edges. Replaces scale-to-COVER which cropped non-9:16 sources (e.g. website captures) badly. |
| PIP source | uploaded talking-head | NOT HeyGen. Opaque by default — no chroma-key. |
| PIP fit | scale-to-FIT (face never cropped) | `scale=CARD_W:CARD_H:force_original_aspect_ratio=decrease` — whole face shows, scaled to fit. Never crop the face. |
| PIP card | 364×504 default, bottom-center | Portrait box sized to the upload's aspect (70% of the earlier 520×720 — smaller, less obtrusive PIP, 2026-06-13). Rounded corners (yuva444p mask at scaled size). |
| PIP position | `overlay=(W-w)/2:(H-h-110)` | 110px bottom margin, always centered (all aspect ratios). BUG FIX bake-off #2: portrait sources were incorrectly placed bottom-left; now centered for all uploads. |
| Audio | talking head's own track | No TTS, no music bed unless explicitly requested. Loudnormed once in Step 2. |
| Target duration | = talking-head length | The VO is the master; background is built to cover it exactly (`shortest=1`). |
| Encode | H.264, yuv420p, CRF 19, `+faststart` | AAC stereo 48k 192k |
| CAP_TOP | `1020` | Caption band clears the bottom PIP (c-reel-premium param). |

---

## Steps

Set up variables:

```bash
TH="<path to downloaded talking-head mp4>"
W="<production>/interim/pip" ; mkdir -p "$W" "$W/src" "$W/bg_beats"
OUT="<production>/final/pip-reel.mp4" ; mkdir -p "$(dirname "$OUT")"
FF="ffmpeg"
SKILL_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" "$HOME/.hermes/profiles" /Users/vasanth/Code/skills -maxdepth 5 -type d -name p-reels-pip 2>/dev/null | head -1)

# Locate component skills
# $HOME/.hermes/profiles is searched for box deployments where skills live under
# $HOME/.hermes/profiles/<slug>/skills/cfw/<skill>/
BROLL_SYNC_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" "$HOME/.hermes/profiles" /Users/vasanth/Code/skills -maxdepth 5 -type d -name c-broll-sync 2>/dev/null | head -1)
PREMIUM_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" "$HOME/.hermes/profiles" /Users/vasanth/Code/skills -maxdepth 5 -type d -name c-reel-premium 2>/dev/null | head -1)
TYPING_UI_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" "$HOME/.hermes/profiles" /Users/vasanth/Code/skills -maxdepth 5 -type d -name c-typing-ui 2>/dev/null | head -1)

# Coverage params (from brief / defaults)
BROLL_COVERAGE_PCT="${broll_coverage_pct:-30}"
BROLL_CLIP_SECS="${broll_clip_seconds:-4}"
BROLL_MIN_SECS="${broll_min_seconds:-2}"
BROLL_MAX_SECS="${broll_max_seconds:-6}"
BROLL_ORDER="${broll_order:-transcript-match}"
BROLL_REUSE="${broll_reuse:-false}"
```

### Step 1 — Localize + probe the talking-head video (MANDATORY)

> **Failure mode this prevents:** a remote URL that fails mid-render gives a black/blank layer.
> Download every source to local disk and ffprobe it BEFORE building anything.

```bash
# Download talking-head to $W/src/th.mp4 if it's a remote URL
# (use cfw-download or curl; never composite from remote URLs)

ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,duration,codec_name \
  -of default=noprint_wrappers=1 "$TH"

# duration is the MASTER reel length, the crop-math driver, and the background-coverage target
BED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TH")

# Verify speech is present (silent track = stop immediately)
$FF -hide_banner -i "$TH" -t 60 -af volumedetect -f null - 2>&1 \
  | grep -E "mean_volume|max_volume"
# max_volume near 0 dB, mean_volume ~-20 dB = real speech.
# ~-90 dB = STOP — no narration; report and ask for a different source.
```

### Step 1.5 — Detect + crop white side-bands (BEFORE anything else)

Reused or exported clips often carry flat-white/cream **side margins** from the recording
environment. Measure left/right edges vs the center; if bands exist, crop them (**left/right
only — NEVER the top**; the head must not be clipped).

```bash
TH_W=$(ffprobe -v error -select_streams v -show_entries stream=width  -of csv=p=0 "$TH")
TH_H=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$TH")

col_luma() {  # x → avg luma (0-255) of a 2px column at mid-frame
  v=$($FF -hide_banner -loglevel error -ss $(echo "$BED_DUR/2"|bc) -i "$TH" -vframes 1 \
        -vf "crop=2:$TH_H:$1:0,scale=1:1,format=gray" -f rawvideo - 2>/dev/null | xxd -p)
  echo $((16#$v))
}

BAND_LEFT=0
for x in $(seq 0 5 $((TH_W/2))); do
  [ "$(col_luma $x)" -lt 245 ] && { BAND_LEFT=$x; break; }
done
BAND_RIGHT=$TH_W
for x in $(seq $((TH_W-2)) -5 $((TH_W/2))); do
  [ "$(col_luma $x)" -lt 245 ] && { BAND_RIGHT=$((x+2)); break; }
done
CLEAN_W=$(( BAND_RIGHT - BAND_LEFT )); CLEAN_W=$(( CLEAN_W - CLEAN_W % 2 ))

if [ "$BAND_LEFT" -gt 4 ] || [ "$BAND_RIGHT" -lt $((TH_W-4)) ]; then
  $FF -y -i "$TH" -vf "crop=$CLEAN_W:$TH_H:$BAND_LEFT:0,setsar=1" \
    -c:v libx264 -pix_fmt yuv420p -c:a copy "$W/th-clean.mp4"
  TH_CLEAN="$W/th-clean.mp4"
else
  TH_CLEAN="$TH"
fi

# Re-probe cleaned clip dimensions
read TH_CW TH_CH < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=p=0:s=' ' "$TH_CLEAN")
```

### Step 2 — Build the loudnormed voice bed (ONCE, never again)

Scale-to-COVER to 1080×1920; loudnorm the audio **once here** — never re-normalize downstream.
The talking head is the duration master.

```bash
$FF -y -i "$TH_CLEAN" \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30" \
  -af "loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 -b:a 192k \
  "$W/bed.mp4"
BED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/bed.mp4")
echo "bed duration: $BED_DUR seconds"
```

### Step 3 — Transcribe with word timestamps (skip when known_transcript provided)

When a wrapper skill supplies `known_transcript` (e.g. p-reels-pip-heygen passes the script),
skip transcription and write `$W/transcript.json` directly from it.

```bash
if [ -n "$KNOWN_TRANSCRIPT_JSON" ]; then
  # Normalize word key: accept both {word,start,end} and {text,start,end}.
  # Wrappers (e.g. p-reels-pip-heygen) may supply either form; cores expect {text,...}.
  echo "$KNOWN_TRANSCRIPT_JSON" | python3 -c "
import json,sys
words=json.load(sys.stdin)
words=[{**w,'text':w.get('text') or w.get('word','')} for w in words]  # normalize word→text
print(json.dumps(words))
" > "$W/transcript.json"
  echo "[p-reels-pip] Using provided transcript — skipping transcription"
else
  # Transcribe the bed audio to word-level JSON.
  # Fallback chain: cfw-transcribe (preferred) → mlx_whisper → whisper → STOP.
  if command -v cfw-transcribe >/dev/null 2>&1; then
    cfw-transcribe --input "$W/bed.mp4" --out "$W/transcript.srt" --format srt
  elif command -v mlx_whisper >/dev/null 2>&1; then
    echo "[p-reels-pip] cfw-transcribe not found — falling back to mlx_whisper"
    mlx_whisper "$W/bed.mp4" --model mlx-community/whisper-small --output-dir "$W" --output-format srt
    mv "$W/bed.srt" "$W/transcript.srt"
  elif command -v whisper >/dev/null 2>&1; then
    echo "[p-reels-pip] cfw-transcribe not found — falling back to whisper CLI"
    whisper "$W/bed.mp4" --model small --output_dir "$W" --output_format srt
    mv "$W/bed.srt" "$W/transcript.srt"
  else
    echo "[p-reels-pip] FATAL: no transcription tool found (cfw-transcribe, mlx_whisper, or whisper). Install cfw-transcribe or provide known_transcript." >&2
    exit 1
  fi
  python3 - "$W/transcript.srt" "$W/transcript.json" <<'PY'
import re, json, sys
lines = open(sys.argv[1]).read().strip().split('\n\n')
words = []
for block in lines:
    parts = block.strip().split('\n')
    if len(parts) < 3: continue
    ts = parts[1]
    text = ' '.join(parts[2:])
    def t2s(ts_str):
        h,m,rest = ts_str.replace(',','.').split(':')
        return int(h)*3600+int(m)*60+float(rest)
    start_s, end_s = ts.split(' --> ')
    for word in text.split():
        words.append({"text": word, "start": t2s(start_s.strip()), "end": t2s(end_s.strip())})
json.dump(words, open(sys.argv[2], 'w'))
PY

  # Quality check: reject if >20% of entries are garbage (♪, [Music], etc.)
  python3 - "$W/transcript.json" <<'PY'
import json, sys, re
words = json.load(open(sys.argv[1]))
garbage = sum(1 for w in words if re.match(r'[♪\[\(]', w.get('text','')) or not w.get('text','').strip())
pct = garbage/len(words)*100 if words else 100
assert pct < 20, f"Transcript quality too low ({pct:.0f}% garbage). Retry with --model medium."
print(f"Transcript OK: {len(words)} words, {pct:.1f}% garbage")
PY
fi
```

### Step 4 — Build the b-roll cue index (for c-broll-sync)

Transcribe each b-roll clip's audio (parallel). Silent clips get `cues: []`. No b-roll supplied
→ write `[]`.

```bash
# For each clip in $BROLL_CLIPS[] (array of local paths):
# broll_cues.json schema: [{"clip":"filename.mp4","duration":12.4,"cues":[{start,end,text}]}]

BROLL_CUES_JSON="[]"   # default: no b-roll

if [ ${#BROLL_CLIPS[@]} -gt 0 ]; then
  TMP_CUES="$W/broll_cues_build"
  mkdir -p "$TMP_CUES"
  BROLL_CUES_JSON="["
  FIRST=1

  build_broll_cue() {
    local clip="$1"
    local fname=$(basename "$clip")
    local dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$clip" 2>/dev/null || echo 0)
    local srt_out="$TMP_CUES/${fname%.mp4}.srt"
    local cues_out="$TMP_CUES/${fname%.mp4}.json"

    # Check if clip has audio
    local has_audio=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$clip" 2>/dev/null | head -1)
    if [ -n "$has_audio" ]; then
      # Use same transcribe fallback chain as Step 3
      if command -v cfw-transcribe >/dev/null 2>&1; then
        cfw-transcribe --input "$clip" --out "$srt_out" --format srt 2>/dev/null
      elif command -v mlx_whisper >/dev/null 2>&1; then
        mlx_whisper "$clip" --model mlx-community/whisper-small --output-dir "$(dirname "$srt_out")" --output-format srt 2>/dev/null && \
        mv "$(dirname "$srt_out")/$(basename "$clip" .mp4).srt" "$srt_out" 2>/dev/null || true
      elif command -v whisper >/dev/null 2>&1; then
        whisper "$clip" --model small --output_dir "$(dirname "$srt_out")" --output_format srt 2>/dev/null && \
        mv "$(dirname "$srt_out")/$(basename "$clip" .mp4).srt" "$srt_out" 2>/dev/null || true
      fi
      [ -f "$srt_out" ] && python3 - "$srt_out" "$cues_out" <<'PY'
import re, json, sys
lines = open(sys.argv[1]).read().strip().split('\n\n')
cues = []
for block in lines:
    parts = block.strip().split('\n')
    if len(parts) < 3: continue
    ts = parts[1]; text = ' '.join(parts[2:])
    def t2s(s): h,m,rest=s.replace(',','.').split(':'); return int(h)*3600+int(m)*60+float(rest)
    start_s, end_s = ts.split(' --> ')
    cues.append({"start": t2s(start_s.strip()), "end": t2s(end_s.strip()), "text": text.strip()})
json.dump(cues, open(sys.argv[2], 'w'))
PY
    else
      echo "[]" > "$cues_out"
    fi

    # Return JSON entry (written to stdout for collection)
    local cues_json=$(cat "$cues_out" 2>/dev/null || echo '[]')
    echo "{\"clip\":\"$fname\",\"duration\":$dur,\"cues\":$cues_json}"
  }

  # Run in parallel (cores-1)
  NPROC=$(nproc 2>/dev/null || echo 4)
  MAXJOBS=$(( NPROC > 1 ? NPROC - 1 : 1 ))
  ENTRY_FILES=()
  for clip in "${BROLL_CLIPS[@]}"; do
    out_f="$TMP_CUES/$(basename "$clip" .mp4)_entry.json"
    build_broll_cue "$clip" > "$out_f" &
    ENTRY_FILES+=("$out_f")
    while [ "$(jobs -r | wc -l)" -ge "$MAXJOBS" ]; do wait -n; done
  done
  wait

  # Assemble into array
  BROLL_CUES_JSON=$(python3 -c "
import json, sys
entries = []
for f in sys.argv[1:]:
    try:
        entries.append(json.loads(open(f).read()))
    except: pass
print(json.dumps(entries))
" "${ENTRY_FILES[@]}")
  echo "$BROLL_CUES_JSON" > "$W/broll_cues.json"
fi

echo "$BROLL_CUES_JSON" > "$W/broll_cues.json"
echo "[p-reels-pip] broll cue index: $(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(len(d),"clips")' < "$W/broll_cues.json")"
```

### Step 5 — Plan the background beat list with c-broll-sync (OPUS brain)

`c-broll-sync` reads the transcript + b-roll cues + coverage params and emits an ordered
`beat_list.json` — each beat tagged `broll(clip,in,out)` or `graphics(scene)`. The executor
never decides what to show; OPUS does.

```bash
node "$BROLL_SYNC_DIR/scripts/plan.js" \
  --transcript "$W/transcript.json" \
  --broll      "$W/broll_cues.json" \
  --coverage   "$BROLL_COVERAGE_PCT" \
  --clip-secs  "$BROLL_CLIP_SECS" \
  --min-secs   "$BROLL_MIN_SECS" \
  --max-secs   "$BROLL_MAX_SECS" \
  --order      "$BROLL_ORDER" \
  --reuse      "$BROLL_REUSE" \
  --bed-dur    "$BED_DUR" \
  --brand      "$W/brand.json" \
  --out        "$W/beat_list.json"

# Validate output
python3 - "$W/beat_list.json" "$BED_DUR" <<'PY'
import json, sys
bl = json.load(open(sys.argv[1]))
assert bl["beats"], "no beats in beat_list.json"
# Verify gapless coverage
prev_end = 0.0
for b in bl["beats"]:
    assert abs(b["start"] - prev_end) < 0.15, f"gap at beat {b['index']}: {prev_end} → {b['start']}"
    prev_end = b["end"]
print(f"beat_list OK: {len(bl['beats'])} beats, achieved broll {bl.get('achieved_broll_pct',0):.1f}%")
PY

# Also extract the cover_at timestamp from the beat list (first non-hook graphics beat, or 30% in)
COVER_AT=$(python3 -c "
import json; bl=json.load(open('$W/beat_list.json'))
mid = float('$BED_DUR') * 0.30
# Find first beat at/after the 30% mark
for b in bl['beats']:
    if b['start'] >= mid:
        print(round(b['start'] + (b['end']-b['start'])*0.5, 2))
        break
else:
    print(round(float('$BED_DUR')*0.35, 2))
")
echo "[p-reels-pip] cover_at: ${COVER_AT}s"
```

### Step 6 — Build + verify the background track (before any compositing)

Each beat is built concurrently. `graphics` beats render via c-typing-ui (for typing/hook scenes)
or a brand motion-card template. `broll` beats are trimmed with scale-to-COVER. All result in
`$W/bg_beats/bg_beat<N>.mp4` (1080×1920, 30fps, no audio).

```bash
NPROC=$(nproc 2>/dev/null || echo 4)
MAXJOBS=$(( NPROC > 1 ? NPROC - 1 : 1 ))
N_BEATS=$(python3 -c "import json; print(len(json.load(open('$W/beat_list.json'))['beats']))")

build_beat() {
  local i=$1
  python3 - "$i" "$W/beat_list.json" "$W" "$FF" "$TYPING_UI_DIR" "$SKILL_DIR" <<'PY'
import json, sys, os, subprocess, html, shutil

i = int(sys.argv[1])
bl = json.load(open(sys.argv[2]))
beat = bl["beats"][i]
W, FF = sys.argv[3], sys.argv[4]
TYPING_UI_DIR, SKILL_DIR = sys.argv[5], sys.argv[6]

dur = round(float(beat["end"]) - float(beat["start"]), 2)
out = f"{W}/bg_beats/bg_beat{i}.mp4"

if beat["kind"] == "broll":
    b = beat["broll"]
    # Locate the clip in $W/src/
    clip_path = os.path.join(W, "src", b["clip"])
    # FIT + BLURRED-FILL composite: the clip is shown whole (no cropping), a
    # heavy-blurred zoomed copy fills the frame edges.  This replaces scale-to-COVER
    # (force_original_aspect_ratio=increase + crop) which cropped the edges off
    # non-9:16 sources like website screen-captures — producing a bad look.
    # For true 9:16 clips the fit copy == the frame; blurred-fill is a harmless no-op.
    # Blur strength is tunable: boxblur=40:2 is the default (stronger = more separation).
    subprocess.run([FF,
        "-ss", str(b["in"]), "-to", str(b["out"]), "-i", clip_path,
        "-vf", (
            "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,"
            "boxblur=40:2,setsar=1[bg];"
            "[0:v]scale=1080:1920:force_original_aspect_ratio=decrease,setsar=1[fg];"
            "[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p,fps=30[bv]"
        ),
        "-map", "[bv]",
        "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-y", out
    ], check=True)
else:
    # Graphics beat
    scene = beat.get("scene", {})
    scene_type = scene.get("type", "")
    gdir = f"{W}/gfx_beat{i}"; os.makedirs(gdir, exist_ok=True)

    if scene_type == "typing-ui":
        # Use c-typing-ui pip-safe variant.
        # BUG FIX: standalone HyperFrames render requires:
        #   1. Full HTML doc (doctype + html/head/body) with GSAP loaded in <head>
        #   2. Root div has data-composition-id="root" data-start="0" data-duration="N"
        #      (NO <template> wrapper — stripped below)
        #   3. window.__timelines["root"] = tl (dict form, NOT .push())
        # c-typing-ui templates use <template> wrapper for sub-composition use; strip it here.
        # Also strip HTML comments — lint v0.6.95 misreads root element on <!-- after <body>.
        tmpl = open(f"{TYPING_UI_DIR}/templates/typing-scene.html").read()
        import re
        tmpl = re.sub(r'<template[^>]*>\s*', '', tmpl)
        tmpl = re.sub(r'\s*</template>', '', tmpl)
        tmpl = re.sub(r'<!--.*?-->', '', tmpl, flags=re.DOTALL)
        replacements = {
            "DURATION": str(dur),
            "LABEL": html.escape(scene.get("label", "claude.ai")),
            "PROMPT": html.escape(scene.get("prompt", "")),
            "TYPING_SPEED": str(scene.get("typing_speed", "1.0")),
            "ACCENT": scene.get("brand", {}).get("accent", "F97316").lstrip("#"),
            "VARIANT": "pip-safe",
            "BOTTOM_TAG": html.escape(scene.get("bottom_tag", "")),
        }
        body = tmpl
        for k, v in replacements.items():
            body = body.replace("{{" + k + "}}", v)
        idx_html = (f'<!DOCTYPE html>\n<html><head><meta charset="utf-8">\n'
                    f'<script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>\n'
                    f'<style>html,body{{margin:0;padding:0;width:1080px;height:1920px;overflow:hidden;}}</style>\n'
                    f'</head><body>{body}</body></html>')
    elif scene_type == "hook":
        # Use c-typing-ui hook variant (standalone — same rules as typing-ui above).
        # Strip HTML comments — lint v0.6.95 false root_missing_composition_id on <!-- after <body>.
        tmpl = open(f"{TYPING_UI_DIR}/templates/hook-scene.html").read()
        import re
        tmpl = re.sub(r'<template[^>]*>\s*', '', tmpl)
        tmpl = re.sub(r'\s*</template>', '', tmpl)
        tmpl = re.sub(r'<!--.*?-->', '', tmpl, flags=re.DOTALL)
        replacements = {
            "DURATION": str(dur),
            "EYEBROW": html.escape(scene.get("eyebrow", "")),
            "LINE1": scene.get("title_html", html.escape(scene.get("ghost", ""))),
            "LINE2": scene.get("line2", ""),
            "LINE3": scene.get("line3", ""),
            "SUBHEAD": scene.get("subhead", ""),
            "ACCENT": scene.get("brand", {}).get("accent", "F97316").lstrip("#"),
        }
        body = tmpl
        for k, v in replacements.items():
            body = body.replace("{{" + k + "}}", v)
        idx_html = (f'<!DOCTYPE html>\n<html><head><meta charset="utf-8">\n'
                    f'<script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>\n'
                    f'<style>html,body{{margin:0;padding:0;width:1080px;height:1920px;overflow:hidden;}}</style>\n'
                    f'</head><body>{body}</body></html>')
    else:
        # Standard motion card — fill the shipped template
        # Motion card template reserves --pip-band: 680px in CSS (content above y≈1240)
        tpl_path = f"{SKILL_DIR}/templates/motion-card.html"
        tmpl = open(tpl_path).read()
        replacements = {
            "DURATION": str(dur),
            "EYEBROW": html.escape(scene.get("eyebrow", "")),
            "GHOST": html.escape(scene.get("ghost", "")),
            "TITLE_HTML": scene.get("title_html", ""),  # raw: may contain <span class="accent">
            "ACCENT": scene.get("brand", {}).get("accent", "F97316"),
            "BG": scene.get("brand", {}).get("bg", "0F172A"),
            "FG": scene.get("brand", {}).get("fg", "F1F5F9"),
        }
        body = tmpl
        for k, v in replacements.items():
            body = body.replace("{{" + k + "}}", v)
        # Wrap in standalone full HTML document.
        # BUG FIX: strip <template> wrapper first (required for standalone render),
        # then inject data-composition-id="root" data-start="0" data-duration="N"
        # onto the .mc-root div so HyperFrames lint passes and the timeline
        # registered as window.__timelines["root"] is correctly resolved.
        # BUG FIX (bake-off #2 2026-06-12 — hyperframes lint v0.6.95 root_missing_composition_id):
        # lint v0.6.95 misreads the root element when an HTML comment (<!-- ... -->)
        # sits right after <body>, producing a false root_missing_composition_id error.
        # Strip all HTML comments from the body BEFORE running lint.
        import re
        body = re.sub(r'<template[^>]*>\s*', '', body)
        body = re.sub(r'\s*</template>', '', body)
        body = re.sub(r'<!--.*?-->', '', body, flags=re.DOTALL)  # strip HTML comments (lint workaround)
        # Add HyperFrames timing attrs to the mc-root div (first occurrence)
        body = re.sub(
            r'<div class="mc-root">',
            f'<div class="mc-root" data-composition-id="root" data-start="0" data-duration="{dur}" data-width="1080" data-height="1920">',
            body, count=1)
        idx_html = (f'<!DOCTYPE html>\n<html><head><meta charset="utf-8">\n'
                    f'<script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>\n'
                    f'<style>html,body{{margin:0;padding:0;width:1080px;height:1920px;overflow:hidden;}}</style>\n'
                    f'</head><body>{body}</body></html>')

    open(f"{gdir}/index.html", "w").write(idx_html)
    subprocess.run(
        f"npx hyperframes lint >/dev/null 2>&1 && "
        f"npx hyperframes render --output {out} --quality high --fps 30",
        shell=True, cwd=gdir, check=True
    )

print(f"beat {i} ({beat['kind']}) done → {out}")
PY
}

for i in $(seq 0 $((N_BEATS-1))); do
  build_beat "$i" &
  while [ "$(jobs -r | wc -l)" -ge "$MAXJOBS" ]; do wait -n; done
done
wait  # barrier: all beats built

# Sanity: every bg_beatN.mp4 exists and is non-trivial
for i in $(seq 0 $((N_BEATS-1))); do
  [ -s "$W/bg_beats/bg_beat$i.mp4" ] || { echo "[p-reels-pip] FATAL: beat $i did not render"; exit 1; }
done

# Concat all beats into bg-all.mp4 (normalized to 1080x1920/30fps/yuv420p first)
python3 - "$W" "$N_BEATS" <<'PY' > "$W/bg_concat.sh"
import sys
W, N = sys.argv[1], int(sys.argv[2])
lines = [f"file '{W}/bg_beats/bg_beat{i}.mp4'" for i in range(N)]
open(f"{W}/bg_concat.txt", "w").write("\n".join(lines))
print(f'ffmpeg -y -f concat -safe 0 -i "{W}/bg_concat.txt" '
      f'-vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p" '
      f'-c:v libx264 -preset medium -crf 20 -an "{W}/bg-all.mp4"')
PY
bash "$W/bg_concat.sh"

# VERIFY background is not black BEFORE compositing
echo "[p-reels-pip] Verifying background brightness..."
for t in 1 $(python3 -c "print(round(float('$BED_DUR')/2,1))") $(python3 -c "print(round(float('$BED_DUR')-1,1))"); do
  $FF -ss "$t" -i "$W/bg-all.mp4" -frames:v 1 \
    -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG" -f null - 2>&1 | grep -o 'YAVG=[0-9.]*'
done
# YAVG ~0 on all samples → background is black → FIX before proceeding.
```

### Step 7 — Composite the talking-head PIP over the background

The talking head is scale-to-FIT (whole face preserved — never cropped). Positioned bottom-center
with a 110px bottom margin (never flush). Audio comes from the talking-head track.

```bash
read TH_CW TH_CH < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=p=0:s=' ' "$TH_CLEAN")

# PIP card: portrait box sized to the upload's aspect.
# SIZING HISTORY: 440×600 (too small) → 520×720 (bake-off #1) → 364×504 (user pref
# 2026-06-13: 70% of 520×720 — a smaller, less obtrusive PIP so the graphics/b-roll
# background carries more of the frame). Still fits the canvas with full margin room.
CARD_W=364; CARD_H=504; MARGIN=110

# All uploads → bottom-CENTER: overlay=(W-w)/2:(H-h-110)
# BUG FIX (bake-off #2 2026-06-12): portrait sources (h > w) were placed
# bottom-LEFT (XPOS=$MARGIN) producing an asymmetric layout. Changed to
# center for all aspect ratios — the PIP card is centered over the frame.
XPOS="(W-w)/2"

# Optional: generate rounded-corner mask at the SCALED dimensions
# (PIL rounded rect r≈40 at the actual ${CARD_W}x${CARD_H} after scale-to-FIT)
# If mask does not exist at this size, skip alphamerge (sharp corners are acceptable)
MASK_PATH=""
if python3 -c "
from PIL import Image, ImageDraw
import sys
W, H, R = $CARD_W, $CARD_H, 40
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
draw.rounded_rectangle([0, 0, W-1, H-1], radius=R, fill=(255, 255, 255, 255))
img.save('$W/pip-mask-${CARD_W}x${CARD_H}.png')
" 2>/dev/null; then
  MASK_PATH="$W/pip-mask-${CARD_W}x${CARD_H}.png"
fi

# Build filter_complex — one line, no comments, no embedded newlines
#
# BUG FIX (bake-off 2026-06-12 — yuv420p alphamerge "Invalid argument"):
# alphamerge requires both inputs to be in an alpha-capable pixel format (yuva*).
# The talking-head clip is yuv420p (no alpha channel). Passing it directly to
# alphamerge fails with "Invalid argument" / "Filtering has failed".
# Fix: convert the scaled TH to yuva444p BEFORE alphamerge. The mask PNG
# (RGBA from PIL) feeds as the alpha plane source; alphamerge copies that plane
# onto the converted TH, yielding an YUVA stream that overlay can handle.
# Filter chain (mask path):
#   [TH] scale→FIT → format=yuva444p → [thfit]
#   [thfit][MASK]  alphamerge → [avpip]   (MASK alpha becomes TH alpha)
#   [BG] format=yuv420p → [bg]
#   [bg][avpip]    overlay → [v]
#
# Note: alphamerge preserves luma/chroma from [thfit] and replaces the alpha
# channel with the luma of [MASK]. The PIL mask has 255 inside the rounded rect
# and 0 outside, so the talking-head appears only inside the rounded corners.
if [ -n "$MASK_PATH" ]; then
  # BUG FIX (bake-off #2 2026-06-12 — alphamerge AVERROR(EINVAL) dim mismatch):
  # A 9:16 talking head scales to FIT inside the 520×720 card as 404×720, leaving
  # a 116px horizontal gap. alphamerge requires both inputs (scaled TH and the mask)
  # to have IDENTICAL dimensions. The mask is always 520×720 (PIL-generated).
  # Without pad, the 404×720 scaled TH fails alphamerge with AVERROR(EINVAL).
  # Fix: add pad=${CARD_W}:${CARD_H}:(ow-iw)/2:0 after scale to letterbox-center
  # the FIT result to exactly the card dimensions before the format conversion.
  FC="[1:v]scale=${CARD_W}:${CARD_H}:force_original_aspect_ratio=decrease,pad=${CARD_W}:${CARD_H}:(ow-iw)/2:0,setsar=1,format=yuva444p[thfit];[thfit][2:v]alphamerge[avpip];[0:v]format=yuv420p[bg];[bg][avpip]overlay=${XPOS}:(H-h-${MARGIN}):format=auto:shortest=1[v];[1:a]anull[a]"
  $FF -y -i "$W/bg-all.mp4" -i "$W/bed.mp4" -i "$MASK_PATH" \
    -filter_complex "$FC" \
    -map "[v]" -map "[a]" \
    -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 \
    -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
    "$W/composed.mp4"
else
  FC="[1:v]scale=${CARD_W}:${CARD_H}:force_original_aspect_ratio=decrease,setsar=1[thfit];[0:v]format=yuv420p[bg];[bg][thfit]overlay=${XPOS}:(H-h-${MARGIN}):format=auto:shortest=1[v];[1:a]anull[a]"
  $FF -y -i "$W/bg-all.mp4" -i "$W/bed.mp4" \
    -filter_complex "$FC" \
    -map "[v]" -map "[a]" \
    -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 \
    -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
    "$W/composed.mp4"
fi
# shortest=1 clips to the talking head (the audio + duration master)
```

**PIP geometry rationale (from fmt2 canonical + fmt5 fix):**
- `force_original_aspect_ratio=decrease` → whole face visible, never cropped (fmt5 v1 bug fix)
- `overlay=(W-w)/2:(H-h-110)` → 110px bottom margin (fmt5 v1 buried PIP at y=1380 flush bottom)
- Card is portrait (not fixed square) → mask generated at scaled size, not a fixed 540² PNG

### Step 8 — CTA end-card (tail TAKEOVER — does NOT extend the reel)

Render a 2.5–3s brand CTA card (HyperFrames, silent), overlay on the FINAL seconds of the bed
using a time-gated `enable=` window. The reel ENDS when the speaker ends — nothing appended.
Total reel duration = `BED_DUR`.

```bash
CTA_DURATION="${CTA_DURATION:-3.0}"
CTA_TEXT="${CTA_TEXT:-FOLLOW FOR MORE}"
CTA_HANDLE="${CTA_HANDLE:-@handle}"

# Render CTA card as HyperFrames composition (reuse p-reels-fmt3 Step 7 pattern)
cat > "$W/cta-card.json" <<JSON
{
  "duration": ${CTA_DURATION},
  "fps": 30,
  "size": [1080, 1920],
  "layers": [
    { "type": "hero",   "text": "${CTA_TEXT}",   "y": 760, "wrap": true },
    { "type": "handle", "text": "${CTA_HANDLE}", "y": 1180 }
  ]
}
JSON

hyperframes render "$W/cta-card.json" "$W/cta-card.mp4" 2>/dev/null || {
  # Fallback: minimal HyperFrames composition
  mkdir -p "$W/cta"
  cat > "$W/cta/index.html" <<HTML
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>html,body{margin:0;padding:0;width:1080px;height:1920px;overflow:hidden;background:#0F172A;display:flex;flex-direction:column;align-items:center;justify-content:center;}
h1{color:#F1F5F9;font-family:Oswald,sans-serif;font-size:120px;font-weight:900;text-align:center;margin:0;padding:0 80px;}
p{color:#F97316;font-family:Inter,sans-serif;font-size:56px;opacity:0.9;margin-top:40px;}</style>
</head><body>
<h1>${CTA_TEXT}</h1><p>${CTA_HANDLE}</p>
</body></html>
HTML
  cd "$W/cta" && npx hyperframes lint && npx hyperframes render --output "$W/cta-card.mp4" --fps 30 --quality high
  cd -
}

COMPOSED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/composed.mp4")
CTA_START=$(python3 -c "print(round(${COMPOSED_DUR} - ${CTA_DURATION}, 3))")

$FF -y -i "$W/composed.mp4" -itsoffset "${CTA_START}" -i "$W/cta-card.mp4" \
  -filter_complex "[0:v][1:v]overlay=enable='between(t,${CTA_START},${COMPOSED_DUR})':eof_action=pass[v]" \
  -map "[v]" -map 0:a \
  -c:v libx264 -pix_fmt yuv420p -c:a copy -movflags +faststart "$W/with-cta.mp4"

# Verify CTA did NOT extend the reel (within ±0.1s)
FINAL_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/with-cta.mp4")
python3 -c "
dur, final = float('$COMPOSED_DUR'), float('$FINAL_DUR')
assert abs(dur - final) < 0.1, f'CTA extended the reel: {dur:.2f}s → {final:.2f}s'
print(f'CTA OK: {final:.2f}s (was {dur:.2f}s)')
"

# Optional outro append (if provided)
if [ -n "${OUTRO_PATH:-}" ] && [ -f "$OUTRO_PATH" ]; then
  # Normalize outro to matching spec, concat via demuxer
  $FF -y -i "$OUTRO_PATH" \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p" \
    -c:v libx264 -preset medium -crf 20 -an "$W/outro-norm.mp4"
  printf "file '%s'\nfile '%s'\n" "$W/with-cta.mp4" "$W/outro-norm.mp4" > "$W/outro_concat.txt"
  $FF -y -f concat -safe 0 -i "$W/outro_concat.txt" -c copy "$W/pre-premium.mp4"
else
  cp "$W/with-cta.mp4" "$W/pre-premium.mp4"
fi
```

### Step 8.5 — c-reel-premium pass (captions + SFX + grade) — DEFAULT ON

```bash
PW="$W/premium"; mkdir -p "$PW"

# Set component vars for c-reel-premium
REEL_IN="$W/pre-premium.mp4"
REEL_OUT="$W/polished.mp4"
WORDS_JSON="$W/transcript.json"
CAP_TOP=1020      # MUST clear the bottom PIP card
CAPTIONS="${CAPTIONS:-on}"
SFX="${SFX:-on}"
GRADE="${GRADE:-}"  # planner picks; default = clean-bright

# Follow c-reel-premium Steps P1–P4
# Source its SKILL.md and run the planning + render + grade/audio steps in $PW
# P1: OPUS plans captions + SFX + grade
# P2: renders caption overlay HyperFrames comp (skip if CAPTIONS=off)
# P3: grades + mixes SFX under original audio (amix=normalize=0 — never re-loudnorm)
# P4: QA gate (frame spot-checks + clean decode)

DUR_CHECK=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$REEL_IN")

# --- P1 ---
PLAN_PROMPT="You are planning the PREMIUM POLISH layer for an assembled 9:16 reel (captions + SFX + grade — the picture is already edited; do NOT plan any takeovers or cuts).
Output STRICT JSON ONLY (one object, no prose).
Word transcript: $(cat "$WORDS_JSON")
Total duration: $DUR_CHECK seconds.
Brand: <from brief via Visual Identity Gate; default accent #F97316, fg #F1F5F9>.
Schema:
{ \"grade\": \"warm-amber|clean-bright\",
  \"brand\": {\"accent\":\"#hex6\",\"fg\":\"#hex6\"},
  \"caption_groups\": [ {\"start\":s,\"end\":s,\"style\":0|1|2,
        \"words\":[{\"w\":\"TEXT\",\"s\":start,\"e\":end,\"em\":false}] } ],
  \"sfx\": [ {\"t\":s,\"name\":\"whoosh-deep|whoosh-air|impact-sub|impact-punch|riser|click|pop|swipe\",\"gain\":0.0-0.6} ] }
RULES:
1. caption_groups cover the FULL duration, 2-4 words each, non-overlapping.
2. LATIN SCRIPT ONLY: transliterate any non-Latin script phonetically. NEVER translate.
3. At most ONE word per group gets \"em\":true.
4. \"style\" cycles 0/1/2 — never same style on adjacent groups.
5. sfx: 4-10 cues total; gain <=0.6. None in first 1s.
IMPORTANT: CAP_TOP=$CAP_TOP — captions must NOT enter the bottom $((1920-CAP_TOP))px (the PIP zone)."

PREMIUM_PLAN=$(env -u ANTHROPIC_BASE_URL -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u CLAUDE_CODE_SUBAGENT_MODEL \
  timeout 240 claude --print "$PLAN_PROMPT" --dangerously-skip-permissions 2>/dev/null \
  | python3 -c "import sys,re; m=re.search(r'\{.*\}', sys.stdin.read(), re.S); print(m.group(0) if m else '')")

if ! echo "$PREMIUM_PLAN" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "[p-reels-pip] Opus unavailable — planning premium on kimi"
  PREMIUM_PLAN=$(claude --print "$PLAN_PROMPT" --dangerously-skip-permissions 2>/dev/null \
    | python3 -c "import sys,re; m=re.search(r'\{.*\}', sys.stdin.read(), __import__('re').S); print(m.group(0) if m else '')")
fi
echo "$PREMIUM_PLAN" > "$PW/plan.json"

# Validate
python3 - "$PW/plan.json" "$DUR_CHECK" <<'PY'
import json,re,sys
p=json.load(open(sys.argv[1])); dur=float(sys.argv[2])
assert p["caption_groups"], "no caption groups"
assert abs(p["caption_groups"][-1]["end"]-dur) < 3.0, "captions do not cover the reel"
assert not re.search(r'[ऀ-ॿ]', json.dumps(p)), "Devanagari in plan — Latin script only"
print(f"premium plan OK: {len(p['caption_groups'])} groups, {len(p.get('sfx',[]))} sfx")
PY

# --- P2: render caption overlay ---
if [ "${CAPTIONS:-on}" = "on" ]; then
  python3 - "$PW" "$PREMIUM_DIR" "$REEL_IN" "$CAP_TOP" <<'PY'
import json, os, shutil, sys, subprocess
PW, PREMIUM, REEL, CAP_TOP = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
plan = json.load(open(f"{PW}/plan.json"))
dur = round(float(subprocess.run(["ffprobe","-v","error","-show_entries","format=duration",
  "-of","csv=p=0",REEL],capture_output=True,text=True).stdout.strip()),2)
proj = f"{PW}/comp"; os.makedirs(f"{proj}/compositions", exist_ok=True)
shutil.copy(REEL, f"{proj}/reel-in.mp4")
def fill(t, m):
    for k, v in m.items(): t = t.replace("{{%s}}" % k, str(v))
    return t
cap = open(f"{PREMIUM}/templates/caption-overlay.html").read()
open(f"{proj}/compositions/caption-overlay.html","w").write(fill(cap, {
    "DURATION": dur, "CAP_TOP": CAP_TOP,
    "ACCENT": plan["brand"]["accent"], "FG": plan["brand"]["fg"],
    "GROUPS_JSON": json.dumps(plan["caption_groups"])}))
root = open(f"{PREMIUM}/templates/root-shell-polish.html").read()
open(f"{proj}/index.html","w").write(fill(root, {"DURATION": dur, "VIDEO_SRC": "reel-in.mp4"}))
print(f"premium comp: {len(plan['caption_groups'])} groups, {dur}s, cap_top={CAP_TOP}")
PY
  cd "$PW/comp" && npx hyperframes lint && npx hyperframes validate && \
    npx hyperframes render --output "$PW/visuals.mp4" --fps 30 --quality high
  cd - >/dev/null
else
  cp "$REEL_IN" "$PW/visuals.mp4"
fi

# --- P3: grade + audio (one pass; amix=normalize=0 — never re-loudnorm) ---
python3 - "$PW" "$PREMIUM_DIR" "$REEL_IN" <<'PY' > "$PW/mux.sh"
import json, sys
PW, PREMIUM, REEL = sys.argv[1], sys.argv[2], sys.argv[3]
plan = json.load(open(f"{PW}/plan.json"))
cues = plan.get("sfx", [])
GRADES = {
  "warm-amber":   "curves=r='0/0 0.5/0.55 1/1':b='0/0 0.5/0.46 1/0.95',eq=contrast=1.05:saturation=1.08,unsharp=5:5:0.5",
  "clean-bright": "eq=brightness=0.02:contrast=1.06:saturation=1.1,unsharp=5:5:0.5",
  "off":          "null",
}
grade = GRADES.get(plan.get("grade","clean-bright"), GRADES["clean-bright"])
inputs = " ".join(f"-i \"{PREMIUM}/assets/sfx/{c['name']}.wav\"" for c in cues)
parts, mix = [], "[1:a]"
for j, c in enumerate(cues):
    ms = int(float(c["t"])*1000)
    parts.append(f"[{j+2}:a]adelay={ms}|{ms},volume={min(float(c.get('gain',0.5)),0.6)}[s{j}]")
    mix += f"[s{j}]"
fc = (";".join(parts)+f";{mix}amix=inputs={len(cues)+1}:normalize=0:duration=first[aout]") if cues else "[1:a]anull[aout]"
print(f'''ffmpeg -y -i "{PW}/visuals.mp4" -i "{REEL}" {inputs} \\
  -filter_complex "[0:v]{grade},format=yuv420p[vout];{fc}" \\
  -map "[vout]" -map "[aout]" \\
  -c:v libx264 -preset medium -crf 19 -r 30 \\
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart "{PW}/polished.mp4"''')
PY
bash "$PW/mux.sh" && cp "$PW/polished.mp4" "$W/polished.mp4"
```

### Step 9 — First-frame cover rule (§2d — MANDATORY)

IG/TikTok use frame 1 of the MP4 as the feed poster. The hook animates in from black, so frame 1
is blank. The canonical fix: prepend a 0.4s money-shot freeze from `cover_at` (a content beat
past the hook). **This must be the last assembly step before upload.**

```bash
# 1. Extract the money-shot frame (cover_at is past the hook, from Step 5)
$FF -y -ss "$COVER_AT" -i "$W/polished.mp4" -frames:v 1 -q:v 2 "$W/cover.png"

# 2. Make a 0.4s freeze clip (1080×1920, 30fps, silent stereo) matching reel specs
# BUG FIX: anullsrc MUST be a proper lavfi input (-f lavfi -i), NOT an -af filter.
# Using -af "anullsrc=..." attaches a filter to the image's (absent) audio stream,
# producing no audio stream → the concat drops audio entirely.
$FF -y -loop 1 -t 0.4 -i "$W/cover.png" \
  -f lavfi -t 0.4 -i "anullsrc=r=48000:cl=stereo" \
  -vf "scale=1080:1920,setsar=1,fps=30,format=yuv420p" \
  -shortest \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 \
  "$W/cover-freeze.mp4"

# 3. Prepend via concat (re-encode to avoid non-monotonic DTS from -c copy across sources)
# BUG FIX: -c copy on a demuxer concat of independently-encoded clips causes DTS
# non-monotonic errors in some ffmpeg builds. Re-encode both streams instead.
printf "file '%s'\nfile '%s'\n" "$W/cover-freeze.mp4" "$W/polished.mp4" > "$W/cover_concat.txt"
$FF -y -f concat -safe 0 -i "$W/cover_concat.txt" \
  -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
  "$W/short-with-cover.mp4"
cp "$W/short-with-cover.mp4" "$OUT"

# Keep cover.png as the explicit Output thumbnail
# (the calling skill / cfw-social's attach_output picks this up as the thumbnail)
COVER_PNG="$W/cover.png"
echo "[p-reels-pip] cover.png extracted at ${COVER_AT}s"
```

### Step 10 — Verify (mandatory)

```bash
# Mechanical checks
$FF -v error -i "$OUT" -f null -    # clean decode = no output
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$OUT"
# Confirm: width=1080, height=1920, video+audio present, fps≈30, clean decode.

# Duration check: total = BED_DUR + 0.4s cover freeze (+ outro if used)
EXPECTED_DUR=$(python3 -c "print(round(float('$BED_DUR') + 0.4, 1))")
ACTUAL_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
python3 -c "
exp, act = float('$EXPECTED_DUR'), float('$ACTUAL_DUR')
assert abs(exp - act) < 0.5, f'duration mismatch: expected ~{exp:.2f}s, got {act:.2f}s'
print(f'duration OK: {act:.2f}s')
"

# VO continuity — talking head audio is present throughout (not silenced)
$FF -hide_banner -ss 1 -t $((${BED_DUR%.*}-2)) -i "$OUT" -af volumedetect -f null - 2>&1 \
  | grep -E "mean_volume|max_volume"
# mean_volume must be louder than ~-60 dB (a nearly-silent reel = audio mastering failed)

# Extract 6 frames and READ each with your vision (non-negotiable)
for pct in 05 20 40 60 80 95; do
  t=$(python3 -c "print(round(float('$ACTUAL_DUR')*0.${pct},1))")
  $FF -y -ss "$t" -i "$OUT" -frames:v 1 "$W/qa_$pct.png"
done
```

**For each frame, check:**
- [ ] **(a) Background is NOT black** — behind/around the PIP there is real footage or motion
      graphics. Black background = build failed → fix Step 6 and re-render.
- [ ] **(b) Complete face shows in the PIP** — forehead to chin, not cropped at top OR bottom,
      not stretched. Cropped face = scale-to-FIT failed → fix Step 7.
- [ ] **(c) PIP is fully on-screen with a margin** — entire PIP card inside the frame with a
      clear gap at the bottom. Flush/buried = margin was dropped → fix `overlay` in Step 7.
- [ ] **(d) Content does NOT cover the PIP** — graphics/captions in the upper zone only;
      nothing invades the bottom band. PIP obscured = pip-safe variant missing in Step 6.
- [ ] **(e) Background fills full width** — no pillarbox bars, no letterbox, no distortion.
- [ ] **(f) Captions legible, brand accent on emphasis words, NOT covering the PIP.**
- [ ] **(g) Frame 0 (cover)** shows the money-shot (from `cover_at`) — not a black/hook frame.

**If ANY check fails: fix, re-render, re-extract, look again. Never upload a failing reel.**

### Step 11 — Upload to R2 and print the URL (LAST LINE)

```bash
cfw-upload "$OUT" 2>/dev/null || bash _scripts/upload-to-recordings.sh "$OUT"
# Also upload cover.png as the thumbnail Output
cfw-upload "$COVER_PNG" 2>/dev/null || true

# Print R2 public URL as the FINAL LINE of output — the worker scrapes this.
# NEVER print an input URL (the talking-head upload, a b-roll source) as the result.
```

Clean up `$W` after the URL is confirmed.

---

## How fmt1 and hf-fmt5 map onto this one core

| Old skill | Which path in p-reels-pip | Notes |
|---|---|---|
| **p-reels-fmt1** (webcam PIP, 100% graphics) | `broll=[]` → `broll_coverage_pct=0` → every beat is `graphics` in c-broll-sync → 100% HyperFrames background | Degenerate case. fmt1's PIP crop (webcam corner from a slide-deck recording) = Step 1.5 white-band crop. The pipeline is identical; only coverage changes. |
| **p-reels-hf-fmt5** (uploaded PIP, transcript-synced bg) | `broll=[...]` + coverage knobs → c-broll-sync assigns b-roll beats where matched, graphics elsewhere | Full general case. hf-fmt5's OPUS planner + beat executor is now c-broll-sync (extracted as a standalone component). |

**Key merges vs fmt1:**
- fmt1 used Remotion (Steps 3, for the graphics). This core uses HyperFrames only — no Remotion.
- fmt1 had no `c-reel-premium` (kinetic captions + SFX + grade). This core adds it.
- fmt1 had no first-frame cover rule. This core adds it (Step 9).

**Key merges vs hf-fmt5:**
- hf-fmt5 had the OPUS planner + beat executor inline. This core delegates to `c-broll-sync`.
- hf-fmt5 had the `c-reel-premium` call at Step 8.5. Retained.
- hf-fmt5 had no first-frame cover rule. This core adds it (Step 9).

---

## Notes & gotchas

- **Degenerate case (no b-roll) = fmt1 behavior, not a failure.** `broll_coverage_pct=0` (or
  `broll=[]`) → every beat is graphics. 100% HyperFrames background. Valid and complete.
- **The talking head is the audio + duration master.** `shortest=1` on the overlay clips the
  composite to it; the background is built to cover at least its full length.
- **FIT + BLURRED-FILL (background), never bare scale or letterbox.**
  B-roll is shown whole (no cropping), a heavy-blurred copy fills the frame edges.
  `pad`/`force_original_aspect_ratio=decrease` alone letterboxes (dead bars) — wrong.
  The old scale-to-COVER (`increase+crop`) cropped non-9:16 sources like website captures badly.
- **Scale-to-FIT (PIP), never crop the face.**
  `scale=CARD_W:CARD_H:force_original_aspect_ratio=decrease` → whole face visible.
  fmt5 v1 cut the chin with a square crop — this is the explicit fix.
- **PIP margin = 110px (never flush).** fmt5 v1 put the PIP at `y=1380` flush to the bottom edge —
  it was buried/clipped on some devices. `overlay=(W-w)/2:(H-h-110)` guarantees full visibility.
- **PIP is always centered** regardless of aspect ratio. bake-off #2 fix: portrait sources (h > w)
  were incorrectly placed bottom-left (`x=$MARGIN`). All sources now use `x=(W-w)/2`.
- **pip-safe variant on all c-typing-ui calls** — content must stay in the top ~54% (above y≈1040).
  Full-frame variant would cover the PIP.
- **Bottom band reserved in motion-card templates (`--pip-band: 680px` CSS var).** Verify with
  frame spot-checks: graphics must never land under the PIP.
- **Loudnorm the bed ONCE** (Step 2). Never re-normalize downstream. The premium pass uses
  `amix=normalize=0` so the VO level is never changed.
- **Cover rule is mandatory.** `cover_at` comes from the beat plan (a content beat past the hook),
  not a guess. Frame 1 of the final MP4 must be the money-shot, not a black/hook frame.
- **Black background = build failed — never ship it.** The YAVG brightness check (Step 6) and
  the visual QA gate (Step 10a) both exist because ffprobe cannot see a black frame.
- **No `#` comments inside `filter_complex`** (ffmpeg parse error). Store long graphs in `.sh`.
- **HyperFrames font gotcha:** never use `var(--font-*)` in `font-family` — use mapped names
  (`'Oswald'`, `'JetBrains Mono'`, `'Inter'`).
- **Root composition = FULL HTML document** (doctype + html/head/body). Bare fragment → bundler
  `Unexpected token '*'`. Sub-compositions stay inside `<template>`.
- **Run `lint` AND `validate` before `render`.** Validate catches runtime errors (window Proxy,
  GSAP issues) that static lint misses.
- **c-broll-sync shortfall logging.** If fewer b-roll clips are available than the budget allows
  (and reuse is off), c-broll-sync logs the shortfall and caps at available clips. This is normal
  — the plan completes with fewer b-roll windows, rest are graphics.
