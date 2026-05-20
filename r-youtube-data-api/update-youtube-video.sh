#!/bin/bash
set -e

usage() {
  echo "Usage: $0 <video_id> [--description <text>] [--tags <csv>] [--category <id>] [--thumbnail <path>]"
  echo ""
  echo "Environment:"
  echo "  CREDS_DIR   Directory containing youtube-oauth-credentials.json and youtube-tokens.json"
  echo "              (default: ./.gsai)"
  echo ""
  echo "Examples:"
  echo "  CREDS_DIR=./.gsai $0 BCsm9ZC97Qk --description 'My video' --tags 'ai,automation' --thumbnail /path/to/thumb.jpg"
  echo "  CREDS_DIR=./.gsai $0 BCsm9ZC97Qk --category 28 --thumbnail /path/to/thumb.jpg"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

VIDEO_ID="$1"
shift

CREDS_DIR="${CREDS_DIR:-./.gsai}"
TOKENS_FILE="$CREDS_DIR/youtube-tokens.json"
CREDS_FILE="$CREDS_DIR/youtube-oauth-credentials.json"

if [ ! -f "$TOKENS_FILE" ]; then
  echo "❌ Tokens file not found: $TOKENS_FILE"
  echo "Set CREDS_DIR or run from a directory with .gsai/ credentials."
  echo "Run: python3 youtube-oauth-localhost.py"
  exit 1
fi

if [ ! -f "$CREDS_FILE" ]; then
  echo "❌ Credentials file not found: $CREDS_FILE"
  echo "Place your GCP Desktop OAuth JSON here."
  exit 1
fi

# Extract OAuth details (handles both web and desktop formats)
CLIENT_ID=$(jq -r '.web.client_id // .installed.client_id' "$CREDS_FILE")
CLIENT_SECRET=$(jq -r '.web.client_secret // .installed.client_secret' "$CREDS_FILE")
REFRESH_TOKEN=$(jq -r '.refresh_token' "$TOKENS_FILE")

# Get fresh access token
echo "🔄 Refreshing access token..."
TOKEN_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "refresh_token=${REFRESH_TOKEN}" \
  -d "grant_type=refresh_token")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get access token:"
  echo "$TOKEN_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Access token acquired"

# Fetch current video metadata
echo ""
echo "📥 Fetching current video metadata..."
CURRENT=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=${VIDEO_ID}")

SNIPPET=$(echo "$CURRENT" | jq '.items[0].snippet')
ETAG=$(echo "$CURRENT" | jq -r '.items[0].etag')

# Initialize variables
THUMBNAIL_PATH=""
UPDATE_METADATA=false

# Parse current values
TITLE=$(echo "$SNIPPET" | jq -r '.title')
DESCRIPTION=$(echo "$SNIPPET" | jq -r '.description')
TAGS=$(echo "$SNIPPET" | jq -r '.tags | join(",")')
CATEGORY=$(echo "$SNIPPET" | jq -r '.categoryId')

echo "Current:"
echo "  Title: $TITLE"
echo "  Description: ${DESCRIPTION:0:100}..."
echo "  Tags: $TAGS"
echo "  Category: $CATEGORY"

# Parse arguments and update values
while [ $# -gt 0 ]; do
  case "$1" in
    --description)
      DESCRIPTION="$2"
      UPDATE_METADATA=true
      shift 2
      ;;
    --tags)
      TAGS="$2"
      UPDATE_METADATA=true
      shift 2
      ;;
    --category)
      CATEGORY="$2"
      UPDATE_METADATA=true
      shift 2
      ;;
    --thumbnail)
      THUMBNAIL_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Update metadata only if changes requested
if [ "$UPDATE_METADATA" = true ]; then
  # Convert tags CSV to JSON array
  TAGS_JSON=$(echo "$TAGS" | jq -R 'split(",")')

  # Build update payload using jq to properly escape all strings
  UPDATE_PAYLOAD=$(jq -n \
    --arg title "$TITLE" \
    --arg desc "$DESCRIPTION" \
    --argjson tags "$TAGS_JSON" \
    --arg category "$CATEGORY" \
    --arg etag "$ETAG" \
    --arg vid "$VIDEO_ID" \
    '{
      kind: "youtube#video",
      etag: $etag,
      id: $vid,
      snippet: {
        title: $title,
        description: $desc,
        tags: $tags,
        categoryId: $category,
        liveBroadcastContent: "none"
      }
    }')

  echo ""
  echo "🔄 Updating video metadata..."

  UPDATE_RESPONSE=$(curl -s -X PUT "https://www.googleapis.com/youtube/v3/videos?part=snippet" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_PAYLOAD")

  if echo "$UPDATE_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
    echo "✅ Video metadata updated successfully!"
    echo ""
    echo "Updated:"
    echo "  Description: ${DESCRIPTION:0:100}..."
    echo "  Tags: $TAGS"
    echo "  Category: $CATEGORY"
  else
    echo "❌ Update failed:"
    echo "$UPDATE_RESPONSE" | jq '.'
    exit 1
  fi
else
  echo ""
  echo "ℹ️  No metadata changes requested (only thumbnail)"
fi

# Upload thumbnail if provided
if [ -n "$THUMBNAIL_PATH" ]; then
  if [ ! -f "$THUMBNAIL_PATH" ]; then
    echo ""
    echo "❌ Thumbnail file not found: $THUMBNAIL_PATH"
    exit 1
  fi

  echo ""
  echo "🖼️  Uploading thumbnail..."

  THUMB_RESPONSE=$(curl -s -X POST \
    "https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId=${VIDEO_ID}" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -F "image=@${THUMBNAIL_PATH}")

  if echo "$THUMB_RESPONSE" | jq -e '.kind == "youtube#thumbnailSetResponse"' > /dev/null 2>&1; then
    THUMB_URL=$(echo "$THUMB_RESPONSE" | jq -r '.items[0].maxres.url // .items[0].standard.url // .items[0].high.url // "N/A"')
    echo "✅ Thumbnail uploaded successfully!"
    echo "  File: $(basename "$THUMBNAIL_PATH")"
    echo "  URL: $THUMB_URL"
  else
    echo "⚠️  Thumbnail upload failed:"
    echo "$THUMB_RESPONSE" | jq '.'
    # Note: don't exit 1 — metadata was successful even if thumbnail fails
  fi
fi

echo ""
echo "🎬 Video: https://www.youtube.com/watch?v=${VIDEO_ID}"
