#!/usr/bin/env bash
# VAS-33 regression: concurrent create-post.sh calls with identical inputs must
# produce exactly ONE POST /social-posts API call and exactly ONE ledger entry.
#
# Strategy: shadow `curl` with a script that logs every call, run N create-post.sh
# calls in parallel with IDEMPOTENCY=on, then count POST /social-posts hits.
# Before the fix all N calls hit POST (duplicate creates); after the fix only 1
# does and the rest short-circuit via the local ledger.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP=$(mktemp -d 2>/dev/null || mktemp -d -t 'postforme-race')
SHIM_DIR="$TMP/shim"
LEDGER_DIR="$TMP/ledger"
mkdir -p "$SHIM_DIR" "$LEDGER_DIR"

CALL_LOG="$TMP/curl.log"
: > "$CALL_LOG"

# --- Shim curl: simulate a slow POST /social-posts so parallel invocations
# genuinely race inside the critical section. Fabricate a distinct post id per
# request and log every call (method + url).
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
    # Intentionally slow so concurrent callers overlap.
    sleep 0.5
    # Emit a unique id per request so duplicate posts are detectable.
    printf '{"id":"post_%s","external_id":"mggpub-dummy"}\n' "$$"
    ;;
  "GET "*"/social-posts"*)
    # Pretend no existing posts for the pre-check layer 2.
    printf '{"data":[]}\n'
    ;;
  *) printf '{}\n' ;;
esac
SHIM
chmod +x "$SHIM_DIR/curl"

# --- Stub jq if missing so the script path that calls jq still works.
if ! command -v jq >/dev/null; then
  cat > "$SHIM_DIR/jq" <<'JQ'
#!/usr/bin/env bash
# Minimal no-op: emit the first field that looks like an id from stdin.
cat
JQ
  chmod +x "$SHIM_DIR/jq"
fi

# --- Run N concurrent create-post.sh with a shared LEDGER_DIR (via HOME override).
N="${N:-6}"
export HOME="$TMP"            # redirects LEDGER_DIR to $TMP/.posting-tools-ledger
export PATH="$SHIM_DIR:$PATH" # curl shim takes precedence
export POSTFORME_API_KEY="test-key"
export CURL_LOG="$CALL_LOG"

PIDS=()
for i in $(seq 1 "$N"); do
  ( "$DIR/create-post.sh" "race caption" "spc_a,spc_b" >/dev/null 2>&1 ) &
  PIDS+=("$!")
done
WAIT_FAILED=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || WAIT_FAILED=$((WAIT_FAILED+1))
done

POST_COUNT=$(grep -c "^POST .*/social-posts$" "$CALL_LOG" || true)
LEDGER_FILE="$HOME/.posting-tools-ledger/postforme.tsv"
LEDGER_ROWS=0
if [ -f "$LEDGER_FILE" ]; then
  LEDGER_ROWS=$(wc -l < "$LEDGER_FILE" | tr -d ' ')
fi

echo "---"
echo "concurrent invocations: $N"
echo "POST /social-posts calls:  $POST_COUNT  (expected 1)"
echo "ledger rows written:       $LEDGER_ROWS (expected 1)"
echo "failed waits:              $WAIT_FAILED"
echo "tmp:                       $TMP"

rc=0
if [ "$POST_COUNT" -ne 1 ]; then
  echo "FAIL: expected exactly 1 POST /social-posts, got $POST_COUNT" >&2
  rc=1
fi
if [ "$LEDGER_ROWS" -ne 1 ]; then
  echo "FAIL: expected exactly 1 ledger row, got $LEDGER_ROWS" >&2
  rc=1
fi

if [ "$rc" -eq 0 ]; then
  echo "PASS: VAS-33 concurrent-create guard holds."
  rm -rf "$TMP"
fi
exit "$rc"
