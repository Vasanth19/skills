---
name: c-ab-scheduler
description: Operate ab-hustler (formerly AB Scheduler) — the unified unattended worker that drains approved Paperclip issues (marketing + dev lanes) and file-queue backlogs for registered CODE repos. Use this to check what's running, register/unregister repos, approve/hold file-queue tasks, see and clear blockers (unblock/watch), trigger an immediate run, read run logs, fire a test notification, run an emergency drain (bypass Paperclip), or explain/tune the system.
when_to_use: Trigger on "AB scheduler", "ab-hustler", "scheduler status", "what's the scheduler doing", "what will run next", "register a project", "add a repo to the loop", "file-approve <task>", "file-hold <task>", "unhold", "what's blocked", "unblock <task>", "clear the blocker", "run the backlog now", "scheduler logs", "turn the scheduler on/off", "BLOCKED.md", "why didn't my task run", "make a task ready", "test notification", "auto-unblock", "watch the blockers", "emergency drain", "Paperclip offline".
allowed-tools: Bash, Read, Edit
---

# c-ab-scheduler — operate ab-hustler (the unified unattended dispatcher)

**ab-hustler** is the unified dispatcher for approved Paperclip issues (marketing + dev lanes)
AND file-queue backlogs for registered CODE repos. Formerly known as "AB Scheduler". The skill
name is kept for trigger compatibility. Full docs: `~/ecosystem/ab-hustler/README.md`.

Binary: `~/ecosystem/ab-hustler/ab-hustler.sh`
CTL:    `~/ecosystem/ab-hustler/ab-hustler-ctl.sh`
Config: `~/ecosystem/ab-hustler/engine.conf` (Paperclip orgs) + `projects.conf` (file-queue repos)

## Mental model

```
launchd — ONE job: com.gsai.ab-hustler (twice-hourly at :22 and :52)
  │
  ├── file-inbox bridge: scan each registered org's backlog/queue/ for status:ready files
  │     → convert to Paperclip issues (hustle:ready + lane:dev) → move to wip/
  │
  ├── marketing lane (hustle:ready + no lane:dev): headless CD/CM worker
  │     → claude -p "<issue>" --dangerously-skip-permissions
  │     → outcome: in_review / done / blocked
  │
  └── dev lane (hustle:ready + lane:dev): full AB pipeline per repo
        → architect → dev → QA → serial integrate → merge to develop
        → outcome: done (merged) / in_review (coding_done) / blocked / timeout
```

**Single launchd job replaces all per-repo `com.absched.*` timers (retired).**

## The one command you drive everything with

`~/ecosystem/ab-hustler/ab-hustler-ctl.sh <verb> [args]`

### Paperclip-board verbs

| Verb | What it does |
|---|---|
| `status` | board state (ready/running/blocked) across all orgs + launchd job status |
| `history [n]` | last N runs from telemetry DB (default 20) |
| `ready <id> [--lane dev\|marketing]` | add hustle:ready to a Paperclip issue |
| `run-now [org]` | trigger an immediate drain (⚠️ real work) |
| `bridge-now [org]` | file-inbox bridge only (no workers) |
| `blockers` | all open Paperclip blockers |
| `unblock <id>` | remove hustle:blocked, add hustle:ready |
| `logs [n]` | tail drainer log |

### File-queue verbs

| Verb | What it does |
|---|---|
| `list` | repos in projects.conf |
| `register <name> <dir>` | add a code repo to projects.conf + create backlog dirs |
| `unregister <name>` | remove a repo (leaves backlog/ intact) |
| `file-queue [repo]` | show eligible (status:ready) file-queue tasks |
| `file-approve <pattern>` | flip matching queue file to status: ready |
| `file-hold <pattern>` | pull matching queue file back to status: backlog |
| `watch` | auto-unblock notes with answer: field filled (loop-safe) |
| `test-notify` | fire a test notification |
| `locks [project]` | show held ab-locks (via ab-lock.sh) |
| `reap [project]` | clear expired leases (via ab-lock.sh) |

### launchd control

| Verb | What it does |
|---|---|
| `enable` | load + enable com.gsai.ab-hustler plist |
| `disable` | unload + disable com.gsai.ab-hustler plist |

