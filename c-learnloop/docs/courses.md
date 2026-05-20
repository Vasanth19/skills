# LearnLoop — Courses, Modules & Lessons

All endpoints require admin auth + community slug header. See SKILL.md for `ll` helper.

---

## Courses

### List courses
```bash
ll GET /courses | python3 -m json.tool
```

### Get a single course (by ID or slug)
```bash
ll GET /courses/my-course-slug | python3 -m json.tool
```

### Create a course
```bash
ll POST /courses -d '{
  "title": "AI for Creators",
  "description": "No-fluff guide to using AI in your content workflow.",
  "accessType": "members_only",
  "difficulty": "beginner",
  "estimatedDuration": 120
}'
```

`accessType` options: `"open"` | `"members_only"` | `"level_unlock"` | `"buy_now"`

### Update a course
```bash
COURSE_ID="550e8400-e29b-41d4-a716-446655440000"
ll PATCH /courses/$COURSE_ID -d '{
  "title": "Updated Title",
  "isPublished": true
}'
```

### Delete a course
```bash
ll DELETE /courses/$COURSE_ID
```

### AI-generate course structure from a goal
```bash
ll POST /courses/generate -d '{
  "goal": "Help creators understand prompt engineering in 5 lessons",
  "targetAudience": "non-technical content creators"
}'
```

---

## Modules

### Create a module inside a course
```bash
COURSE_ID="..."
ll POST /courses/$COURSE_ID/modules -d '{
  "title": "Module 1 — The Basics",
  "description": "Foundation concepts",
  "orderIndex": 0
}'
```

### Update a module
```bash
MODULE_ID="..."
ll PATCH /courses/$COURSE_ID/modules/$MODULE_ID -d '{
  "title": "Module 1 — Foundations (Revised)"
}'
```

### Delete a module
```bash
ll DELETE /courses/$COURSE_ID/modules/$MODULE_ID
```

---

## Lessons

### Create a lesson inside a module
```bash
ll POST /courses/$COURSE_ID/modules/$MODULE_ID/lessons -d '{
  "title": "What is a Prompt?",
  "contentMarkdown": "## Introduction\n\nA prompt is the instruction you give to an AI...",
  "orderIndex": 0,
  "isPreview": false,
  "videoSource": "youtube",
  "videoYoutubeId": "dQw4w9WgXcQ"
}'
```

**Video source options:** `"youtube"` | `"cloudflare"` | `"mux"` | `null`

### Update a lesson
```bash
LESSON_ID="..."
ll PATCH /courses/$COURSE_ID/modules/$MODULE_ID/lessons/$LESSON_ID -d '{
  "contentMarkdown": "## Updated content...",
  "isPreview": true
}'
```

### Get a lesson (with navigation context — prev/next)
```bash
ll GET /courses/$COURSE_ID/lessons/$LESSON_ID | python3 -m json.tool
```

### Delete a lesson
```bash
ll DELETE /courses/$COURSE_ID/modules/$MODULE_ID/lessons/$LESSON_ID
```

---

## Progress (Member-facing)

### Get course progress for current user
```bash
# Requires Clerk JWT (not API key) — member-scoped
curl -s "$LL_URL/courses/$COURSE_ID/progress" \
  -H "Authorization: Bearer $CLERK_JWT" \
  -H "x-community-slug: $LL_SLUG" | python3 -m json.tool
```

### Mark a lesson complete
```bash
ll POST /courses/$COURSE_ID/lessons/$LESSON_ID/progress -d '{
  "completed": true,
  "watchedSeconds": 342
}'
```

---

## Personalized Course (AI-generated for a member)

### Generate a personalized course from goal
```bash
# Member-scoped — needs Clerk JWT
curl -s -X POST "$LL_URL/courses/personalize" \
  -H "Authorization: Bearer $CLERK_JWT" \
  -H "x-community-slug: $LL_SLUG" \
  -H "Content-Type: application/json" \
  -d '{ "goal": "Learn how to automate my content pipeline with AI" }'
```

### Get active personalized course
```bash
curl -s "$LL_URL/courses/personalize/active" \
  -H "Authorization: Bearer $CLERK_JWT" \
  -H "x-community-slug: $LL_SLUG" | python3 -m json.tool
```

---

## Bulk seed — create a full course with modules + lessons in one script

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../../../.env"

# 1. Create course
COURSE=$(ll POST /courses -d '{
  "title": "Prompt Engineering for Creators",
  "description": "Practical prompting in 4 lessons.",
  "accessType": "members_only",
  "difficulty": "beginner"
}')
COURSE_ID=$(echo "$COURSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
echo "Course: $COURSE_ID"

# 2. Create module
MOD=$(ll POST /courses/$COURSE_ID/modules -d '{
  "title": "Module 1 — Foundations",
  "orderIndex": 0
}')
MOD_ID=$(echo "$MOD" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")

# 3. Add lessons
for i in 1 2 3; do
  ll POST /courses/$COURSE_ID/modules/$MOD_ID/lessons -d "{
    \"title\": \"Lesson $i\",
    \"contentMarkdown\": \"## Lesson $i\\n\\nContent here.\",
    \"orderIndex\": $((i-1))
  }" > /dev/null
  echo "Added lesson $i"
done

echo "Done — course $COURSE_ID ready."
```

---

## Gotchas

- `accessType: "level_unlock"` requires `unlockLevel` (int) in the payload.
- `accessType: "buy_now"` requires `priceAmount` (cents) and a connected Stripe account.
- Lessons inherit course visibility — a published course with `isPreview: false` lessons requires membership to view.
- `videoYoutubeId` is just the video ID (e.g. `dQw4w9WgXcQ`) — not the full URL.
- Module/lesson `orderIndex` is 0-based. Gap-free integers recommended; the frontend respects order as returned.
