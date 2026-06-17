---
name: r-youtube-data-api
description: >
  Automate YouTube video metadata updates (title, description, tags, category) and custom
  thumbnail uploads via the YouTube Data API v3 — capturing the first-24h SEO ranking window
  that publishing tools like PostForMe drop on publish. Includes one-time OAuth setup and
  troubleshooting for auth / permission failures. Trigger on "update youtube video", "upload
  youtube thumbnail", "fix youtube auth", "youtube metadata", "youtube oauth", "youtube api
  error", "refresh youtube token".
when-to-use: >
  Use when the user wants to update a YouTube video's metadata, upload a custom YouTube
  thumbnail, authenticate with the YouTube Data API v3, refresh a YouTube OAuth token, or
  debug why a YouTube metadata/thumbnail update failed. Not for uploading new videos — this
  edits metadata + thumbnails on existing videos post-publish.
kind: distribution
visibility: catalog
---

# r-youtube-data-api

## Trigger

Use when the user wants to:
- Update YouTube video metadata (title, description, tags, category)
- Upload a custom thumbnail to an existing YouTube video
- Authenticate with YouTube Data API v3
- Fix OAuth or permission issues with YouTube automation
- Check why a YouTube metadata update or thumbnail upload failed

Phrases: "update youtube video", "upload youtube thumbnail", "fix youtube auth", "youtube metadata", "youtube description", "youtube oauth", "youtube api error", "refresh youtube token".

## Purpose

Automate YouTube video metadata updates (description, tags, category) and custom thumbnail uploads via the YouTube Data API v3. Eliminates manual YouTube Studio updates post-publish, capturing the critical first-24h SEO ranking window.

## Problem Solved

Publishing tools (e.g., PostForMe) often drop descriptions, tags, and custom thumbnails when publishing to YouTube. Manual updates in YouTube Studio add 1+ hour delay, missing the first-24h ranking opportunity. This skill provides sub-5-second automation.

## Files

1. **`update-youtube-video.sh`** — Main script for metadata + thumbnail updates
   - Usage: `./update-youtube-video.sh <video_id> --description "..." --tags "..." --category 28 --thumbnail /path.jpg`
   - Handles multi-line descriptions with proper JSON escaping
   - Returns video URL and thumbnail CDN URL on success

2. **`youtube-oauth-localhost.py`** — One-time OAuth authorization script
   - Opens browser for user authorization (YouTube channel access)
   - Saves refresh token to `{CREDS_DIR}/youtube-tokens.json`
   - Run once per brand channel: `python3 youtube-oauth-localhost.py`

3. **`README-SETUP.md`** — Step-by-step one-time setup guide

## How to Use

### One-Time Setup (Per Brand/Channel)

1. **GCP OAuth Setup** (brand folder, not shared):
   - Create Desktop application OAuth credential in Google Cloud Console
   - Download JSON credentials file
   - Place at: `{brand}/.gsai/youtube-oauth-credentials.json`
   - Register redirect URI: `http://localhost:8089/callback` in GCP OAuth settings
   - Add user as test user in OAuth consent screen (for Internal apps)

2. **Get Refresh Token**:
   ```bash
   cd {brand}/.scripts
   export CREDS_DIR={brand}/.gsai
   python3 {skill-path}/youtube-oauth-localhost.py
   ```
   - Opens browser for authorization
   - Saves refresh token to `{CREDS_DIR}/youtube-tokens.json`
   - One-time per channel

### Post-Publish Workflow

After `create-post.sh` returns `post_id` and the video is live on YouTube:

```bash
export CREDS_DIR={brand}/.gsai
{skill-path}/update-youtube-video.sh <video_id> \
  --description "Full description with chapters" \
  --tags "tag1,tag2,tag3" \
  --category 28 \
  --thumbnail /path/to/thumbnail-yt.jpg
```

**All parameters are optional:**
- Only description? `--description "..."`
- Only thumbnail? `--thumbnail /path.jpg`
- Only category? `--category 28`

**Response verification:**
- Metadata update: `"✅ Video metadata updated successfully!"`
- Thumbnail: `"✅ Thumbnail uploaded successfully! URL: https://i.ytimg.com/..."`
- Verify live: `GET https://www.googleapis.com/youtube/v3/videos?part=snippet&id={video_id}`

## Configuration & Credentials

### Credential Locations (Brand-Specific)

