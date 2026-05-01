#!/usr/bin/env bash
# post-thread.sh — Post a Twitter/X thread via X API v2, OAuth 1.0a.
#
# Mirrors the MGG n8n workflow: tweet 1 posts top-level, each subsequent tweet
# posts as in_reply_to the previous tweet's id — forming a proper thread chain.
#
# Usage:
#   ./post-thread.sh "Tweet 1" "Tweet 2" "Tweet 3"
#   ./post-thread.sh --file tweets.json        # JSON array of strings
#   ./post-thread.sh --file tweets.txt         # one tweet per line
#   ./post-thread.sh --reply-to-id <id> "T2"  # resume a partial thread
#   ./post-thread.sh --dry-run "Tweet 1" "Tweet 2"
#
# Auth (set in env or posting-tools/.gsai/secret):
#   X_API_KEY             Consumer Key
#   X_API_SECRET          Consumer Secret
#   X_ACCESS_TOKEN        Access Token (for @MrGrowthGuide)
#   X_ACCESS_TOKEN_SECRET Access Token Secret
#
# Optional env:
#   TWEET_DELAY   Seconds between tweets (default: 2; mirrors n8n Wait node)
#   IDEMPOTENCY   Set to "off" to skip duplicate check (default: on)

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
X_API_URL="https://api.twitter.com/2/tweets"
LEDGER_DIR="${HOME}/.posting-tools-ledger"
THREAD_LEDGER="${LEDGER_DIR}/x-thread.tsv"
TWEET_DELAY="${TWEET_DELAY:-2}"
IDEMPOTENCY="${IDEMPOTENCY:-on}"
DRY_RUN=0

# --- Load auth from .gsai/secret ---
_load_gsai_secret() {
  local dir="$DIR"
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

# --- OAuth 2.0 token refresh ---
_refresh_oauth2_token() {
  local response access_token
  response=$(curl -sS -X POST "https://api.twitter.com/2/oauth2/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "${X_CLIENT_ID}:${X_CLIENT_SECRET}" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "refresh_token=${X_OAUTH2_REFRESH_TOKEN}")

  access_token=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('access_token',''))" <<< "$response")
  local new_refresh
  new_refresh=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('refresh_token',''))" <<< "$response")

  if [ -z "$access_token" ]; then
    echo "ERROR: Token refresh failed: $response" >&2
    return 1
  fi

  X_OAUTH2_ACCESS_TOKEN="$access_token"
  [ -n "$new_refresh" ] && X_OAUTH2_REFRESH_TOKEN="$new_refresh"

  # Persist refreshed tokens to secret file
  local secret_file=""
  local dir="$DIR"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.gsai/secret" ]; then secret_file="$dir/.gsai/secret"; break; fi
    dir="$(dirname "$dir")"
  done
  if [ -n "$secret_file" ]; then
    python3 - "$secret_file" "$access_token" "$X_OAUTH2_REFRESH_TOKEN" <<'PYEOF'
import sys, re
f, at, rt = sys.argv[1:]
content = open(f).read()
content = re.sub(r'^export X_OAUTH2_ACCESS_TOKEN=".*"', f'export X_OAUTH2_ACCESS_TOKEN="{at}"', content, flags=re.MULTILINE)
content = re.sub(r'^export X_OAUTH2_REFRESH_TOKEN=".*"', f'export X_OAUTH2_REFRESH_TOKEN="{rt}"', content, flags=re.MULTILINE)
open(f, 'w').write(content)
PYEOF
    echo "[oauth2] Tokens refreshed and persisted." >&2
  fi
}

# --- Post a single tweet ---
_post_tweet() {
  local text="$1" reply_to="${2:-}"

  local body
  if [ -n "$reply_to" ]; then
    body=$(python3 -c "
import json, sys
print(json.dumps({'text': sys.argv[1], 'reply': {'in_reply_to_tweet_id': sys.argv[2]}}))
" "$text" "$reply_to")
  else
    body=$(python3 -c "import json, sys; print(json.dumps({'text': sys.argv[1]}))" "$text")
  fi

  if [ "$DRY_RUN" = "1" ]; then
    local fake_id="dry-$(date +%s)${RANDOM}"
    echo "[dry-run] POST $X_API_URL" >&2
    echo "[dry-run] body: $body" >&2
    [ -n "$reply_to" ] && echo "[dry-run] in_reply_to: $reply_to" >&2
    python3 -c "
import json, sys
print(json.dumps({'data': {'id': sys.argv[1], 'text': sys.argv[2]}}))
" "$fake_id" "$text"
    return 0
  fi

  # OAuth 2.0 Bearer token (user-context) — auto-refresh on 401
  local response http_code
  _do_post() {
    curl -sS -w "\n__HTTP_CODE__%{http_code}" \
      -X POST "$X_API_URL" \
      -H "Authorization: Bearer ${X_OAUTH2_ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$body"
  }

  response=$(_do_post)
  http_code=$(printf '%s' "$response" | grep -o '__HTTP_CODE__[0-9]*' | sed 's/__HTTP_CODE__//')
  response=$(printf '%s' "$response" | sed 's/__HTTP_CODE__[0-9]*$//' | sed '/^[[:space:]]*$/d')

  # Auto-refresh on 401 (expired access token)
  if [ "$http_code" = "401" ]; then
    echo "[oauth2] Access token expired — refreshing..." >&2
    _refresh_oauth2_token
    response=$(_do_post)
    http_code=$(printf '%s' "$response" | grep -o '__HTTP_CODE__[0-9]*' | sed 's/__HTTP_CODE__//')
    response=$(printf '%s' "$response" | sed 's/__HTTP_CODE__[0-9]*$//' | sed '/^[[:space:]]*$/d')
  fi

  if [ -z "$http_code" ] || [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    echo "ERROR: X API returned HTTP ${http_code:-unknown}" >&2
    echo "$response" >&2
    exit 1
  fi

  printf '%s' "$response"
}

# --- Argument parsing ---
TWEETS=()
FILE=""
RESUME_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)      DRY_RUN=1; shift ;;
    --file)         FILE="${2:?--file requires a path}"; shift 2 ;;
    --reply-to-id)  RESUME_ID="${2:?--reply-to-id requires a tweet id}"; shift 2 ;;
    *)              TWEETS+=("$1"); shift ;;
  esac
