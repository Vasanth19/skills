# CFW Social — External Agent API Quickstart

How to call the CFW Social API from an **external agent, script, or automation** using a brand-scoped API key. No browser session required.

---

## The Right Surface: `/api/v2/` (Hono) + allowlisted `/api/v1/` routes

> **Use `/api/v2/*` for the content workflow (workspaces → runs → outputs → posts).**
> **Use the allowlisted `/api/v1/*` routes for brand management** (agent provisioning, quick publish, provider vault, API-key minting) — these have no v2 equivalent.

Most `/api/v1/*` routes are blocked by the Next.js middleware for non-session traffic (307 → /login), **but a specific allowlist of brand-management routes accepts `x-api-key` auth** (see "Full Brand Management" below). Since 2026-06-02 (PR #49), an external agent holding a brand key can **fully provision and operate a brand headlessly** — only billing, `/agents/rig-up`, and account deletion remain session-only.

`/api/v2/*` is a Hono catch-all tagged `api-or-session` — all routes accept `x-api-key` auth.

| Surface | Auth | When to use |
|---|---|---|
| `https://app.cfw.social/api/v2/*` | `x-api-key: cfw_xxx` | Content workflow: workspaces, runs, outputs, posts |
| `https://app.cfw.social/api/v1/*` (allowlisted) | `x-api-key: cfw_xxx` | Brand management: create agents, quick publish, provider vault, mint keys |
| `https://app.cfw.social/api/v1/mcp` | `x-api-key: cfw_xxx` | MCP protocol clients (cfw-agent, Claude Desktop) |
| `https://app.cfw.social/api/v1/*` (everything else) | Session cookie only | Browser UI |

---

## Auth

Get your brand-scoped API key from **Settings → API Keys** in the UI, or mint one via the master key:

```bash
curl -s -X POST https://app.cfw.social/api/v1/api-keys \
  -H "cfw-api-key: $CFW_MASTER_API_KEY" \
  -H "x-cfw-brand: $BRAND_ID" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-agent"}'
# { "key": { "plain": "cfw_xxxxxxxx...", ... } }
# Save the plain value — shown once
```

Use it on every request:

```bash
x-api-key: cfw_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

`Authorization: Bearer cfw_xxx` also works.

---

## Base URL

```
https://app.cfw.social
```

For local dev tunnel (same API, local DB):

```
https://v2.cfw.social
```

---

## Core Workflow: Run an Agent

The typical external agent flow is: **workspace → agent → run → poll SSE → read outputs**.

### 1. List workspaces

```bash
curl -s https://app.cfw.social/api/v2/workspaces/list \
  -H "x-api-key: $BRAND_KEY"
# [{ "id": "ws_...", "name": "...", "status": "active" }, ...]
```

### 2. Create a workspace (if needed)

```bash
curl -s -X POST https://app.cfw.social/api/v2/workspaces \
  -H "x-api-key: $BRAND_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Podcast Episode 42"}'
# { "workspace": { "id": "ws_...", "name": "Podcast Episode 42" } }
```

### 3. Add a source

```bash
curl -s -X POST https://app.cfw.social/api/v2/workspaces/$WORKSPACE_ID/sources \
  -H "x-api-key: $BRAND_KEY" \
  -H "Content-Type: application/json" \
  -d '{"kind":"url","url":"https://example.com/transcript.txt","name":"ep42 transcript"}'
```

### 4. Start a run

```bash
RUN_RES=$(curl -s -X POST https://app.cfw.social/api/v2/runs \
  -H "x-api-key: $BRAND_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "workspaceId": "'$WORKSPACE_ID'",
    "agentId": "'$AGENT_ID'",
    "prompt": "Turn this transcript into a LinkedIn carousel and 3 short-form posts"
  }')
RUN_ID=$(echo "$RUN_RES" | jq -r .runId)
```

### 5. Stream events (SSE)

```bash
curl -N -s "https://app.cfw.social/api/v2/runs/$RUN_ID/events" \
  -H "x-api-key: $BRAND_KEY"
```

SSE frames follow the frozen v1 contract:

| Event | Meaning |
|---|---|
| `stage` | Agent progress step description |
| `agent.message` | Text output from the agent |
| `tool.call` | Skill invocation detail |
| `asset.created` | An output was produced (has `cdnUrl`) |
| `run.ready` | Run completed; approval token issued if applicable |
| `done` | Stream finished |
| `error` | Fatal error; stream closes |

Use `?since=<seq>` to replay missed events after reconnection.

### 6. Read outputs

```bash
curl -s "https://app.cfw.social/api/v2/workspaces/$WORKSPACE_ID/outputs" \
  -H "x-api-key: $BRAND_KEY"
