#!/usr/bin/env bash
# List posts.
# Usage: ./list-posts.sh [limit] [--dry-run]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key
filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
LIMIT="${ARGS[0]:-25}"
run_curl GET "/posts?limit=${LIMIT}"
