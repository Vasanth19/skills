#!/usr/bin/env bash
# Validate every Upload Post script without hitting the network.
# Uses a PATH-shimmed fake `curl` that records the URL/method to a log file
# instead of making a real HTTP call.
# Usage: ./test.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fake curl: records its args and prints a stub JSON response.
cat > "$TMP/curl" <<'SHIM'
#!/usr/bin/env bash
# Record every arg, newline-separated, to $CURL_LOG.
: > "$CURL_LOG"
for a in "$@"; do
  printf '%s\n' "$a" >> "$CURL_LOG"
done
# Emit a plausible JSON response so `jq .` downstream doesn't fail.
echo '{"status":"ok","mocked":true}'
SHIM
chmod +x "$TMP/curl"

export PATH="$TMP:$PATH"
export CURL_LOG="$TMP/last.log"
export UPLOAD_POST_API_KEY="test-key"

PASS=0
FAIL=0
RESULTS=()

# check <name> <url_substring> <method> -- <script> [args...]
check() {
  local name="$1"; shift
  local url_substr="$1"; shift
  local method="$1"; shift
  local sep="$1"; shift
  [ "$sep" = "--" ] || { echo "bad check call"; exit 2; }

  local out
  if ! out=$("$@" 2>&1); then
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL  $name — script errored:\n$out")
    return
  fi

  local log; log=$(cat "$CURL_LOG" 2>/dev/null || echo "")
  local url_ok=0 method_ok=0
  if echo "$log" | grep -Fq "$url_substr"; then url_ok=1; fi
  # The method follows `-X` in the log.
  if grep -A1 '^-X$' "$CURL_LOG" 2>/dev/null | grep -Fxq "$method"; then method_ok=1; fi

  if [ "$url_ok" = "1" ] && [ "$method_ok" = "1" ]; then
    PASS=$((PASS+1))
    RESULTS+=("PASS  $name")
  else
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL  $name — url_ok=$url_ok method_ok=$method_ok\nlog:\n$log")
  fi
}

check "list-users"       "https://api.upload-post.com/api/uploadposts/users" GET  -- ./list-users.sh
check "create-user"      "https://api.upload-post.com/api/uploadposts/users" POST -- ./create-user.sh brand-test
check "connect-accounts" "https://api.upload-post.com/api/uploadposts/users/generate-jwt" POST -- ./connect-accounts.sh brand-test
check "check-status"     "https://api.upload-post.com/api/uploadposts/status/req_123" GET -- ./check-status.sh req_123
check "list-history"     "https://api.upload-post.com/api/uploadposts/history?user=brand-test" GET -- ./list-history.sh brand-test
check "get-analytics"    "https://api.upload-post.com/api/analytics/brand-test" GET -- ./get-analytics.sh brand-test
check "upload-video/url" "https://api.upload-post.com/api/upload" POST -- ./upload-video.sh https://example.com/v.mp4 brand-test tiktok "title"
check "upload-photo/url" "https://api.upload-post.com/api/upload_photos" POST -- ./upload-photo.sh https://example.com/p.jpg brand-test instagram "caption"

echo ""
printf '%s\n' "${RESULTS[@]}"
echo ""
echo "========================================"
echo "Upload Post: $PASS passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -eq 0 ]
