# CFW Social — Local Dev API Quickstart

How to actually **call** the cfw-social HTTP API against your local dev server. The other docs in this skill explain WHAT the routes are; this one explains HOW to authenticate and hit them from outside the browser.

> Companion to `auth.md` (theory) and `routes.json` (inventory). If you only need to know "does this route exist?", check `routes.json`. If you need to "send a request right now", you're in the right file.

---

## Base URL

```
http://localhost:3000
```

All `/api/**` paths in `routes.json` are relative to this. The dev server is started from `/Users/vasanth/Code/cfw/cfw-social` with `pnpm dev` (use the safe-start pattern in the project's CLAUDE.md — do not blindly run `pnpm dev` if port 3000 is occupied).

A public cloudflared tunnel mirrors the same dev server at `https://v2.cfw.social` — use that when an external service (Stripe webhook, OAuth callback, Telegram bot) needs to reach back into local dev.

---

## Env vars you need to authenticate calls

All of these live in `cfw-social/.env`. The most relevant for hitting the API:

| Env var | Why you need it |
|---|---|
| `DATABASE_URL` | Must be `postgres://vasanth@localhost:5432/cfw_social_dev` — same DB cfw-agent reads. |
| `DIRECT_DATABASE_URL` | Same value as `DATABASE_URL`. |
| `ENCRYPTION_KEY` | 64-char hex (AES-256-GCM). Encrypts `pfmProjectApiKey`, `pfmProjectWebhookSecret`, `PlatformConnection` tokens, `TelegramBot.botToken`, `TelegramBot.webhookSecret`, and other sensitive columns. Must be **identical** in `cfw-agent/.env` (cfw-agent uses it for Telegram webhook secret verification). |
| `CFW_MASTER_API_KEY` | Operator master key. Send as `cfw-api-key` header with `x-cfw-brand: <brandId>` to bypass session auth on any `api-or-session` route. |
| `CFW_APPROVAL_SECRET` | Signs approval JWTs (`/api/v1/inbox/approve`, `/api/v1/inbox/reject`). |
| `BETTER_AUTH_SECRET` / `BETTER_AUTH_URL` | Better Auth — only relevant if you mint sessions programmatically. For interactive testing, sign in through the UI and copy the `cfw-session-token` cookie. |

Print which ones are populated (without leaking values):

```bash
cd /Users/vasanth/Code/cfw/cfw-social
grep -E "^(ENCRYPTION_KEY|CFW_MASTER_API_KEY|CFW_APPROVAL_SECRET|DATABASE_URL|BETTER_AUTH_SECRET)=" .env | sed 's/=.*$/=<set>/'
```

---

## Auth modes in practice

`routes.json` tags every route. Here is the exact header recipe for each tag.

### 1. `public` — no headers required

```bash
curl -s http://localhost:3000/api/health
# {"status":"ok"}

# Dev-only — list brands (also no auth):
curl -s http://localhost:3000/api/v1/dev/brands
```

### 2. `api-or-session` via **master key** — easiest for scripts

Send `cfw-api-key` + `x-cfw-brand`. The brand must exist; the master key is validated against `CFW_MASTER_API_KEY` env.

```bash
MASTER="$(grep ^CFW_MASTER_API_KEY= /Users/vasanth/Code/cfw/cfw-social/.env | cut -d= -f2-)"
BRAND_ID="c03qwb3jtj1px"   # vasanth-cfw — your local dev brand

curl -s http://localhost:3000/api/v1/brand/dna \
  -H "cfw-api-key: $MASTER" \
  -H "x-cfw-brand: $BRAND_ID"
```

This works for any route tagged `api-or-session`. It does NOT work for routes tagged `session` — those are blocked by the middleware before the handler runs (see `auth.md` § "Middleware Allowlist").

### 3. `api-or-session` via **brand-scoped API key** — what 3rd-party integrations use

A brand-scoped key is created from inside the brand's account. Mint one (you need either a session OR the master key to call this):

```bash
curl -s -X POST http://localhost:3000/api/v1/api-keys \
  -H "cfw-api-key: $MASTER" \
  -H "x-cfw-brand: $BRAND_ID" \
  -H "Content-Type: application/json" \
  -d '{"name":"local-test"}'
# { "key": { "id":"...", "name":"local-test", "prefix":"cfw_xxxxxxxx", "plain":"cfw_xxxxxxxx<long>", "createdAt":"..." } }
```

**Save the `plain` value — it is shown once.** Then use it as `x-api-key`:

```bash
BRAND_KEY="cfw_xxxxxxxx..."   # the "plain" value from above

curl -s http://localhost:3000/api/v1/brand/dna -H "x-api-key: $BRAND_KEY"
```

`Authorization: Bearer $BRAND_KEY` also works (api-auth.ts accepts either header).

### 4. `session` — interactive UI flows only

Most `/api/v1/*` routes require a Better Auth session cookie. The middleware blocks all unauthenticated traffic to these paths with `307 → /login` BEFORE the handler runs — so `cfw-api-key` won't help. Options:

1. **Sign in via the UI**, then copy the `cfw-session-token` cookie from devtools and replay it:
   ```bash
   curl -s http://localhost:3000/api/v1/workspaces/list \
     -H "Cookie: cfw-session-token=<paste-from-devtools>"
   ```
2. **Promote a session-only route to `api-or-session`** by adding its path to `ALWAYS_OPEN_PREFIXES` or `ALWAYS_OPEN_REGEXES` in `src/proxy.ts`, then re-tag in `routes.json`.

### 5. `webhook` — HMAC signed by sender

Reproducing a webhook requires the right HMAC secret. The handlers will reject mismatched signatures with 401. See `auth.md` § "Webhook HMAC" for per-provider validators. For local testing it is easier to invoke the underlying business logic via a `signed-token` or `api-or-session` route than to forge the HMAC.

### 6. `signed-token` — approval / capture flows

These take a JWT in the URL path. Mint one with `signApprovalToken()` from `src/lib/crypto/approval-tokens.ts` (or pull a real one from `ApprovalToken.token` in the DB):

```bash
TOKEN="<paste from approval_tokens table>"
curl -s -X POST "http://localhost:3000/api/v1/inbox/approve" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\"}"
```

---

## Bootstrapping a clean dev brand

If there is no brand in your local DB yet:

```bash
curl -s -X POST http://localhost:3000/api/v1/dev/brands \
  -H "Content-Type: application/json" \
  -d '{"slug":"vasanth-cfw","name":"Vasanth CFW"}'
# { "brand": { "id":"<new-id>", "slug":"vasanth-cfw", "name":"Vasanth CFW" }, "created": true }
```

Soft-delete:

```bash
curl -s -X POST http://localhost:3000/api/v1/dev/brands \
  -H "Content-Type: application/json" \
  -d '{"slug":"vasanth-cfw","action":"delete"}'
```

Both endpoints are `public` and are registered ONLY under `/api/v1/dev/*` (always open in `proxy.ts`). Do not deploy them to production without gating.

---

## Consuming SSE — the agent run loop

The most interesting endpoints are streams.

### `POST /api/v1/runs` → `GET /api/v1/runs/{runId}/events`

```bash
# Start a run (session auth required — use a session cookie OR promote to api-or-session).
RUN_RES=$(curl -s -X POST http://localhost:3000/api/v1/runs \
  -H "Cookie: cfw-session-token=<…>" \
  -H "Content-Type: application/json" \
  -d '{"workspaceId":"<wid>","agentId":"<aid>","prompt":"hello"}')
RUN_ID=$(echo "$RUN_RES" | jq -r .runId)

# Consume the SSE stream. Use --no-buffer or curl will block.
curl -N -s "http://localhost:3000/api/v1/runs/$RUN_ID/events" \
  -H "Cookie: cfw-session-token=<…>"
```

The event stream conforms to the frozen v1 contract (`stage` / `agent.message` / `tool.call` / `asset.created` / `run.ready` / `done` / `error`). Schemas live at `cfw-social/src/lib/orchestrator/contract.ts`. The `?since=<seq>` query param replays missed events.

### Verify the cfw-agent → cfw-social loop end-to-end

cfw-agent calls `POST /api/v1/mcp` back into cfw-social for tools like `record_inbound_message`, `get_media_urls`, `attach_output`. Auth is `api-or-session` — cfw-agent reuses the same `x-api-key` plaintext that the inbound `/chat/stream` request carried; cfw-social's `requireApiBrand` bcrypt-verifies it against the `api_keys` table. To smoke-test the loop:

1. Ensure the brand has at least one active `api_keys` row — see "Wire a brand for the full agent loop" below.
2. cfw-agent's `DATABASE_URL` must point at the same `cfw_social_dev`.
3. `CFW_MASTER_API_KEY` must be set in cfw-agent's `.env` (for system-initiated flows like the Telegram webhook sweep).
4. Start cfw-agent (`pnpm dev` in `cfw-agent/`), then `POST /chat/stream` directly to `http://localhost:8081/chat/stream` with the brand-scoped `x-api-key`.

---

## Wire a brand for the full agent loop (dev)

**Phase 3 reality (post-2026-05-18):** cfw-agent authenticates exclusively via the `api_keys` table — there is no envelope to decrypt, no `Brand.openclawApiKey` column. "Wiring a brand for cfw-agent" simply means: ensure the brand has at least one active `api_keys` row and save its plaintext value for use as `x-api-key`.

### Mint an `api_keys` row (master-key auth)

```bash
MASTER="$(grep ^CFW_MASTER_API_KEY= /Users/vasanth/Code/cfw/cfw-social/.env | cut -d= -f2-)"
BRAND_ID="c03qwb3jtj1px"   # your local dev brand id

curl -s -X POST http://localhost:3000/api/v1/api-keys \
  -H "cfw-api-key: $MASTER" \
  -H "x-cfw-brand: $BRAND_ID" \
  -H "Content-Type: application/json" \
  -d '{"name":"cfw-agent-dev"}'
# { "key": { "id":"...", "name":"cfw-agent-dev", "prefix":"cfw_xxxxxxxx", "plain":"cfw_xxxxxxxx<long>", ... } }
```

**Save the `plain` value — it is shown exactly once.** This is the `x-api-key` to pass to cfw-agent for that brand.

### Call cfw-agent with the key

```bash
BRAND_KEY="cfw_xxxxxxxx..."   # the "plain" value from above

curl -N -s -X POST http://localhost:8081/chat/stream \
  -H "x-api-key: $BRAND_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"brandId\":\"$BRAND_ID\",\"prompt\":\"hello\"}"
```

### System-initiated flows (Telegram webhook, media sweeps)

These flows don't carry a user-supplied `x-api-key`. cfw-agent uses `cfw-api-key: $CFW_MASTER_API_KEY` + `x-cfw-brand: <brandId>` for its outbound calls into cfw-social. Ensure `CFW_MASTER_API_KEY` is set to the same value in both `.env` files.

---

## Useful one-liners

```bash
# Show brands + active api_keys row count (to confirm cfw-agent wiring):
psql cfw_social_dev -c "select b.id, b.slug, b.name, count(ak.id) as api_keys from brands b left join api_keys ak on ak.brand_id = b.id and ak.is_active = true where b.deleted_at is null group by b.id, b.slug, b.name;"

# Show ApiKey rows for a brand (prefix only — never the hash):
psql cfw_social_dev -c "select prefix, name, last_used_at, created_at from api_keys where is_active = true and brand_id = '<brandId>';"

# Tail SSE events for the most recent run:
RUN=$(psql cfw_social_dev -tAc "select id from runs order by created_at desc limit 1")
curl -N -s "http://localhost:3000/api/v1/runs/$RUN/events" -H "Cookie: cfw-session-token=<…>"

# List actual route files on disk (to spot drift vs routes.json):
find /Users/vasanth/Code/cfw/cfw-social/src/app/api -name "route.ts" | sort
```

---

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `307 → /login` on any `/api/v1/*` call | Route tagged `session`; middleware blocks before handler. Header doesn't matter. | Use master-key flow only on `api-or-session` routes, OR add path to `ALWAYS_OPEN_*` in `src/proxy.ts`. |
| `403 Brand not found` | `cfw-api-key` valid but `x-cfw-brand` does not match a `Brand.id`. | Use `/api/v1/dev/brands` (GET) to list valid ids; or seed via POST. |
| `401 invalid_api_key` from cfw-agent | No active `api_keys` row for the given `(brandId, prefix)`, OR the bcrypt compare against `key_hash` returned false. | Confirm via `SELECT prefix, last_used_at FROM api_keys WHERE brand_id = $1 AND prefix = $2 AND is_active = true`; if empty, mint a new key — see "Wire a brand for the full agent loop" above. |
| cfw-agent can't see a brand you just created in cfw-social | One of the services is pointed at a `prisma dev` proxy URL instead of `:5432/cfw_social_dev`. | Set both `.env` files to `postgres://vasanth@localhost:5432/cfw_social_dev`, stop any `prisma dev`, run `npx prisma migrate deploy`. |
| Webhook returns 401 with a valid-looking payload | Wrong HMAC secret. | Re-derive the signature using the secret currently in `.env` (Stripe: `STRIPE_WEBHOOK_SECRET`; PFM: `Brand.pfmProjectWebhookSecret`; Telegram: `botToken` in URL must match a `TelegramBot` row). |
| SSE stream hangs / never receives events | curl is buffering, OR proxy buffering somewhere. | Use `curl -N -s` (or `--no-buffer`). The handler sets `X-Accel-Buffering: no` but some intermediaries override. |

---

## See also

- `auth.md` — full theory of every auth mode
- `routes.json` — canonical route inventory + auth tag per route
- `admin-runbook.md` — recovery and rotation procedures
- `integrations.md` — provider-specific setup (Telegram, Discord, Slack, Stripe, PostForMe)
- `c-cfw-social-smoke-test` — bulk smoke-tester that uses these auth recipes
