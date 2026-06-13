---
name: c-hook
description: Engine-agnostic hook-segment producer. Downloads a 4-7s creator clip (windowed yt-dlp), normalises to 1080×1920/30fps/48k via scale-to-COVER, and returns a ready-to-prepend hook-clip.mp4 + metadata (duration, optional word transcript). The creator's audio is NEVER speed-adjusted or pitch-shifted — that natural voice is the entire scroll-stop value. Any reel core can optionally call this component and prepend its output before its own content.
kind: component
visibility: internal
version: 1.0.0
dependsOn: [c-ffmpeg]
requires: ffmpeg, yt-dlp, python3
---

# c-hook — Hook-Segment Producer

Extracts a scroll-stopping hook segment from a creator's publicly available video and normalises
it to the reel's target spec. The output is a single `hook-clip.mp4` that any reel core can
prepend in front of its own render — the actual brand continuation is the calling core's concern,
not this component's.

**Extracted from `p-hook-reel` so every format can optionally hook-jack without rebuilding the
download + normalise logic themselves.**

---

## When to use

Call `c-hook` when a reel recipe needs to open with 4–7s of a famous creator's footage as its
scroll-stopping hook. Do NOT call it if the recipe has its own branded opener — this component is
purely for the "hook-jack" pattern (creator hook → brand continuation).

---

## Inputs

| Var | Required | Default | Notes |
|---|---|---|---|
| `HOOK_SOURCE_URL` | Yes | — | YouTube (or other yt-dlp-supported) URL for the creator video. |
| `HOOK_START` | Yes | — | Start time of the hook span in the source (e.g. `0:04`). |
| `HOOK_END` | Yes | — | End time of the hook span in the source (e.g. `0:10`). Span should be 4–7 s. |
| `HOOK_OUT` | Yes | — | Output directory (e.g. `$W/interim/hook`). Component writes `hook-clip.mp4` here. |
| `TARGET_W` | No | `1080` | Output width (px). |
| `TARGET_H` | No | `1920` | Output height (px). |
| `TARGET_FPS` | No | `30` | Output frame rate. |
| `TARGET_AR` | No | `48000` | Output audio sample rate (Hz). |
| `TRANSCRIBE` | No | `false` | `true` → run Whisper on the clip and write `hook-words.json` alongside `hook-clip.mp4`. |

---

## Output contract

After a successful run `$HOOK_OUT/` contains:

```
hook-clip.mp4        # normalised hook segment, ready-to-prepend
hook-meta.json       # { "path": "…/hook-clip.mp4", "duration": 5.3, "words": […] | null }
hook-words.json      # present only when TRANSCRIBE=true — word-level [{text,start,end}]
```

`hook-meta.json` schema:

```json
{
  "path": "/absolute/path/to/hook-clip.mp4",
  "duration": 5.3,
  "words": [
    { "text": "This", "start": 0.00, "end": 0.12 },
    { "text": "changes", "start": 0.13, "end": 0.45 }
  ]
}
```

`words` is `null` when `TRANSCRIBE=false`.

---

## Hard rules

1. **NEVER speed-adjust or pitch-shift the hook audio.** The creator's natural cadence and voice
   tone are the scroll-stop. `atempo`, `rubberband`, `asetrate`, or any equivalent filter is
   prohibited on the hook audio track. Violation silently destroys the product value.

2. **Duration cap: 4–7 seconds.** If `hook_end - hook_start` exceeds 7 s, the script emits a
   warning and trims to the first 7 s. Under 4 s is also a warning (short hook risks scroll-past).

3. **Scale-to-COVER only.** The hook frame fills the full 1080×1920 canvas. No pillar-box, no
   letter-box. Use `scale=W:H:force_original_aspect_ratio=increase,crop=W:H`.

4. **Windowed download only.** Use yt-dlp `--download-sections` to pull only the hook span
   (reduces bandwidth and avoids downloading a full creator video).

5. **No brand elements added here.** c-hook does not add logos, captions, or brand overlays — it
   returns raw normalised footage. The calling core adds brand treatment after prepending.

6. **The hook frame can serve as the money-shot cover.** When the calling recipe needs a cover
   thumbnail, it may use the first frame of `hook-clip.mp4` — the hook's visual is usually the
   strongest scroll-stopping image.

