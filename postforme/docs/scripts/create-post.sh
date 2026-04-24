#!/usr/bin/env bash
# Create (and optionally schedule) a social post — with layered duplicate prevention.
#
# Usage: ./create-post.sh <caption> <social_account_ids_csv> [media_url] [scheduled_at_iso8601] [--dry-run]
#
# Duplicate-prevention layers (VAS-31 + VAS-33, in order of execution):
#   1. PUBLISH-INTENT LEDGER (NEW, VAS-33 Track A — 2026-04-22)
#      At scheduling time, write an intent row keyed by PUBLISH_INTENT_KEY
#      (defaults to BRAND:SOURCE_ISSUE:CONTENT_HASH). If a live intent already
#      exists from a different PID within the intent TTL, abort BEFORE any
#      external write. Catches parallel-agent races where caption+media_url
#      both differ but agents are fighting over the same reel/issue.
#
#   2. CONTENT-FINGERPRINT LEDGER (NEW, VAS-33 Track A — 2026-04-22)
#      CONTENT_HASH (SHA256 of the local MP4) is a secondary dedup key. If a
#      recent post in the last 24h used the same CONTENT_HASH to any account
#      in our target set, abort — the video already shipped. Catches the
#      "rogue rewrote caption + re-uploaded bytes" failure mode (Apr 22).
#
#   3. INPUT-HASH LOCK (VAS-33 initial — 2026-04-21)
#      A per-key `mkdir` lock serializes the check/create/write critical
#      section across concurrent calls with identical inputs.
#
#   4. INPUT-HASH LOCAL LEDGER (VAS-31 — 2026-04-20)
#      Hash of (caption + media_url + sorted_accounts). Authoritative record
#      of successful creates; wins over server_external_id (which PostForMe
#      silently drops).
#
#   5. SERVER external_id check (belt-and-suspenders, currently degraded)
#      Kept in case PostForMe fixes external_id persistence.
#
#   6. POST-CREATE VERIFICATION
#      Re-lists posts for the external_id; warns loudly if >1 match is seen.
#
# Env vars (new):
#   CONTENT_HASH             SHA256 of the local media file (from upload-media.sh).
#                            If set, activates content-fingerprint dedup + gets
#                            persisted in the post ledger row.
#   PUBLISH_INTENT_KEY       Optional explicit intent key. If unset, composed as
#                            BRAND:SOURCE_ISSUE:CONTENT_HASH (requires CONTENT_HASH
#                            to be meaningful; otherwise falls back to input-hash).
#   PUBLISH_INTENT_TTL_SEC   How long an intent row blocks others (default 3600s).
#   IDEMPOTENCY=off          Disables ALL dedup layers (emergency override only).
#
# Examples:
#   ./create-post.sh "Hello world" "spc_abc,spc_def"
#   ./create-post.sh "Launch!" "spc_abc" "https://cdn/img.jpg"
#   ./create-post.sh "Tomorrow" "spc_abc" "" "2026-12-31T10:00:00Z"
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_common.sh"
# Brand analytics ledger (best-effort, non-blocking). Resolves to
# posting-tools/shared/ledger.sh from this script's location.
LEDGER_LIB="$DIR/../../../../shared/ledger.sh"
# shellcheck disable=SC1090
[ -f "$LEDGER_LIB" ] && source "$LEDGER_LIB"
require_key

filter_args "$@"; ARGS=("${CLEAN_ARGS[@]+"${CLEAN_ARGS[@]}"}")
CAPTION="${ARGS[0]:?Usage: create-post.sh <caption> <social_account_ids_csv> [media_url] [scheduled_at]}"
ACCOUNTS_CSV="${ARGS[1]:?Provide comma-separated social_account IDs}"
MEDIA_URL="${ARGS[2]:-}"
SCHEDULED_AT="${ARGS[3]:-}"
IDEMPOTENCY="${IDEMPOTENCY:-on}"
LEDGER_DIR="${HOME}/.posting-tools-ledger"
LEDGER_FILE="${LEDGER_DIR}/postforme.tsv"
INTENT_FILE="${LEDGER_DIR}/publish-intent.tsv"
FP_POST_FILE="${LEDGER_DIR}/postforme-fingerprints.tsv"
mkdir -p "$LEDGER_DIR"
touch "$LEDGER_FILE" "$INTENT_FILE" "$FP_POST_FILE"

