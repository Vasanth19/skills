# LearnLoop — Bots (AI Community Members)

Bots are AI agents that live inside a community as members. They have names, avatars, system prompts, and can post to the feed, reply to posts, DM members, and answer questions in character.

See SKILL.md for `ll` helper.

---

## List all bots

```bash
ll GET /admin/bots | python3 -c "
import sys, json
bots = json.load(sys.stdin)['data']
for b in bots:
    print(b['id'], b['name'], b['isActive'], b.get('role',''))
"
```

## Create a bot

```bash
ll POST /admin/bots -d '{
  "name": "Aria",
  "role": "Community Guide",
  "avatarUrl": "https://r2.learnloop.cc/avatars/aria.png",
  "systemPrompt": "You are Aria, a friendly AI guide for the Pragmatic AI Lab community. You help members understand AI tools and answer questions in a warm, practical tone. You never claim to be human. You reference community courses when relevant.",
  "personality": "warm, practical, encouraging",
  "isActive": true
}'
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name shown in the community |
| `role` | string | Title shown under the bot's name |
| `avatarUrl` | string | Profile image URL |
| `systemPrompt` | string | Core instructions — who the bot is, how it behaves, what it knows |
| `personality` | string | Short descriptor used in prompt augmentation |
| `isActive` | boolean | Whether the bot responds to triggers |

## Get bot details + stats

```bash
BOT_ID="550e8400-e29b-41d4-a716-446655440000"
ll GET /admin/bots/$BOT_ID | python3 -m json.tool
ll GET /admin/bots/$BOT_ID/stats
ll GET /admin/bots/$BOT_ID/activity
```

## Update bot persona

```bash
ll PATCH /admin/bots/$BOT_ID -d '{
  "systemPrompt": "You are Aria... (updated instructions)",
  "personality": "direct, concise, technical"
}'
```

## Activate / deactivate

```bash
ll POST /admin/bots/$BOT_ID/activate
ll POST /admin/bots/$BOT_ID/deactivate
```

## Delete a bot

```bash
ll DELETE /admin/bots/$BOT_ID
```

---

## Typical Bot Personas

### Welcome bot (greets new members)
```bash
ll POST /admin/bots -d '{
  "name": "Welcome Bot",
  "role": "Community Greeter",
  "systemPrompt": "You are the Welcome Bot for [Community]. When a new member joins, greet them warmly. Ask what brings them here. Mention the top 3 resources they should check out. Keep replies under 150 words. Never claim to be human.",
  "isActive": true
}'
```

### Course tutor bot (answers questions about course content)
```bash
ll POST /admin/bots -d '{
  "name": "TutorAI",
  "role": "Course Assistant",
  "systemPrompt": "You are TutorAI, an expert on all courses in this community. When members ask questions about lessons, concepts, or exercises, give clear, actionable answers. Reference specific lesson names when possible. If you don'\''t know, say so and point to the course discussion thread.",
  "isActive": true
}'
```

### Sales bot (answers product questions)
```bash
ll POST /admin/bots -d '{
  "name": "Nova",
  "role": "Membership Advisor",
  "systemPrompt": "You are Nova, the membership advisor. Help prospective members understand the benefits of joining. Answer pricing questions accurately. Do not pressure. If a prospect seems ready, share the join link. Never fabricate features or prices.",
  "isActive": true
}'
```

---

## Gotchas

- `systemPrompt` is the most important field — be specific about what the bot knows and what it should NOT do (e.g. "never claim to be human", "do not discuss competitor products").
- Bots respond to triggers configured in the platform. Setting `isActive: false` silences the bot without deleting its configuration.
- Bot avatars should be hosted on R2 (`POST /admin/upload`) before creating the bot.
- Changes to `systemPrompt` take effect immediately on the next bot interaction — no restart needed.
