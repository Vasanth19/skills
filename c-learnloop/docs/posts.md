# LearnLoop — Community Feed & Posts

The community feed is the social layer. Members post updates, ask questions, share wins. Admins can pin, moderate, and create posts via API.

See SKILL.md for `ll` helper.

---

## List posts

```bash
ll GET /posts
ll GET "/posts?category=announcement&page=1&limit=20"
```

Category options: `"all"` | `"general"` | `"lesson_qna"` | `"announcement"`

## Create a post

```bash
ll POST /posts -d '{
  "content": "Welcome to the community! 👋 Introduce yourself below.",
  "category": "announcement",
  "isPinned": false
}'
```

### Create a pinned announcement

```bash
ll POST /posts -d '{
  "content": "## 🚀 New course just dropped!\n\nCheck out **AI for Creators** in the Classroom tab.",
  "category": "announcement",
  "isPinned": true
}'
```

### Create a post with a link/image

```bash
ll POST /posts -d '{
  "content": "Check out this great resource on prompt engineering.",
  "category": "general",
  "attachmentUrl": "https://example.com/resource",
  "attachmentType": "link"
}'
```

## Get a single post

```bash
POST_ID="..."
ll GET /posts/$POST_ID | python3 -m json.tool
```

## Update a post (author only)

```bash
ll PATCH /posts/$POST_ID -d '{
  "content": "Updated content..."
}'
```

## Delete a post (author or admin)

```bash
ll DELETE /posts/$POST_ID
```

## Pin / unpin a post (admin)

```bash
ll POST /posts/$POST_ID/pin   # toggles pin state
```

## Like / unlike a post

```bash
ll POST /posts/$POST_ID/like
ll DELETE /posts/$POST_ID/like
```

## Bookmark / remove bookmark

```bash
ll POST /posts/$POST_ID/bookmark
ll DELETE /posts/$POST_ID/bookmark
```

## Get bookmarked posts (current user)

```bash
ll GET /posts/bookmarked | python3 -m json.tool
```

---

## Comments

### List comments on a post

```bash
ll GET /posts/$POST_ID/comments | python3 -c "
import sys, json
comments = json.load(sys.stdin)['data']
for c in comments:
    print(c['createdAt'][:10], c.get('author',{}).get('displayName','?'), c['content'][:80])
"
```

### Add a comment

```bash
ll POST /posts/$POST_ID/comments -d '{
  "content": "Great post! I had the same experience with GPT-4o."
}'
```

---

## AI post generation (admin)

```bash
# Generate post ideas from community context
ll POST /posts/generate-ideas -d '{
  "topic": "AI tools for content creators",
  "count": 5
}'

# Generate a full post from an idea
ll POST /posts/generate -d '{
  "idea": "How I used Claude to 10x my newsletter output",
  "tone": "conversational",
  "category": "general"
}'
```

---

## Report a post

```bash
ll POST /posts/$POST_ID/report -d '{
  "reason": "spam",
  "details": "This post contains repeated promotional links."
}'
```

Reason options: `"spam"` | `"harassment"` | `"misinformation"` | `"off_topic"` | `"other"`

---

## Seed multiple announcement posts

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../../../.env"

ANNOUNCEMENTS=(
  "Welcome to the community! Introduce yourself below 👇"
  "📚 Check out the Courses tab — we'\''ve added 3 new lessons this week."
  "🎯 Community challenge: share your biggest AI win this month."
)

for msg in "${ANNOUNCEMENTS[@]}"; do
  RESULT=$(ll POST /posts -d "{\"content\": \"$msg\", \"category\": \"announcement\"}")
  echo "Created: $(echo $RESULT | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')"
done
```

---

## Gotchas

- `content` supports Markdown — the frontend renders it with GFM.
- `isPinned: true` on create requires admin auth. Members cannot pin their own posts.
- Only one post can be pinned at a time per category — pinning a new post unpins the previous one.
- File attachments (`POST /posts/upload`) return a URL — pass it as `attachmentUrl` in the post payload.
- The `feedType` query param (if supported) controls algorithmic vs chronological ordering — default is chronological.
