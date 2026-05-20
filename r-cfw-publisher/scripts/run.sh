#!/usr/bin/env bash
# Process all due Posts for ONE brand. Stateless — caller supplies brand + key.
#
# Usage:
#   V2_API_BASE=... ENCRYPTION_KEY=... \
#     run.sh --brand-id <brandId> --api-key <V2_BRAND_API_KEY>
#
# Exit codes:
#   0 — success (zero-or-more posts processed; per-post failures recorded to V2)
#   1 — V2 unreachable (couldn't even list /posts/due)
#   2 — config / arg error
set -euo pipefail

BRAND_ID=""
API_KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --brand-id) BRAND_ID="$2"; shift 2;;
    --api-key)  API_KEY="$2"; shift 2;;
    -h|--help)
      sed -n '2,/^$/p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[[ -z "$BRAND_ID" ]]   && { echo "missing --brand-id" >&2; exit 2; }
[[ -z "$API_KEY" ]]    && { echo "missing --api-key"  >&2; exit 2; }
: "${V2_API_BASE:?V2_API_BASE env not set (e.g. http://host.docker.internal:3000/api/v1)}"
: "${ENCRYPTION_KEY:?ENCRYPTION_KEY env not set (64-char hex)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_AT="$(date -u +%FT%TZ)"

# Pull due list
DUE_JSON="$("$SCRIPT_DIR/list-due.sh" "$API_KEY" 2>&1)" || {
  echo "[run $BRAND_ID @ $START_AT] V2 unreachable: $DUE_JSON" >&2
  exit 1
}

POST_IDS="$(echo "$DUE_JSON" | jq -r '.posts[].id // empty')"
COUNT="$(echo "$POST_IDS" | grep -c . || true)"

if [[ "$COUNT" -eq 0 ]]; then
  echo "[run $BRAND_ID @ $START_AT] no due posts"
  exit 0
fi

echo "[run $BRAND_ID @ $START_AT] $COUNT due post(s)"

# Process each — failures DO NOT abort the loop
FAILED=0
echo "$POST_IDS" | while read -r POST_ID; do
  [[ -z "$POST_ID" ]] && continue
  if ! "$SCRIPT_DIR/publish-one.sh" --post-id "$POST_ID" --api-key "$API_KEY"; then
    FAILED=$((FAILED + 1))
    echo "[run $BRAND_ID] post $POST_ID failed (continuing)" >&2
  fi
done

echo "[run $BRAND_ID @ $START_AT] done"
exit 0
