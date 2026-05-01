#!/usr/bin/env bash
# Create a new user profile (brand)
# Usage: ./create-user.sh <username>
#
# Example:
#   ./create-user.sh my-new-brand

set -euo pipefail

# Auto-load .gsai/secret if key not already exported.
source "$(dirname "${BASH_SOURCE[0]}")/_load-secret.sh"

UPLOAD_POST_API_KEY="${UPLOAD_POST_API_KEY:?Set UPLOAD_POST_API_KEY or add to .gsai/secret}"
BASE_URL="https://api.upload-post.com/api"

USERNAME="${1:?Usage: create-user.sh <username>}"

curl -s -X POST "$BASE_URL/uploadposts/users" \
  -H "Authorization: Apikey $UPLOAD_POST_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\"}" | jq .
