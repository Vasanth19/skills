# CFW Social — Brand Management

How to set up, configure, and manage a Brand in CFW Social.

---

## Brand Creation

A `Brand` is the tenant root. Every user gets one automatically on sign-up via `initUserWorkspace` (called from Better Auth `databaseHooks.user.create.after`).

### Auto-created on sign-up

1. `User` row created (Better Auth)
2. `Brand` row created with:
   - `ownerId` = new user id
   - `name` = user's name
   - `slug` = auto-generated from email or name
   - `plan` = "free"
   - `timezone` = "UTC"
3. `Workspace` row created with:
   - `brandId` = new brand
   - `userId` = new user
   - `title` = null (user can rename later)
4. `UserBrandAccess` row created with `role = "owner"`

### Manual brand creation (admin)

`POST /api/v1/dev/brands` — dev-only endpoint, no auth required. Used for seeding test data.

---

## Brand DNA

`BrandDna` is a 1:1 child of `Brand`. It defines the voice, tone, and visual identity that the agent uses when generating content.

| Field | Purpose | Example |
|---|---|---|
| `voice` | Personality descriptor | "Casual, witty, authoritative" |
| `tone` | Emotional register | "Friendly but professional" |
| `audience` | Target demographic | "SaaS founders, 25-45, tech-savvy" |
| `keywords` | Brand-specific terms | ["CFW", "OpenClaw", "Hyperagent"] |
| `avoidWords` | Words to never use | ["cheap", "guarantee"] |
| `guidelines` | Free-form writing rules | "Never use emojis. Always cite sources." |
| `visualStyle` | Design direction | "Dark studio, purple accents, Poppins font" |
| `systemPrompt` | Custom LLM system prompt override | "You are the brand's chief content officer..." |
| `examplePosts` | JSON array of exemplar content | `[{ "platform": "linkedin", "caption": "..." }]` |

### How DNA is loaded

The cfw-agent MCP `get_brand_dna` tool returns this data. The agent loop injects it into the system prompt on every turn. Changes take effect immediately (no restart required).

### Updating DNA

- **Web UI**: `/brand/settings` or similar
- **API**: No dedicated DNA update endpoint exposed in routes.json — likely part of brand setup or settings flow
- **Direct DB**: `UPDATE brand_dna SET voice = '...' WHERE brand_id = '...'`

---

## Brand Insights (Memory v2)

`BrandInsight` is structured memory extracted from conversations by the consolidator worker (Claude Haiku). Each insight is a "fact" about the brand or its audience.

| Field | Meaning |
|---|---|
| `kind` | `fact` | `preference` | `context` | `rule` |
| `text` | The insight itself (plain text) |
| `entities` | Named entities mentioned |
| `confidence` | 0.0–1.0, default 0.7 |
| `alwaysOn` | If true, always injected into system prompt regardless of semantic relevance |
| `supersededBy` | If set, this insight is contradicted by a newer one — kept for provenance but excluded from active retrieval |
| `embedding` | pgvector(768) for semantic ANN search |

### How insights are used

1. **Consolidator worker** reads conversation messages, extracts insights, writes rows
2. **Agent loop** queries `search_brand_insights` or `fts_brand_insights` MCP tools to find relevant context
3. **Always-on insights** are unconditionally prepended to the system prompt
4. **Semantic insights** are retrieved by vector similarity to the current user intent

### MCP tools for insights

- `record_brand_insights` — write new insights (consolidator worker uses this)
- `search_brand_insights` — semantic search via pgvector
- `fts_brand_insights` — full-text search
- `get_always_on_insights` — retrieve all `alwaysOn = true` rows

---

## Social Account Connection

Brands connect to social platforms via `PlatformConnection` rows.

### OAuth flow

1. User clicks "Connect Instagram" (or other platform) in UI
2. cfw-social redirects to platform OAuth (or PostForMe OAuth proxy)
3. Platform redirects back to `/api/v1/social/callback/postforme`
4. cfw-social creates `PlatformConnection` row with:
   - `platform` = "instagram"
   - `provider` = "postforme"
   - `externalAccountId` = PFM `sa_xxx` id
   - `accountName` = user's handle
   - `isActive` = true

### Connection health

`connectionHealth` enum: `healthy` | `expiring` | `expired` | `error`

- `healthy`: token valid, last sync within window
- `expiring`: token expires within 7 days (refresh scheduled)
- `expired`: token expired, re-auth required
- `error`: last API call failed (e.g., revoked permissions)

