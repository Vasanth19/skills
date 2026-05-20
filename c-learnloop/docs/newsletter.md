# LearnLoop — Newsletter

Manage email campaigns and subscriber lists per community. Campaigns are drafted, then scheduled or sent immediately. Subscribers are added via the public subscribe form, gate unlocks, or admin import.

See SKILL.md for `ll` / `ll_pub` helpers.

---

## Campaigns

### List all campaigns (admin)
```bash
ll GET /admin/newsletter
```

### Get a single campaign
```bash
CAMPAIGN_ID="..."
ll GET /admin/newsletter/$CAMPAIGN_ID | python3 -m json.tool
```

### Create a draft campaign
```bash
ll POST /admin/newsletter -d '{
  "title": "May Update — New Courses + AI Tools",
  "subject": "5 AI tools worth your time this month",
  "previewText": "Plus: new courses, community wins...",
  "body": "## Hey {firstName},\n\nHere'\''s what'\''s new this month...",
  "slug": "may-2026-update"
}'
```

`body` supports Markdown. Use `{firstName}` for personalization (replaced per recipient).

### Update a draft campaign
```bash
ll PATCH /admin/newsletter/$CAMPAIGN_ID -d '{
  "subject": "Revised subject line",
  "body": "Updated body content..."
}'
```

### Send test email to yourself (admin email)
```bash
ll POST /admin/newsletter/$CAMPAIGN_ID/test
```

### Schedule campaign send
```bash
ll POST /admin/newsletter/$CAMPAIGN_ID/schedule -d '{
  "scheduledAt": "2026-05-10T09:00:00Z"
}'
# scheduledAt must be in the future
```

### Send immediately
```bash
ll POST /admin/newsletter/$CAMPAIGN_ID/publish
```

### Delete a draft campaign
```bash
ll DELETE /admin/newsletter/$CAMPAIGN_ID
# Only works on drafts — sent campaigns cannot be deleted
```

---

## Public campaign archive

```bash
# List published campaigns (visible to anyone)
ll_pub GET /newsletter

# Read a specific campaign
ll_pub GET /newsletter/may-2026-update | python3 -m json.tool
```

---

## Subscribers

### List subscribers (admin, paginated)
```bash
ll GET /admin/newsletter/subscribers
ll GET "/admin/newsletter/subscribers?page=2&limit=50"
```

### Bulk import subscribers
```bash
ll POST /admin/newsletter/subscribers/import -d '{
  "subscribers": [
    { "email": "alice@example.com", "firstName": "Alice" },
    { "email": "bob@example.com", "firstName": "Bob" },
    { "email": "carol@example.com" }
  ]
}'
```

### Import from CSV file
```bash
python3 -c "
import csv, json, sys

with open('leads.csv') as f:
    rows = list(csv.DictReader(f))

payload = {
  'subscribers': [
    {'email': r['email'], 'firstName': r.get('name', r.get('firstName',''))}
    for r in rows if r.get('email')
  ]
}
print(json.dumps(payload))
" | xargs -d '\n' -I{} bash -c 'll POST /admin/newsletter/subscribers/import -d "{}"'

# Simpler one-liner approach:
CSV_FILE="leads.csv"
python3 << EOF
import csv, json, subprocess, os

with open("$CSV_FILE") as f:
    rows = list(csv.DictReader(f))

subs = [{"email": r["email"], "firstName": r.get("name", r.get("firstName",""))} for r in rows if r.get("email")]
payload = json.dumps({"subscribers": subs})
print(f"Importing {len(subs)} subscribers...")

result = subprocess.run(
    ["curl", "-s", "-X", "POST",
     f"{os.environ['LL_URL']}/admin/newsletter/subscribers/import",
     "-H", f"Authorization: Bearer {os.environ['LEARNLOOP_API_KEY']}",
     "-H", f"x-community-slug: {os.environ['LL_SLUG']}",
     "-H", "Content-Type: application/json",
     "-d", payload],
    capture_output=True, text=True
)
print(result.stdout)
EOF
```

### Remove a subscriber
```bash
SUBSCRIBER_ID="..."
ll DELETE /admin/newsletter/subscribers/$SUBSCRIBER_ID
```

---

## Public subscribe (no auth — for anonymous forms)

```bash
ll_pub POST /newsletter/subscribe -d '{
  "email": "visitor@example.com",
  "firstName": "Visitor"
}'
```

---

## Unsubscribe (token-based, no auth)

```bash
# Each subscriber has a unique unsubscribeToken in the DB
# The unsubscribe link in campaign emails points to:
# GET /api/v1/newsletter/unsubscribe/{token}
# Returns an HTML confirmation page
curl -s "$LL_URL/newsletter/unsubscribe/$TOKEN"
```

---

## Gotchas

- `scheduledAt` must be at least 1 minute in the future — backend validation rejects past times.
- Bulk import deduplicates by email — existing subscribers are silently skipped (no error).
- Gate unlocks (`POST /library/:slug/unlock`) automatically upsert to the subscriber list with `source: "subscribe_form"`. These subscribers appear in the same list.
- Campaign `body` is stored as Markdown but rendered to HTML for email sending.
- `{firstName}` is the only merge tag currently supported. Missing firstName → falls back to empty string (not "there" or similar).
- Sent campaigns cannot be edited or deleted — create a new campaign if you need to resend.
