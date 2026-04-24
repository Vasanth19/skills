# Outstand API — Endpoint Summary

Base URL: `https://api.outstand.so/v1`
Auth: `Authorization: Bearer $OUTSTAND_API_KEY`

## Social Networks (your OAuth app configs)
| Method | Path | Purpose |
|---|---|---|
| POST | `/social-networks` | Register OAuth client_key / client_secret for a platform |
| GET  | `/social-networks/{id}` | Get network details |
| PATCH | `/social-networks/{id}` | Update network |
| DELETE | `/social-networks/{id}` | Disconnect network |
| GET | `/social-networks/{id}/auth-url` | Get user OAuth URL |

## Social Accounts (user-connected accounts)
| Method | Path | Purpose |
|---|---|---|
| GET | `/social-accounts` | List connected accounts |
| POST | `/social-accounts/auth-url` | Start a connection flow |
| GET | `/social-accounts/pending/{id}` | Get pending connection details |
| POST | `/social-accounts/pending/{id}/finalize` | Finalize pending connection |
| DELETE | `/social-accounts/{id}` | Disconnect account |
| GET | `/social-accounts/{id}/metrics` | Account metrics |

## Posts
| Method | Path | Purpose |
|---|---|---|
| POST | `/posts` | Create/schedule a post |
| GET | `/posts` | List posts |
| GET | `/posts/{id}` | Post details |
| GET | `/posts/{id}/analytics` | Post analytics |
| DELETE | `/posts/{id}` | Delete/cancel a post |

### Create Post Body
```json
{
  "containers": [ { "content": "Hello world" } ],
  "socialAccountIds": ["acc_123", "acc_456"],
  "scheduledAt": "2026-12-31T10:00:00Z"
}
```

## Comments/Replies
| Method | Path | Purpose |
|---|---|---|
| POST | `/posts/{id}/comments` | Create first comment / publish a comment |
| GET | `/posts/{id}/comments` | Get replies/comments |

## Media (presigned-URL upload)
| Method | Path | Purpose |
|---|---|---|
| POST | `/media/upload-url` | Get a signed upload URL |
| POST | `/media/{id}/confirm` | Confirm upload |
| GET | `/media/{id}` | Get media file |
| GET | `/media` | List media |
| DELETE | `/media/{id}` | Delete media |

## Usage
| Method | Path | Purpose |
|---|---|---|
| GET | `/usage` | Current billing usage |

## Webhooks (events)
- `post.published` — post successfully hit at least one account
- `post.error` — all target accounts failed
- `account.token_expired` — OAuth refresh failed; user must re-auth

Webhook requests include `X-Outstand-Signature: sha256=<hmac>` when a signing secret is configured.
