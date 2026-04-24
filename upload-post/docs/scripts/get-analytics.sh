#!/usr/bin/env bash
# Get analytics for a user profile across platforms
# Usage: ./get-analytics.sh <username> [platforms]
#
# Example:
#   ./get-analytics.sh mrgg "instagram,tiktok,youtube"

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"

USERNAME="${1:?Usage: get-analytics.sh <username> [platforms]}"
PLATFORMS="${2:-instagram,tiktok,youtube,linkedin}"

curl -s -X GET "$BASE_URL/analytics/$USERNAME?platforms=$PLATFORMS" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" | jq .
