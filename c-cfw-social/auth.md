# CFW Social — Auth & Security

Full auth cascade, middleware behavior, and security model for the CFW Social HTTP API.

---

## Auth Modes

Every route in `routes.json` is tagged with one of five auth modes. The mode reflects **gateway-level** auth (what `src/proxy.ts` allows), not just what the handler imports.

| Auth mode | Who can call | Validation |
|---|---|---|
| `public` | Anyone | No auth required |
| `api-or-session` | Logged-in user OR API key | Session cookie OR `x-api-key` OR `cfw-api-key` |
| `session` | Logged-in user only | Session cookie (Better Auth); unauth → 307 to /login |
| `webhook` | External service | HMAC signature in header |
| `signed-token` | Token holder | Signed JWT in URL path |

---

## Auth Cascade (requireApiBrand)

`src/lib/auth/api-auth.ts` implements the unified brand resolver:

```
1. x-api-key header ───────────────────────────────▶ brand-key auth
   OR Authorization: Bearer <key>

2. cfw-api-key header ─────────────────────────────▶ master-key auth
   + x-cfw-brand header required
   + validates against CFW_MASTER_API_KEY env
   + confirms brand exists in DB

3. Better Auth session cookie ──────────────────────▶ session auth
   Falls through to getCurrentBrand()
```

### brand-key resolution

```
x-api-key: cfw_abc1def2ghi3...
    │
    ▼
Extract prefix (first 12 chars)
    │
    ▼
Query ApiKey where prefix = ... AND isActive = true
    │
    ▼
For each candidate: bcrypt.compare(plain, keyHash)
    │
    ▼
First match wins → brandId returned
    │
    ▼
Fire-and-forget: UPDATE lastUsedAt = now()
```

### master-key resolution

```
cfw-api-key: <CFW_MASTER_API_KEY>
x-cfw-brand: <brandId>
    │
    ▼
Validate cfw-api-key === env.CFW_MASTER_API_KEY
    │
    ▼
Query Brand by id
    │
    ▼
Brand exists → return { brandId, mode: "master-key" }
    │
    ▼
Brand missing → 403 "Brand not found"
```

### session resolution

```
Better Auth cookie: cfw-session-token
    │
    ▼
auth.api.getSession({ headers })
    │
    ▼
User resolved
    │
    ▼
getCurrentBrand()
    │
    ├──▶ x-cfw-brand header (if present, from proxy)
    ├──▶ cfw_brand cookie (fallback)
    └──▶ default: first owner brand, then oldest brand
    │
    ▼
UserBrandAccess resolved
    │
    ▼
Return { brand, role, userId }
```

---

## Middleware Allowlist (proxy.ts)

`src/proxy.ts` is the Next.js 16 middleware. It has three allowlist structures that bypass the session-cookie check: `ALWAYS_OPEN_PREFIXES` (startsWith match), `ALWAYS_OPEN_EXACT` (exact path match), and `ALWAYS_OPEN_REGEXES`.

### Current allowlist (as of 2026-06-02 — PR #49)

