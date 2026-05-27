# cfw-agent MCP — caller's guide

The `cfw-agent` service exposes a Model Context Protocol (MCP) endpoint at `POST /mcp` that lets any MCP-aware client (Claude Code, custom agents, raw `curl`) drive a brand-aware AI orchestrator. The orchestrator picks and runs the right content/media skill (video, audio, image, social distribution) and returns generated outputs as Cloudflare R2 URLs.

This is the document to read **before** you call `cfw_run` for the first time. It tells you how to register the MCP, how to authenticate, what the tool surface looks like, and what to expect when things go wrong.

> Sibling reference: `SKILL.md` in this folder covers the *smoke-test* runner for cfw-social's HTTP API. That's a different surface — same project, different purpose.

---

## 1. What is the cfw-agent MCP?

A single tool, `cfw_run`, that takes a `brandId` plus a natural-language `prompt` and returns:
- the agent's final reply,
- a list of generated `outputs` (R2 URLs with mime type + asset kind),
- the LLM tool calls it made, the stages it went through, and token + cost numbers.

The inner agent (Kimi K2.6 by default, configurable per call) has access to ~35 file-system skills like `c-ffmpeg`, `t-heygen`, `p-vsl`, `p-gfx-short`, `r-cfw-publisher`. **You do not pick a skill yourself.** You describe what you want. The agent picks the right skill, executes it via `claude --print` subprocesses, and streams progress notifications back over Server-Sent Events while the run is in flight.

Three companion MCP **resources** give the calling agent a menu *before* it formulates a prompt:

- `cfw://catalog/agent-guide` — top-level usage guide (three-step workflow, decision tree)
- `cfw://catalog/skills-catalog` — every skill grouped by output type, with "when to use"
- `cfw://catalog/skills-json` — JSON index with search-by-output-type / by-AI-method

Read those once at session start and you won't "chat blind."

---

## 2. Register the MCP in your Claude Code

> ⚠️ **Argument order matters.** The `claude mcp add` parser is positional. The URL **must come immediately after the name**, BEFORE any flags. If you put it at the end you'll get this exact error:
>
> ```
> error: missing required argument 'commandOrUrl'
> ```
>
> ❌ **Broken:** `claude mcp add cfw-agent-local --transport http -H "x-api-key: ..." http://localhost:8081/mcp`
> ✅ **Works:** `claude mcp add cfw-agent-local http://localhost:8081/mcp --transport http -H "x-api-key: ..."`

### Local (cfw-agent running on your Mac, port 8081)

```bash
claude mcp add cfw-agent-local http://localhost:8081/mcp \
  --transport http \
  --scope user \
  -H "x-api-key: <BRAND_API_KEY_PLAINTEXT>"
```

### Production (Railway, when deployed)

```bash
claude mcp add cfw-agent https://agent.cfw.social/mcp \
  --transport http \
  --scope user \
  -H "x-api-key: <BRAND_API_KEY_PLAINTEXT>"
```

Notes:
- `--scope user` makes the registration available from **every** Claude Code session (not just the cwd you ran the command in). Without it, you'd have to re-add per project.
- Use `-H` short form, not `--header`, to dodge a separate parser quirk where the long form sometimes greedy-eats the next arg.
- The plaintext key value can contain a `:` — that's fine for `-H` because the colon is inside the quoted string.

Verify with `claude mcp list` — the entry should show `✓ Connected`. If it says authentication failed, the api key is wrong for the brand you'll be calling. To remove and retry: `claude mcp remove cfw-agent-local`.

---

## 3. Get your brand's api key

The `x-api-key` header value is a **brand-scoped api_keys row plaintext** — a key that lives in cfw-social's `api_keys` table and is bcrypt-verified on each request.

How auth works (Phase 3 model, shipped 2026-05-18):

1. cfw-agent receives the `x-api-key` header value.
2. It extracts the first 12 characters as the prefix.
3. It queries `SELECT … FROM api_keys WHERE brand_id = $1 AND prefix = $2 AND is_active = true`.
4. It runs `bcrypt.compare(providedKey, row.keyHash)` — match → auth OK; updates `api_keys.last_used_at`.
5. The **same plaintext** is forwarded as `x-api-key` on cfw-agent's MCP back-channel to cfw-social `/api/v1/mcp`. cfw-social's `requireApiBrand` bcrypt-verifies the same row, so **one secret works for both legs**.

**To mint a key:**

- UI: go to cfw-social `/settings/api-keys` and generate a new key for the brand.
- API: `POST /api/v1/api-keys` with cfw-social master auth. The response includes the full plaintext — copy it immediately, it is not stored in readable form.

The key is brand-scoped — different brands need separate keys (and separate MCP registrations, or per-call header overrides).