---

## Step H1 — Windowed download

```bash
mkdir -p "$HOOK_OUT"

# Derive duration from the time range (supports M:SS and SS.s formats)
HOOK_DURATION=$(python3 - "$HOOK_START" "$HOOK_END" <<'PY'
import sys, re
def to_sec(t):
    t = t.strip()
    if re.match(r'^\d+(\.\d+)?$', t): return float(t)
    parts = t.split(':')
    return sum(float(p) * 60**(len(parts)-1-i) for i, p in enumerate(parts))
s, e = to_sec(sys.argv[1]), to_sec(sys.argv[2])
assert 0 < e - s <= 10, f"span {e-s:.1f}s out of range — expect 1–10s"
print(round(e - s, 3))
PY
)

# Warn on duration outside the recommended 4-7s window
python3 -c "
d=$HOOK_DURATION
if d < 4: print(f'[c-hook] WARNING: hook span {d}s is under 4s — may not scroll-stop')
if d > 7: print(f'[c-hook] WARNING: hook span {d}s exceeds 7s — trimming to 7s')
d = min(d, 7)
print(d)" > /tmp/c_hook_dur.txt
HOOK_DURATION=$(cat /tmp/c_hook_dur.txt | tail -1)

yt-dlp \
  --download-sections "*${HOOK_START}-${HOOK_END}" \
  --force-keyframes-at-cuts \
  -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
  --merge-output-format mp4 \
  -o "$HOOK_OUT/hook-raw.%(ext)s" \
  "$HOOK_SOURCE_URL"

# Confirm download succeeded
[ -f "$HOOK_OUT/hook-raw.mp4" ] || { echo "[c-hook] ERROR: yt-dlp download failed"; exit 1; }
```

## Step H2 — Normalise to target spec (scale-to-COVER, NEVER speed-adjust audio)

```bash
W=${TARGET_W:-1080}
H=${TARGET_H:-1920}
FPS=${TARGET_FPS:-30}
AR=${TARGET_AR:-48000}
HOOK_DURATION_CLAMPED=$(python3 -c "print(min($HOOK_DURATION, 7))")

ffmpeg -y \
  -i "$HOOK_OUT/hook-raw.mp4" \
  -t "$HOOK_DURATION_CLAMPED" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},fps=${FPS},format=yuv420p" \
  -af "aresample=${AR}" \
  -c:v libx264 -preset fast -crf 18 \
  -c:a aac -b:a 192k -ar ${AR} -ac 2 \
  -movflags +faststart \
  "$HOOK_OUT/hook-clip.mp4"

# ⛔ PROHIBITED — never add any of these filters to the hook audio:
#   atempo, rubberband, asetrate, aresample with ratio change, pitch=*
# The creator's natural voice cadence IS the scroll-stop.

# Verify output
ffmpeg -v error -i "$HOOK_OUT/hook-clip.mp4" -f null - \
  || { echo "[c-hook] ERROR: output failed decode check"; exit 1; }
```

## Step H3 — Extract transcript (optional, TRANSCRIBE=true only)

```bash
if [ "${TRANSCRIBE:-false}" = "true" ]; then
  # Whisper — use 'small' model; do NOT use '.en' suffix (multilingual hooks are common)
  npx hyperframes transcribe "$HOOK_OUT/hook-clip.mp4" --model small \
    --output-json "$HOOK_OUT/hook-words.json" 2>/dev/null \
  || whisper "$HOOK_OUT/hook-clip.mp4" --model small --output_format json \
       --output_dir "$HOOK_OUT" 2>/dev/null
fi
```

## Step H4 — Write metadata + QA

```bash
python3 "$SKILL_DIR/scripts/write-meta.py" \
  --clip  "$HOOK_OUT/hook-clip.mp4" \
  --words "$HOOK_OUT/hook-words.json" \
  --out   "$HOOK_OUT/hook-meta.json"
```

QA checks (mandatory before returning to caller):