# [{ "id": "out_...", "kind": "video", "cdnUrl": "https://...", "mimeType": "video/mp4" }, ...]
```

---

## Full Route Catalog (api/v2)

All routes accept `x-api-key` (brand-scoped).

### Runs

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v2/runs` | Start a run |
| `GET` | `/api/v2/runs/:id/events` | SSE stream (`?since=<seq>` for replay) |

**POST /api/v2/runs body:**
```jsonc
{
  "workspaceId": "ws_...",
  "agentId": "ag_...",
  "prompt": "string",
  "sources": [],            // optional — override workspace sources for this run
  "model": "claude-sonnet-4-6"  // optional
}
```

### Workspaces

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v2/workspaces/list` | List all workspaces for brand |
| `POST` | `/api/v2/workspaces` | Create workspace |
| `PATCH` | `/api/v2/workspaces/:id` | Rename workspace (`{"name":"..."}`) |
| `GET` | `/api/v2/workspaces/:id/outputs` | All outputs across all runs |
| `GET` | `/api/v2/workspaces/:id/runs` | All runs in workspace |
| `GET` | `/api/v2/workspaces/:id/posts` | Posts created from this workspace |
| `GET` | `/api/v2/workspaces/:id/assets` | Raw assets |
| `GET` | `/api/v2/workspaces/:id/sources` | Source list |
| `POST` | `/api/v2/workspaces/:id/sources` | Add source |
| `DELETE` | `/api/v2/workspaces/:id/sources?sourceId=...` | Remove source |

**Source kinds:** `url` · `text` · `file` · `transcript` · `doc` · `image` · `video`

### Skills

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v2/skills` | Skill catalog (synced from cfw-agent) |

### Agents

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v2/agents` | **List all agents for the brand** (id, name, description, model, allowDiscovery, skillCount, isDirector, createdAt) |
| `GET` | `/api/v2/agents/:id` | **Full agent config** — incl. `allowedSkills[]` + sanitized `instructions` |
| `GET` | `/api/v2/agents/:id/instructions` | **Just the instructions** (`{ agentId, name, model, instructions }`) |
| `POST` | `/api/v2/agents` | Create agent under a workspace |
| `POST` | `/api/v2/agents/:id/skills` | Add a skill to agent curation |
| `DELETE` | `/api/v2/agents/:id/skills` | Remove skill from curation |
| `PUT` | `/api/v2/agents/:id/discovery` | Toggle `allowDiscovery` |

#### Reading agent instructions

Any brand-key holder can enumerate the brand's agents and read each agent's
configuration — including its **instructions** (the system-prompt persona) — so
another runtime can reproduce or "communicate as" that agent.

```bash
# 1. List the brand's agents
curl -s https://app.cfw.social/api/v2/agents -H "x-api-key: $BRAND_KEY"
# { "agents": [
#     { "id":"ag_...", "name":"Creative Director", "description":"...",
#       "model":"claude-sonnet-4-6", "allowDiscovery":true,
#       "skillCount":12, "isDirector":true, "createdAt":"2026-05-…" }, ... ] }

# 2. Full config for one agent (instructions + curated skills)
curl -s https://app.cfw.social/api/v2/agents/$AGENT_ID -H "x-api-key: $BRAND_KEY"
# { "id","name","description","model","allowDiscovery","isDirector",
#   "allowedSkills":["p-vsl","c-broll", ...],
#   "instructions":"You are a VSL Writer. …",   // null if none set
#   "createdAt":"…" }

# 3. Just the instructions (lighter payload)
curl -s https://app.cfw.social/api/v2/agents/$AGENT_ID/instructions -H "x-api-key: $BRAND_KEY"
# { "agentId","name","model","instructions":"…" }
```

**Notes**
- `instructions` maps to the internal `Agent.systemPromptOverride` column.
- It is **sanitized at the read boundary** via `scanAndCapPersona()` (8000-char cap
  + prompt-injection scrub + audit) — identical to the internal MCP
  `get_agent_config` tool. You never receive a raw, unscrubbed persona.
- `isDirector` is true when the agent is the brand's locked Creative Director
  (`Brand.directorAgentId`).
- Cross-brand or unknown `agentId` → `404 { "error": "Agent not found" }`
  (existence is never leaked across tenants).

---

## Full Brand Management (v1 surface — brand-key enabled 2026-06-02)

These routes live on **`/api/v1/`** (not v2) but are proxy-allowlisted and handler-authenticated
via `requireApiBrand`, so a brand key (`x-api-key` / `Authorization: Bearer`) works headlessly.
With these + the v2 content routes, an external agent can **fully provision and operate a brand**.

### Create an agent (specialist roster)

```bash
curl -s -X POST https://app.cfw.social/api/v1/agents \
  -H "x-api-key: $BRAND_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "VSL Writer",
    "skillNames": ["p-vsl", "r-cfw-publisher"],
    "persona": "You write punchy VSL scripts in the brand voice.",
    "allowDiscovery": false
  }'
