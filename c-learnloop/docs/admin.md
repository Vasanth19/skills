# LearnLoop — Admin: Settings, Categories, API Keys

Community-level configuration. All endpoints require admin auth.

See SKILL.md for `ll` helper.

---

## Community Settings

### Get current settings
```bash
ll GET /admin/settings | python3 -m json.tool
```

### Update settings
```bash
ll PATCH /admin/settings -d '{
  "name": "Pragmatic AI Lab",
  "description": "No-fluff AI education for builders.",
  "brandColor": "#3D3E9B",
  "isPrivate": false,
  "communityType": "freemium",
  "welcomeMessage": "Welcome! Start with the Courses tab."
}'
```

### Update navigation tabs visibility
```bash
ll PATCH /admin/navigation-tabs -d '{
  "tabs": {
    "feed": true,
    "courses": true,
    "library": true,
    "events": true,
    "members": true,
    "newsletter": true,
    "prompts": false
  }
}'
```

---

## Post Categories

### List categories
```bash
ll GET /admin/categories
```

### Create a category
```bash
ll POST /admin/categories -d '{
  "name": "Course Q&A",
  "emoji": "🎓",
  "description": "Questions about specific lessons or modules"
}'
```

### Update a category
```bash
CATEGORY_ID="..."
ll PATCH /admin/categories/$CATEGORY_ID -d '{
  "name": "Updated Name",
  "emoji": "📚"
}'
```

### Reorder categories
```bash
ll POST /admin/categories/reorder -d '{
  "orderedIds": ["uuid-1", "uuid-2", "uuid-3"]
}'
```

### Delete a category
```bash
ll DELETE /admin/categories/$CATEGORY_ID
```

---

## Community Rules

### List rules
```bash
ll GET /admin/rules
```

### Create a rule
```bash
ll POST /admin/rules -d '{
  "title": "Be respectful",
  "description": "Treat everyone with kindness. No harassment, personal attacks, or hate speech.",
  "orderIndex": 0
}'
```

### Update a rule
```bash
RULE_ID="..."
ll PATCH /admin/rules/$RULE_ID -d '{ "title": "Updated rule title" }'
```

### Reorder rules
```bash
ll POST /admin/rules/reorder -d '{ "orderedIds": ["uuid-1", "uuid-2"] }'
```

### Delete a rule
```bash
ll DELETE /admin/rules/$RULE_ID
```

---

## API Keys

### List API keys
```bash
ll GET /admin/api-keys | python3 -c "
import sys, json
keys = json.load(sys.stdin)['data']
for k in keys:
    print(k['id'], k['name'], k['createdAt'][:10], 'last used:', k.get('lastUsedAt','never'))
"
```

### Create an API key
```bash
RESULT=$(ll POST /admin/api-keys -d '{ "name": "Paperclip Agent Key" }')
API_KEY=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])")
echo "Save this — shown once: $API_KEY"
```

**The key is only shown once on creation.** Store it immediately in `.env` or your secrets manager.

### Delete an API key
```bash
KEY_ID="..."
ll DELETE /admin/api-keys/$KEY_ID
```

---

## File Upload (R2)

Upload files before creating library resources, bot avatars, product fulfillment files, or post attachments.

```bash
FILE_PATH="/path/to/handbook.pdf"
UPLOAD=$(curl -s -X POST "$LL_URL/admin/upload" \
  -H "Authorization: Bearer $LEARNLOOP_API_KEY" \
  -H "x-community-slug: $LL_SLUG" \
  -F "file=@$FILE_PATH")

URL=$(echo "$UPLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['url'])")
KEY=$(echo "$UPLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])")
echo "URL: $URL"
echo "Key: $KEY"
```

Response shape: `{ data: { url, key, size, contentType } }`

Supported: PDF, images (jpg, png, webp, gif), zip, mp4.

---

## Community info (public)

```bash
# Get community by slug — no auth needed
curl -s "$LL_URL/tenants/by-slug/$LL_SLUG" | python3 -m json.tool

# Discover communities (search)
curl -s "$LL_URL/tenants/discover?search=ai" | python3 -m json.tool
```

---

## Gotchas

- API keys have no expiry — rotate them manually if compromised via `DELETE` + `POST`.
- File uploads are limited to 50MB per file. For large videos, use Cloudflare Stream directly.
- `communityType` options: `"free"` | `"paid"` | `"freemium"`. Changing to `"paid"` requires a connected Stripe account.
- `brandColor` must be a valid hex string (`"#3D3E9B"`). Used across the UI as the primary accent.
- Navigation tab visibility changes take effect immediately with no cache invalidation needed.

---

## `actingAsClerkId` — Impersonating a User via API Key

Every API key row in the `apiKeys` table has an optional `actingAsClerkId` column. When set, the auth middleware synthesises a Clerk-style auth context (`{ type: "clerk", userId: actingAsClerkId }`) instead of a bare API-key context — making the request appear to the route handler as if that Clerk user made it. This is how **AI bots post to the community feed**: each bot's dedicated API key has `actingAsClerkId` pointing to the bot's Clerk member ID, so bot posts and comments are attributed correctly. Set it when creating an API key for any non-human actor that must appear as a specific community member. Leave it `null` for admin/automation keys that don't need a member identity (those get `type: "api_key"` auth and pass all `requireTenantAdmin` checks directly).

```bash
# Create a bot API key that acts as a specific Clerk user
RESULT=$(ll POST /admin/api-keys -d '{
  "name": "Aria Bot Key",
  "actingAsClerkId": "user_2abc123"
}')
API_KEY=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])")
echo "Save once: $API_KEY"
```

---

## Auth Scopes

LearnLoop API keys carry a `scopes` array (stored in the DB, returned on key creation). The backend currently uses three auth tiers rather than fine-grained OAuth scopes: **public** (no auth — `ll_pub`, slug header only), **tenant-admin** (`requireTenantAdmin` middleware — any valid API key or Clerk org admin/owner JWT passes), and **member/Clerk-scoped** (`getClerkAuth()` — requires a real Clerk JWT or an API key with `actingAsClerkId` set; bare API keys without that field are rejected). Routes like course progress, RSVP, follow/unfollow, and personalized courses are member-scoped and will return 403 for a bare admin key. If you need to call those routes via API key, create the key with `actingAsClerkId` pointing to the target member's Clerk ID.
