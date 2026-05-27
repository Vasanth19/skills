# Orchestrator Contract v1 (FROZEN)

The canonical boundary between **cfw-social** and **cfw-agent** (or any future orchestrator: Hermes, OpenClaw, etc.).

## Status

**LOCKED.** No new fields may be added to v1 schemas. New capabilities require a v2 contract + coordinated migration.

## Transports

| Transport | Direction | Purpose |
|---|---|---|
| `POST /chat/stream` | cfw-social → orchestrator | Start a run; receive SSE events |
| `GET /v1/skills` | cfw-social → orchestrator | Fetch skill catalog for DB sync |
| `POST /v1/skills/sync-webhook` | orchestrator → cfw-social | Push-notify re-sync on deploy |

## Auth

All requests carry:
```
x-api-key: <brand-scoped api_keys plaintext>
```

cfw-agent bcrypt-verifies the value against the `api_keys` table for the brand (prefix lookup + `bcrypt.compare` against stored hash). The same plaintext is reused by cfw-agent's MCP back-channel to cfw-social — one secret covers both legs.

The sync-webhook uses `CFW_SKILL_SYNC_KEY` env (service account key).

## POST /chat/stream

### Request body

```json
{
  "workspaceId": "ws_clxyz123",
  "agentId": "ag_clxyz456",
  "runId": "run_idempotency_key",
  "brandId": "brand_clxyz789",
  "sources": [
    {
      "kind": "transcript",
      "name": "May podcast ep. 3",
      "url": "https://r2.cfwsocial.com/transcripts/may-ep3.txt",
      "metadata": { "durationSec": 3600 }
    }
  ],
  "prompt": "Turn this into a LinkedIn carousel",
  "allowedSkills": ["p-linkedin-carousel", "c-ffmpeg"],
  "allowDiscovery": false,
  "model": "claude-sonnet-4-6",
  "systemPromptOverride": "You are..."
}
```

**Idempotency:** If `runId` is already executing, returns `202 Accepted`. Caller can subscribe to existing SSE stream via `GET /v1/runs/:runId/events`.

### SSE Event Taxonomy

| Event | When | Data |
|---|---|---|
| `stage` | Processing phase change | `{ label: "Analyzing sources" }` |
| `agent.message` | LLM produces text | `{ role: "assistant", text: "..." }` |
| `tool.call` | Skill invoked | `{ name: "p-gfx-short", ms: 4200, ok: true }` |
| `asset.created` | Output uploaded to R2 | `{ assetId, mediaId, cdnUrl, mimeType, kind }` |
| `run.ready` | Reviewable output ready | `{ runId }` |
| `done` | Terminal success | `{ tokensIn, tokensOut, costUsd }` |
| `error` | Terminal failure | `{ message: "..." }` |

### Asset shape

```json
{
  "assetId": "asset_cl123",
  "mediaId": "media_cl456",
  "cdnUrl": "https://cdn.cfwsocial.com/outputs/carousel-may-ep3.mp4",
  "mimeType": "video/mp4",
  "kind": "video"
}
```

- `mediaId` = cfw-social `Media.id` (written via MCP tool)
- `assetId` = orchestrator-internal reference

## GET /v1/skills

Returns the orchestrator's skill catalog:

```json
[
  {
    "name": "p-viral-reel",
    "kind": "pipeline",
    "description": "Produces a short-form vertical reel...",
    "whenToUse": "Use when the user asks for a Reel...",
    "version": "1.4.2",
    "checksum": "sha256:abc123def456"
  }
]
```

| Field | Type | Notes |
|---|---|---|
| `name` | `string` | Primary key — matches skill filename prefix |
| `kind` | `"component" \| "pipeline" \| "distribution"` | Category |
| `description` | `string` | One-line description |
| `whenToUse` | `string` | Verbatim from SKILL.md frontmatter |
| `version` | `string` | Semver or commit SHA |
| `checksum` | `string` | SHA-256 of SKILL.md body |

## POST /v1/skills/sync-webhook

Pushed by orchestrator on deploy:

```json
{
  "triggeredBy": "deploy",
  "timestamp": "2026-05-11T14:00:00Z"
}
```

Response: `{ "status": "sync_queued" }`. cfw-social enqueues a `GET /v1/skills` call.

## HTTP Error Shapes

| Status | Body | Meaning |
|---|---|---|
| `400` | `{ "error": "invalid_json" }` | Malformed request |
| `400` | `{ "error": "brandId and prompt are required" }` | Missing required fields |
| `401` | `{ "error": "invalid_api_key" }` | API key not recognised |
| `404` | `{ "error": "unknown_brand" }` | No brand/bot found |
| `409` | `{ "error": "run_already_active", "runId": "..." }` | Duplicate runId active |

## Version-Bump Policy

| Action | v1 | v2 |
|---|---|---|
| Add required field | Forbidden | New schema version |
| Add optional field | Forbidden | New schema version |
| Add new event type | Forbidden | New event in v2 union |
| Rename event field | Forbidden | New field in v2 schema |
| Fix typo in message | Allowed | — |
| Change costUsd calc | Allowed | — |

## Orchestrator Swappability

To swap in a new orchestrator:

1. Implement `POST /chat/stream` returning v1 SSE events
2. Implement `GET /v1/skills` returning v1 skill catalog rows
3. Set `ORCHESTRATOR_URL` env in cfw-social
4. Run smoke test: mock orchestrator emitting v1 events should produce identical UI stream

No cfw-social code changes required.

## Files

- `cfw-social/src/lib/openclaw/contracts.ts` — Zod schemas (mirrored in `cfw-agent/src/contracts.ts`)
- `cfw-social/docs/orchestrator-contract-v1.md` — full specification
- `cfw-agent/test/contract-conformance.spec.ts` — 37 conformance checks
