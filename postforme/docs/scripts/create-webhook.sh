#!/usr/bin/env bash
# Register a webhook.
# Usage: ./create-webhook.sh <url> <event_types_csv> [--dry-run]
# Valid events: social.post.created, social.post.updated, social.post.deleted,
#               social.post.result.created, social.account.created, social.account.updated
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key

filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
URL="${ARGS[0]:?Usage: create-webhook.sh <url> <event_types_csv>}"
EVENTS_CSV="${ARGS[1]:?Provide comma-separated event types}"

EVENTS_JSON=$(printf '%s' "$EVENTS_CSV" | awk -F, '{
  printf "["
  for (i=1;i<=NF;i++){ printf "%s\"%s\"", (i>1?",":""), $i }
  printf "]"
}')

BODY=$(cat <<JSON
{
  "url": "${URL}",
  "event_types": ${EVENTS_JSON}
}
JSON
)

run_curl POST "/webhooks" --data "$BODY"
