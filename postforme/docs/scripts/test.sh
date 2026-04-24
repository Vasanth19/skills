#!/usr/bin/env bash
# Validate every Post For Me script without hitting the network.
# Runs each script with --dry-run and confirms the expected URL/method.
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

# Every script should hit the correct URL / HTTP method in dry-run mode.
check "list-accounts"      "GET https://api.postforme.dev/v1/social-accounts"                       ./list-accounts.sh --dry-run
check "get-auth-url"       "POST https://api.postforme.dev/v1/social-accounts/auth-url"              ./get-auth-url.sh x user-123 --dry-run
check "create-post"        "POST https://api.postforme.dev/v1/social-posts"                          ./create-post.sh "hi" "spc_a,spc_b" --dry-run
check "create-post+media"  "POST https://api.postforme.dev/v1/social-posts"                          ./create-post.sh "hi" "spc_a" "https://x/y.jpg" --dry-run
check "create-post+sched"  "POST https://api.postforme.dev/v1/social-posts"                          ./create-post.sh "hi" "spc_a" "" "2026-12-31T10:00:00Z" --dry-run
check "list-posts"         "GET https://api.postforme.dev/v1/social-posts?limit=25"                  ./list-posts.sh --dry-run
check "get-post"           "GET https://api.postforme.dev/v1/social-posts/post_abc"                  ./get-post.sh post_abc --dry-run
check "delete-post"        "DELETE https://api.postforme.dev/v1/social-posts/post_abc"               ./delete-post.sh post_abc --dry-run
check "get-post-results"   "GET https://api.postforme.dev/v1/social-post-results"                    ./get-post-results.sh --dry-run
check "get-post-result/id" "GET https://api.postforme.dev/v1/social-post-results/res_1"              ./get-post-results.sh res_1 --dry-run
check "create-upload-url"  "POST https://api.postforme.dev/v1/media/create-upload-url"               ./create-upload-url.sh --dry-run
check "upload-media"       "dry-run"                                                                 ./upload-media.sh ./fake.jpg --dry-run
check "create-webhook"     "POST https://api.postforme.dev/v1/webhooks"                              ./create-webhook.sh https://example.com/hook "social.post.created,social.post.updated" --dry-run

echo ""
printf '%s\n' "${RESULTS[@]}"
echo ""
echo "========================================"
echo "Post For Me: $PASS passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -eq 0 ]