# 201 { "agentId": "ag_..." }
```

Body: `name?`, `skillNames[]` (validated against the synced skill catalog; idempotent binding),
`persona?` (becomes `systemPromptOverride`), `allowDiscovery?` (defaults: `true` when no skills,
`false` when skills given), `workspaceId?`.

> ⚠️ `/api/v1/agents/rig-up` (standard-crew rig-up) remains **session-only** by design.

### Quick publish (multi-platform, one call)

```bash
curl -s -X POST https://app.cfw.social/api/v1/posts/quick \
  -H "x-api-key: $BRAND_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "platforms": ["instagram", "linkedin"],
    "captionsByPlatform": { "instagram": "IG caption ✨", "linkedin": "LI caption" },
    "mediaUrls": ["https://r2.../image.png"],
    "kind": "image",
    "saveAsDraft": false
  }'
# { "count": 2, "scheduled": 2, "drafted": 0, "failed": 0,
#   "posts": [{ "id": "post_...", "platform": "instagram", "status": "scheduled", "scheduledAt": "..." }, ...] }
```

Behavior: each platform gets its own `Post` row. Platforms with an active `PlatformConnection` +
PostTiming rules are **scheduled** via Post for Me; platforms without a connection (or with
`saveAsDraft: true`) are saved as **drafts** — nothing is ever silently skipped. Per-platform PFM
failures mark that post `failed` and continue with the rest.

### Provider key vault (brand-secrets)

The vault stores per-brand provider API keys (HeyGen, ElevenLabs, etc.), AES-256-GCM encrypted.
Brand-key callers get **full read + write + delete** (owner decision 2026-06-02 — the brand key IS
brand authority). In session mode, only `role = owner` may touch the vault.

```bash
# List (masked hints only — never plaintext over REST)
curl -s https://app.cfw.social/api/v1/brand-secrets -H "x-api-key: $BRAND_KEY"
# { "secrets": [{ "provider": "heygen", "envVar": "HEYGEN_API_KEY", "known": true,
#                 "maskedHint": "••••a1b2", "createdAt": "...", "lastUsedAt": "..." }] }

# Upsert one provider key
curl -s -X PUT https://app.cfw.social/api/v1/brand-secrets \
  -H "x-api-key: $BRAND_KEY" -H "Content-Type: application/json" \
  -d '{ "provider": "heygen", "value": "hg_xxxxxxxxxxxxxxxx" }'
# { "ok": true, "provider": "heygen" }

# Delete one provider
curl -s -X DELETE https://app.cfw.social/api/v1/brand-secrets/heygen \
  -H "x-api-key: $BRAND_KEY"
```

**Known providers** (canonical env-var mapping): `heygen` → `HEYGEN_API_KEY`, `elevenlabs` →
`ELEVENLABS_API_KEY`, `kie` → `KIE_AI_API_KEY`, `perplexity` → `PERPLEXITY_API_KEY`, `replicate` →
`REPLICATE_API_TOKEN`, `gemini` → `GEMINI_API_KEY`, `fal` → `FAL_KEY`. **Custom providers** are
allowed (kebab-case name → derived `<NAME>_API_KEY`), except deny-listed names/prefixes that would
collide with CFW infrastructure (`R2_`, `LLM_`, `ANTHROPIC_`, `CFW_`).

**MCP equivalents** (via `/api/v1/mcp`, registered in ALL auth modes since 2026-06-02):
- `get_brand_secrets` — returns **decrypted plaintext** keys (MCP only; REST never returns plaintext)
- `set_brand_secret` — encrypt + upsert

> ⚠️ Security note: a leaked brand key can exfiltrate stored provider keys via MCP
> `get_brand_secrets`. This is an accepted, documented risk; `secret_access_log` is the planned
> mitigation. Treat brand keys with the same care as the provider keys themselves.

### Mint / revoke API keys

```bash
# Mint a brand key using the master key
curl -s -X POST https://app.cfw.social/api/v1/api-keys \
  -H "cfw-api-key: $CFW_MASTER_API_KEY" -H "x-cfw-brand: $BRAND_ID" \
  -H "Content-Type: application/json" -d '{"name":"my-agent"}'
