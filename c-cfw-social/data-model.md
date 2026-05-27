# CFW Social — Data Model

Source of truth: `cfw-social/prisma/schema.prisma` (966 lines). This document extracts and organizes every entity, field, relationship, and index for operational reasoning.

---

## Entity Overview

| Entity | Purpose | Key Relations |
|---|---|---|
| `User` | Human operator (Better Auth) | owns `Brand`s, belongs to `Workspace`s |
| `Brand` | Tenant / business unit | owns `Workspace`s, `PlatformConnection`s, `Post`s, `Composition`s |
| `Workspace` | Topic container per brand | contains `Agent`s, `Source`s, `Run`s, `Composition`s, `Post`s |
| `Agent` | Named AI executor in a workspace | runs `Run`s, has curated `AgentSkill`s |
| `Run` | One agent execution | produces `Output`s, emits `RunEvent`s, can create `Post`s |
| `Output` | Deliverable from a Run (image/video/audio/doc) | linked to `Post`s |
| `Composition` | Type-locked deliverable inside a Workspace | has `ApprovalToken`s, `Post`s |
| `Post` | Scheduled / published content per platform | linked to `Run`, `Output`, `Composition`, `Workspace` |
| `ApprovalToken` | Signed JWT for human-in-the-loop approval | scoped to `Workspace` or `Composition` |
| `PlatformConnection` | OAuth connection to a social platform | per `Brand` |
| `ContentSource` | Brand-level ingest (YouTube, RSS, etc.) | per `Brand` |
| `BrandInsight` | Structured memory atom (Memory v2) | per `Brand`, pgvector-embedded |
| `BrandDna` | Voice, tone, audience, guidelines | one per `Brand` |
| `PostTiming` | Optimal posting schedule per platform | per `Brand` |
| `Source` | Polymorphic workspace input | per `Workspace` |
| `RunEvent` | Persisted SSE event log | per `Run`, monotonic `seq` |
| `Skill` / `AgentSkill` | Curated skill catalog | many-to-many between `Agent` and `Skill` |
| `ApiKey` | Brand-scoped API key (bcrypt hash) | per `Brand` |
| `UserBrandAccess` | RBAC (owner/admin/member) | between `User` and `Brand` |
| `ConversationMessage` | Chat message in a conversation | per `BrandConversation` |
| `BrandConversation` | Channel-agnostic conversation thread | per `Brand` |
| `ChannelConnection` | Generic inbound routing connection | per `Brand` |
| `TelegramBot` / `SlackInstall` / `DiscordBot` | Platform-specific bot configs | per `Brand` |
| `CustomerConfig` | Tier + routing + custom keys | per `Brand` |
| `Template` | Reusable prompt templates | per `Brand` or system |
| `MusicTrack` / `ImageTemplate` / `CharacterRef` | Asset libraries | system-wide or per `Brand` |
| `AuditLog` / `AgentAuditLog` | Security / runtime audit | immutable |
| `BrandUsage` / `AICostLog` | Usage + cost tracking | per `Brand` per month |

---

## Detailed Schema

### User + Auth (Better Auth)

```
User
  id                  String    @id @default(cuid())
  email               String    @unique
  name                String
  image               String?   @map("avatar_url")
  emailVerified       Boolean   @default(false)
  lastLoginAt         DateTime?
  onboardingCompleted Boolean   @default(false)
  role                String    @default("member")  // member | admin
  createdAt           DateTime  @default(now())
  updatedAt           DateTime  @updatedAt
  deletedAt           DateTime?
  deletionRequestedAt DateTime?  // GDPR: hard-delete after 30 days

  Relations: sessions[], accounts[], ownedBrands[], brandAccess[], workspaces[]
```

Better Auth manages `Session`, `Account`, `Verification` tables. CFW domain tables (User, Brand, etc.) coexist alongside them.

### Brand (tenant root)

