---
name: r-cfw-publisher
description: >
  Publish due Posts from CFW Social V2's Post table.
  Polls /api/v1/posts/due for one brand, pulls /publish-bundle for each,
  routes to the right provider skill (postforme / outstand / upload-post),
  then PATCHes /publish-result with the platformPostId or failureReason.
  Stateless — caller passes brandId + V2 API key + V2 base URL via args/env.
---

# r-cfw-publisher


> **SELF-IMPROVEMENT RULE — READ FIRST:**
> 1. Before executing ANY step in this skill, read `LEARNINGS.md` in this same folder.
> 2. Apply every item under **Active Feedback** as if it were a non-negotiable rule.
> 3. Only then proceed with the skill's normal instructions.
> 4. After completing the task, ask the user: "How did this go? Any corrections or improvements for next time?"
> 5. Summarize the feedback into 1–3 bullet points and append to `LEARNINGS.md` with today's date.
> 6. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section so it applies on every future run.

## What This Is
A scheduled publisher for CFW Social V2's `Post` table. Picks up `Post` rows
where `status='scheduled'` and `scheduledAt <= now`, executes them via the
right provider skill, then closes the loop by PATCHing `/publish-result`.

The skill is intentionally **stateless** — it never reads from a DB itself,
never enumerates brands, never decides when to run. The trigger (cron, daemon,
heartbeat, manual `bash run.sh`) is the caller's job.

## When to use
- Triggered by a cron container, daemon, or any external scheduler.
- One invocation per brand. Caller supplies `--brand-id` + `--api-key`.

## API Reference (V2 endpoints used)
- `GET    /api/v1/posts/due`                   — list scheduled posts due for publishing
- `GET    /api/v1/posts/:id/publish-bundle`    — fetch caption + media + provider connection (incl. `accessTokenEnc`)
- `PATCH  /api/v1/posts/:id/publish-result`    — record state transition + platformPostId / platformUrl / failureReason

Auth: `x-api-key: <brand-scoped V2 API key>`.

## Scripts

| Script | Usage |
|---|---|
| `scripts/run.sh` | Main entrypoint — process all due posts for one brand |
| `scripts/list-due.sh` | List due posts for a brand (returns `posts[]` JSON) |
| `scripts/publish-one.sh` | Process one post end-to-end (claim → bundle → publish → result) |
| `scripts/decrypt-token.mjs` | Decrypt the AES-256-GCM `v1:iv:ct:tag` envelope |
| `scripts/test.sh` | Shape-check (no network) — verifies all scripts parse + `--help` flow works |

## Required env

| Var | Purpose |
|---|---|
| `V2_API_BASE` | e.g. `http://host.docker.internal:3000/api/v1` |
| `ENCRYPTION_KEY` | 64-char hex (32 bytes). Same value used by openclaw-cfw + cfw-social — required to decrypt `accessTokenEnc` from `/publish-bundle` |
| `SKILLS_HOME` | (optional) Path to skills root. Defaults to `~/.claude/skills`. The skill invokes `$SKILLS_HOME/r-social-post-postforme/...` etc. |

## Usage

```bash
V2_API_BASE="http://host.docker.internal:3000/api/v1" \
ENCRYPTION_KEY="<hex>" \
  scripts/run.sh --brand-id "$BRAND_ID" --api-key "$V2_BRAND_API_KEY"
```

Process exits 0 if all due posts are processed (success OR recorded-failure).
Non-zero exit only on configuration errors (missing env, missing args, V2
unreachable). Per-post failures are recorded to `/publish-result` with
`status=failed` and `failureReason` — they do NOT abort the loop.

## Provider routing

Read from the `/publish-bundle` response's `platformConnection.provider` field.

| `provider` | Skill invoked |
|---|---|
| `postforme` | `r-social-post-postforme/scripts/create-post.sh` |
| `outstand`  | `r-social-post-outstand/scripts/create-post.sh` (TODO) |
| `upload-post` | `r-social-post-upload/scripts/create-post.sh` (TODO) |

Unknown provider → marks the post as `failed` with `failureReason`. Does not crash.

## State machine (mirrors V2's publish-result route)

```
scheduled → publishing  (claim — PATCH publishAttempts++)
publishing → published  (success — PATCH platformPostId, status=published)
publishing → failed     (any error — PATCH failureReason, status=failed)
```

Idempotent: re-running on the same `published` post returns 409 from V2 and is treated as success.

## Future migration to standalone daemon
This skill is the entire publishing logic. To split it off later:
1. `git clone` or `cp -r ~/Code/skills/r-cfw-publisher` into the new daemon.
2. Replace the cron trigger with the daemon's scheduler.
3. Set `V2_API_BASE` + `ENCRYPTION_KEY` in the new env.
4. No code changes needed in openclaw-cfw or cfw-social.

## Self-Improvement Feedback Loop

After completing this skill's task:
1. Ask the user: "How did this go? Any corrections or improvements for next time?"
2. Summarize feedback into 1–3 concise bullet points.
3. Append to `LEARNINGS.md` in this folder with the date.
4. If feedback is critical (affects correctness or quality), add it to the **Active Feedback** section at the top of `LEARNINGS.md`.
5. Mark critical feedback with `[ACTIVE]` prefix so it is visually distinct.

