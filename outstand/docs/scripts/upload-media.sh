#!/usr/bin/env bash
# Full media upload flow: get presigned URL, PUT file, confirm, print media id.
# Usage: ./upload-media.sh <file_path> [--dry-run]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key

filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
FILE="${ARGS[0]:?Usage: upload-media.sh <file_path>}"

if [ "${DRY_RUN}" = "1" ]; then
  echo "[dry-run] POST ${OUTSTAND_BASE_URL}/${OUTSTAND_API_VERSION}/media/upload-url" >&2
  echo "[dry-run] PUT <signed-url>" >&2
  echo "[dry-run] POST ${OUTSTAND_BASE_URL}/${OUTSTAND_API_VERSION}/media/<id>/confirm" >&2
  echo "{\"dry_run\": true, \"file\": \"${FILE}\"}"
  exit 0
fi

[ -f "$FILE" ] || { echo "File not found: $FILE" >&2; exit 1; }
FILENAME=$(basename "$FILE")
CT=$(file --mime-type -b "$FILE" 2>/dev/null || echo "application/octet-stream")

# 1. Request signed URL
BODY="{\"filename\":\"${FILENAME}\",\"contentType\":\"${CT}\"}"
RESP=$(curl -sS -X POST "${OUTSTAND_BASE_URL}/${OUTSTAND_API_VERSION}/media/upload-url" \
  -H "Authorization: Bearer ${OUTSTAND_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$BODY")

UPLOAD_URL=$(echo "$RESP" | jq -r '.data.uploadUrl // .uploadUrl // empty')
MEDIA_ID=$(echo "$RESP" | jq -r '.data.id // .id // empty')

if [ -z "$UPLOAD_URL" ] || [ -z "$MEDIA_ID" ]; then
  echo "Failed to get upload URL:" >&2
  echo "$RESP" >&2
  exit 1
fi

# 2. PUT file
curl -sS -X PUT "$UPLOAD_URL" -H "Content-Type: ${CT}" --data-binary "@${FILE}" >/dev/null

# 3. Confirm upload
curl -sS -X POST "${OUTSTAND_BASE_URL}/${OUTSTAND_API_VERSION}/media/${MEDIA_ID}/confirm" \
  -H "Authorization: Bearer ${OUTSTAND_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{}' >/dev/null

echo "{\"id\": \"${MEDIA_ID}\"}"
