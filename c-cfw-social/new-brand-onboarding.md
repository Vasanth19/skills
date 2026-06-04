# CFW Social — New Brand Onboarding (Production)

How to take a brand from "row exists" to "fully set up" in production, and how to verify it. Based on the Mr. Growth Guide onboarding performed 2026-06-02.

> Companion to `brand-management.md` (concepts) and `prod.md` (auth/base URLs). This file is the operational checklist.

---

## What "fully set up" means

A production brand is fully onboarded when ALL of these are true:

| # | Item | Where it lives | How to check |
|---|---|---|---|
| 1 | Brand row (name, slug, timezone) | `brands` | `SELECT name, slug, timezone FROM brands WHERE id = ...` |
| 2 | **Brand brief** (9-section template) | `brand_dna.guidelines` | Non-null, contains `## Identity` … `## Win Condition` |
| 3 | **Logo** | R2 `brands/{id}/logo.{ext}` + `brands.logo_url` | `logo_url` non-null, URL returns 200 |
| 4 | **Character ref(s)** | R2 `brands/{id}/characters/*` + `character_refs` row | ≥1 row with `starred_image_keys` |
| 5 | Agent crew (director + specialists) | `agents` + `brands.director_agent_id` | Aria (director) + Cody/Remy/Kyle/Quinn/Sage |
| 6 | Agent skill curation | `agent_skills` | Each agent has >0 skills or `allow_discovery = true` |
| 7 | Platform connections | `platform_connections` | All target platforms `is_active`, `connection_health = 'healthy'` |
| 8 | Channel (Telegram bot etc.) | `telegram_bots` (`active` column, NOT `is_active`) | Bot row active |
| 9 | API key(s) | `api_keys` | ≥1 active key; plaintext saved to `~/.gsai/secrets/<brand>-api-keys.env` |
| 10 | Workspace(s) | `workspaces` | ≥1 active workspace |
| 11 | (Optional) Per-brand PFM project key | `brands.pfm_project_api_key` + `pfm_project_webhook_secret` | Falls back to global `POSTFORME_API_KEY` env when null |
| 12 | (Optional) Provider vault keys | `brand_secrets` | HeyGen/ElevenLabs/etc. keys for cfw-agent skill runs |
| 13 | (Optional) CustomerConfig | `customer_configs` | Created automatically only by `/api/v1/brand/setup` path |

---

## The Brand Brief template

The canonical template is `BRAND_BRIEF_PROMPT` in `src/components/brand-dna/BrandDnaForm.tsx`. The brief is stored **verbatim in `brand_dna.guidelines`** (the other DNA columns — voice/tone/audience — can stay null when the brief covers them).

The 9 required sections (in order):

```
# Brand Brief — {brand name}
## Identity          (who, why, mission/vision — 2-4 sentences)
## Audience          (who, the pain, the outcome — 2-3 sentences)
## Voice & Tone      (We are: X. We are NOT: Y. + do-say/don't-say examples)
## Visual Identity   (Primary/Secondary/Accent/Neutral hex + typography + photo style)
## Content Pillars   (3-5 numbered themes with angle)
## Formats           (short-form video / long-form / carousels / threads specs)
## Messaging         (Always use / Never use / Off-limits topics)
## Reference Brands  (Admire: … Distinct from: …)
## Win Condition     (one sentence: what a winning post looks like)
```

Keep under 700 words / 10,000 chars. The character-sheet generation prompt (`CHARACTER_SHEET_PROMPT`, same file) produces the turnaround sheets uploaded as character refs.

---

## Path A — brand doesn't exist yet: `POST /api/v1/brand/setup`

One-shot endpoint (master-key only) that creates EVERYTHING: brand + customer config + DNA + workspace + agent crew + API key + logo + character ref.

```bash
MASTER=$(cd /Users/vasanth/Code/cfw/cfw-agent && fly ssh console -C "printenv CFW_MASTER_API_KEY")
curl -X POST https://app.cfw.social/api/v1/brand/setup \
  -H "cfw-api-key: $MASTER" \
  -F "name=My Brand" \
  -F "slug=my-brand" \
  -F "ownerEmail=owner@example.com" \
  -F 'brief={"guidelines":"# Brand Brief — My Brand\n## Identity\n...","workspaceTitle":"My Brand Content"}' \
  -F "logo=@/path/to/logo.png" \
  -F "characterSheet=@/path/to/character-sheet.png"
# → 201 { brandId, slug, workspaceId, agentId, apiKey }   ← SAVE apiKey (shown once)
```

Notes:
- `ownerEmail` must match an existing `users` row (owner signs up first).
- 409 if slug taken. The brief is a JSON string (multipart field).
- This is the ONLY path that creates `customer_configs` automatically.

## Path B — brand already exists (e.g. created via signup): piecemeal

