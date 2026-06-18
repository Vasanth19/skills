---
name: pc-dispatch
allowed-tools: Bash, Read, Agent, Skill
description: Orchestrator dispatch — resolve a Paperclip task to its project + role, then spawn an in-session sub-agent stamped with that role's persona, the brand's context, and the right skills. You stay the orchestrator; the sub-agent carries the context, does the work, and updates the issue. Trigger on BOTH the explicit `/pc-dispatch <TASK-ID>` command AND natural-language intent to delegate Paperclip work to a role/brand — e.g. "work on VAS-575", "have the creative director make the MGG outro", "dispatch this to the CTO", "get the founding engineer on CFW-83", "spawn a sub-agent for PAS-234", "make a reel for Tamil Thozha about X", "have the CD produce <thing> for <brand>", "kick off <TASK-ID>", "assign this to <role>". Whenever the orchestrator should hand a task to the right role-worker rather than doing it itself, use this.
---

# /pc-dispatch $ARGUMENTS

## Step 0 — Invocation (slash command OR natural language)

This fires two ways. Normalize both into `{TASK-ID(s), role?, project?, background?}` before Step 1:

- **Explicit command** — `/pc-dispatch VAS-575 role:creative-director` → parse args directly.
- **Natural language** — the user describes work to delegate, e.g. "have the creative
  director do the MGG outro", "work on VAS-575", "get the founding engineer on CFW-83",
  "make a reel for Tamil Thozha about morning routines". Extract:
  - **Task ID** if present (`VAS-575`, `CFW-83`…) → use it.
  - **Role** if named ("creative director", "CTO", "founding engineer"→`fullstack-dev`/`cto`,
    "designer"→`ux-expert`, etc.) → use it; else infer in Step 3.
  - **Brand/project** if named ("Tamil Thozha", "MGG", "Wellbeing"…) → resolve to its
    `ecosystem.yaml` project entry.
  - **No task ID given** (pure description of work): resolve the project from the brand named,
    then **find or create** the backing Paperclip issue before dispatching:
    1. Search that project's open issues for a clear match (`paperclipai issue list
       --project <id>` / the company issues endpoint). If one fits, use it.
    2. If none fits, create one first (`paperclipai issue create` under the right company +
       project, title from the request, status `todo`), tell the user the new ID, **then**
       dispatch. Never dispatch work that has no Paperclip issue behind it — the worker must
       have an issue to update (priority-stack rule 3).
  - If the brand/project is ambiguous or you can't tell which issue, **ask** — don't guess.

You are the **orchestrator**. Do **not** switch your own context. Your job is to look at a
Paperclip task, figure out *which project it belongs to* and *which role should do it*, then
spawn an **in-session sub-agent** (the `Agent` tool) that is born with exactly that identity:
the role persona + the brand `CLAUDE.md` + the brand's `.claude/skills/` recipes + the task.
The sub-agent does the work and reports back to you. You collect the result and move on.

## Argument format

```
/pc-dispatch <TASK-ID> [role:<role-slug>] [background]
```

- `TASK-ID` — Paperclip identifier, e.g. `VAS-573`, `CFW-83`, `PAS-234`. **Required.**
- `role:<role-slug>` — optional override. One of:
  `creative-director`, `cto`, `fullstack-dev`, `devops`, `cmo`, `sdr`, `qa`,
  `quality-auditor`, `ceo`, `ux-expert`.
  If omitted, **infer** the role from the task (see Step 3).
- `background` — optional. Run the sub-agent with `run_in_background: true` so you're free
  to dispatch more while it works. Default: foreground (you wait for one, then report).

You can also pass **several** task IDs to fan out: `/pc-dispatch VAS-575 VAS-576 CFW-83`.
Dispatch each as its own sub-agent — in **one** message with multiple `Agent` calls so they
run concurrently.

---

## Step 1 — Resolve the task → company → issue

For each `TASK-ID`:

1. Split the prefix (everything before `-`): `VAS`, `CFW`, `PAS`, `COM`, `FUL`, `LEA`, `GRO`, `GROA`.
2. Map prefix → `companyId` from `~/.gsai/ecosystem.yaml` (the `orgs` block — each org has
   `prefix:` and `paperclip_id:`). Read it; never hardcode.
3. Fetch the issue:
   ```bash
   curl -s "http://localhost:3100/api/companies/<companyId>/issues?limit=200" \
     | python3 -c "import sys,json; \
       issues=json.load(sys.stdin); \
       issues=issues if isinstance(issues,list) else issues.get('issues',[]); \
       m=[i for i in issues if i.get('identifier')=='<TASK-ID>']; \
       print(json.dumps(m[0],indent=2) if m else 'NOT FOUND')"
   ```
   (If the list endpoint is paginated and the issue isn't found, widen `limit` or page.)
4. From the issue, capture: `title`, `description`, `status`, `priority`, `projectId`,
   `assigneeAgentId`, `assigneeUserId`, `executionAgentNameKey`.
   - **Fail fast:** if the task isn't found, stop and report — do not guess an ID.

## Step 2 — Resolve project → workspace cwd + skills

1. In `~/.gsai/ecosystem.yaml`, find the `projects:` entry whose `paperclip:` == the issue's
   `projectId`. Read off its `local:` path — that is the **brand/workspace cwd**.
   - If `projectId` is null or no entry matches, stop and tell the user the task has no mapped
     workspace (it can't be dispatched with brand context — ask whether to run it generically).
2. Derive the two context paths:
   - Brand instructions: `<local>/CLAUDE.md` (may not exist — note it, don't fail).
   - Skills/recipes:     `<local>/.claude/skills/` — list it:
     ```bash
     ls -1 <local>/.claude/skills/ 2>/dev/null
     ```
   - **If the skills dir is empty or missing AND the role is `creative-director`**, warn the
     user: this brand has no recipes wired (the known gap — only `mr-growth-guide` and
     `b-vasanth` have them today). The CD sub-agent will have nothing to produce from. Offer
     to proceed anyway or wire skills first.

## Step 3 — Resolve the role

Order of precedence:
1. Explicit `role:<slug>` argument → use it.
2. Else the issue's assignee/`executionAgentNameKey` if it names a role → use it.
3. Else **infer** from the task `title` + `description`:
   - creative asset / reel / video / post / carousel / thumbnail / brand content → `creative-director`
   - build / API / endpoint / bug / refactor / deploy / migration / code → `fullstack-dev`
     (use `cto` for architecture/decision-level, `devops` for infra/CI/deploy)
   - campaign / positioning / GTM / messaging / launch strategy → `cmo`
   - outbound / leads / discovery calls / prospecting → `sdr`
   - test / QA / smoke / regression / verify → `qa`
   - audit / review / quality gate → `quality-auditor`
   - design / UX / wireframe / usability → `ux-expert`
   - cross-cutting strategy / decision → `ceo`

Confirm the persona dir exists: `~/.gsai/paperclip-agents/roles/<role>/`. If not, stop and
list the available roles.

## Step 4 — Compose the sub-agent prompt

Build a prompt that **stamps the identity** (the sub-agent shares your cwd, so context must be
injected — it will `Read` these paths itself):

```
You are the <ROLE TITLE> for <PROJECT NAME>. Act fully in that role.

