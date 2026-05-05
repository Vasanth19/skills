#!/usr/bin/env bash
# List posts.
# Usage: ./list-posts.sh [limit] [--all] [--offset N] [--dry-run]
#   --all       Follow meta.next until exhausted; outputs all posts as a single
#               JSON object {"data":[...], "meta":{...}}. Ignores --offset.
#   --offset N  Skip N posts before the first returned (default 0).
#               Use with limit to manually page: e.g., ./list-posts.sh 25 --offset 25
#   limit       Max posts per page (default 25, API default 50).
#
# Pagination fix (VAS-403, 2026-05-04):
#   Previous version fetched only one page — posts beyond LIMIT were invisible.
#   --all follows meta.next until null, merging all data arrays into one response.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key

# --- Parse flags before filter_args so --all/--offset don't collide with positionals ---
FETCH_ALL=0
OFFSET=0
_PASSTHROUGH=()
_i=0
_ARGV=("$@")
while [ $_i -lt ${#_ARGV[@]} ]; do
  case "${_ARGV[$_i]}" in
    --all)    FETCH_ALL=1 ;;
    --offset) _i=$((_i + 1)); OFFSET="${_ARGV[$_i]:-0}" ;;
    *)        _PASSTHROUGH+=("${_ARGV[$_i]}") ;;
  esac
  _i=$((_i + 1))
done

filter_args "${_PASSTHROUGH[@]+"${_PASSTHROUGH[@]}"}"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
LIMIT="${ARGS[0]:-25}"

if [ "$FETCH_ALL" = "1" ] && [ "${DRY_RUN}" != "1" ]; then
  # Paginate all pages; accumulate data array; emit combined response at the end.
  ALL_DATA="[]"
  CUR_OFFSET=0
  META_TOTAL=0
  while true; do
    PAGE=$(curl -sS \
      -H "Authorization: Bearer ${POSTFORME_API_KEY}" \
      -H "Content-Type: application/json" \
      "${POSTFORME_BASE_URL}/${POSTFORME_API_VERSION}/social-posts?limit=${LIMIT}&offset=${CUR_OFFSET}")
    PAGE_COUNT=$(printf '%s' "$PAGE" | (command -v jq >/dev/null && jq '.data | length' || echo "0"))
    META_TOTAL=$(printf '%s' "$PAGE" | (command -v jq >/dev/null && jq '.meta.total // 0' || echo "0"))
    META_NEXT=$(printf '%s' "$PAGE" | (command -v jq >/dev/null && jq -r '.meta.next // ""' || echo ""))
    # Merge current page into accumulated array
    ALL_DATA=$(printf '%s' "$PAGE" | (command -v jq >/dev/null \
      && jq --argjson acc "$ALL_DATA" '$acc + .data' \
      || echo "$ALL_DATA"))
    CUR_OFFSET=$((CUR_OFFSET + LIMIT))
    # Stop when meta.next is null/empty or page returned fewer items than limit
    [ -z "$META_NEXT" ] || [ "${PAGE_COUNT:-0}" -lt "$LIMIT" ] && break
  done
  printf '%s' "$ALL_DATA" | (command -v jq >/dev/null \
    && jq --argjson total "$META_TOTAL" --argjson fetched "${CUR_OFFSET}" \
       '{"data": ., "meta": {"total": $total, "offset": 0, "limit": $fetched, "next": null}}' \
    || cat)
elif [ "$FETCH_ALL" = "1" ] && [ "${DRY_RUN}" = "1" ]; then
  echo "[dry-run] Would paginate all pages: GET /social-posts?limit=${LIMIT}&offset=0 → follow meta.next until null" >&2
  echo '{"dry_run": true, "mode": "all_pages"}'
else
  run_curl GET "/social-posts?limit=${LIMIT}&offset=${OFFSET}"
fi
