---
name: c-paperclip
description: >-
  The main skill for managing the Paperclip control plane — the multi-agent
  orchestration system that runs Vasanth's AI workforce across every
  organization. Load this whenever you need to inspect, create, update, comment
  on, organize, cancel, or approve issues; work across multiple orgs/companies;
  understand how agents pick up and execute work (heartbeats, checkout, agent
  lifecycle, adapters, OpenClaw runtime); align the day's work to
  Paperclip-routed priorities; or reason about when and how to file tracked
  work. This is the primary "manage my Paperclip system" skill. Related:
  `/pc-impersonate` (run as a specific agent), `/board` (cross-org board view),
  `paperclip-create-agent` (hiring agents), `paperclip-converting-plans-to-tasks`.
---

# Paperclip — Control Plane Management

Paperclip is the multi-agent orchestration platform — if OpenClaw is an employee,
Paperclip is the company. It owns task/issue assignment, agent lifecycle, org
charts, goals, approvals, routines, cost tracking, and the heartbeat system that
wakes agents to do work. This skill is the operator's guide to running it.

- **Where:** `/Users/vasanth/Code/paperclip`
- **API:** `http://localhost:3100` (all endpoints under `/api`, all JSON)
- **CLI:** `paperclipai`
- **Adapters** (how agents are run): `claude_local`, `codex_local`, `cursor`,
  `gemini_local`, `openclaw_gateway`, `hermes_local`, `process`, `http`
- **OpenClaw** is the agent runtime — an individual AI employee that receives
  heartbeats from Paperclip via the `openclaw_gateway` adapter.

## How work actually flows (the model)

Agents do **not** run continuously. They run in **heartbeats** — short execution
windows triggered by Paperclip (timer, assignment, on-demand, or event-driven).
Each heartbeat an agent: wakes up → checks identity & inbox → picks work →
**checks out** the issue (atomic — one agent per task; a 409 means it's already
owned) → reads context → does the work → updates status → exits.

This is why issue hygiene matters: agents act on what the issue says. A vague,
unassigned, or mis-statused issue produces no useful heartbeat.

## Organizations (companies)

Paperclip is multi-org. Every issue belongs to a company. Always resolve the
company first:

```bash
paperclipai company list --json          # all orgs → id + prefix (VAS, GRO, PAS, COM, …)
```

Issue identifiers carry the org prefix (`VAS-43`, `GRO-12`, `COM-8`). When working
across orgs, scope every list/create call with `--company-id <id>`. For a
cross-org rollup, use the `/board` skill.

## Issue lifecycle

**Statuses:** `backlog` → `todo` → `in_progress` → `in_review` → `done`; plus
`blocked` and `cancelled`.

- `backlog` — parked/unscheduled, not about to be started.
- `todo` — ready and actionable, not yet checked out.
- `in_progress` — actively owned, execution-backed work (entered via checkout).
- `in_review` — paused pending a reviewer/approver/board/user. A *healthy* waiting
  path, not a synonym for done. Needs a real reviewer path.
- `blocked` — cannot proceed until something specific changes. Always name the
  blocker and who must act; prefer first-class `blockedByIssueIds` over free text.
- `done` — complete, no follow-up on this issue.
- `cancelled` — intentionally abandoned. Does NOT count as a resolved blocker.

**Priorities:** `critical`, `high`, `medium`, `low`.

## Core operations (CLI)

### List issues
```bash
paperclipai issue list --status todo,in_progress,in_review,blocked --json
paperclipai issue list --company-id <id> --json
paperclipai issue list --assignee-agent-id <id> --json
```
Display as a table: identifier | status | priority | title. Group blocked →
in_review → in_progress → todo.

### Get an issue (full detail + comments)
```bash
paperclipai issue get <identifier-or-uuid> --json
```
Show title, status, assignee, description, then comments chronologically.

### Create an issue
Required: `--title` and `--company-id` (look it up first).
```bash
paperclipai issue create \
  --company-id <id> \
  --title "<title>" \
  [--description "<desc>"] \
  [--priority critical|high|medium|low] \
  [--status backlog|todo|in_progress|in_review|blocked]
```
Print the new identifier after creation.

