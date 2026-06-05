---
name: c-ab-scheduler
description: Operate the CFW AB Scheduler — the unattended hourly worker that drains the cfw-social and cfw-agent backlog queues by running /ab-work-on-it on approved (status:ready) tasks, then pings when it hits a hard block. Use this to check what's running, approve/hold tasks, see and clear blockers (unblock), trigger an immediate run, read run logs, or explain/tune the system.
when_to_use: Trigger on "AB scheduler", "scheduler status", "what's the scheduler doing", "what will run next", "approve <task>", "hold <task>", "unhold", "what's blocked", "unblock <task>", "clear the blocker", "run the backlog now", "scheduler logs", "turn the scheduler on/off", "is the hourly task running", "BLOCKED.md", "why didn't my task run", "make a task ready".
allowed-tools: Bash, Read, Edit
---

# c-ab-scheduler — operate the CFW unattended backlog worker

The **CFW AB Scheduler** runs `/ab-work-on-it` on a timer for two repos and pings the user
only when it gets genuinely stuck. This skill is the operator manual + the exact commands to
drive it. Full docs live at `/Users/vasanth/Code/cfw/scripts/AB-SCHEDULER.md`.

## Mental model (say this if the user asks "what is it")

```
launchd
  ├─ :00 hourly → ab-scheduler.sh cfw-social → picks ONE approved task → /ab-work-on-it → merge to develop
  └─ :30 hourly → ab-scheduler.sh cfw-agent  → (same)
```

- **One task per run**, never the whole queue. Cadence ≈ 1 task/hour/repo.
- **Approval gate:** it ONLY works tasks whose frontmatter is `status: ready`. Everything
  else in `queue/` (`backlog`, `blocked`, `coding_done`, `in_progress`) is ignored. Highest
  priority first (`high > normal/medium > low`), oldest-file tie-break. No `ready` task ⇒ the
  run is a silent no-op (logged `SKIP`).
- **Fully autonomous** once a task is `ready`: code → tests → `/ab-test-and-complete` →
  merge to **`develop`** (never `main`). It stops only on a hard block.
- **Hard block ⇒** it writes `<repo>/backlog/blocked/<TASK-ID>.md` with a concrete
  *How to unblock* section, never guesses, never half-merges.

## The one command you drive everything with

`/Users/vasanth/Code/cfw/scripts/ab-scheduler-ctl.sh <verb> [args]`
(the user runs it relative as `scripts/ab-scheduler-ctl.sh …` from the cfw root; when YOU run
it via Bash, always use the absolute path — your cwd is not guaranteed.)

| Verb | What it does |
|---|---|
| `status` | are the two launchd jobs loaded? |
| `ready` | list approved+eligible tasks per repo (what WILL run next) |
| `approve <id>` | flip a queued task to `status: ready` (the approval valve) |
| `unhold <id>` | flip a task back to `status: backlog` (scheduler will skip it) |
| `blockers` | print all open blockers + their *reply with* line |
| `unblock <id> "<answer>"` | clear a blocker: fold the answer into the task, set `ready`, requeue, delete the note |
| `run-now [social\|agent\|both]` | trigger an immediate run (don't wait for the hour) |
| `logs [social\|agent]` | tail run history |
| `on` / `off` | enable / disable both jobs |

## Operator playbook — map intent → action

**"What's it going to work next?" / "what's approved?"**
→ `ab-scheduler-ctl.sh ready`. Report the per-repo list and the top of each (that's next).

**"Approve X" / "make X ready" / "let it work X"**
→ `ab-scheduler-ctl.sh approve <id>`. Then remind: it'll be picked at the next :00/:30 and
merged to develop. If they approve several, note they run one-per-hour in priority order.
Before approving anything that ships a **Prisma migration / schema change**, flag the blast
radius (it merges to develop unattended) and confirm they want it autonomous.

**"Hold X" / "don't run X yet" / "pull X back"**
→ `ab-scheduler-ctl.sh unhold <id>` (sets it back to `backlog`).

**"What's blocked?"**
→ `ab-scheduler-ctl.sh blockers` (or `Read /Users/vasanth/Code/cfw/BLOCKED.md`). Relay the
*needs* + the suggested *reply with* line. NEVER invent the answer — it's the user's call.

**User replies with an unblock answer** (e.g. "use STRIPE_PRICE_PRO_M", "the key is hg_live_…")
→ this is the core loop. Run:
`ab-scheduler-ctl.sh unblock <TASK-ID> "<their exact answer>"`.
That appends an `## Owner resolution` block to the task, sets it `status: ready`, moves it
back to `queue/`, and deletes the blocked note. Then offer `run-now` so it retries now
instead of waiting for the hour.

**"Run it now" / "don't wait an hour"**
→ `ab-scheduler-ctl.sh run-now both` (or `social`/`agent`). Then `logs` to watch.
⚠️ This does real work and merges to develop — confirm before triggering if unprompted.

**"Why didn't my task run?"** — check in order:
1. `status:` is not `ready` (most common — it's still `backlog`). → `approve` it.
2. It has an unresolved `blocked-by:` dependency.
3. The job is off (`status` shows nothing loaded) → `on`.
4. A higher-priority `ready` task ran instead (one-per-hour).

**"Turn it off/on" / pause the automation** → `off` / `on`.

## Surfacing — how blockers reach the user ("the terminal here")

Four overlapping surfaces (see AB-SCHEDULER.md): macOS notification on block; root
`/Users/vasanth/Code/cfw/BLOCKED.md` (auto-generated, self-clears); SessionStart hook prints
blockers when the cfw folder opens; Stop hook injects a *new* mid-session block once.
Hooks are wired in `/Users/vasanth/Code/cfw/.claude/settings.local.json`.

## How a task becomes work the user creates

The user creates work by writing AB-* task files into `<repo>/backlog/queue/` (per the
`feedback-workflow-ab-tasks` convention / the `/ab-create-task` command) as `status: backlog`,
then **approves** the ones they want built. Nothing runs until approved. See the project's
existing `cfw-social/.claude/commands/ab-*.md` for the underlying task engine.

## Files (all under /Users/vasanth/Code/cfw)

| Path | Role |
|---|---|
| `scripts/ab-scheduler.sh` | per-repo hourly worker (launchd calls it); holds the approval gate |
| `scripts/ab-scheduler-ctl.sh` | the control panel — every verb above |
| `scripts/ab-blocked-write-root.sh` | regenerates root `BLOCKED.md` (single source of truth) |
| `scripts/ab-blocked-surface.sh` | SessionStart hook |
| `scripts/ab-blocked-stop-hook.sh` | Stop hook (mid-session blocker injection) |
| `scripts/AB-SCHEDULER.md` | full human docs |
| `~/Library/LaunchAgents/com.cfw.ab-scheduler.cfw-{social,agent}.plist` | the :00 / :30 timers |
| `<repo>/backlog/.scheduler/runs.log` | run history |
| `<repo>/backlog/blocked/*.md` | open blockers awaiting an answer |

## Tuning knobs

- **One vs all per run:** the gate hands the agent ONE task ID. To drain the whole approved
  set each run, you'd loop in `ab-scheduler.sh` — don't, unless the user explicitly asks.
- **Approval keyword:** the gate matches `status: ready`; override per-run with
  `AB_READY_STATUS=<word>`.
- **Cadence:** edit `StartCalendarInterval` in the plists, then `ctl off && ctl on`.
- **Autonomy:** runs with `--dangerously-skip-permissions`; blast radius is `develop` only.
