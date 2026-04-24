---
name: postforme
description: >
  Publish, schedule, and fetch results for social posts across 9 platforms
  (TikTok, Instagram, Facebook, X, LinkedIn, YouTube, Pinterest, Bluesky,
  Threads) via the PostForMe unified REST API. Use for organic distribution
  of finished creative assets and for pulling per-account publish results
  and analytics. Scripts expect POSTFORME_API_KEY; brand-specific social
  account IDs live in each brand repo at `.config/postforme.yaml`.
---

# Post For Me — Unified Social Media Posting API

## What This Is
Developer-first unified REST API to publish posts, schedule, fetch analytics, and pull feeds across 9 social platforms: TikTok, Instagram, Facebook, X (Twitter), LinkedIn, YouTube, Pinterest, Bluesky, Threads.

Built by Day Moon Development. Open source. Pay-per-post pricing (from $10/mo for 1,000 posts).

## API Reference
- **Base URL**: `https://api.postforme.dev`
- **API Version**: `/v1`
- **Auth**: `Authorization: Bearer $POSTFORME_API_KEY` (key passed by caller)
- **Dashboard**: https://www.postforme.dev
- **Docs**: https://docs.postforme.dev (Scalar) — spec mirrored at `docs/openapi.json`

## docs/ Folder Contents

| File | What It Is |
|---|---|
| `openapi.json` | OpenAPI 3.0 spec — full endpoint definitions |
| `scripts/` | Bash scripts for common operations |

## Auth

Scripts read `POSTFORME_API_KEY` in this order:

1. Environment variable (if already exported by the caller).
2. Fallback: `<posting-tools>/.gsai/secret` — a gitignored file containing `export POSTFORME_API_KEY=...`. Scripts walk up from their own directory to find it, so they work no matter where they're invoked from.

Agents (OpenClaw etc.) can either export the key in their shell or drop it into `.gsai/secret` once and forget.

## Scripts

Run any script with `--dry-run` to print the curl command without executing.

| Script | Usage |
|---|---|
| `list-accounts.sh` | `./list-accounts.sh` — list all connected social accounts |
| `get-auth-url.sh` | `./get-auth-url.sh <platform> [external_id] [redirect_url]` — get OAuth URL to connect an account |
| `create-post.sh` | `./create-post.sh <caption> <social_account_ids> [media_url] [scheduled_at]` — publish or schedule a post |
| `list-posts.sh` | `./list-posts.sh [limit]` — list posts |
| `get-post.sh` | `./get-post.sh <post_id>` — fetch a single post |
| `delete-post.sh` | `./delete-post.sh <post_id>` — delete/cancel a post |
| `get-post-results.sh` | `./get-post-results.sh [post_id]` — fetch per-platform publish results |
| `create-upload-url.sh` | `./create-upload-url.sh` — get a signed URL to upload media |
| `upload-media.sh` | `./upload-media.sh <file>` — full upload flow (get URL + PUT file) |
| `create-webhook.sh` | `./create-webhook.sh <url> <event_types>` — register a webhook |
| `test.sh` | `./test.sh` — validates all scripts shape-check without network calls |

## Core Concepts

- **Social Account**: A connected user platform account. Identified by `spc_...` IDs. Created via OAuth flow (use `get-auth-url.sh`).
- **Social Post**: A piece of content sent to one or many `social_accounts`. Can be instant or scheduled (`scheduled_at`).
- **Social Post Result**: Per-account publish outcome (one post → N results, one per target account).
- **Media**: Upload to a signed URL first, then reference the returned `media_url` when creating the post.
- **Platform Configurations**: Per-platform overrides (e.g. Instagram stories vs feed, Pinterest board id). Pass as `platform_configurations` on the post body.
- **Webhooks**: Subscribe to `social.post.created`, `social.post.updated`, `social.post.result.created`, etc. for async publish status.

## Minimal Post Flow

```bash
# 1. List accounts to get social_account IDs
./list-accounts.sh

# 2. (Optional) Upload media
./upload-media.sh ./image.jpg
# Returns media_url

# 3. Create a post
./create-post.sh "Hello world!" "spc_abc,spc_def" "<media_url>"

# 4. Poll post results
./get-post-results.sh <post_id>
```

## Publishing Workflow (for Agents)

When an agent is asked to "publish a post":

1. **Resolve target accounts** — call `list-accounts.sh`, filter by platform/username, extract `id`s.
2. **Upload media if needed** — use `upload-media.sh` for any local file; use the returned `media_url`.
3. **Create the post** — call `create-post.sh` with caption, comma-separated account IDs, optional media URL, optional `scheduled_at` ISO-8601 timestamp.
4. **Verify** — call `get-post-results.sh` with the returned post id; check each result's status.

## Platform-Specific Rules (MANDATORY)

### YouTube — Always Include a Detailed Description

**NEVER publish a YouTube video with an empty or title-only description.** The YouTube API defaults to using the caption as the description — override this every time.

A YouTube description MUST include:
1. **Hook paragraph** (2-3 sentences) — what the video covers and who it's for
2. **Timestamps** (if video is >2 min) — `00:00 Intro`, `00:20 The problem`, etc.
3. **Primary CTA with URL** — the most important link (repo, product, article, booking page)
4. **Secondary links** — related resources, social profiles
5. **Hashtags** — 3-5 relevant hashtags at the end

**Template:**
```
{2-3 sentence hook describing what the viewer will learn}

TIMESTAMPS:
00:00 — {section}
{mm:ss} — {section}

{PRIMARY CTA LABEL}: {URL}

{Secondary links}
---
{3-5 hashtags}
```

**How to pass description via PostForMe API:**
```bash
# Use platform_configurations to set YouTube-specific description
curl -s -X POST "https://api.postforme.dev/v1/social-posts" \
  -H "Authorization: Bearer $POSTFORME_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "caption": "Short title for the post",
    "social_account_ids": ["spc_..."],
    "media": [{"url": "..."}],
    "platform_configurations": {
      "youtube": {
        "description": "Full multi-paragraph description here...\n\nTimestamps:\n00:00 Intro\n...\n\nRepo: https://..."
      }
    }
  }'
```

**When using create-post.sh**, if the script does not support platform_configurations, call the API directly with the full JSON body above.

This rule applies to every YouTube upload — no exceptions.

## Supported Event Types (Webhooks)
- `social.post.created`
- `social.post.updated`
- `social.post.deleted`
- `social.post.result.created`
- `social.account.created`
- `social.account.updated`