```bash
# 1. Duration within 4-7s window
ACTUAL_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$HOOK_OUT/hook-clip.mp4")
python3 -c "
d=float('$ACTUAL_DUR')
assert 3.5 <= d <= 7.5, f'hook duration {d:.2f}s outside 3.5–7.5s window'
print(f'[c-hook] QA pass: {d:.2f}s hook-clip.mp4')
"

# 2. Resolution check
ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
  -of csv=s=x:p=0 "$HOOK_OUT/hook-clip.mp4" \
  | python3 -c "import sys; dims=sys.stdin.read().strip(); \
    assert dims=='${TARGET_W:-1080}x${TARGET_H:-1920}', f'resolution mismatch: {dims}'; \
    print(f'[c-hook] QA pass: resolution {dims}')"

# 3. Sample rate
ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate \
  -of csv=p=0 "$HOOK_OUT/hook-clip.mp4" \
  | python3 -c "import sys; ar=sys.stdin.read().strip(); \
    assert ar=='${TARGET_AR:-48000}', f'sample rate {ar} != ${TARGET_AR:-48000}'; \
    print(f'[c-hook] QA pass: audio {ar}Hz')"

echo "[c-hook] Done → $HOOK_OUT/hook-clip.mp4"
cat "$HOOK_OUT/hook-meta.json"
```

---

## Calling pattern (from a reel core)

```bash
# Locate c-hook (pack or local install)
HOOK_DIR=$(find "$HOME/.claude/skills" "$HOME/.hermes/skills" -maxdepth 4 -type d -name c-hook 2>/dev/null | head -1)
[ -n "$HOOK_DIR" ] || HOOK_DIR="$SKILL_DIR/.hub/c-hook"

HOOK_OUT="$W/interim/hook"
HOOK_SOURCE_URL="https://www.youtube.com/watch?v=EXAMPLE"
HOOK_START="0:04"
HOOK_END="0:10"
TRANSCRIBE="true"

# Source and run
source "$HOOK_DIR/scripts/run.sh"  # or inline the steps above

# Prepend hook to brand core render (caller's responsibility)
HOOK_META=$(cat "$HOOK_OUT/hook-meta.json")
HOOK_PATH=$(echo "$HOOK_META" | python3 -c "import json,sys; print(json.load(sys.stdin)['path'])")
HOOK_DUR=$(echo "$HOOK_META"  | python3 -c "import json,sys; print(json.load(sys.stdin)['duration'])")

# Example concat (caller adjusts to its specific concat strategy)
ffmpeg -y \
  -i "$HOOK_PATH" \
  -i "$W/continuation.mp4" \
  -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[vout][aout]" \
  -map "[vout]" -map "[aout]" \
  -c:v libx264 -preset medium -crf 19 \
  -c:a aac -b:a 192k \
  "$W/stitched.mp4"
```

> **Separate-tracks concat is safer for mixed sources.** Prefer extracting audio/video tracks
> independently, concatenating each, then muxing — this prevents rogue codec artifacts from
> mixed-container concat (the same pattern used in `p-hook-reel` Step 4 / `c-ffmpeg`
> `separate-tracks-mux`).

---

## Gotchas

- **yt-dlp `--download-sections` requires recent yt-dlp (≥ 2023.03).** Check: `yt-dlp --version`.
  Older versions ignore the flag silently and download the full video — verify the raw file duration
  before proceeding.
- **Some platforms (Instagram, TikTok) block yt-dlp or rotate cookies.** Have a fallback: manually
  download the clip and pass it as a local path by skipping Step H1 and placing the raw file at
  `$HOOK_OUT/hook-raw.mp4` before Step H2.
- **`--force-keyframes-at-cuts` adds a small re-encode step in yt-dlp.** This is intentional —
  it guarantees a clean cut at `HOOK_START` with no leading I-frame bleed.
- **Vertical-native sources (Instagram Reels, TikTok)** are already 9:16; the scale filter still
  runs but is effectively a no-op. Safe to leave in.
- **Whisper `.en` model is prohibited here.** Hooks from international creators contain non-English
  words; the base multilingual model handles code-switching correctly.
- **Do not re-encode the hook audio at a different sample rate ratio.** `aresample` is used only to
  set the sample rate to the target value, not to change playback speed. The resampler must not
  change the pitch or duration — ensure no `tempo` or `pitch` flag is passed.
