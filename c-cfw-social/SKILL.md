---
name: c-cfw-social
description: >-
  THE comprehensive reference for managing the CFW Social app itself. Covers the
  full Prisma data model (User, Brand, Workspace, Agent, Run, Output, Composition,
  Post, ApprovalToken, PlatformConnection, ContentSource, BrandInsight, etc.),
  entity relationships, run lifecycle (pending → running → done/failed), output
  states, approval workflow (send-for-approval → signed-token → inbox
  approve/reject/revoke), publishing system (post creation → scheduling →
  calendar → platform publish), brand management (setup, DNA, insights, social
  account OAuth, channel connections, API keys), workspace operations (CRUD,
  sources, assets, runs/outputs/posts listing), auth cascade (Better-Auth session
  → brand-key → master-key → signed-token → webhook HMAC), and admin operations
  (stuck run recovery, key rotation, billing changes, account deletion). Load this
  whenever you need to reason about, query, mutate, or debug the CFW Social app's
  data or operations.
when_to_use: >
  Trigger on: "cfw social data model", "how does cfw-social work", "brand
  setup", "workspace management", "run lifecycle", "approval flow", "post
  scheduling", "cfw auth", "cfw-social admin", "recover stuck run",
  "platform connection", "social account oauth", "cfw-social Prisma",
  "content source", "brand insight", "composition status", "cfw-social
  publishing", "cfw-social billing", "cfw-social API key", "cfw-social
  channel connection", "what is a run in cfw", "what is a workspace in cfw",
  "how do approvals work", "cfw-social routes", "cfw-social middleware",
  "better-auth cfw", "cfw-social webhook", "stripe webhook cfw",
  "postforme webhook cfw", "telegram bot cfw", "discord bot cfw",
  "slack install cfw", "external agent call cfw", "call cfw api from agent",
  "api/v2 cfw", "cfw api key access", "programmatic api cfw",
  "how to call app.cfw.social", "cfw rest api", "brand secrets",
  "provider vault", "provider keys cfw", "quick publish", "posts/quick",
  "manage brand headlessly", "external agent manage brand",
  "create agent via api", "brand-key agent".
allowed-tools: Bash, Read, Write, Edit
---

# c-cfw-social — Comprehensive CFW Social App Management

This is the canonical skill for understanding, operating, and debugging the **CFW Social** application. It covers everything from the database schema to the HTTP API surface, from brand onboarding to post publishing.

## What this skill covers

| Topic | File | Read when you need… |
|---|---|---|
| **Data model** | `data-model.md` | Entity definitions, field glossaries, relationships, indexes |
| **Lifecycle** | `lifecycle.md` | How a run executes, how outputs are produced, how approvals flow, how posts get published |
| **Composition authoring** | `composition-authoring.md` | How an agent must build compositions: per-platform image sizes/aspect ratios, reel specs, carousel multi-image flow, per-platform caption formatting. **Read before calling `propose_composition`.** |
| **Brand management** | `brand-management.md` | Onboarding, DNA, insights, social accounts, channel connections, API keys, provider-key vault (brand-secrets), headless agent provisioning |
| **Workspace ops** | `workspace-operations.md` | CRUD, sources, assets, listing runs/outputs/posts within a workspace |
| **Approval workflow** | `approval-workflow.md` | send-for-approval, signed tokens, inbox actions, approval chat |
| **Publishing** | `publishing.md` | Posts, scheduling, calendar, platform constraints, status transitions |
| **Media & capture** | `media-capture.md` | Presigned uploads, capture events, linking, status polling |
| **Auth & security** | `auth.md` | Full auth cascade, middleware allowlist, HMAC, session vs API-key vs signed-token |
| **Integrations** | `integrations.md` | Telegram, Discord, Slack, Stripe, PostForMe setup guides |
| **Admin runbook** | `admin-runbook.md` | Stuck run recovery, key rotation, account deletion, billing changes |
| **API routes** | `routes.json` | Canonical manifest of every HTTP route + auth mode + sample body |
| **Local dev API quickstart** | `local-dev.md` | Base URL + working curl per auth mode + SSE consumption + dev-brand bootstrap (localhost:3000) |
| **Production API quickstart** | `prod.md` | Base URL (`app.cfw.social`), how to pull prod master key via Vercel, brand ID lookup, security notes on dev endpoints |
| **External agent API** | `external-agent-api.md` | How external agents/scripts call `app.cfw.social` via API key — `/api/v2/` route catalog, **full brand management via allowlisted `/api/v1/` routes** (create agents, quick publish, provider vault — PR #49, 2026-06-02), auth, SSE, Python + TS examples |
| **Quick start** | `README.md` | First-time orientation for operators |

## How to use this skill

1. **Start with `README.md`** for a quick orientation.
2. **Jump to the relevant topic file** based on what you're trying to do.
3. **Cross-reference `data-model.md`** when reasoning about queries or mutations — it has the ground truth on relationships.
4. **Check `routes.json`** when you need to know which endpoints exist and what auth they require.

## See also

- `c-cfw-social-smoke-test` — smoke-test runner for confirming no 5xx's after deploy
- `c-cfw-agent` — how to talk to the cfw-agent orchestrator via its MCP (`cfw_run` tool)
- `cfw-social/docs/orchestrator-contract-v1.md` — the frozen SSE contract between cfw-social and cfw-agent
