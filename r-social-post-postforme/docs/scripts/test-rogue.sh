#!/usr/bin/env bash
# VAS-33 Track A regression: the Apr 22 rogue-agent failure mode.
#
# Scenario:
#   Agent A scheduled post for content X to accounts {a,b,c,d,e} with caption "C1".
#   Agent B (rogue) arrives and publishes content X with caption "C2", re-uploaded
#   MEDIA_URL, and account split {a,b,c,d} + {e}. Every input differs EXCEPT the
#   underlying video bytes.
#
#   - Layer 4 (input-hash ledger) MUST NOT catch this (different inputs).
#   - Layer 1 (publish-intent ledger) SHOULD catch it when the BRAND:SOURCE_ISSUE
#     pair is the same (agents fighting over the same reel).
#   - Layer 2 (content-fingerprint ledger) SHOULD catch it independently (same
#     CONTENT_HASH + overlapping accounts).
#
# Strategy: shadow `curl` so we never hit the network; sequence two create-post
# calls with the same CONTENT_HASH but different captions / media_urls / accounts;
# assert call 2 short-circuits via the new dedup layers.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP=$(mktemp -d 2>/dev/null || mktemp -d -t 'postforme-rogue')
SHIM_DIR="$TMP/shim"
LEDGER_DIR="$TMP/ledger"
mkdir -p "$SHIM_DIR" "$LEDGER_DIR"

CALL_LOG="$TMP/curl.log"
: > "$CALL_LOG"

cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
METHOD="GET"
URL=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X) METHOD="$2"; shift 2 ;;
    -H) shift 2 ;;
    --data) shift 2 ;;
    -sS|-s|-S) shift ;;
    -*) shift ;;
    *) if [ -z "$URL" ]; then URL="$1"; fi; shift ;;
  esac
done
printf '%s %s\n' "$METHOD" "$URL" >> "$CURL_LOG"
case "$METHOD $URL" in
  "POST "*"/social-posts")
    printf '{"id":"post_%s","external_id":"mggpub-dummy"}\n' "$$"
    ;;
  "GET "*"/social-posts"*)
    printf '{"data":[]}\n'
    ;;
  *) printf '{}\n' ;;
esac
SHIM
chmod +x "$SHIM_DIR/curl"

if ! command -v jq >/dev/null; then
  cat > "$SHIM_DIR/jq" <<'JQ'
#!/usr/bin/env bash
cat
JQ
  chmod +x "$SHIM_DIR/jq"
fi

export HOME="$TMP"
export PATH="$SHIM_DIR:$PATH"
export POSTFORME_API_KEY="test-key"
export CURL_LOG="$CALL_LOG"
export BRAND="mr-growth-guide"

# --- Call 1: Agent A schedules the legitimate publish (VAS-46) ---
SOURCE_ISSUE="VAS-46" \
  CONTENT_HASH="a1b2c3d4e5f60718293a4b5c6d7e8f901234567890abcdef1234567890abcdef" \
  "$DIR/create-post.sh" \
    "Day 1 of 100 — text-forward caption #AITools" \
    "spc_a,spc_b,spc_c,spc_d,spc_e" \
    "https://cdn.postforme.dev/media/A1.mp4" \
    >/dev/null 2>&1
CALL1_POSTS=$(grep -c "^POST .*/social-posts$" "$CALL_LOG" || true)

# --- Call 2: Rogue Agent B — same CONTENT_HASH + overlapping accounts, but
#     DIFFERENT SOURCE_ISSUE so intent_key differs. Must be caught by the
#     content-fingerprint layer (Layer 2) in isolation. ---
RC=0
SOURCE_ISSUE="VAS-XXX-different-issue" \
  CONTENT_HASH="a1b2c3d4e5f60718293a4b5c6d7e8f901234567890abcdef1234567890abcdef" \
  "$DIR/create-post.sh" \
    "5 tools. 48 hours. 1 AI business. 🚀" \
    "spc_a,spc_b,spc_c,spc_d" \
    "https://cdn.postforme.dev/media/B2-reupload.mp4" \
    >"$TMP/call2.out" 2>"$TMP/call2.err" || RC=$?
