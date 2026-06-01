#!/usr/bin/env bash
# research.sh — Dual-provider research CLI (Perplexity → Firecrawl fallback)
#
# Usage:
#   bash research.sh "content marketing trends 2026"
#   bash research.sh "AI video tools landscape" --recency month
#   bash research.sh "what is happening with LinkedIn algorithm" --recency day
#
# Options:
#   --recency  day|week|month  (default: week)
#
# Provider selection (in order):
#   1. PERPLEXITY_API_KEY set  → Perplexity sonar-pro (supports --recency natively)
#   2. FIRECRAWL_API_KEY set   → Firecrawl /v1/search (--recency ignored, best-effort)
#   3. Neither set             → fail-fast with instructions for both
#
# Exit codes:
#   0 — success
#   1 — bad args or no API key set
#   2 — API error (non-200 HTTP status or parse failure)

set -euo pipefail

# ── argument parsing ──────────────────────────────────────────────────────────
TOPIC=""
RECENCY_FILTER="week"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recency)
      RECENCY_FILTER="$2"
      shift 2
      ;;
    --recency=*)
      RECENCY_FILTER="${1#*=}"
      shift
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      echo "Usage: bash research.sh \"<topic>\" [--recency day|week|month]" >&2
      exit 1
      ;;
    *)
      TOPIC="$1"
      shift
      ;;
  esac
done

if [ -z "$TOPIC" ]; then
  echo "Usage: bash research.sh \"<topic>\" [--recency day|week|month]" >&2
  exit 1
fi

# Validate recency filter
case "$RECENCY_FILTER" in
  day|week|month) ;;
  *)
    echo "ERROR: --recency must be one of: day, week, month (got: $RECENCY_FILTER)" >&2
    exit 1
    ;;
esac

# ── key resolution ────────────────────────────────────────────────────────────
# Source secrets file first (local dev); process env wins if already set
[ -f ~/.gsai/secrets.env ] && source ~/.gsai/secrets.env

# ── provider selection ────────────────────────────────────────────────────────
if [ -n "${PERPLEXITY_API_KEY:-}" ]; then
  PROVIDER="perplexity"
elif [ -n "${FIRECRAWL_API_KEY:-}" ]; then
  PROVIDER="firecrawl"
else
  echo "ERROR: No research API key found. Set one of:" >&2
  echo "" >&2
  echo "  PERPLEXITY_API_KEY  (preferred — sonar-pro, native recency filtering)" >&2
  echo "    Get key:   https://www.perplexity.ai/settings/api" >&2
  echo "" >&2
  echo "  FIRECRAWL_API_KEY   (fallback — web search, --recency flag ignored)" >&2
  echo "    Get key:   https://www.firecrawl.dev" >&2
  echo "" >&2
  echo "  Local dev:  add to ~/.gsai/secrets.env" >&2
  echo "  Fly.io:     fly secrets set PERPLEXITY_API_KEY=pplx-... (or FIRECRAWL_API_KEY=fc-...)" >&2
  echo "  VPS hst:    add to /opt/cfw-agent/.env" >&2
  exit 1
fi

echo "Provider: $PROVIDER | Topic: $TOPIC | Recency: $RECENCY_FILTER" >&2
echo "" >&2