IDENTITY & PROCESS — read these first:
- Persona/process: ~/.gsai/paperclip-agents/roles/<role>/  (read AGENTS.md, HEARTBEAT.md, and any *-STANDARD.md)
- Brand context:   <local>/CLAUDE.md   (brand voice, visual standards, recipe matrix — if present)

YOUR TOOLS/SKILLS — load the ones the task needs:
- Recipes/skills live at <local>/.claude/skills/ — available: <list from Step 2>
  Load a recipe by reading its SKILL.md, then follow its pipeline through to final/.
  (If none are listed, say so explicitly and do not invent a pipeline.)

WORKING DIRECTORY:
- Treat <local> as your working directory for all file output. Create/read files there, not in
  the orchestrator's cwd.

TASK — Paperclip <TASK-ID> (<priority>):
<title>

<description>

DELIVERABLE:
- Do the work end-to-end. <For CD: produce through to final/. For dev: implement + verify build/tests.>
- **ALWAYS update Paperclip issue <TASK-ID> with your results before you finish** — this is mandatory, not optional:
  1. Post a comment on the issue with: what you produced, the exact file paths / output
     locations, key decisions, and anything blocked or assumed. Use:
     `paperclipai issue comment <TASK-ID> --body "<results>"`
     (or POST `http://localhost:3100/api/companies/<companyId>/issues/<issueId>/comments`
     with `{"body": "..."}` if the CLI isn't available).
  2. Set status to reflect reality: `in_review` if the work is complete and awaiting
     approval, or `blocked` (name the blocker) if you couldn't finish. Use the CLI
     `paperclipai issue update <TASK-ID> --status <status>` or the issue PATCH endpoint.
     Do NOT set `done` — `done` is the orchestrator's/board's call after review.
- Then report the same summary back to the orchestrator.
```

Fill every `<...>` with the resolved values. Keep the task title/description verbatim. Pass the
resolved `companyId` and the issue's `id` (UUID, from Step 1) into the prompt so the worker can
address the comment/PATCH endpoints without re-resolving them.

## Step 5 — Spawn the sub-agent

Call the `Agent` tool:
- `subagent_type`: `general-purpose` (the persona is carried by the injected prompt, so no
  custom agent type is needed).
- `description`: `<role> · <TASK-ID>` (3–5 words).
- `prompt`: the composed prompt from Step 4.
- `run_in_background`: `true` only if `background` was passed or you're fanning out several.

For multiple task IDs, issue all `Agent` calls in **one** message so they run concurrently.

## Step 6 — Collect & report

- Foreground: when the sub-agent returns, relay a tight summary to the user — role dispatched,
  task, what came back, file paths, blockers. You did not switch context; the worker did.
- Background: tell the user what you launched and that you'll report on completion. Don't read
  the sub-agent's raw output file via shell.
- Status: the worker already posted its results to the issue and set it to `in_review` (or
  `blocked`). Confirm that landed. Only `done` is yours/the board's — offer it on the user's
  say-so after review, per issue discipline.

---

## Notes

- **Why inject instead of cd:** an in-session sub-agent shares the orchestrator's working
  directory — it does not `cd` into the brand folder, so `<cwd>/.claude/skills/` auto-mounting
  does **not** happen for it. Injecting the persona + brand + skills paths into the prompt is
  what gives the worker its identity regardless of cwd.
- **The skills gap is real:** today only `mr-growth-guide` and `b-vasanth` have recipes wired.
  Dispatching a `creative-director` to Tamil Thozha, Wellbeing, Longevity Lab, AI Creator Lab,
  etc. will surface an empty skills dir until those brands are wired. Warn, don't silently
  proceed.
- **Detached alternative:** if a task needs live browser auth or a long unattended run, prefer
  `/pc-impersonate <ORG>/<role> <project> new tab` (a real process in the brand cwd with skills
  auto-mounted) over an in-session sub-agent.