# --- Compute IDEMPOTENCY_KEY: stable hash of (caption + media_url + sorted_accounts) ---
# Note: short hex (first 16 chars) fits well inside PostForMe's external_id field.
SORTED_ACCOUNTS=$(printf '%s' "$ACCOUNTS_CSV" | tr ',' '\n' | sort | paste -sd, -)
IDEMPOTENCY_KEY=$(printf '%s|%s|%s' "$CAPTION" "$MEDIA_URL" "$SORTED_ACCOUNTS" \
  | shasum -a 256 | cut -c1-16)

# --- Compose PUBLISH_INTENT_KEY (intent-level dedup key) ---
# Intent keys are deliberately INDEPENDENT of caption + media_url so that
# different-caption, re-uploaded-media rogues still collide at this layer.
CONTENT_HASH="${CONTENT_HASH:-}"
PUBLISH_INTENT_KEY="${PUBLISH_INTENT_KEY:-}"
if [ -z "$PUBLISH_INTENT_KEY" ]; then
  if [ -n "$CONTENT_HASH" ]; then
    # Default: BRAND:SOURCE_ISSUE:CONTENT_HASH — works whether BRAND/ISSUE are set.
    PUBLISH_INTENT_KEY="${BRAND:-unknown}:${SOURCE_ISSUE:-noissue}:${CONTENT_HASH}"
  else
    # No CONTENT_HASH — intent key degenerates to the input hash. Still records
    # an intent, but cannot catch caption/media-drift rogues. Caller should pass
    # CONTENT_HASH to get the full protection.
    PUBLISH_INTENT_KEY="inputhash:${IDEMPOTENCY_KEY}"
  fi
fi
PUBLISH_INTENT_TTL_SEC="${PUBLISH_INTENT_TTL_SEC:-3600}"
CALLER_PID="$$"

