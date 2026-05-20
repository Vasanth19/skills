#!/usr/bin/env bash
# Publish ONE Post end-to-end:
#   1. Claim it    (PATCH /publish-result {status:publishing, publishAttempts:true})
#   2. Pull bundle (GET  /publish-bundle  → caption, mediaUrls, platformConnection.{provider,externalAccountId,accessTokenEnc})
#   3. Decrypt accessTokenEnc using ENCRYPTION_KEY
#   4. Route to provider skill, capture platformPostId
#   5. PATCH /publish-result {status:published, platformPostId}
#
# On any step failure: PATCH {status:failed, failureReason} and exit 1
# (the loop in run.sh continues on to the next post).
#
# Usage:
#   V2_API_BASE=... ENCRYPTION_KEY=... publish-one.sh --post-id <id> --api-key <key>

set -euo pipefail

POST_ID=""
API_KEY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --post-id) POST_ID="$2"; shift 2;;
    --api-key) API_KEY="$2"; shift 2;;
    -h|--help)
      sed -n '2,/^$/p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[[ -z "$POST_ID" ]]    && { echo "missing --post-id" >&2; exit 2; }
[[ -z "$API_KEY" ]]    && { echo "missing --api-key" >&2; exit 2; }
: "${V2_API_BASE:?V2_API_BASE env not set}"
: "${ENCRYPTION_KEY:?ENCRYPTION_KEY env not set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_HOME="${SKILLS_HOME:-$HOME/.claude/skills}"

V2_HDR=(-H "x-api-key: $API_KEY" -H "content-type: application/json" -H "accept: application/json")
PR_URL="$V2_API_BASE/posts/$POST_ID/publish-result"
BUNDLE_URL="$V2_API_BASE/posts/$POST_ID/publish-bundle"

# Helper — record failure and exit 1
fail() {
  local reason="$1"
  echo "[publish-one $POST_ID] FAIL: $reason" >&2
  curl -fsS -X PATCH "${V2_HDR[@]}" "$PR_URL" \
    -d "$(jq -nc --arg r "$reason" '{status:"failed", failureReason:$r}')" \
    >/dev/null || true
  exit 1
}

# 1. Claim — transition scheduled → publishing
echo "[publish-one $POST_ID] claim"
if ! curl -fsS -X PATCH "${V2_HDR[@]}" "$PR_URL" \
       -d '{"status":"publishing","publishAttempts":true}' >/dev/null; then
  fail "claim PATCH failed"
fi

# 2. Bundle
echo "[publish-one $POST_ID] bundle"
BUNDLE="$(curl -fsS "${V2_HDR[@]}" "$BUNDLE_URL")" || fail "bundle GET failed"

PROVIDER="$(echo "$BUNDLE" | jq -r '.platformConnection.provider // empty')"
EXT_ACCOUNT="$(echo "$BUNDLE" | jq -r '.platformConnection.externalAccountId // empty')"
TOKEN_ENC="$(echo "$BUNDLE" | jq -r '.platformConnection.accessTokenEnc // empty')"
CAPTION="$(echo "$BUNDLE" | jq -r '.caption // ""')"
MEDIA_URL="$(echo "$BUNDLE" | jq -r '.mediaUrls[0] // empty')"
PLATFORM="$(echo "$BUNDLE" | jq -r '.platform // empty')"

[[ -z "$PROVIDER" ]]    && fail "platformConnection.provider missing — no active connection for brand+platform $PLATFORM"
[[ -z "$EXT_ACCOUNT" ]] && fail "platformConnection.externalAccountId missing"
[[ -z "$TOKEN_ENC" ]]   && fail "platformConnection.accessTokenEnc missing"

# 3. Decrypt access token
ACCESS_TOKEN="$(node "$SCRIPT_DIR/decrypt-token.mjs" "$TOKEN_ENC")" || fail "decrypt-token failed"

# 4. Route to provider skill
PLATFORM_POST_ID=""
case "$PROVIDER" in
  postforme)
    SKILL="$SKILLS_HOME/r-social-post-postforme/scripts/create-post.sh"
    [[ -x "$SKILL" ]] || fail "r-social-post-postforme not installed at $SKILL"
    echo "[publish-one $POST_ID] postforme → $EXT_ACCOUNT"
    # create-post.sh signature: <caption> <social_account_ids> [media_url] [scheduled_at]
    if [[ -n "$MEDIA_URL" ]]; then
      RESP="$(POSTFORME_API_KEY="$ACCESS_TOKEN" "$SKILL" "$CAPTION" "$EXT_ACCOUNT" "$MEDIA_URL" 2>&1)" || \
        fail "postforme create-post failed: $(echo "$RESP" | tail -c 300)"
    else
      RESP="$(POSTFORME_API_KEY="$ACCESS_TOKEN" "$SKILL" "$CAPTION" "$EXT_ACCOUNT" 2>&1)" || \
        fail "postforme create-post failed: $(echo "$RESP" | tail -c 300)"
    fi
    # PFM responses include the post id as .id
    PLATFORM_POST_ID="$(echo "$RESP" | jq -r '.id // empty' 2>/dev/null || true)"
    ;;
  outstand)
    fail "outstand provider routing not implemented yet (TODO)"
    ;;
  upload-post|upload_post)
    fail "upload-post provider routing not implemented yet (TODO)"
    ;;
  *)
    fail "unknown provider: $PROVIDER"
    ;;
esac

# 5. Mark published. platformUrl arrives async via webhook (handled by V2's
#    /api/v1/webhooks/postforme route) — we don't set it here.
echo "[publish-one $POST_ID] published (platformPostId=${PLATFORM_POST_ID:-unknown})"
PAYLOAD="$(jq -nc \
  --arg pid "$PLATFORM_POST_ID" \
  '{status:"published"} + (if $pid != "" then {platformPostId:$pid} else {} end)')"

curl -fsS -X PATCH "${V2_HDR[@]}" "$PR_URL" -d "$PAYLOAD" >/dev/null || \
  echo "[publish-one $POST_ID] WARN: final PATCH failed but post WAS published — V2 may show stale 'publishing' state" >&2
