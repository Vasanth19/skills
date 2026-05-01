---
name: upload-post
description: >
  Schedule and publish social posts across 10+ platforms (TikTok, Instagram,
  YouTube, LinkedIn, Facebook, X, Threads, Pinterest, Bluesky, Reddit,
  Google Business) via the Upload-Post multi-brand API. Alternative to
  postforme with multi-brand/profile support. Requires UPLOAD_POST_API_KEY.
---

# Upload Post — Social Media Scheduling API

## What This Is
Multi-brand, multi-platform social media scheduling and publishing service. Supports 10+ networks: TikTok, Instagram, YouTube, LinkedIn, Facebook, X, Threads, Pinterest, Bluesky, Reddit, Google Business.

## API Reference
- Base URL: `https://api.upload-post.com/api`
- Auth: `Authorization: Apikey $UPLOAD_POST_API_KEY` (key passed by caller)
- Dashboard: https://upload-post.com
- Docs: https://docs.upload-post.com

## docs/ Folder Contents

| File | What It Is |
|---|---|
| `openapi.json` | OpenAPI 3.0 spec — full endpoint definitions |
| `llm.txt` | Complete API docs in markdown (LLM-optimized) |
| `brands.yaml` | Brand config: user profiles, schedules, voice, content routing |
| `multi-tenant-visual.html` | Architecture diagram (open in browser) |
| `scripts/` | Bash scripts for common operations |

## Scripts

| Script | Usage |
|---|---|
| `upload-video.sh` | `./upload-video.sh <video> <user> <platforms> [title] [scheduled_date]` |
| `upload-photo.sh` | `./upload-photo.sh <image> <user> <platforms> [title]` |
| `check-status.sh` | `./check-status.sh <request_id>` |
| `list-history.sh` | `./list-history.sh <user> [page]` |
| `list-users.sh` | `./list-users.sh` |
| `create-user.sh` | `./create-user.sh <username>` |
| `connect-accounts.sh` | `./connect-accounts.sh <username>` |
| `get-analytics.sh` | `./get-analytics.sh <username> [platforms]` |

## Auth

Scripts read `UPLOAD_POST_API_KEY` in this order:

1. Environment variable (if already exported by the caller).
2. Fallback: `<posting-tools>/.gsai/secret` — a gitignored file containing `export UPLOAD_POST_API_KEY=...`. Scripts walk up from their own directory to find it, so they work no matter where they're invoked from.

Agents (OpenClaw etc.) can either export the key in their shell or drop it into `.gsai/secret` once and forget.

## Core Concepts
- **User Profile**: Each brand maps to a user profile for multi-tenant isolation
- **Social Platform Connection (SPC)**: A connected social account
- **Upload Request**: A scheduled post targeting one or more SPCs
- **Queue System**: Auto-schedule posts to optimal time slots

## Brand = Upload Post User Profile
Each brand maps to an Upload Post "user profile". Multi-tenant isolation is built-in.
When uploading, specify `user="brand-name"` to target the right brand's connected accounts.