# ══════════════════════════════════════════════════════════════════════════════
# PERPLEXITY PATH
# ══════════════════════════════════════════════════════════════════════════════
if [ "$PROVIDER" = "perplexity" ]; then

  MODEL="sonar-pro"

  # Build JSON payload with python3 to safely escape the topic string
  PAYLOAD=$(python3 -c "
import json, sys
topic = sys.argv[1]
recency = sys.argv[2]
model = sys.argv[3]
payload = {
    'model': model,
    'search_recency_filter': recency,
    'messages': [
        {
            'role': 'system',
            'content': (
                'You are a research assistant for a content studio. '
                'Return thorough, cited findings on the topic. '
                'Structure your response as: key findings (3-5 bullet points with '
                'source citations inline as [1], [2], etc.), followed by a numbered '
                'citation list with full URLs. Be specific and data-driven. '
                'Focus on actionable insights for content creators.'
            )
        },
        {
            'role': 'user',
            'content': topic
        }
    ]
}
print(json.dumps(payload))
" "$TOPIC" "$RECENCY_FILTER" "$MODEL")

  # Execute curl; capture body + status code
  RAW_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
    -X POST "https://api.perplexity.ai/chat/completions" \
    -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  HTTP_STATUS=$(echo "$RAW_RESPONSE" | grep '__HTTP_STATUS__' | sed 's/__HTTP_STATUS__//')
  BODY=$(echo "$RAW_RESPONSE" | grep -v '__HTTP_STATUS__' | head -c 500000)

  if [ "$HTTP_STATUS" != "200" ]; then
    echo "ERROR: Perplexity API returned HTTP $HTTP_STATUS" >&2
    ERROR_MSG=$(echo "$BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('error', {}).get('message', '')
    if msg:
        print(msg)
    else:
        print(json.dumps(d, indent=2))
except Exception:
    pass
" 2>/dev/null || true)
    if [ -n "$ERROR_MSG" ]; then
      echo "$ERROR_MSG" >&2
    else
      echo "$BODY" >&2
    fi
    exit 2
  fi

  # Parse and emit output
  python3 - "$TOPIC" "$RECENCY_FILTER" <<PYEOF
import sys, json

topic = sys.argv[1]
recency = sys.argv[2]

raw = """$BODY"""
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"ERROR: Failed to parse API response: {e}", file=sys.stderr)
    sys.exit(2)

content = data['choices'][0]['message']['content']
citations = data.get('citations', [])

print(f"# Research: {topic}")
print(f"# Provider: Perplexity sonar-pro | Recency: {recency}")
print("=" * 72)
print()
print("## Research Findings")
print()
print(content)

if citations:
    print()
    print("## Citations")
    print()
    for i, url in enumerate(citations, 1):
        print(f"[{i}] {url}")

print()
print("## Suggested Brand Insights")
print()
print("Review the findings above and consider:")
print("- Which trends are most relevant to this brand's audience?")
print("- What content angles emerge from the cited data?")
print("- Are there statistics or claims worth fact-checking before publishing?")
PYEOF

# ══════════════════════════════════════════════════════════════════════════════
# FIRECRAWL PATH
# ══════════════════════════════════════════════════════════════════════════════
elif [ "$PROVIDER" = "firecrawl" ]; then

  if [ "$RECENCY_FILTER" != "week" ]; then
    echo "NOTE: --recency is not natively supported by Firecrawl search and will be ignored." >&2
  fi

  # Build JSON payload safely
  PAYLOAD=$(python3 -c "
import json, sys
topic = sys.argv[1]
payload = {
    'query': topic,
    'limit': 5
}
print(json.dumps(payload))
" "$TOPIC")

  # Execute curl; capture body + status code
  RAW_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
    -X POST "https://api.firecrawl.dev/v1/search" \
    -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  HTTP_STATUS=$(echo "$RAW_RESPONSE" | grep '__HTTP_STATUS__' | sed 's/__HTTP_STATUS__//')
  BODY=$(echo "$RAW_RESPONSE" | grep -v '__HTTP_STATUS__' | head -c 500000)

  if [ "$HTTP_STATUS" != "200" ]; then
    echo "ERROR: Firecrawl API returned HTTP $HTTP_STATUS" >&2
    ERROR_MSG=$(echo "$BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('error', d.get('message', ''))
    if msg:
        print(msg)
    else:
        print(json.dumps(d, indent=2))
except Exception:
    pass
" 2>/dev/null || true)
    if [ -n "$ERROR_MSG" ]; then
      echo "$ERROR_MSG" >&2
    else
      echo "$BODY" >&2
    fi
    exit 2
  fi

  # Parse Firecrawl results and emit same output shape as Perplexity
  python3 - "$TOPIC" <<PYEOF
import sys, json

topic = sys.argv[1]

raw = """$BODY"""
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"ERROR: Failed to parse API response: {e}", file=sys.stderr)
    sys.exit(2)

results = data.get('data', [])

if not results:
    print("ERROR: No results returned from Firecrawl search.", file=sys.stderr)
    sys.exit(2)

print(f"# Research: {topic}")
print(f"# Provider: Firecrawl /v1/search | Recency: best-effort (not natively filtered)")
print("=" * 72)
print()
print("## Research Findings")
print()

# Emit findings as cited bullets matching Perplexity output shape
for i, result in enumerate(results, 1):
    title = result.get('title', 'Untitled')
    url = result.get('url', '')
    # Prefer markdown content if present; fall back to description
    snippet = result.get('markdown', result.get('description', '')).strip()
    # Truncate long snippets to keep output concise
    if len(snippet) > 600:
        snippet = snippet[:600].rsplit(' ', 1)[0] + '…'
    if snippet:
        print(f"- **{title}** [{i}]")
        print(f"  {snippet}")
    else:
        print(f"- **{title}** [{i}]")
    print()

print()
print("## Citations")
print()
for i, result in enumerate(results, 1):
    title = result.get('title', 'Untitled')
    url = result.get('url', '')
    print(f"[{i}] {title} — {url}")

print()
print("## Suggested Brand Insights")
print()
print("Review the findings above and consider:")
print("- Which trends are most relevant to this brand's audience?")
print("- What content angles emerge from the cited data?")
print("- Are there statistics or claims worth fact-checking before publishing?")
PYEOF

fi
