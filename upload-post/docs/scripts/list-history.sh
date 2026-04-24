#!/usr/bin/env bash
# List upload history for a user profile
# Usage: ./list-history.sh <user> [page]
#
# Example:
#   ./list-history.sh mrgg
#   ./list-history.sh mrgg 2

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"

USER="${1:?Usage: list-history.sh <user> [page]}"
PAGE="${2:-1}"

curl -s -X GET "$BASE_URL/uploadposts/history?user=$USER&page=$PAGE" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" | jq .