CALL2_POSTS=$(grep -c "^POST .*/social-posts$" "$CALL_LOG" || true)

# --- Call 3: Rogue Agent C — DISJOINT ACCOUNTS, same BRAND:ISSUE:CONTENT_HASH.
#     Content-fingerprint will NOT fire (no account overlap).
#     Publish-intent MUST fire (same intent_key). ---
SOURCE_ISSUE="VAS-46" \
  CONTENT_HASH="a1b2c3d4e5f60718293a4b5c6d7e8f901234567890abcdef1234567890abcdef" \
  "$DIR/create-post.sh" \
    "some other caption" \
    "spc_w,spc_x,spc_y,spc_z" \
    "https://cdn.postforme.dev/media/C3-disjoint.mp4" \
    >/dev/null 2>"$TMP/call3.err" || true
CALL3_POSTS=$(grep -c "^POST .*/social-posts$" "$CALL_LOG" || true)

# --- Call 4: Agent D — DIFFERENT content AND different issue. MUST proceed. ---
CONTENT_HASH="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" \
  SOURCE_ISSUE="VAS-50" \
  "$DIR/create-post.sh" \
    "unrelated post" \
    "spc_a,spc_b" \
    "https://cdn.postforme.dev/media/C4.mp4" \
    >/dev/null 2>"$TMP/call4.err" || true
CALL4_POSTS=$(grep -c "^POST .*/social-posts$" "$CALL_LOG" || true)

echo "---"
echo "POST calls after call 1:  $CALL1_POSTS (expected 1)"
echo "POST calls after call 2:  $CALL2_POSTS (expected 1 — content-fingerprint blocks, same accounts)"
echo "POST calls after call 3:  $CALL3_POSTS (expected 1 — publish-intent blocks, disjoint accounts)"
echo "POST calls after call 4:  $CALL4_POSTS (expected 2 — legitimately different content+issue)"
echo "call 2 stderr (first 3):"
sed 's/^/   | /' "$TMP/call2.err" | head -3
echo "call 3 stderr (first 3):"
sed 's/^/   | /' "$TMP/call3.err" | head -3
echo ""

rc=0
if [ "$CALL1_POSTS" -ne 1 ]; then
  echo "FAIL: call 1 should have made 1 POST, got $CALL1_POSTS" >&2
  rc=1
fi
if [ "$CALL2_POSTS" -ne 1 ]; then
  echo "FAIL: call 2 (same-accounts rogue) should have been blocked — expected POSTs to stay at 1, got $CALL2_POSTS" >&2
  rc=1
fi
if [ "$CALL3_POSTS" -ne 1 ]; then
  echo "FAIL: call 3 (disjoint-accounts rogue) should have been blocked by intent-ledger — expected POSTs to stay at 1, got $CALL3_POSTS" >&2
  rc=1
fi
if [ "$CALL4_POSTS" -ne 2 ]; then
  echo "FAIL: call 4 (different content) should have proceeded — expected 2 POSTs, got $CALL4_POSTS" >&2
  rc=1
fi
if ! grep -q 'content_fingerprint' "$TMP/call2.err"; then
  echo "FAIL: call 2 did not cite content_fingerprint in stderr" >&2
  rc=1
fi
if ! grep -q 'intent_collision' "$TMP/call3.err"; then
  echo "FAIL: call 3 did not cite intent_collision in stderr" >&2
  rc=1
fi

if [ "$rc" -eq 0 ]; then
  echo "PASS: VAS-33 Track A — content-fingerprint AND publish-intent both catch caption-drift duplicates."
  rm -rf "$TMP"
fi
exit "$rc"
