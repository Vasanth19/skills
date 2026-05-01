---
name: outstand
description: >
  Post, schedule, fetch analytics, and manage comments across 10 social
  platforms (X, LinkedIn, Instagram, Facebook, Threads, TikTok, YouTube,
  Bluesky, Pinterest, Google Business) via the Outstand.so unified REST API.
  Usage-based ($0.50/month/account + $0.01/post). Alternative to postforme
  and upload-post. Requires OUTSTAND_API_KEY.
---

# Outstand.so — Unified Social Media API

## What This Is
Developer-first, usage-based unified REST API to post, schedule, fetch analytics, and manage comments across 10 social platforms: X (Twitter), LinkedIn, Instagram, Facebook, Threads, TikTok, YouTube, Bluesky, Pinterest, Google Business.

Pricing: $0.50/month per connected account + $0.01 per post published. No tiers, no seats.

## API Reference
- **Base URL**: `https://api.outstand.so`
- **API Version**: `/v1`
- **Auth**: `Authorization: Bearer $OUTSTAND_API_KEY` (key passed by caller)
- **Dashboard**: https://www.outstand.so
- **Docs**: https://www.outstand.so/docs/getting-started
- **MCP Server**: `https://mcp.outstand.so/mcp` (25 tools, same API key)

## docs/ Folder Contents

| File | What It Is |
|---|---|
| `endpoints.md` | Endpoint summary extracted from the docs |
| `scripts/` | Bash scripts for common operations |

## Auth

Scripts read `OUTSTAND_API_KEY` in this order:

1. Environment variable (if already exported by the caller).
2. Fallback: `<posting-tools>/.gsai/secret` — a gitignored file containing `export OUTSTAND_API_KEY=...`. Scripts walk up from their own directory to find it, so they work no matter where they're invoked from.

Agents (OpenClaw etc.) can either export the key in their shell or drop it into `.gsai/secret` once and forget.

## Scripts

Run any script with `--dry-run` to print the curl command without executing.

| Script | Usage |
|---|---|
| `list-accounts.sh` | `./list-accounts.sh` — list connected social accounts |
| `get-auth-url.sh` | `./get-auth-url.sh <social_network_id>` — get OAuth URL to connect an account |
| `create-post.sh` | `./create-post.sh <content> <account_ids> [media_id] [scheduled_at]` — publish or schedule |
| `list-posts.sh` | `./list-posts.sh [limit]` — list posts |
| `get-post.sh` | `./get-post.sh <post_id>` — fetch a single post |
| `get-post-analytics.sh` | `./get-post-analytics.sh <post_id>` — fetch post analytics |
| `delete-post.sh` | `./delete-post.sh <post_id>` — delete/cancel a post |
| `upload-media.sh` | `./upload-media.sh <file>` — full upload flow (URL + PUT + confirm) |
| `create-comment.sh` | `./create-comment.sh <post_id> <content>` — publish a first comment on a post |
| `get-usage.sh` | `./get-usage.sh` — current billing usage |
| `test.sh` | `./test.sh` — offline validation of all scripts |

## Core Concepts

- **Social Network**: Your OAuth app config for a platform (e.g., your X or Facebook app). Created once per platform via `POST /v1/social-networks`.
- **Social Account**: A user's connected account (e.g. `@john` on X). Identified by `acc_...` IDs.
- **Post**: Content published via `containers` → one or more `socialAccountIds`. Optional `scheduledAt` (ISO-8601) for scheduling.
- **Container**: Holds `content` text and optional media references for a post.
- **Media**: Presigned-URL upload flow: get URL → PUT file → confirm upload → attach media_id to a post container.
- **First Comment**: Outstand can schedule an auto-posted first comment on networks that support it.
- **Webhooks**: `post.published`, `post.error`, `account.token_expired`. HMAC-SHA256 signature via `X-Outstand-Signature`.

## Minimal Post Flow

```bash
# 1. List accounts to get socialAccountIds
./list-accounts.sh

# 2. (Optional) Upload media
./upload-media.sh ./photo.jpg
# Returns media id

# 3. Create post
./create-post.sh "Hello world!" "acc_123,acc_456"

# 4. Check status
./get-post.sh <post_id>
```

## Publishing Workflow (for Agents)

When an agent is asked to "publish a post":

1. **Resolve target accounts** — call `list-accounts.sh`, filter by `network` and `username`, extract `id`s.
2. **Upload media if needed** — use `upload-media.sh`; note the returned media id.
3. **Create the post** — call `create-post.sh` with content, comma-separated account IDs, optional media id, optional `scheduledAt`.
4. **Verify** — call `get-post.sh` to check per-account status, or subscribe to the `post.published` / `post.error` webhooks.

## Response Shape

Outstand wraps responses as `{ success: boolean, data: ..., error?: string }`. Error example:
```json
{ "success": false, "error": "Invalid or missing API key" }
```
