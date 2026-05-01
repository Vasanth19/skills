#!/usr/bin/env bash
# Publish a first comment on a post.
# Usage: ./create-comment.sh <post_id> <content> [--dry-run]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key

filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
POST_ID="${ARGS[0]:?Usage: create-comment.sh <post_id> <content>}"
CONTENT="${ARGS[1]:?Provide comment content}"

CONTENT_JSON=$(printf '%s' "$CONTENT" | python3 -c "import sys,json;print(json.dumps(sys.stdin.read()))")
BODY="{\"content\":${CONTENT_JSON}}"

run_curl POST "/posts/${POST_ID}/comments" --data "$BODY"
