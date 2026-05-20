#!/usr/bin/env bash
# List Posts that are due for publishing for one brand.
# Usage:
#   V2_API_BASE=... list-due.sh <V2_BRAND_API_KEY>
# Prints the V2 response JSON ({"posts":[{id,brandId,compositionId,platform,scheduledAt}, ...]}).
set -euo pipefail

API_KEY="${1:?V2_BRAND_API_KEY required as first arg}"
: "${V2_API_BASE:?V2_API_BASE env not set (e.g. http://host.docker.internal:3000/api/v1)}"

curl -fsS \
  -H "x-api-key: $API_KEY" \
  -H "accept: application/json" \
  "$V2_API_BASE/posts/due"
