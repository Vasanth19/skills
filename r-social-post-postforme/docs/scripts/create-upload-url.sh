#!/usr/bin/env bash
# Request a signed upload URL for media.
# Usage: ./create-upload-url.sh [--dry-run]
# Returns { media_url, upload_url }. PUT your file to upload_url, then use media_url in posts.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key
run_curl POST "/media/create-upload-url" --data '{}'
