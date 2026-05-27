# CFW Social — Publishing System

How content moves from approved compositions to published posts across social platforms.

---

## Post Data Model

```
Post
  id             String   @id @default(cuid())
  brandId        String
  workspaceId    String?  // nullable
  compositionId  String?  // nullable (SetNull on delete)
  runId          String?  // nullable
  outputId       String?  // nullable

  platform     String   // instagram | tiktok | youtube | twitter | linkedin | facebook | pinterest | threads | bluesky
  kind         String   @default("post")  // post | reel | story | carousel | video | multi_image
  caption      String?  @db.Text
  mediaUrl     String?  // primary R2 CDN url
  mediaUrls    String[] // carousel / multi-image set

  status       String   @default("scheduled")
  scheduledAt  DateTime?
  publishedAt  DateTime?
  publishedUrl String?
  errorMessage String?  @db.Text

  pfmPostId    String?  @unique  // PostForMe external id

  metadata     Json?
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
```

### Indexes

- `[brandId, status]` — list posts by status
- `[brandId, scheduledAt]` — scheduler polling
- `[brandId, platform]` — analytics per platform
- `[outputId]` — find posts for an output
- `[compositionId]` — find posts for a composition

---

## Post Status Lifecycle

```
┌─────────┐   manual or approval   ┌───────────┐   scheduler polls   ┌───────────┐
│  draft  │ ─────────────────────▶│ scheduled │ ──────────────────▶│ publishing │
└─────────┘                        └─────┬─────┘                        └─────┬─────┘
                                       │                                    │
                                       │ user cancels                       │ platform confirms
                                       ▼                                    ▼
                                 ┌───────────┐                        ┌───────────┐
                                 │ cancelled │                        │  published │
                                 └───────────┘                        └───────────┘
                                                                              │
                                                                              │ platform error
                                                                              ▼
                                                                       ┌───────────┐
                                                                       │   failed   │
                                                                       └───────────┘
```

### Status definitions

| Status | Meaning | Writable by |
|---|---|---|
| `draft` | Post row exists but not scheduled (incl. approved posts with no connected platform yet) | User / agent / approval handler |
| `scheduled` | `scheduledAt` set, waiting for publish time | Scheduler / approval handler |
| `publishing` | Platform API call in flight | Publisher worker |
| `published` | Platform confirmed publish | Webhook handler |
| `failed` | Platform returned error | Webhook handler / publisher retry |
| `cancelled` | User cancelled before publishing | User action |

---

## Scheduling

### PostTiming configuration

`PostTiming` rows define when content should be published:

```
PostTiming
  id             String  @id @default(cuid())
  brandId        String
  platform       String  // instagram, linkedin, etc.
  dayOfWeek      Int     // 0=Sun, 1=Mon, ..., 6=Sat
  timeSlot       String  // "09:00", "12:30", "18:00"
  maxPostsPerDay Int     @default(3)
  isActive       Boolean @default(true)
  priority       Int     @default(0)

  @@unique([brandId, platform, dayOfWeek, timeSlot])
```

### Approval always succeeds — unconnected platforms become drafts

**A missing platform connection is NOT an approval failure.** When a dish is
approved (`POST /api/v1/inbox/approve`), each output's target platform is
checked against the brand's active `PlatformConnection`s:

- **Connected** → the post is scheduled (3-tier algorithm below) and, if a
  publish time is computed, queued with PostForMe.
- **Not connected** (or connected but no schedulable slot) → the post is still
  created, as a **draft** (`status = "draft"`, `scheduledAt = null`, no PostForMe
  call). The composition is still marked `approved` and the approval token is
  stamped. The owner (or an agent) schedules these drafts later — from the
  calendar or programmatically — once a platform is connected.

Approval only returns an error (HTTP 422) when **nothing** could be created at
all (e.g. an output has no caption). The response separates the outcomes:

```jsonc
{
  "scheduled": [{ "platform": "linkedin", "scheduledAt": "…", "postId": "…", "pfmPostId": "…" }],
  "drafted":   [{ "platform": "linkedin", "postId": "…" }],   // approved, awaiting a connection / slot
  "failed":    [{ "platform": "…", "error": "…" }]            // genuine errors only (no caption, PFM/DB error)
}
```

This is the standard everywhere approval happens (inbox + workspace dish
preview): approving never blocks on connection state; it degrades to a draft.

### How scheduling works

1. **Approval creates posts** with `status = "scheduled"` (connected) or
   `status = "draft"` (unconnected / unschedulable — see above)
2. **Scheduler worker** polls every minute:
   ```sql
   SELECT * FROM posts
   WHERE status = 'scheduled'
     AND scheduled_at <= NOW()
   ORDER BY scheduled_at ASC
   ```
3. **For each post**, determine publisher:
   - If `PlatformConnection.provider = "postforme"` → send to PostForMe API
   - If `provider = "direct"` → use OAuth tokens directly (future)
4. **Update post**: `status = "publishing"`
5. **PostForMe returns** `pfmPostId` immediately
6. **Webhook confirms** final status (`published` or `failed`)

### Scheduling algorithm

When approval creates posts, the scheduler picks the next available slot:

