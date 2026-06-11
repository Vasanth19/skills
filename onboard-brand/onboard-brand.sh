#!/usr/bin/env bash
# onboard-brand.sh — stand up a CFW Social brand end-to-end with the master key.
#
#   Phase 1  create   POST /api/v1/brand/setup            (master key, multipart)
#   Phase 2  place    UPDATE Brand.hermesBoxId            (prod DB)
#   Phase 3  connect  POST /api/v1/channels/telegram/connect (brand key)
#   Phase 4  bind     handled automatically by the hst daemon draining /pack/pending
#
# Auth: CFW_MASTER_API_KEY (env, required). CFW_PROD_DATABASE_URL (env, for phase 2).
# Secrets are never echoed except the final brand-key line you need.
set -euo pipefail

# ── defaults ──────────────────────────────────────────────────────────────────
BASE_URL="https://app.cfw.social"
BOX="hst"
NAME="" SLUG="" OWNER_EMAIL="" BRIEF_FILE="" LOGO="" CHARACTER=""
BOT_TOKEN="" ALLOWED_USERS="" BRAND_KEY="" BRAND_ID=""
TELEGRAM_ONLY=false SKIP_TELEGRAM=false DRY_RUN=false

die() { echo "❌ $*" >&2; exit 1; }
note() { echo "→ $*" >&2; }

# ── args ──────────────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --slug) SLUG="$2"; shift 2;;
    --owner-email) OWNER_EMAIL="$2"; shift 2;;
    --brief) BRIEF_FILE="$2"; shift 2;;
    --logo) LOGO="$2"; shift 2;;
    --character) CHARACTER="$2"; shift 2;;
    --bot-token) BOT_TOKEN="$2"; shift 2;;
    --allowed-users) ALLOWED_USERS="$2"; shift 2;;
    --box) BOX="$2"; shift 2;;
    --base-url) BASE_URL="$2"; shift 2;;
    --brand-key) BRAND_KEY="$2"; shift 2;;
    --brand-id) BRAND_ID="$2"; shift 2;;
    --telegram-only) TELEGRAM_ONLY=true; shift;;
    --skip-telegram) SKIP_TELEGRAM=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    *) die "unknown flag: $1";;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required"
command -v curl >/dev/null 2>&1 || die "curl is required"
[ -n "${CFW_MASTER_API_KEY:-}" ] || die "CFW_MASTER_API_KEY env is required"

case "$BASE_URL" in
  *v2.cfw.social*) die "refusing to run against the dev tunnel ($BASE_URL). Use https://app.cfw.social";;
esac

mime_for() {  # crude mime from extension; route maps these to R2 ext
  case "${1##*.}" in
    jpg|jpeg) echo image/jpeg;; png) echo image/png;; gif) echo image/gif;;
    webp) echo image/webp;; svg) echo image/svg+xml;; avif) echo image/avif;;
    *) echo application/octet-stream;;
  esac
}

# ── preflight: master key works + daemon alive ────────────────────────────────
preflight() {
  note "preflight: checking master key + daemon on box '$BOX'"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "cfw-api-key: $CFW_MASTER_API_KEY" \
    "$BASE_URL/api/v1/pack/pending?box=$BOX" --max-time 20 || true)
  [ "$code" = "200" ] || die "master key / daemon preflight failed (HTTP $code from /pack/pending?box=$BOX). Master key wrong, or daemon not registered for this box."
  note "preflight ok (daemon feed reachable)"
}

# ── phase 2: placement (prod DB) ──────────────────────────────────────────────
place_brand() {  # $1 = brandId
  local bid="$1"
  if [ -z "${CFW_PROD_DATABASE_URL:-}" ]; then
    cat >&2 <<EOF

⚠️  PLACEMENT BLOCKED — CFW_PROD_DATABASE_URL is not set.
   The brand was created ($bid) but cannot be placed on box '$BOX'.
   Telegram bind needs Brand.hermesBoxId set, or it falls into the dead Fly path.

   Run this SQL against prod, then resume Telegram:
     UPDATE "Brand" SET "hermesBoxId" = '$BOX' WHERE id = '$bid';

   Resume command:
     $0 --telegram-only --brand-id $bid --brand-key <brandKey> \\
        --bot-token $BOT_TOKEN ${ALLOWED_USERS:+--allowed-users $ALLOWED_USERS} --box $BOX --base-url $BASE_URL
EOF
    exit 2
  fi
  command -v psql >/dev/null 2>&1 || die "psql required for placement (or set placement manually with the SQL above)"
  note "placing brand $bid on box '$BOX'"
  $DRY_RUN && { note "[dry-run] would UPDATE Brand.hermesBoxId='$BOX'"; return; }
  psql "$CFW_PROD_DATABASE_URL" -v ON_ERROR_STOP=1 -c \
    "UPDATE \"Brand\" SET \"hermesBoxId\" = '$BOX' WHERE id = '$bid';" >&2
  note "placement done"
}

