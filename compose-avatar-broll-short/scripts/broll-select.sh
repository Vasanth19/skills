#!/usr/bin/env bash
# broll-select.sh — validate b-roll clips and write placement-plan.json
# Usage: broll-select.sh --theme <ai|app|gfx|images|recordings> --brand-root <path> --output <plan.json> [--duration 20]
#
# Reads clips from creatives/brolls/<theme>/ and produces a placement plan
# with 4-6 clips covering t=3 to t=17 (leaving hook + CTA as avatar-only).
set -euo pipefail

THEME="ai"
BRAND_ROOT="/Users/vasanth/vasanth-hq/mr-growth-guide"
OUTPUT=""
TOTAL_DUR=20
HOOK_DUR=3
CTA_DUR=3
BROLL_WINDOW=$((TOTAL_DUR - HOOK_DUR - CTA_DUR))  # 14s available

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)       THEME="$2"; shift 2 ;;
    --brand-root)  BRAND_ROOT="$2"; shift 2 ;;
    --output)      OUTPUT="$2"; shift 2 ;;
    --duration)    TOTAL_DUR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$OUTPUT" ]] && { echo "ERROR: --output required" >&2; exit 1; }

BROLL_DIR="$BRAND_ROOT/creatives/brolls/$THEME"
[[ ! -d "$BROLL_DIR" ]] && { echo "ERROR: b-roll dir not found: $BROLL_DIR" >&2; exit 1; }

# Collect .mp4 clips from the theme folder
CLIPS=()
while IFS= read -r f; do
  CLIPS+=("$(basename "$f")")
done < <(find "$BROLL_DIR" -maxdepth 1 -name "*.mp4" | sort)

[[ ${#CLIPS[@]} -eq 0 ]] && { echo "ERROR: no .mp4 clips found in $BROLL_DIR" >&2; exit 1; }

# Supplement with ai theme if fewer than 4 clips
if [[ ${#CLIPS[@]} -lt 4 && "$THEME" != "ai" ]]; then
  AI_DIR="$BRAND_ROOT/creatives/brolls/ai"
  while IFS= read -r f; do
    CLIPS+=("$(basename "$f")")
  done < <(find "$AI_DIR" -maxdepth 1 -name "*.mp4" | sort)
  echo "Supplemented with ai theme clips (now ${#CLIPS[@]} total)"
fi

# Build placement plan: fill 14s window starting at t=3, clips of 3-4s each
python3 - "$OUTPUT" "${BROLL_DIR}" "$HOOK_DUR" "$BROLL_WINDOW" "${CLIPS[@]}" <<'PYEOF'
import sys, json
from pathlib import Path
import subprocess

output = sys.argv[1]
broll_dir = Path(sys.argv[2])
hook_dur = float(sys.argv[3])
window = float(sys.argv[4])
clips = sys.argv[5:]

def get_duration(path):
    try:
        r = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
            capture_output=True, text=True, timeout=10
        )
        return float(r.stdout.strip())
    except Exception:
        return 4.0  # fallback: assume 4s

plan = []
t = hook_dur
used = set()

# Use clips in rotation (avoid repeats)
clip_queue = [c for c in clips if not c.startswith('.')]

for clip in clip_queue:
    if t >= hook_dur + window:
        break
    if clip in used:
        continue
    clip_path = broll_dir / clip
    if not clip_path.exists():
        # try ai theme as fallback
        alt = broll_dir.parent / "ai" / clip
        if alt.exists():
            clip_path = alt
        else:
            continue
    raw_dur = get_duration(clip_path)
    clip_dur = min(4.0, raw_dur)  # use up to 4s per clip
    remaining = (hook_dur + window) - t
    if remaining < 2.0:
        break
    clip_dur = min(clip_dur, remaining)
    plan.append({
        "clip": clip,
        "clip_start": 0,
        "duration": round(clip_dur, 2),
        "t_start": round(t, 2),
        "t_end": round(t + clip_dur, 2)
    })
    used.add(clip)
    t += clip_dur

if len(plan) < 2:
    print(f"WARNING: only {len(plan)} clips placed — check clip availability", file=sys.stderr)

Path(output).parent.mkdir(parents=True, exist_ok=True)
Path(output).write_text(json.dumps(plan, indent=2))

total_broll = sum(c["duration"] for c in plan)
print(f"Placement plan: {len(plan)} clips, {total_broll:.1f}s b-roll coverage")
for c in plan:
    print(f"  t={c['t_start']:.1f}-{c['t_end']:.1f}s  {c['clip']}")
PYEOF

echo "Placement plan written to: $OUTPUT"
