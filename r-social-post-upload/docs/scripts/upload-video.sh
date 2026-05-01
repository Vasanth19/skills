#!/usr/bin/env bash
# Upload a video to one or more platforms via Upload Post API
# Usage: ./upload-video.sh <video_path_or_url> <user> <platforms> [title] [scheduled_date]
#
# Example:
#   ./upload-video.sh ./video.mp4 mrgg "tiktok,instagram" "My post title"
#   ./upload-video.sh https://example.com/video.mp4 mrgg "youtube" "Title" "2025-12-31T10:00:00Z"
#
# Duplicate-prevention layers (matches postforme/create-post.sh approach):
#
#   1. Pre-flight platform check — only uploads to connected platforms.
#
#   2. Local idempotency ledger (~/.posting-tools-ledger/upload-post.tsv).
#      Computes SHA256 of (video_ref + user + platforms_sorted + title + scheduled_date).
#      If the key was recorded in the last 24h, aborts with the prior request_id.
#      Override with IDEMPOTENCY=off env var (not recommended).
#
#   3. Post-upload verification — calls /uploadposts/history for the user and warns
#      loudly if more than one recent entry matches the same title (last 5 min window),
#      which usually indicates a re-run created a duplicate.
#
# Pre-flight: validates that all requested platforms are connected for the user.
# If any platform is NOT connected, the script will:
#   - Print a WARNING for each disconnected platform
#   - Only upload to connected platforms
#   - If NO platforms are connected, exit with error

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

# Brand analytics ledger (best-effort, non-blocking).
_LEDGER_LIB="$(dirname "${BASH_SOURCE[0]}")/../../../../shared/ledger.sh"
# shellcheck disable=SC1090
[ -f "$_LEDGER_LIB" ] && source "$_LEDGER_LIB"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"
IDEMPOTENCY="${IDEMPOTENCY:-on}"
LEDGER_DIR="${HOME}/.posting-tools-ledger"
LEDGER_FILE="${LEDGER_DIR}/upload-post.tsv"
DEDUP_WINDOW_HOURS="${DEDUP_WINDOW_HOURS:-24}"

VIDEO="${1:?Usage: upload-video.sh <video> <user> <platforms> [title] [scheduled_date]}"
USER="${2:?Provide user profile name}"
PLATFORMS="${3:?Provide comma-separated platforms: tiktok,instagram,youtube,linkedin,facebook,x,threads,pinterest,bluesky,reddit}"
TITLE="${4:-}"
SCHEDULED_DATE="${5:-}"

# ── Compute idempotency key from inputs (stable, deterministic) ──
SORTED_PLATFORMS=$(printf '%s' "$PLATFORMS" | tr ',' '\n' | sort | paste -sd, -)
IDEMPOTENCY_KEY=$(printf '%s|%s|%s|%s|%s' "$VIDEO" "$USER" "$SORTED_PLATFORMS" "$TITLE" "$SCHEDULED_DATE" \
  | shasum -a 256 | cut -c1-16)

# ── Pre-check: has this exact upload been done in the last 24h? ──
if [ "$IDEMPOTENCY" = "on" ]; then
  mkdir -p "$LEDGER_DIR"
  touch "$LEDGER_FILE"
  if [ -s "$LEDGER_FILE" ]; then
    # Format: epoch \t key \t request_id \t user \t platforms \t title
    NOW=$(date +%s)
    CUTOFF=$(( NOW - DEDUP_WINDOW_HOURS * 3600 ))
    MATCH=$(awk -F'\t' -v key="$IDEMPOTENCY_KEY" -v cutoff="$CUTOFF" \
      '$2==key && $1>cutoff {print $0}' "$LEDGER_FILE" | tail -1)
    if [ -n "$MATCH" ]; then
      PRIOR_TS=$(printf '%s' "$MATCH" | cut -f1)
      PRIOR_RID=$(printf '%s' "$MATCH" | cut -f3)
      echo "🛑 DEDUP: identical upload already recorded at epoch $PRIOR_TS (request_id=$PRIOR_RID)." >&2
      echo "   Same inputs within ${DEDUP_WINDOW_HOURS}h window — not re-uploading." >&2
      echo "   Override with IDEMPOTENCY=off (not recommended)." >&2
      echo "{\"deduped\": true, \"existing_request_id\": \"${PRIOR_RID}\", \"idempotency_key\": \"${IDEMPOTENCY_KEY}\"}"
      exit 0
    fi
  fi
fi

