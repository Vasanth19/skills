# c-cfw-social

THE comprehensive reference for managing the CFW Social application.

## What is this?

CFW Social is the main application — a Next.js 16 app with a Prisma/PostgreSQL backend that handles:
- **Brands** (tenants) with DNA, insights, social connections
- **Workspaces** (topic containers) with agents, sources, runs, compositions
- **Runs** (agent executions) that produce outputs via the cfw-agent orchestrator
- **Compositions** (type-locked deliverables) that go through human approval
- **Posts** (scheduled/published content) dispatched to social platforms
- **Auth** (Better Auth sessions, brand-scoped API keys, webhooks, signed tokens)
- **Integrations** (Telegram, Discord, Slack, Stripe, PostForMe)

## Quick start

### For operators

1. Read `data-model.md` to understand the entities and relationships
2. Read `lifecycle.md` to understand how work flows through the system
3. Jump to the relevant topic file (brand-management, workspace-operations, etc.)

### For engineers

1. Read `auth.md` to understand the auth cascade and middleware allowlist
2. Read `routes.json` to see every endpoint + auth mode + sample body
3. Use `c-cfw-social-smoke-test` to verify no 5xx's after deploy

### For debugging

1. Check `admin-runbook.md` for stuck run recovery, key rotation, billing changes
2. Query `AgentAuditLog` and `AuditLog` for telemetry and security events
3. Use `routes.json` + auth.md to trace request flow

## File map

| File | Read when you need… |
|---|---|
| `SKILL.md` | Orientation + "what this skill covers" |
| `README.md` | This file — quick start |
| `data-model.md` | Entity definitions, relationships, indexes |
| `lifecycle.md` | Run → output → approval → post flow |
| `brand-management.md` | Onboarding, DNA, insights, connections, keys |
| `workspace-operations.md` | CRUD, sources, assets, runs/outputs/posts |
| `approval-workflow.md` | send-for-approval, signed tokens, inbox |
| `publishing.md` | Posts, scheduling, calendar, platform constraints |
| `media-capture.md` | Presigned uploads, capture events, linking |
| `auth.md` | Auth cascade, middleware, HMAC, encryption |
| `integrations.md` | Telegram, Discord, Slack, Stripe, PostForMe setup |
| `admin-runbook.md` | Recovery, rotation, deletion, billing, tuning |
| `routes.json` | Every HTTP route + auth mode + sample body |

## Related skills

- [`c-cfw-social-smoke-test`](../c-cfw-social-smoke-test/) — smoke-test runner for the HTTP API
- [`c-cfw-agent`](../c-cfw-agent/) — how to talk to the cfw-agent orchestrator via MCP
