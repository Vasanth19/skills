#!/usr/bin/env bash
# List all user profiles (brands)
# Usage: ./list-users.sh

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"

curl -s -X GET "$BASE_URL/uploadposts/users" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" | jq .