```
Brand
  id                   String   @id @default(cuid())
  ownerId              String   @map("owner_id")
  name                 String
  slug                 String   @unique
  logoUrl              String?  @map("logo_url")
  timezone             String   @default("UTC")

  // Billing
  plan                 String   @default("free")  // free | creator | pro
  stripeCustomerId     String?  @unique
  stripeSubscriptionId String?
  trialEndsAt          DateTime?
  apiAddonActive       Boolean  @default(false)

  // External service credentials (AES-256-GCM encrypted)
  pfmProjectApiKey     String?  @map("pfm_project_api_key") @db.Text
  pfmProjectWebhookSecret String? @map("pfm_project_webhook_secret") @db.Text

  createdAt  DateTime  @default(now())
  updatedAt  DateTime  @updatedAt
  deletedAt  DateTime?

  Relations:
    owner              User
    brandDna           BrandDna?          (1:1)
    userAccess         UserBrandAccess[]
    connections        PlatformConnection[]
    apiKeys            ApiKey[]
    postTimings        PostTiming[]
    workspaces         Workspace[]
    templates          Template[]
    customerConfig     CustomerConfig?      (1:1)
    telegramBot        TelegramBot?         (1:1)
    slackInstall       SlackInstall?        (1:1)
    discordBot         DiscordBot?          (1:1)
    channelConnections ChannelConnection[]
    conversations      BrandConversation[]
    usage              BrandUsage[]
    invitations        Invitation[]
    agentAuditLogs     AgentAuditLog[]
    contentSources     ContentSource[]
    compositions       Composition[]
    posts              Post[]
    brandInsights      BrandInsight[]
```

### Workspace (topic container)

```
Workspace
  id              String   @id @default(cuid())
  brandId         String   @map("brand_id")
  userId          String   @map("user_id")
  title           String?
  intentEmbedding Unsupported("vector(768)")?  // semantic matching
  status          String   @default("active")  // active | archived

  createdAt  DateTime  @default(now())
  updatedAt  DateTime  @updatedAt
  deletedAt  DateTime?

  Relations:
    brand          Brand
    user           User
    agents         Agent[]
    sources        Source[]
    runs           Run[]
    compositions   Composition[]
    approvalTokens ApprovalToken[]
    posts          Post[]

  Indexes: [brandId, status, deletedAt], [brandId, updatedAt]
```

### Agent (AI executor)

```
Agent
  id                   String   @id @default(cuid())
  workspaceId          String   @map("workspace_id")
  name                 String
  description          String?
  model                String   @default("claude-sonnet-4-6")
  systemPromptOverride String?  @map("system_prompt_override") @db.Text
  allowDiscovery       Boolean  @default(true)  // can use global skills outside allow-list
  createdAt            DateTime @default(now())
  updatedAt            DateTime @updatedAt

  Relations:
    workspace   Workspace
    agentSkills AgentSkill[]
    runs        Run[]

  Index: [workspaceId]
```

### Run (one execution)

```
Run
  id             String    @id @default(cuid())
  agentId        String    @map("agent_id")
  workspaceId    String    @map("workspace_id")
  conversationId String?   @map("conversation_id")
  status         String    @default("pending")  // pending | running | done | failed
  prompt         String    @db.Text
  costUsd        Float     @default(0)
  tokensIn       Int       @default(0)
  tokensOut      Int       @default(0)
  startedAt      DateTime  @default(now())
  completedAt    DateTime?

  Relations:
    agent        Agent
    workspace    Workspace
    conversation BrandConversation?  // nullable (not all runs start from chat)
    events       RunEvent[]
    outputs      Output[]
    posts        Post[]

  Indexes: [agentId], [workspaceId], [conversationId], [status]
```

### Output (deliverable)

```
Output
  id        String   @id @default(cuid())
  runId     String   @map("run_id")
  kind      String   // image | video | audio | doc
  cdnUrl    String   @map("cdn_url")
  mimeType  String   @map("mime_type")
  metadata  Json?    // arbitrary skill-produced metadata
  createdAt DateTime @default(now())

  Relations:
    run   Run
    posts Post[]

  Index: [runId]
```

### Composition (type-locked deliverable)

```
Composition
  id               String   @id @default(cuid())
  workspaceId      String   @map("workspace_id")
  brandId          String   @map("brand_id")
  type             String   // post | reel | video | carousel | article
  platform         String   // instagram | linkedin | twitter | tiktok | facebook | threads | bluesky | youtube
  status           String   @default("draft")  // draft | awaiting_approval | approved | scheduled | published | rejected
  title            String?
  body             String?  @db.Text
  assetId          String?  @map("asset_id")
  captions         Json     @default("{}")       // { "instagram": "caption text", ... }
  platformCaptions Json     @default("[]")      // UX-25 PlatformCaption[]
  mediaIds         String[] @default([])
  metadata         Json?
  revisionVersion  Int      @default(1)
  totalRevisions   Int      @default(1)
  autoRenamedAt    DateTime?
  approvedAt       DateTime?
  publishedAt      DateTime?
  createdAt        DateTime @default(now())
  updatedAt        DateTime @updatedAt
  deletedAt        DateTime?

  Relations:
    workspace       Workspace
    brand           Brand
    approvalTokens  ApprovalToken[]
    posts           Post[]

  Indexes: [workspaceId], [workspaceId, status], [brandId, status]
```

