# c-cfw-agent

Quick-start for calling the cfw-agent orchestrator via its MCP.

## What is this?

cfw-agent is the AI orchestrator behind CFW Social. It picks and executes content/media skills (video, audio, image, social distribution) and returns generated outputs as Cloudflare R2 URLs.

This skill teaches you how to **call** cfw-agent from outside — via its MCP endpoint.

## Prerequisites

- cfw-agent running on `http://localhost:8081` (host) or `https://agent.cfw.social` (prod)
- A plaintext `openclawApiKey` for a brand
- `jq` installed (`brew install jq`)

## 30-second smoke test

```bash
# Protocol-only (free, no LLM call, ~1 second)
bash /Users/vasanth/Code/skills/c-cfw-agent/mcp-example.sh --no-tool-call

# Full smoke with LLM (~$0.02, ~3 seconds)
bash /Users/vasanth/Code/skills/c-cfw-agent/mcp-example.sh \
  --base-url=http://localhost:8081 \
  --api-key="$(cd /Users/vasanth/Code/cfw/cfw-agent && pnpm tsx --env-file=.env scripts/decrypt-brand-key.ts e2e-brand-001 2>/dev/null | tail -1)" \
  --brand-id=e2e-brand-001
```

## Register in Claude Code

```bash
# Local
claude mcp add cfw-agent-local http://localhost:8081/mcp \
  --transport http \
  --scope user \
  -H "x-api-key: <PASTE_PLAINTEXT_KEY_HERE>"

# Production
claude mcp add cfw-agent https://agent.cfw.social/mcp \
  --transport http \
  --scope user \
  -H "x-api-key: <PASTE_PLAINTEXT_KEY_HERE>"

# Verify
claude mcp list | grep cfw-agent
```

⚠️ **Argument order matters:** URL must come right after the name, BEFORE flags.

## First prompt

```
Use the cfw-agent-local MCP. Call resources/list, then resources/read on
`cfw://catalog/skills-catalog`. Then call cfw_run with brandId=e2e-brand-001
and prompt="Reply with the word READY and list 3 skills you can run."
Show me what comes back.
```

Expected: `READY` + 3 skill names. Cost: ~$0.02.

## File map

| File | Read for… |
|---|---|
| `README.md` | This file — quick start |
| `mcp.md` | Full caller guide — registration, auth, tool surface, 10 example prompts, error modes, local vs prod |
| `mcp-example.sh` | Bash smoke — CI, first-time verify |
| `cfw-run.md` | Deep dive on `cfw_run` schema, streaming, progress tokens |
| `orchestration-contract.md` | The frozen v1 SSE contract |

## See also

- `c-cfw-social` — manage the CFW Social app itself (data model, lifecycle, operations)
- `c-cfw-social-smoke-test` — smoke-test cfw-social's HTTP API