### Emergency

| Verb | What it does |
|---|---|
| `emergency-drain <repo-dir>` | bypass Paperclip; drain queue/ via ab-lib directly |

## Operator playbook — map intent → action

**"Add project X to the loop" / "I want X on the scheduler"**
→ `ab-hustler-ctl.sh register <name> <dir>`. Note: this adds to projects.conf for file-queue
operations. To have the org polled for Paperclip issues, add a line to `engine.conf` as well.
The ab-* command suite must be in `<dir>/.claude/commands/` for the dev pipeline to work.

**"What's it going to work next?"** → `status` (Paperclip board) + `file-queue` (file tasks).

**"Approve X" (Paperclip issue)** → `ready <id>` or `ready <id> --lane dev`.

**"Approve X" (file-queue task)** → `file-approve <id-substring>`.

**"Hold X" (file-queue task)** → `file-hold <id-substring>`.

**"What's blocked (Paperclip)?"** → `blockers`. Relay *needs* + *how to unblock*. NEVER invent the answer.

**User gives an unblock answer (Paperclip)** → `unblock <ISSUE-ID>`, then offer `run-now`.

**User gives an unblock answer (file-queue)** → fill the `answer:` field in the blocked note,
then `watch` picks it up. Or run `emergency-drain <repo>` to drain without Paperclip.

**"Paperclip is offline, I need to drain the queue"** → `emergency-drain <repo-dir>`. This runs
the full ab-lib pipeline (worktree→build→merge) with zero Paperclip calls. File lifecycle:
`queue/ → wip/ → done/<YYYY-MM>/ or blocked/`. Reconcile the board manually afterwards.

**"Run it now"** → `run-now [org]`, then `logs`. ⚠️ Real work + merges to develop.

**"Why didn't my task run?"** → check: (1) missing hustle:ready label → `ready <id>`;
(2) Paperclip API unreachable; (3) job disabled → `enable`; (4) global cap reached →
`locks` to see what's in-flight; (5) file-queue: status != ready → `file-approve`.

**"Turn it off/on"** → `disable` / `enable`.

## Task file frontmatter (file-queue)

```yaml
---
task-id: "MYPROJ-42"
title: "Short title"
status: ready             # ready = eligible; backlog = parked
priority: normal          # high | normal | low
model: sonnet             # optional: opus | sonnet | haiku | glm
effort: high              # optional: low | medium | high | max (native only)
---
```

`model:` and `effort:` are honoured in both emergency-drain and via the bridge (translated to
Paperclip `hustle:model-*` / `hustle:effort-*` labels on the created issue).

## Config knobs (still honoured in ab-lib)

Set via env or `<repo>/backlog/.scheduler/config`:

- `AB_FANOUT` — tasks in parallel per batch (default 3)
- `AB_MERGE_TARGET` — branch to merge into (default develop)
- `AB_AGENT_TIMEOUT` — per-agent wall-clock cap, seconds (default 1500 = 25 min)

## Files

| Path | Role |
|---|---|
| `~/ecosystem/ab-hustler/engine.conf` | Paperclip org registry |
| `~/ecosystem/ab-hustler/projects.conf` | file-queue repo registry |
| `~/ecosystem/ab-hustler/ab-hustler.sh` | main drainer + bridge + emergency-drain |
| `~/ecosystem/ab-hustler/ab-hustler-ctl.sh` | operator control CLI |
| `~/ecosystem/ab-hustler/ab-lib.sh` | AB pipeline shared library |
| `~/ecosystem/ab-hustler/ab-lock.sh` | cross-channel concurrency mutex |
| `~/ecosystem/ab-hustler/ab-hustler.db` | telemetry DB (runs + counters + bridge_map) |
| `~/Library/LaunchAgents/com.gsai.ab-hustler.plist` | the ONE launchd timer |
| `~/.claude-worktrees/<repo>-<TASK-ID>` | per-task agent worktree (transient) |
| `~/.claude-worktrees/<repo>-ab-develop` | dedicated serial-merge worktree |
| `<repo>/backlog/{queue,wip,blocked,done}` | file-queue lifecycle folders |