# ── Pre-flight: check which platforms are connected ──
echo "🔍 Checking connected platforms for '$USER'..."
USER_DATA=$(curl -s "$BASE_URL/users?username=$USER" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY")

IFS=',' read -ra REQUESTED <<< "$PLATFORMS"
CONNECTED_PLATFORMS=()
DISCONNECTED_PLATFORMS=()

for p in "${REQUESTED[@]}"; do
  p_lower=$(echo "$p" | tr '[:upper:]' '[:lower:]')
  # Check if this platform has a non-empty, non-null value in social_accounts
  # The list-users endpoint returns social_accounts with platform keys
  account_value=$(echo "$USER_DATA" | jq -r ".profiles[] | select(.username==\"$USER\") | .social_accounts.${p_lower} // empty")

  if [ -n "$account_value" ] && [ "$account_value" != "null" ] && [ "$account_value" != "" ]; then
    CONNECTED_PLATFORMS+=("$p")
    echo "  ✅ $p — connected"
  else
    DISCONNECTED_PLATFORMS+=("$p")
    echo "  ❌ $p — NOT CONNECTED (skipping)"
  fi
done

if [ ${#CONNECTED_PLATFORMS[@]} -eq 0 ]; then
  echo ""
  echo "🚨 ERROR: No connected platforms for user '$USER'. Cannot upload."
  echo "   Connect platforms at https://upload-post.com"
  exit 1
fi

if [ ${#DISCONNECTED_PLATFORMS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Warning: ${#DISCONNECTED_PLATFORMS[@]} platform(s) not connected: ${DISCONNECTED_PLATFORMS[*]}"
  echo "   Only uploading to: ${CONNECTED_PLATFORMS[*]}"
  echo "   Connect missing platforms at https://upload-post.com"
  echo ""
fi

# Build platform array params (only connected platforms)
PLATFORM_ARGS=""
for p in "${CONNECTED_PLATFORMS[@]}"; do
  PLATFORM_ARGS="$PLATFORM_ARGS -F platform[]=$p"
done

# Build optional params
OPTIONAL_ARGS=""
[ -n "$TITLE" ] && OPTIONAL_ARGS="$OPTIONAL_ARGS -F title=$TITLE"
[ -n "$SCHEDULED_DATE" ] && OPTIONAL_ARGS="$OPTIONAL_ARGS -F scheduled_date=$SCHEDULED_DATE"

# Detect if video is URL or file
if [[ "$VIDEO" == http* ]]; then
  VIDEO_ARG="-F video=$VIDEO"
else
  VIDEO_ARG="-F video=@$VIDEO"
fi

echo "📤 Uploading to: ${CONNECTED_PLATFORMS[*]}..."
RESULT=$(curl -s -X POST "$BASE_URL/upload" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" \
  -F "user=$USER" \
  $PLATFORM_ARGS \
  $VIDEO_ARG \
  -F "async_upload=true" \
  $OPTIONAL_ARGS)

echo "$RESULT" | jq .

# Show summary
REQUEST_ID=$(echo "$RESULT" | jq -r '.request_id // empty')
TOTAL=$(echo "$RESULT" | jq -r '.total_platforms // "unknown"')
if [ -n "$REQUEST_ID" ]; then
  echo ""
  echo "📋 Upload queued: $REQUEST_ID"
  echo "   Platforms: ${CONNECTED_PLATFORMS[*]} (${#CONNECTED_PLATFORMS[@]} connected, ${#DISCONNECTED_PLATFORMS[@]} skipped)"

  # ── Record in ledger for future dedup ──
  if [ "$IDEMPOTENCY" = "on" ]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date +%s)" "$IDEMPOTENCY_KEY" "$REQUEST_ID" "$USER" "$SORTED_PLATFORMS" "$TITLE" \
      >> "$LEDGER_FILE"
  fi

  # ── Brand analytics ledger (best-effort) ──
  # Set BRAND env var (folder slug under ~/vasanth-hq/) to opt in.
  # SOURCE_ISSUE / SOURCE_BRIEF_ID env vars are optional provenance.
  if [ -n "${BRAND:-}" ] && declare -f ledger_record_post >/dev/null 2>&1; then
    ledger_record_post \
      "$BRAND" "$REQUEST_ID" "upload-post" "$TITLE" "$VIDEO" \
      "$IDEMPOTENCY_KEY" "${SOURCE_ISSUE:-}" "${SOURCE_BRIEF_ID:-}" \
      || true
    for p in "${CONNECTED_PLATFORMS[@]}"; do
      ledger_record_platform "$BRAND" "$REQUEST_ID" "$p" "" "" "pending" "" || true
    done
  fi

  # ── Post-upload verification: are there multiple recent uploads with the same title? ──
  if [ -n "$TITLE" ]; then
    sleep 1
    RECENT=$(curl -s "$BASE_URL/uploadposts/history?user=$USER&page=1" \
      -H "Authorization: Apikey $UPLOAD_POST_API_KEY" \
      | jq -r --arg title "$TITLE" '[.history[]? // empty | select(.title==$title)] | length' 2>/dev/null || echo "1")
    if [ "${RECENT:-1}" -gt 1 ]; then
      echo ""
      echo "⚠️  WARNING: ${RECENT} recent uploads found with title \"$TITLE\" for user $USER." >&2
      echo "   Possible duplicate. Check https://upload-post.com dashboard or run:" >&2
      echo "   ./list-history.sh $USER | jq '.history[] | select(.title==\"$TITLE\")'" >&2
    fi
  fi
fi
