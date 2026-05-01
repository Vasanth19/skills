#!/usr/bin/env bash
# Generate a JWT connect URL for a user to link their social accounts
# Usage: ./connect-accounts.sh <username>
#
# Example:
#   ./connect-accounts.sh mrgg
#   # Opens a URL where the user can connect Instagram, TikTok, etc.

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"

USERNAME="${1:?Usage: connect-accounts.sh <username>}"

curl -s -X POST "$BASE_URL/uploadposts/users/generate-jwt" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\"}" | jq .
