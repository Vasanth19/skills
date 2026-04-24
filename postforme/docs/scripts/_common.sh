#!/usr/bin/env bash
# Shared helpers for Post For Me scripts.
# Sourced by every other script in this folder.

set -euo pipefail

POSTFORME_BASE_URL="${POSTFORME_BASE_URL:-https://api.postforme.dev}"
POSTFORME_API_VERSION="v1"

# In dry-run mode ($DRY_RUN=1 or --dry-run flag), scripts print the curl they
# would run instead of executing it. Used by test.sh for offline validation.
DRY_RUN="${DRY_RUN:-0}"
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then DRY_RUN=1; fi
done

# Walk up from this file to find a `.gsai/secret` file and source it.
# Lets agents run scripts directly without pre-exporting keys, as long as
# the caller saved them to <posting-tools>/.gsai/secret.
_load_gsai_secret() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.gsai/secret" ]; then
      # shellcheck disable=SC1090
      source "$dir/.gsai/secret"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

require_key() {
  if [ "${DRY_RUN}" = "1" ]; then
    POSTFORME_API_KEY="${POSTFORME_API_KEY:-dry-run-key}"
  fi
  # Fall back to .gsai/secret if the env var isn't already set.
  if [ -z "${POSTFORME_API_KEY:-}" ]; then
    _load_gsai_secret || true
  fi
  : "${POSTFORME_API_KEY:?Set POSTFORME_API_KEY, add it to .gsai/secret, or pass --dry-run}"
}

# run_curl <method> <path> [curl args...]
# Prints the call in dry-run mode; otherwise executes and pipes through jq.
run_curl() {
  local method="$1"; shift
  local path="$1"; shift
  local url="${POSTFORME_BASE_URL}/${POSTFORME_API_VERSION}${path}"

  if [ "${DRY_RUN}" = "1" ]; then
    echo "[dry-run] curl -X ${method} ${url} $*" >&2
    echo "{\"dry_run\": true, \"method\": \"${method}\", \"url\": \"${url}\"}"
    return 0
  fi

  curl -sS -X "${method}" "${url}" \
    -H "Authorization: Bearer ${POSTFORME_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@" | (command -v jq >/dev/null && jq . || cat)
}

# Strip --dry-run from positional args so scripts see clean arguments.
# Populates the global array CLEAN_ARGS (bash 3.2+ compatible — no mapfile).
filter_args() {
  CLEAN_ARGS=()
  for a in "$@"; do
    [ "$a" = "--dry-run" ] || CLEAN_ARGS+=("$a")
  done
}