### Post (scheduled / published content)

```
Post
  id             String   @id @default(cuid())
  brandId        String   @map("brand_id")
  workspaceId    String?  @map("workspace_id")
  compositionId  String?  @map("composition_id")
  runId          String?  @map("run_id")
  outputId       String?  @map("output_id")

  platform     String   // instagram | tiktok | youtube | twitter | linkedin | facebook | pinterest | threads | bluesky
  kind         String   @default("post")  // post | reel | story | carousel | video | multi_image
  caption      String?  @db.Text
  mediaUrl     String?  @map("media_url")   // primary R2 CDN url
  mediaUrls    String[] @default([])         // carousel / multi-image set

  status       String   @default("scheduled")  // draft | scheduled | publishing | published | failed
  scheduledAt  DateTime?
  publishedAt  DateTime?
  publishedUrl String?
  errorMessage String?  @map("error_message") @db.Text

  pfmPostId    String?  @unique @map("pfm_post_id")  // PostForMe external id

  metadata     Json?
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  Relations:
    brand       Brand
    workspace   Workspace?   // nullable (post may not be workspace-scoped)
    composition Composition? // nullable (SetNull on delete)
    run         Run?         // nullable
    output      Output?      // nullable

  Indexes: [brandId, status], [brandId, scheduledAt], [brandId, platform], [outputId], [compositionId]
```

### ApprovalToken

```
ApprovalToken
  id               String       @id @default(cuid())
  workspaceId      String       @map("workspace_id")
  workspace        Workspace    @relation(fields: [workspaceId], references: [id])
  compositionId    String?      @map("composition_id")
  composition      Composition? @relation(fields: [compositionId], references: [id], onDelete: SetNull)
  token            String       @unique  // signed JWT
  brandId          String       @map("brand_id")
  expiresAt        DateTime     @map("expires_at")
  revokedAt        DateTime?    @map("revoked_at")
  revocationReason String?      @map("revocation_reason") @db.Text
  approvedAt       DateTime?    @map("approved_at")       // 05-INBAPPR
  firstAccessedAt  DateTime?    @map("first_accessed_at")
  lastAccessedAt   DateTime?    @map("last_accessed_at")
  accessCount      Int          @default(0) @map("access_count")
  ipAddresses      String[]     @default([]) @map("ip_addresses")
  createdAt        DateTime     @default(now())

  Indexes: [brandId], [token], [workspaceId], [compositionId]
```

### PlatformConnection

```
PlatformConnection
  id                String    @id @default(cuid())
  brandId           String    @map("brand_id")
  platform          String
  provider          String    @default("postforme")  // postforme | direct
  accountName       String?
  accountId         String?
  externalAccountId String?   // PFM sa_xxx ID
  accessTokenEnc    String?   @db.Text  // AES-256 encrypted (null for PFM)
  refreshTokenEnc   String?   @db.Text
  tokenExpiry       DateTime?
  scopes            String[]
  isActive          Boolean   @default(true)
  lastSyncAt        DateTime?
  connectionHealth  String    @default("healthy")  // healthy | expiring | expired | error
  metadata          Json?
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt

  Relation: brand Brand

  @@unique([brandId, platform, externalAccountId])
  Index: [externalAccountId]
```

### BrandDna

```
BrandDna
  id           String   @id @default(cuid())
  brandId      String   @unique @map("brand_id")
  voice        String?  @db.Text
  tone         String?  @db.Text
  audience     String?  @db.Text
  keywords     String[]
  avoidWords   String[] @map("avoid_words")
  guidelines   String?  @db.Text
  visualStyle  String?  @map("visual_style") @db.Text
  systemPrompt String?  @map("system_prompt") @db.Text
  examplePosts Json?    @map("example_posts")
  updatedAt    DateTime @updatedAt

  Relation: brand Brand
```

### BrandInsight (Memory v2)

