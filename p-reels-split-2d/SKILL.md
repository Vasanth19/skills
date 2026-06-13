---
name: p-reels-split-2d
description: "Turn an uploaded talking-head video into a premium 9:16 reel with a 50/50 vertical split — the TOP half (y 0→960) is rendered with Konva.js (Canvas 2D, headless node-canvas), replicating manthanpatelll's reel-overlay style: animated liquid-gradient pills, outward-only wave outlines, and transcript-beat-paired visuals (custom illustrations ~60% / emoji ~25% / logo ~15%), all constrained to the top 960px. The BOTTOM half (y 960→1920) is the speaker's face scaled to fill the zone (blurred-fill). This is the A/B counterpart to p-reels-split (which uses HyperFrames/GSAP). Trigger on: 'Konva split reel', '2D canvas split', 'pill overlay reel', 'canvas 2D top graphics'."
when-to-use: "Use instead of p-reels-split when the user wants the Canvas-2D / Konva pill-and-visual style on the top half, or to A/B compare the Konva approach against the HyperFrames version. Both produce a finished 1080×1920 H.264 reel from a real talking-head clip; only the top-half renderer differs. p-reels-split uses HyperFrames/GSAP web templates; p-reels-split-2d uses Konva.js rendered headless with node-canvas, frame-by-frame."
version: 1.0.0
kind: pipeline
visibility: catalog
produces:
  dish: Uploaded Talking-Head Split-Screen Reel (Konva/Canvas-2D top)
  format: 9:16 vertical video
  duration: 20-60s
inputs: [talking_head_video, broll, known_transcript, outro]
dependsOn: [c-ffmpeg, c-audio, c-reel-premium, c-broll-sync]
metadata:
  hermes:
    vendored: [c-reel-premium, c-broll-sync, c-ffmpeg, c-audio]
    notes: "Top-half renderer is self-contained — renderer/ dir ships its own package.json (konva + canvas). Install with: cd renderer && npm install"
---

# p-reels-split-2d — 50/50 Split-Screen Reel, Konva/Canvas-2D Top Half

Produces one 9:16 (1080×1920) H.264 MP4. Layout is IDENTICAL to p-reels-split:

```
┌──────────────────────────────┐  1080×1920
│  TOP ZONE    (y 0 → 960)     │  ← Konva.js Canvas-2D overlay:
│                              │     animated liquid-gradient PILLS +
│   [ pills + visuals ]        │     paired contextual VISUALS (illus/emoji/logo)
│                              │     transcript-beat-driven, 8-14 beats per reel
├──────────────────────────────┤  ← hard split at y=960
│  BOTTOM ZONE (y 960 → 1920)  │  ← talking-head face, BLURRED-FILL into 1080×960.
│                              │     Speaker's voice is the single audio bed.
│   [ talking-head face ]      │
│                              │
└──────────────────────────────┘
```

**Engine difference from p-reels-split:**

| | p-reels-split | **p-reels-split-2d** |
|---|---|---|
| Top-half renderer | HyperFrames (Chromium + GSAP, HTML/CSS) | **Konva.js + node-canvas (Canvas 2D, headless Node.js)** |
| Overlay style | motion card / typing-ui / b-roll | **manthan-style liquid pills + paired visuals** |
| Install | npx hyperframes | cd renderer && npm install |
| Alpha output | No (opaque mp4 per beat) | No (opaque 1080×960 mp4 via ffmpeg pipe) |

Everything else — bottom half, audio, b-roll planning via c-broll-sync, premium pass via c-reel-premium, vstack composite, first-frame cover rule — is IDENTICAL to p-reels-split.

---

## Konva Overlay System (Top Half Only)

### Zones — centroid coordinates on a 1080×960 canvas

```
top-left:   cx=360, cy=360   (top-left quadrant of the 960px band)
top-center: cx=540, cy=540   (center — hooks and CTAs)
top-right:  cx=720, cy=360   (top-right quadrant)
```

**Hard constraint: cy ≤ 900.** No element's centroid may exceed y=900. The bottom 60px is a safety margin before the y=960 split. The renderer enforces this at beat load time.