# ── phase 3: telegram connect (brand key) ─────────────────────────────────────
connect_telegram() {  # $1 = brandKey, $2 = brandId
  local bkey="$1" bid="$2"
  [ -n "$BOT_TOKEN" ] || { note "no --bot-token; skipping telegram"; return; }
  local allowed_json="[]"
  if [ -n "$ALLOWED_USERS" ]; then
    allowed_json=$(printf '%s' "$ALLOWED_USERS" | jq -R 'split(",")|map(gsub("^ +| +$";""))|map(select(length>0))')
  fi
  local body; body=$(jq -n --arg t "$BOT_TOKEN" --argjson a "$allowed_json" \
    '{botToken:$t, allowedUserIds:$a}')
  note "connecting telegram for brand $bid"
  $DRY_RUN && { note "[dry-run] would POST telegram/connect"; return; }
  local out; out=$(curl -s -X POST "$BASE_URL/api/v1/channels/telegram/connect" \
    -H "x-api-key: $bkey" -H "x-cfw-brand: $bid" -H "Content-Type: application/json" \
    --data "$body" --max-time 30)
  local mode; mode=$(printf '%s' "$out" | jq -r '.mode // empty' 2>/dev/null || true)
  local state; state=$(printf '%s' "$out" | jq -r '.bindingState // empty' 2>/dev/null || true)
  if [ "$mode" = "hermes" ] && [ "$state" = "assigning" ]; then
    echo "✅ telegram: hermes-mode bind enqueued (bindingState=assigning); daemon will start the gateway shortly."
  else
    echo "⚠️  telegram connect returned an unexpected result — inspect:" >&2
    printf '%s\n' "$out" >&2
    case "$out" in
      *'"webhookSetAt"'*) die "connect used WEBHOOK (Fly) mode — hermesBoxId was not set. Placement failed.";;
    esac
  fi
}

# ════════════════════════════════════════════════════════════════════════════
$DRY_RUN || preflight

# ── telegram-only resume path ────────────────────────────────────────────────
if $TELEGRAM_ONLY; then
  [ -n "$BRAND_KEY" ] || die "--telegram-only requires --brand-key"
  [ -n "$BRAND_ID" ]  || die "--telegram-only requires --brand-id"
  connect_telegram "$BRAND_KEY" "$BRAND_ID"
  exit 0
fi

# ── phase 1: create brand ─────────────────────────────────────────────────────
[ -n "$NAME" ] || die "--name required"
[ -n "$SLUG" ] || die "--slug required"
[ -n "$OWNER_EMAIL" ] || die "--owner-email required"
[ -n "$BRIEF_FILE" ] || die "--brief <file.json> required"
[ -f "$BRIEF_FILE" ] || die "brief file not found: $BRIEF_FILE"
jq -e . "$BRIEF_FILE" >/dev/null 2>&1 || die "brief is not valid JSON: $BRIEF_FILE"
[ -z "$LOGO" ] || [ -f "$LOGO" ] || die "logo not found: $LOGO"
[ -z "$CHARACTER" ] || [ -f "$CHARACTER" ] || die "character not found: $CHARACTER"

BRIEF_JSON=$(cat "$BRIEF_FILE")
CURL_ARGS=( -s -X POST "$BASE_URL/api/v1/brand/setup"
  -H "cfw-api-key: $CFW_MASTER_API_KEY"
  -F "name=$NAME" -F "slug=$SLUG" -F "ownerEmail=$OWNER_EMAIL" -F "brief=$BRIEF_JSON" )
[ -n "$LOGO" ]      && CURL_ARGS+=( -F "logo=@$LOGO;type=$(mime_for "$LOGO")" )
[ -n "$CHARACTER" ] && CURL_ARGS+=( -F "characterSheet=@$CHARACTER;type=$(mime_for "$CHARACTER")" )

if $DRY_RUN; then
  note "[dry-run] would POST brand/setup name=$NAME slug=$SLUG owner=$OWNER_EMAIL logo=${LOGO:-none} char=${CHARACTER:-none}"
  exit 0
fi

note "creating brand '$NAME' ($SLUG)"
RESP=$(curl "${CURL_ARGS[@]}" --max-time 60)
if ! printf '%s' "$RESP" | jq -e '.brandId' >/dev/null 2>&1; then
  ERR=$(printf '%s' "$RESP" | jq -r '.error // empty' 2>/dev/null || true)
  die "brand/setup failed: ${ERR:-$RESP}"
fi
NEW_BRAND_ID=$(printf '%s' "$RESP" | jq -r '.brandId')
NEW_SLUG=$(printf '%s' "$RESP" | jq -r '.slug')
NEW_WS=$(printf '%s' "$RESP" | jq -r '.workspaceId')
NEW_AGENT=$(printf '%s' "$RESP" | jq -r '.agentId')
NEW_KEY=$(printf '%s' "$RESP" | jq -r '.apiKey')
echo "✅ brand created: $NEW_BRAND_ID ($NEW_SLUG)"

# ── phase 2 + 3 ───────────────────────────────────────────────────────────────
if ! $SKIP_TELEGRAM && [ -n "$BOT_TOKEN" ]; then
  place_brand "$NEW_BRAND_ID"
  connect_telegram "$NEW_KEY" "$NEW_BRAND_ID"
elif ! $SKIP_TELEGRAM && [ -z "$BOT_TOKEN" ]; then
  note "no --bot-token supplied; brand created without Telegram. (You can still place + connect later with --telegram-only.)"
fi

# ── summary ───────────────────────────────────────────────────────────────────
cat <<EOF

──────── onboarded ────────
 brandId     : $NEW_BRAND_ID
 slug        : $NEW_SLUG
 workspaceId : $NEW_WS
 directorId  : $NEW_AGENT
 brand key   : $NEW_KEY   (store securely — do not paste in shared logs)
 box         : $BOX
 owner UI    : $BASE_URL/$NEW_SLUG
───────────────────────────
Next: wait ~30-60s for the daemon to bind the bot, then DM it to cook a test dish.
EOF
