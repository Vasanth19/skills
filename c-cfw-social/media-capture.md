# CFW Social — Media Capture & Upload

How media files (images, videos, audio, documents) flow into the CFW Social system.

---

## Overview

```
Client requests upload
    │
    ▼
GET /api/v1/captures/presign-upload
    │
    ├──▶ Returns presigned R2 URL
    │
    ▼
Client uploads file directly to R2
    │
    ▼
R2 confirms upload
    │
    ▼
Client notifies cfw-social
    │
    ▼
cfw-social creates Media row + links to workspace
```

---

## Presigned Upload

### Endpoint

`GET /api/v1/captures/presign-upload`  
**Auth:** `signed-token` (used by capture workflow) or `api-or-session`

### Request

```
GET /api/v1/captures/presign-upload?filename=my-video.mp4&contentType=video/mp4
```

### Response

```json
{
  "presignedUrl": "https://<bucket>.r2.cloudflarestorage.com/<key>?X-Amz-Algorithm=...",
  "publicUrl": "https://cdn.cfwsocial.com/<key>",
  "storageKey": "brand-id/workspace-id/media-id.mp4"
}
```

### R2 key format

All R2 keys MUST start with `${brandId}/`:

```
${brandId}/${workspaceId|inbox}/${mediaId}.${ext}
```

The adapter throws if the key does not have the brand prefix. This enforces tenant isolation at the storage layer.

---

## Capture Events

Captures represent the full lifecycle of a media file from upload through processing.

### Capture states

| State | Meaning |
|---|---|
| `pending` | Upload URL generated, file not yet uploaded |
| `uploaded` | File confirmed in R2 |
| `processing` | Transcoding, thumbnail generation, etc. |
| `ready` | All processing complete, media available |
| `failed` | Upload or processing failed |

### Event endpoints

`GET /api/v1/captures/{captureId}/events` — list events for a capture  
`POST /api/v1/captures/{captureId}/events` — add an event

### Webhook events

External services (e.g., video transcoding) can send events to:

`POST /api/v1/captures/{captureId}/events`  
**Auth:** `public` (validated by capture-specific token)

---

## Capture Linking

After upload, a capture must be linked to a workspace to be usable by the agent.

### Endpoint

`POST /api/v1/captures/{captureId}/link`

Body:
```json
{
  "workspaceId": "ws_abc123"
}
```

### Effect

1. `Capture` row updated with `workspaceId`
2. `Source` row created (kind = "file" or "image" or "video")
3. `Workspace.sources` now includes the capture
4. Agent can reference it in future turns

---

## Capture Status

`GET /api/v1/captures/{captureId}/status`

**Auth:** `signed-token`

Returns:
```json
{
  "captureId": "...",
  "status": "ready",
  "progress": 100,
  "mediaUrl": "https://cdn...",
  "thumbnailUrl": "https://cdn...",
  "metadata": {
    "durationSec": 120,
    "width": 1920,
    "height": 1080,
    "format": "mp4"
  }
}
```

---

## Pending Captures

`GET /api/v1/captures/pending`

**Auth:** `public`

Returns all captures in `pending` state (used by cleanup workers).

---

## Media Library

### Workspace assets

`GET /api/v1/workspaces/{workspaceId}/assets` returns all media linked to a workspace.

### Brand-level media

Not directly exposed in routes.json. Media is primarily workspace-scoped. Brand-level media (e.g., logo, brand guidelines) is stored as `Brand.logoUrl` or in the `BrandDna` metadata.

### Output media

`Output.cdnUrl` is the canonical location for agent-produced media. These are public R2 URLs with the brand prefix.

---

## MCP Tool: attach_output_to_composition

When cfw-agent produces media via a skill, it calls this MCP tool to register the output:

**Input:**
```json
{
  "workspaceId": "ws_abc123",
  "compositionId": "comp_def456",
  "mediaUrls": ["https://cdn.cfwsocial.com/brand-id/.../output.mp4"]
}
```

**Effect:**
1. Validates URLs start with brand prefix
2. Creates `Output` row(s)
3. Updates `Composition.mediaIds`
4. Returns `{ ok: true, outputIds: ["..."] }`

---

## MCP Tool: get_media_urls

Resolves R2 CDN URLs for asset IDs:

**Input:**
```json
{
  "assetIds": ["media_abc", "media_def"]
}
```

**Output:**
```json
{
  "media": [
    {
      "id": "media_abc",
      "r2Url": "https://cdn.cfwsocial.com/brand-id/.../abc.mp4",
      "mimeType": "video/mp4",
      "kind": "video"
    }
  ]
}
```

This is used by the agent loop to resolve media references before passing them to skills.

---

## Cleanup

### Stale pending captures

A background worker should periodically:
1. Query `Capture` where `status = 'pending' AND createdAt < now() - INTERVAL '1 hour'`
2. Mark as `failed` or delete
3. Revoke presigned URLs (they expire naturally after 1 hour)

### Orphaned R2 objects

R2 objects without corresponding `Media` or `Output` rows should be cleaned up by a periodic sweep:
1. List R2 keys by brand prefix
2. Cross-reference with DB
3. Delete objects with no DB row
