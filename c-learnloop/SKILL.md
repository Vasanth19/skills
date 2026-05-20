---
name: c-learnloop
description: >
  LearnLoop platform API — create and manage courses, lessons, modules, library
  resources (gated and free), newsletter campaigns, community posts, bots,
  events, members, products, and admin settings. Use for any automation,
  seeding, or integration against a LearnLoop tenant.
when_to_use: >
  Trigger on: LearnLoop API, learnloop, create course, create lesson, gated
  library, library resource, newsletter subscriber, community bot, bot persona,
  community member, tenant admin API, LEARNLOOP_API_KEY, unlock resource,
  library lead, community post, RSVP event, create product, prompt library.
allowed-tools: Bash
---

# LearnLoop API — Master Skill


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

## Setup

```bash
# Copy and fill in values
cp "$(dirname "$0")/../c-learnloop/.env.example" .env
source .env
```

Resolve active URL and key from environment:

```bash
export LEARNLOOP_API_URL="${LEARNLOOP_ENV:-dev}" \
  && [ "$LEARNLOOP_ENV" = "prod" ] \
  && LEARNLOOP_API_URL="$LEARNLOOP_API_URL_PROD" \
  || LEARNLOOP_API_URL="$LEARNLOOP_API_URL_DEV"

export LEARNLOOP_API_KEY="${LEARNLOOP_ENV:-dev}" \
  && [ "$LEARNLOOP_ENV" = "prod" ] \
  && LEARNLOOP_API_KEY="$LEARNLOOP_API_KEY_PROD" \
  || LEARNLOOP_API_KEY="$LEARNLOOP_API_KEY_DEV"

# Shorthand
export LL_URL="$LEARNLOOP_API_URL/api/v1"
export LL_SLUG="$LEARNLOOP_COMMUNITY_SLUG"
```

## Auth

| Header | Value | Required on |
|--------|-------|-------------|
| `Authorization` | `Bearer $LEARNLOOP_API_KEY` | All admin/write endpoints |
| `X-Tenant-Slug` | `$LL_SLUG` | **Every** request |

Public endpoints (list library, unlock gated, subscribe newsletter, storefront) need only the slug header — no auth.

## Base curl helper

Define once per session. All sub-docs use `ll` for authenticated requests and `ll_pub` for public ones.

```bash
ll() {
  local method="$1" path="$2"; shift 2
  curl -s -X "$method" "$LL_URL$path" \
    -H "Authorization: Bearer $LEARNLOOP_API_KEY" \
    -H "X-Tenant-Slug: $LL_SLUG" \
    -H "Content-Type: application/json" \
    "$@"
}

ll_pub() {
  local method="$1" path="$2"; shift 2
  curl -s -X "$method" "$LL_URL$path" \
    -H "X-Tenant-Slug: $LL_SLUG" \
    -H "Content-Type: application/json" \
    "$@"
}
```

## Interactive docs

```
# Dev
http://localhost:3021/api/v1/docs

# Prod
https://api.learnloop.cc/api/v1/docs
```

Authorize with your API key. The **Gated Content** tag covers all library gate endpoints.

---

## Domain Quick Lookup

| I want to… | Read |
|-----------|------|
| Create / update courses, modules, lessons | [docs/courses.md](docs/courses.md) |
| Create library resources (free or gated) | [docs/library.md](docs/library.md) |
| Manage newsletter campaigns + subscribers | [docs/newsletter.md](docs/newsletter.md) |
| Post to the community feed | [docs/posts.md](docs/posts.md) |
| Manage members, roles, invites, bans | [docs/members.md](docs/members.md) |
| Create / configure AI bots | [docs/bots.md](docs/bots.md) |
| Create / RSVP events | [docs/events.md](docs/events.md) |
| Create products, run checkout | [docs/products.md](docs/products.md) |
| Admin settings, categories, API keys | [docs/admin.md](docs/admin.md) |

---

## Global Gotchas

- **`x-community-slug` is required on every request** — missing it returns 404.
- **Static routes must come before `/:id` in Hono** — already handled in the backend; don't reorder.
- **API key auth works on all `requireTenantAdmin` endpoints** — but NOT on user-scoped endpoints that call `getClerkAuth()` directly (those need a Clerk JWT).
- **`content` is `null` on gated library resources** until unlocked — always check before accessing.
- **Unlock is idempotent** — same email + same resource creates no duplicate lead.
- **Newsletter upsert on gate unlock** — re-activates previously unsubscribed emails. Intentional.

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

