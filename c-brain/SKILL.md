---
name: c-brain
description: >-
  How to use GBrain — the permanent, git-versioned knowledge base — across BOTH
  of its instances: `brain-personal` (life + business knowledge: projects,
  people, companies, decisions, SOPs) and `brain-competitive` (scraped community
  intelligence, patterns, gap analysis — Research-agent only, hard firewall).
  Load this whenever you need to STORE or RETRIEVE permanent knowledge, decide
  WHERE a piece of information or a file belongs, navigate either brain on disk,
  use the `brain-personal` / `brain-competitive` MCP tools or CLIs, or apply the
  project-repo-vs-GBrain litmus test. Covers both brains, their MCP tool
  surfaces, the firewall between them, recall/write order, the canonical
  vasanth-hq folder structure, and the "where does X go?" decision matrix.
---

# GBrain — Using the Permanent Knowledge Base

GBrain is the permanent, git-versioned knowledge base. It is the source of truth
for projects, people, companies, decisions, SOPs, and competitive intelligence.
There are **two isolated instances** — pick by content type, **NEVER mix them**.

| | `brain-personal` | `brain-competitive` |
|---|---|---|
| **Holds** | Life + business knowledge: projects (CFW, GrowthSystems, SellersCommerce, clients), people, companies, decisions, SOPs, email-to-brain ingestion, the `vasanth-hq/` HQ context | Scraped Skool communities (Mark Kashef Early AI Dopters, Nate Herk, etc.), extracted patterns/frameworks, gap analysis, opportunities |
| **GBRAIN_HOME** | `/Users/vasanth/Code/Infra/brain-personal/` | `/Users/vasanth/Code/Infra/brain-competitive/` |
| **Postgres DB** | `postgresql://localhost:5433/brain_personal` | `postgresql://localhost:5433/brain_competitive` |
| **CLI** | `brain-personal` (in PATH) | `brain-competitive` (in PATH) |
| **MCP tools** | `mcp__brain-personal__*` | `mcp__brain-competitive__*` |
| **Read access** | All agents | **Research agent ONLY** |
| **Write access** | All agents (per Write Order) | **Research agent ONLY** |

**What it is technically:** garrytan/gbrain — markdown on disk + Postgres (pgvector
+ FTS + graph). Git-versioned. Each page has compiled-truth at the top, an
append-only timeline below. Fully rebuildable from disk via `<instance> reindex`.
Survives reinstalls. Embeddings: Ollama `nomic-embed-text` (local, 768d).
Reasoning: Anthropic Claude.

## ⚠️ The brain-competitive Firewall (HARD RULE)

`brain-competitive` is a competitive-intelligence vault. Read AND write are
restricted:

- **Research agent only.** It reads to find gaps + patterns, and writes new intel
  from scrapes.
- **Content / Comms / CMO / Creative Director agents MUST NEVER query
  `brain-competitive`.** Risk: semantic confusion and plagiarism.
- If a non-Research agent needs a competitive insight, the Research agent first
  extracts a *sanitized* note into `brain-personal/concepts/`. Content agents read
  from there — never from the competitive brain directly.
- Never call a `mcp__brain-competitive__*` tool, or the `brain-competitive` CLI,
  unless you are operating as the Research agent.

## Using the brains — MCP tools

Both instances expose the same MCP tool surface. Use the `mcp__brain-personal__*`
prefix for the personal brain and `mcp__brain-competitive__*` for the competitive
brain (Research only). Prefer MCP tools over raw CLI/grep when the MCP is up.

**Retrieval — the everyday tools:**
- `query` — natural-language question over the brain; the default for "what do we
  know about X?"
- `search` — keyword/FTS search across pages
- `recall` — pull back stored memory relevant to a context
- `think` — reasoning pass over brain content
- `traverse_graph` — walk the knowledge graph from a starting node
- `get_recent_salience` — what's recently important
- `resolve_slugs` — turn names/slugs into canonical page references

**Pages — read & write:**
- `get_page`, `list_pages` — read
- `put_page` — create or update a page (compiled-truth + timeline pattern)
- `get_chunks` — retrieve the chunked/embedded form of a page
- `get_versions`, `revert_version` — page history
- `delete_page`, `restore_page`, `purge_deleted_pages` — lifecycle

**Graph, links, tags:**
- `add_link`, `remove_link`, `get_links`, `get_backlinks` — relationships between pages
- `add_tag`, `remove_tag`, `get_tags` — tagging