### Update an issue
```bash
paperclipai issue update <identifier> \
  [--status done|blocked|in_review|in_progress|todo|cancelled] \
  [--priority critical|high|medium|low] \
  [--title "<text>"]
```
Shorthands: `done` → status done, `block` → blocked, `review` → in_review,
`start` → in_progress.

### Comment on an issue
```bash
paperclipai issue comment <identifier> --body "<body>"
```
For multiline markdown, build the body from a heredoc/file — never hand-compress
markdown into a one-line string, or comments get "smooshed" together.

### Approvals
```bash
paperclipai approval list --json
paperclipai approval approve <id>
paperclipai approval reject <id> --reason "<reason>"
paperclipai approval request-revision <id> --reason "<reason>"
```

### Agents
```bash
paperclipai agent list --json            # name | role | current issue | status
```

For API-level work (subtasks, documents, blockers, interactions, routines,
execution workspaces) the full endpoint surface lives in the Paperclip repo skill
at `~/Code/paperclip/skills/paperclip/` and its `references/api-reference.md`.

## Caveats — when (and when not) to create an issue

- **Create an issue** for any meaningful, trackable unit of work: something an
  agent should pick up, something with a deliverable, something you'd want a
  history on. Conscious deviation from priorities is fine — but if it's real
  work, file it so it becomes tracked.
- **Don't create an issue** for trivial throwaway steps, or as a substitute for
  just doing a 30-second task. Don't fragment one coherent deliverable into a
  dozen micro-issues.
- **One issue = one outcome.** If you can't state the "done" condition in a
  sentence, the issue is too big — split it, or make a parent with children.
- Always set `--company-id` to the *correct* org. Misfiled issues are invisible
  to the agents who should see them.

## Keeping Paperclip organized

- **Parent / children = decomposition only:** `parentId` is for splitting one
  deliverable into genuine subtasks — never for grouping by theme or sprint (use
  `goalId` and labels for that; see *Org-wide PM structure* below). Don't
  busy-poll children — Paperclip wakes the parent's assignee when all children
  complete.
- **Blockers are first-class:** express "A is blocked by B" via `blockedByIssueIds`
  (an array — it *replaces* the set on each update; send `[]` to clear). Dependent
  work auto-resumes when blockers reach `done`. `cancelled` blockers do NOT count
  as resolved.
- **Status hygiene:** never leave finished artifact work sitting in `in_progress`
  with no live continuation path. Move it to `done`, `in_review` (real reviewer),
  or `blocked` (named blocker) before walking away.
- **Don't cancel cross-team tasks** — reassign to the owning manager with a
  comment explaining why.
- **Ticket references are links:** in comments/descriptions, wrap any
  `{PREFIX}-{NUMBER}` id as a markdown link with the company prefix, e.g.
  `[VAS-43](/VAS/issues/VAS-43)`. Never leave bare ticket ids.
- **Comment style:** short status line, bullets for what changed / what's blocked,
  links to related entities. For agent-work handoffs use the STATE / RUN /
  PENDING / BLOCK / NEXT schema — bullets only, no prose.
- **Plans live as issue documents** (`plan` document key), not as repo files and
  not appended into the description.

## Org-wide PM structure & weekly sprints

Every Paperclip org follows one operating model. The canonical, full SOP lives in
GBrain — `brain-personal` page `concepts/infra/paperclip/pm-structure-sprint-playbook`
(read it with `mcp__brain-personal__get_page` or `brain-personal query`). The
essentials:

**The Goal tree is a full OKR tree** — all four `level` values are used:

| Goal `level` | OKR role | Lifespan | Title shape |
|---|---|---|---|
| `company` | **Pillar** + headline target | Standing | `<pillar> — <metric>` |
| `team` | **Objective** — what a squad drives this cycle | 12-week cycle | `<workstream> — Cycle YYYY-MM-DD→MM-DD` |
| `agent` | **Key Result** — measurable outcome, `ownerAgentId` set | 12-week cycle | `<role>: <metric> this cycle` |
| `task` | **Monthly milestone** — the achievable monthly chunk | 1 month | `Month <n> (<month>): <chunk>` |