### Beat types

| Type | Description | Konva nodes used |
|---|---|---|
| `hook` | First 3-5s. 2-4 words, big (70-84px), top-center. Fade in/out. | Pill (Konva.Group: Rect+Text+wave outline) |
| `keyword` | 1-2 word pill. 2-5s. Unique 6-stop liquid palette. | Pill |
| `emoji` | Apple/system emoji rendered via node-canvas `fillText`. 2-3s. | Konva.Text |
| `logo` | Brand PNG (≥512px icon-only) + label pill. | Konva.Image + label Rect/Text |
| `primitive` | Custom Canvas 2D illustration drawn via `draw(ctx, t, props)`. | Konva.Canvas (custom shape) |
| `cta` | Final 4-6s, two words, top-center cyOffset=280. Pulse idle. | Pill |

### Pill anatomy (per manthan's spec)

```
┌─────────────────────────────────────┐  ← 3-layer drop shadow underneath
│  [animated linear gradient body]    │  ← palette[0-3], gradient rotates slowly
│    TEXT (plain fill, no stroke)     │  ← white if dark bg, near-black if light
└─────────────────────────────────────┘
  ↑ outward-only wave stroke (strokeLiquidOutline)
    palette[0-5] family, bumps OUTWARD ONLY
```

**6-stop palette per beat (HARD — each beat must have its own `palette` array):**
- `[deepShadow, bodyDeep, bodyMid, bodyLight, accentLight, accentBright]`
- Body gradient uses stops 0-3. Wave outline uses all 6.
- `props.fill` = `palette[1]` (static plate under gradient).
- Text contrasts bg: light palette → `#1F2937`; dark palette → `#FFFFFF`.
- Never repeat a base color across two pills in the same reel.

### Visual pairing layout rule

```
Pill in top-center → visual in top-left OR top-right
Pill in top-left   → visual in top-right
Pill in top-right  → visual in top-left
```

Visual accompanies its pill for ~80%+ of the pill window, with a slight stagger (visual `start` += 0.3s).

### Target visual mix per reel

| ~60% | ~25% | ~15% |
|---|---|---|
| Custom Canvas 2D illustration (`type: "primitive"`) | Apple emoji (`type: "emoji"`) | Brand logo or mascot (`type: "logo"`) |

### Animation envelope

**In-animations:** `pop | slide-up | slide-down | slide-left | slide-right | drop | fade`
**Out-animations:** `pop | snap-up | snap-down | slide-left | slide-right | fade`
**Idle:** `bob | breathe | pulse | false`

Never reuse the same `inAnim` twice in a row across neighbors.

---

## Renderer (`renderer/`)

Self-contained Node.js module. Uses **Konva** as the scene graph and **node-canvas** (`canvas` npm package) as the headless Canvas backend. Konva on Node automatically delegates to node-canvas when the `canvas` package is present.

### Install

```bash
cd /path/to/p-reels-split-2d/renderer
npm install
# Note: canvas requires node-gyp + native build (libcairo, libpango).
# On macOS: brew install pkg-config cairo pango libpng jpeg giflib librsvg
# On Ubuntu: apt-get install build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libpng-dev libgif-dev
```

### Usage

```bash
node renderer/render-overlay.mjs \
  --beats beats.json \
  --duration 42.5 \
  --out /tmp/top-overlay.mp4 \
  [--fps 30] \
  [--width 1080] [--height 960] \
  [--font /path/to/font.ttf] \
  [--smoke 1.5,8.0,22.0]
  # --smoke: comma-separated t values → renders those frames as PNGs to /tmp/split2d-smoke/ and exits
```

The renderer outputs a 1080×960 MP4 with no audio, encoded via an ffmpeg pipe (raw BGRA frames → ffmpeg stdin → H.264). This is the `top-all.mp4` used by the vstack composite step.

---

## Inputs

