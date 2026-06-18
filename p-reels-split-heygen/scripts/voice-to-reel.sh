#!/usr/bin/env bash
# voice-to-reel: SCRIPT → ElevenLabs v3 VO → HeyGen v3 audio-driven avatar (Avatar III, 16:9 1080p)
#   → downloads the finished talking-head MP4 to $OUT.
#
# This is the provider step ONLY (Step 0 of p-reels-split-heygen). It contains ZERO compositing —
# the split-screen / cut-zoom / captions / CTA all live in p-reels-split, which this skill delegates
# to afterwards. Source-promoted from
#   cfw-marketing/creatives/productions/fnb-split-screen-short/voice-to-reel.sh
# and generalized: no hardcoded production folder; output path + work dir are parameterized.
#
# Keys: ELEVENLABS_API_KEY, HEYGEN_API_KEY — taken from the environment, else auto-loaded
#       from ~/.gsai/secrets.env (override path with SECRETS_FILE=...).
# Usage:
#   bash voice-to-reel.sh "Script text here" /path/to/out/th.mp4
#   SCRIPT="..." OUT=/path/th.mp4 bash voice-to-reel.sh
# Optional env overrides: EL_VOICE, EL_MODEL, HG_AVATAR, WORK
#
# Prints the absolute path of the finished MP4 as its LAST line.
set -euo pipefail

# Load keys from the canonical secrets file if not already in the environment.
# Single source of truth: ~/.gsai/secrets.env (also feeds heygen-credit-check.sh).
SECRETS_FILE="${SECRETS_FILE:-${HOME}/.gsai/secrets.env}"
if { [ -z "${ELEVENLABS_API_KEY:-}" ] || [ -z "${HEYGEN_API_KEY:-}" ]; } && [ -f "$SECRETS_FILE" ]; then
  # shellcheck source=/dev/null
  set +u; source "$SECRETS_FILE"; set -u
fi

: "${ELEVENLABS_API_KEY:?set ELEVENLABS_API_KEY (env or $SECRETS_FILE)}"
: "${HEYGEN_API_KEY:?set HEYGEN_API_KEY (env or $SECRETS_FILE)}"

EL_VOICE="${EL_VOICE:-qfNHzU5pVyzMLm53FhzY}"          # ElevenLabs cloned "Vasanth-042026"
EL_MODEL="${EL_MODEL:-eleven_v3}"
# DEFAULT = Avatar III "GG-4k" (id confirmed Avatar III via preview path /avatar/v3/).
# Do NOT swap to an Avatar IV/V avatar — generation is set by the avatar_id itself
# (no version param exists in the API). Keep an Avatar-III avatar_id here.
HG_AVATAR="${HG_AVATAR:-9273e994f1ed484d9031afa3725676c5}"  # HeyGen Growth Guide (GG-4k, Avatar III)

SCRIPT="${SCRIPT:-${1:-}}"
[ -z "$SCRIPT" ] && { echo "[voice-to-reel] No script. Pass as arg 1 or set SCRIPT=." >&2; exit 1; }
OUT="${OUT:-${2:-./th.mp4}}"
mkdir -p "$(dirname "$OUT")"
WORK="${WORK:-$(dirname "$OUT")/_v2r}" ; mkdir -p "$WORK"

echo "[1/4] ElevenLabs $EL_MODEL TTS ($EL_VOICE) ..." >&2
EL_VOICE="$EL_VOICE" EL_MODEL="$EL_MODEL" SCRIPT="$SCRIPT" WORK="$WORK" python3 - <<'PY'
import os,json,urllib.request
voice,model,script,work=os.environ["EL_VOICE"],os.environ["EL_MODEL"],os.environ["SCRIPT"],os.environ["WORK"]
body=json.dumps({"text":script,"model_id":model,"voice_settings":{"stability":0.5,"similarity_boost":0.75}}).encode()
req=urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voice}?output_format=mp3_44100_128",
    data=body, headers={"xi-api-key":os.environ["ELEVENLABS_API_KEY"],"Content-Type":"application/json","Accept":"audio/mpeg"}, method="POST")
with urllib.request.urlopen(req) as r: open(f"{work}/vo-eleven.mp3","wb").write(r.read())
print("  wrote vo-eleven.mp3")
PY

echo "[2/4] upload audio asset to HeyGen ..." >&2
ASSET=$(curl -s -X POST "https://upload.heygen.com/v1/asset" -H "X-Api-Key: $HEYGEN_API_KEY" \
  -H "Content-Type: audio/mpeg" --data-binary "@$WORK/vo-eleven.mp3" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['id'])")
echo "  asset_id=$ASSET" >&2

echo "[3/4] generate v3 avatar video (audio-driven, 16:9 1080p) ..." >&2
# IMPORTANT: request 16:9 (NOT 9:16). 9:16 letterboxes the landscape avatar with white bars →
# only ~1080x608 of real avatar pixels → pixelated after the split-screen crop+cut-zoom upscale.
# 16:9 gives a full 1920x1080 sharp avatar; p-reels-split only needs the landscape strip anyway.
VID=$(curl -s -X POST "https://api.heygen.com/v3/videos" -H "X-Api-Key: $HEYGEN_API_KEY" -H "Content-Type: application/json" \
  -d "{\"type\":\"avatar\",\"avatar_id\":\"$HG_AVATAR\",\"audio_asset_id\":\"$ASSET\",\"aspect_ratio\":\"16:9\",\"resolution\":\"1080p\",\"title\":\"voice-to-reel\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['video_id'])")
echo "  video_id=$VID" >&2

echo "[4/4] poll + download -> $OUT ..." >&2
while true; do
  S=$(curl -s -H "X-Api-Key: $HEYGEN_API_KEY" "https://api.heygen.com/v1/video_status.get?video_id=$VID")
  ST=$(echo "$S" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['status'])")
  [ "$ST" = "completed" ] && { URL=$(echo "$S" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['video_url'])"); curl -sL "$URL" -o "$OUT"; echo "  downloaded $OUT" >&2; break; }
  [ "$ST" = "failed" ] && { echo "  RENDER FAILED: $S" >&2; exit 1; }
  sleep 15
done

# Final line = the path the caller (p-reels-split-heygen Step 1) reads as TALKING_HEAD_VIDEO.
echo "$OUT"
