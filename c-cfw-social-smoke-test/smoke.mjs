#!/usr/bin/env node
/**
 * c-cfw-social-smoke-test smoke runner
 *
 * Hits every GET + POST handler in cfw-social with master-key auth, classifies
 * each by its declared auth mode, and reports a pass/fail table.
 *
 * Pass rule:
 *   - public            → expects < 500  (handler must answer)
 *   - api-or-session    → expects < 500  (master-key + x-cfw-brand must auth)
 *   - session-only      → expects 401/403, or a 3xx redirect to /login
 *                          (the Better-Auth middleware bounces unauthenticated
 *                          calls to /login?redirect=...; that's the correct
 *                          rejection, not a 401 from the handler)
 *   - webhook           → SKIPPED (needs HMAC signature) — listed but not called
 *   - signed-token      → SKIPPED (needs HMAC token in URL)
 *
 * Anything that returns 5xx, times out, or refuses connection is a FAIL.
 *
 * NB: We use `redirect: "manual"` so the 307 → /login bounce is observable;
 * otherwise fetch follows it and we see /login's 200 instead.
 *
 * Usage:
 *   node smoke.mjs \
 *     --base-url=http://localhost:3000 \
 *     --api-key=<CFW_MASTER_API_KEY> \
 *     --brand-id=<brandId> \
 *     [--include=GET,POST,PATCH,PUT,DELETE]  (default: GET,POST)
 *     [--workspace-id=<id>]                  (default: auto-resolved via /workspaces/list)
 *     [--filter=<substring>]                 (only run routes whose path contains this)
 *     [--json]                               (emit JSONL instead of a colored table)
 *     [--timeout-ms=8000]                    (per-request timeout)
 *     [--concurrency=6]
 *
 * Env-var fallbacks (handy when invoked as a skill):
 *   CFW_BASE_URL, CFW_API_KEY, CFW_BRAND_ID, CFW_WORKSPACE_ID
 */

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── arg parsing ─────────────────────────────────────────────────────────────
const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const eq = a.indexOf("=");
    if (a.startsWith("--") && eq > 0) return [a.slice(2, eq), a.slice(eq + 1)];
    if (a.startsWith("--")) return [a.slice(2), "true"];
    return [a, "true"];
  })
);

const BASE_URL = (args["base-url"] ?? process.env.CFW_BASE_URL ?? "http://localhost:3000").replace(/\/$/, "");
const API_KEY = args["api-key"] ?? process.env.CFW_API_KEY ?? "";
const BRAND_ID = args["brand-id"] ?? process.env.CFW_BRAND_ID ?? "";
let WORKSPACE_ID = args["workspace-id"] ?? process.env.CFW_WORKSPACE_ID ?? "";
const INCLUDE = (args["include"] ?? "GET,POST").split(",").map((m) => m.trim().toUpperCase());
const FILTER = args["filter"] ?? "";
const JSON_OUT = args["json"] === "true";
const TIMEOUT_MS = Number(args["timeout-ms"] ?? 8000);
const CONCURRENCY = Number(args["concurrency"] ?? 6);

if (!API_KEY || !BRAND_ID) {
  console.error("ERROR: --api-key and --brand-id are required (or set CFW_API_KEY / CFW_BRAND_ID).");
  process.exit(2);
}

// ─── load manifest ───────────────────────────────────────────────────────────
const MANIFEST = JSON.parse(readFileSync(join(__dirname, "routes.json"), "utf8"));

// ─── id resolution ───────────────────────────────────────────────────────────
const PLACEHOLDER = {
  agentId: "00000000-0000-0000-0000-000000000000",
  apiKeyId: "00000000-0000-0000-0000-000000000000",
  brandId: BRAND_ID,
  captureId: "00000000-0000-0000-0000-000000000000",
  channelConnectionId: "00000000-0000-0000-0000-000000000000",
  compositionId: "00000000-0000-0000-0000-000000000000",
  conversationId: "00000000-0000-0000-0000-000000000000",
  insightId: "00000000-0000-0000-0000-000000000000",
  postId: "00000000-0000-0000-0000-000000000000",
  runId: "00000000-0000-0000-0000-000000000000",
  socialAccountId: "00000000-0000-0000-0000-000000000000",
  telegramChannelId: "00000000-0000-0000-0000-000000000000",
  workspaceId: WORKSPACE_ID || "00000000-0000-0000-0000-000000000000",
  botToken: "fake-bot-token",
  mediaPath: "smoke/none.txt",
  token: "smoke-token",
  provider: "smoke-nonexistent", // brand-secrets/{provider} — deleting a provider that was never stored is a no-op
};

