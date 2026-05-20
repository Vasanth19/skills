#!/usr/bin/env bash
# composite.sh — ffmpeg composition: keyed avatar (bottom) + b-roll clips (top 60%)
# Usage: composite.sh --avatar <path> --duration <secs> --broll-dir <path> --placement-plan <json> --output <path>
set -euo pipefail

AVATAR=""
DURATION=20
BROLL_DIR=""
PLACEMENT_PLAN=""
OUTPUT=""
BG_COLOR="0x0F172A"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --avatar)         AVATAR="$2"; shift 2 ;;
    --duration)       DURATION="$2"; shift 2 ;;
    --broll-dir)      BROLL_DIR="$2"; shift 2 ;;
    --placement-plan) PLACEMENT_PLAN="$2"; shift 2 ;;
    --output)         OUTPUT="$2"; shift 2 ;;
    --bg-color)       BG_COLOR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$AVATAR" || -z "$OUTPUT" || -z "$PLACEMENT_PLAN" ]] && {
  echo "ERROR: --avatar, --placement-plan, and --output are required" >&2
  exit 1
}

[[ ! -f "$AVATAR" ]] && { echo "ERROR: avatar file not found: $AVATAR" >&2; exit 1; }
[[ ! -f "$PLACEMENT_PLAN" ]] && { echo "ERROR: placement plan not found: $PLACEMENT_PLAN" >&2; exit 1; }

mkdir -p "$(dirname "$OUTPUT")"

# Parse placement plan JSON (requires python3 or jq)
# Expected format: [{"clip":"filename.mp4","clip_start":0,"duration":4,"t_start":3,"t_end":7}, ...]
if command -v python3 &>/dev/null; then
  CLIPS=$(python3 -c "
import json, sys
plan = json.load(open('$PLACEMENT_PLAN'))
for i, c in enumerate(plan):
    print(f\"{i}|{c['clip']}|{c.get('clip_start',0)}|{c['duration']}|{c['t_start']}|{c['t_end']}\")
")
else
  echo "ERROR: python3 required to parse placement plan" >&2
  exit 1
fi

# Build ffmpeg inputs
INPUTS=(-i "$AVATAR")
FILTER_PARTS=()
CLIP_COUNT=0

while IFS='|' read -r idx clip clip_start dur t_start t_end; do
  CLIP_PATH="$BROLL_DIR/$clip"
  [[ ! -f "$CLIP_PATH" ]] && { echo "ERROR: b-roll clip not found: $CLIP_PATH" >&2; exit 1; }
  INPUTS+=(-i "$CLIP_PATH")
  CLIP_COUNT=$((CLIP_COUNT + 1))
  # b-roll filter: trim, offset, fps align, scale-fill 1080x1152 (top 60%)
  # force_original_aspect_ratio=increase + crop handles both landscape (pad-free) and portrait sources
  FILTER_PARTS+=("[${CLIP_COUNT}:v]trim=start=${clip_start}:duration=${dur},setpts=PTS-STARTPTS+${t_start}/TB,fps=30,scale=1080:1152:force_original_aspect_ratio=increase,crop=1080:1152,format=yuv420p[br${idx}]")
done <<< "$CLIPS"

# Canvas base
FILTER="color=c=${BG_COLOR}:s=1080x1920:d=${DURATION},format=yuv420p[canvas];"

# Avatar: fps align → two-pass colorkey → scale to 1080 wide (auto-preserving aspect)
# Assumes source is 1312x736 landscape (Cozy Tech Guru); keyed green becomes transparent
FILTER+="[0:v]fps=30,colorkey=0x00FF00:0.25:0.05,colorkey=0x00FF00:0.40:0.01,scale=1080:-2[avatar_keyed];"

# B-roll clip filters
for part in "${FILTER_PARTS[@]}"; do
  FILTER+="${part};"
done

# Overlay chain: canvas → b-roll segments → avatar (always last/on top)
PREV="canvas"
while IFS='|' read -r idx clip clip_start dur t_start t_end; do
  NEXT="l${idx}"
  FILTER+="[${PREV}][br${idx}]overlay=0:0:enable='between(t,${t_start},${t_end})'[${NEXT}];"
  PREV="$NEXT"
done <<< "$CLIPS"

# Avatar flush to bottom, full duration
FILTER+="[${PREV}][avatar_keyed]overlay=0:(H-h),format=yuv420p[vout]"

echo "Compositing ${CLIP_COUNT} b-roll clips over ${DURATION}s avatar..."
echo "Output: $OUTPUT"

ffmpeg -y "${INPUTS[@]}" \
  -filter_complex "$FILTER" \
  -map "[vout]" -map "0:a" \
  -c:v libx264 -crf 18 -preset fast \
  -c:a aac -b:a 192k \
  -movflags +faststart \
  "$OUTPUT"

echo "Done: $OUTPUT"
