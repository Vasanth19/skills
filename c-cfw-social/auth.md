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

`src/proxy.ts` is the Next.js 16 middleware. It has `ALWAYS_OPEN_PREFIXES` and `ALWAYS_OPEN_REGEXES` that bypass the session-cookie check.

### Current allowlist (v3 of routes.json)

**Prefix allowlist:**
- `/api/v1/mcp`
- `/api/v1/audit-log`
- `/api/v1/captures*`
- `/api/v1/dev/*`
- `/api/v1/social/callback/*`

**Regex allowlist:**
- `/api/v1/brand/{id}/context`
- `/api/v1/brand/{id}/captures`
- `/api/v1/brand/dna`
- `/api/v1/brands/{id}/insights`
- `/api/v1/brands/{id}/insights/{insightId}`
- `/api/v1/posts/{id}` (DELETE only)

**Webhook routes (all bypass session):**
- `/api/webhooks/stripe`
- `/api/v1/telegram/webhook/*`
- `/api/v1/slack/events`
- `/api/v1/discord/interactions`
- `/api/v1/webhooks/*`

### Important note

A route that imports `requireApiBrand` but is NOT in the allowlist will be blocked by the middleware with a `307 → /login` **before the handler ever runs**. The `session` tag in `routes.json` reflects this.

To make a session-protected route reachable by master key:
1. Add its path/regex to `src/proxy.ts`
2. Re-tag it `api-or-session` in `routes.json`
3. Bump `_version`

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
