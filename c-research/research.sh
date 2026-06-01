#!/usr/bin/env bash
# research.sh — Dual-provider research CLI (Perplexity → Firecrawl fallback)
#
# Usage:
#   bash research.sh "content marketing trends 2026"
#   bash research.sh "AI video tools landscape" --recency month
#
# Options:
#   --recency  day|week|month  (default: week; Perplexity-only, ignored by Firecrawl)
#
# Provider selection:
#   - PERPLEXITY_API_KEY set → try Perplexity first (sonar-pro, native recency).
#   - If Perplexity FAILS at runtime (quota/401/5xx) AND FIRECRAWL_API_KEY is set
#     → automatically fall back to Firecrawl (true dual-provider resilience).
#   - Only PERPLEXITY missing → Firecrawl directly.
#   - Neither key → fail-fast naming both.
#
# Exit codes:
#   0 — success
#   1 — missing topic / both keys missing
#   2 — all available providers failed

set -uo pipefail

# ── argument parsing ──────────────────────────────────────────────────────────
TOPIC=""
RECENCY_FILTER="week"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recency)    RECENCY_FILTER="$2"; shift 2 ;;
    --recency=*)  RECENCY_FILTER="${1#*=}"; shift ;;
    -*)
      echo "Unknown flag: $1" >&2
      echo "Usage: bash research.sh \"<topic>\" [--recency day|week|month]" >&2
      exit 1 ;;
    *)            TOPIC="$1"; shift ;;
  esac
done

if [ -z "$TOPIC" ]; then
  echo "Usage: bash research.sh \"<topic>\" [--recency day|week|month]" >&2
  exit 1
fi

case "$RECENCY_FILTER" in
  day|week|month) ;;
  *) echo "ERROR: --recency must be one of: day, week, month (got: $RECENCY_FILTER)" >&2; exit 1 ;;
esac

# ── key resolution ────────────────────────────────────────────────────────────
# Source secrets file first (local dev); process env wins if already set.
[ -f ~/.gsai/secrets.env ] && source ~/.gsai/secrets.env

# ══════════════════════════════════════════════════════════════════════════════
# run_perplexity — returns 0 on success (prints findings to stdout), 2 on failure
# ══════════════════════════════════════════════════════════════════════════════
run_perplexity() {
  local MODEL="sonar-pro"
  local PAYLOAD
  PAYLOAD=$(python3 -c "
import json, sys
topic, recency, model = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    'model': model,
    'search_recency_filter': recency,
    'messages': [
        {'role': 'system', 'content': (
            'You are a research assistant for a content studio. '
            'Return thorough, cited findings on the topic. '
            'Structure your response as: key findings (3-5 bullet points with '
            'source citations inline as [1], [2], etc.), followed by a numbered '
            'citation list with full URLs. Be specific and data-driven. '
            'Focus on actionable insights for content creators.')},
        {'role': 'user', 'content': topic},
    ],
}))
" "$TOPIC" "$RECENCY_FILTER" "$MODEL")

  local RAW HTTP_STATUS BODY
  RAW=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
    -X POST "https://api.perplexity.ai/chat/completions" \
    -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  HTTP_STATUS=$(echo "$RAW" | grep '__HTTP_STATUS__' | sed 's/__HTTP_STATUS__//')
  BODY=$(echo "$RAW" | grep -v '__HTTP_STATUS__' | head -c 500000)

  if [ "$HTTP_STATUS" != "200" ]; then
    echo "WARN: Perplexity API returned HTTP $HTTP_STATUS" >&2
    echo "$BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin); m = d.get('error', {}).get('message', '')
    print(m or json.dumps(d, indent=2))
except Exception: pass
" 2>/dev/null >&2 || true
    return 2
  fi

  BODY="$BODY" python3 - "$TOPIC" "$RECENCY_FILTER" <<'PYEOF'
import sys, json, os
topic, recency = sys.argv[1], sys.argv[2]
try:
    data = json.loads(os.environ["BODY"])
except json.JSONDecodeError as e:
    print(f"ERROR: Failed to parse API response: {e}", file=sys.stderr); sys.exit(2)
content = data['choices'][0]['message']['content']
citations = data.get('citations', [])
print(f"# Research: {topic}")
print(f"# Provider: Perplexity sonar-pro | Recency: {recency}")
print("=" * 72); print(); print("## Research Findings"); print(); print(content)
if citations:
    print(); print("## Citations"); print()
    for i, url in enumerate(citations, 1): print(f"[{i}] {url}")
print(); print("## Suggested Brand Insights"); print()
print("Review the findings above and consider:")
print("- Which trends are most relevant to this brand's audience?")
print("- What content angles emerge from the cited data?")
print("- Are there statistics or claims worth fact-checking before publishing?")
PYEOF
}