| Param | Required | Default | Notes |
|---|---|---|---|
| `talking_head_video` | YES | — | Real face + real voice. The voice is the duration master. |
| `broll[]` | No | `[]` | Placed in the TOP half as b-roll beat windows by c-broll-sync. |
| `known_transcript` | No | — | Word-level `[{text,start,end}]`. Skips Step 3 transcription. |
| `outro` | No | off | Optional outro mp4 appended after the main reel. |

### c-broll-sync coverage params (passthrough)

| Param | Default |
|---|---|
| `broll_coverage_pct` | 30 |
| `broll_clip_seconds` | 4 |
| `broll_min_seconds` | 2 |
| `broll_max_seconds` | 6 |
| `broll_order` | transcript-match |
| `broll_reuse` | false |

---

## Beat Schema

The agent plans the beat list (JSON array) after reading the transcript. Reference: `renderer/beat-schema.md`.

Minimal example:

```json
[
  {
    "id": "hook",
    "type": "hook",
    "start": 0.1,
    "end": 4.2,
    "zone": "top-center",
    "inAnim": "fade",
    "outAnim": "fade",
    "inDur": 0.5,
    "outDur": 0.4,
    "idle": false,
    "props": {
      "text": "2 hooks max",
      "fontSize": 76,
      "fill": "#A04A2C",
      "textColor": "#FFFFFF",
      "palette": ["#5B1F0E","#A04A2C","#D97757","#F2A684","#FCDDC9","#FFE8B8"]
    }
  },
  {
    "id": "kw-1",
    "type": "keyword",
    "start": 5.0,
    "end": 9.5,
    "zone": "top-left",
    "inAnim": "pop",
    "outAnim": "snap-up",
    "idle": "breathe",
    "props": {
      "text": "one idea",
      "fontSize": 56,
      "fill": "#5B21B6",
      "textColor": "#FFFFFF",
      "palette": ["#2E1065","#5B21B6","#7C3AED","#A78BFA","#DDD6FE","#F5F3FF"]
    }
  },
  {
    "id": "viz-1",
    "type": "primitive",
    "start": 5.3,
    "end": 9.5,
    "zone": "top-right",
    "inAnim": "fade",
    "outAnim": "fade",
    "idle": false,
    "props": {
      "draw": "drawAgentGrid"
    }
  }
]
```

For `type: "primitive"`, `props.draw` is a string key into the per-reel illustrations module (`renderer/illustrations.mjs`). The renderer calls `illustrations[props.draw](ctx, t, props)` at every frame.

---

## Steps

Set up variables:

```bash
TH="<path to downloaded talking-head mp4>"
W="<production>/interim/split2d" ; mkdir -p "$W" "$W/src" "$W/top_beats"
OUT="<production>/final/split2d-reel-with-cover.mp4" ; mkdir -p "$(dirname "$OUT")"
FF="ffmpeg"

SKILL_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" /Users/vasanth/Code/skills -maxdepth 4 -type d -name p-reels-split-2d 2>/dev/null | head -1)
RENDERER_DIR="$SKILL_DIR/renderer"
BROLL_SYNC_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" /Users/vasanth/Code/skills -maxdepth 4 -type d -name c-broll-sync 2>/dev/null | head -1)
PREMIUM_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" /Users/vasanth/Code/skills -maxdepth 4 -type d -name c-reel-premium 2>/dev/null | head -1)

BROLL_COVERAGE_PCT="${broll_coverage_pct:-30}"
BROLL_CLIP_SECS="${broll_clip_seconds:-4}"
BROLL_MIN_SECS="${broll_min_seconds:-2}"
BROLL_MAX_SECS="${broll_max_seconds:-6}"
BROLL_ORDER="${broll_order:-transcript-match}"
BROLL_REUSE="${broll_reuse:-false}"

SPLIT_H=960
CANVAS_W=1080
CANVAS_H=1920
```

### Step 1 — Localize + probe the talking-head video (MANDATORY)

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,duration,codec_name \
  -of default=noprint_wrappers=1 "$TH"

BED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TH")

$FF -hide_banner -i "$TH" -t 60 -af volumedetect -f null - 2>&1 \
  | grep -E "mean_volume|max_volume"
