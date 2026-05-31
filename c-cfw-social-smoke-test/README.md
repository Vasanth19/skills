# c-cfw-social-smoke-test

Smoke-test runner for the cfw-social HTTP API (`smoke.mjs` + `routes.json` + `SKILL.md`) — used to confirm no route 5xx's after a deploy.

> **See also:** [`c-cfw-agent`](../c-cfw-agent/) — caller's guide for the cfw-agent MCP (`cfw_run` tool).

---

## Folder contents

| File | What it is | Read it for |
|---|---|---|
| `README.md` | this file | A first-time overview |
| `SKILL.md` | Frontmatter + smoke-runner docs | "How do I confirm cfw-social isn't 5xx'ing after my route changes?" |
| `smoke.mjs` | Node script that hits every cfw-social route | The actual runner; called by `SKILL.md` instructions |
| `routes.json` | Manifest of every cfw-social route + auth mode + sample body | Hand-curated; edit after route changes (bump `_version`) |

---

## Which one do you need?

| You want to… | Use |
|---|---|
| Confirm cfw-social's API didn't break after your changes | `SKILL.md` → `smoke.mjs` |

---

## Quick start: testing the cfw-agent MCP

### Prerequisites
- cfw-social running on `http://localhost:3000` (or prod).
- `$CFW_MASTER_API_KEY` from `cfw-social/.env`.
- `$CFW_BRAND_ID` from your local Postgres.

### Quick smoke

```bash
node /Users/vasanth/Code/skills/c-cfw-social-smoke-test/smoke.mjs \
  --base-url=http://localhost:3000 \
  --api-key="$CFW_MASTER_API_KEY" \
  --brand-id="$CFW_BRAND_ID"
```

---

## Tool surface — `cfw_run`

Single tool, one required arg (`brandId`) and one required prompt:

```json
{
  "name": "cfw_run",
  "inputSchema": {
    "type": "object",
    "required": ["brandId", "prompt"],
    "properties": {
      "brandId":        { "type": "string" },
      "prompt":         { "type": "string" },
      "agentId":        { "type": "string", "description": "Optional curated Agent within the brand's workspace" },
      "workspaceId":    { "type": "string" },
      "sources":        { "type": "array",  "items": { "type": "object" } },
      "allowedSkills":  { "type": "array",  "items": { "type": "string" } },
      "allowDiscovery": { "type": "boolean" },
      "model":          { "type": "string", "description": "Override LLM_MODEL (default Kimi K2.6)" }
    }
  }
}
```

Returns `structuredContent` with `reply`, `outputs` (R2 URLs), `toolCalls`, `stages`, `tokensIn`, `tokensOut`, `costUsd`.

---

## Resources — read these before chatting

Three MCP resources surface the skill catalog so the calling agent never "chats blind":

| URI | Source file | What's in it |
|---|---|---|
| `cfw://catalog/agent-guide` | `~/Code/skills/AGENT-GUIDE.md` | Three-step workflow + decision tree |
| `cfw://catalog/skills-catalog` | `~/Code/skills/SKILLS-CATALOG.md` | Every skill by output type, with inputs/outputs/when-to-use |
| `cfw://catalog/skills-json` | `~/Code/skills/skills.json` | JSON index with search-by-output-type / by-AI-method |

Read them via:

```bash
curl -s -X POST http://localhost:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"cfw://catalog/skills-catalog"}}' \
  | jq -r '.result.contents[0].text'
```

From Claude Code, just ask: *"List the cfw-agent-local MCP resources and read the skills-catalog."*

---

## Ten example prompts to try

Full list with placeholders is in `mcp.md` §6. Short recap of what each tests:

| # | What it tests | Skill the agent should pick |
|---|---|---|
| 1 | Single photo enhancement with brand frame | `c-html-gfx` + `c-ffmpeg` |
| 2 | 4-photo carousel with brand frame | `c-html-gfx` (batch) |
| 3 | Text quote → Twitter card | `c-html-gfx` |
| 4 | Long quote → 5-slide LinkedIn carousel | `p-linkedin-carousel` |
| 5 | Transcript → ElevenLabs voiceover + music + video | `c-studio-audio` + `c-ffmpeg` |
| 6 | Script → 9:16 reel with HeyGen avatar | `p-avatar-short` |
| 7 | Script → 9:16 faceless GFX reel | `p-gfx-short` |
| 8 | Audio file → transcript + captions | `c-studio-audio` (Mac-only today; fails in Linux container until Groq swap) |
| 9 | Video → Post for Me publish | `r-cfw-publisher` or `r-social-post-postforme` |
| 10 | Capability discovery (zero compute) | (none — exercises `resources/*`) |