// Try to discover a real workspaceId if the caller didn't supply one.
async function resolveWorkspaceId() {
  if (WORKSPACE_ID) return;
  try {
    const r = await fetch(`${BASE_URL}/api/v1/workspaces/list`, {
      headers: masterHeaders(),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!r.ok) return;
    const body = await r.json();
    const id = body?.workspaces?.[0]?.id ?? body?.[0]?.id;
    if (id) {
      WORKSPACE_ID = id;
      PLACEHOLDER.workspaceId = id;
    }
  } catch {}
}

// ─── header helpers ──────────────────────────────────────────────────────────
function masterHeaders(extra = {}) {
  return {
    "cfw-api-key": API_KEY,
    "x-cfw-brand": BRAND_ID,
    "content-type": "application/json",
    ...extra,
  };
}

function substitutePath(path) {
  return path.replace(/\{(\w+)\}/g, (_m, name) => PLACEHOLDER[name] ?? `unknown-${name}`);
}

function substituteBody(body) {
  if (!body || typeof body !== "object") return body;
  return JSON.parse(
    JSON.stringify(body).replace(/\$WORKSPACE_ID/g, PLACEHOLDER.workspaceId).replace(/\$BRAND_ID/g, BRAND_ID)
  );
}

// ─── classification ──────────────────────────────────────────────────────────
function expectedFor(auth) {
  switch (auth) {
    case "public":
    case "api-or-session":
      return { pass: (s) => s > 0 && s < 500, label: "<500" };
    case "session":
      // A 3xx (typically 307 to /login) is the correct rejection from the
      // Better-Auth middleware. 401/403 from the handler is equally valid.
      // A 2xx is suspect — the route may be missing its auth gate.
      return {
        pass: (s) => s === 401 || s === 403 || (s >= 300 && s < 400),
        label: "401/403 or 3xx",
      };
    case "webhook":
    case "signed-token":
      return { pass: () => true, label: "SKIPPED" };
    default:
      return { pass: (s) => s > 0 && s < 500, label: "<500" };
  }
}

function shouldCall(route) {
  if (route.auth === "webhook" || route.auth === "signed-token") return false;
  return true;
}

// ─── one request ─────────────────────────────────────────────────────────────
async function hit(method, route) {
  const url = `${BASE_URL}${substitutePath(route.path)}`;
  const baseHeaders =
    route.auth === "session" ? { "content-type": "application/json" } : masterHeaders();
  const headers = { ...baseHeaders, ...(route.headers ?? {}) };
  const init = {
    method,
    headers,
    redirect: "manual",
    signal: AbortSignal.timeout(TIMEOUT_MS),
  };
  if (method === "POST" || method === "PUT" || method === "PATCH") {
    init.body = JSON.stringify(substituteBody(route.body ?? {}));
  }
  const t0 = Date.now();
  try {
    const r = await fetch(url, init);
    const ms = Date.now() - t0;
    let preview = "";
    try {
      const text = await r.text();
      preview = text.slice(0, 140).replace(/\s+/g, " ");
    } catch {}
    return { status: r.status, ms, preview };
  } catch (err) {
    return { status: 0, ms: Date.now() - t0, preview: `ERR: ${err.message ?? err}` };
  }
}

// ─── runner ──────────────────────────────────────────────────────────────────
async function main() {
  await resolveWorkspaceId();

  // Build the list of (method, route) jobs.
  const jobs = [];
  for (const route of MANIFEST.routes) {
    if (FILTER && !route.path.includes(FILTER)) continue;
    for (const method of route.methods) {
      if (!INCLUDE.includes(method)) continue;
      jobs.push({ method, route });
    }
  }

  // Concurrency-limited execution.
  const results = new Array(jobs.length);
  let cursor = 0;
  async function worker() {
    while (true) {
      const i = cursor++;
      if (i >= jobs.length) return;
      const { method, route } = jobs[i];
      if (!shouldCall(route)) {
        results[i] = { method, route, skipped: true };
        continue;
      }
      const r = await hit(method, route);
      const exp = expectedFor(route.auth);
      results[i] = { method, route, ...r, ok: exp.pass(r.status), expected: exp.label };
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));

  // ─── report ────────────────────────────────────────────────────────────────
  if (JSON_OUT) {
    for (const r of results) {
      const out = r.skipped
        ? { skipped: true, method: r.method, path: r.route.path, auth: r.route.auth }
        : { method: r.method, path: r.route.path, auth: r.route.auth, status: r.status, ms: r.ms, ok: r.ok, preview: r.preview };
      console.log(JSON.stringify(out));
    }
    return;
  }

  const PAD = 56;
  const c = {
    g: (s) => `\x1b[32m${s}\x1b[0m`,
    r: (s) => `\x1b[31m${s}\x1b[0m`,
    y: (s) => `\x1b[33m${s}\x1b[0m`,
    dim: (s) => `\x1b[2m${s}\x1b[0m`,
    b: (s) => `\x1b[1m${s}\x1b[0m`,
  };

  console.log(c.b(`\nc-cfw-social-smoke-test smoke — ${BASE_URL} brand=${BRAND_ID.slice(0, 8)} workspace=${(WORKSPACE_ID || "n/a").slice(0, 8)}\n`));
  console.log(c.dim("STATUS  METHOD  PATH".padEnd(PAD + 16) + " AUTH              TIME"));
  console.log(c.dim("─".repeat(PAD + 38)));

  let pass = 0, fail = 0, skip = 0;
  const fails = [];
  for (const r of results) {
    const path = r.route.path.padEnd(PAD).slice(0, PAD);
    const method = r.method.padEnd(6);
    if (r.skipped) {
      skip++;
      console.log(c.dim(`SKIP    ${method}  ${path}  ${r.route.auth.padEnd(16)} —`));
      continue;
    }
    const tag = r.ok ? c.g("PASS  ") : c.r("FAIL  ");
    const status = String(r.status).padEnd(3);
    const ms = `${r.ms}ms`.padStart(6);
    console.log(`${tag}  ${method}  ${path}  ${r.route.auth.padEnd(16)} ${status}  ${ms}`);
    if (r.ok) pass++;
    else {
      fail++;
      fails.push(r);
    }
  }

  console.log();
  console.log(c.b(`${c.g(pass + " pass")}, ${fail > 0 ? c.r(fail + " fail") : "0 fail"}, ${c.dim(skip + " skipped")} of ${results.length} requests`));

  if (fails.length) {
    console.log(c.b("\nFailures:"));
    for (const r of fails) {
      console.log(`  ${c.r("✗")} ${r.method} ${r.route.path}  → status=${r.status}  ${c.dim(r.preview.slice(0, 120))}`);
    }
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("FATAL:", err);
  process.exit(2);
});