All OAuth credentials are stored **in the brand folder** (not shared):

```
{brand-folder}/
├── .gsai/
│   ├── youtube-oauth-credentials.json  (Desktop app OAuth credential from GCP)
│   └── youtube-tokens.json             (refresh token + access token, auto-managed)
└── .scripts/
    └── update-youtube-video.sh         (this script, from skill)
```

**Environment variable:**
- `CREDS_DIR` — directory containing `youtube-oauth-credentials.json` and `youtube-tokens.json` (default: `./.gsai`)

### Scope Requirements

- **Required**: `youtube` (full read/write)
- **Insufficient**: `youtube.upload` (upload-only, cannot read/update)
- Re-auth needed if scope changes: re-run `youtube-oauth-localhost.py`

### Token Lifecycle

- **Refresh token** (`youtube-tokens.json`): long-lived, never expires automatically
- **Access token**: short-lived (1 hour), auto-refreshed by script before each call
- **Manual re-auth**: if refresh token leaks or is revoked, re-run `youtube-oauth-localhost.py`

## Quota Impact

- Metadata update: ~1 unit
- Thumbnail upload: ~1 unit
- Total: ~2 units per video

YouTube quota: 10,000 units/day per channel. Typical CMO publish: 3-4/day = 6-8 units/day. **No quota concerns.**

## Gotchas

| Error | Root Cause | Fix |
|-------|-----------|-----|
| `redirect_uri_mismatch` | Web credentials used instead of Desktop | Use Desktop application type, not Web |
| `The out-of-band (OOB) flow has been blocked` | OOB deprecated by Google | Use localhost server on port 8089 instead |
| `Invalid JSON payload` | Newlines in description not escaped | Use `jq -n --arg` for string escaping |
| `insufficientPermissions` | OAuth scope too narrow | Re-auth with `youtube` (full) scope |
| Thumbnail 404 | Wrong endpoint path | Use `/upload/youtube/v3/thumbnails/set` |
| Thumbnail empty response | Endpoint is correct but body is empty | Empty body = success (HTTP 200) |
| `org_internal` (Error 403) | User not added as test user | Add user to OAuth consent screen test users |
| `authError` with access_token | Refresh token invalid or revoked | Re-run `youtube-oauth-localhost.py` |

## Technical Details

### Metadata Update Endpoint

```
PUT https://www.googleapis.com/youtube/v3/videos?part=snippet
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "kind": "youtube#video",
  "etag": "{current_etag}",
  "id": "{video_id}",
  "snippet": {
    "title": "...",
    "description": "...",
    "tags": ["tag1", "tag2"],
    "categoryId": "28",
    "liveBroadcastContent": "none"
  }
}
```

**Important**: Must include current `etag` from GET response, or update will fail with 409 Conflict.

### Thumbnail Upload Endpoint

```
POST https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId={video_id}
Authorization: Bearer {access_token}
Content-Type: multipart/form-data

image=@{filepath}  (JPEG, 1280×720, max 2MB)
```

**Response**: `youtube#thumbnailSetResponse` with auto-generated resolutions:
- `default`: 120×90
- `medium`: 320×180
- `high`: 480×360
- `standard`: 640×480
- `maxres`: 1280×720 (custom thumbnail)

## Performance

- Access token refresh: ~0.5 sec
- Metadata update: ~1-2 sec
- Thumbnail upload: ~1-2 sec
- **Total**: ~3-5 seconds per video

## Support & Debugging

### Test script locally first

```bash
# Check OAuth works
curl -s -H "Authorization: Bearer $(jq -r .access_token ${CREDS_DIR:-.gsai}/youtube-tokens.json)" \
  https://www.googleapis.com/youtube/v3/channels?part=id&mine=true

# Check specific video exists
curl -s -H "Authorization: Bearer ..." \
  "https://www.googleapis.com/youtube/v3/videos?part=snippet&id={video_id}"
```

### Enable verbose curl output

Add `set -x` to script top for debugging, or run individual curl commands with `-v` flag.

## Maintenance

This skill is versioned in MemPalace and Paperclip. Updates are:
1. Documented in MemPalace `wing_roles/cmo` (gotchas, new endpoints, scope changes)
2. Tested against YouTube Data API v3 (current, no known sunset date)
3. Monitored for OAuth flow changes (Google deprecates OOB annually)

Current status: **Production-ready**, tested on MGG (2026-05-08), all operations working.