```
BrandInsight
  id               String   @id @default(cuid())
  brandId          String   @map("brand_id")
  conversationId   String?  @map("conversation_id")
  kind             String   // fact | preference | context | rule
  text             String
  entities         String[]
  confidence       Float    @default(0.7)
  sourceMessageIds String[] @map("source_message_ids")
  embedding        Unsupported("vector(768)")?  // pgvector ANN
  alwaysOn         Boolean  @default(false)  // always injected into system prompt
  supersededBy     String?  @map("superseded_by")
  createdAt        DateTime @default(now())

  Relation: brand Brand

  Indexes: [brandId, kind, createdAt], [brandId, alwaysOn]
```

### ContentSource (Repurpose)

```
ContentSource
  id           String   @id @default(cuid())
  brandId      String   @map("brand_id")
  url          String?
  platform     String?  // youtube, rss, etc.
  title        String?
  author       String?
  thumbnailUrl String?
  transcript   String?  @db.Text
  viewCount    BigInt?
  viralScore   Float?
  metadata     Json?
  status       String   @default("new")  // new | transcribed | composing | done

  createdAt  DateTime  @default(now())
  updatedAt  DateTime  @updatedAt
  deletedAt  DateTime?

  Relation: brand Brand

  Index: [brandId, status]
```

### Source (Workspace input)

```
Source
  id          String   @id @default(cuid())
  workspaceId String   @map("workspace_id")
  kind        String   // file | url | transcript | doc | image | video
  name        String
  url         String
  metadata    Json?
  createdAt   DateTime @default(now())

  Relation: workspace Workspace

  Index: [workspaceId]
```

### RunEvent (SSE log)

```
RunEvent
  id        String   @id @default(cuid())
  runId     String   @map("run_id")
  type      String   // stage | agent.message | tool.call | asset.created | run.ready | done | error
  dataJson  Json     @map("data_json")
  seq       Int      // monotonic per run
  createdAt DateTime @default(now())

  Relation: run Run

  @@unique([runId, seq])
  Index: [runId]
```

### Conversation + Messages

```
BrandConversation
  id              String   @id @default(cuid())
  brandId         String   @map("brand_id")
  channel         String   // telegram | slack | discord | web
  channelThreadId String?  @map("channel_thread_id")
  startedAt       DateTime @default(now())

  Relations: brand Brand, messages[], runs[]

  Index: [brandId, channel]

ConversationMessage
  id             String   @id @default(cuid())
  conversationId String   @map("conversation_id")
  role           String   // user | agent | system
  content        String   @db.Text
  attachments    Json?
  localPath      String?
  cloudUrl       String?
  mediaMeta      Json?    // { mimeType?, fileSize?, storageKey?, status }
  createdAt      DateTime @default(now())

  Relation: conversation BrandConversation

  Index: [conversationId, createdAt]
```

### ApiKey

```
ApiKey
  id         String    @id @default(cuid())
  brandId    String    @map("brand_id")
  name       String
  keyHash    String    @map("key_hash")  // bcrypt hash
  prefix     String    // first 12 chars: "cfw_abc1..."
  lastUsedAt DateTime?
  isActive   Boolean   @default(true)
  createdAt  DateTime  @default(now())

  Relation: brand Brand

  Indexes: [brandId], [prefix]
```

### ChannelConnection

```
ChannelConnection
  id        String   @id @default(cuid())
  brandId   String   @map("brand_id")
  channel   String   // telegram | whatsapp | sms | web
  channelId String   @map("channel_id")  // bot token, phone number, etc.
  userId    String?  @map("user_id")     // chat_id, phone number (null = all)
  label     String?
  isActive  Boolean  @default(true)
  metadata  Json     @default("{}")
  createdAt DateTime @default(now())

  Relation: brand Brand

  @@unique([channel, channelId, userId])
  Indexes: [brandId], [channel, channelId]
```

### Billing + Usage

