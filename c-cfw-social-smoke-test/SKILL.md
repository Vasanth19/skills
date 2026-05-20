---
name: c-cfw-social-smoke-test
description: Smoke-test every GET + POST handler on a running cfw-social instance with master-key auth; classifies expected status by auth mode (public / api-or-session / session / webhook / signed-token). Fast 5xx hunt across every route after deploy or route changes.
when_to_use: Trigger on "smoke test cfw-social", "smoke test the API", "check cfw-social endpoints", "is the server healthy", "did my route changes break anything", "test all GETs/POSTs", "cfw smoke", "verify cfw-social deploy".
allowed-tools: Bash, Read
---

# c-cfw-social-smoke-test — Endpoint smoke runner

This folder contains the **smoke-test runner** for cfw-social HTTP API endpoints.

| File | Audience | Use it when |
|---|---|---|
| `SKILL.md` (this file) — drives `smoke.mjs` + `routes.json` | engineers QA'ing cfw-social | You touched `src/app/api/**` and want a fast 5xx hunt across every route |

> **Related:** [`c-cfw-agent`](../c-cfw-agent/) — caller's guide for the cfw-agent MCP (`cfw_run` tool).  
> **Related:** [`c-cfw-social`](../c-cfw-social/) — comprehensive management guide for the CFW Social app (data model, lifecycle, operations).

---

## Endpoint smoke runner

Hits every GET + POST route declared in `routes.json` against a running cfw-social
instance (default `http://localhost:3000`). Each route is classified by its auth
mode and the runner asserts the right pass condition:

| Auth mode         | Pass condition                                              |
|-------------------|-------------------------------------------------------------|
| `public`          | HTTP < 500 (handler answered)                               |
| `api-or-session`  | HTTP < 500 (master-key + `x-cfw-brand` must auth)           |
| `session`         | 401/403 or a 3xx redirect to /login (proxy.ts bouncing the unauth call) |
| `webhook`         | **Skipped** — requires a real HMAC signature                |
| `signed-token`    | **Skipped** — requires a real HMAC token in the URL         |

Anything that returns ≥ 500, refuses connection, or times out is a **FAIL**.

### The `auth` tag reflects GATEWAY auth, not just the handler

`src/proxy.ts` is the Next.js 16 middleware. It has an explicit allowlist
(`ALWAYS_OPEN_PREFIXES` + `ALWAYS_OPEN_REGEXES`) of routes that bypass the
session-cookie check and authenticate themselves inside the handler. Only
those routes are tagged `api-or-session` in the manifest — everything else
under `/api/v1/*` is `session`, **even if the handler file imports
`requireApiBrand`**, because the middleware will 307 → /login before the
handler ever runs.

The current allowlist (as of v3 of the manifest):

- `/api/v1/mcp`, `/api/v1/audit-log` — prefix allowlist
- `/api/v1/brand/{id}/context`, `/api/v1/brand/{id}/captures`, `/api/v1/brand/dna`
- `/api/v1/brands/{id}/insights`, `/api/v1/brands/{id}/insights/{insightId}`
- `/api/v1/posts/{id}` (DELETE)
- `/api/v1/captures*`, `/api/v1/dev/*`, `/api/v1/social/callback/*`
- All webhooks (`/api/webhooks/stripe`, `/api/v1/telegram/webhook/*`, `/api/v1/slack/events`, `/api/v1/discord/interactions`, `/api/v1/webhooks/*`)

If you want a session-protected route reachable by master key from a
server-to-server caller, add its path/regex to `src/proxy.ts` first, then
re-tag it in `routes.json`.

## Caller variables

