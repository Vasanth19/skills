#!/usr/bin/env bash
# Upload photo(s) to one or more platforms via Upload Post API
# Usage: ./upload-photo.sh <image_path_or_url> <user> <platforms> [title]
#
# Example:
#   ./upload-photo.sh ./photo.jpg mrgg "instagram,linkedin" "Caption here"

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"

IMAGE="${1:?Usage: upload-photo.sh <image> <user> <platforms> [title]}"
USER="${2:?Provide user profile name}"
PLATFORMS="${3:?Provide comma-separated platforms}"
TITLE="${4:-}"

PLATFORM_ARGS=""
IFS=',' read -ra PLATS <<< "$PLATFORMS"
for p in "${PLATS[@]}"; do
  PLATFORM_ARGS="$PLATFORM_ARGS -F platform[]=$p"
done

OPTIONAL_ARGS=""
[ -n "$TITLE" ] && OPTIONAL_ARGS="$OPTIONAL_ARGS -F title=$TITLE"

if [[ "$IMAGE" == http* ]]; then
  IMAGE_ARG="-F photo=$IMAGE"
else
  IMAGE_ARG="-F photo=@$IMAGE"
fi

curl -s -X POST "$BASE_URL/upload_photos" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" \
  -F "user=$USER" \
  $PLATFORM_ARGS \
  $IMAGE_ARG \
  -F "async_upload=true" \
  $OPTIONAL_ARGS | jq .