Used for MGG 2026-06-02. The brand existed (signup + rig-up) but was missing logo, character refs, and a usable local API key.

### B1. Logo → R2 + DB

There is **no API endpoint** to set a logo on an existing brand (the UI's logo upload is local-preview only as of 2026-06-02). Do it directly:

1. Upload to R2 key `brands/{brandId}/logo.{ext}` (creds: Vercel env `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, bucket `cfw-social-media`). Use `@aws-sdk/client-s3` from the cfw-social repo's node_modules — script must live inside the repo for module resolution.
2. `UPDATE brands SET logo_url = 'https://media.cfw.social/brands/{brandId}/logo.{ext}' WHERE id = '{brandId}';`

### B2. Character refs → R2 + DB

1. Upload sheet(s) to `brands/{brandId}/characters/{slug}.png`
2. Insert (raw SQL needs an explicit cuid-style id — Prisma's default is client-side):

```sql
INSERT INTO character_refs (id, brand_id, slug, name, starred_image_keys, created_at, updated_at)
VALUES ('c<24 random alphanumerics>', '{brandId}', 'main', '{Character Name}',
        ARRAY['brands/{brandId}/characters/main.png', ...], now(), now())
ON CONFLICT (brand_id, slug) DO UPDATE SET starred_image_keys = EXCLUDED.starred_image_keys;
```

### B3. Brand brief

If missing: paste the 9-section brief into `brand_dna.guidelines` (UI: `/{brandSlug}/settings/brand-dna`, or `UPDATE brand_dna SET guidelines = ...`).

### B4. Mint a brand API key

```bash
curl -X POST https://app.cfw.social/api/v1/api-keys \
  -H "cfw-api-key: $MASTER" -H "x-cfw-brand: {brandId}" \
  -H "Content-Type: application/json" -d '{"name":"local-sync"}'
# → { key: { plain: "cfw_...", prefix } }  ← save to ~/.gsai/secrets/<brand>-api-keys.env
```

### B5. Push local content as draft posts

Pattern (see MGG `scripts/sync-to-cfw-social.mjs` for a working implementation):

1. `POST /api/v2/workspaces {"name": "..."}` → idempotent by title
2. `GET /api/v2/media/presign?filename=...&mime=video/mp4` → `{ uploadUrl, cdnUrl }`
3. `PUT <uploadUrl>` with the file bytes
4. `POST /api/v2/posts {"workspaceId", "platform", "kind": "reel"|"video", "caption", "mediaUrl": cdnUrl, "status": "draft"}` — one per platform

All with `x-api-key: <brand key>`.

---

## Sanity-check SQL (run after onboarding)

```sql
-- swap :bid for the brand id
SELECT name, slug, logo_url IS NOT NULL AS has_logo,
       director_agent_id IS NOT NULL AS has_director FROM brands WHERE id = :bid;
SELECT length(guidelines), guidelines LIKE '%## Win Condition%' FROM brand_dna WHERE brand_id = :bid;
SELECT slug, array_length(starred_image_keys,1) FROM character_refs WHERE brand_id = :bid;
SELECT name, allow_discovery FROM agents WHERE brand_id = :bid;
SELECT platform, connection_health FROM platform_connections WHERE brand_id = :bid;
SELECT bot_username, active FROM telegram_bots WHERE brand_id = :bid;   -- column is "active"
SELECT prefix, name FROM api_keys WHERE brand_id = :bid AND is_active;
SELECT title, status FROM workspaces WHERE brand_id = :bid;
SELECT platform, status, count(*) FROM posts WHERE brand_id = :bid GROUP BY 1,2;
```

---

## Gotchas (learned 2026-06-02, MGG onboarding)

- **Stale brand IDs**: a brand can be renamed/replaced in prod while local configs (`~/.gsai/`, brand repo `.config/`) still point at the old id. ALWAYS verify the brand id by slug/name in the DB before operating: a brand key resolves to whatever brand it was minted for, not "the brand you mean".
- **`vercel env pull` returns empty strings** for several prod vars on this project (`CFW_MASTER_API_KEY`, `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_PUBLIC_BASE_URL`). Working fallbacks: master key from Fly (`fly ssh console -C "printenv CFW_MASTER_API_KEY"`), bucket name from `R2_BUCKET_NAME`, public base = `https://media.cfw.social`.
- **`brands` has NO `openclaw_api_key` column** (despite older docs) — orchestrator auth is via `api_keys` rows named `orchestrator-bridge`.
- **`telegram_bots.active`**, not `is_active`. **`agents` has no `slug`/`is_active`** columns.
- **Raw-SQL inserts need explicit ids** — Prisma cuid defaults are client-side.
- **Platform post-name casing is inconsistent** in `posts.platform` ("Instagram" from the composition/approval path vs "instagram" from `/api/v2/posts`). Treat case-insensitively when querying.