**Timeline & facts:**
- `add_timeline_entry`, `get_timeline` — append-only event log on a page
- `extract_facts`, `forget_fact` — structured facts

**Ingestion, sources & jobs:**
- `sources_add`, `sources_list`, `sources_remove`, `sources_status` — managed sources
- `submit_job`, `get_job`, `list_jobs`, `get_job_progress`, `send_job_message`,
  `cancel_job`, `pause_job`, `resume_job`, `retry_job`, `replay_job` — async jobs
- `file_upload`, `file_url`, `file_list` — attachments
- `log_ingest`, `get_ingest_log`, `get_raw_data`, `put_raw_data` — ingestion plumbing

**Health & maintenance:**
- `get_health`, `get_stats`, `run_doctor` — status
- `sync_brain` — re-index after editing markdown on disk
- `find_anomalies`, `find_orphans` — integrity checks
- `get_brain_identity`, `whoami` — confirm which instance you're talking to

**Takes / transcripts:** `takes_list`, `takes_search`, `takes_scorecard`,
`takes_calibration`, `get_recent_transcripts`.

## Using the brains — CLI quick reference

```bash
brain-personal query "Sarah at Acme pricing history"
brain-personal sync                # re-index after editing markdown on disk
brain-personal reindex             # rebuild the DB from markdown
brain-competitive query "Skool funnel patterns"   # Research agent ONLY
```

## Background services (auto-start at login via launchd)
- `com.gbrain.autopilot.brain-personal` — continuous (5-min) sync + embed + extract + dream cycle
- `com.gbrain.sync.brain-competitive` — every 15 min
- `com.gbrain.dream.brain-personal` — nightly 2 AM (11-phase maintenance)
- `com.gbrain.dream.brain-competitive` — nightly 3 AM (staggered)
- `com.gbrain.maintenance.brain-{personal,competitive}` — weekly Mon

## When a GBrain MCP fails
Fall back to grepping the markdown directly:
`rg "term" /Users/vasanth/Code/Infra/brain-personal/`. Tell the user the MCP is
down — do not silently switch knowledge stores or fabricate an answer.

## Recall Order (always follow)
1. **File path / project location** → read `~/.gsai/ecosystem.yaml`
2. **Business / life knowledge** (project decisions, people, companies, SOPs,
   email history) → `brain-personal` MCP (`mcp__brain-personal__query` first)
3. **Competitive intel** (scraped communities, frameworks, gap analysis) →
   `brain-competitive` MCP — **Research agent only**
4. **MCP unavailable** → grep the markdown:
   `rg "..." /Users/vasanth/Code/Infra/brain-personal/`

## Write Order
- **Business truth** (decision made, person met, company researched, SOP authored,
  project milestone) → `mcp__brain-personal__put_page` (or write markdown to
  `/Users/vasanth/Code/Infra/brain-personal/<projects|people|companies|concepts|skills>/...`
  using the compiled-truth + timeline pattern, then `brain-personal sync`).
- **Competitive intel** (scraped post, extracted framework, gap analysis) → the
  `brain-competitive` brain. **Research agent only.** Content / Comms / CMO /
  Creative Director agents must NEVER write here.
- **Never invent a top-level GBrain folder** — follow the existing structure
  (`projects/`, `people/`, `companies/`, `concepts/`, `skills/`, `vasanth-hq/`).

## Canonical `vasanth-hq/` structure (HQ-level context)

`brain-personal/vasanth-hq/` is for HQ-LEVEL context that sits ABOVE individual
projects — Vasanth-the-person, not Vasanth-on-a-project. Master `_README.md` lives
at the folder root; each subfolder has its own `_README.md` describing what does
and does NOT belong.

| Folder | What goes there |
|---|---|
| `banks/` | Bank accounts, cards, brokerage, institutions |
| `subscriptions/` | SaaS, streaming, memberships — recurring spend |
| `finance/investments/` | Equity, crypto, real estate, angel positions |
| `finance/expenses/` | Recurring + one-off cost categories, budget caps |
| `finance/taxes/` | Filing history, deductions, entity structures |
| `assets/` | Equipment, software licenses, domains, IP, keys inventory |
| `contacts/` | Phone, email, addresses for people who matter |
| `decisions/` | **HQ-level only** — life-level strategic decisions, NOT project decisions |
| `personal/` | Health, insurance, fitness, hobbies, family |
| `workflow/` | Cross-project routines and rituals |
| `aspirations/` | Life goals, favorite-problems lists, what to build next |
| `career/` | Career history (companies worked at, roles, learnings) |
| `identity/` | Identity decisions, principles, intellectual blueprint |
| `journal/` | Daily journaling, reflections |
| `logs/` | Action logs, decision logs, assistant-actions logs |
| `meetings/` | Meeting notes (`YYYY-MM-DD - title.md`) |
| `north-star/` | Life/business north-star, metrics, periodic reviews |
| `project-index.md` | One-line summary of every project + paths |
| `skill-registry.md` | Where every reusable skill lives on disk |
| `agents.md` | Instructions for AI agents reading the brain |
| `master-plan.md` | Knowledge-base architecture + phased build plan |