> **History note (removed in Phase 3 — 2026-05-18):** prior to this release, the x-api-key was the AES-256-GCM-decrypted value of `Brand.openclawApiKey`. That column was dropped in migration `20260518000000_drop_openclaw_api_key` (cfw-social commit `0327637`, cfw-agent commit `1429bbd`). The `scripts/decrypt-brand-key.ts` helper was also deleted. Do not use that approach.

---

## 4. Tool surface — `cfw_run`

Live `tools/list` output (verify against your running server with the smoke script):

```json
{
  "name": "cfw_run",
  "title": "Run CFW Agent",
  "inputSchema": {
    "type": "object",
    "required": ["brandId", "prompt"],
    "properties": {
      "brandId":        { "type": "string" },
      "prompt":         { "type": "string" },
      "agentId":        { "type": "string" },
      "workspaceId":    { "type": "string" },
      "sources":        { "type": "array",   "items": { "type": "object" } },
      "allowedSkills":  { "type": "array",   "items": { "type": "string" } },
      "allowDiscovery": { "type": "boolean" },
      "model":          { "type": "string" }
    }
  }
}
```

| Arg | Required | Notes |
|---|---|---|
| `brandId` | yes | Loads brand DNA, voice config, skill curation. |
| `prompt` | yes | Natural-language instruction. The inner agent decides which skill to call. |
| `agentId` | no | Pick a curated Agent within the brand's workspace. Omit for default skill set. |
| `workspaceId` | no | Scope the run to a workspace. Affects skill availability + source context. |
| `sources` | no | `[{ kind, name, url, metadata? }]` — files/urls/transcripts to ground on. |
| `allowedSkills` | no | Allow-list of skill names. Empty = all allowed. |
| `allowDiscovery` | no | If `true`, the inner agent can use any global skill regardless of `allowedSkills`. |
| `model` | no | Override the LLM. Defaults to the server's `LLM_MODEL` env (Kimi K2.6). |

**Result shape:**

```json
{
  "content": [{ "type": "text", "text": "Human-readable summary…" }],
  "structuredContent": {
    "reply": "Final assistant text",
    "outputs": [
      { "assetId": "…", "mediaId": "…", "url": "https://media.cfw.social/…",
        "mimeType": "video/mp4", "kind": "video" }
    ],
    "toolCalls": [{ "name": "run_skill", "ms": 4321, "ok": true }],
    "stages": ["Loading brand context…", "Running p-gfx-short…", "Uploading to R2…"],
    "tokensIn": 6816, "tokensOut": 364, "costUsd": 0.0259
  },
  "isError": false
}
```

### Streaming progress

If your MCP client sends `_meta.progressToken` in the `tools/call` params, the response is `text/event-stream` and you'll get one `notifications/progress` JSON-RPC message per intermediate event (stage labels, tool calls, assistant tokens, asset uploads), terminated by the final result message. Claude Code does this automatically.

---

## 5. Resources — read these *before* formulating a prompt

```bash
# JSON-RPC over HTTP (curl)
curl -s -X POST http://localhost:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"resources/list"}' | jq

curl -s -X POST http://localhost:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"cfw://catalog/skills-catalog"}}' | jq -r '.result.contents[0].text'
```

From a Claude Code session, just ask: *"List the cfw-agent-local MCP resources and read the skills-catalog."*

---

## 6. Ten example prompts

Each prompt is paste-ready into a fresh Claude Code session with `cfw-agent-local` registered. Replace `<your-brand-id>` and any `<R2_URL>` / `<paste>` placeholders.

1. **Single photo → brand-framed enhanced image.**
   "Use cfw_run with brandId=`<your-brand-id>` to take this photo `<R2_URL>` and produce a brand-framed 1080×1080 enhanced version with the brand logo bottom-right and a subtle gradient border. Return the new R2 URL."

2. **Carousel: 4 photos → enhanced + brand frame on each.**
   "Use cfw_run to take these 4 photos `<R2_URLS>` and produce a 4-slide LinkedIn-style image carousel where each slide has the same brand frame (white border, logo top-left, slide number bottom-right). Return one R2 URL per slide."

3. **Text quote → Twitter-card image.**
   "Use cfw_run to render this quote as a 1200×675 Twitter-card image with the brand color background and the brand handle bottom-left: \"Discipline equals freedom. — Jocko\". Return the R2 URL."

4. **Text-quote carousel (5 slides from 1 long quote).**
   "Use cfw_run via p-linkedin-carousel to split this 250-word passage into 5 punchy slide quotes and render them as a 1080×1350 LinkedIn carousel with consistent brand styling. Passage: \"<paste>\". Return 5 R2 URLs."

5. **Transcript → ElevenLabs voiceover + music bed video.**
   "Use cfw_run to take this transcript `<text>`, generate an ElevenLabs voiceover using the brand's configured voice_id (from `brand-ref.md`), layer it under a soft cinematic music bed at -20 LUFS, and produce a 16:9 video with the transcript as animated captions. Return the R2 URL."