```
CustomerConfig
  id             String @id @default(cuid())
  brandId        String @unique @map("brand_id")
  tier           String @default("founder")  // founder | standard | premium | enterprise
  hermesEndpoint String @default("shared")   // "shared" or dedicated VPS URL
  anthropicKeyEnc String? @db.Text  // enterprise-only, AES-256 encrypted
  openaiKeyEnc    String? @db.Text
  pfmKeyEnc       String? @db.Text
  pfmConnectionId String?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

BrandUsage (per month rollup)
  id               String  @id @default(cuid())
  brandId          String
  month            String  // "2026-04"
  aiGenerations    Int     @default(0)
  postsCreated     Int     @default(0)
  mediaUploadedMb  Int     @default(0)
  recipeExecutions Int     @default(0)
  aiCostUsd        Decimal @default(0) @db.Decimal(10, 4)

  @@unique([brandId, month])

AICostLog (per-call immutable)
  id           String   @id @default(cuid())
  brandId      String
  userId       String?
  model        String
  inputTokens  Int
  outputTokens Int
  costUsd      Decimal  @db.Decimal(10, 6)
  feature      String   // caption | image-prompt | research | recipe
  createdAt    DateTime @default(now())

  Index: [brandId, createdAt]
```

### Audit + Security

```
AuditLog (user-driven security events)
  id         String   @id @default(cuid())
  brandId    String?
  userId     String
  action     String   // dot-namespaced: brand.delete, billing.plan_change, platform.connect
  entityType String   // brand | user | post | subscription | platform_connection
  entityId   String?
  metadata   Json     @default("{}")
  ip         String?
  userAgent  String?
  createdAt  DateTime @default(now())

  Indexes: [brandId, createdAt], [userId, createdAt]

AgentAuditLog (per-turn LLM telemetry)
  id                    String   @id @default(cuid())
  brandId               String
  conversationId        String?
  channelUserId         String?
  inboundMessageId      String?
  toolName              String?
  toolInputHash         String?  // sha256 only — no raw payloads
  toolOutputHash        String?
  llmTokensIn           Int?
  llmTokensOut          Int?
  llmCostUsd            Decimal? @db.Decimal(10, 6)
  outputFilterTriggered Boolean  @default(false)
  createdAt             DateTime @default(now())

  Relation: brand Brand
  Index: [brandId, createdAt]
```

### Asset Libraries

```
MusicTrack
  id          String  @id @default(cuid())
  title       String
  artist      String
  durationSec Int
  category    String  // upbeat | chill | corporate | cinematic | trending
  storageKey  String
  cdnUrl      String
  attribution String?  // non-null = required in caption
  isActive    Boolean @default(true)

ImageTemplate
  id       String  @id @default(cuid())
  brandId  String? // null = system template
  slug     String  @unique
  name     String
  prompt   String  @db.Text  // supports {token} placeholders
  isActive Boolean @default(true)

CharacterRef
  id               String   @id @default(cuid())
  brandId          String
  slug             String   // @mention-able
  name             String
  starredImageKeys String[] // canonical Media.storageKey values

  @@unique([brandId, slug])
```

---

## Relationship Diagram (simplified)

```
User ──owns──▶ Brand ──has──▶ Workspace ──contains──▶ Agent ──executes──▶ Run
                                                      │                    │
                                                      │                    ├──emits──▶ RunEvent
                                                      │                    ├──produces──▶ Output
                                                      │                    └──creates──▶ Post
                                                      │
                                                      ├──sources──▶ Source
                                                      ├──compositions──▶ Composition ──has──▶ ApprovalToken
                                                      └──posts──▶ Post

Brand ──has──▶ BrandDna, PlatformConnection, ApiKey, PostTiming,
              ContentSource, BrandInsight, ChannelConnection,
              TelegramBot, SlackInstall, DiscordBot, CustomerConfig,
              Template, Composition, Post

BrandConversation ──has──▶ ConversationMessage
                     └──spawns──▶ Run
```

---

## Key Indexes for Query Patterns

| Query | Index |
|---|---|
| List workspaces for brand | `[brandId, status, deletedAt]` |
| List runs for workspace | `[workspaceId]` on Run |
| List posts for brand by status | `[brandId, status]` on Post |
| List posts for brand by scheduled time | `[brandId, scheduledAt]` on Post |
| List events for run, ordered | `[runId, seq]` (unique) on RunEvent |
| Resolve brand by API key prefix | `[prefix]` on ApiKey |
| Find content sources by status | `[brandId, status]` on ContentSource |
| Semantic insight search | `[brandId, kind, createdAt]`, `[brandId, alwaysOn]` on BrandInsight |
| Workspace intent matching | `intentEmbedding` (pgvector) on Workspace |

---

## R2 Storage Rules

All R2 keys MUST start with `${brandId}/`. Pattern:
```
${brandId}/${workspaceId|inbox}/${mediaId}.${ext}
```
The adapter throws if the key does not have the brand prefix.