**Never invent a top-level `vasanth-hq/` folder.** If a fit isn't obvious, STOP
and ask Vasanth.

**Project decisions go in `brain-personal/projects/<project>/decisions/`** — not in
`vasanth-hq/decisions/`. The HQ decisions folder is for things like "should I move
to Austin," "Solo CTO vs build a team" — org-structure choices that affect all of
Vasanth's work.

## Project repo vs GBrain — the litmus test

Project runtime repos (e.g. `~/vasanth-hq/mr-growth-guide/`, `~/Code/rspur/`,
`~/vasanth-hq/job-hunter/`) hold anything the system needs to RUN. GBrain holds the
WHY behind those files.

**Ask: "If someone deleted this file, would the system stop working, or would I
just lose the explanation?"**
- System stops → project repo
- Lose the explanation → GBrain

**Lives in the project repo (NEVER in GBrain):**
- Runtime YAML / JSON / TOML configs the system loads (e.g. `postforme.yaml`)
- Supporting scripts (`.scripts/*.sh`, `scripts/*.py`)
- Raw analytics dumps, JSONL state, generated reports
- Source code, lockfiles, credentials, build artifacts

**Lives in GBrain (NOT duplicated in the project repo):**
- Decision docs ("why we picked X on date Y because Z")
- SOPs / runbooks ("how to add a new YT channel")
- Patterns and frameworks ("X hook format converts at Y%")
- People / company / project-level context
- Postmortems and learnings

If you catch yourself copying a YAML or script into GBrain "so I can search it
later" — STOP. `rg "term" <project-repo>/` already indexes the project repo.
GBrain stores the rationale, not the artifact.

## Decision Matrix — where does X go?

| If I want to store... | It goes in... |
|---|---|
| "CFW picked Redis Streams over RabbitMQ on 2026-02-14" | brain-personal/projects/cfw/decisions/ |
| "Sarah at Acme prefers concise emails, last spoke 2026-04-12" | brain-personal/people/sarah-acme.md |
| "SOP for onboarding a new client" | brain-personal/skills/client-onboarding.md |
| "GrowthSystems quarterly revenue trend" | brain-personal/projects/growthsystems/ |
| "Email from John about pricing" | brain-personal/accounts/<acct>/threads/ |
| "Mark Kashef's funnel pattern from Skool post" | brain-competitive/communities/early-ai-dopters/ (Research only) |
| "Extracted: how top AI creators monetize" | brain-competitive/patterns/ (Research only) |
| "Sanitized takeaway for Content agents to use" | brain-personal/concepts/ (so Content can read it) |
| "Chase Sapphire — 2% on dining, billing cycle 14th" | brain-personal/vasanth-hq/banks/ |
| "Anthropic API monthly: $X, why kept" | brain-personal/vasanth-hq/subscriptions/ |
| "Angel check into startup Y, valuation, vesting" | brain-personal/vasanth-hq/finance/investments/ |
| "2026 LLC vs S-corp decision rationale" | brain-personal/vasanth-hq/finance/taxes/ |
| "M4 MacBook Pro — 64GB / 2TB, primary work machine" | brain-personal/vasanth-hq/assets/ |
| "Accountant John — phone, scope of work" | brain-personal/vasanth-hq/contacts/ |
| "Should I move to Austin? Decision + reasoning" | brain-personal/vasanth-hq/decisions/ |
| "Friday weekly-review structure" | brain-personal/vasanth-hq/workflow/ |
| "Where does the X skill live?" | brain-personal/vasanth-hq/skill-registry.md |
| "Quick summary of every project" | brain-personal/vasanth-hq/project-index.md |
| "How does GBrain delete/sync/embed actually work?" | brain-personal/concepts/infra/gbrain/ |
| "Paperclip routine spec or platform gotcha" | brain-personal/concepts/infra/paperclip/ |

**Never invent a top-level GBrain folder** — follow the existing structure, and
check `~/.gsai/ecosystem.yaml` for where projects live.
