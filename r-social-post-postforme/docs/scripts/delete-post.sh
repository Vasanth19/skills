#!/usr/bin/env bash
# Delete (or cancel, if scheduled) a post.
# Usage: ./delete-post.sh <post_id> [--dry-run]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key
filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
POST_ID="${ARGS[0]:?Usage: delete-post.sh <post_id>}"
run_curl DELETE "/social-posts/${POST_ID}"
