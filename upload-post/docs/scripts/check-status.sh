#!/usr/bin/env bash
# Check the status of an upload request
# Usage: ./check-status.sh <request_id>
#
# Example:
#   ./check-status.sh 1a2b3c4d5e

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"

REQUEST_ID="${1:?Usage: check-status.sh <request_id>}"

curl -s -X GET "$BASE_URL/uploadposts/status/$REQUEST_ID" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" | jq .