# GET /api/v1/api-keys (list) and DELETE /api/v1/api-keys/{id} (revoke) also accept key auth
```

### What stays session-only (intentionally)

| Route | Why |
|---|---|
| `POST /api/v1/billing/checkout`, `/billing/portal` | A leaked brand key must not change the plan |
| `POST /api/v1/agents/rig-up` | Standard-crew rig-up is an owner UI action |
| `POST /api/v1/me/delete-account` | Account deletion requires a logged-in human |

---

### Posts

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v2/posts/list` | List posts (`?status=draft\|scheduled\|published\|failed`) |
| `GET` | `/api/v2/posts/calendar` | Posts in date range (`?from=&to=`) |
| `GET` | `/api/v2/posts/count` | Count by status (badge data) |
| `GET` | `/api/v2/posts/:id` | Single post detail |
| `PATCH` | `/api/v2/posts/:id` | Update caption / scheduledAt |
| `DELETE` | `/api/v2/posts/:id` | Delete post |

### Brand

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v2/brands/mine` | Brands accessible to this key |
| `GET` | `/api/v2/brand/dna` | Voice, tone, audience, keywords |
| `PUT` | `/api/v2/brand/dna` | Update DNA fields |
| `GET` | `/api/v2/brand/:id/context` | Full brand context (for agent prompting) |
| `GET` | `/api/v2/brands/:id/insights` | BrandInsight rows |

### Inbox / Approvals

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v2/inbox/approve` | Approve composition (requires signed token) |
| `POST` | `/api/v2/inbox/reject` | Reject with optional reason |

---

## Python Example (minimal)

```python
import httpx, json

BASE = "https://app.cfw.social"
KEY  = "cfw_xxxxxxxxxxxxxxxx"

headers = {"x-api-key": KEY, "Content-Type": "application/json"}

# List workspaces
ws = httpx.get(f"{BASE}/api/v2/workspaces/list", headers=headers).json()
workspace_id = ws[0]["id"]

# Start a run
run = httpx.post(f"{BASE}/api/v2/runs", headers=headers, json={
    "workspaceId": workspace_id,
    "agentId": "<ag_id>",
    "prompt": "Repurpose this into 5 LinkedIn posts"
}).json()

# Stream SSE
with httpx.stream("GET", f"{BASE}/api/v2/runs/{run['runId']}/events", headers=headers) as r:
    for line in r.iter_lines():
        if line.startswith("data:"):
            event = json.loads(line[5:].strip())
            print(event)
```

---

## TypeScript / Node Example

```typescript
const BASE = "https://app.cfw.social";
const KEY  = process.env.CFW_API_KEY!;

const h = { "x-api-key": KEY, "Content-Type": "application/json" };

// Start run
const { runId } = await fetch(`${BASE}/api/v2/runs`, {
  method: "POST",
  headers: h,
  body: JSON.stringify({ workspaceId, agentId, prompt }),
}).then(r => r.json());

// Consume SSE
const res = await fetch(`${BASE}/api/v2/runs/${runId}/events`, { headers: h });
const reader = res.body!.getReader();
const decoder = new TextDecoder();

for await (const chunk of readableStream(reader)) {
  const text = decoder.decode(chunk);
  for (const line of text.split("\n")) {
    if (line.startsWith("data:")) {
      const event = JSON.parse(line.slice(5).trim());
      console.log(event);
    }
  }
}
```

---

## Common Errors

| Error | Cause | Fix |
|---|---|---|
| `307 → /login` | Using a NON-allowlisted `/api/v1/*` route with API key | Use the `/api/v2/*` equivalent, or one of the allowlisted v1 brand-management routes above |
| `401 Not authenticated` | Missing/wrong key on an allowlisted route | Check the `x-api-key` header value |
| `401 invalid_api_key` | Wrong key or key revoked | Re-mint from Settings → API Keys |
| `403 owner_only` | Session (browser) caller without owner role hitting the vault | Vault via UI requires `role = owner`; brand-key callers are not affected |
| `403 Forbidden` | workspaceId/agentId belongs to different brand | Confirm IDs are for this brand's key |
| `404 Agent not found` | Wrong `agentId` | Use `GET /api/v2/agents` to list this brand's agents |
| `400 invalid_provider` | Vault PUT with deny-listed or malformed provider name | Use a known provider or valid kebab-case custom name |
| SSE stream hangs | curl buffering | Use `curl -N -s` (no-buffer) |

---

## Authoring compositions correctly

Starting a run produces outputs, but **how** the agent shapes those outputs into
platform-correct compositions (image sizes per platform, reel specs, carousel
multi-image flow, per-platform caption formatting) is its own contract. The API does
**no** resizing, cropping, or caption shaping — it stores exactly what you give it, one
platform per composition.

➡️ **See `composition-authoring.md` before calling `propose_composition`.**

## See also

- `composition-authoring.md` — per-platform media specs + caption rules for building compositions
- `auth.md` — full auth cascade theory
- `routes.json` — canonical route inventory
- `local-dev.md` — local dev equiv. patterns
- `c-cfw-agent` skill — how to call the orchestrator (`cfw_run`)
- `cfw-social/docs/orchestrator-contract-v1.md` — SSE event schema spec
