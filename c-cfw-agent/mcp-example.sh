#!/usr/bin/env bash
#
# mcp-example.sh — raw curl smoke for the cfw-agent MCP.
#
# Exercises initialize → tools/list → resources/list → tools/call cfw_run
# ("say HELLO" — the cheapest possible LLM round-trip). Prints PASS / FAIL
# per step + exits 1 on any failure. No Claude Code dependency.
#
# Usage:
#   bash mcp-example.sh \
#     --base-url=http://localhost:8081 \
#     --api-key="$CFW_OPENCLAW_KEY" \
#     --brand-id=e2e-brand-001
#
# Or via env vars:
#   CFW_BASE_URL=https://agent.cfw.social CFW_API_KEY=… CFW_BRAND_ID=… bash mcp-example.sh
#
set -euo pipefail

BASE_URL="${CFW_BASE_URL:-http://localhost:8081}"
API_KEY="${CFW_API_KEY:-}"
BRAND_ID="${CFW_BRAND_ID:-}"
SKIP_TOOL_CALL=0

for arg in "$@"; do
  case "$arg" in
    --base-url=*) BASE_URL="${arg#*=}" ;;
    --api-key=*)  API_KEY="${arg#*=}" ;;
    --brand-id=*) BRAND_ID="${arg#*=}" ;;
    --no-tool-call) SKIP_TOOL_CALL=1 ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 64 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (brew install jq)." >&2
  exit 64
fi

MCP_URL="${BASE_URL%/}/mcp"
echo "→ MCP endpoint: $MCP_URL"

call() {
  # call <id> <method> <params-json> → echoes the response
  local id="$1" method="$2" params="$3"
  curl -sS -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    ${API_KEY:+-H "x-api-key: $API_KEY"} \
    -d "{\"jsonrpc\":\"2.0\",\"id\":$id,\"method\":\"$method\",\"params\":$params}"
}

# ── 1. initialize ────────────────────────────────────────────────────────────
echo
echo "─── initialize ─────────────────────────"
RESP=$(call 1 initialize '{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"mcp-example.sh","version":"1.0.0"}}')
echo "$RESP" | jq -e '.result.serverInfo.name == "cfw-agent"' >/dev/null \
  && echo "PASS  serverInfo.name == cfw-agent" \
  || { echo "FAIL  initialize: $RESP"; exit 1; }

# ── 2. tools/list ────────────────────────────────────────────────────────────
echo
echo "─── tools/list ─────────────────────────"
RESP=$(call 2 tools/list '{}')
echo "$RESP" | jq -e '.result.tools[] | select(.name=="cfw_run")' >/dev/null \
  && echo "PASS  cfw_run tool present" \
  || { echo "FAIL  tools/list: $RESP"; exit 1; }

# ── 3. resources/list ────────────────────────────────────────────────────────
echo
echo "─── resources/list ─────────────────────"
RESP=$(call 3 resources/list '{}')
URI_COUNT=$(echo "$RESP" | jq '.result.resources | length')
echo "$RESP" | jq -e '.result.resources | map(.uri) | contains(["cfw://catalog/agent-guide","cfw://catalog/skills-catalog","cfw://catalog/skills-json"])' >/dev/null \
  && echo "PASS  3 catalog resources present (found $URI_COUNT)" \
  || { echo "FAIL  resources/list: $RESP"; exit 1; }

# ── 4. tools/call cfw_run (only if creds + brand provided) ───────────────────
if [[ $SKIP_TOOL_CALL -eq 1 ]]; then
  echo
  echo "(skipping tools/call — --no-tool-call)"
  echo
  echo "ALL CHECKS PASSED ✓"
  exit 0
fi

if [[ -z "$API_KEY" || -z "$BRAND_ID" ]]; then
  echo
  echo "(skipping tools/call — set --api-key + --brand-id to exercise the LLM)"
  echo
  echo "PROTOCOL CHECKS PASSED ✓ (no auth attempted)"
  exit 0
fi

echo
echo "─── tools/call cfw_run (say HELLO) ─────"
RESP=$(call 4 tools/call "{\"name\":\"cfw_run\",\"arguments\":{\"brandId\":\"$BRAND_ID\",\"prompt\":\"Reply with just the word HELLO and nothing else.\"}}")
REPLY=$(echo "$RESP" | jq -r '.result.structuredContent.reply // empty')
COST=$(echo "$RESP" | jq -r '.result.structuredContent.costUsd // empty')
IS_ERR=$(echo "$RESP" | jq -r '.result.isError // false')

if [[ "$IS_ERR" == "true" ]]; then
  echo "FAIL  cfw_run returned tool error:"
  echo "$RESP" | jq -r '.result.content[0].text'
  exit 1
fi

if [[ -z "$REPLY" ]]; then
  echo "FAIL  no reply in structuredContent"
  echo "$RESP" | jq
  exit 1
fi

echo "PASS  reply=\"$REPLY\"  costUsd=\$$COST"
echo
echo "ALL CHECKS PASSED ✓"