# ══════════════════════════════════════════════════════════════════════════════
# run_firecrawl — returns 0 on success (prints findings to stdout), 2 on failure
# ══════════════════════════════════════════════════════════════════════════════
run_firecrawl() {
  if [ "$RECENCY_FILTER" != "week" ]; then
    echo "NOTE: --recency is not natively supported by Firecrawl search and will be ignored." >&2
  fi
  local PAYLOAD
  PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'query': sys.argv[1], 'limit': 5}))
" "$TOPIC")

  local RAW HTTP_STATUS BODY
  RAW=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
    -X POST "https://api.firecrawl.dev/v1/search" \
    -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  HTTP_STATUS=$(echo "$RAW" | grep '__HTTP_STATUS__' | sed 's/__HTTP_STATUS__//')
  BODY=$(echo "$RAW" | grep -v '__HTTP_STATUS__' | head -c 500000)

  if [ "$HTTP_STATUS" != "200" ]; then
    echo "WARN: Firecrawl API returned HTTP $HTTP_STATUS" >&2
    echo "$BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin); m = d.get('error', d.get('message', ''))
    print(m or json.dumps(d, indent=2))
except Exception: pass
" 2>/dev/null >&2 || true
    return 2
  fi

  BODY="$BODY" python3 - "$TOPIC" <<'PYEOF'
import sys, json, os
topic = sys.argv[1]
try:
    data = json.loads(os.environ["BODY"])
except json.JSONDecodeError as e:
    print(f"ERROR: Failed to parse API response: {e}", file=sys.stderr); sys.exit(2)
results = data.get('data', [])
if not results:
    print("ERROR: No results returned from Firecrawl search.", file=sys.stderr); sys.exit(2)
print(f"# Research: {topic}")
print("# Provider: Firecrawl /v1/search | Recency: best-effort (not natively filtered)")
print("=" * 72); print(); print("## Research Findings"); print()
for i, r in enumerate(results, 1):
    title = r.get('title', 'Untitled'); url = r.get('url', '')
    snippet = (r.get('markdown') or r.get('description') or '').strip()
    if len(snippet) > 600: snippet = snippet[:600].rsplit(' ', 1)[0] + '…'
    print(f"- **{title}** [{i}]")
    if snippet: print(f"  {snippet}")
    print()
print(); print("## Citations"); print()
for i, r in enumerate(results, 1):
    print(f"[{i}] {r.get('title', 'Untitled')} — {r.get('url', '')}")
print(); print("## Suggested Brand Insights"); print()
print("Review the findings above and consider:")
print("- Which trends are most relevant to this brand's audience?")
print("- What content angles emerge from the cited data?")
print("- Are there statistics or claims worth fact-checking before publishing?")
PYEOF
}

# ── orchestration: provider selection + runtime fallback ──────────────────────
HAVE_PPLX=0; HAVE_FC=0
[ -n "${PERPLEXITY_API_KEY:-}" ] && HAVE_PPLX=1
[ -n "${FIRECRAWL_API_KEY:-}" ] && HAVE_FC=1

if [ "$HAVE_PPLX" = "0" ] && [ "$HAVE_FC" = "0" ]; then
  echo "ERROR: No research API key found. Set one of:" >&2
  echo "" >&2
  echo "  PERPLEXITY_API_KEY  (preferred — sonar-pro, native recency filtering)" >&2
  echo "    Get key:   https://www.perplexity.ai/settings/api" >&2
  echo "  FIRECRAWL_API_KEY   (fallback — web search, --recency ignored)" >&2
  echo "    Get key:   https://www.firecrawl.dev" >&2
  echo "" >&2
  echo "  Local dev:  add to ~/.gsai/secrets.env" >&2
  echo "  Fly.io:     fly secrets set PERPLEXITY_API_KEY=pplx-... (or FIRECRAWL_API_KEY=fc-...)" >&2
  echo "  VPS hst:    add to /opt/cfw-agent/.env" >&2
  exit 1
fi

if [ "$HAVE_PPLX" = "1" ]; then
  echo "Provider: perplexity | Topic: $TOPIC | Recency: $RECENCY_FILTER" >&2; echo "" >&2
  if run_perplexity; then exit 0; fi
  if [ "$HAVE_FC" = "1" ]; then
    echo "Perplexity failed — falling back to Firecrawl." >&2; echo "" >&2
    echo "Provider: firecrawl (fallback) | Topic: $TOPIC" >&2; echo "" >&2
    run_firecrawl && exit 0 || exit 2
  fi
  exit 2
else
  echo "Provider: firecrawl | Topic: $TOPIC" >&2; echo "" >&2
  run_firecrawl && exit 0 || exit 2
fi
