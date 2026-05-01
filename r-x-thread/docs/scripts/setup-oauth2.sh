#!/usr/bin/env bash
# setup-oauth2.sh — One-time PKCE authorization flow for X API v2 (OAuth 2.0)
#
# Run this ONCE to get the user-context access_token + refresh_token for
# @MrGrowthGuide. Tokens are written back to posting-tools/.gsai/secret.
#
# Prerequisites:
#   1. X_CLIENT_ID and X_CLIENT_SECRET set in .gsai/secret (already done)
#   2. "https://127.0.0.1" added as a redirect URI in the X Developer Portal
#      (developer.x.com → your app → Auth settings → Redirect URIs)
#   3. App permissions set to "Read and Write" in the X Developer Portal
#
# Usage:
#   ./setup-oauth2.sh

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load credentials
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
}
_load_gsai_secret

: "${X_CLIENT_ID:?X_CLIENT_ID not set — check posting-tools/.gsai/secret}"
: "${X_CLIENT_SECRET:?X_CLIENT_SECRET not set}"

REDIRECT_URI="https://127.0.0.1"
SCOPE="tweet.read tweet.write users.read offline.access"

# --- Generate PKCE code_verifier + code_challenge ---
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-43)
CODE_CHALLENGE=$(printf '%s' "$CODE_VERIFIER" \
  | openssl dgst -sha256 -binary \
  | base64 \
  | tr '+/' '-_' \
  | tr -d '=')

STATE=$(openssl rand -hex 8)

ENCODED_REDIRECT=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REDIRECT_URI', safe=''))")
ENCODED_SCOPE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SCOPE', safe=''))")

AUTH_URL="https://twitter.com/i/oauth2/authorize?response_type=code&client_id=${X_CLIENT_ID}&redirect_uri=${ENCODED_REDIRECT}&scope=${ENCODED_SCOPE}&state=${STATE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  X OAuth 2.0 Setup — @MrGrowthGuide"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Step 1: Open this URL in your browser:"
echo ""
echo "  $AUTH_URL"
echo ""
echo "Step 2: Log in as @MrGrowthGuide and click Authorize."
echo ""
echo "Step 3: You'll be redirected to https://127.0.0.1 (it will fail to load — that's fine)."
echo "        Copy the FULL URL from the browser address bar and paste it below."
echo ""
printf "Paste the full redirect URL: "
read -r CALLBACK_URL

# Extract code from callback URL
AUTH_CODE=$(python3 -c "
import urllib.parse, sys
url = sys.argv[1]
qs = urllib.parse.urlparse(url).query
params = dict(urllib.parse.parse_qsl(qs))
print(params.get('code', ''))
" "$CALLBACK_URL")

if [ -z "$AUTH_CODE" ]; then
  echo "ERROR: Could not extract auth code from URL. Make sure you pasted the full redirect URL."
  exit 1
fi

echo ""
echo "Exchanging auth code for tokens..."

# Exchange code for access_token + refresh_token
TOKEN_RESPONSE=$(curl -sS -X POST "https://api.twitter.com/2/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${X_CLIENT_ID}:${X_CLIENT_SECRET}" \
  --data-urlencode "code=${AUTH_CODE}" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "client_id=${X_CLIENT_ID}" \
  --data-urlencode "redirect_uri=${REDIRECT_URI}" \
  --data-urlencode "code_verifier=${CODE_VERIFIER}")

ACCESS_TOKEN=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('access_token',''))" <<< "$TOKEN_RESPONSE")
REFRESH_TOKEN=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('refresh_token',''))" <<< "$TOKEN_RESPONSE")
EXPIRES_IN=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('expires_in','unknown'))" <<< "$TOKEN_RESPONSE")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Token exchange failed. Response:"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

# Find and update the secret file
SECRET_FILE=""
dir="$DIR"
while [ "$dir" != "/" ]; do
  if [ -f "$dir/.gsai/secret" ]; then
    SECRET_FILE="$dir/.gsai/secret"
    break
  fi
  dir="$(dirname "$dir")"
done

if [ -z "$SECRET_FILE" ]; then
  echo "ERROR: Could not find .gsai/secret file to update."
  exit 1
fi

# Update the tokens in-place using python3 (safe line replacement)
python3 - "$SECRET_FILE" "$ACCESS_TOKEN" "$REFRESH_TOKEN" <<'PYEOF'
import sys, re

secret_file = sys.argv[1]
access_token = sys.argv[2]
refresh_token = sys.argv[3]

with open(secret_file, 'r') as f:
    content = f.read()

content = re.sub(
    r'^export X_ACCESS_TOKEN=".*"',
    f'export X_ACCESS_TOKEN="{access_token}"',
    content, flags=re.MULTILINE
)
content = re.sub(
    r'^export X_REFRESH_TOKEN=".*"',
    f'export X_REFRESH_TOKEN="{refresh_token}"',
    content, flags=re.MULTILINE
)

with open(secret_file, 'w') as f:
    f.write(content)

print("Tokens written to secret file.")
PYEOF

echo ""
echo "✓ Setup complete."
echo "  Access token: ${ACCESS_TOKEN:0:12}... (expires in ${EXPIRES_IN}s / ~2h)"
echo "  Refresh token: ${REFRESH_TOKEN:0:12}... (valid ~6 months; auto-refreshed by post-thread.sh)"
echo ""
echo "You can now run:"
echo "  ./post-thread.sh \"Tweet 1\" \"Tweet 2\" \"Tweet 3\""
