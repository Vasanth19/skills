#!/usr/bin/env bash
# Create (and optionally schedule) a post across one or more accounts — with idempotency.
# Usage: ./create-post.sh <content> <social_account_ids_csv> [media_id] [scheduled_at_iso8601] [--dry-run]
#
# Examples:
#   ./create-post.sh "Hello" "acc_123,acc_456"
#   ./create-post.sh "Launch!" "acc_123" "med_789"
#   ./create-post.sh "Tomorrow" "acc_123" "" "2026-12-31T10:00:00Z"
#
# Duplicate-prevention layers (mirrors postforme/upload-post approach):
#
#   1. Local idempotency ledger (~/.posting-tools-ledger/outstand.tsv).
#      Computes SHA256 of (content + sorted_accounts + media_id + scheduled_at).
#      If the key was recorded in the last 24h, aborts with the prior post_id.
#      Override with IDEMPOTENCY=off env var (not recommended).
#
#   2. Post-create verification — re-lists recent posts and warns loudly if
#      more than one recent post matches the same content (60 s window). Catches
#      partial failures that slip through despite client-side errors.
#
# Why a local ledger (not API-side external_id like postforme):
#   Outstand's POST /posts body does not expose an external_id / idempotencyKey
#   field (see docs/endpoints.md), so we fall back to the same local-ledger
#   pattern used in upload-post/upload-video.sh.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key

filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
CONTENT="${ARGS[0]:?Usage: create-post.sh <content> <account_ids_csv> [media_id] [scheduled_at]}"
ACCOUNTS_CSV="${ARGS[1]:?Provide comma-separated socialAccountIds}"
MEDIA_ID="${ARGS[2]:-}"
SCHEDULED_AT="${ARGS[3]:-}"

IDEMPOTENCY="${IDEMPOTENCY:-on}"
LEDGER_DIR="${HOME}/.posting-tools-ledger"
LEDGER_FILE="${LEDGER_DIR}/outstand.tsv"
DEDUP_WINDOW_HOURS="${DEDUP_WINDOW_HOURS:-24}"

# --- Compute idempotency key: stable hash of (content + sorted_accounts + media + scheduled_at) ---
SORTED_ACCOUNTS=$(printf '%s' "$ACCOUNTS_CSV" | tr ',' '\n' | sort | paste -sd, -)
IDEMPOTENCY_KEY=$(printf '%s|%s|%s|%s' "$CONTENT" "$SORTED_ACCOUNTS" "$MEDIA_ID" "$SCHEDULED_AT" \
  | shasum -a 256 | cut -c1-16)

# --- Pre-check: has this exact create been done in the last 24h? ---
if [ "$IDEMPOTENCY" = "on" ] && [ "${DRY_RUN}" != "1" ]; then
  mkdir -p "$LEDGER_DIR"
  touch "$LEDGER_FILE"
  if [ -s "$LEDGER_FILE" ]; then
    # Format: epoch \t key \t post_id \t accounts \t content-preview
    NOW=$(date +%s)
    CUTOFF=$(( NOW - DEDUP_WINDOW_HOURS * 3600 ))
    MATCH=$(awk -F'\t' -v key="$IDEMPOTENCY_KEY" -v cutoff="$CUTOFF" \
      '$2==key && $1>cutoff {print $0}' "$LEDGER_FILE" | tail -1)
    if [ -n "$MATCH" ]; then
      PRIOR_TS=$(printf '%s' "$MATCH" | cut -f1)
      PRIOR_PID=$(printf '%s' "$MATCH" | cut -f3)
      echo "🛑 DEDUP: identical outstand post already recorded at epoch $PRIOR_TS (post_id=$PRIOR_PID)." >&2
      echo "   Same inputs within ${DEDUP_WINDOW_HOURS}h window — not re-creating." >&2
      echo "   Override with IDEMPOTENCY=off (not recommended)." >&2
      echo "{\"deduped\": true, \"existing_post_id\": \"${PRIOR_PID}\", \"idempotency_key\": \"${IDEMPOTENCY_KEY}\"}"
      exit 0
    fi
  fi
fi

# --- Build JSON body ---
ACCOUNTS_JSON=$(printf '%s' "$ACCOUNTS_CSV" | awk -F, '{
  printf "["
  for (i=1;i<=NF;i++){ printf "%s\"%s\"", (i>1?",":""), $i }
  printf "]"
}')

CONTAINER_CONTENT=$(printf '%s' "$CONTENT" | python3 -c "import sys,json;print(json.dumps(sys.stdin.read()))")

if [ -n "$MEDIA_ID" ]; then
  CONTAINERS_JSON="[{\"content\":${CONTAINER_CONTENT},\"mediaIds\":[\"${MEDIA_ID}\"]}]"
else
  CONTAINERS_JSON="[{\"content\":${CONTAINER_CONTENT}}]"
fi

SCHED_FIELD=""
if [ -n "$SCHEDULED_AT" ]; then
  SCHED_FIELD=",\"scheduledAt\":\"${SCHEDULED_AT}\""
fi

BODY="{\"containers\":${CONTAINERS_JSON},\"socialAccountIds\":${ACCOUNTS_JSON}${SCHED_FIELD}}"

# --- Create the post ---
RESPONSE=$(run_curl POST "/posts" --data "$BODY")
printf '%s\n' "$RESPONSE"

# --- Record ledger entry + post-create verification ---
if [ "${DRY_RUN}" != "1" ]; then
  POST_ID=$(printf '%s' "$RESPONSE" \
    | (command -v jq >/dev/null && jq -r '.id // .data.id // empty' || echo ""))

  if [ -n "$POST_ID" ] && [ "$IDEMPOTENCY" = "on" ]; then
    mkdir -p "$LEDGER_DIR"
    CONTENT_PREVIEW=$(printf '%s' "$CONTENT" | tr '\n\t' '  ' | cut -c1-60)
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(date +%s)" "$IDEMPOTENCY_KEY" "$POST_ID" "$SORTED_ACCOUNTS" "$CONTENT_PREVIEW" \
      >> "$LEDGER_FILE"
  fi

  # Post-verify: count recent posts with the same content snippet.
  sleep 1
  CONTENT_PREVIEW_JSON=$(printf '%s' "$CONTENT" | cut -c1-60 \
    | python3 -c "import sys,json;print(json.dumps(sys.stdin.read()))")
  RECENT=$(curl -sS -H "Authorization: Bearer ${OUTSTAND_API_KEY}" \
    "${OUTSTAND_BASE_URL}/${OUTSTAND_API_VERSION}/posts?limit=10" \
    | (command -v jq >/dev/null \
         && jq --argjson preview "$CONTENT_PREVIEW_JSON" \
              '[.data[]? // .[]? | select((.containers[0].content // "") | startswith($preview))] | length' \
         || echo "1") )
  if [ "${RECENT:-1}" -gt 1 ]; then
    echo "" >&2
    echo "⚠️  WARNING: ${RECENT} recent posts match this content preview — possible duplicate." >&2
    echo "   List with: list-posts.sh 10 | jq '.data[] | {id, content: .containers[0].content}'" >&2
    echo "   This usually means a prior call partially succeeded despite a client-side error." >&2
  fi
fi