**Prefix allowlist (`ALWAYS_OPEN_PREFIXES`):**
- `/api/auth` — better-auth handler
- `/api/v1/webhooks` — provider webhooks (self-signed)
- `/api/webhooks/stripe` — Stripe-Signature auth
- `/api/v1/telegram/webhook` — Telegram path-token auth
- `/api/v1/slack/events`, `/api/v1/discord/interactions` — channel webhooks
- `/api/v1/mcp` — OpenClaw MCP endpoint (requireApiBrand in handler)
- `/api/v1/audit-log` — agent audit sink
- `/api/v1/skills` — catalog sync (x-admin-key)
- `/api/v1/api-keys` — [AB-KEYMINT] mint/list/revoke via key auth
- `/api/v1/ops-prescriptions`
- `/api/health`, `/api/v2/` — Hono catch-all (requireApiBrand per-route)
- `/api/v1/social/callback`, `/api/v1/captures`, `/api/v1/media/upload-url`, `/api/v1/dev/`
- `/privacy`, `/terms`, `/c/`, `/a/`, `/s/` (token-as-credential page surfaces: capture / approval / script share — PR #52)

**Exact allowlist (`ALWAYS_OPEN_EXACT`):**
- `/api/v1/compositions` (POST — Engine creates dish)
- `/api/v1/runs` — [AB-KEYMINT] start a run via key auth
- `/api/v1/agents` — **PR #49**: external brand-key agents create their roster. EXACT on purpose: `/api/v1/agents/rig-up` stays session-gated
- `/api/v1/inbox/approve|reject|regenerate|conversation` — token-as-credential
- `/manifest.json`

**Regex allowlist (`ALWAYS_OPEN_REGEXES`):**
- `/api/v1/brand/{id}/context|recent-compositions|captures`
- `/api/v1/compositions/{id}/...` (approve/reject/regenerate/events/outputs/sources/complete/…)
- `/api/v1/compositions/{id}` (DELETE)
- `/api/v1/approval/{token}/caption|chat`
- `/api/v1/posts`, `/api/v1/posts/{id}` — **also matches `/api/v1/posts/quick`** (PR #49 quick publish needed no proxy change)
- `/api/v1/brand/dna`
- `/api/v1/brands/{id}/insights(/{insightId})`
- `/api/v1/workspaces/{id}/compositions`
- `/api/v1/agents/{id}/skills`, `/api/v1/agents/{id}/discovery` — [AB-KEYMINT]
- `/api/v1/runs/{id}/events` — [AB-KEYMINT]
- `/api/v1/brand-secrets`, `/api/v1/brand-secrets/{provider}` — **PR #49**: provider vault
- `/api/v1/skill-executions(/{id})`, `/api/v1/media/{id}/confirm`

### Important note

A route that imports `requireApiBrand` but is NOT in the allowlist will be blocked by the middleware with a `307 → /login` **before the handler ever runs**. The `session` tag in `routes.json` reflects this. **The proxy allowlist is the REAL gate** — handler-level auth is inert until the path is allowlisted.

To make a session-protected route reachable by API key:
1. Add its path/regex to `src/proxy.ts` (prefer EXACT/regex over prefix to avoid opening adjacent routes)
2. Re-tag it `api-or-session` in `routes.json`
3. Bump `_version`
4. Add a lock-in check to `cfw-social/test/api-auth-allowlist.test.ts`

### Vault authorization (`authorizeVault`)

`src/lib/auth/vault-access.ts` adds a second gate on top of `requireApiBrand` for the provider-key vault (`/api/v1/brand-secrets*`):

| Caller mode | Result |
|---|---|
| `brand-key` | ✅ pass — the brand key IS brand authority (owner decision 2026-06-02) |
| `master-key` | ✅ pass |
| `session` | only `role === "owner"` passes; others get `403 owner_only` |

Accepted risk: a leaked brand key can read/write/delete stored provider keys (and read **plaintext** via MCP `get_brand_secrets`). Planned mitigation: `secret_access_log`.

---

## Webhook HMAC

### Stripe

`POST /api/webhooks/stripe`

Validation:
1. Extract `Stripe-Signature` header
2. Verify HMAC with `STRIPE_WEBHOOK_SECRET`
3. Parse payload
4. Handle event types:
   - `checkout.session.completed` → activate plan
   - `invoice.paid` → update subscription
   - `invoice.payment_failed` → notify user
   - `customer.subscription.deleted` → downgrade to free

### PostForMe

`POST /api/v1/webhooks/postforme/events`

Validation:
1. Extract signature from header
2. Verify with `pfmProjectWebhookSecret` (from `Brand.pfmProjectWebhookSecret` or env)
3. Handle events:
   - `post.published` → update Post.status
   - `post.failed` → update Post.status + errorMessage

### Telegram

`POST /api/v1/telegram/webhook/{botToken}`

Validation:
1. `botToken` in URL must match a `TelegramBot` row
2. Validate update payload structure
3. Deduplicate by `update_id` (T-014 contract)

---

## Signed Token (Approval)

`POST /api/v1/inbox/approve` and `/api/v1/inbox/reject`

Auth: `signed-token`

Validation:
1. Extract token from URL path or body
2. Verify JWT signature with `CFW_APPROVAL_SECRET`
3. Lookup `ApprovalToken` row by token string
4. Check not expired, not revoked, not already approved
5. Resolve brand from JWT claims
6. Proceed with action

---

## Impersonation

Admin users can impersonate other users via the `cfw_impersonating` cookie.

### Flow

1. Admin sets `cfw_impersonating` cookie to target user ID
2. `getCurrentBrand()` checks cookie
3. Verifies real caller's `role = "admin"`
4. Resolves brand context as impersonated user
5. Returns `{ ...access, _realUserId, _isImpersonating: true }`

### Security

- Only users with `role = "admin"` can set the cookie
- Cookie is validated on every request
- Audit logs record `_realUserId` for accountability

---

## Rate Limiting

Per-brand rate caps are enforced at the webhook handler level:

| Cap | Trigger | Response |
|---|---|---|
| Message rate | > N messages per minute | `429` + retry after N seconds |
| Spend cap | Daily AI budget exceeded | `503` + "Try again tomorrow" |

### Rate limit response

```
HTTP/1.1 429 Too Many Requests
Retry-After: 30

{ "error": "rate_limited", "retryAfterSec": 30 }
```

### Spend cap response

```
HTTP/1.1 503 Service Unavailable

{ "error": "spend_capped", "message": "Daily LLM spend cap reached" }
```

---

## Encryption at Rest

| Field | Algorithm | Key |
|---|---|---|
| `BrandSecret.encryptedValue` (provider vault: HeyGen/ElevenLabs/etc. keys) | AES-256-GCM | `ENCRYPTION_KEY` env |
| `Brand.pfmProjectApiKey` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `Brand.pfmProjectWebhookSecret` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `PlatformConnection.accessTokenEnc` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `PlatformConnection.refreshTokenEnc` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `TelegramBot.botToken` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `TelegramBot.webhookSecret` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `SlackInstall.botTokenEnc` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `DiscordBot.tokenEnc` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `CustomerConfig.anthropicKeyEnc` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `CustomerConfig.openaiKeyEnc` | AES-256-GCM | `ENCRYPTION_KEY` env |
| `CustomerConfig.pfmKeyEnc` | AES-256-GCM | `ENCRYPTION_KEY` env |

`ENCRYPTION_KEY` is a 64-character hex string shared between cfw-social and cfw-agent.

---

## Audit Logging

### Security events (AuditLog)

| Action | When |
|---|---|
| `user.signup` | New user registered |
| `user.login` | User signed in |
| `brand.create` | New brand created |
| `brand.delete` | Brand deleted |
| `billing.plan_change` | Plan upgraded/downgraded |
| `platform.connect` | Social account connected |
| `platform.disconnect` | Social account removed |
| `api_key.create` | New API key generated |
| `api_key.revoke` | API key deactivated |
| `post.publish` | Content published |
| `post.delete` | Post removed |

### Agent telemetry (AgentAuditLog)

| Field | Purpose |
|---|---|
| `toolName` | Which MCP tool was called |
| `toolInputHash` | SHA-256 of tool input (no raw payloads) |
| `toolOutputHash` | SHA-256 of tool output |
| `llmTokensIn` / `llmTokensOut` | Token consumption |
| `llmCostUsd` | Estimated cost |
| `outputFilterTriggered` | Whether content filter blocked output |

---

## GDPR / Data Deletion

### Soft delete

`User.deletedAt` and `Brand.deletedAt` mark rows as deleted without removing data.

### Hard delete

After 30 days of `deletionRequestedAt`:
1. All `User` data purged
2. All `Brand` data purged (cascades to related tables)
3. R2 objects deleted
4. Stripe customer data deleted

### Right to erasure

`POST /api/v1/me/delete-account` initiates the process:
1. Sets `deletionRequestedAt = now()`
2. Schedules hard delete for +30 days
3. Sends confirmation email
4. Cancels all active subscriptions