### Listing connections

`GET /api/v1/social/accounts` — returns active `PlatformConnection`s for the brand

### Deleting connections

`DELETE /api/v1/social/accounts/{socialAccountId}` — removes the connection

---

## Channel Connections

`ChannelConnection` is the generic inbound routing layer. It maps channel metadata (bot token, phone number) to a `Brand`.

### Supported channels

| Channel | `channelId` meaning | `userId` meaning |
|---|---|---|
| `telegram` | Bot token | Chat ID (null = all users) |
| `whatsapp` | Phone number | Customer phone number |
| `sms` | Phone number | Customer phone number |
| `web` | Browser session token | User ID |

### How inbound routing works

1. External service (Telegram, etc.) sends webhook to cfw-social
2. cfw-social looks up `ChannelConnection` by `(channel, channelId, userId)`
3. Resolves `brandId` from the connection
4. Routes to the appropriate conversation thread

### Telegram bot setup

1. Create bot with @BotFather, get token
2. `POST /api/v1/channels/telegram/connect` — stores encrypted token in `TelegramBot`
3. cfw-social calls Telegram `setWebhook` API
4. Telegram sends updates to `/api/v1/telegram/webhook/{botToken}`

### Slack install

1. User initiates Slack OAuth from cfw-social
2. `SlackInstall` row created with `workspaceId`, `channelId`, `botTokenEnc`
3. Slack events sent to `/api/v1/slack/events`

### Discord bot

1. User adds Discord bot to guild
2. `DiscordBot` row created with `guildId`, `channelId`, `tokenEnc`
3. Discord interactions sent to `/api/v1/discord/interactions`

---

## API Key Provisioning

Brands can create scoped API keys for server-to-server access.

### Creating a key

`POST /api/v1/api-keys` — creates an `ApiKey` row:
- `name` = human-readable label
- `keyHash` = bcrypt hash of the full key
- `prefix` = first 12 chars (e.g. `cfw_abc1def2...`)
- `isActive` = true

The full plaintext key is shown **once** to the user and never stored.

### Auth with brand key

```
GET /api/v1/workspaces/list
Headers:
  x-api-key: cfw_abc1def2ghi3...
```

Resolution order (`requireApiBrand` in `src/lib/auth/api-auth.ts`):
1. `x-api-key` header → lookup by prefix, bcrypt verify → `brand-key` mode
2. `Authorization: Bearer cfw_...` → same as #1
3. `cfw-api-key` header → master key (`CFW_MASTER_API_KEY` env) + `x-cfw-brand` header → `master-key` mode
4. Better Auth session cookie → `session` mode

### Revoking a key

`DELETE /api/v1/api-keys/{apiKeyId}` — sets `isActive = false` (soft delete)

---

## Billing

### Plans

| Plan | Features |
|---|---|
| `free` | Limited runs, basic publishing |
| `creator` | More runs, advanced scheduling, team access |
| `pro` | Unlimited runs, API access, custom integrations |

### Plan change flow

1. User selects plan in UI
2. `POST /api/v1/billing/checkout` — Stripe Checkout session
3. Stripe webhook (`/api/webhooks/stripe`) confirms payment
4. `Brand.plan` updated
5. `Brand.stripeCustomerId` and `Brand.stripeSubscriptionId` recorded

### Self-service portal

`POST /api/v1/billing/portal` — redirects to Stripe Customer Portal for:
- Plan changes
- Payment method updates
- Invoice history
- Cancellation

---

## Team Access

`UserBrandAccess` controls who can see and edit a brand.

| Role | Permissions |
|---|---|
| `owner` | Full control, can delete brand, manage billing |
| `admin` | Can manage content, connections, team members |
| `member` | Can create content, cannot manage brand settings |

### Adding team members

1. Owner invites via email
2. `Invitation` row created with token and expiry
3. Invitee accepts → `UserBrandAccess` row created

### Listing team

`GET /api/v1/team` — returns `UserBrandAccess` rows for the current brand

---

## Brand Context for Agent

When cfw-agent starts a turn, it loads brand context via MCP tools:

1. `get_brand` → `{ id, name, slug, timezone, logoUrl, plan }`
2. `get_brand_dna` → voice, tone, audience, keywords, avoidWords, guidelines, systemPrompt
3. `get_recent_messages` → last N conversation messages
4. `get_content_sources` → workspace sources for grounding

This context is injected into the LLM system prompt before every turn.
