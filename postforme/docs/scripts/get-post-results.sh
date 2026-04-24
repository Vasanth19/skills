#!/usr/bin/env bash
# Fetch per-platform publish results (one per target account).
# Usage: ./get-post-results.sh [post_id] [--dry-run]
#
# If post_id is given, returns that result by ID.
# If omitted, lists recent results.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key
filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
POST_ID="${ARGS[0]:-}"
if [ -n "$POST_ID" ]; then
  run_curl GET "/social-post-results/${POST_ID}"
else
  run_curl GET "/social-post-results"
fi
