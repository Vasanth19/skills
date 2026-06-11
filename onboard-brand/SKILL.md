---
name: onboard-brand
description: >
  Stand up a brand-new CFW Social brand end-to-end with nothing but the prod
  master key. One call to /api/v1/brand/setup creates the Brand + DNA + default
  Workspace + the full agent crew (Director "Aria" + specialists) + a default
  brand API key, and uploads the logo + character sheet to R2. Then it places
  the brand on the Hermes box (hermesBoxId) and connects a Telegram bot so the
  brand's Director starts polling. After it runs, you DM the new brand's bot to
  test content end-to-end. Pure HTTP + master key — drop it into any Hermes.
when_to_use: >
  Trigger on: onboard a brand, create a new brand, set up a new client,
  stand up a brand, new CFW brand, provision a brand, onboard <name>,
  create brand and connect telegram, admin onboarding, birth a brand.
allowed-tools: Bash, Read, Write
---

# onboard-brand

The **admin / operator** recipe. Turns *(name, owner email, brief, logo, character, bot token)* into a **live brand on production CFW Social with a polling Telegram bot** — using only the **master key**.

> ⚠️ **This is master-key power. It is NOT a brand Director skill.** Never install this on a customer-facing brand profile. It belongs on a dedicated operator profile (e.g. local SafeClaw `operator-home`) that holds `CFW_MASTER_API_KEY`. The master key can create/read/place *any* brand — treat it like root.

---

## What it does (the 4 phases)

| Phase | Endpoint / action | Auth | Result |
|---|---|---|---|
| 1. **Create** | `POST /api/v1/brand/setup` (multipart) | master key (`cfw-api-key`) | Brand + BrandDna + Workspace + agent crew + default brand key; logo + characterSheet → R2 |
| 2. **Place** | set `Brand.hermesBoxId = <box>` | prod DB (`CFW_PROD_DATABASE_URL`) | brand assigned to the Hermes box so the daemon will service it |
| 3. **Connect** | `POST /api/v1/channels/telegram/connect` | brand key (`x-api-key`) | deletes webhook, mints hermes bot key, enqueues a `telegram_bind` pack_task |
| 4. **Bind (automatic)** | hst daemon drains `/pack/pending?box=<box>` | — | writes the token into the profile `.env` and starts `hermes gateway run` |

Phases 1–3 are this skill. Phase 4 happens on its own because the **provisioner daemon on hst is already running** and polling `/pack/pending`.

---

## Run it

Everything is in `onboard-brand.sh`. Set the master key, write a brief, call the script.

```bash
export CFW_MASTER_API_KEY="…"                 # required — the prod master key (cfw-social/.env.prod)
export CFW_PROD_DATABASE_URL="postgres://…"   # required for placement (phase 2); same value as cfw-social/.env.prod DATABASE_URL

# brief.json — the brand voice/DNA (all fields optional except as your brand needs)
cat > /tmp/brief.json <<'JSON'
{
  "vertical": "restaurant",
  "voice": "warm, neighbourly, a little cheeky",
  "tone": "friendly",
  "audience": "Bangalore home cooks who want restaurant-quality at home",
  "keywords": ["home cooking", "south indian", "weeknight"],
  "avoidWords": ["cheap", "diet"],
  "guidelines": "Always end with a question. Never claim health benefits.",
  "visualStyle": "warm natural light, top-down food shots",
  "workspaceTitle": "Acme Kitchen Content"
}
JSON

./onboard-brand.sh \
  --name "Acme Kitchen" \
  --slug acme-kitchen \
  --owner-email vasanth@hyphenlabs.com \
  --brief /tmp/brief.json \
  --logo /path/to/logo.png \
  --character /path/to/character.png \
  --bot-token 8123456789:AA… \
  --allowed-users 6266996141 \
  --box hst
```

On success it prints the new `brandId`, `slug`, `workspaceId`, `agentId`, the **default brand key**, and the Telegram `bindingState`. Within ~30–60s the daemon binds the bot — then DM it to test.

### Flags
- `--name` (req) · `--slug` (req, lowercase-kebab) · `--owner-email` (req, **must be an existing user**)
- `--brief <file.json>` (req) · `--logo <file>` · `--character <file>` (optional images)
- `--bot-token <tok>` · `--allowed-users <csv of telegram numeric ids>` — omit to create the brand without Telegram
- `--box <id>` (default `hst`) · `--base-url <url>` (default `https://app.cfw.social`)
- `--telegram-only --brand-key <cfw_…> --brand-id <id>` — resume just phase 2+3 for an already-created brand
- `--skip-telegram` — phase 1 only · `--dry-run` — print what it would do

---

## Hard rules & gotchas (read before first run)

1. **Two different auth headers.** Master key → `cfw-api-key`. Brand key → `x-api-key`. They are NOT interchangeable; sending the master key as `x-api-key` 401s with a misleading "Invalid or inactive API key". The script wires each phase to the right header.
2. **`ownerEmail` must already be a registered user.** `brand/setup` returns **404 "No user found"** otherwise — it does not create users. Register the owner first (better-auth signup) and re-run.
3. **`slug` must be free.** Taken slug → **409**. Pick another.
4. **Placement is the one non-HTTP step.** There is currently **no REST/MCP endpoint to set `Brand.hermesBoxId`**. Without it, `telegram/connect` falls into the **retired Fly webhook path** instead of the Hermes daemon path — the bot will never bind. The script sets it via `CFW_PROD_DATABASE_URL`. If that env var is missing, the script **stops after phase 1** (fail-fast, no silent fallback), prints the exact SQL, and gives you the `--telegram-only` resume command. The SQL is:
   ```sql
   UPDATE "Brand" SET "hermesBoxId" = 'hst' WHERE id = '<brandId>';
   ```
5. **Use prod, never the dev tunnel.** `--base-url` must be `https://app.cfw.social`. The `v2.cfw.social` tunnel points at *local dev* cfw-social and will create the brand in the wrong DB.
6. **The daemon must be alive on the box** for phase 4. Verify: `curl -H "cfw-api-key: $CFW_MASTER_API_KEY" "https://app.cfw.social/api/v1/pack/pending?box=hst"` → `200`. If the daemon is down, the brand + task exist but the bot never starts.
7. **Never log the keys.** The script keeps the master key, brand key, and bot token out of stdout except the final brand-key line you need. Don't paste that line into shared logs.
8. **Plan/tier.** `brand/setup` creates the brand on tier `creator`, `hermesEndpoint: shared`. Adjust later via admin if the customer is `$149` dedicated.

---

## Verify end-to-end (after the script)

1. **Brand reads from prod:** with the printed brand key,
   `curl -s -X POST https://app.cfw.social/api/v1/mcp -H "x-api-key: <brandKey>" -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_brand","arguments":{}}}'` → should return the new brand record.
2. **Bot bound:** within a minute the daemon should flip `bindingState` to `bound`. DM the bot — it should reply.
3. **Cook a dish:** DM "make me a LinkedIn post about X" → it should land as a Dish in the prod Inbox at `app.cfw.social`.

---

## Self-improvement
Before running, read `LEARNINGS.md` in this folder if present and apply anything under **Active Feedback**. After a run, append 1–3 bullets of what broke or what to do differently next time.
