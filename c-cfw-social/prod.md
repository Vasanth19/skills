# CFW Social — Production API Quickstart

How to call the cfw-social HTTP API against the **production** app. Same auth patterns as `local-dev.md` — different base URL and key source.

> Companion to `auth.md` (theory) and `routes.json` (inventory). See `local-dev.md` for localhost flows.

---

## Base URL

```
https://app.cfw.social
```

All `/api/**` paths in `routes.json` are relative to this.

---

## Saved brand API keys

### Mr Growth Guide (MGG) — production

```bash
# Brand ID (cuid2, verified 2026-05-20)
MGG_BRAND_ID="cmpda8nmp000004jssp8vno38"

# Brand-scoped API key
BRAND_KEY="$(grep ^CFW_SOCIAL_API_KEY= ~/.gsai/secrets/mgg-api-keys.env | cut -d= -f2-)"

# Example call
curl -s https://app.cfw.social/api/v1/brand/dna -H "x-api-key: $BRAND_KEY"
```

Key auto-resolves the brand — no need to pass `x-cfw-brand` separately when using a brand-scoped key.

**Workspaces:**
- `cmpedqfar000004ld0d5hjwvf` — "Good Times"
- `cmpdguuv2000004lbhgo60iws` — "AI Automation Sample" (default)

---

## Getting the production master key

The production `CFW_MASTER_API_KEY` lives in Vercel — not in any local `.env` file. Pull it:

```bash
cd /Users/vasanth/Code/cfw/cfw-social
vercel env pull .env.production.local --environment=production
MASTER="$(grep ^CFW_MASTER_API_KEY= .env.production.local | cut -d= -f2-)"
```

> **Security:** `.env.production.local` is gitignored. Never commit it. Delete it after use if you don't need it cached locally.

---

## Auth modes in production

Same header recipes as local-dev.md — just swap the base URL and use the Vercel-sourced key.

### 1. `public` — no headers required

```bash
curl -s https://app.cfw.social/api/health
# {"status":"ok","timestamp":"...","database":{"status":"connected"}}
```

### 2. `api-or-session` via master key

```bash
MASTER="$(grep ^CFW_MASTER_API_KEY= .env.production.local | cut -d= -f2-)"
BRAND_ID="<prod-brand-id>"

curl -s https://app.cfw.social/api/v1/brand/dna \
  -H "cfw-api-key: $MASTER" \
  -H "x-cfw-brand: $BRAND_ID"
```

### 3. `api-or-session` via brand-scoped API key

Mint a brand key (use master key to auth this call):

```bash
curl -s -X POST https://app.cfw.social/api/v1/api-keys \
  -H "cfw-api-key: $MASTER" \
  -H "x-cfw-brand: $BRAND_ID" \
  -H "Content-Type: application/json" \
  -d '{"name":"operator-prod"}'
# { "key": { "plain": "cfw_xxxxxxxx..." } }   ← save this; shown once
```

Then use it as `x-api-key` on all subsequent calls — no master key required.

---

## Getting production brand IDs

**`/api/v1/dev/brands` is NOT a safe source in production** — it is a public endpoint with no `NODE_ENV` guard (see security note below). Do NOT rely on it for prod enumeration.

Correct ways to look up a production brand ID:

**Option A — pull Neon connection string and query directly:**

```bash
NEON_URL="$(grep ^DATABASE_URL= .env.production.local | cut -d= -f2-)"
psql "$NEON_URL" -c "select id, slug, name from brands where deleted_at is null;"
```

**Option B — use the master key against a session-promoted route** (if one exists for brand listing — check `routes.json` for any `GET /api/v1/brands` or similar with `api-or-session` auth).

---

## Known production brand IDs

| Brand | ID | Slug |
|---|---|---|
| Mr. Growth Guide | *(pull from Neon or brand.yaml)* | mr-growth-guide |

> Update this table as brands are provisioned. Do not hardcode IDs — they are cuid2 values generated at brand creation time.

---

## ⚠️ Security: `/api/v1/dev/*` is public in production

The dev routes (`/api/v1/dev/brands`, `/api/v1/dev/upload`, etc.) have **no `NODE_ENV` check** — they are live and unauthenticated on `app.cfw.social`. Until a guard is added, anyone who knows the path can enumerate brands or trigger dev utilities.

**Recommended fix** (one-liner at the top of each dev route handler):

```ts
if (process.env.NODE_ENV !== "development") {
  return NextResponse.json({ error: "Not found" }, { status: 404 });
}
```

Files to patch:
- `src/app/api/v1/dev/brands/route.ts`
- `src/app/api/v1/dev/media/[...path]/route.ts`
- `src/app/api/v1/dev/telegram-bot/route.ts`
- `src/app/api/v1/dev/telegram-rewire/route.ts`
- `src/app/api/v1/dev/upload/route.ts`
- `src/app/api/v1/dev/upload-fail/route.ts`

---

## Useful one-liners (production)

```bash
# Pull prod env to .env.production.local
vercel env pull .env.production.local --environment=production

# Health check
curl -s https://app.cfw.social/api/health | jq .

# List brands via Neon (requires DATABASE_URL from pulled env)
NEON_URL="$(grep ^DATABASE_URL= .env.production.local | cut -d= -f2-)"
psql "$NEON_URL" -c "select id, slug, name from brands where deleted_at is null;"

# Show active api_keys for a brand
psql "$NEON_URL" -c "select prefix, name, last_used_at from api_keys where is_active = true and brand_id = '<brandId>';"

# Get brand DNA
curl -s https://app.cfw.social/api/v1/brand/dna \
  -H "cfw-api-key: $MASTER" -H "x-cfw-brand: $BRAND_ID" | jq .
```

---

## See also

- `local-dev.md` — localhost dev workflow
- `auth.md` — full theory of every auth mode
- `routes.json` — canonical route inventory
- `admin-runbook.md` — stuck run recovery, key rotation
