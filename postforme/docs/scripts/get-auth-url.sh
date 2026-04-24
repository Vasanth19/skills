#!/usr/bin/env bash
# Get an OAuth authorization URL to connect a new social account.
# Usage: ./get-auth-url.sh <platform> [external_id] [redirect_url] [--dry-run]
#
# platform: tiktok | instagram | facebook | x | linkedin | youtube | pinterest | bluesky | threads
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key

filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
PLATFORM="${ARGS[0]:?Usage: get-auth-url.sh <platform> [external_id] [redirect_url]}"
EXTERNAL_ID="${ARGS[1]:-}"
REDIRECT_URL="${ARGS[2]:-}"

BODY=$(cat <<JSON
{
  "platform": "${PLATFORM}"$([ -n "$EXTERNAL_ID" ] && printf ',\n  "external_id": "%s"' "$EXTERNAL_ID")$([ -n "$REDIRECT_URL" ] && printf ',\n  "redirect_url_override": "%s"' "$REDIRECT_URL"),
  "permissions": ["posts", "feeds"]
}
JSON
)
# Remove dangling comma edge-cases
BODY=$(echo "$BODY" | sed 's/,\s*}/}/g')

run_curl POST "/social-accounts/auth-url" --data "$BODY"
