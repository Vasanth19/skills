---
name: c-research
description: Dual-provider web research for the creative studio. Prefers Perplexity sonar-pro when available; falls back to Firecrawl search automatically. Use for strategy research, trend discovery, cited web research, competitive intelligence, and grounding content ideas with real-world findings. Returns structured cited findings with source URLs in a consistent format regardless of provider.
when_to_use: Trigger on research, strategy research, Perplexity, sonar, web research, firecrawl, topic research, find sources, trend analysis, competitive research, fact check, grounded insights, market research, content strategy research, what is happening with.
allowed-tools: Bash
kind: component
visibility: internal
---

# Studio Research — Dual-Provider Web Research

> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

## Caller Variables

| Variable | Required | Source | Description |
|----------|----------|--------|-------------|
| `$TOPIC` | Yes | Caller | The research question or topic to investigate |
| `$RECENCY_FILTER` | No | Caller (default: `week`) | Recency filter: `day`, `week`, `month` — Perplexity only; ignored by Firecrawl |
| `$PERPLEXITY_API_KEY` | Preferred | `~/.gsai/secrets.env` or process env | Perplexity API key (sonar-pro, native recency) |
| `$FIRECRAWL_API_KEY` | Fallback | `~/.gsai/secrets.env` or process env | Firecrawl API key (web search, recency best-effort) |

## Provider Selection — Fail Fast

```bash
# Source secrets file first (local dev path)
[ -f ~/.gsai/secrets.env ] && source ~/.gsai/secrets.env

# Provider priority: Perplexity > Firecrawl > fail
if [ -n "${PERPLEXITY_API_KEY:-}" ]; then
  PROVIDER="perplexity"
elif [ -n "${FIRECRAWL_API_KEY:-}" ]; then
  PROVIDER="firecrawl"
else
  echo "ERROR: No research API key found. Set one of:" >&2
  echo "  PERPLEXITY_API_KEY  — ~/.gsai/secrets.env | fly secrets | /opt/cfw-agent/.env" >&2
  echo "  FIRECRAWL_API_KEY   — ~/.gsai/secrets.env | fly secrets | /opt/cfw-agent/.env" >&2
  exit 1
fi
```

> **Current state (2026-06-01):** `PERPLEXITY_API_KEY` is NOT provisioned; `FIRECRAWL_API_KEY` IS set in `~/.gsai/secrets.env`. The skill runs via Firecrawl automatically. When a Perplexity key is added, the skill will use it without any code changes.

## Perplexity Path (sonar-pro)

- Full LLM synthesis with inline citations `[1]`, `[2]`, etc.
- Native `--recency day|week|month` filtering via `search_recency_filter`.
- Returns `choices[0].message.content` + `citations[]` array.

## Firecrawl Path (/v1/search)

- Endpoint: `POST https://api.firecrawl.dev/v1/search`
- Auth: `Authorization: Bearer $FIRECRAWL_API_KEY`
- Body: `{"query": "<topic>", "limit": 5}`
- Returns `data[]` with `url`, `title`, `markdown`/`description` per result.
- Output is normalized to the same cited-findings shape as the Perplexity path.
- `--recency` flag is accepted but ignored (Firecrawl does not support server-side recency filtering on `/v1/search`).

## Output Format

Both providers emit the same three-section structure:

```
# Research: <topic>
# Provider: <Perplexity sonar-pro | Firecrawl /v1/search> | Recency: <value>
════════════════════════════════════════════════════════════════════════════

## Research Findings
<cited findings — bullets with [1], [2] inline citations>

## Citations
[1] <Title> — <URL>
[2] <Title> — <URL>

## Suggested Brand Insights
<3 reflection prompts for the Director to use when shaping a content angle>
```

## CLI Usage

```bash
# Basic
bash /Users/vasanth/Code/skills/c-research/research.sh "content marketing trends 2026"

# With recency (Perplexity only; silently ignored on Firecrawl)
bash /Users/vasanth/Code/skills/c-research/research.sh "AI video tools landscape" --recency month

# Test: no args → usage
bash /Users/vasanth/Code/skills/c-research/research.sh

# Test: no keys → fail-fast naming both vars
env -u PERPLEXITY_API_KEY -u FIRECRAWL_API_KEY bash /Users/vasanth/Code/skills/c-research/research.sh "test"
```

## Director Integration (case 22 — strategy chat)

When Aria is handling a strategy question:
1. Ask the user: "Want me to research this topic first?"
2. On yes → invoke `c-research` with the topic as `$TOPIC`
3. Synthesize findings into a grounded reply citing sources
4. Optionally surface "Suggested Brand Insights" for the user to act on

> **Insight write-back:** Findings can be stored as brand topic atoms via the MCP back-channel (`record_insight` tool in cfw-social). Future enhancement — for now, the Director summarizes findings inline. See `05-BRAND-VAULT` for the full brand-vault design.

## Recency Filter Guide

| Filter | Use When | Perplexity | Firecrawl |
|--------|----------|-----------|-----------|
| `day` | Breaking news, live events | Supported | Ignored |
| `week` | General strategy (default) | Supported | Ignored |
| `month` | Evergreen, seasonal planning | Supported | Ignored |

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.
