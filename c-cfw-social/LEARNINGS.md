# CFW Social — Operational Learnings

Hard-won gotchas from real operations. Read alongside `new-brand-onboarding.md` and `publishing.md`.

---

## 2026-06-03 — Brand-level PFM override is ignored on quick/approve unless `brandId` is threaded

**Symptom:** A brand with its own PFM project (`brands.pfm_project_api_key` set) fails every publish through
`POST /api/v1/posts/quick` and `POST /api/v1/inbox/approve` with PFM error **"invalid social accounts, not
owned by user"** — even though the brand's social account is connected and the override key is correct.

**Cause:** both routes called `pfmFetch("/v1/social-posts", {...})` **without `brandId`**, so
`getPfmConfig(undefined)` returned the *global* `POSTFORME_API_KEY` env key. The global project doesn't own
the brand's social account → PFM rejects it. `posts/[id]/publish` already passed `brandId` correctly; it was
the reference.

**Fix:** commit `e31c0b8` — add `brandId` to the `pfmFetch` init in both routes. **Rule:** every
`pfmFetch('/v1/social-posts', …)` that publishes for a brand MUST pass `brandId`, or brand PFM overrides silently
fall back to the global key. Validate after a deploy: a brand-override publish should land with `media:1, accounts:1`.

## 2026-06-03 — `posts/quick` stacks N posts on the SAME day unless `maxPostsPerDay` is lowered

**Symptom:** Calling `posts/quick` three times in a row (one post each) put **all three on the same day/slot**
instead of spreading across days.

**Cause:** `getNextSlotForBrand` respects `PostTiming.maxPostsPerDay` (**default 3**). With a single daily
timeslot, three posts all fit under the cap on day 1. The 4th would roll to day 2.

**Fix for a 1-post/day brand:** set `UPDATE post_timings SET max_posts_per_day = 1 WHERE brand_id=… AND
platform=…`. Then sequential `posts/quick` calls each roll to the next open day. (Note: each `posts/quick` call
only de-dupes within its own request via `claimedSlots`; cross-call spacing relies on prior posts already being
`status='scheduled'` in the DB, so a *failed* publish frees its slot and the next call reuses that day.)

## 2026-06-03 — `/api/v1/brand/setup` did NOT create `UserBrandAccess` (brand invisible to its owner)

**Symptom:** A brand created via `POST /api/v1/brand/setup` does not appear in the owner's brand switcher /
`/api/v1/brands/mine`, even though `brands.owner_id` is correct.

**Cause:** The UI brand list is driven by `UserBrandAccess`, NOT `brands.owner_id`. `brand/setup` set `ownerId`
but never created the `UserBrandAccess` owner row (the sign-up path via `initUserWorkspace` does — see
`brand-management.md` §"Auto-created on sign-up" step 4). So API-created brands were invisible.

**Fix:** commit `ec632ac` — `brand/setup` now creates the `UserBrandAccess` owner row. **Backfill for brands
created before the fix:** `INSERT INTO user_brand_access (id,user_id,brand_id,role,created_at) VALUES
('c'||…, owner_id, brand_id, 'owner', now()) ON CONFLICT (user_id,brand_id) DO NOTHING`. (Doc note:
`new-brand-onboarding.md` Path A's "creates EVERYTHING" predates this — it omitted UserBrandAccess.)

## 2026-06-03 — Brand-level PFM webhook secret is DEAD CONFIG (verify path is global-only)

When a brand uses its own PFM project (`pfm_project_api_key`), that project starts with **zero webhook endpoints**
(`GET https://api.postforme.dev/v1/webhooks` → `{data:[], total:0}`). So real-time publish confirmations don't
flow for that brand — status updates fall back to the reconcile cron (`postforme/reconcile.ts` + `sync-analytics`).

**The trap:** you cannot fix this by setting `brands.pfm_project_webhook_secret`. The incoming-webhook verifier
`PostForMeProvider.verifyWebhook()` calls **`getPfmConfigSync()`** (env-only — `getPfmConfigSync` just returns
`getBasePfmConfig()`, NO brand override) and compares the `post-for-me-webhook-secret` header against the **global**
`POSTFORME_WEBHOOK_SECRET`. The async `getPfmConfig(brandId)` DOES read `pfm_project_webhook_secret`, but it's only
used for *outbound* `pfmFetch`, never for verifying *incoming* webhooks (at verify time the body isn't parsed yet,
so the brand is unknown).

**Consequence:** registering a webhook in a brand's separate PFM project returns a **PFM-generated** secret that
won't match the global `POSTFORME_WEBHOOK_SECRET` → cfw-social rejects every delivery → PFM retries 8× over 24h
(log noise, no benefit). Verified 2026-06-03 (created + immediately deleted a test webhook to confirm).

**To actually get real-time webhooks per brand:** make `verifyWebhook` brand-aware — parse the body first
(`pfmPostId` → `Post` → `brandId` → `getPfmConfig(brandId)`), then timing-safe-compare against the brand secret
(falling back to global). Until that ships, leave brand PFM projects webhook-less and rely on the reconcile cron.

## Rescheduling a scheduled post = PFM delete + recreate (no native reschedule)

PFM does **not** support `PATCH /v1/social-posts/{id}` (404) — posts are immutable. To move a scheduled post to a
new date: `DELETE /v1/social-posts/{oldId}`, then `POST /v1/social-posts` with the same
`social_accounts` + `caption` + `media:[{url}]` + `external_id` (the CFW post id) + new `scheduled_at`, then
`UPDATE posts SET pfm_post_id=<new>, scheduled_at=<new>`. Swapping two posts' dates = do this for both.