Goals nest via their own `parentId` — one level per rung, no skipping. Goals are
**not** issues. **Pillars** are the 3–6 standing life/business areas of an org.
The live tree is the source of truth — fetch with
`GET /api/companies/{companyId}/goals`; never hardcode pillar names here.

**The other primitives:**

| Primitive | Role |
|---|---|
| **Project** | 1:1 with a repo/folder — never an epic, never a sprint |
| **Issue** | One finishable outcome; carries `goalId` (most specific descendant Goal) + `projectId` if it touches a repo |
| **Label** `sprint-YYYY-MM-DD-DD` | The week (Sun–Sat) the work is committed to |
| **Routine** | The weekly-ritual automation (cron) |

**The time model — 12-Week Year:** Cycle (12 wk, the strategic unit — set
Objectives/KRs/milestones) → Month (a `task`-level milestone, ~3 per cycle) →
Sprint (the weekly `sprint-…` label) → Issue.

**Hard rules:**
- **Sprint = Label, never a parent issue.** A "sprint" parent issue bloats every
  child's ancestor context (agents walk the parent chain on each heartbeat),
  forces weekly re-parenting churn, and steals the single `parentId` slot from
  real decomposition. Tag the week with a label; filter the board by `labelId`.
- **`parentId` = decomposition only** (in *both* trees). Issue `parentId` builds
  the epic→L1→L2 execution tree; Goal `parentId` builds the OKR ladder. Theme
  grouping is `goalId`. A large "NO PARENT" issue bucket is correct and healthy —
  group-by-Goal or filter-by-sprint-label instead of inventing parents.
- **Every issue carries `goalId`** — bound to the *most specific* descendant Goal:
  epic → Objective; L1/L2 → KR or Monthly milestone.
- **`[EPIC]` issues are a smell.** Convert them to `team`-level Objective Goals;
  re-point their children via `goalId` and clear `parentId`.

**Per-org hygiene checklist** (run once per org as a migration, then keep clean):
1. Establish the org's 3–6 `company`-level Pillar Goals.
2. `[EPIC]` issues → `team`-level Objective Goals, parented to their Pillar;
   children re-pointed via `goalId`.
3. Add `agent`-level KRs (set `ownerAgentId`) + `task`-level monthly milestones
   under each Objective.
4. Re-bind every issue's `goalId` to its most specific descendant Goal.
5. `projectId` audited — repo-touching issues only.
6. Malformed issues fixed (UUID-as-title, etc.).
7. Orphaned `parentId` refs cleared.
8. Junk/test issues deleted; duplicate clusters deduped (keep one canonical).
9. Current `sprint-YYYY-MM-DD-DD` label minted + applied to committed work; rest → `backlog`.

**Keep it tidy with a background agent — but never as Paperclip issues.** Don't
hand-clean orgs ad hoc, and don't file "housekeeping" issues — the board is for
clear, crisp *work*, not chores. The sweep runs as a **local launchd job** invoking
headless `claude -p` weekly — NOT a remote `/schedule` routine (can't reach the
localhost API) and NOT a Paperclip Routine (would spawn issues). It loads context
first — the PM doctrine from GBrain, plus each org's goals, projects, agents and
skills — then:
- **Organizes aggressively** (reversible, fully logged — this is the point of the
  job): assigns `goalId` to every open issue missing one, applies the current
  sprint label to committed work, sets `parentId` on clear decomposition
  relationships, ties recurring-event clusters to their goal, mints the sprint
  label.