# ~-90 dB mean = STOP — no narration; ask for a different source.
```

### Step 1.5 — Detect + crop white side-bands

```bash
TH_W=$(ffprobe -v error -select_streams v -show_entries stream=width  -of csv=p=0 "$TH")
TH_H=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$TH")

col_luma() {
  v=$($FF -hide_banner -loglevel error -ss $(echo "$BED_DUR/2"|bc) -i "$TH" -vframes 1 \
        -vf "crop=2:$TH_H:$1:0,scale=1:1,format=gray" -f rawvideo - 2>/dev/null | xxd -p)
  echo $((16#${v:-00}))
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

read TH_CW TH_CH < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=p=0:s=' ' "$TH_CLEAN")
```

### Step 2 — Build the loudnormed voice bed

```bash
$FF -y -i "$TH_CLEAN" \
  -vn -af "loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000" \
  -c:a aac -ar 48000 -ac 2 -b:a 192k \
  "$W/voice-bed.aac"

BED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TH_CLEAN")
echo "bed duration: $BED_DUR seconds"
```

### Step 3 — Transcribe with word timestamps (skip when known_transcript provided)

```bash
if [ -n "$KNOWN_TRANSCRIPT_JSON" ]; then
  echo "$KNOWN_TRANSCRIPT_JSON" | python3 -c "
import json,sys
words=json.load(sys.stdin)
words=[{**w,'text':w.get('text') or w.get('word','')} for w in words]
print(json.dumps(words))
" > "$W/transcript.json"
  echo "[p-reels-split-2d] Using provided transcript — skipping transcription"
else
  cfw-transcribe --input "$W/voice-bed.aac" --out "$W/transcript.srt" --format srt \
    && python3 - "$W/transcript.srt" "$W/transcript.json" <<'PY'
import re, json, sys
lines = open(sys.argv[1]).read().strip().split('\n\n')
words = []
for block in lines:
    parts = block.strip().split('\n')
    if len(parts) < 3: continue
    ts = parts[1]; text = ' '.join(parts[2:])
    def t2s(s): h,m,rest=s.replace(',','.').split(':'); return int(h)*3600+int(m)*60+float(rest)
    start_s, end_s = ts.split(' --> ')
    for word in text.split():
        words.append({"text": word, "start": t2s(start_s.strip()), "end": t2s(end_s.strip())})
json.dump(words, open(sys.argv[2], 'w'))
PY
fi
```

### Step 4 — Plan the beat list (AGENT TASK — read transcript → produce beats.json)

This is the creative step. The agent:

1. Reads `$W/transcript.json`
2. Plans **8–14 beats** for a 30–60s reel, mapping transcript moments to beat types
3. Writes per-reel illustrations if any `primitive` beats are planned (add to `renderer/illustrations.mjs` as named exports)
4. Produces `$W/beats.json` — array of beat objects per the schema in `renderer/beat-schema.md`

**Beat planning rules:**
- First beat = `hook`, `zone: "top-center"`, `start: 0.05–0.15s`
- Last beat = `cta`, `zone: "top-center"`, `cyOffset: 280`, `inAnim: "pop"`, `idle: "pulse"`
- Never repeat a base palette color across two pills in the same reel
- Text 4 words max per pill; CTA = exactly two words (verb + noun)
- One element per zone at a time (no simultaneous same-zone overlap)
- Visual mix: ~60% primitive, ~25% emoji, ~15% logo
- cy constraint: all zone centroids ≤ 900

```bash
# Validate the planned beat list
python3 - "$W/beats.json" "$BED_DUR" <<'PY'
import json, sys
beats = json.load(open(sys.argv[1]))
dur = float(sys.argv[2])
assert len(beats) >= 4, f"too few beats: {len(beats)}"
assert len(beats) <= 20, f"too many beats: {len(beats)}"
for b in beats:
    assert b.get("zone") in ("top-left","top-center","top-right") or ("cx" in b and "cy" in b), \
        f"beat {b['id']}: invalid zone"
    if "zone" in b:
        cy_map = {"top-left": 360, "top-center": 540, "top-right": 360}
        cy = cy_map[b["zone"]] + b.get("cyOffset", 0)
        assert cy <= 900, f"beat {b['id']}: cy={cy} > 900 (top-half constraint violated)"
    if b.get("type") in ("keyword","hook","cta"):
        palette = b.get("props",{}).get("palette")
        assert palette and len(palette) == 6, f"beat {b['id']}: missing 6-stop palette"
print(f"beats.json OK: {len(beats)} beats, duration budget {dur:.1f}s")
PY
```

### Step 5 — Plan the b-roll cue index (for b-roll beats in the top zone)

```bash
BROLL_CUES_JSON="[]"

if [ ${#BROLL_CLIPS[@]} -gt 0 ]; then
  TMP_CUES="$W/broll_cues_build"
  mkdir -p "$TMP_CUES"

  build_broll_cue() {
    local clip="$1"
    local fname=$(basename "$clip")
    local dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$clip" 2>/dev/null || echo 0)
    local cues_out="$TMP_CUES/${fname%.mp4}.json"
    local has_audio=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$clip" 2>/dev/null | head -1)
    if [ -n "$has_audio" ]; then
      local srt_out="$TMP_CUES/${fname%.mp4}.srt"
      cfw-transcribe --input "$clip" --out "$srt_out" --format srt 2>/dev/null && \
      python3 - "$srt_out" "$cues_out" <<'PY'
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
    echo "{\"clip\":\"$fname\",\"duration\":$dur,\"cues\":$(cat "$cues_out" 2>/dev/null || echo '[]')}"
  }

  ENTRY_FILES=()
  for clip in "${BROLL_CLIPS[@]}"; do
    out_f="$TMP_CUES/$(basename "$clip" .mp4)_entry.json"
    build_broll_cue "$clip" > "$out_f" &
    ENTRY_FILES+=("$out_f")
    while [ "$(jobs -r | wc -l)" -ge "$(( $(nproc 2>/dev/null || echo 4) - 1 ))" ]; do wait -n; done
  done
  wait

  BROLL_CUES_JSON=$(python3 -c "
import json, sys
entries = []
for f in sys.argv[1:]:
    try: entries.append(json.loads(open(f).read()))
    except: pass
print(json.dumps(entries))
" "${ENTRY_FILES[@]}")
fi

echo "$BROLL_CUES_JSON" > "$W/broll_cues.json"
```

### Step 6 — Render the Konva top-half overlay (1080×960 MP4)

The renderer takes `beats.json`, renders every frame via Konva+node-canvas at 30fps, and pipes raw BGRA to ffmpeg.

```bash
# Verify renderer deps are installed
[ -d "$RENDERER_DIR/node_modules/konva" ] || (cd "$RENDERER_DIR" && npm install)

# Smoke check: render 3 frames as PNG before full render
node "$RENDERER_DIR/render-overlay.mjs" \
  --beats    "$W/beats.json" \
  --duration "$BED_DUR" \
  --fps      30 \
  --smoke    "$(python3 -c "d=float('$BED_DUR'); print(f'{d*0.08:.1f},{d*0.35:.1f},{d*0.75:.1f}')")" \
  --out      "$W/top-all.mp4"
# Smoke mode exits after writing PNGs to /tmp/split2d-smoke/. Review them.

# Check smoke frames exist and look sane
ls -la /tmp/split2d-smoke/
echo "[p-reels-split-2d] Review smoke frames before full render. Ctrl-C to abort."

# Full render (remove --smoke flag):
node "$RENDERER_DIR/render-overlay.mjs" \
  --beats    "$W/beats.json" \
  --duration "$BED_DUR" \
  --fps      30 \
  --out      "$W/top-all.mp4"

# Also handle b-roll beats: for beats with kind=="broll" the renderer switches to
# blurred-fill b-roll video for that window (path from beats.json broll.clip).
# The renderer internally calls ffmpeg for b-roll segments and stitches them.

# Verify top track is 1080x960
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=p=0 "$W/top-all.mp4"
# Must print: 1080,960

# Brightness check (must not be black)
for t in 1 $(python3 -c "print(round(float('$BED_DUR')/2,1))") $(python3 -c "print(round(float('$BED_DUR')-1,1))"); do
  $FF -ss "$t" -i "$W/top-all.mp4" -frames:v 1 \
    -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG" -f null - 2>&1 | grep -o 'YAVG=[0-9.]*'
done
# YAVG near 0 on all samples → renderer output is black → fix renderer and rerun.
```

### Step 7 — Build the bottom-half face track (1080×960, BLURRED-FILL)

```bash
FC_BOTTOM="[0:v]scale=1080:960:force_original_aspect_ratio=increase,crop=1080:960,boxblur=40:2,setsar=1[bg];[0:v]scale=1080:960:force_original_aspect_ratio=decrease,setsar=1[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p,fps=30[bv]"

$FF -y -i "$TH_CLEAN" -i "$W/voice-bed.aac" \
  -filter_complex "$FC_BOTTOM" \
  -map "[bv]" -map 1:a \
  -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -shortest "$W/bottom-all.mp4"

BOTTOM_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/bottom-all.mp4")
echo "[p-reels-split-2d] bottom track: ${BOTTOM_DUR}s"
```

### Step 7.5 — Trim top-all.mp4 to match bottom-all.mp4 duration

```bash
BOTTOM_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/bottom-all.mp4")
TOP_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/top-all.mp4")

python3 -c "
top, bot = float('$TOP_DUR'), float('$BOTTOM_DUR')
diff = abs(top - bot)
assert diff < 1.0, f'top/bottom duration mismatch too large: top={top:.2f}s bot={bot:.2f}s'
print(f'duration delta: {diff:.3f}s')
"

$FF -y -i "$W/top-all.mp4" -t "$BOTTOM_DUR" \
  -c:v libx264 -preset medium -crf 20 -an -pix_fmt yuv420p "$W/top-trimmed.mp4"
```

### Step 8 — vstack: composite TOP zone over BOTTOM zone

```bash
$FF -y -i "$W/top-trimmed.mp4" -i "$W/bottom-all.mp4" \
  -filter_complex "[0:v][1:v]vstack=inputs=2[v]" \
  -map "[v]" -map 1:a \
  -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
  "$W/composed.mp4"

ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=p=0 "$W/composed.mp4"
# Must print: 1080,1920
```

### Step 9 — CTA end-card (tail TAKEOVER)

```bash
CTA_DURATION="${CTA_DURATION:-3.0}"
CTA_TEXT="${CTA_TEXT:-FOLLOW FOR MORE}"
CTA_HANDLE="${CTA_HANDLE:-@handle}"

# Render CTA card as a simple HyperFrames template OR a plain ffmpeg lavfi colored card
# (no HyperFrames dependency needed for a simple text-only CTA):
$FF -y -f lavfi -t "$CTA_DURATION" \
  -i "color=c=0x0F172A:s=1080x1920:r=30" \
  -vf "drawtext=text='$CTA_TEXT':fontsize=120:fontcolor=white:x=(w-tw)/2:y=(h-th)/2-60:font='sans-bold',\
       drawtext=text='$CTA_HANDLE':fontsize=56:fontcolor=#F97316:x=(w-tw)/2:y=(h/2)+80:font='sans'" \
  -c:v libx264 -pix_fmt yuv420p "$W/cta-card.mp4"

COMPOSED_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/composed.mp4")
CTA_START=$(python3 -c "print(round(${COMPOSED_DUR} - ${CTA_DURATION}, 3))")

$FF -y -i "$W/composed.mp4" -itsoffset "${CTA_START}" -i "$W/cta-card.mp4" \
  -filter_complex "[0:v][1:v]overlay=enable='between(t,${CTA_START},${COMPOSED_DUR})':eof_action=pass[v]" \
  -map "[v]" -map 0:a \
  -c:v libx264 -pix_fmt yuv420p -c:a copy -movflags +faststart "$W/with-cta.mp4"

FINAL_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$W/with-cta.mp4")
python3 -c "
dur, final = float('$COMPOSED_DUR'), float('$FINAL_DUR')
assert abs(dur - final) < 0.1, f'CTA extended the reel: {dur:.2f}s → {final:.2f}s'
print(f'CTA OK: {final:.2f}s')
"

if [ -n "${OUTRO_PATH:-}" ] && [ -f "$OUTRO_PATH" ]; then
  $FF -y -i "$OUTRO_PATH" \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p" \
    -c:v libx264 -preset medium -crf 20 -an "$W/outro-norm.mp4"
  printf "file '%s'\nfile '%s'\n" "$W/with-cta.mp4" "$W/outro-norm.mp4" > "$W/outro_concat.txt"
  $FF -y -f concat -safe 0 -i "$W/outro_concat.txt" -c copy "$W/pre-premium.mp4"
else
  cp "$W/with-cta.mp4" "$W/pre-premium.mp4"
fi
```

### Step 9.5 — c-reel-premium pass (captions + SFX + grade)

Identical to p-reels-split. `CAP_TOP=860` keeps captions in the top zone. Captions must NOT appear in the bottom half (y 960+).

```bash
PW="$W/premium"; mkdir -p "$PW"

REEL_IN="$W/pre-premium.mp4"
REEL_OUT="$W/polished.mp4"
WORDS_JSON="$W/transcript.json"
CAP_TOP=860

DUR_CHECK=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$REEL_IN")

PLAN_PROMPT="You are planning the PREMIUM POLISH layer for an assembled 9:16 reel (captions + SFX + grade).
Output STRICT JSON ONLY (one object, no prose).
Word transcript: $(cat "$WORDS_JSON")
Total duration: $DUR_CHECK seconds.
Brand: default accent #F97316, fg #F1F5F9.
Schema: { \"grade\": \"warm-amber|clean-bright\", \"brand\": {\"accent\":\"#hex6\",\"fg\":\"#hex6\"}, \"caption_groups\": [ {\"start\":s,\"end\":s,\"style\":0|1|2, \"words\":[{\"w\":\"TEXT\",\"s\":start,\"e\":end,\"em\":false}] } ], \"sfx\": [ {\"t\":s,\"name\":\"whoosh-deep|whoosh-air|impact-sub|impact-punch|riser|click|pop|swipe\",\"gain\":0.0-0.6} ] }
RULES: 1. caption_groups cover the FULL duration, 2-4 words each, non-overlapping. 2. LATIN SCRIPT ONLY. 3. At most ONE word per group gets em:true. 4. style cycles 0/1/2. 5. sfx: 4-10 cues, gain <=0.6, none in first 1s. 6. CAP_TOP=$CAP_TOP — captions stay above y=$CAP_TOP (top zone only)."

PREMIUM_PLAN=$(timeout 240 claude --print "$PLAN_PROMPT" --dangerously-skip-permissions 2>/dev/null \
  | python3 -c "import sys,re; m=re.search(r'\{.*\}', sys.stdin.read(), re.S); print(m.group(0) if m else '')")

echo "$PREMIUM_PLAN" > "$PW/plan.json"

python3 - "$PW/plan.json" "$DUR_CHECK" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); dur=float(sys.argv[2])
assert p["caption_groups"], "no caption groups"
assert abs(p["caption_groups"][-1]["end"]-dur) < 3.0, "captions do not cover the reel"
print(f"premium plan OK: {len(p['caption_groups'])} groups, {len(p.get('sfx',[]))} sfx")
PY

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

### Step 10 — First-frame cover rule (MANDATORY)

```bash
COVER_AT=$(python3 -c "print(round(float('$BED_DUR') * 0.30, 2))")

$FF -y -ss "$COVER_AT" -i "$W/polished.mp4" -frames:v 1 -q:v 2 "$W/cover.png"

$FF -y -loop 1 -t 0.4 -i "$W/cover.png" \
  -f lavfi -t 0.4 -i "anullsrc=r=48000:cl=stereo" \
  -vf "scale=1080:1920,setsar=1,fps=30,format=yuv420p" \
  -shortest \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 \
  "$W/cover-freeze.mp4"

printf "file '%s'\nfile '%s'\n" "$W/cover-freeze.mp4" "$W/polished.mp4" > "$W/cover_concat.txt"
$FF -y -f concat -safe 0 -i "$W/cover_concat.txt" \
  -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart \
  "$W/split2d-reel-with-cover.mp4"
cp "$W/split2d-reel-with-cover.mp4" "$OUT"

COVER_PNG="$W/cover.png"
echo "[p-reels-split-2d] cover.png extracted at ${COVER_AT}s"
```

### Step 11 — Verify (mandatory)

```bash
$FF -v error -i "$OUT" -f null -

ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$OUT"

ACTUAL_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
python3 -c "
exp = float('$BED_DUR') + 0.4
act = float('$ACTUAL_DUR')
assert abs(exp - act) < 0.5, f'duration mismatch: expected ~{exp:.2f}s, got {act:.2f}s'
print(f'duration OK: {act:.2f}s')
"

for pct in 05 20 40 60 80 95; do
  t=$(python3 -c "print(round(float('$ACTUAL_DUR')*0.${pct},1))")
  $FF -y -ss "$t" -i "$OUT" -frames:v 1 "$W/qa_$pct.png"
done
```

**For each frame, check:**
- [ ] **(a) Top half (y 0–960)** has pill/visual overlay — NOT black.
- [ ] **(b) Bottom half (y 960–1920)** shows the complete face — not cropped.
- [ ] **(c) Hard split at y=960** — no overlap or bleed between zones.
- [ ] **(d) Face fills the bottom half** — full 960px, not a small inset.
- [ ] **(e) No pillarbox bars** — BLURRED-FILL covers width gaps.
- [ ] **(f) Captions in the top zone only** — none in the bottom half.
- [ ] **(g) Frame 0 (cover)** is the money-shot, not black.

### Step 12 — Upload to R2

```bash
cfw-upload "$OUT" 2>/dev/null || bash _scripts/upload-to-recordings.sh "$OUT"
cfw-upload "$COVER_PNG" 2>/dev/null || true
```

---

## Notes & Gotchas

- **50/50 is fixed.** Split at y=960. Never move it.
- **vstack, not overlay.** Hard pixel boundary. Both inputs must be exactly 1080×960.
- **Renderer font.** node-canvas uses the system font stack; do NOT use `-apple-system` in font strings — it silently falls back to a fixed-size bitmap font. Pass `--font /path/to/ProximaNova.ttf` (or any TTF/OTF you have) to `render-overlay.mjs`; the renderer registers it as `'Proxima Nova'` and uses that family for all pill text. If no font is passed, the renderer falls back to `'DejaVu Sans'` (bundled with most Linux systems) and warns.
- **node-canvas native build.** `canvas` npm package requires libcairo + libpango at compile time. On a clean VPS: `apt-get install libcairo2-dev libpango1.0-dev pkg-config libjpeg-dev libpng-dev`. On macOS: `brew install pkg-config cairo pango`.
- **Konva on Node.** Konva detects the `canvas` package and uses it as the backend automatically — no extra config needed.
- **One element per zone at a time.** The renderer throws `ZoneConflict` if two beats share the same zone with overlapping time windows.
- **Wave bumps outward only.** `strokeLiquidOutline` in the renderer uses a path that expands the pill outline outward. It never eats the interior. The math: normal offset with positive expansion only.
- **CAP_TOP=860.** Captions from c-reel-premium stay in the top zone.
- **No loudnorm after Step 2.** The premium pass uses `amix=normalize=0`.
- **B-roll in top zone.** When c-broll-sync plans b-roll beats, the renderer switches to ffmpeg blurred-fill for those time windows (same 3-chain as p-reels-split). The beat schema uses `"kind": "broll"` with a `broll` sub-object carrying `clip`, `in`, `out` times.
