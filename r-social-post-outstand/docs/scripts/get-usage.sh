#!/usr/bin/env bash
# Fetch current billing usage.
# Usage: ./get-usage.sh [--dry-run]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
require_key
run_curl GET "/usage"
