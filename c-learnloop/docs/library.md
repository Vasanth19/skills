# LearnLoop — Library Resources (Free + Gated)

Library is the public content hub per community. Resources can be free (anyone reads immediately) or gated (email capture before content is revealed).

See SKILL.md for `ll` / `ll_pub` helpers.

---

## Content Types

| `type` | `content` shape |
|--------|----------------|
| `article` | `{ "body": "markdown string" }` |
| `download` | `{ "fileUrl": "...", "fileType": "pdf", "fileSize": 102400 }` |
| `link` | `{ "url": "https://...", "siteName": "Example" }` |
| `video` | `{ "videoUrl": "...", "embedType": "youtube\|vimeo\|cloudflare\|mux" }` |
| `embed` | `{ "embedHtml": "<iframe ...>", "sourceUrl": "..." }` |

## Visibility vs Gating

| `visibility` | `isGated` | Who sees page | Who gets content |
|-------------|-----------|--------------|----------------|
| `public` | `false` | Anyone | Anyone |
| `public` | `true` | Anyone (gate form shown) | After email capture |
| `members` | — | Members only (403 for anon) | Members only |
| `unlisted` | `false` | Anyone with direct URL | Anyone |
| `unlisted` | `true` | Anyone with URL (gate shown) | After email capture |

---

## List public resources

```bash
ll_pub GET /library
ll_pub GET "/library?type=download&tag=ai&page=1&limit=20"
```

## Get a single resource

```bash
SLUG="ai-productivity-handbook"
ll_pub GET /library/$SLUG
# content=null when isGated=true and not yet unlocked
```

## Create a FREE resource

```bash
ll POST /library -d '{
  "slug": "ai-tips-2026",
  "title": "10 AI Tips for 2026",
  "type": "article",
  "content": { "body": "## Tip 1\n\nUse Claude for drafts..." },
  "visibility": "public",
  "publishedAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "tags": ["ai", "productivity"],
  "isFeatured": false
}'
```

## Create a GATED resource (email capture → download)

```bash
ll POST /library -d '{
  "slug": "ai-productivity-handbook",
  "title": "The AI Productivity Handbook",
  "type": "download",
  "content": {
    "fileUrl": "https://r2.learnloop.cc/files/handbook.pdf",
    "fileType": "pdf",
    "fileSize": 2048000
  },
  "visibility": "public",
  "publishedAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "isGated": true,
  "gateConfig": {
    "buttonText": "Download Free",
    "thankYouMessage": "Here'\''s your handbook!",
    "collectName": true
  }
}'
```

## Create a GATED video resource

```bash
ll POST /library -d '{
  "slug": "prompt-masterclass",
  "title": "Prompt Masterclass (Free)",
  "type": "video",
  "content": {
    "videoUrl": "https://youtube.com/watch?v=XXXX",
    "embedType": "youtube"
  },
  "visibility": "public",
  "publishedAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "isGated": true,
  "gateConfig": {
    "buttonText": "Watch Free",
    "collectName": false
  }
}'
```

## Gate an existing resource

```bash
RESOURCE_ID="550e8400-e29b-41d4-a716-446655440000"
ll PATCH /library/$RESOURCE_ID -d '{
  "isGated": true,
  "gateConfig": { "buttonText": "Get Free Access", "collectName": true }
}'
```

## Remove gate (make free)

```bash
ll PATCH /library/$RESOURCE_ID -d '{ "isGated": false }'
```

## Update content / metadata

```bash
ll PATCH /library/$RESOURCE_ID -d '{
  "title": "New Title",
  "tags": ["ai", "tools"],
  "coverImageUrl": "https://r2.learnloop.cc/covers/new.jpg"
}'
```

## Toggle publish / feature / enable

```bash
ll POST /library/$RESOURCE_ID/publish   # toggle published state
ll POST /library/$RESOURCE_ID/feature   # toggle isFeatured
ll POST /library/$RESOURCE_ID/enable    # toggle isEnabled
```

## Reorder resources

```bash
ll POST /library/reorder -d '{
  "ids": ["uuid-1", "uuid-2", "uuid-3"]
}'
```

## Delete a resource

```bash
ll DELETE /library/$RESOURCE_ID
```

---

## Gated Content — Unlock (visitor-facing, no auth)

This is what happens when a visitor submits the gate form. Call from any script simulating a visitor.

```bash
SLUG="ai-productivity-handbook"

RESULT=$(ll_pub POST /library/$SLUG/unlock -d '{
  "email": "jane@example.com",
  "name": "Jane Smith"
}')

# Extract the file URL
echo "$RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']['content']
print(data.get('fileUrl') or data.get('videoUrl') or data.get('url') or 'content:', data)
"
```

**What happens internally:**
1. Lead recorded in `libraryResourceLeads` (unique per resourceId + email — safe to call twice)
2. Email upserted into newsletter subscribers (`isActive: true`, reactivates unsubscribes)
3. Full `content` returned

---

## Leads (admin)

### List leads for a resource

```bash
RESOURCE_ID="550e8400-e29b-41d4-a716-446655440000"

ll GET /library/admin/leads/$RESOURCE_ID \
  | python3 -c "
import sys, json
leads = json.load(sys.stdin)['data']
print(f'{len(leads)} leads')
for l in leads:
    print(l['submittedAt'][:10], l['email'], l.get('name',''))
"
```

### Export leads to CSV

```bash
ll GET /library/admin/leads/$RESOURCE_ID \
  | python3 -c "
import sys, json, csv
leads = json.load(sys.stdin)['data']
w = csv.writer(sys.stdout)
w.writerow(['email','name','submittedAt'])
for l in leads: w.writerow([l['email'], l.get('name',''), l['submittedAt']])
" > leads.csv && echo "Exported $(wc -l < leads.csv) rows"
```

---

## Admin: list all resources (including drafts/disabled)

```bash
ll GET /library/admin/all
ll GET "/library/admin/all?type=download&visibility=public&search=handbook"
```

---

## AI features (admin)

```bash
# Generate AI summary + meta description for a resource
ll POST /library/ai/summarize/$RESOURCE_ID

# Generate AI description from title + content
ll POST /library/ai/generate-description -d '{
  "title": "AI Productivity Handbook",
  "type": "download",
  "content": "Covers 10 AI tools for creators..."
}'

# Generate AI cover image (returns R2 URL)
ll POST /library/ai/generate-cover-image -d '{
  "title": "AI Productivity Handbook",
  "type": "download",
  "content": "Covers 10 AI tools for creators..."
}'

# Get AI content suggestions for library
ll GET /library/ai/suggestions
ll POST /library/ai/suggestions/generate   # generate new batch
ll PATCH /library/ai/suggestions/$SUGGESTION_ID -d '{ "status": "approved" }'
```

---

## Gotchas

- `content` is `null` in GET responses for gated resources — never assume it's always an object.
- Upload files to Cloudflare R2 first (`POST /admin/upload`), then use the returned URL as `fileUrl`.
- `publishedAt: null` = draft. Pass `"publishedAt": "<ISO datetime>"` to publish immediately.
- Tags are free-form strings — no pre-registration needed.
- AI summarize runs async (fire-and-forget). Poll GET `/:slug` after ~5s to see `aiSummary` populated.