# --- Pre-check LAYER 1: publish-intent ledger ---
# Format: ts \t intent_key \t accounts \t pid \t status \t post_id
# status in {pending, claimed, failed, released}. Only {pending, claimed} block.
# Rules for "live":
#   - claimed row → ALWAYS live within TTL (finished post; already shipped)
#   - pending row → live only if its PID is still alive (else stale crash)
# We scan ALL matching rows, not just the first — so a stale pending row
# doesn't hide a real claimed row from the same agent.
if [ "$IDEMPOTENCY" = "on" ] && [ "${DRY_RUN}" != "1" ]; then
  NOW=$(date +%s)
  CUTOFF=$((NOW - PUBLISH_INTENT_TTL_SEC))
  # Dump all candidate rows — bash does the liveness check.
  CANDIDATES=$(awk -F'\t' -v k="$PUBLISH_INTENT_KEY" -v cutoff="$CUTOFF" -v mypid="$CALLER_PID" '
    $1 >= cutoff && $2 == k && ($5 == "pending" || $5 == "claimed") && $4 != mypid {
      print $4 "\t" $5 "\t" $6
    }' "$INTENT_FILE" 2>/dev/null || true)
  if [ -n "$CANDIDATES" ]; then
    BLOCK_PID=""
    BLOCK_STATUS=""
    BLOCK_POST=""
    while IFS=$'\t' read -r ROW_PID ROW_STATUS ROW_POST; do
      [ -z "$ROW_PID" ] && continue
      if [ "$ROW_STATUS" = "claimed" ]; then
        # claimed rows always block (post already created upstream).
        BLOCK_PID="$ROW_PID"; BLOCK_STATUS="$ROW_STATUS"; BLOCK_POST="$ROW_POST"
        break
      fi
      # pending: live iff holder PID is still alive.
      if kill -0 "$ROW_PID" 2>/dev/null; then
        BLOCK_PID="$ROW_PID"; BLOCK_STATUS="$ROW_STATUS"; BLOCK_POST="$ROW_POST"
        break
      fi
    done <<< "$CANDIDATES"
    if [ -n "$BLOCK_PID" ]; then
      echo "{\"intent_collision\": true, \"intent_key\": \"${PUBLISH_INTENT_KEY}\", \"holder_pid\": \"${BLOCK_PID}\", \"holder_status\": \"${BLOCK_STATUS}\", \"holder_post_id\": \"${BLOCK_POST}\"}" >&2
      echo "   Another publish for intent_key=${PUBLISH_INTENT_KEY} is already live (pid ${BLOCK_PID}, status ${BLOCK_STATUS})." >&2
      echo "   If this is legitimate (different reel with overlapping key), set PUBLISH_INTENT_KEY explicitly to a distinct value." >&2
      echo "{\"id\": \"${BLOCK_POST:-}\", \"deduped\": true, \"source\": \"publish_intent\", \"intent_key\": \"${PUBLISH_INTENT_KEY}\"}"
      exit 0
    fi
  fi
fi

# --- Pre-check LAYER 2: content-fingerprint ledger ---
# Format: ts \t content_hash \t post_id \t accounts_csv \t caption_first80
# A recent (≤24h) post with the same CONTENT_HASH going to any overlapping
# account is a content-level dedup hit — even if caption/media_url differ.
if [ "$IDEMPOTENCY" = "on" ] && [ "${DRY_RUN}" != "1" ] && [ -n "$CONTENT_HASH" ]; then
  NOW=$(date +%s)
  CUTOFF=$((NOW - 86400))
  FP_MATCH=$(awk -F'\t' -v h="$CONTENT_HASH" -v accounts="$SORTED_ACCOUNTS" -v cutoff="$CUTOFF" '
    function overlap(a, b,   na, nb, i, j) {
      n=split(a, A, ",")
      m=split(b, B, ",")
      for (i=1; i<=n; i++)
        for (j=1; j<=m; j++)
          if (A[i] == B[j]) return 1
      return 0
    }
    $1 >= cutoff && $2 == h {
      if (overlap($4, accounts)) {
        print $3 "\t" $4
        exit
      }
    }' "$FP_POST_FILE" 2>/dev/null)
  if [ -n "$FP_MATCH" ]; then
    PRIOR_POST=$(printf '%s' "$FP_MATCH" | awk -F'\t' '{print $1}')
    PRIOR_ACCOUNTS=$(printf '%s' "$FP_MATCH" | awk -F'\t' '{print $2}')
    echo "{\"deduped\": true, \"existing_post_id\": \"${PRIOR_POST}\", \"source\": \"content_fingerprint\", \"content_hash\": \"${CONTENT_HASH}\", \"overlapping_accounts\": \"${PRIOR_ACCOUNTS}\"}" >&2
    echo "   Same video (content_hash=${CONTENT_HASH:0:12}…) already shipped to overlapping accounts." >&2
    echo "   Override with IDEMPOTENCY=off if this is a deliberate re-post to different platforms." >&2
    echo "{\"id\": \"${PRIOR_POST}\", \"deduped\": true, \"source\": \"content_fingerprint\"}"
    exit 0
  fi
fi

# --- LAYER 3: per-idempotency-key lock (serialize check/create/write) ---
LOCK_ACQUIRED=0
LOCK_DIR=""
# --- LAYER 1 ledger bookkeeping: track intent-row bookkeeping for trap/cleanup ---
INTENT_ROW_WRITTEN=0

# Shared cleanup trap — always runs. Releases lock + finalizes intent row.
cleanup() {
  local rc=$?
  if [ "$INTENT_ROW_WRITTEN" = "1" ] && [ "${DRY_RUN}" != "1" ]; then
    # If we never claimed successfully, mark the intent row failed so other
    # callers don't see it as a permanent reservation.
    local state_file="${LEDGER_DIR}/.intent-state-${CALLER_PID}-${IDEMPOTENCY_KEY}"
    local final_state="failed"
    if [ -f "$state_file" ]; then
      final_state=$(cat "$state_file" 2>/dev/null || echo "failed")
      rm -f "$state_file"
    fi
    if [ "$final_state" != "claimed" ]; then
      # Append a release row instead of rewriting — TSV is append-only for safety.
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date +%s)" "$PUBLISH_INTENT_KEY" "$SORTED_ACCOUNTS" "$CALLER_PID" "released" "" \
        >> "$INTENT_FILE"
    fi
  fi
  if [ "$LOCK_ACQUIRED" = "1" ] && [ -n "$LOCK_DIR" ]; then
    rm -rf "$LOCK_DIR"
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

if [ "$IDEMPOTENCY" = "on" ] && [ "${DRY_RUN}" != "1" ]; then
  LOCK_DIR="${LEDGER_DIR}/.lock-${IDEMPOTENCY_KEY}"
  LOCK_TIMEOUT="${POSTFORME_LOCK_TIMEOUT_SEC:-60}"
  LOCK_DEADLINE=$(( $(date +%s) + LOCK_TIMEOUT ))
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    # If the holder PID is dead, reclaim the lock.
    if [ -r "${LOCK_DIR}/pid" ]; then
      HOLDER_PID=$(cat "${LOCK_DIR}/pid" 2>/dev/null || echo "")
      if [ -n "$HOLDER_PID" ] && ! kill -0 "$HOLDER_PID" 2>/dev/null; then
        rm -rf "$LOCK_DIR"
        continue
      fi
    fi
    if [ "$(date +%s)" -ge "$LOCK_DEADLINE" ]; then
      echo "{\"error\": \"lock_timeout\", \"idempotency_key\": \"mggpub-${IDEMPOTENCY_KEY}\", \"timeout_sec\": ${LOCK_TIMEOUT}}" >&2
      echo "   Another create-post.sh for the same key has held the lock for >${LOCK_TIMEOUT}s." >&2
      echo "   Raise with POSTFORME_LOCK_TIMEOUT_SEC or investigate the stuck process." >&2
      exit 75  # EX_TEMPFAIL
    fi
    sleep 0.2
  done
  printf '%s\n' "$CALLER_PID" > "${LOCK_DIR}/pid"
  LOCK_ACQUIRED=1
fi

# --- Pre-check LAYER 4: input-hash local ledger (existing) ---
if [ "$IDEMPOTENCY" = "on" ] && [ "${DRY_RUN}" != "1" ]; then
  NOW=$(date +%s)
  CUTOFF=$((NOW - 86400))
  LEDGER_MATCH=$(awk -F'\t' -v key="$IDEMPOTENCY_KEY" -v cutoff="$CUTOFF" \
    '$1 >= cutoff && $2 == key { print $3; exit }' "$LEDGER_FILE" 2>/dev/null)
  if [ -n "$LEDGER_MATCH" ]; then
    echo "{\"deduped\": true, \"existing_post_id\": \"${LEDGER_MATCH}\", \"source\": \"local_ledger\", \"idempotency_key\": \"mggpub-${IDEMPOTENCY_KEY}\"}" >&2
    echo "   Override with IDEMPOTENCY=off (NOT recommended — confirmed dupes at 2026-04-20)." >&2
    echo "{\"id\": \"${LEDGER_MATCH}\", \"deduped\": true, \"source\": \"local_ledger\"}"
    exit 0
  fi
fi

# --- Pre-check LAYER 5 (DEGRADED — server external_id not persisted by PostForMe as of 2026-04-20):
# Keep this check in case PostForMe fixes external_id persistence — belt and suspenders.
if [ "$IDEMPOTENCY" = "on" ] && [ "${DRY_RUN}" != "1" ]; then
  EXISTING=$(curl -sS -H "Authorization: Bearer ${POSTFORME_API_KEY}" \
    "${POSTFORME_BASE_URL}/${POSTFORME_API_VERSION}/social-posts?limit=50" \
    | (command -v jq >/dev/null \
         && jq -r ".data[]? | select(.external_id==\"mggpub-${IDEMPOTENCY_KEY}\") | .id" \
         || echo "") )
  if [ -n "$EXISTING" ]; then
    echo "{\"deduped\": true, \"existing_post_id\": \"${EXISTING}\", \"source\": \"server_external_id\", \"idempotency_key\": \"mggpub-${IDEMPOTENCY_KEY}\"}" >&2
    echo "{\"id\": \"${EXISTING}\", \"deduped\": true, \"source\": \"server_external_id\"}"
    exit 0
  fi
fi

# --- Write the PENDING intent row (after all pre-checks, before external write) ---
if [ "$IDEMPOTENCY" = "on" ] && [ "${DRY_RUN}" != "1" ]; then
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$PUBLISH_INTENT_KEY" "$SORTED_ACCOUNTS" "$CALLER_PID" "pending" "" \
    >> "$INTENT_FILE"
  INTENT_ROW_WRITTEN=1
fi

# --- Build JSON body ---
ACCOUNTS_JSON=$(printf '%s' "$ACCOUNTS_CSV" | awk -F, '{
  printf "["
  for (i=1;i<=NF;i++){ printf "%s\"%s\"", (i>1?",":""), $i }
  printf "]"
}')

MEDIA_JSON="null"
if [ -n "$MEDIA_URL" ]; then
  MEDIA_JSON="[{\"url\":\"${MEDIA_URL}\"}]"
fi

SCHED_JSON="null"
if [ -n "$SCHEDULED_AT" ]; then
  SCHED_JSON="\"${SCHEDULED_AT}\""
fi

BODY=$(cat <<JSON
{
  "caption": $(printf '%s' "$CAPTION" | python3 -c "import sys,json;print(json.dumps(sys.stdin.read()))"),
  "social_accounts": ${ACCOUNTS_JSON},
  "media": ${MEDIA_JSON},
  "scheduled_at": ${SCHED_JSON},
  "external_id": "mggpub-${IDEMPOTENCY_KEY}"
}
JSON
)

# --- Create the post ---
RESPONSE=$(run_curl POST "/social-posts" --data "$BODY")
printf '%s\n' "$RESPONSE"

# --- Capture post_id for ledger rows ---
CREATED_POST_ID=""
if [ "${DRY_RUN}" != "1" ]; then
  CREATED_POST_ID=$(printf '%s' "$RESPONSE" | (command -v jq >/dev/null && jq -r '.id // empty' || echo ""))
fi

# --- LAYER 4 WRITE: input-hash local ledger (authoritative record of success) ---
if [ "${DRY_RUN}" != "1" ] && [ -n "$CREATED_POST_ID" ]; then
  # Append content_hash as a 6th column — backward-compatible (old readers stop at 5 fields).
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$IDEMPOTENCY_KEY" "$CREATED_POST_ID" "$SORTED_ACCOUNTS" "${CAPTION:0:80}" "$CONTENT_HASH" \
    >> "$LEDGER_FILE"
fi

# --- LAYER 2 WRITE: content-fingerprint ledger ---
if [ "${DRY_RUN}" != "1" ] && [ -n "$CREATED_POST_ID" ] && [ -n "$CONTENT_HASH" ]; then
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$CONTENT_HASH" "$CREATED_POST_ID" "$SORTED_ACCOUNTS" "${CAPTION:0:80}" \
    >> "$FP_POST_FILE"
fi

# --- LAYER 1 UPDATE: mark intent CLAIMED with the post_id ---
if [ "${DRY_RUN}" != "1" ] && [ "$INTENT_ROW_WRITTEN" = "1" ] && [ -n "$CREATED_POST_ID" ]; then
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$PUBLISH_INTENT_KEY" "$SORTED_ACCOUNTS" "$CALLER_PID" "claimed" "$CREATED_POST_ID" \
    >> "$INTENT_FILE"
  # Tell the cleanup trap we finished successfully.
  printf 'claimed' > "${LEDGER_DIR}/.intent-state-${CALLER_PID}-${IDEMPOTENCY_KEY}"
fi

# --- Brand analytics ledger (best-effort, never breaks the publish) ---
# Set BRAND env var (folder slug under ~/vasanth-hq/) to opt in.
# SOURCE_ISSUE / SOURCE_BRIEF_ID env vars are optional provenance.
if [ "${DRY_RUN}" != "1" ] && [ -n "${BRAND:-}" ] && declare -f ledger_record_post >/dev/null 2>&1; then
  if [ -n "$CREATED_POST_ID" ]; then
    ledger_record_post \
      "$BRAND" "$CREATED_POST_ID" "postforme" "$CAPTION" "$MEDIA_URL" \
      "mggpub-${IDEMPOTENCY_KEY}" "${SOURCE_ISSUE:-}" "${SOURCE_BRIEF_ID:-}" \
      || true
  fi
fi

# --- Post-create verification: count posts matching our external_id ---
if [ "${DRY_RUN}" != "1" ]; then
  sleep 1
  COUNT=$(curl -sS -H "Authorization: Bearer ${POSTFORME_API_KEY}" \
    "${POSTFORME_BASE_URL}/${POSTFORME_API_VERSION}/social-posts?limit=10" \
    | (command -v jq >/dev/null \
         && jq "[.data[]? | select(.external_id==\"mggpub-${IDEMPOTENCY_KEY}\")] | length" \
         || echo "1") )
  if [ "${COUNT:-1}" -gt 1 ]; then
    echo "" >&2
    echo "⚠️  WARNING: ${COUNT} posts matching idempotency key mggpub-${IDEMPOTENCY_KEY} — possible duplicate." >&2
    echo "   List with: list-posts.sh 10 | grep mggpub-${IDEMPOTENCY_KEY}" >&2
    echo "   This usually means a prior call partially succeeded despite a client-side error." >&2
  fi
fi
