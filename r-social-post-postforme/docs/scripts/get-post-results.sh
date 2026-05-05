#!/usr/bin/env bash
# Fetch per-platform publish results (one per target account).
# Usage: ./get-post-results.sh [post_id] [--dry-run]
#
# If post_id is given, returns results filtered to that post (query param).
# If omitted, lists recent results (default limit 50).
#
# Bug fix (VAS-403, 2026-05-04): previously used path param /social-post-results/{id}
# which returns HTTP 500 on older posts (confirmed in auto-memory reference_postforme_url_recovery.md).
# Now uses the documented list endpoint with ?post_id= query filter instead.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key
filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
POST_ID="${ARGS[0]:-}"
if [ -n "$POST_ID" ]; then
  run_curl GET "/social-post-results?post_id=${POST_ID}"
else
  run_curl GET "/social-post-results"
fi
