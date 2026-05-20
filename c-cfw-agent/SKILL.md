---
name: c-cfw-agent
description: >-
  How to interact with the cfw-agent orchestrator via its Model Context Protocol
  (MCP). Covers the `cfw_run` tool (single tool that takes brandId + prompt and
  returns generated outputs as R2 URLs), MCP registration in Claude Code, auth
  (`x-api-key` flow with brand-scoped `openclawApiKey`), the 3 MCP catalog
  resources (`cfw://catalog/agent-guide`, `skills-catalog`, `skills-json`), 10
  example prompts, error modes, local vs prod, and the bring-your-own smoke test.
  Also covers the 28 MCP tools exposed by cfw-social at `/api/v1/mcp` that
  cfw-agent uses as its back-channel for mutations (create_workspace,
  propose_composition, request_approval, record_brand_insights, etc.).
when_to_use: >
  Trigger on: "cfw_run", "cfw agent", "call cfw-agent", "register cfw-agent
  MCP", "cfw-agent MCP", "how to use cfw_run", "ship cfw-agent to a teammate",
  "cfw-agent smoke test", "cfw-agent protocol", "cfw-agent local",
  "cfw-agent production", "cfw-agent auth", "cfw-agent error",
  "orchestrator contract", "cfw-agent tools", "cfw-agent integration",
  "cfw-agent caller guide".
allowed-tools: Bash, Read, Write
---

# c-cfw-agent — CFW Agent Interaction Guide

How to talk to the **cfw-agent** orchestrator — the service that runs the AI loop, picks skills, and produces content.

## What is cfw-agent?

- A Hono-based HTTP service (port 8081 local, Railway in prod)
- Receives `POST /chat/stream` calls from cfw-social
- Runs a Claude Sonnet / Kimi K2.6 agent loop
- Spawns `claude --print` subprocesses to execute file-system skills
- Streams typed SSE events back to cfw-social
- Also exposes an **MCP endpoint** at `POST /mcp` for external callers

## Two ways to talk to cfw-agent

| Path | Audience | Auth | Use it when… |
|---|---|---|---|
| `cfw-social → POST /chat/stream` | Internal | `x-api-key` (decrypted `Brand.openclawApiKey`) | cfw-social web UI or chat channels trigger runs |
| **External → `POST /mcp`** | **You** | **`x-api-key` header** | You want to call `cfw_run` from Claude Code, curl, or CI |

This skill covers the **external MCP path**.

## Files in this skill

| File | What it covers |
|---|---|
| `SKILL.md` | This file — orientation |
| `README.md` | Quick start for first-time callers |
| `mcp.md` | Full MCP caller guide — registration, auth, `cfw_run`, resources, 10 example prompts, error modes |
| `mcp-example.sh` | Bash smoke test — no Claude Code dependency |
| `cfw-run.md` | Deep dive on `cfw_run` tool schema, streaming, progress tokens |
| `orchestration-contract.md` | The frozen v1 SSE contract between cfw-social and cfw-agent |

## See also

- `c-cfw-social` — comprehensive management guide for the CFW Social app itself
- `c-cfw-social-smoke-test` — smoke-test runner for cfw-social HTTP API
- `cfw-agent/CLAUDE.md` — service architecture, env vars, durable rules
- `cfw-social/docs/orchestrator-contract-v1.md` — the frozen SSE contract (same content as `orchestration-contract.md` here)
