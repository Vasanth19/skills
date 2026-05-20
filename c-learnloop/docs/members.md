# LearnLoop — Members

Manage community membership: list members, update roles, invite, ban, follow.

See SKILL.md for `ll` helper.

---

## List members

```bash
ll GET /members
ll GET "/members?role=admin&status=active&search=jane&limit=50"
```

Filter params: `role` (`admin`|`member`), `status` (`active`|`banned`), `search` (name/email), `online` (boolean)

## Get a member's profile

```bash
CLERK_ID="user_abc123"
ll GET /members/$CLERK_ID | python3 -m json.tool
```

## Update a member's role (admin)

```bash
ll PATCH /members/$CLERK_ID/role -d '{ "role": "admin" }'
# role options: "admin" | "member"
```

## Ban / unban a member (admin)

```bash
ll POST /members/$CLERK_ID/ban -d '{ "reason": "Repeated spam posts" }'
ll DELETE /members/$CLERK_ID/ban
```

## Follow / unfollow a member

```bash
ll POST /members/$CLERK_ID/follow
ll DELETE /members/$CLERK_ID/follow
ll GET /members/$CLERK_ID/following   # who this member follows
```

---

## Invites

### Send a single invite

```bash
ll POST /members/invite -d '{
  "email": "newmember@example.com",
  "role": "member",
  "message": "You'\''re invited to join the Pragmatic AI Lab!"
}'
```

### Bulk invite

```bash
ll POST /members/bulk-invite -d '{
  "emails": [
    "alice@example.com",
    "bob@example.com",
    "carol@example.com"
  ],
  "role": "member"
}'
```

### Bulk invite from CSV

```bash
CSV_FILE="invites.csv"   # one email per line (no header needed)

EMAILS=$(python3 -c "
import csv, json
with open('$CSV_FILE') as f:
    emails = [row[0].strip() for row in csv.reader(f) if row and row[0].strip()]
print(json.dumps(emails))
")

ll POST /members/bulk-invite -d "{\"emails\": $EMAILS, \"role\": \"member\"}"
```

### List pending invites (admin)

```bash
ll GET /members/invites | python3 -c "
import sys, json
invites = json.load(sys.stdin)['data']
for i in invites:
    print(i['email'], i['status'], i['createdAt'][:10])
"
```

### Revoke an invite

```bash
INVITE_ID="..."
ll DELETE /members/invites/$INVITE_ID
```

---

## Member locations map

```bash
ll GET /members/locations | python3 -m json.tool
```

## Update own location

```bash
ll PATCH /members/$CLERK_ID/location -d '{
  "city": "Austin",
  "country": "US",
  "lat": 30.2672,
  "lng": -97.7431
}'
```

---

## Gotchas

- Bulk invite deduplicates by email — already-invited or already-member emails are skipped silently.
- Banning a member does NOT remove their posts or comments — it just blocks access.
- Only `admin` role members can update other members' roles. Demoting yourself as the only admin is blocked.
- `follow` / `unfollow` are member-scoped — requires Clerk JWT, not API key, unless posting as a bot user.
