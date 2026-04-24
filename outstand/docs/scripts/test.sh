#!/usr/bin/env bash
# Validate every Outstand script without hitting the network.
# Usage: ./test.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PASS=0
FAIL=0
RESULTS=()

check() {
  local name="$1"; shift
  local expect="$1"; shift
  local out
  if ! out=$("$@" 2>&1); then
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL  $name — script errored:\n$out")
    return
  fi
  if echo "$out" | grep -q "$expect"; then
    PASS=$((PASS+1))
    RESULTS+=("PASS  $name")
  else
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL  $name — expected '$expect' in output:\n$out")
  fi
}

check "list-accounts"     "GET https://api.outstand.so/v1/social-accounts"                   ./list-accounts.sh --dry-run
check "get-auth-url"      "GET https://api.outstand.so/v1/social-networks/net_123/auth-url"  ./get-auth-url.sh net_123 --dry-run
check "create-post"       "POST https://api.outstand.so/v1/posts"                            ./create-post.sh "hi" "acc_1,acc_2" --dry-run
check "create-post+media" "POST https://api.outstand.so/v1/posts"                            ./create-post.sh "hi" "acc_1" "med_9" --dry-run
check "create-post+sched" "POST https://api.outstand.so/v1/posts"                            ./create-post.sh "hi" "acc_1" "" "2026-12-31T10:00:00Z" --dry-run
check "list-posts"        "GET https://api.outstand.so/v1/posts?limit=25"                    ./list-posts.sh --dry-run
check "get-post"          "GET https://api.outstand.so/v1/posts/post_abc"                    ./get-post.sh post_abc --dry-run
check "get-post-analytics" "GET https://api.outstand.so/v1/posts/post_abc/analytics"         ./get-post-analytics.sh post_abc --dry-run
check "delete-post"       "DELETE https://api.outstand.so/v1/posts/post_abc"                 ./delete-post.sh post_abc --dry-run
check "upload-media"      "dry-run"                                                          ./upload-media.sh ./fake.jpg --dry-run
check "create-comment"    "POST https://api.outstand.so/v1/posts/post_abc/comments"          ./create-comment.sh post_abc "Nice post!" --dry-run
check "get-usage"         "GET https://api.outstand.so/v1/usage"                             ./get-usage.sh --dry-run

echo ""
printf '%s\n' "${RESULTS[@]}"
echo ""
echo "========================================"
echo "Outstand: $PASS passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -eq 0 ]
