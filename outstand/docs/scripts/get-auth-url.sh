#!/usr/bin/env bash
# Get OAuth authorization URL for a registered social network.
# Usage: ./get-auth-url.sh <social_network_id> [--dry-run]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key
filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
NETWORK_ID="${ARGS[0]:?Usage: get-auth-url.sh <social_network_id>}"
run_curl GET "/social-networks/${NETWORK_ID}/auth-url"
