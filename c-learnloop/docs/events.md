# LearnLoop — Events

Community events with RSVP tracking, recurrence, and AI-assisted scheduling.

See SKILL.md for `ll` helper.

---

## List events

```bash
ll GET /events
ll GET "/events?month=2026-05"    # filter by month (YYYY-MM)
```

## Get a single event

```bash
EVENT_ID="..."
ll GET /events/$EVENT_ID | python3 -m json.tool
```

## Create an event (admin)

```bash
ll POST /events -d '{
  "title": "Live Q&A — AI Tools for Creators",
  "description": "Ask anything about the tools we covered this month.",
  "startDate": "2026-05-15T18:00:00Z",
  "endDate": "2026-05-15T19:30:00Z",
  "location": "Zoom (link sent on RSVP)",
  "isOnline": true,
  "coverImageUrl": "https://r2.learnloop.cc/events/qa-cover.jpg",
  "maxAttendees": 100
}'
```

### Create a recurring event

```bash
ll POST /events -d '{
  "title": "Weekly Office Hours",
  "description": "Drop in and ask questions.",
  "startDate": "2026-05-06T17:00:00Z",
  "endDate": "2026-05-06T18:00:00Z",
  "isOnline": true,
  "recurrenceRule": "FREQ=WEEKLY;BYDAY=TU;COUNT=8"
}'
```

`recurrenceRule` is an iCal RRULE string. Common patterns:
- Weekly on Tuesday: `FREQ=WEEKLY;BYDAY=TU;COUNT=8`
- Monthly on 1st: `FREQ=MONTHLY;BYMONTHDAY=1;COUNT=6`
- Every 2 weeks: `FREQ=WEEKLY;INTERVAL=2;COUNT=10`

## Update an event (admin)

```bash
ll PATCH /events/$EVENT_ID -d '{
  "title": "Updated Event Title",
  "location": "Google Meet (new link)",
  "maxAttendees": 200
}'
```

## Delete an event (admin)

```bash
ll DELETE /events/$EVENT_ID
```

## RSVP to an event (member)

```bash
# Requires Clerk JWT — member-scoped
curl -s -X POST "$LL_URL/events/$EVENT_ID/rsvp" \
  -H "Authorization: Bearer $CLERK_JWT" \
  -H "x-community-slug: $LL_SLUG" \
  -H "Content-Type: application/json" \
  -d '{ "status": "going" }'
```

RSVP status options: `"going"` | `"maybe"` | `"not_going"`

---

## AI Event Features (admin)

### Suggest optimal times for a new event

```bash
ll POST /events-ai/suggest-times -d '{
  "duration": 90,
  "preferredDays": ["tuesday", "thursday"],
  "timezone": "America/Chicago",
  "targetAudience": "working professionals"
}'
```

### Generate an event description with AI

```bash
ll POST /events-ai/generate-description -d '{
  "title": "AI Tools Workshop",
  "format": "live Q&A",
  "duration": 60,
  "topics": ["ChatGPT", "Claude", "automation"]
}'
```

### Predict expected attendance

```bash
ll POST /events-ai/predict-attendance -d '{
  "eventType": "workshop",
  "dayOfWeek": "tuesday",
  "startTime": "18:00",
  "topic": "AI tools"
}'
```

### Analyze historical attendance patterns

```bash
ll POST /events-ai/analyze-attendance
```

---

## Bulk create events for a series

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../../../.env"

TITLES=(
  "Week 1 — Foundations of AI Prompting"
  "Week 2 — ChatGPT for Content"
  "Week 3 — Claude for Long-Form"
  "Week 4 — Automation with n8n"
)

START_DATE="2026-05-13T18:00:00Z"

for i in "${!TITLES[@]}"; do
  WEEK_OFFSET=$((i * 7))
  START=$(python3 -c "
from datetime import datetime, timedelta
d = datetime.fromisoformat('${START_DATE%Z}') + timedelta(days=$WEEK_OFFSET)
print(d.strftime('%Y-%m-%dT%H:%M:%SZ'))
")
  END=$(python3 -c "
from datetime import datetime, timedelta
d = datetime.fromisoformat('${START_DATE%Z}') + timedelta(days=$WEEK_OFFSET, hours=1)
print(d.strftime('%Y-%m-%dT%H:%M:%SZ'))
")

  RESULT=$(ll POST /events -d "{
    \"title\": \"${TITLES[$i]}\",
    \"startDate\": \"$START\",
    \"endDate\": \"$END\",
    \"isOnline\": true
  }")
  echo "Created: $(echo $RESULT | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')"
done
```

---

## Gotchas

- `recurrenceRule` creates a parent event + child events. Deleting the parent removes all children.
- `endDate` must be after `startDate` — backend validates this.
- `maxAttendees: null` = unlimited. Once the limit is reached, new RSVPs are blocked.
- RSVP endpoints are member-scoped (Clerk JWT). Admin/API key cannot RSVP on behalf of members.
- Timezone in the response is always UTC — convert for display using the community's timezone setting.
