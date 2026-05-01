#!/usr/bin/env bash
# Full media upload flow: request signed URL, PUT the file, print media_url + content_hash.
#
# Usage: ./upload-media.sh <file_path> [--dry-run]
#
# VAS-33 Track A — content fingerprint (2026-04-22):
#   SHA256 the local file BEFORE uploading. If the same content was uploaded
#   within the last 24h, reuse the existing media_url instead of re-uploading.
#   This gives downstream create-post.sh a second dedup key that catches the
#   "rogue agent rewrote caption + re-uploaded same MP4" failure mode — where
#   caption-based idempotency keys differ but the video content is identical.
#
# Output JSON:
#   { "media_url": "...", "content_hash": "<sha256>", "content_bytes": <n>, "reused": true|false }
#
# Env vars:
#   FINGERPRINT=off       disables the content-fingerprint cache lookup (force re-upload)
#   BRAND                 optional — recorded in the fingerprint ledger for provenance
#   SOURCE_ISSUE          optional — recorded in the fingerprint ledger for provenance
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key

filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
FILE="${ARGS[0]:?Usage: upload-media.sh <file_path>}"

LEDGER_DIR="${HOME}/.posting-tools-ledger"
FP_LEDGER="${LEDGER_DIR}/media-fingerprints.tsv"
mkdir -p "$LEDGER_DIR"
touch "$FP_LEDGER"

if [ "${DRY_RUN}" = "1" ]; then
  echo "[dry-run] Would request upload URL, then PUT ${FILE}" >&2
  echo "{\"dry_run\": true, \"file\": \"${FILE}\"}"
  exit 0
fi

[ -f "$FILE" ] || { echo "File not found: $FILE" >&2; exit 1; }

# --- Content fingerprint (SHA256 of the raw file bytes) ---
CONTENT_HASH=$(shasum -a 256 "$FILE" | awk '{print $1}')
CONTENT_BYTES=$(wc -c < "$FILE" | tr -d ' ')
FINGERPRINT="${FINGERPRINT:-on}"

# --- Dedup LAYER: look up recent (≤24h) upload for this content_hash. Reuse if found. ---
if [ "$FINGERPRINT" = "on" ]; then
  NOW=$(date +%s)
  CUTOFF=$((NOW - 86400))
  REUSED_URL=$(awk -F'\t' -v h="$CONTENT_HASH" -v cutoff="$CUTOFF" \
    '$1 >= cutoff && $2 == h { print $3; exit }' "$FP_LEDGER" 2>/dev/null)
  if [ -n "$REUSED_URL" ]; then
    echo "{\"deduped_upload\": true, \"content_hash\": \"${CONTENT_HASH}\", \"media_url\": \"${REUSED_URL}\"}" >&2
    echo "   Override with FINGERPRINT=off (forces fresh upload)." >&2
    printf '{"media_url": "%s", "content_hash": "%s", "content_bytes": %s, "reused": true}\n' \
      "$REUSED_URL" "$CONTENT_HASH" "$CONTENT_BYTES"
    exit 0
  fi
fi

# 1. Get signed URL
RESP=$(curl -sS -X POST "${POSTFORME_BASE_URL}/${POSTFORME_API_VERSION}/media/create-upload-url" \
  -H "Authorization: Bearer ${POSTFORME_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{}')

MEDIA_URL=$(echo "$RESP" | jq -r '.media_url // empty')
UPLOAD_URL=$(echo "$RESP" | jq -r '.upload_url // empty')

if [ -z "$UPLOAD_URL" ]; then
  echo "Failed to get upload URL:" >&2
  echo "$RESP" >&2
  exit 1
fi

# 2. Detect content type (best-effort)
CT=$(file --mime-type -b "$FILE" 2>/dev/null || echo "application/octet-stream")

# 3. PUT file
curl -sS -X PUT "$UPLOAD_URL" \
  -H "Content-Type: ${CT}" \
  --data-binary "@${FILE}" >/dev/null

# 4. Record content_hash -> media_url in the fingerprint ledger
# Fields: ts  content_hash  media_url  bytes  brand  source_issue  file_path
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(date +%s)" "$CONTENT_HASH" "$MEDIA_URL" "$CONTENT_BYTES" \
  "${BRAND:-}" "${SOURCE_ISSUE:-}" "$FILE" \
  >> "$FP_LEDGER"

printf '{"media_url": "%s", "content_hash": "%s", "content_bytes": %s, "reused": false}\n' \
  "$MEDIA_URL" "$CONTENT_HASH" "$CONTENT_BYTES"