done

# Load tweets from file
if [ -n "$FILE" ]; then
  if [[ "$FILE" == *.json ]]; then
    mapfile -t FILE_TWEETS < <(python3 -c "
import json, sys
tweets = json.load(open(sys.argv[1]))
for t in tweets:
    print(t if isinstance(t, str) else t.get('text', str(t)))
" "$FILE")
  else
    mapfile -t FILE_TWEETS < <(grep -v '^[[:space:]]*$' "$FILE")
  fi
  TWEETS=("${FILE_TWEETS[@]+"${FILE_TWEETS[@]}"}" "${TWEETS[@]+"${TWEETS[@]}"}")
fi

if [ "${#TWEETS[@]}" -eq 0 ]; then
  echo "Usage: $0 \"Tweet 1\" \"Tweet 2\" ... [--dry-run]" >&2
  echo "       $0 --file tweets.json [--dry-run]" >&2
  echo "       $0 --reply-to-id <id> \"Tweet 2\" \"Tweet 3\"  # resume partial thread" >&2
  exit 1
fi

# --- Auth ---
if [ -z "${X_OAUTH2_ACCESS_TOKEN:-}" ]; then _load_gsai_secret || true; fi
if [ "$DRY_RUN" != "1" ]; then
  : "${X_OAUTH2_ACCESS_TOKEN:?Set X_OAUTH2_ACCESS_TOKEN in env or posting-tools/.gsai/secret}"
  : "${X_OAUTH2_REFRESH_TOKEN:?Set X_OAUTH2_REFRESH_TOKEN in env or posting-tools/.gsai/secret}"
  : "${X_CLIENT_ID:?Set X_CLIENT_ID in env or posting-tools/.gsai/secret}"
  : "${X_CLIENT_SECRET:?Set X_CLIENT_SECRET in env or posting-tools/.gsai/secret}"
fi

# --- Duplicate check ---
mkdir -p "$LEDGER_DIR"
touch "$THREAD_LEDGER"

THREAD_HASH=$(printf '%s' "${TWEETS[*]}" | shasum -a 256 | cut -c1-16)

if [ "$IDEMPOTENCY" = "on" ] && [ "$DRY_RUN" != "1" ]; then
  NOW=$(date +%s)
  CUTOFF=$((NOW - 86400))
  EXISTING=$(awk -F'\t' -v h="$THREAD_HASH" -v cutoff="$CUTOFF" \
    '$1 >= cutoff && $2 == h { print $3; exit }' "$THREAD_LEDGER" 2>/dev/null || true)
  if [ -n "$EXISTING" ]; then
    echo "Thread already posted within 24h (root id: $EXISTING). Use IDEMPOTENCY=off to force." >&2
    echo "{\"deduped\": true, \"thread_root_id\": \"$EXISTING\", \"source\": \"thread_ledger\"}"
    exit 0
  fi
fi

# --- Post the thread ---
LAST_ID="${RESUME_ID:-}"
RESULTS=()
THREAD_ROOT_ID=""
TOTAL="${#TWEETS[@]}"

echo "Posting $TOTAL-tweet thread to @MrGrowthGuide..." >&2

for tweet in "${TWEETS[@]}"; do
  [ -z "$tweet" ] && continue

  INDEX=$((${#RESULTS[@]} + 1))
  echo "  [$INDEX/$TOTAL] $(printf '%s' "$tweet" | cut -c1-60)..." >&2

  RESPONSE=$(_post_tweet "$tweet" "$LAST_ID")

  TWEET_ID=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" <<< "$RESPONSE")

  if [ -z "$TWEET_ID" ]; then
    echo "ERROR: Could not extract tweet id. Response:" >&2
    echo "$RESPONSE" >&2
    [ -n "$THREAD_ROOT_ID" ] && echo "Resume: $0 --reply-to-id $LAST_ID \"<next tweet>\"..." >&2
    exit 1
  fi

  LAST_ID="$TWEET_ID"
  RESULTS+=("$RESPONSE")
  [ -z "$THREAD_ROOT_ID" ] && THREAD_ROOT_ID="$TWEET_ID"

  # Delay between tweets (mirrors n8n Wait node)
  [ "$INDEX" -lt "$TOTAL" ] && sleep "$TWEET_DELAY"
done

echo "  Done. Thread root: https://x.com/MrGrowthGuide/status/$THREAD_ROOT_ID" >&2

# --- Write to ledger ---
if [ "$IDEMPOTENCY" = "on" ] && [ "$DRY_RUN" != "1" ] && [ -n "$THREAD_ROOT_ID" ]; then
  printf '%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$THREAD_HASH" "$THREAD_ROOT_ID" "${TWEETS[0]:0:80}" \
    >> "$THREAD_LEDGER"
fi

# --- Output ---
python3 -c "
import json, sys
results = [json.loads(r) for r in sys.argv[1:]]
print(json.dumps({
    'thread_root_id': results[0]['data']['id'],
    'thread_url': 'https://x.com/MrGrowthGuide/status/' + results[0]['data']['id'],
    'tweet_count': len(results),
    'tweets': results
}, indent=2))
" "${RESULTS[@]}"
