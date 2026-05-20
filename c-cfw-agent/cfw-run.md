# cfw_run — Deep Dive

The single tool exposed by cfw-agent's MCP: `cfw_run`. It takes a `brandId` + natural-language `prompt` and returns generated outputs as R2 URLs.

---

## Tool Schema

```json
{
  "name": "cfw_run",
  "title": "Run CFW Agent",
  "description": "Run the CFW Agent — a brand-aware AI orchestrator...",
  "inputSchema": {
    "type": "object",
    "required": ["brandId", "prompt"],
    "properties": {
      "brandId":        { "type": "string", "description": "The brand ID to run under" },
      "prompt":         { "type": "string", "description": "Natural-language instruction" },
      "agentId":        { "type": "string", "description": "Optional curated Agent within the workspace" },
      "workspaceId":    { "type": "string", "description": "Scope the run to a workspace" },
      "sources":        {
        "type": "array",
        "description": "Optional input sources",
        "items": {
          "type": "object",
          "properties": {
            "kind": { "type": "string" },
            "name": { "type": "string" },
            "url": { "type": "string" },
            "metadata": {}
          },
          "required": ["kind", "name", "url"]
        }
      },
      "allowedSkills":  { "type": "array", "items": { "type": "string" }, "description": "Allow-list of skill names" },
      "allowDiscovery": { "type": "boolean", "description": "Allow any global skill" },
      "model":          { "type": "string", "description": "Override LLM (default: Kimi K2.6)" }
    }
  }
}
```

---

## Input Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `brandId` | **Yes** | — | Loads brand DNA, voice, timezone, skill curation |
| `prompt` | **Yes** | — | Natural-language instruction. The agent picks the skill. |
| `agentId` | No | default agent | Pick a curated Agent within the workspace |
| `workspaceId` | No | — | Scope the run to a specific workspace (affects sources + context) |
| `sources` | No | [] | Files/URLs/transcripts to ground the generation |
| `allowedSkills` | No | all skills | Restrict which skills the agent can invoke |
| `allowDiscovery` | No | false | If true, agent can use any global skill regardless of `allowedSkills` |
| `model` | No | `LLM_MODEL` env | Override the LLM (e.g., "claude-opus-4-7") |

---

## Result Shape

### Non-streaming (no `progressToken`)

```json
{
  "content": [{ "type": "text", "text": "Human-readable summary…" }],
  "structuredContent": {
    "reply": "Final assistant text",
    "outputs": [
      {
        "assetId": "asset_cl123",
        "mediaId": "media_cl456",
        "url": "https://media.cfw.social/brand-id/.../output.mp4",
        "mimeType": "video/mp4",
        "kind": "video"
      }
    ],
    "toolCalls": [
      { "name": "run_skill", "ms": 4321, "ok": true }
    ],
    "stages": [
      "Loading brand context…",
      "Running p-gfx-short…",
      "Uploading to R2…"
    ],
    "tokensIn": 6816,
    "tokensOut": 364,
    "costUsd": 0.0259
  },
  "isError": false
}
```

### Streaming (with `progressToken`)

If `_meta.progressToken` is sent in the `tools/call` params, the response is `text/event-stream`:

```
event: message
data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progressToken":1,"progress":1,"message":"stage: Loading brand context"}}

event: message
data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progressToken":1,"progress":2,"message":"assistant: Here's your 5-slide carousel..."}}

event: message
data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progressToken":1,"progress":3,"message":"tool.call: p-gfx-short ok 4200ms"}}

event: message
data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progressToken":1,"progress":4,"message":"asset: video https://media.cfw.social/.../output.mp4"}}

event: message
data: {"jsonrpc":"2.0","id":1,"result":{"content":[...],"structuredContent":{...},"isError":false}}
```

Claude Code automatically requests `progressToken` — you'll see real-time progress in the UI.

---

## Auth

Every `cfw_run` call must carry:

```
x-api-key: <plaintext openclawApiKey>
```

Resolution order (same as `/chat/stream`):
1. `Brand.openclawApiKey` (canonical, WS-01)
2. `TelegramBot.openclawApiKey` (back-compat fallback)

Both are AES-256-GCM encrypted at rest; decrypted at request time with `ENCRYPTION_KEY`.

---

## How `cfw_run` Works Internally

```
1. Caller sends JSON-RPC to POST /mcp
2. cfw-agent validates x-api-key against Brand.openclawApiKey
3. cfw-agent calls cfw-social MCP tool: record_inbound_message
   → gets conversationId
4. cfw-agent builds AgentTurnContext:
   { brandId, conversationId, channel: "web", inboundText: prompt, ... }
5. SonnetAgentLoop.runAgentTurnStream(ctx, onEvent)
   ├── Loads brand context (get_brand, get_brand_dna, get_recent_messages)
   ├── Builds system prompt with skill list
   ├── Calls LLM (Kimi K2.6 by default)
   ├── LLM decides which skill to run
   ├── Skill runner spawns `claude --print` subprocess
   ├── Subprocess executes skill (e.g., p-gfx-short)
   ├── Skill produces file → uploads to R2
   ├── cfw-agent calls attach_output_to_composition MCP tool
   ├── Emits SSE events (stage, tool.call, asset.created, done)
   └── Returns final result
6. cfw-agent formats result as MCP tool response
7. Returns to caller
```

---

## Cost

| Component | Typical Cost |
|---|---|
| Short prompt round-trip | **~$0.02–0.03** (brand context dominates tokens) |
| Video pipeline (p-avatar-short, p-vsl) | **~$1–5** in ElevenLabs / HeyGen / Replicate credits |
| Image generation (c-html-gfx, c-ai-media) | **~$0.01–0.10** per image |
| Transcription (c-studio-audio) | **~$0.001** per minute |

Note: Video/audio provider costs are charged to **their** providers, not visible in `costUsd`.

---

## Error Modes

| Error | Cause | What to do |
|---|---|---|
| `unknown_brand` | `brandId` doesn't exist | Check `psql cfw_social_dev -c "SELECT id, slug FROM brands"` |
| `invalid_api_key` | `x-api-key` doesn't match | Re-decrypt: `pnpm tsx --env-file=.env scripts/decrypt-brand-key.ts <brandId>` |
| `prompt is required` / `brandId is required` | Missing required arg | Add both to `arguments` |
| `Unknown tool: ...` | Wrong tool name | Must be `cfw_run` |
| Skill subprocess crash | Missing binary (`yt-dlp`, `chromium`, `mlx_whisper`) | Check cfw-agent logs |
| Empty reply, no outputs | Brand context missing or prompt ambiguous | Re-prompt with specifics |
| `skill not in allow-list` | `allowedSkills` set but skill not included | Add skill name or set `allowDiscovery: true` |

---

## Pre-flight Checklist

Before calling `cfw_run`:

- [ ] cfw-agent is running (`curl http://localhost:8081/health`)
- [ ] Brand exists in DB
- [ ] `openclawApiKey` is set for the brand
- [ ] Brand's `brand-ref.md` has `voice_id` / `avatar_id` (if using audio/avatar skills)
- [ ] Skills directory is mounted (`SKILLS_DIR` env points to `/Users/vasanth/Code/skills`)
- [ ] R2 credentials are configured (for asset uploads)