| Variable          | Required | Source                                       | Notes                                                                            |
|-------------------|----------|----------------------------------------------|----------------------------------------------------------------------------------|
| `$CFW_API_KEY`    | Yes      | Caller / `cfw-social/.env` (`CFW_MASTER_API_KEY`) | The **master** API key. Paired with `x-cfw-brand` it grants brand-scoped access. |
| `$CFW_BRAND_ID`   | Yes      | Caller                                       | The brand whose data the request is scoped to.                                   |
| `$CFW_BASE_URL`   | No       | Caller                                       | Default `http://localhost:3000`. Set to `https://app.cfw.social` for prod.       |
| `$CFW_WORKSPACE_ID` | No     | Caller (auto-resolved if absent)             | Used for `/workspaces/{id}/...` routes. Auto-fetched via `/workspaces/list`.     |

The runner sends both `cfw-api-key: $CFW_API_KEY` and `x-cfw-brand: $CFW_BRAND_ID`
on every authenticated request (see `src/lib/auth/api-auth.ts` for the auth cascade).

## Invocation

```bash
node /Users/vasanth/Code/skills/c-cfw-social-smoke-test/smoke.mjs \
  --base-url="$CFW_BASE_URL" \
  --api-key="$CFW_API_KEY" \
  --brand-id="$CFW_BRAND_ID"
```

Common flags:

| Flag                       | Default       | Effect                                                                       |
|----------------------------|---------------|------------------------------------------------------------------------------|
| `--include=GET,POST`       | `GET,POST`    | Which HTTP methods to call. Add `PATCH,PUT,DELETE` to exercise mutators too. |
| `--workspace-id=<id>`      | auto-resolved | Override the workspace used for `/workspaces/{id}/...` routes.               |
| `--filter=<substring>`     | none          | Only run routes whose path contains the substring (e.g. `--filter=workspaces`). |
| `--json`                   | off           | Emit JSONL (one record per request) instead of a colored table.              |
| `--timeout-ms=8000`        | `8000`        | Per-request timeout.                                                         |
| `--concurrency=6`          | `6`           | Parallel in-flight requests.                                                 |

Env vars `CFW_BASE_URL`, `CFW_API_KEY`, `CFW_BRAND_ID`, `CFW_WORKSPACE_ID`
override / replace the flags. The runner exits `1` on any failure (suitable for CI).

## Quick recipes

```bash
# Smoke localhost against a specific brand
node smoke.mjs --api-key="$CFW_MASTER_API_KEY" --brand-id=ef06fc8c-2712-4124-a712-805602b617e3

# Only test workspace routes
node smoke.mjs --api-key="$KEY" --brand-id="$B" --filter=workspaces

# Include destructive methods (be careful)
node smoke.mjs --api-key="$KEY" --brand-id="$B" --include=GET,POST,PATCH,PUT,DELETE

# Machine-readable output for CI
node smoke.mjs --api-key="$KEY" --brand-id="$B" --json > smoke.jsonl
```

## When routes change

`routes.json` is hand-curated from `src/app/api/**/route.ts`. After adding,
removing, or renaming a route, edit `routes.json` and bump `_version`. The
runner does not auto-discover routes — that's intentional: the manifest also
encodes the expected auth mode and a sane default body shape, both of which
can't be reliably inferred.

Common edits:
- New GET route → add `{ "path": "...", "methods": ["GET"], "auth": "api-or-session" }`.
- New POST → add `body: { ... }` with a minimally-valid shape (or `{}` to trigger 400, still a pass).
- New `{paramName}` segment → add a placeholder entry to `PLACEHOLDER` in `smoke.mjs`.

## Failure triage

A FAIL means a 5xx, a connection refused, or a timeout — i.e. the handler
crashed or never answered. Look at the `preview` column for the first ~140
chars of the response body, then:

1. Check the server logs for the matching path.
2. Confirm the route file imports compile (`pnpm typecheck`).
3. Confirm Prisma is connected (`SELECT 1` via psql).
4. If only one auth mode fails everywhere, suspect `src/lib/auth/api-auth.ts`.

## Files in this skill

- `SKILL.md`     — this file
- `smoke.mjs`    — the runner (Node 20+, no deps; uses global `fetch`)
- `routes.json`  — manifest of every route + its declared auth mode + sample body
