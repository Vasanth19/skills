# CFW Social — Approval Workflow

Human-in-the-loop approval for AI-generated content. A signed-token auth system that lets non-logged-in users (e.g., Telegram contacts, email recipients) approve or reject compositions without needing a cfw-social account.

---

## Overview

```
Agent generates composition
    │
    ▼
Agent calls `request_approval` MCP tool
    │
    ▼
cfw-social creates ApprovalToken (signed JWT)
    │
    ▼
Approval URL delivered to human (Telegram / Email / Web)
    │
    ▼
Human visits approval page → reviews content → approves / rejects / chats
    │
    ├──▶ Approve → Post rows created → scheduled for publishing
    ├──▶ Reject → Composition.status = "rejected"
    └──▶ Chat → messages logged, no status change
```

---

## Step 1: Request Approval

### MCP tool: `request_approval`

**Input:**
```json
{
  "workspaceId": "ws_abc123",
  "compositionId": "comp_def456"  // optional
}
```

**Output:**
```json
{
  "approvalUrl": "https://app.cfw.social/approval/eyJhbGci...",
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresAt": "2026-05-24T12:00:00Z",
  "compositionId": "comp_def456"
}
```

### What cfw-social does

1. Validates `workspaceId` belongs to the authenticated brand
2. Optionally validates `compositionId` belongs to the workspace
3. Generates a signed JWT with claims:
   - `brandId`
   - `workspaceId`
   - `compositionId` (optional)
   - `exp` (7 days)
4. Creates `ApprovalToken` row:
   - `token` = JWT string
   - `expiresAt` = JWT exp
   - `workspaceId`, `compositionId`, `brandId`
   - `approvedAt`, `revokedAt` = null
   - `accessCount` = 0
   - `ipAddresses` = []
5. Returns `approvalUrl` + metadata

### Composition status change

If `compositionId` provided:
- `Composition.status` → `awaiting_approval`
- `Composition.approvedAt` remains null

---

## Step 2: Deliver Approval URL

The `approvalUrl` is delivered through the same channel the conversation started on:

| Channel | Delivery method |
|---|---|
| `telegram` | Bot sends message with inline keyboard (Approve / Reject / Chat) |
| `web` | Inbox notification or email |
| `slack` | Bot posts to channel with interactive blocks |
| `discord` | Bot DM or channel message with buttons |

---

## Step 3: Human Review

### Approval page

URL: `/approval/{token}/chat`

Auth: `signed-token` — the token in the URL path is validated against the `ApprovalToken` row.

**What the page renders:**
- Composition `body` (the caption / text)
- `mediaUrls` or `Output.cdnUrl` previews
- Platform badges (Instagram, LinkedIn, etc.)
- Approve / Reject / Chat buttons
- Chat history (if any)

### Chat during approval

`GET /api/v1/approval/{token}/chat` — returns conversation messages  
`POST /api/v1/approval/{token}/chat` — sends a message

Messages are stored as `ConversationMessage` rows linked to the `BrandConversation`. The agent can respond, potentially regenerating the composition (`regenerate_composition` MCP tool with feedback).

---

## Step 4: Human Action

### Approve

**Endpoint:** `POST /api/v1/inbox/approve`  
**Auth:** `signed-token` (from approval URL)

**What happens:**
1. Token validated:
   - Must exist in `ApprovalToken` table
   - Must not be expired (`expiresAt > now()`)
   - Must not be revoked (`revokedAt` is null)
   - Must not already be approved (`approvedAt` is null)
2. `ApprovalToken.approvedAt` = now()
3. If `compositionId` set:
   - `Composition.status` → `approved`
   - `Composition.approvedAt` = now()
4. Post rows created:
   - One `Post` per target platform
   - `Post.status` = `scheduled`
   - `Post.scheduledAt` = next available slot from `PostTiming`
   - `Post.compositionId` = composition id
   - `Post.workspaceId` = workspace id
   - `Post.brandId` = brand id
5. Audit log written

### Reject

**Endpoint:** `POST /api/v1/inbox/reject`  
**Auth:** `signed-token`

**What happens:**
1. Token validated (same rules as approve)
2. `Composition.status` → `rejected` (if `compositionId` set)
3. Audit log written

### Revoke

**Endpoint:** `POST /api/v1/inbox/revoke`  
**Auth:** `session` (only brand members can revoke)

**What happens:**
1. User session validated
2. User must have access to the brand
3. `ApprovalToken.revokedAt` = now()
4. `ApprovalToken.revocationReason` = provided reason (optional)
5. Any pending posts from this token are cancelled

---

## Token Security Model

### Signed JWT

- Algorithm: HS256 (or RS256 in production)
- Secret: `CFW_APPROVAL_SECRET` env var (never exposed to clients)
- Claims:
  ```json
  {
    "brandId": "...",
    "workspaceId": "...",
    "compositionId": "...",
    "iat": 1715961600,
    "exp": 1716566400
  }
  ```

### Validation rules

| Check | Fail if |
|---|---|
| Token exists in DB | JWT valid but row missing (tampered or expired) |
| Not expired | `expiresAt <= now()` |
| Not revoked | `revokedAt` is not null |
| Not already approved | `approvedAt` is not null |
| Brand matches | `brandId` in JWT ≠ resolved brand |

### Audit trail

Every token access is logged:
- `firstAccessedAt` — timestamp of first page load
- `lastAccessedAt` — timestamp of most recent page load
- `accessCount` — number of times the page was loaded
- `ipAddresses` — array of IP addresses (last N)

---

## Approval Token States

```
┌─────────┐   created    ┌─────────┐   approved   ┌─────────┐
│  active │ ──────────▶│ approved │ ──────────▶│ consumed │
│         │              │         │              │ (done)   │
└────┬────┘              └─────────┘              └─────────┘
     │
     ├──▶ expired (after 7 days)
     │
     └──▶ revoked (by brand member)
```

---

## Error Handling

| Error | Cause | HTTP Status |
|---|---|---|
| `token_expired` | `expiresAt` passed | 401 |
| `token_revoked` | `revokedAt` set | 401 |
| `token_already_approved` | `approvedAt` already set | 409 |
| `token_invalid` | JWT signature mismatch | 401 |
| `composition_not_found` | `compositionId` in token doesn't exist | 404 |
| `brand_mismatch` | Token brand ≠ request brand | 403 |

---

## Integration with Scheduler

Approved compositions → `Post` rows with `status = "scheduled"`. The background scheduler:
1. Polls `Post` where `status = 'scheduled' AND scheduledAt <= NOW()`
2. Dispatches to PostForMe (or direct platform API)
3. Updates `Post.status` → `publishing`
4. Receives webhook → `published` or `failed`
