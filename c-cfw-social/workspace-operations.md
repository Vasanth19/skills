# CFW Social — Workspace Operations

A `Workspace` is a topic-scoped container within a `Brand`. It holds `Agent`s, `Source`s, `Run`s, `Composition`s, and `Post`s.

---

## Workspace CRUD

### List workspaces

`GET /api/v1/workspaces/list`

Returns workspaces for the current brand, ordered by `updatedAt` desc. Includes only `active` workspaces (not `archived`) unless specified.

### Get workspace

`GET /api/v1/workspaces/{workspaceId}/runs` — returns runs  
`GET /api/v1/workspaces/{workspaceId}/outputs` — returns outputs  
`GET /api/v1/workspaces/{workspaceId}/posts` — returns posts  
`GET /api/v1/workspaces/{workspaceId}/sources` — returns sources  
`GET /api/v1/workspaces/{workspaceId}/assets` — returns assets

### Update workspace

`PATCH /api/v1/workspaces/{workspaceId}`

Body: `{ "name": "smoke-rename" }`

Changes `Workspace.title`. The `updatedAt` timestamp is bumped.

### Archive workspace

Not directly exposed in routes.json — likely a PATCH with `status: "archived"` or a DELETE (soft delete via `deletedAt`).

### Semantic workspace matching

`Workspace.intentEmbedding` (pgvector(768)) is used by the `find_workspace_by_intent` MCP tool. When a user sends a message, the agent can search for an existing workspace with a similar intent before creating a new one.

---

## Sources

`Source` rows are polymorphic workspace inputs. They ground agent generation on real content.

### Kinds

| Kind | Meaning | Typical URL |
|---|---|---|
| `file` | Uploaded file | R2 CDN URL |
| `url` | External webpage | `https://...` |
| `transcript` | Text transcript | R2 CDN URL |
| `doc` | Document (PDF, etc.) | R2 CDN URL |
| `image` | Image asset | R2 CDN URL |
| `video` | Video asset | R2 CDN URL |

### Creating sources

`POST /api/v1/workspaces/{workspaceId}/sources`

Body:
```json
{
  "kind": "url",
  "url": "https://example.com",
  "name": "smoke"
}
```

### Deleting sources

`DELETE /api/v1/workspaces/{workspaceId}/sources` — removes source(s) from workspace

---

## Assets

Assets are media files uploaded to R2 and linked to workspaces.

### Upload flow

1. Client requests presigned URL: `GET /api/v1/captures/presign-upload`
2. Client uploads file directly to R2
3. cfw-social creates `Media` row (not shown in schema extract — likely a system table)
4. Asset linked to workspace via `POST /api/v1/workspaces/{workspaceId}/assets`

### R2 key rules

All R2 keys MUST start with `${brandId}/`. Pattern:
```
${brandId}/${workspaceId|inbox}/${mediaId}.${ext}
```

---

## Runs within Workspace

`GET /api/v1/workspaces/{workspaceId}/runs` returns all `Run`s for the workspace.

### Run structure per workspace

```
Workspace
  └── Run[]
        ├── RunEvent[] (SSE log, monotonic seq)
        ├── Output[] (deliverables)
        └── Post[] (if run created posts directly)
```

### Run events

`GET /api/v1/runs/{runId}/events` — returns `RunEvent` rows for a run. Accepts `?since=<seq>` for replay.

---

## Outputs within Workspace

`GET /api/v1/workspaces/{workspaceId}/outputs` returns all `Output`s produced by runs in the workspace.

### Output structure

```
Output
  id        String
  runId     String
  kind      String   // image | video | audio | doc
  cdnUrl    String   // R2 public URL
  mimeType  String
  metadata  Json?    // skill-specific
  createdAt DateTime
```

---

## Compositions within Workspace

`GET /api/v1/workspaces/{workspaceId}` includes `compositions` in the response:

```json
{
  "workspaceId": "...",
  "title": "...",
  "status": "...",
  "body": "...",
  "mediaIds": [],
  "compositions": [
    {
      "compositionId": "...",
      "type": "reel",
      "platform": "instagram",
      "status": "awaiting_approval",
      "currentRevisionId": "..."
    }
  ]
}
```

### Composition types

| Type | Platforms |
|---|---|
| `post` | All |
| `reel` | Instagram, TikTok, YouTube Shorts |
| `video` | YouTube, LinkedIn, Facebook |
| `carousel` | Instagram, LinkedIn, Facebook |
| `article` | LinkedIn, Facebook |

---

## Posts within Workspace

`GET /api/v1/workspaces/{workspaceId}/posts` returns `Post` rows scoped to the workspace.

### Post views by status

| View | Query |
|---|---|
| Calendar | All posts with `scheduledAt` or `publishedAt` |
| Scheduled | `status = 'scheduled'` |
| Posted | `status = 'published'` |
| Drafts | `status = 'draft'` |
| Failed | `status = 'failed'` |

### Platform-specific constraints

| Platform | Max media | Caption length | Special rules |
|---|---|---|---|
| Instagram | 10 images / 1 video | 2,200 chars | Reels 15s–90s |
| LinkedIn | 1 image / 1 video | 3,000 chars | Article posts support longer text |
| X | 4 images / 1 video | 280 chars (4,800 premium) | Thread support via `r-x-thread` |
| TikTok | 1 video | 2,200 chars | 15s–10min |
| YouTube | 1 video | 5,000 chars | Shorts <60s, regular up to 12hrs |
| Facebook | 10 images / 1 video | 63,206 chars | |
| Pinterest | 1 image | 500 chars | 2:3 aspect ratio preferred |
| Threads | 10 images / 1 video | 500 chars | |
| Bluesky | 4 images / 1 video | 300 chars | |
| Google Business | 1 image | 1,500 chars | |

---

## Workspace Cleanup

### Deleting a workspace

Not directly exposed in routes.json. Likely:
- Soft delete: `deletedAt` timestamp set
- Hard delete: cascades to `Agent`, `Source`, `Run`, `Composition`, `Post`

### Archiving

`status = "archived"` — workspace hidden from default listings but data preserved.
