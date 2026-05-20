# CFW Social — Integrations

How to set up and manage external service integrations.

---

## Telegram Bot

### Creating a bot

1. Message @BotFather on Telegram
2. Send `/newbot`
3. Choose a name and username
4. Copy the token (format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Connecting to CFW Social

`POST /api/v1/channels/telegram/connect`

Body:
```json
{
  "botToken": "123456789:ABCdef..."
}
```

cfw-social:
1. Encrypts token with AES-256-GCM
2. Creates `TelegramBot` row:
   - `brandId`
   - `botToken` (encrypted)
   - `botUsername` (from Telegram API)
   - `active` = true
   - `webhookSecret` (encrypted)
   - `allowedUserIds` = []
3. Calls Telegram `setWebhook`:
   ```
   POST https://api.telegram.org/bot<token>/setWebhook
   {
     "url": "https://app.cfw.social/api/v1/telegram/webhook/<encryptedToken>",
     "secret_token": "<webhookSecret>"
   }
   ```

### Webhook handling

`POST /api/v1/telegram/webhook/{botToken}`

Validation:
1. `botToken` in URL must decrypt to a valid `TelegramBot` row
2. `X-Telegram-Bot-Api-Secret-Token` header must match `webhookSecret`
3. Deduplicate by `update_id` (T-014 contract)
4. Route to `BrandConversation` via `ChannelConnection`

### Disconnecting

`DELETE /api/v1/channels/telegram/{telegramChannelId}`

1. Calls Telegram `deleteWebhook`
2. Sets `TelegramBot.active = false`
3. Keeps row for audit trail

---

## Discord Bot

### Creating a bot

1. Go to https://discord.com/developers/applications
2. Create new application
3. Go to "Bot" tab, click "Add Bot"
4. Copy token
5. Enable intents: `MESSAGE_CONTENT`, `SERVER_MEMBERS`

### Connecting to CFW Social

Not directly exposed in routes.json. Likely via admin UI or dev endpoint:

```
POST /api/v1/dev/discord-bot  (assumed)
{
  "guildId": "...",
  "channelId": "...",
  "token": "..."
}
```

cfw-social:
1. Encrypts token
2. Creates `DiscordBot` row:
   - `brandId`
   - `guildId`
   - `channelId`
   - `tokenEnc`
   - `active` = true

### Webhook handling

`POST /api/v1/discord/interactions`

Validation:
1. Discord signature verification (Ed25519)
2. `application_id` must match a `DiscordBot` row
3. Handle interaction types:
   - `PING` → respond with `PONG`
   - `APPLICATION_COMMAND` → route to agent
   - `MESSAGE_COMPONENT` → button clicks

### Disconnecting

Not directly exposed. Likely admin action to set `active = false`.

---

## Slack

### Creating an app

1. Go to https://api.slack.com/apps
2. Create from manifest or scratch
3. Enable Bot Token Scopes:
   - `chat:write`
   - `channels:read`
   - `groups:read`
   - `im:read`
   - `mpim:read`
4. Install to workspace
5. Copy "Bot User OAuth Token"

### Connecting to CFW Social

OAuth flow (not detailed in routes.json — likely via `/api/v1/social/connect` with `platform: "slack"`):

1. User clicks "Connect Slack" in cfw-social
2. Redirect to Slack OAuth
3. Slack redirects back with code
4. cfw-social exchanges code for token
5. Creates `SlackInstall` row:
   - `brandId`
   - `workspaceId` (Slack workspace ID)
   - `channelId` (default channel)
   - `botTokenEnc`
   - `active` = true

### Webhook handling

`POST /api/v1/slack/events`

Validation:
1. Slack signature verification
2. URL verification challenge on first setup
3. Event types:
   - `message` → route to agent
   - `app_mention` → route to agent
   - `member_joined_channel` → update channel list

### Disconnecting

Not directly exposed. Likely admin action or `DELETE /api/v1/brands/channel-connections/{id}`.

---

## Stripe

### Setup

1. Create Stripe account
2. Get publishable key and secret key
3. Configure webhook endpoint:
   ```
   https://app.cfw.social/api/webhooks/stripe
   ```
4. Select events:
   - `checkout.session.completed`
   - `invoice.paid`
   - `invoice.payment_failed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`

### Webhook handling

`POST /api/webhooks/stripe`

Validation:
1. Extract `Stripe-Signature` header
2. Verify HMAC with `STRIPE_WEBHOOK_SECRET`
3. Construct event object
4. Handle by type:

| Event | Action |
|---|---|
| `checkout.session.completed` | `Brand.plan` = session.metadata.plan; `Brand.stripeSubscriptionId` = session.subscription |
| `invoice.paid` | Update `BrandUsage` if needed; send receipt email |
| `invoice.payment_failed` | Notify brand owner; retry logic |
| `customer.subscription.updated` | `Brand.plan` = subscription.items[0].price.lookup_key |
| `customer.subscription.deleted` | `Brand.plan` = "free"; `Brand.stripeSubscriptionId` = null |

### Billing endpoints

| Endpoint | Purpose |
|---|---|
| `POST /api/v1/billing/checkout` | Create Stripe Checkout for plan upgrade |
| `POST /api/v1/billing/portal` | Redirect to Stripe Customer Portal |

---

## PostForMe

### Setup

1. Create PostForMe account
2. Get project API key and webhook secret
3. Configure cfw-social:
   - Env: `PFM_PROJECT_API_KEY` (fallback)
   - Per-brand: `Brand.pfmProjectApiKey` (override)
   - Per-brand: `Brand.pfmProjectWebhookSecret` (override)

### Connecting social accounts

`POST /api/v1/social/connect`

Body:
```json
{
  "platform": "linkedin"
}
```

Flow:
1. cfw-social redirects to PostForMe OAuth for the platform
2. User grants permission
3. PostForMe redirects to `/api/v1/social/callback/postforme`
4. cfw-social creates `PlatformConnection`:
   - `platform` = "linkedin"
   - `provider` = "postforme"
   - `externalAccountId` = PFM `sa_xxx` ID
   - `accountName` = user's handle
   - `isActive` = true

### Webhook handling

`POST /api/v1/webhooks/postforme/events`

Validation:
1. Signature from `Brand.pfmProjectWebhookSecret` or env fallback
2. Event types:

| Event | Action |
|---|---|
| `post.created` | `Post.status` = "publishing" |
| `post.published` | `Post.status` = "published"; `Post.publishedAt` = now(); `Post.publishedUrl` = event.url |
| `post.failed` | `Post.status` = "failed"; `Post.errorMessage` = event.error |
| `post.deleted` | (handled gracefully, no status change) |

### Disconnecting

`DELETE /api/v1/social/accounts/{socialAccountId}`

1. Calls PostForMe disconnect API (if applicable)
2. Sets `PlatformConnection.isActive = false`
3. Keeps row for audit

---

## Integration Summary Table

| Integration | Webhook URL | Auth Method | Key Tables |
|---|---|---|---|
| Telegram | `/api/v1/telegram/webhook/{botToken}` | Token in URL + secret header | `TelegramBot`, `ChannelConnection` |
| Discord | `/api/v1/discord/interactions` | Ed25519 signature | `DiscordBot` |
| Slack | `/api/v1/slack/events` | Signature + challenge | `SlackInstall` |
| Stripe | `/api/webhooks/stripe` | HMAC signature | `Brand` (billing fields) |
| PostForMe | `/api/v1/webhooks/postforme/events` | HMAC signature | `PlatformConnection`, `Post` |