- **Deletes clutter decisively** (irreversible — but clutter ≠ work): junk/test
  issues, redundant duplicate copies (comments don't protect a *copy*), and recurring
  process residue (`routine_execution` / productivity-review / stalled-recovery /
  repeated post-mortem clusters — keep one, delete the rest). Only ever when
  `done`/`cancelled`/`backlog` + childless. Never an open issue, never one with
  children, never a distinct real deliverable. The safety is the *definition of
  clutter*, not hesitation.
- **Flags upstream** (out-of-band digest + Discord scoop, never an issue):
  `[EPIC]`-titled issues, recurring tasks that should be Routines, stuck/stale work,
  anything genuinely unclassifiable.

The rule: **organizing is reversible and is the point — do it aggressively;
deleting is irreversible — do it carefully.** A timid sweep that only "reports" is
a failed sweep. Full spec: `~/.paperclip/hygiene/hygiene-prompt.md`.

## Daily Priority Alignment

Priorities are managed in Paperclip — there is no separate "today's priorities"
file. The source of truth is whatever open work the control plane has routed to
Vasanth, surfaced automatically by the `daddy-priority-check.sh` SessionStart hook.

**What counts as "on today's list"** — an issue that is open AND:
- `assigneeUserId == "local-board"` (assigned directly to Vasanth), OR
- `status == "in_review"` (needs his sign-off), OR
- `status == "blocked"` (needs him to unblock)

…ranked high → medium → low, with direct-assignments beating review/blocked at the
same priority.

**When to check:**
1. **Session start** — the hook auto-injects the top items. Read them.
2. **Before new work** — does this map to a Paperclip issue? If not, gently flag
   it and offer to create one.
3. **When the user drifts** — "Heads up — this doesn't match Paperclip priorities.
   Want to continue, or refocus?"
4. **Progress updates** — when work advances, update the issue (comment, status,
   work-product). Don't track progress in side files.
5. **End of session** — move relevant issues forward (`in_review`, `done`, or a
   handoff comment).

**Rules:**
- Never guilt-trip. The system is for awareness, not punishment.
- Conscious deviation is fine — but track meaningful work as an issue.
- If Paperclip is unreachable, the hook says so; proceed without alignment checks.
  Do not fall back to any retired priority file.

## Error handling

- CLI/API error → show the raw error, stop, do **not** retry silently.
- Server unreachable → "Paperclip server not responding at http://localhost:3100
  — is it running?"
- Unknown company → run `paperclipai company list --json` and show the options.
- A `409 Conflict` on checkout means the task belongs to another agent — never
  retry it.

## Attaching files to issues

Agents and the board can attach files directly to issues. Attachments are
stored locally at `~/.paperclip/instances/default/data/storage/` (keyed by
`{companyId}/issues/{issueId}/{date}/{uuid}-{filename}`).

**Allowed types** (enforced server-side):
- Text/scripts: `text/plain`, `text/markdown`, `text/csv`, `text/html`
- Data: `application/json`
- Documents: `application/pdf`
- Images: `image/png`, `image/jpeg`, `image/webp`, `image/gif`
- **NOT yet allowed:** video, audio, zip, binary executables

**How to attach** (curl — preferred for agents and board use):
```bash
curl -s -X POST \
  "http://localhost:3100/api/companies/{companyId}/issues/{issueId}/attachments" \
  -F "file=@/path/to/file;type=text/markdown"
```
Resolve `companyId` and `issueId` (UUID, not the VAS-357 identifier) before calling.
The identifier-to-UUID lookup: `paperclipai issue get VAS-357 --json | jq .id`.

**When to attach:**
- Script bundles (`.md`, `.sh`, `.py`) that the issue describes or delivers
- Reference PDFs, brand briefs, or spec sheets that an agent needs to consume
- Screenshots or diagrams that clarify acceptance criteria
- **Do NOT attach:** large binaries, video files, or files already checked into a repo

**Attachment preview in the UI** — the issue detail page renders attachments inline:
text/script files expand with a copy button; images show in a gallery; video plays inline
(once video MIME types are uploaded).

## Related skills
- `/pc-impersonate` — run a session AS a specific Paperclip agent.
- `/board` — cross-org board summary, monitoring, sponsoring agent work.
- `paperclip-create-agent` — hiring/configuring new agents.
- `paperclip-converting-plans-to-tasks` — turning a plan into a dependency tree of issues.