6. **Transcript → 9:16 short with HeyGen avatar.**
   "Use cfw_run via p-avatar-short to turn this 60-second script into a 9:16 reel with the brand's HeyGen avatar (from `brand-ref.md`) and captions. Script: \"<paste>\". Return the R2 URL."

7. **Transcript → 9:16 GFX short (no avatar).**
   "Use cfw_run via p-gfx-short to turn this 30-second script into a 9:16 faceless GFX reel with animated HTML overlays and an ElevenLabs voiceover. Script: \"<paste>\". Return the R2 URL."

8. **Audio file → transcript + captions.**
   "Use cfw_run to transcribe this audio file `<R2_URL>` and return both the plain transcript and a `.srt` captions file." ⚠️ Today the audio skill uses `mlx_whisper` — Mac-only. Will fail in a Linux container until the Groq Whisper swap lands. Use this to confirm the failure mode is graceful before relying on it.

9. **Distribution: existing video → Post for Me publish.**
   "Use cfw_run to take this video R2 URL `<URL>` and publish it via Post for Me to LinkedIn + Instagram + X with caption \"<text>\". Return the post IDs."

10. **Capability discovery (no compute, smoke-test the resources).**
    "Use cfw-agent-local's resources/list, then resources/read on `cfw://catalog/skills-catalog`, and recommend the 3 skills best suited to producing a 60-second founder testimonial reel. Then call cfw_run with brandId=`<your-brand-id>` to execute the top recommendation."

> **Pre-flight before #5–7:** the inner skills read voice_id / avatar_id from per-brand `brand-ref.md` files at `/Users/vasanth/Code/cfw/cfw-social/creatives/brand-guidelines/<brand-slug>/brand-ref.md`. Confirm the file exists and the fields are filled in for your target brand, or inline `voice_id=…` / `avatar_id=…` directly in the prompt as an override.

---

## 7. Error modes

| Surface | Cause | What you'll see |
|---|---|---|
| `result.isError: true, content="Error: unknown_brand"` | `brandId` doesn't exist in the cfw-social Postgres | 401-ish tool error; no LLM call burned |
| `result.isError: true, content="Error: invalid_api_key"` | `x-api-key` bcrypt-verification failed for the brand's api_keys row | 401-ish tool error; no LLM call burned |
| JSON-RPC `-32602` "prompt is required" / "brandId is required" | Missing required arg | Tool-call rejected before reaching the agent |
| JSON-RPC `-32602` "Unknown tool: …" | Wrong tool name | Tool-call rejected |
| `result.isError: true` with skill-subprocess output | The agent picked a skill but it crashed (missing `yt-dlp`, `chromium`, `mlx_whisper` on Linux, missing brand-ref.md field, etc.) | Look at the surrounding `stages` + `toolCalls` and tail the cfw-agent log |
| Empty / very short `reply` with `outputs: []` | The agent gave up early. Usually means brand context is missing or the prompt is ambiguous | Re-prompt with more specifics or a `agentId` hint |

Cost guardrail: every result includes `tokensIn`, `tokensOut`, `costUsd`. With Kimi K2.6 as the default LLM, a typical short-prompt round-trip is **~$0.02–0.03** (brand context dominates input tokens). Video-pipeline runs add **~$1–5** in ElevenLabs / HeyGen / Replicate credits — those are charged to *their* providers, not visible in `costUsd`.

---

## 8. Local vs prod

| Concern | Local (`http://localhost:8081/mcp`) | Prod (`https://agent.cfw.social/mcp`) |
|---|---|---|
| Server runtime | host `pnpm tsx` or `docker compose` | Railway |
| Postgres | local `:5432/cfw_social_dev` | Neon (us-east-1) |
| `LLM_MODEL` | whatever your `.env` has | set in Railway env |
| Skill mount | `SKILLS_DIR=/Users/vasanth/Code/skills` | container `/home/node/.claude/skills` (synced at startup) |
| Brand keys | seeded by your local cfw-social dev | provisioned per-tenant |
| Cost ceiling | your local API budget | Railway-side limits + provider quotas |

For dev work, register `cfw-agent-local` first and shake out the prompts. For shareable demos / non-engineering teammates, point at `cfw-agent` (prod) with a brand key issued to them.

---

## 9. Bring-your-own smoke test

If you want to confirm a server is reachable and serving the protocol **without** Claude Code, run the bundled bash script:

```bash
bash /Users/vasanth/Code/skills/c-cfw-agent/mcp-example.sh \
  --base-url=http://localhost:8081 \
  --api-key="$CFW_API_KEY" \
  --brand-id="$BRAND_ID"
```

It calls `initialize`, `tools/list`, `resources/list`, and a tiny `tools/call cfw_run` (prompt `"say HELLO"`) — then prints PASS or the exact failure. Useful for CI and for "is the prod endpoint up" alerts.