```
For each target platform:
  1. Find PostTiming rows for (brandId, platform, today.dayOfWeek)
  2. Filter to isActive = true, timeSlot > now()
  3. Sort by priority desc, timeSlot asc
  4. Check maxPostsPerDay: count today's posts for platform
  5. If under limit, assign earliest slot
  6. If over limit, assign next available day
```

---

## Calendar View

`GET /api/v1/posts/calendar` returns posts grouped by date for calendar rendering.

### Response shape

```json
{
  "posts": [
    {
      "id": "...",
      "platform": "instagram",
      "kind": "reel",
      "caption": "...",
      "mediaUrl": "https://cdn...",
      "status": "scheduled",
      "scheduledAt": "2026-05-20T09:00:00Z",
      "publishedAt": null,
      "publishedUrl": null
    }
  ]
}
```

### Calendar filters

| Filter | Endpoint param |
|---|---|
| Date range | `?from=2026-05-01&to=2026-05-31` |
| Platform | `?platform=instagram` |
| Status | `?status=scheduled` |

---

## Post Counts

`GET /api/v1/posts/count` returns aggregate counts:

```json
{
  "total": 150,
  "byStatus": {
    "draft": 10,
    "scheduled": 25,
    "published": 100,
    "failed": 15
  },
  "byPlatform": {
    "instagram": 40,
    "linkedin": 35,
    "twitter": 30,
    "tiktok": 25,
    "youtube": 20
  }
}
```

---

## Platform-Specific Constraints

### Instagram

| Constraint | Value |
|---|---|
| Max images per carousel | 10 |
| Max video duration (Reels) | 90 seconds |
| Aspect ratio (Reels) | 9:16 |
| Caption | 2,200 chars |
| Hashtags | 30 max |
| File size (image) | 8 MB |
| File size (video) | 650 MB |

### LinkedIn

| Constraint | Value |
|---|---|
| Max images | 1 (native) / 9 (some third-party) |
| Video duration | 30 min |
| Caption | 3,000 chars |
| Article posts | Support long-form with title + body |

### X (Twitter)

| Constraint | Value |
|---|---|
| Tweet text | 280 chars (4,800 with Premium) |
| Images per tweet | 4 |
| Video duration | 2 min 20 sec (standard) / 60 min (Premium) |
| Thread chaining | Via `in_reply_to_tweet_id` |

### TikTok

| Constraint | Value |
|---|---|
| Video duration | 15 sec – 10 min |
| Aspect ratio | 9:16 |
| Caption | 2,200 chars |
| Hashtags | 33 max |

### YouTube

| Constraint | Value |
|---|---|
| Shorts duration | < 60 seconds |
| Regular video | Up to 12 hours (verified) |
| Title | 100 chars |
| Description | 5,000 chars |
| Tags | 500 chars total |

### Facebook

| Constraint | Value |
|---|---|
| Images per post | 10 |
| Video duration | 240 min |
| Caption | 63,206 chars |

### Pinterest

| Constraint | Value |
|---|---|
| Images per Pin | 1 |
| Aspect ratio | 2:3 preferred |
| Description | 500 chars |

### Threads

| Constraint | Value |
|---|---|
| Images per post | 10 |
| Video duration | 5 min |
| Caption | 500 chars |

### Bluesky

| Constraint | Value |
|---|---|
| Images per post | 4 |
| Video duration | 60 sec |
| Caption | 300 chars |

---

## Publishing via PostForMe

### Flow

1. cfw-social calls PostForMe API with:
   - `platform` (e.g., "instagram")
   - `caption`
   - `mediaUrls[]` (R2 public URLs)
   - `scheduledAt` (optional, for delayed publish)
2. PostForMe returns `pfmPostId`
3. cfw-social updates `Post.pfmPostId`
4. PostForMe publishes at scheduled time
5. PostForMe sends webhook to `/api/v1/webhooks/postforme/events`
6. cfw-social updates `Post.status`, `Post.publishedAt`, `Post.publishedUrl`

### Webhook events

| Event | Post status |
|---|---|
| `post.created` | `publishing` |
| `post.published` | `published` |
| `post.failed` | `failed` |
| `post.deleted` | (row remains, status unchanged or set to `draft`) |

### Error handling

If `PostForMe` returns an error:
- `Post.status` → `failed`
- `Post.errorMessage` = error text
- Retry logic: up to 3 attempts with exponential backoff
- After max retries, alert brand owner

---

## Direct Publishing (Future)

When `PlatformConnection.provider = "direct"`:

1. cfw-social uses OAuth tokens from `PlatformConnection.accessTokenEnc`
2. Calls platform APIs directly (e.g., Instagram Graph API)
3. No PostForMe intermediary
4. Webhooks from platform update post status

---

## Post Deletion

`DELETE /api/v1/posts/{postId}` — removes a post row.

- If post is `scheduled` and `pfmPostId` exists, also call PostForMe cancel
- If post is `published`, only delete the local row (platform post remains)
- Soft delete or hard delete depending on policy

---

## Analytics

### Post-level

- `publishedAt` vs `scheduledAt` — on-time delivery rate
- `errorMessage` — failure reasons by platform
- `publishedUrl` — direct link to live post

### Brand-level

`BrandUsage` table tracks per-month:
- `postsCreated`
- `mediaUploadedMb`
- `aiGenerations`
- `recipeExecutions`
- `aiCostUsd`
