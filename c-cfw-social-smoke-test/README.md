# c-cfw-social-smoke-test

Smoke-test runner for the cfw-social HTTP API (`smoke.mjs` + `routes.json` + `SKILL.md`) — used to confirm no route 5xx's after a deploy.

> **See also:** [`c-cfw-social`](../c-cfw-social/) — comprehensive management guide for the CFW Social app.

---

## Folder contents

| File | What it is | Read it for |
|---|---|---|
| `README.md` | this file | A first-time overview |
| `SKILL.md` | Frontmatter + smoke-runner docs | "How do I confirm cfw-social isn't 5xx'ing after my route changes?" |
| `smoke.mjs` | Node script that hits every cfw-social route | The actual runner; called by `SKILL.md` instructions |
| `routes.json` | Manifest of every cfw-social route + auth mode + sample body | Hand-curated; edit after route changes (bump `_version`) |

---

## Quick start

### Prerequisites
- cfw-social running on `http://localhost:3000` (or prod `https://app.cfw.social`).
- `$CFW_MASTER_API_KEY` from `cfw-social/.env`.
- `$CFW_BRAND_ID` from your local Postgres.

### Run the smoke

```bash
node /Users/vasanth/Code/skills/c-cfw-social-smoke-test/smoke.mjs \
  --base-url=http://localhost:3000 \
  --api-key="$CFW_MASTER_API_KEY" \
  --brand-id="$CFW_BRAND_ID"
```

Full docs: `SKILL.md` (frontmatter, flags, recipes, failure triage).

Auth is the **cfw-social master-key path** (`cfw-api-key` + `x-cfw-brand` headers). Brand API keys (stored in the `api_keys` table, bcrypt-verified server-side) are environment-scoped: a key seeded in local dev won't exist in production and vice versa — never copy a local key and try it against prod. Generate and register the appropriate key for each environment.

---

## Shipping this to a teammate

Two things they need:

1. The folder `~/Code/skills/c-cfw-social-smoke-test/` (drop into their `~/Code/skills/` or `~/.claude/skills/`).
2. A working `CFW_MASTER_API_KEY` + `CFW_BRAND_ID` pair.

---

## Related docs

- [`c-cfw-social`](../c-cfw-social/) — data model, lifecycle, auth cascade, admin runbook
- `c-cfw-social/routes.json` + `auth.md` — request-flow tracing