**Pre-flight for #5–7:** voice_id / avatar_id come from `/Users/vasanth/Code/cfw/cfw-social/creatives/brand-guidelines/<brand-slug>/brand-ref.md` — verify your target brand has one filled in, or inline the IDs in the prompt.

---

## Common errors and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `error: missing required argument 'commandOrUrl'` when running `claude mcp add` | URL placed after flags instead of right after name | Put the URL second: `claude mcp add <name> <url> --transport http -H "..."` |
| `curl: (7) Failed to connect to localhost:8081` | cfw-agent not running | `cd ~/Code/cfw/cfw-agent && pnpm tsx --env-file=.env src/server.ts &` |
| `result.isError: true, "Error: unknown_brand"` | `brandId` doesn't exist in your local Postgres | `psql cfw_social_dev -c "SELECT id, slug FROM brands LIMIT 10;"` and pick a real one |
| `result.isError: true, "Error: invalid_api_key"` | The `x-api-key` header value doesn't match any active `api_keys` row for that brand | Check the brand has at least one active key: `psql cfw_social_dev -c "SELECT prefix, name, active FROM api_keys WHERE brand_id='<brandId>';"` — if empty or inactive, generate a new key from the API Keys settings page and update the MCP registration |
| `cfw-agent-local` not visible in fresh Claude Code window | Window was open before registration | Close and reopen Claude Code (user-scope MCPs are loaded at startup) |
| Skill subprocess fails with `mlx_whisper: command not found` | Stale skill file — predates the `cfw-transcribe` swap (05-STT, 2026-05-31) | Re-pull `/Users/vasanth/Code/skills/`; use case #8 should now pass via Gemini (`cfw-transcribe` helper) in container and via the MLX fast-path on macOS. <!-- 05-STT: cloud STT replaces Mac-only mlx_whisper --> |
| `c-studio-audio` works locally but skill needs a voice_id | Skill reads from `brand-ref.md`; that brand's file may be missing or empty | Check `/Users/vasanth/Code/cfw/cfw-social/creatives/brand-guidelines/<slug>/brand-ref.md` |

---

## Local vs production

| Concern | Local (`http://localhost:8081/mcp`) | Production (`https://agent.cfw.social/mcp`) |
|---|---|---|
| Runtime | host `pnpm tsx` or `docker compose` | Railway |
| Postgres | local `:5432/cfw_social_dev` | Neon (us-east-1) |
| Default LLM | from your `.env` (currently Kimi K2.6) | from Railway env |
| Skill source | `/Users/vasanth/Code/skills/` via `SKILLS_DIR` | container `/home/node/.claude/skills` (synced at startup) |
| Brand keys | local seeded keys (won't work in prod) | provisioned per-tenant in production cfw-social |
| Cost ceiling | your local API budget | Railway-side limits + provider quotas |

Brand API keys (stored in the `api_keys` table, bcrypt-verified server-side) are environment-scoped. A key seeded in local dev won't exist in production and vice versa — never copy a local key and try it against prod. Generate and register the appropriate key for each environment.

---

## Smoke-test runner

If you came here for the *cfw-social* route smoke, the runner lives at `smoke.mjs` and the manifest at `routes.json`. Quick recipe:

```bash
node /Users/vasanth/Code/skills/c-cfw-social-smoke-test/smoke.mjs \
  --base-url=http://localhost:3000 \
  --api-key="$CFW_MASTER_API_KEY" \
  --brand-id="$CFW_BRAND_ID"
```

Full docs: `SKILL.md` (frontmatter, flags, recipes, failure triage).

This is the **cfw-social master-key path**, not the cfw-agent MCP. Don't confuse the two — they use different auth headers (`cfw-api-key` vs `x-api-key`) and target different services.

---

## Shipping this to a teammate

Two things they need:

1. The folder `~/Code/skills/c-cfw-social-smoke-test/` (drop into their `~/Code/skills/` or `~/.claude/skills/`).
2. A working `CFW_MASTER_API_KEY` + `CFW_BRAND_ID` pair.

For MCP access, point them at `c-cfw-agent/README.md` instead.

---

## Related docs

- `cfw-agent/CLAUDE.md` — cfw-agent service architecture
- `~/Code/skills/c-cfw-agent/README.md` — cfw-agent MCP caller guide
- `cfw-social/docs/orchestrator-contract-v1.md` — the frozen SSE contract
